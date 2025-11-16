/// Timing feedback with classification and millisecond error
///
/// Provides detailed timing feedback for display to the user, including
/// the classification (onTime/early/late) and the signed error in milliseconds.
///
/// Matches Rust type: rust/src/analysis/quantizer.rs::TimingFeedback
class TimingFeedback {
  /// Classification of timing accuracy
  final TimingClassification classification;

  /// Timing error in milliseconds
  /// - Positive values indicate late (after beat)
  /// - Negative values indicate early (before beat)
  /// - Zero indicates exactly on beat
  final double errorMs;

  const TimingFeedback({required this.classification, required this.errorMs});

  factory TimingFeedback.fromJson(Map<String, dynamic> json) {
    return TimingFeedback(
      classification: TimingClassificationParser.fromLabel(
        json['classification'] as String? ?? 'onTime',
      ),
      errorMs: (json['error_ms'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'classification': classification.name,
      'error_ms': errorMs,
    };
  }

  /// Format error as string with sign (e.g., "+12.5ms", "-5.0ms", "0.0ms")
  String get formattedError {
    if (errorMs == 0.0) {
      return '0.0ms';
    } else if (errorMs > 0) {
      return '+${errorMs.toStringAsFixed(1)}ms';
    } else {
      return '${errorMs.toStringAsFixed(1)}ms'; // Negative sign already included
    }
  }

  @override
  String toString() =>
      'TimingFeedback(classification: $classification, errorMs: $errorMs)';
}

/// Timing classification for onset accuracy relative to metronome grid
///
/// Determines whether a detected onset is on-time, early, or late relative
/// to the nearest beat boundary.
///
/// Matches Rust type: rust/src/analysis/quantizer.rs::TimingClassification
enum TimingClassification {
  /// Onset is within 50ms of a beat boundary
  onTime,

  /// Onset is too early (more than 50ms before nearest beat, but closer to previous beat)
  early,

  /// Onset is too late (more than 50ms after beat boundary)
  late;

  /// Get human-readable display name
  String get displayName {
    switch (this) {
      case TimingClassification.onTime:
        return 'ON-TIME';
      case TimingClassification.early:
        return 'EARLY';
      case TimingClassification.late:
        return 'LATE';
    }
  }
}

abstract class TimingClassificationParser {
  static TimingClassification fromLabel(String value) {
    switch (value.toLowerCase()) {
      case 'on_time':
      case 'ontime':
        return TimingClassification.onTime;
      case 'early':
        return TimingClassification.early;
      case 'late':
        return TimingClassification.late;
      default:
        return TimingClassification.onTime;
    }
  }
}
