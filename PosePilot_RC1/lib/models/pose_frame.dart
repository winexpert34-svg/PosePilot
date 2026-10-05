class JointPoint {
  final double x, y, likelihood;
  const JointPoint(this.x, this.y, [this.likelihood = 1]);
}

class PoseFrame {
  final Map<String, JointPoint> joints;
  final int timestampMs;
  const PoseFrame(this.joints, this.timestampMs);
  JointPoint? operator [](String key) => joints[key];
}
