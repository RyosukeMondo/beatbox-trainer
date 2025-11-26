import 'package:flutter/material.dart';

/// Reasons for engine-provided guidance during calibration
enum CalibrationGuidanceReason { stagnation, tooQuiet, clipped }

/// Guidance payload accompanying calibration progress updates
class CalibrationGuidance {
  /// Sound currently being calibrated
  final CalibrationSound sound;

  /// Guidance reason emitted by the engine
  final CalibrationGuidanceReason reason;

  /// RMS/level observed when guidance was generated
  final double level;

  /// Number of consecutive misses triggering guidance
  final int misses;

  const CalibrationGuidance({
    required this.sound,
    required this.reason,
    required this.level,
    required this.misses,
  });
}

/// Progress information for the current calibration step
///
/// Tracks progress through the 4-step calibration workflow:
/// 1. Measure ambient noise floor (user stays quiet)
/// 2. Collect 10 kick drum samples
/// 3. Collect 10 snare drum samples
/// 4. Collect 10 hi-hat samples
///
/// Matches Rust type: rust/src/calibration/procedure.rs::CalibrationProgress
class CalibrationProgress {
  /// Current sound being calibrated
  final CalibrationSound currentSound;

  /// Number of samples collected for current sound (0-10)
  final int samplesCollected;

  /// Total samples needed per sound
  final int samplesNeeded;

  /// Whether waiting for user confirmation to proceed to next phase
  final bool waitingForConfirmation;

  /// Optional guidance hint from the engine
  final CalibrationGuidance? guidance;

  /// Whether a buffered candidate is available for manual acceptance
  final bool manualAcceptAvailable;

  /// Debug info about the current gates (for user feedback/instrumentation)
  final CalibrationProgressDebug? debug;

  const CalibrationProgress({
    required this.currentSound,
    required this.samplesCollected,
    required this.samplesNeeded,
    this.waitingForConfirmation = false,
    this.guidance,
    this.manualAcceptAvailable = false,
    this.debug,
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

/// Debug payload for current gates and reject counters
class CalibrationProgressDebug {
  /// Current RMS gate (null if not applicable)
  final double? rmsGate;

  /// Current centroid gate min/max
  final double centroidMin;
  final double centroidMax;

  /// Current ZCR gate min/max
  final double zcrMin;
  final double zcrMax;

  /// Consecutive misses for the active sound
  final int misses;

  /// Last evaluated centroid (if available)
  final double? lastCentroid;

  /// Last evaluated ZCR (if available)
  final double? lastZcr;

  /// Last evaluated RMS (if available)
  final double? lastRms;

  /// Last evaluated max amplitude (if available)
  final double? lastMaxAmp;

  const CalibrationProgressDebug({
    required this.seq,
    required this.rmsGate,
    required this.centroidMin,
    required this.centroidMax,
    required this.zcrMin,
    required this.zcrMax,
    required this.misses,
    this.lastCentroid,
    this.lastZcr,
    this.lastRms,
    this.lastMaxAmp,
  });

  /// Sequence counter to force UI updates
  final int seq;
}

/// Sound type being calibrated
///
/// DESIGN NOTE: This enum mirrors the Rust CalibrationSound (rust/src/calibration/progress.rs)
/// and the FRB-generated type (lib/bridge/api.dart/calibration/progress.dart).
///
/// We use a separate Dart enum with extensions rather than the FRB type because:
/// 1. Anti-Corruption Layer: Shields UI from FFI implementation details
/// 2. Extension support: Dart extensions add displayName, next, color, icon etc.
/// 3. Compile-time safety: The mapping in audio_service_impl.dart fails if variants mismatch
///
/// The mapping layer is in: lib/services/audio/audio_service_impl.dart::_mapFfiToModelCalibrationSound
enum CalibrationSound {
  /// Step 1: Measuring ambient noise level (user should stay quiet)
  noiseFloor,

  /// Kick drum - low frequency sound
  kick,

  /// Snare drum - mid frequency sound
  snare,

  /// Hi-hat - high frequency sound
  hiHat;

  /// Get human-readable display name for UI instructions
  String get displayName {
    switch (this) {
      case CalibrationSound.noiseFloor:
        return 'NOISE FLOOR';
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
      case CalibrationSound.noiseFloor:
        return CalibrationSound.kick;
      case CalibrationSound.kick:
        return CalibrationSound.snare;
      case CalibrationSound.snare:
        return CalibrationSound.hiHat;
      case CalibrationSound.hiHat:
        return null;
    }
  }

  /// Check if this is a sound collection phase (not noise floor)
  bool get isSoundPhase => this != CalibrationSound.noiseFloor;
}

/// UI-specific extensions for CalibrationSound
///
/// Separates UI concerns from model data following SSOT principle.
/// Import 'package:flutter/material.dart' to use these extensions.
extension CalibrationSoundUI on CalibrationSound {
  /// Color associated with this sound type for UI display
  Color get color {
    switch (this) {
      case CalibrationSound.noiseFloor:
        return const Color(0xFF9B9B9B); // Gray for quiet phase
      case CalibrationSound.kick:
        return const Color(0xFFFF6B6B); // Red
      case CalibrationSound.snare:
        return const Color(0xFF4ECDC4); // Teal
      case CalibrationSound.hiHat:
        return const Color(0xFFFFE66D); // Yellow
    }
  }

  /// Icon representing this sound type
  IconData get icon {
    switch (this) {
      case CalibrationSound.noiseFloor:
        return Icons.hearing; // Listening icon for noise floor
      case CalibrationSound.kick:
        return Icons.speaker; // Bass
      case CalibrationSound.snare:
        return Icons.graphic_eq; // Mid
      case CalibrationSound.hiHat:
        return Icons.air; // High/crisp
    }
  }

  /// Instruction text explaining how to make this sound
  String get instructionText {
    switch (this) {
      case CalibrationSound.noiseFloor:
        return 'Please stay quiet while we measure ambient noise';
      case CalibrationSound.kick:
        return 'A deep, bass-heavy sound from your chest';
      case CalibrationSound.snare:
        return 'A sharp, punchy sound with your tongue';
      case CalibrationSound.hiHat:
        return 'A crisp, high-frequency sound through your teeth';
    }
  }

  /// Phonetic hint showing how to vocalize this sound
  String get phoneticHint {
    switch (this) {
      case CalibrationSound.noiseFloor:
        return '🤫 Stay Silent';
      case CalibrationSound.kick:
        return '"B" or "Boom"';
      case CalibrationSound.snare:
        return '"Psh" or "Ka"';
      case CalibrationSound.hiHat:
        return '"Ts" or "Tss"';
    }
  }

  /// Helpful tip for better sample collection
  String get tipText {
    switch (this) {
      case CalibrationSound.noiseFloor:
        return 'This helps us distinguish your beatbox sounds from background noise. Stay as quiet as possible.';
      case CalibrationSound.kick:
        return 'Keep the microphone 6-12 inches away. Make each sound clearly and distinctly.';
      case CalibrationSound.snare:
        return 'Try to make each sound at a consistent volume. The level meter helps you stay in the optimal range.';
      case CalibrationSound.hiHat:
        return 'Almost done! Make sure each hi-hat sound is crisp and distinct from the other sounds.';
    }
  }
}
