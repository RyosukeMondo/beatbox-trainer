import 'package:flutter/material.dart';
import '../../models/classification_result.dart';
import '../../models/timing_feedback.dart';

/// Display formatting utilities for UI components
///
/// Provides centralized, pure functions for formatting BPM values,
/// timing errors, and color mappings for beatbox sounds and timing.
class DisplayFormatters {
  DisplayFormatters._(); // Private constructor to prevent instantiation

  /// Format BPM value as display string
  ///
  /// Examples:
  /// - formatBpm(120) → "120 BPM"
  /// - formatBpm(60) → "60 BPM"
  static String formatBpm(int bpm) {
    return '$bpm BPM';
  }

  /// Format timing error with sign (e.g., "+12.5ms", "-5.0ms", "0.0ms")
  ///
  /// - Positive values indicate late (after beat)
  /// - Negative values indicate early (before beat)
  /// - Zero indicates exactly on beat
  static String formatTimingError(double errorMs) {
    if (errorMs == 0.0) {
      return '0.0ms';
    } else if (errorMs > 0) {
      return '+${errorMs.toStringAsFixed(1)}ms';
    } else {
      return '${errorMs.toStringAsFixed(1)}ms'; // Negative sign already included
    }
  }

  /// Get color for beatbox sound type
  ///
  /// Color scheme:
  /// - Kick: Red (low frequency)
  /// - Snare: Blue (mid frequency)
  /// - Hi-hats: Green (high frequency)
  /// - K-Snare: Purple (hybrid)
  /// - Unknown: Grey
  static Color getSoundColor(BeatboxHit sound) {
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

  /// Get color for timing classification
  ///
  /// Color scheme:
  /// - On-time: Green (good)
  /// - Early/Late: Amber (needs improvement)
  static Color getTimingColor(TimingClassification classification) {
    switch (classification) {
      case TimingClassification.onTime:
        return Colors.green;
      case TimingClassification.early:
      case TimingClassification.late:
        return Colors.amber;
    }
  }
}
