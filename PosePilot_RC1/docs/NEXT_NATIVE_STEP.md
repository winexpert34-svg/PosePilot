# Native completion gate

Android: CameraX/ML Kit pose stream -> normalized PoseFrame -> Flutter EventChannel or native matching.
iOS: AVFoundation/Vision body pose -> normalized PoseFrame -> same contract.

Acceptance gate:
- 15+ FPS landmark analysis on target devices
- front-camera mirroring correct
- pose score stable under minor jitter
- Perfect only after 300 ms stable confidence
- automatic photo fires once per pose
- no raw video upload
