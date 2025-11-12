import 'package:flutter/material.dart';
import '../../models/classification_result.dart';
import '../../models/timing_feedback.dart';

/// TimingFeedbackWidget displays timing accuracy with millisecond precision
///
/// Features:
/// - Color-coded display based on timing classification
/// - Shows signed error in milliseconds (+/- format)
/// - Clear visual feedback for training accuracy
/// - Idle state display when no timing data available
///
/// Color scheme:
/// - ON_TIME → Green
/// - EARLY → Amber (yellow)
/// - LATE → Amber (yellow)
/// - Idle state → Gray with "---"
///
/// Display format:
/// - "+12.5ms LATE" for late hits
/// - "-5.0ms EARLY" for early hits
/// - "0.0ms ON-TIME" for perfectly timed hits
///
/// This widget is stateless and takes nullable ClassificationResult to handle
/// both active and idle states.
class TimingFeedbackWidget extends StatelessWidget {
  /// Classification result containing timing data (null for idle state)
  final ClassificationResult? result;

  const TimingFeedbackWidget({
    super.key,
    this.result,
  });

  /// Get color for the given timing classification
  Color _getTimingColor(TimingClassification classification) {
    switch (classification) {
      case TimingClassification.onTime:
        return Colors.green;
      case TimingClassification.early:
      case TimingClassification.late:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Idle state - no timing data available
    if (result == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '---',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    // Active state - display timing feedback
    final timing = result!.timing;
    final timingColor = _getTimingColor(timing.classification);
    final displayText = '${timing.formattedError} ${timing.classification.displayName}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: timingColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
