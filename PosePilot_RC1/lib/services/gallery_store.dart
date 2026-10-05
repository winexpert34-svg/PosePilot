import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GalleryStore {
  static const _key='posepilot_shots_v1';
  Future<List<String>> load() async {
    final p=await SharedPreferences.getInstance();
    return (p.getStringList(_key) ?? const <String>[]);
  }
  Future<void> add(String path) async {
    final p=await SharedPreferences.getInstance();
    final shots=p.getStringList(_key) ?? <String>[];
    if(!shots.contains(path)) shots.insert(0,path);
    await p.setStringList(_key,shots.take(200).toList());
  }
  Future<void> clear() async {
    final p=await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
