import 'models/pose.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'models/pose_frame.dart';
import 'services/pose_matcher.dart';
import 'services/stability_gate.dart';
import 'services/session_engine.dart';
import 'widgets/ghost_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PosePilot());
}

class PosePilot extends StatelessWidget {
  const PosePilot({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SplashScreen());
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B0B0D),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 72,
                color: Color(0xFFB8A7FF),
              ),
              SizedBox(height: 28),
              Text(
                'POSEPILOT',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Your Personal AI Photographer',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFFB8A7FF),
                ),
              ),
              SizedBox(height: 80),
              Text(
                'Created by Dmitrijs Zigilijs',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9B9BA1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? camera;
  final detector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
  final matcher = PoseMatcher();
  final gate = StabilityGate(requiredMs: 350);
  final session = SessionEngine(total: 10);
  bool processing = false, shooting = false, auto = true, paused = false;
  String guidance = 'Step into frame';
  double score = 0, confidence = 0;
  String? error;
  int lastFrame = 0;
  final List<String> captures = [];
  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    try {
      final available = await availableCameras();
      if (available.isEmpty) throw StateError('No camera found');
      final rear =
          available.where((c) => c.lensDirection == CameraLensDirection.back);
      final selected = rear.isNotEmpty ? rear.first : available.first;
      final c = CameraController(selected, ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888);
      await c.initialize();
      camera = c;
      if (mounted) setState(() {});
      await c.startImageStream(analyze);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  InputImage? inputFrom(CameraImage image) {
    final c = camera;
    if (c == null || image.planes.length != 1) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    final rotation =
        InputImageRotationValue.fromRawValue(c.description.sensorOrientation);
    if (rotation == null) return null;
    return InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: image.planes.first.bytesPerRow));
  }

  Future<void> analyze(CameraImage image) async {
    if (processing ||
        shooting ||
        paused ||
        session.state == ShootState.complete) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastFrame < 100) return;
    lastFrame = now;
    processing = true;
    try {
      final input = inputFrom(image);
      if (input == null) {
        if (mounted)
          setState(() => error = 'Unsupported image format on this device');
        return;
      }
      final poses = await detector.processImage(input);
      if (!mounted) return;
      if (poses.isEmpty) {
        gate.reset();
        setState(() {
          score = 0;
          confidence = 0;
          guidance = 'Step into frame';
        });
        return;
      }
      final pose = poses.first;
      final joints = <String, JointPoint>{};
      const mapping = <String, PoseLandmarkType>{
        'leftShoulder': PoseLandmarkType.leftShoulder,
        'rightShoulder': PoseLandmarkType.rightShoulder,
        'leftHip': PoseLandmarkType.leftHip,
        'rightHip': PoseLandmarkType.rightHip,
        'leftWrist': PoseLandmarkType.leftWrist,
        'rightWrist': PoseLandmarkType.rightWrist,
        'leftAnkle': PoseLandmarkType.leftAnkle,
        'rightAnkle': PoseLandmarkType.rightAnkle,
      };
      for (final e in mapping.entries) {
        final point = pose.landmarks[e.value];
        if (point != null) {
          joints[e.key] = JointPoint(
              point.x / image.width, point.y / image.height, point.likelihood);
        }
      }
      final result = matcher.match(PoseFrame(joints, now), session.target);
      final stable = gate.update(result.perfect, now);
      setState(() {
        score = result.score;
        confidence = result.confidence;
        guidance = stable ? 'Perfect ✨' : result.guidance;
        error = null;
      });
      if (stable && auto) {
        gate.reset();
        await shoot();
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Pose detection error: $e');
    } finally {
      processing = false;
    }
  }

  Future<void> shoot() async {
    final c = camera;
    if (shooting || c == null || !c.value.isInitialized) return;
    shooting = true;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
      final photo = await c.takePicture();
      captures.add(photo.path);
      session.acceptShot(photo.path);
      if (mounted)
        setState(() {
          score = 0;
          guidance = session.state == ShootState.complete
              ? 'Session complete'
              : session.target.cue;
        });
      gate.reset();
      if (session.state != ShootState.complete && c.value.isInitialized)
        await c.startImageStream(analyze);
    } catch (e) {
      if (mounted) setState(() => error = 'Capture error: $e');
      if (c.value.isInitialized && !c.value.isStreamingImages) {
        try {
          await c.startImageStream(analyze);
        } catch (_) {}
      }
    } finally {
      shooting = false;
    }
  }

  void skip() {
    gate.reset();
    session.skip();
    setState(() {
      score = 0;
      guidance = session.state == ShootState.complete
          ? 'Session complete'
          : session.target.cue;
    });
  }

  @override
  void dispose() {
    camera?.dispose();
    detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = camera;
    const accent = Color(0xFFB8A7FF);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: SafeArea(
        child: c == null || !c.value.isInitialized
            ? const Center(
                child: CircularProgressIndicator(color: accent),
              )
            : Stack(
                children: [
                  Positioned.fill(child: CameraPreview(c)),
                  Positioned.fill(
                    child: GhostOverlay(
                      score: score,
                    ),
                  ),

                  // Top premium bar
                  Positioned(
                    top: 14,
                    left: 18,
                    right: 18,
                    child: Row(
                      children: [
                        const Text(
                          'POSEPILOT',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accent.withOpacity(.55),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 13,
                                color: accent,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'AI',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${session.current}/${session.total}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Guidance glass card
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 132,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 17, 20, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xE61A191F),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(.10),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 24,
                            color: Color(0x55000000),
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            session.state == ShootState.complete
                                ? 'Session Complete'
                                : session.target.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: accent,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error ?? guidance,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              value: score.clamp(0, 1),
                              backgroundColor: Colors.white.withOpacity(.14),
                              valueColor: const AlwaysStoppedAnimation(accent),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            '${(score * 100).round()}% match  •  ${(confidence * 100).round()}% confidence',
                            style: TextStyle(
                              color: Colors.white.withOpacity(.78),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom controls
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _cameraAction(
                          icon: Icons.accessibility_new_rounded,
                          label: 'POSE',
                          onTap: () async {
                            final selected = await Navigator.push<int>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PoseLibraryScreen(
                                  selectedIndex: session.current,
                                ),
                              ),
                            );
                            if (selected != null && mounted) {
                              gate.reset();
                              session.selectPose(selected);
                              setState(() {
                                score = 0;
                                confidence = 0;
                                guidance = session.target.cue;
                                error = null;
                              });
                            }
                          },
                        ),
                        _cameraAction(
                          icon: Icons.light_mode_outlined,
                          label: 'LIGHT',
                          onTap: () {},
                        ),
                        GestureDetector(
                          onTap: shooting ? null : shoot,
                          child: Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                            ),
                            padding: const EdgeInsets.all(5),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: shooting
                                  ? const Padding(
                                      padding: EdgeInsets.all(18),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF0B0B0D),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Color(0xFF0B0B0D),
                                      size: 30,
                                    ),
                            ),
                          ),
                        ),
                        _cameraAction(
                          icon: auto
                              ? Icons.auto_awesome
                              : Icons.auto_awesome_outlined,
                          label: 'AI',
                          active: auto,
                          onTap: () => setState(() => auto = !auto),
                        ),
                        _cameraAction(
                          icon: Icons.photo_library_outlined,
                          label: 'SHOTS',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Gallery(
                                paths: List.of(captures),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _cameraAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    const accent = Color(0xFFB8A7FF);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? accent : Colors.white,
              size: 25,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? accent : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: .6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PoseLibraryScreen extends StatelessWidget {
  final int selectedIndex;

  const PoseLibraryScreen({
    super.key,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFB8A7FF);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'POSE LIBRARY',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            Text(
              '30 AI-guided poses',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9B9BA1),
              ),
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: poseLibrary.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final pose = poseLibrary[index];
          final selected = index == selectedIndex;

          return Material(
            color: selected ? accent.withOpacity(.14) : const Color(0xFF151518),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.pop(context, index),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? accent.withOpacity(.65)
                        : Colors.white.withOpacity(.07),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pose.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            pose.cue,
                            style: const TextStyle(
                              color: Color(0xFF9B9BA1),
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.chevron_right_rounded,
                      color: selected ? accent : const Color(0xFF9B9BA1),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class Gallery extends StatelessWidget {
  final List<String> paths;
  const Gallery({super.key, required this.paths});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('Session gallery (${paths.length})')),
      body: paths.isEmpty
          ? const Center(child: Text('Your captured photos will appear here'))
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2),
              itemCount: paths.length,
              itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.all(3),
                  child: Image.file(File(paths[i]), fit: BoxFit.cover))));
}
