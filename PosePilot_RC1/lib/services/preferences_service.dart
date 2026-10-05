import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  Future<bool> onboarded() async =>
      (await SharedPreferences.getInstance()).getBool('onboarded') ?? false;
  Future<void> completeOnboarding() async =>
      (await SharedPreferences.getInstance()).setBool('onboarded', true);
  Future<String> style() async =>
      (await SharedPreferences.getInstance()).getString('style') ?? 'Natural';
  Future<void> setStyle(String v) async =>
      (await SharedPreferences.getInstance()).setString('style', v);
  Future<String> guidance() async =>
      (await SharedPreferences.getInstance()).getString('guidance') ??
      'Visual + Voice';
  Future<void> setGuidance(String v) async =>
      (await SharedPreferences.getInstance()).setString('guidance', v);
}
