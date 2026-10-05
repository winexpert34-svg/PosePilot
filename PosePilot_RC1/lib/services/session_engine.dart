import '../models/pose.dart';

enum ShootState { searching, tracking, guiding, almost, perfect, shooting, reviewing, next, complete }

class SessionEngine {
  final int total;
  int current = 0;
  ShootState state = ShootState.searching;
  final List<String> shots = [];
  SessionEngine({this.total=10});

  PoseTarget get target => poseLibrary[current % poseLibrary.length];

  void acceptShot(String path) {
    shots.add(path);
    current++;
    state = current >= total ? ShootState.complete : ShootState.next;
  }

  void skip() {
    current++;
    state = current >= total ? ShootState.complete : ShootState.next;
  }
}
