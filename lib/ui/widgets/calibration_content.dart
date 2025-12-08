import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/calibration_progress.dart';
import 'calibration_confirmation_buttons.dart';
import 'calibration_level_feedback.dart';
import 'sample_progress_dots.dart';

class CalibrationContent extends StatelessWidget {
  const CalibrationContent({
    super.key,
    required this.progress,
    required this.audioRms,
    required this.guidance,
    required this.manualAcceptAvailable,
    required this.onManualAccept,
    required this.onRetry,
    required this.onConfirm,
    required this.onComplete,
    required this.pulseAnimation,
    required this.flashAnimation,
  });

  final CalibrationProgress progress;
  final ValueListenable<double?> audioRms;
  final ValueListenable<String?> guidance;
  final ValueListenable<bool> manualAcceptAvailable;
  final VoidCallback onManualAccept;
  final Future<void> Function() onRetry;
  final Future<bool> Function() onConfirm;
  final Future<void> Function() onComplete;
  final Animation<double> pulseAnimation;
  final Animation<double> flashAnimation;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildOverallProgress(),
            const SizedBox(height: 24),
            _buildSoundTypeIndicator(),
            const SizedBox(height: 24),
            ValueListenableBuilder<double?>(
              valueListenable: audioRms,
              builder: (context, currentRms, _) => CalibrationLevelFeedback(
                currentRms: currentRms,
                debug: progress.debug,
                sound: progress.currentSound,
              ),
            ),
            const SizedBox(height: 16),
            if (progress.currentSound.isSoundPhase)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: CalibrationStatusSummary(
                  debug: progress.debug,
                  sound: progress.currentSound,
                ),
              ),
            ValueListenableBuilder<String?>(
              valueListenable: guidance,
              builder: (context, guidanceMessage, _) {
                if (guidanceMessage == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _GuidanceBanner(message: guidanceMessage),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: manualAcceptAvailable,
              builder: (context, available, _) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: available ? onManualAccept : null,
                      icon: const Icon(Icons.rule),
                      label: const Text('Count last hit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.lightBlueAccent,
                        side: BorderSide(
                          color: Colors.lightBlueAccent.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            SampleProgressDots(
              collected: progress.samplesCollected,
              needed: progress.samplesNeeded,
              color: progress.currentSound.color,
            ),
            const SizedBox(height: 20),
            if (progress.waitingForConfirmation)
              CalibrationConfirmationButtons(
                sound: progress.currentSound,
                onRetry: onRetry,
                onConfirm: () async {
                  final hasNext = await onConfirm();
                  if (!hasNext) {
                    await onComplete();
                  }
                },
              )
            else
              _buildInstructions(),
            const SizedBox(height: 20),
            _buildTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallProgress() {
    final currentStep = progress.currentSound.index + 1;
    const totalSteps = 4;
    final overallProgress = progress.overallProgressFraction;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step $currentStep of $totalSteps',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(overallProgress * 100).toInt()}% Complete',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: overallProgress,
            minHeight: 8,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D9FF)),
          ),
        ),
      ],
    );
  }

  Widget _buildSoundTypeIndicator() {
    final sound = progress.currentSound;
    final color = sound.color;
    final icon = sound.icon;

    return AnimatedBuilder(
      animation: flashAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(
                  alpha: 0.3 + (flashAnimation.value * 0.5),
                ),
                blurRadius: 30 + (flashAnimation.value * 20),
                spreadRadius: 5 + (flashAnimation.value * 10),
              ),
            ],
          ),
          child: ScaleTransition(
            scale: pulseAnimation,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color, width: 3),
              ),
              child: Icon(icon, size: 70, color: color),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructions() {
    final sound = progress.currentSound;
    final isNoiseFloor = sound == CalibrationSound.noiseFloor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            isNoiseFloor
                ? 'Measuring Ambient Noise'
                : 'Make the ${sound.displayName} sound',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sound.instructionText,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: sound.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              sound.phoneticHint,
              style: TextStyle(
                color: sound.color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontStyle: isNoiseFloor ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.amber[300], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              progress.currentSound.tipText,
              style: TextStyle(color: Colors.amber[100], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidanceBanner extends StatelessWidget {
  const _GuidanceBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hearing, color: Colors.lightBlueAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
