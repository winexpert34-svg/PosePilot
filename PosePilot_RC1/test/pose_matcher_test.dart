import 'package:flutter_test/flutter_test.dart';
import 'package:posepilot/models/pose.dart';
import 'package:posepilot/models/pose_frame.dart';
import 'package:posepilot/services/pose_matcher.dart';

void main(){
  test('low landmark count asks user to move back',(){
    final f=PoseFrame({'leftShoulder':const JointPoint(.3,.3,.9)},0);
    final r=PoseMatcher().match(f,poseLibrary.first);
    expect(r.score,0);
    expect(r.guidance,contains('Move back'));
  });
  test('matcher clamps scores to valid range',(){
    final j=<String,JointPoint>{
      'leftShoulder':const JointPoint(.35,.30,.95),'rightShoulder':const JointPoint(.65,.30,.95),
      'leftHip':const JointPoint(.40,.55,.95),'rightHip':const JointPoint(.60,.55,.95),
      'leftWrist':const JointPoint(.30,.55,.95),'rightWrist':const JointPoint(.70,.55,.95),
      'leftAnkle':const JointPoint(.43,.90,.95),'rightAnkle':const JointPoint(.57,.90,.95),
    };
    final r=PoseMatcher().match(PoseFrame(j,0),poseLibrary.first);
    expect(r.score,inInclusiveRange(0,1));
    expect(r.confidence,inInclusiveRange(0,1));
  });
}
