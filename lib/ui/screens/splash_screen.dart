import 'package:flutter/material.dart';

/// Splash screen that checks for existing calibration data
/// Implementation will be completed in Task 3.2
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 64),
            SizedBox(height: 16),
            Text('Beatbox Trainer', style: TextStyle(fontSize: 24)),
            SizedBox(height: 32),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
