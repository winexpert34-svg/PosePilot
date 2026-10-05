import 'package:flutter_test/flutter_test.dart';
import 'package:posepilot/services/stability_gate.dart';
void main(){test('requires stable window',(){final g=StabilityGate(requiredMs:300);expect(g.update(true,1000),false);expect(g.update(true,1200),false);expect(g.update(true,1301),true);g.update(false,1400);expect(g.update(true,1500),false);});}
