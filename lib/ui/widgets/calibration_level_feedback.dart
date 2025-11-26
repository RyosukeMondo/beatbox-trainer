import 'package:flutter/material.dart';

import '../../models/calibration_progress.dart';

/// Visual feedback widget for calibration showing level vs noise floor.
///
/// User-centric design: Shows if sound is loud enough to be detected.
/// No frequency/crispness gates - we learn what YOUR sounds look like.
class CalibrationLevelFeedback extends StatelessWidget {
  /// Current raw RMS level (0.0 to ~0.5 typical range)
  final double? currentRms;

  /// Debug data containing thresholds
  final CalibrationProgressDebug? debug;

  /// Current sound being calibrated (for color theming)
  final CalibrationSound sound;

  const CalibrationLevelFeedback({
    super.key,
    required this.currentRms,
    required this.debug,
    required this.sound,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSoundPhase = sound.isSoundPhase;

    if (!isSoundPhase) {
      // Noise floor phase - show simpler meter
      return _buildNoiseFloorMeter();
    }

    return _buildSoundCaptureMeter();
  }

  Widget _buildNoiseFloorMeter() {
    final level = ((currentRms ?? 0) * 10).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.hearing, color: sound.color, size: 20),
              const SizedBox(width: 8),
              const Text(
                'MEASURING BACKGROUND NOISE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AnimatedLevelBar(level: level, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            level < 0.3
                ? '✓ Nice and quiet - perfect!'
                : level < 0.6
                    ? 'A bit noisy, but OK'
                    : 'Try to reduce background noise',
            style: TextStyle(
              color: level < 0.3
                  ? Colors.green
                  : level < 0.6
                      ? Colors.amber
                      : Colors.red,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundCaptureMeter() {
    final lastRms = debug?.lastRms ?? currentRms ?? 0;
    final noiseFloor = debug?.rmsGate ?? 0.01;

    // Detection threshold is 2x noise floor (matches Rust logic)
    final detectionThreshold = noiseFloor * 2.0;

    // Scale for display: map 0-0.15 RMS to 0-1 visual range
    const maxDisplayRms = 0.12;
    final normalizedLevel = (lastRms / maxDisplayRms).clamp(0.0, 1.0);
    final normalizedThreshold = (detectionThreshold / maxDisplayRms).clamp(0.0, 0.6);

    final isAboveThreshold = lastRms >= detectionThreshold;
    final isStrongSignal = lastRms >= detectionThreshold * 1.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isStrongSignal
              ? sound.color.withValues(alpha: 0.5)
              : isAboveThreshold
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic, color: sound.color, size: 20),
              const SizedBox(width: 8),
              Text(
                'MAKE YOUR ${sound.displayName} SOUND',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              _buildStatusIndicator(isAboveThreshold, isStrongSignal),
            ],
          ),
          const SizedBox(height: 12),

          // Level bar with noise floor marker
          SizedBox(
            height: 40,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final thresholdX = constraints.maxWidth * normalizedThreshold;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Background track
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),

                    // "Detected" zone (above noise floor)
                    Positioned(
                      left: thresholdX,
                      right: 0,
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              sound.color.withValues(alpha: 0.1),
                              sound.color.withValues(alpha: 0.25),
                            ],
                          ),
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    // Current level bar
                    _AnimatedLevelBarPositioned(
                      width: constraints.maxWidth * normalizedLevel,
                      height: 28,
                      isActive: isAboveThreshold,
                      color: sound.color,
                    ),

                    // Noise floor marker
                    Positioned(
                      left: thresholdX - 1,
                      top: 0,
                      child: Container(
                        width: 2,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white60,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),

                    // "MIN" label
                    Positioned(
                      left: thresholdX - 14,
                      top: 30,
                      child: const Text(
                        'MIN',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Simple feedback message
          _buildFeedbackMessage(isAboveThreshold, isStrongSignal),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(bool isAboveThreshold, bool isStrong) {
    if (isStrong) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sound.color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sound.color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: sound.color, size: 16),
            const SizedBox(width: 4),
            Text(
              'DETECTED!',
              style: TextStyle(
                color: sound.color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else if (isAboveThreshold) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hearing, color: Colors.green, size: 16),
            SizedBox(width: 4),
            Text(
              'HEARD',
              style: TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_off, color: Colors.white38, size: 16),
            SizedBox(width: 4),
            Text(
              'WAITING',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFeedbackMessage(bool isAboveThreshold, bool isStrong) {
    if (isStrong) {
      return Row(
        children: [
          Icon(Icons.thumb_up, color: sound.color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Great ${sound.displayName}! Keep going at this volume.',
              style: TextStyle(color: sound.color, fontSize: 13),
            ),
          ),
        ],
      );
    } else if (isAboveThreshold) {
      return const Row(
        children: [
          Icon(Icons.volume_up, color: Colors.amber, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Good! Try a bit louder for clearer detection.',
              style: TextStyle(color: Colors.amber, fontSize: 13),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          const Icon(Icons.arrow_upward, color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Make your ${sound.displayName} sound - we\'ll learn what it sounds like!',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ],
      );
    }
  }
}

/// Animated level bar widget
class _AnimatedLevelBar extends StatelessWidget {
  final double level;
  final Color color;

  const _AnimatedLevelBar({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: level,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

/// Positioned animated level bar
class _AnimatedLevelBarPositioned extends StatelessWidget {
  final double width;
  final double height;
  final bool isActive;
  final Color color;

  const _AnimatedLevelBarPositioned({
    required this.width,
    required this.height,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: LinearGradient(
          colors: isActive
              ? [color.withValues(alpha: 0.7), color]
              : [Colors.grey.shade600, Colors.grey.shade500],
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Compact status summary widget - simplified for user-centric calibration
class CalibrationStatusSummary extends StatelessWidget {
  final CalibrationProgressDebug? debug;
  final CalibrationSound sound;

  const CalibrationStatusSummary({
    super.key,
    required this.debug,
    required this.sound,
  });

  @override
  Widget build(BuildContext context) {
    if (debug == null || !sound.isSoundPhase) {
      return const SizedBox.shrink();
    }

    final lastRms = debug?.lastRms ?? 0;
    final noiseFloor = debug?.rmsGate ?? 0.01;
    // Detection threshold is 2x noise floor (matches Rust logic)
    final isDetected = lastRms >= noiseFloor * 2.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDetected
            ? sound.color.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDetected
              ? sound.color.withValues(alpha: 0.3)
              : Colors.white12,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isDetected ? Icons.music_note : Icons.mic,
            color: isDetected ? sound.color : Colors.white38,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isDetected
                ? 'Sound detected! Each distinct ${sound.displayName} will be counted.'
                : 'Waiting for your ${sound.displayName} sound...',
            style: TextStyle(
              color: isDetected ? sound.color : Colors.white54,
              fontSize: 13,
              fontWeight: isDetected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
