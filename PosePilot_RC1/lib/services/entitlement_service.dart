import 'package:shared_preferences/shared_preferences.dart';

enum Entitlement { freeTrial, pro, expired, cancelled }

class EntitlementService {
  static const _key='posepilot_entitlement';
  Future<Entitlement> read() async {
    final p=await SharedPreferences.getInstance();
    final raw=p.getString(_key) ?? 'freeTrial';
    return Entitlement.values.firstWhere((e)=>e.name==raw,orElse:()=>Entitlement.freeTrial);
  }
  Future<void> setForTesting(Entitlement value) async {
    final p=await SharedPreferences.getInstance();
    await p.setString(_key,value.name);
  }
  bool hasPremium(Entitlement e)=>e==Entitlement.freeTrial || e==Entitlement.pro;
}

// Production gate: replace local testing state with StoreKit/Google Play
// purchase verification + server entitlement before store submission.
