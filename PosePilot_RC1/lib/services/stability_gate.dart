class StabilityGate {
  final int requiredMs;
  int? _since;
  StabilityGate({this.requiredMs = 350});
  bool update(bool good, int nowMs) {
    if (!good) {
      _since = null;
      return false;
    }
    _since ??= nowMs;
    return nowMs - _since! >= requiredMs;
  }

  void reset() => _since = null;
}
