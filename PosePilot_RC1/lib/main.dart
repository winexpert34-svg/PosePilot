import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PosePilotApp());
}

class PosePilotApp extends StatelessWidget {
  const PosePilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const Scaffold(
        backgroundColor: Color(0xFF0B0B0D),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined,
                    size: 72, color: Color(0xFFB8A7FF)),
                SizedBox(height: 28),
                Text(
                  'POSEPILOT',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Your Personal AI Photographer',
                  style: TextStyle(fontSize: 16, color: Color(0xFFB8A7FF)),
                ),
                SizedBox(height: 80),
                Text(
                  'Created by Dmitrijs Zigilijs',
                  style: TextStyle(fontSize: 14, color: Color(0xFF9B9BA1)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
