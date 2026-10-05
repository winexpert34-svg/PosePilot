class PoseTarget {
  final String id, name, cue;
  final double shoulderTilt, hipTilt, armSpread, stance;
  const PoseTarget(this.id, this.name, this.cue, this.shoulderTilt,
      this.hipTilt, this.armSpread, this.stance);
}

const poseLibrary = <PoseTarget>[
  PoseTarget('S01', 'Relaxed Stand', 'Relax your shoulders', 0, 0, .35, .30),
  PoseTarget('S02', 'One Leg Forward', 'Bring one foot slightly forward', 0,
      .08, .35, .48),
  PoseTarget('S03', 'Weight Shift', 'Shift your weight to one hip', .03, .18,
      .32, .38),
  PoseTarget('S04', '¾ Stand', 'Turn your body slightly', .05, .12, .30, .34),
  PoseTarget(
      'S05', 'Over Shoulder', 'Turn away, then look back', .08, .15, .28, .32),
  PoseTarget('S06', 'Walking', 'Take a slow natural step', .05, .10, .42, .62),
  PoseTarget('S07', 'Hands at Waist', 'Bring your hands toward your waist', 0,
      .08, .55, .34),
  PoseTarget(
      'S08', 'Relaxed Hands', 'Let your arms fall naturally', 0, 0, .24, .32),
  PoseTarget('S09', 'Chair Relaxed', 'Sit tall and relax your shoulders', 0,
      .08, .40, .50),
  PoseTarget(
      'S10', 'Chair ¾', 'Turn slightly while seated', .05, .12, .38, .48),
  PoseTarget('S11', 'Edge Sitting', 'Sit near the edge and lengthen posture', 0,
      .08, .42, .55),
  PoseTarget(
      'S12', 'Crossed Legs', 'Cross your legs naturally', 0, .10, .32, .28),
  PoseTarget(
      'S13', 'One Leg Extended', 'Extend one leg slightly', 0, .08, .34, .60),
  PoseTarget(
      'S14', 'Relaxed Lounge', 'Lean back naturally', .06, .12, .48, .45),
  PoseTarget(
      'S15', 'Shoulder Lean', 'Lean one shoulder gently', .18, .08, .32, .34),
  PoseTarget('S16', 'Back Lean', 'Lean back slightly', .04, .08, .30, .36),
  PoseTarget(
      'S17', 'One Foot Wall', 'Lift one foot behind you', .04, .12, .34, .55),
  PoseTarget('S18', 'Side Lean', 'Lean gently to one side', .20, .12, .34, .38),
  PoseTarget(
      'S19', 'Facing Window', 'Turn toward the light', .04, .08, .28, .32),
  PoseTarget(
      'S20', 'Window Profile', 'Show a clean side profile', .04, .10, .26, .32),
  PoseTarget(
      'S21', 'Looking Outside', 'Look beyond the camera', .04, .08, .28, .32),
  PoseTarget(
      'S22', 'Back to Window', 'Turn away from the window', .05, .10, .30, .34),
  PoseTarget(
      'S23', 'Face Forward', 'Square your face to camera', 0, 0, .30, .32),
  PoseTarget('S24', 'Head Turn', 'Turn your head slightly', 0, .04, .30, .32),
  PoseTarget(
      'S25', 'Chin Slightly Down', 'Lower your chin a little', 0, 0, .30, .32),
  PoseTarget('S26', 'Look Away', 'Look just past the camera', 0, .04, .30, .32),
  PoseTarget(
      'S27', 'Dynamic Step', 'Step through the frame', .08, .12, .45, .68),
  PoseTarget('S28', 'Hand Near Face', 'Bring one hand near your face', .04, .06,
      .62, .32),
  PoseTarget('S29', 'Turn & Look', 'Turn, then look back to camera', .08, .16,
      .34, .38),
  PoseTarget('S30', 'Editorial', 'Create a stronger asymmetrical line', .18,
      .20, .58, .50),
];
