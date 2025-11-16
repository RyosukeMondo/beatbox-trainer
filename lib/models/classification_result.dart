import 'timing_feedback.dart';

/// Classification result combining sound type and timing feedback
///
/// This model represents the result of analyzing a detected beatbox sound,
/// including both the type of sound detected and timing accuracy relative
/// to the metronome grid.
///
/// Matches Rust type: rust/src/analysis/mod.rs::ClassificationResult
class ClassificationResult {
  /// Detected beatbox sound type
  final BeatboxHit sound;

  /// Timing accuracy relative to metronome grid
  final TimingFeedback timing;

  /// Timestamp in milliseconds since engine start
  final int timestampMs;

  /// Classification confidence score (0.0-1.0)
  /// Calculated as max_score / sum_of_all_scores
  final double confidence;

  const ClassificationResult({
    required this.sound,
    required this.timing,
    required this.timestampMs,
    required this.confidence,
  });

  factory ClassificationResult.fromJson(Map<String, dynamic> json) {
    return ClassificationResult(
      sound: BeatboxHitParser.fromLabel(json['sound'] as String? ?? 'unknown'),
      timing: TimingFeedback.fromJson(
        Map<String, dynamic>.from(json['timing'] as Map),
      ),
      timestampMs: json['timestamp_ms'] as int? ?? 0,
      confidence: (json['confidence'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sound': sound.displayName,
      'timing': timing.toJson(),
      'timestamp_ms': timestampMs,
      'confidence': confidence,
    };
  }

  @override
  String toString() =>
      'ClassificationResult(sound: $sound, timing: $timing, timestampMs: $timestampMs, confidence: $confidence)';
}

/// BeatboxHit represents classified beatbox sounds
///
/// Level 1 sounds: kick, snare, hiHat
/// Level 2 adds subcategories: closedHiHat, openHiHat, kSnare
///
/// Matches Rust type: rust/src/analysis/classifier.rs::BeatboxHit
enum BeatboxHit {
  /// Kick drum (low frequency, low ZCR)
  kick,

  /// Snare drum (mid frequency)
  snare,

  /// Hi-hat (high frequency, high ZCR) - Level 1 generic
  hiHat,

  /// Closed hi-hat (short decay) - Level 2
  closedHiHat,

  /// Open hi-hat (long decay) - Level 2
  openHiHat,

  /// K-snare (kick+snare hybrid, noisy kick) - Level 2
  kSnare,

  /// Unknown sound (doesn't match any pattern)
  unknown;

  /// Get human-readable display name
  String get displayName {
    switch (this) {
      case BeatboxHit.kick:
        return 'KICK';
      case BeatboxHit.snare:
        return 'SNARE';
      case BeatboxHit.hiHat:
        return 'HI-HAT';
      case BeatboxHit.closedHiHat:
        return 'CLOSED HI-HAT';
      case BeatboxHit.openHiHat:
        return 'OPEN HI-HAT';
      case BeatboxHit.kSnare:
        return 'K-SNARE';
      case BeatboxHit.unknown:
        return 'UNKNOWN';
    }
  }
}

/// Helper utilities for converting between serialized beatbox hits and enums.
abstract class BeatboxHitParser {
  static BeatboxHit fromLabel(String value) {
    switch (value.toUpperCase()) {
      case 'KICK':
        return BeatboxHit.kick;
      case 'SNARE':
        return BeatboxHit.snare;
      case 'HI-HAT':
      case 'HIHAT':
        return BeatboxHit.hiHat;
      case 'CLOSED HI-HAT':
        return BeatboxHit.closedHiHat;
      case 'OPEN HI-HAT':
        return BeatboxHit.openHiHat;
      case 'K-SNARE':
        return BeatboxHit.kSnare;
      default:
        return BeatboxHit.unknown;
    }
  }
}
