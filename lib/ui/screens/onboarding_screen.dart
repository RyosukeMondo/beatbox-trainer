import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Onboarding screen that explains calibration to first-time users
///
/// This screen provides a welcoming introduction to the app and explains
/// the calibration process that new users need to complete before training.
///
/// Features:
/// - App logo/icon display
/// - Welcome message
/// - Explanation of calibration purpose
/// - 3-step visual guide (KICK → SNARE → HI-HAT)
/// - Navigation button to start calibration
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 32),
              _buildCalibrationSteps(context),
              const SizedBox(height: 48),
              _buildStartButton(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the header with logo and welcome message
  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.mic, size: 100, color: Colors.deepPurple),
        const SizedBox(height: 32),
        Text(
          'Welcome to Beatbox Trainer!',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Before you start training, we need to calibrate '
          'the app to recognize your beatbox sounds.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Builds the start calibration button
  Widget _buildStartButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => context.go('/calibration'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      child: const Text('Start Calibration', style: TextStyle(fontSize: 18)),
    );
  }

  /// Builds the 3-step calibration guide
  Widget _buildCalibrationSteps(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Calibration Steps:',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildStep(context, '1', 'Make 10 KICK sounds', Icons.circle),
        const SizedBox(height: 12),
        _buildStep(context, '2', 'Make 10 SNARE sounds', Icons.circle_outlined),
        const SizedBox(height: 12),
        _buildStep(context, '3', 'Make 10 HI-HAT sounds', Icons.adjust),
      ],
    );
  }

  /// Builds a single step indicator
  Widget _buildStep(
    BuildContext context,
    String stepNumber,
    String description,
    IconData icon,
  ) {
    return Row(
      children: [
        // Step number circle
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade100,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Step icon
        Icon(icon, color: Colors.deepPurple.shade300, size: 24),
        const SizedBox(width: 12),

        // Step description
        Expanded(
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
