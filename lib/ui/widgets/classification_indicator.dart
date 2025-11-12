import 'package:flutter/material.dart';
import '../../models/classification_result.dart';

/// ClassificationIndicator displays the detected beatbox sound type
///
/// Features:
/// - Color-coded display based on sound type
/// - Large, readable text for quick visual feedback
/// - Idle state display when no classification available
///
/// Color scheme:
/// - KICK → Red
/// - SNARE → Blue
/// - HI-HAT (all variants) → Green
/// - K-SNARE → Purple
/// - UNKNOWN → Gray
/// - Idle state → Gray with "---"
///
/// This widget is stateless and takes nullable ClassificationResult to handle
/// both active and idle states.
class ClassificationIndicator extends StatelessWidget {
  /// Classification result to display (null for idle state)
  final ClassificationResult? result;

  const ClassificationIndicator({
    super.key,
    this.result,
  });

  /// Get color for the given beatbox sound type
  Color _getSoundColor(BeatboxHit sound) {
    switch (sound) {
      case BeatboxHit.kick:
        return Colors.red;
      case BeatboxHit.snare:
        return Colors.blue;
      case BeatboxHit.hiHat:
      case BeatboxHit.closedHiHat:
      case BeatboxHit.openHiHat:
        return Colors.green;
      case BeatboxHit.kSnare:
        return Colors.purple;
      case BeatboxHit.unknown:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Idle state - no classification result available
    if (result == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          '---',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    // Active state - display classification result
    final soundColor = _getSoundColor(result!.sound);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: soundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        result!.sound.displayName,
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
