/// Progress information for the current calibration step
///
/// Tracks progress through the 3-step calibration workflow:
/// 1. Collect 10 kick drum samples
/// 2. Collect 10 snare drum samples
/// 3. Collect 10 hi-hat samples
///
/// Matches Rust type: rust/src/calibration/procedure.rs::CalibrationProgress
class CalibrationProgress {
  /// Current sound being calibrated
  final CalibrationSound currentSound;

  /// Number of samples collected for current sound (0-10)
  final int samplesCollected;

  /// Total samples needed per sound
  final int samplesNeeded;

  const CalibrationProgress({
    required this.currentSound,
    required this.samplesCollected,
    required this.samplesNeeded,
  });

  /// Check if current sound is complete
  bool get isSoundComplete => samplesCollected >= samplesNeeded;

  /// Check if entire calibration is complete
  bool get isCalibrationComplete =>
      isSoundComplete && currentSound == CalibrationSound.hiHat;

  /// Get progress as a fraction (0.0 to 1.0) for the current sound
  double get progressFraction => samplesCollected / samplesNeeded;

  /// Get overall progress as a fraction (0.0 to 1.0) across all 3 sounds
  double get overallProgressFraction {
    final soundIndex = currentSound.index;
    final totalSounds = CalibrationSound.values.length;
    final completedSounds = soundIndex;
    final currentSoundProgress = progressFraction;

    return (completedSounds + currentSoundProgress) / totalSounds;
  }

  @override
  String toString() =>
      'CalibrationProgress(sound: $currentSound, collected: $samplesCollected/$samplesNeeded)';
}

/// Sound type being calibrated
///
/// Matches Rust type: rust/src/calibration/procedure.rs::CalibrationSound
enum CalibrationSound {
  /// Kick drum - low frequency sound
  kick,

  /// Snare drum - mid frequency sound
  snare,

  /// Hi-hat - high frequency sound
  hiHat;

  /// Get human-readable display name for UI instructions
  String get displayName {
    switch (this) {
      case CalibrationSound.kick:
        return 'KICK';
      case CalibrationSound.snare:
        return 'SNARE';
      case CalibrationSound.hiHat:
        return 'HI-HAT';
    }
  }

  /// Get the next sound in the calibration sequence
  ///
  /// Returns null if this is the last sound (hiHat)
  CalibrationSound? get next {
    switch (this) {
      case CalibrationSound.kick:
        return CalibrationSound.snare;
      case CalibrationSound.snare:
        return CalibrationSound.hiHat;
      case CalibrationSound.hiHat:
        return null;
    }
  }
}
