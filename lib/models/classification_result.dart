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

  const ClassificationResult({
    required this.sound,
    required this.timing,
    required this.timestampMs,
  });

  @override
  String toString() =>
      'ClassificationResult(sound: $sound, timing: $timing, timestampMs: $timestampMs)';
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
