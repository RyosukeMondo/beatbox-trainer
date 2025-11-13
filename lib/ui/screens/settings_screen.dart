import 'package:flutter/material.dart';

/// Settings screen for configuring BPM, debug mode, and classifier level
/// Implementation will be completed in Task 4.3
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 64),
            SizedBox(height: 16),
            Text('Settings Screen', style: TextStyle(fontSize: 24)),
            SizedBox(height: 16),
            Text('This will be implemented in Task 4.3'),
          ],
        ),
      ),
    );
  }
}
