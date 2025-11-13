import 'package:flutter/material.dart';

/// Onboarding screen that explains calibration to first-time users
/// Implementation will be completed in Task 3.3
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 64),
            SizedBox(height: 16),
            Text('Onboarding Screen', style: TextStyle(fontSize: 24)),
            SizedBox(height: 16),
            Text('This will be implemented in Task 3.3'),
          ],
        ),
      ),
    );
  }
}
