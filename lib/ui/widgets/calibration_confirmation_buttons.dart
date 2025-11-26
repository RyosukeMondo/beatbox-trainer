import 'package:flutter/material.dart';
import '../../models/calibration_progress.dart';

/// Confirmation dialog widget shown after sample collection.
///
/// Displays:
/// - Success icon and message for completed phase
/// - Information about the next phase
/// - OK/Retry buttons for user decision
///
/// Pass callbacks for onRetry and onConfirm to handle user actions.
class CalibrationConfirmationButtons extends StatelessWidget {
  /// Current calibration sound that was just completed
  final CalibrationSound sound;

  /// Callback when user clicks Retry
  final VoidCallback onRetry;

  /// Callback when user clicks OK/Finish
  final VoidCallback onConfirm;

  const CalibrationConfirmationButtons({
    super.key,
    required this.sound,
    required this.onRetry,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final color = sound.color;
    final nextSound = sound.next;
    final isLastSound = nextSound == null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, color: color, size: 48),
          const SizedBox(height: 16),
          Text(
            '${sound.displayName} Complete!',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLastSound
                ? 'All samples collected. Ready to finish calibration?'
                : 'Samples look good? Continue to ${nextSound.displayName} or retry?',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.replay),
                  label: const Text('RETRY'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check),
                  label: Text(isLastSound ? 'FINISH' : 'OK'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
