import 'dart:math';
import 'package:gal/gal.dart';
import 'models/pose.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
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
  double lightLevel = 0.0;
  String lightAdvice = 'Analyzing your light';

  CameraController? camera;
  final detector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableTracking: false,
    ),
  );
  final objectDetector = ObjectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    ),
  );

  final matcher = PoseMatcher();
  final gate = StabilityGate(requiredMs: 350);
  final session = SessionEngine(total: 10);
  bool processing = false, shooting = false, auto = true, paused = false;
  String guidance = 'Step into frame';
  double score = 0, confidence = 0;
  String? error;
  int lastFrame = 0;

  // PosePilot Scene AI
  int lastSceneAnalysis = 0;
  String sceneAdvice = 'Analyzing scene...';
  int sceneObjectCount = 0;
  final List<String> captures = [];
  final Map<String, double> shotQuality = {};
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

    // PosePilot Light Engine — local realtime luminance analysis.
    // Uses the camera Y plane only; no cloud and no extra dependencies.
    if (image.planes.isNotEmpty) {
      final bytes = image.planes.first.bytes;
      if (bytes.isNotEmpty) {
        const sampleCount = 1200;
        final step =
            bytes.length > sampleCount ? bytes.length ~/ sampleCount : 1;

        int total = 0;
        int count = 0;

        for (int i = 0; i < bytes.length; i += step) {
          total += bytes[i];
          count++;
        }

        if (count > 0) {
          final value = total / count / 255.0;
          lightLevel =
              lightLevel == 0 ? value : (lightLevel * 0.82) + (value * 0.18);

          if (lightLevel < 0.22) {
            lightAdvice = 'Move toward a light source';
          } else if (lightLevel < 0.38) {
            lightAdvice = 'A little more light would help';
          } else if (lightLevel > 0.86) {
            lightAdvice = 'Light is too strong — move away slightly';
          } else if (lightLevel > 0.72) {
            lightAdvice = 'Bright light — turn slightly';
          } else {
            lightAdvice = 'Light looks good ✨';
          }
        }
      }
    }

    try {
      final input = inputFrom(image);
      if (input == null) {
        if (mounted)
          setState(() => error = 'Unsupported image format on this device');
        return;
      }
      // Scene AI — throttled object detection.
      if (now - lastSceneAnalysis >= 1000) {
        lastSceneAnalysis = now;
        try {
          final objects = await objectDetector.processImage(input);
          if (mounted) {
            setState(() {
              sceneObjectCount = objects.length;
              sceneAdvice = objects.isEmpty
                  ? 'Open scene'
                  : objects.length == 1
                      ? '1 object detected'
                      : '${objects.length} objects detected';
            });
          }
        } catch (e) {
          debugPrint('PosePilot Scene AI: $e');
        }
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
      if (stable && auto && !shooting) {
        gate.reset();
        if (mounted) {
          setState(() => guidance = 'Perfect ✨ Hold still…');
        }
        await Future.delayed(const Duration(milliseconds: 450));
        if (!mounted || shooting) return;
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

      // AI Picks Human Gate.
      // The SAVED JPEG is checked by an independent face detector.
      // Pose Detection is deliberately NOT used to prove a human exists.
      bool personVisibleInPhoto = false;
      double compositionScore = 1.0;
      try {
        final capturedInput = InputImage.fromFilePath(photo.path);
        final faces = await faceDetector.processImage(capturedInput);
        personVisibleInPhoto = faces.isNotEmpty;

        // AI Picks 2.0: composition affects ranking, not Human Gate.
        if (faces.isNotEmpty) {
          final largestFace = faces.reduce((a, b) =>
              a.boundingBox.width * a.boundingBox.height >=
                      b.boundingBox.width * b.boundingBox.height
                  ? a
                  : b);
          final box = largestFace.boundingBox;
          final faceArea = box.width * box.height;
          // Prefer a clearly visible face over a tiny distant face.
          // This is a mild ranking bonus, never a rejection condition.
          compositionScore = faceArea > 0 ? 1.0 : 0.95;
        }
        debugPrint(
          'PosePilot Human Gate: faces=${faces.length}, '
          'eligible=$personVisibleInPhoto',
        );
      } catch (e) {
        // Fail closed: detector failure must never create an AI Pick.
        personVisibleInPhoto = false;
        debugPrint('PosePilot Human Gate failed: $e');
      }

      // Save every captured PosePilot photo to the phone gallery.
      try {
        await Gal.putImage(photo.path, album: 'PosePilot');
      } catch (e) {
        debugPrint('PosePilot gallery save failed: $e');
      }

      // PosePilot ShotQuality v1
      final poseQuality = score.clamp(0.0, 1.0);
      final trackingQuality = confidence.clamp(0.0, 1.0);
      final exposureQuality =
          (1.0 - ((lightLevel - 0.55).abs() / 0.55)).clamp(0.0, 1.0);

      final baseQuality =
          (poseQuality * 0.50 + trackingQuality * 0.25 + exposureQuality * 0.25)
              .clamp(0.0, 1.0);

      // ShotQuality v2: suppress unusable frames before AI Picks ranking.
      double qualityPenalty = 1.0;

      if (trackingQuality < 0.30) {
        qualityPenalty *= 0.35;
      } else if (trackingQuality < 0.50) {
        qualityPenalty *= 0.70;
      }

      if (exposureQuality < 0.25) {
        qualityPenalty *= 0.40;
      } else if (exposureQuality < 0.45) {
        qualityPenalty *= 0.75;
      }

      // Human-first AI Picks v6.
      // Only the captured JPEG decides whether a person exists.
      // This prevents stale live-camera tracking and false AI Picks.
      final humanPenalty = personVisibleInPhoto ? 1.0 : 0.0;
      final eligibleForAiPick = personVisibleInPhoto;

      final quality =
          (baseQuality * qualityPenalty * humanPenalty * compositionScore)
              .clamp(0.0, 1.0);

      captures.add(photo.path);
      shotQuality[photo.path] = quality;

      // AI Photographer: keep every photo in ALL,
      // but only real detected people may enter AI PICKS.
      final acceptShot =
          trackingQuality >= 0.45 && exposureQuality >= 0.35 && quality >= 0.42;

      if (acceptShot && eligibleForAiPick) {
        session.acceptShot(photo.path);
      }

      if (mounted) {
        setState(() {
          score = 0;
          guidance = acceptShot
              ? (session.state == ShootState.complete
                  ? 'Session complete ✨'
                  : 'Great shot ✨ Next pose')
              : 'Let’s retry this shot';
        });
      }
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
    faceDetector.close();
    objectDetector.close();
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
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'LIGHT AI • $lightAdvice • ${(lightLevel * 100).round()}%'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
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
                                quality: Map.of(shotQuality),
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

class Gallery extends StatefulWidget {
  final List<String> paths;
  final Map<String, double> quality;

  const Gallery({
    super.key,
    required this.paths,
    required this.quality,
  });

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  int tab = 0;
  final Set<String> favorites = {};

  List<String> get visible {
    if (tab == 0) {
      // Rank photos by PosePilot ShotQuality.
      // AI PICKS contains only photos that passed Human Gate + quality.
      // Rejected photos remain available in ALL.
      final ranked = widget.paths
          .where((path) => (widget.quality[path] ?? 0.0) >= 0.42)
          .toList()
        ..sort(
          (a, b) =>
              (widget.quality[b] ?? 0.0).compareTo(widget.quality[a] ?? 0.0),
        );

      return ranked.take(ranked.length < 3 ? ranked.length : 3).toList();
    }
    if (tab == 2) {
      return widget.paths.where(favorites.contains).toList();
    }
    return widget.paths;
  }

  @override
  Widget build(BuildContext context) {
    final photos = visible;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0D),
        foregroundColor: const Color(0xFFF5F5F2),
        title: const Text('Session Gallery'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _tab('AI PICKS', 0),
                const SizedBox(width: 8),
                _tab('ALL', 1),
                const SizedBox(width: 8),
                _tab('FAVORITES', 2),
              ],
            ),
          ),
          Expanded(
            child: photos.isEmpty
                ? Center(
                    child: Text(
                      tab == 2
                          ? 'Tap ♡ on a photo to add it here'
                          : 'Your captured photos will appear here',
                      style: const TextStyle(color: Color(0xFF9B9BA1)),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: photos.length,
                    itemBuilder: (_, i) {
                      final path = photos[i];
                      final fav = favorites.contains(path);

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(path),
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: const Color(0x990B0B0D),
                              shape: const CircleBorder(),
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    fav
                                        ? favorites.remove(path)
                                        : favorites.add(path);
                                  });
                                },
                                icon: Icon(
                                  fav ? Icons.favorite : Icons.favorite_border,
                                  color: fav
                                      ? const Color(0xFFB8A7FF)
                                      : const Color(0xFFF5F5F2),
                                ),
                              ),
                            ),
                          ),
                          if (tab == 0)
                            const Positioned(
                              left: 10,
                              bottom: 10,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0xCC151518),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(20)),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    'AI PICK ✨',
                                    style: TextStyle(
                                      color: Color(0xFFB8A7FF),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, int index) {
    final selected = tab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFB8A7FF) : const Color(0xFF1D1D21),
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color:
                  selected ? const Color(0xFF0B0B0D) : const Color(0xFFF5F5F2),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
