import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'models/pose.dart';
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
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,theme:ThemeData.dark(),
    home:const CameraScreen());
}
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override State<CameraScreen> createState()=>_CameraScreenState();
}
class _CameraScreenState extends State<CameraScreen> {
  CameraController? camera;
  final detector=PoseDetector(options:PoseDetectorOptions(mode:PoseDetectionMode.stream));
  final matcher=PoseMatcher();
  final gate=StabilityGate(requiredMs:350);
  final session=SessionEngine(total:10);
  bool processing=false, shooting=false, auto=true, paused=false;
  String guidance='Step into frame';
  double score=0, confidence=0;
  String? error;
  int lastFrame=0;
  final List<String> captures=[];
  @override void initState(){super.initState();initCamera();}
  Future<void> initCamera() async {
    try {
      final available=await availableCameras();
      if(available.isEmpty)throw StateError('No camera found');
      final rear=available.where((c)=>c.lensDirection==CameraLensDirection.back);
      final selected=rear.isNotEmpty?rear.first:available.first;
      final c=CameraController(selected,ResolutionPreset.medium,enableAudio:false,
        imageFormatGroup:Platform.isAndroid?ImageFormatGroup.nv21:ImageFormatGroup.bgra8888);
      await c.initialize();
      camera=c;
      if(mounted)setState((){});
      await c.startImageStream(analyze);
    } catch(e){if(mounted)setState(()=>error='$e');}
  }
  InputImage? inputFrom(CameraImage image) {
    final c=camera;
    if(c==null || image.planes.length!=1)return null;
    final format=InputImageFormatValue.fromRawValue(image.format.raw);
    if(format==null)return null;
    if(Platform.isAndroid && format!=InputImageFormat.nv21)return null;
    if(Platform.isIOS && format!=InputImageFormat.bgra8888)return null;
    final rotation=InputImageRotationValue.fromRawValue(c.description.sensorOrientation);
    if(rotation==null)return null;
    return InputImage.fromBytes(bytes:image.planes.first.bytes,
      metadata:InputImageMetadata(size:Size(image.width.toDouble(),image.height.toDouble()),
        rotation:rotation,format:format,bytesPerRow:image.planes.first.bytesPerRow));
  }
  Future<void> analyze(CameraImage image) async {
    if(processing||shooting||paused||session.state==ShootState.complete)return;
    final now=DateTime.now().millisecondsSinceEpoch;
    if(now-lastFrame<100)return;
    lastFrame=now;processing=true;
    try {
      final input=inputFrom(image);
      if(input==null){if(mounted)setState(()=>error='Unsupported image format on this device');return;}
      final poses=await detector.processImage(input);
      if(!mounted)return;
      if(poses.isEmpty){gate.reset();setState((){score=0;confidence=0;guidance='Step into frame';});return;}
      final pose=poses.first;
      final joints=<String,JointPoint>{};
      const mapping=<String,PoseLandmarkType>{
        'leftShoulder':PoseLandmarkType.leftShoulder,'rightShoulder':PoseLandmarkType.rightShoulder,
        'leftHip':PoseLandmarkType.leftHip,'rightHip':PoseLandmarkType.rightHip,
        'leftWrist':PoseLandmarkType.leftWrist,'rightWrist':PoseLandmarkType.rightWrist,
        'leftAnkle':PoseLandmarkType.leftAnkle,'rightAnkle':PoseLandmarkType.rightAnkle,
      };
      for(final e in mapping.entries){final point=pose.landmarks[e.value];if(point!=null){
        joints[e.key]=JointPoint(point.x/image.width,point.y/image.height,point.likelihood);
      }}
      final result=matcher.match(PoseFrame(joints,now),session.target);
      final stable=gate.update(result.perfect,now);
      setState((){score=result.score;confidence=result.confidence;
        guidance=stable?'Perfect ✨':result.guidance;error=null;});
      if(stable&&auto){gate.reset();await shoot();}
    }catch(e){if(mounted)setState(()=>error='Pose detection error: $e');}
    finally{processing=false;}
  }
  Future<void> shoot() async {
    final c=camera;if(shooting||c==null||!c.value.isInitialized)return;
    shooting=true;
    try{
      if(c.value.isStreamingImages)await c.stopImageStream();
      final photo=await c.takePicture();
      captures.add(photo.path);session.acceptShot(photo.path);
      if(mounted)setState((){score=0;guidance=session.state==ShootState.complete?'Session complete':session.target.cue;});
      gate.reset();
      if(session.state!=ShootState.complete && c.value.isInitialized)await c.startImageStream(analyze);
    }catch(e){if(mounted)setState(()=>error='Capture error: $e');
      if(c.value.isInitialized&&!c.value.isStreamingImages){try{await c.startImageStream(analyze);}catch(_){}}}
    finally{shooting=false;}
  }
  void skip(){gate.reset();session.skip();setState((){score=0;guidance=session.state==ShootState.complete?'Session complete':session.target.cue;});}
  @override void dispose(){camera?.dispose();detector.close();super.dispose();}
  @override Widget build(BuildContext context){
    final c=camera;
    return Scaffold(backgroundColor:const Color(0xFF0B0B0D),body:SafeArea(child:
      c==null||!c.value.isInitialized?Center(child:Text(error??'Opening camera…')):
      Stack(children:[
        Positioned.fill(child:CameraPreview(c)),
        Positioned.fill(child:GhostOverlay(score:score)),
        Positioned(top:16,left:16,right:16,child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
          const Text('POSEPILOT',style:TextStyle(fontWeight:FontWeight.bold,letterSpacing:3)),
          Text('${session.current}/${session.total} captured')])),
        Positioned(left:16,right:16,bottom:115,child:Container(padding:const EdgeInsets.all(16),
          decoration:BoxDecoration(color:const Color(0xE0151518),borderRadius:BorderRadius.circular(20)),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            Text(session.state==ShootState.complete?'Finished':session.target.name,
              style:const TextStyle(color:Color(0xFFB8A7FF),fontWeight:FontWeight.bold)),
            const SizedBox(height:8),Text(error??guidance,textAlign:TextAlign.center),
            const SizedBox(height:8),LinearProgressIndicator(value:score.clamp(0,1)),
            Text('${(score*100).round()}% • confidence ${(confidence*100).round()}%'),
          ]))),
        Positioned(bottom:18,left:14,right:14,child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
          TextButton(onPressed:()=>setState(()=>auto=!auto),child:Text(auto?'AUTO':'MANUAL')),
          IconButton(onPressed:shoot,icon:const Icon(Icons.camera,size:58),tooltip:'Take photo'),
          TextButton(onPressed:session.state==ShootState.complete?null:skip,child:const Text('SKIP')),
          IconButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Gallery(paths:List.of(captures)))),
            icon:const Icon(Icons.photo_library_outlined),tooltip:'Session gallery'),
        ]))
      ])));
  }
}
class Gallery extends StatelessWidget {
  final List<String> paths;const Gallery({super.key,required this.paths});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('Session gallery (${paths.length})')),
    body:paths.isEmpty?const Center(child:Text('Your captured photos will appear here')):
    GridView.builder(gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2),
      itemCount:paths.length,itemBuilder:(_,i)=>Padding(padding:const EdgeInsets.all(3),
      child:Image.file(File(paths[i]),fit:BoxFit.cover))));
}
