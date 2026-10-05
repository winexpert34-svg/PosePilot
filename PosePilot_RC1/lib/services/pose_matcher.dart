import 'dart:math' as math;
import '../models/pose.dart';
import '../models/pose_frame.dart';

class PoseMatchResult {
  final double score, confidence;
  final String guidance;
  const PoseMatchResult(this.score, this.confidence, this.guidance);
  bool get almost => score >= .72 && confidence >= .55;
  bool get perfect => score >= .86 && confidence >= .70;
}

class PoseMatcher {
  PoseMatchResult match(PoseFrame f, PoseTarget target) {
    final ls = f['leftShoulder'],
        rs = f['rightShoulder'],
        lh = f['leftHip'],
        rh = f['rightHip'];
    final lw = f['leftWrist'],
        rw = f['rightWrist'],
        la = f['leftAnkle'],
        ra = f['rightAnkle'];
    final pts =
        [ls, rs, lh, rh, lw, rw, la, ra].whereType<JointPoint>().toList();
    if (pts.length < 6)
      return const PoseMatchResult(0, .2, 'Move back so I can see you');
    final confidence =
        pts.map((p) => p.likelihood).reduce((a, b) => a + b) / pts.length;
    final shoulderWidth = (ls!.x - rs!.x).abs().clamp(.05, 1.0);
    double tilt(JointPoint a, JointPoint b) =>
        ((a.y - b.y) / (a.x - b.x).abs().clamp(.05, 1)).abs();
    final shoulderTilt = tilt(ls, rs).clamp(0.0, 1.0);
    final hipTilt = tilt(lh!, rh!).clamp(0.0, 1.0);
    final armSpread =
        (((lw!.x - rw!.x).abs() / shoulderWidth) / 4).clamp(0.0, 1.0);
    final stance =
        (((la!.x - ra!.x).abs() / shoulderWidth) / 2).clamp(0.0, 1.0);
    double closeness(double a, double b) =>
        math.max(0, 1 - (a - b).abs() * 2.2);
    final parts = [
      closeness(shoulderTilt, target.shoulderTilt),
      closeness(hipTilt, target.hipTilt),
      closeness(armSpread, target.armSpread),
      closeness(stance, target.stance)
    ];
    final score = (parts.reduce((a, b) => a + b) / parts.length) * confidence;
    String g = target.cue;
    final minVal = parts.reduce(math.min), idx = parts.indexOf(minVal);
    if (idx == 0) g = 'Relax your shoulders';
    if (idx == 1) g = 'Shift your hips slightly';
    if (idx == 2)
      g = armSpread < target.armSpread
          ? 'Open your arms a little'
          : 'Bring your arms in slightly';
    if (idx == 3)
      g = stance < target.stance
          ? 'Widen your stance slightly'
          : 'Bring your feet a little closer';
    if (score >= .72) g = 'Almost — hold that';
    if (score >= .86 && confidence >= .70) g = 'Perfect ✨';
    return PoseMatchResult(score.clamp(0, 1), confidence.clamp(0, 1), g);
  }
}
