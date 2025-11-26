import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../bridge/api.dart/api.dart' as api;
import '../../bridge/api.dart/api/streams.dart' as streams;
import '../../bridge/api.dart/api/types.dart';
import '../../models/calibration_progress.dart';
import '../../models/calibration_state.dart';
import '../../services/audio/i_audio_service.dart';
import '../../services/error_handler/exceptions.dart';
import '../../services/storage/i_storage_service.dart';

/// Calibration screen business logic controller.
///
/// Handles calibration workflow, progress tracking, audio level monitoring,
/// and state persistence. Decoupled from UI for independent testing.
///
/// Example:
/// ```dart
/// final controller = CalibrationController(
///   audioService: audioService,
///   storageService: storageService,
/// );
///
/// await controller.init();
/// await controller.startCalibration();
/// ```
class CalibrationController {
  final IAudioService _audioService;
  final IStorageService _storageService;

  /// Current calibration progress (null when not started)
  CalibrationProgress? _currentProgress;

  /// Whether calibration is currently active
  bool _isCalibrating = false;

  /// Error message (null if no error)
  String? _errorMessage;

  /// Stream subscription for progress updates
  StreamSubscription<CalibrationProgress>? _progressSubscription;

  /// Stream subscription for audio metrics (level meter)
  StreamSubscription<AudioMetrics>? _audioMetricsSubscription;

  /// Value notifier for progress updates (for UI reactivity)
  final ValueNotifier<CalibrationProgress?> progressNotifier =
      ValueNotifier<CalibrationProgress?>(null);

  /// Value notifier for error updates (for UI reactivity)
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);

  /// Value notifier for lightweight guidance hints shown in UI
  final ValueNotifier<String?> guidanceNotifier = ValueNotifier<String?>(null);

  /// Value notifier for calibration state (for UI reactivity)
  final ValueNotifier<bool> isCalibratingNotifier = ValueNotifier<bool>(false);

  /// Whether manual accept is available for the current sound
  final ValueNotifier<bool> manualAcceptAvailableNotifier = ValueNotifier<bool>(
    false,
  );

  /// Value notifier for audio level (RMS) for live level meter
  final ValueNotifier<double> audioLevelNotifier = ValueNotifier<double>(0.0);

  /// Value notifier for "sample just collected" animation trigger
  final ValueNotifier<int> sampleCollectedNotifier = ValueNotifier<int>(0);

  /// Creates a new CalibrationController with required service dependencies.
  ///
  /// All parameters are required to enforce proper dependency injection.
  CalibrationController({
    required IAudioService audioService,
    required IStorageService storageService,
  }) : _audioService = audioService,
       _storageService = storageService;

  /// Current calibration progress.
  CalibrationProgress? get currentProgress => _currentProgress;

  /// Whether calibration is currently active.
  bool get isCalibrating => _isCalibrating;

  /// Current error message (null if no error).
  String? get errorMessage => _errorMessage;

  /// Initialize storage service.
  ///
  /// Must be called before starting calibration.
  /// Throws exception if storage initialization fails.
  Future<void> init() async {
    debugPrint('[CalibrationController] Initializing storage service');
    try {
      await _storageService.init();
      debugPrint('[CalibrationController] Storage service initialized');
    } catch (e, stackTrace) {
      debugPrint('[CalibrationController] Storage init error: $e');
      debugPrint('[CalibrationController] Stack trace: $stackTrace');
      _setError('Failed to initialize storage: $e');
      rethrow;
    }
  }

  /// Start calibration workflow.
  ///
  /// Starts the 4-step calibration procedure and subscribes to progress updates.
  /// Steps: NoiseFloor → Kick → Snare → HiHat
  /// Also subscribes to audio metrics stream for live level meter display.
  /// Throws [CalibrationServiceException] if calibration fails to start.
  /// Throws [AudioServiceException] if audio engine errors occur.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await controller.startCalibration();
  /// } on CalibrationServiceException catch (e) {
  ///   // Handle calibration error
  /// } on AudioServiceException catch (e) {
  ///   // Handle audio error
  /// }
  /// ```
  Future<void> startCalibration() async {
    debugPrint('[CalibrationController] Starting calibration...');
    try {
      // Start calibration procedure first
      debugPrint(
        '[CalibrationController] Calling audioService.startCalibration()',
      );
      await _audioService.startCalibration();
      debugPrint(
        '[CalibrationController] startCalibration() completed successfully',
      );

      // Set initial progress immediately (NoiseFloor, 0 samples)
      // This ensures UI shows calibration interface right away
      // Note: noise floor collects 30 samples in Rust, but we show it as 30
      // to indicate automatic progress during silence
      _currentProgress = CalibrationProgress(
        currentSound: CalibrationSound.noiseFloor,
        samplesCollected: 0,
        samplesNeeded: 30,
      );
      progressNotifier.value = _currentProgress;
      manualAcceptAvailableNotifier.value =
          _currentProgress?.manualAcceptAvailable ?? false;
      guidanceNotifier.value = null;

      // Now subscribe to calibration progress stream
      debugPrint('[CalibrationController] Getting calibration stream');
      final stream = _audioService.getCalibrationStream();
      debugPrint('[CalibrationController] Got calibration stream');

      final subscription = stream.listen(
        _handleProgressUpdate,
        onError: _handleStreamError,
        onDone: _handleStreamDone,
      );
      _progressSubscription = subscription;

      // Subscribe to audio metrics stream for live level meter
      debugPrint('[CalibrationController] Subscribing to audio metrics stream');
      try {
        _audioMetricsSubscription = streams.audioMetricsStream().listen(
          _handleAudioMetrics,
          onError: (e) =>
              debugPrint('[CalibrationController] Audio metrics error: $e'),
        );
      } catch (e) {
        debugPrint(
          '[CalibrationController] Audio metrics stream unavailable: $e',
        );
      }

      _setCalibrating(true);
      _clearError();
      debugPrint('[CalibrationController] Calibration started');
    } on CalibrationServiceException catch (e) {
      debugPrint(
        '[CalibrationController] CalibrationServiceException: ${e.message}',
      );
      debugPrint('[CalibrationController] Error code: ${e.errorCode}');
      _setError(e.message);
      _setCalibrating(false);
      rethrow;
    } on AudioServiceException catch (e) {
      debugPrint('[CalibrationController] AudioServiceException: ${e.message}');
      debugPrint('[CalibrationController] Error code: ${e.errorCode}');
      _setError(e.message);
      _setCalibrating(false);
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[CalibrationController] Unexpected error: $e');
      debugPrint('[CalibrationController] Stack trace: $stackTrace');
      _setError('Unexpected error: $e');
      _setCalibrating(false);
      rethrow;
    }
  }

  /// Handle audio metrics for live level meter.
  void _handleAudioMetrics(AudioMetrics metrics) {
    // RMS is typically 0.0-1.0, convert to dB-like scale for display
    // Clamp and normalize for UI display
    final level = (metrics.rms * 2.0).clamp(0.0, 1.0);
    audioLevelNotifier.value = level;
  }

  /// Finish calibration and persist calibration state.
  ///
  /// Completes the calibration workflow and saves thresholds to storage.
  /// Automatically called when all samples are collected.
  ///
  /// Throws [CalibrationServiceException] if calibration finish fails.
  /// Throws [StorageException] if persistence fails.
  Future<void> finishCalibration() async {
    debugPrint('[CalibrationController] Finishing calibration...');
    try {
      await _audioService.finishCalibration();
      debugPrint('[CalibrationController] Calibration finished successfully');

      // Get calibration state from bridge
      final stateJson = await api.getCalibrationState();
      final state = CalibrationState.fromJson(
        jsonDecode(stateJson) as Map<String, dynamic>,
      );

      // Persist calibration state
      await _persistCalibrationState(state);

      _setCalibrating(false);
      _clearProgress();
    } catch (e) {
      debugPrint('[CalibrationController] Finish calibration error: $e');
      _setError('Failed to finish calibration: $e');
      _setCalibrating(false);
      rethrow;
    }
  }

  /// User confirms current calibration step is OK and advances to next sound.
  ///
  /// Called when user clicks "OK" after reviewing collected samples.
  /// Emits progress update via stream to update UI.
  ///
  /// Returns true if advanced to next sound, false if calibration complete.
  Future<bool> confirmStep() async {
    debugPrint('[CalibrationController] Confirming current step...');
    try {
      final hasNext = await api.confirmCalibrationStep();
      debugPrint('[CalibrationController] Step confirmed, hasNext: $hasNext');
      if (!hasNext) {
        // Calibration is complete - auto-finish
        debugPrint(
          '[CalibrationController] Calibration complete, finishing...',
        );
        await finishCalibration();
      }
      return hasNext;
    } catch (e) {
      debugPrint('[CalibrationController] Confirm step error: $e');
      _setError('Failed to confirm step: $e');
      rethrow;
    }
  }

  /// User wants to retry the current calibration step.
  ///
  /// Called when user clicks "Retry" to redo sample collection.
  /// Clears collected samples and allows re-collection.
  Future<void> retryStep() async {
    debugPrint('[CalibrationController] Retrying current step...');
    try {
      await api.retryCalibrationStep();
      debugPrint('[CalibrationController] Step retried, ready for new samples');
    } catch (e) {
      debugPrint('[CalibrationController] Retry step error: $e');
      _setError('Failed to retry step: $e');
      rethrow;
    }
  }

  /// Cancel calibration workflow.
  ///
  /// Stops the current calibration session without saving.
  /// Safe to call even if calibration is not active.
  Future<void> cancelCalibration() async {
    debugPrint('[CalibrationController] Cancelling calibration...');
    try {
      if (_isCalibrating) {
        // Ignore errors during cancel cleanup
        try {
          await _audioService.finishCalibration();
        } catch (e) {
          debugPrint('[CalibrationController] Error during cancel cleanup: $e');
        }
      }
    } finally {
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      _setCalibrating(false);
      _clearProgress();
      debugPrint('[CalibrationController] Calibration cancelled');
    }
  }

  /// Dispose controller resources.
  ///
  /// Cancels any active subscriptions and cleans up.
  /// Should be called when the controller is no longer needed.
  Future<void> dispose() async {
    debugPrint('[CalibrationController] Disposing controller');
    await cancelCalibration();
    await _audioMetricsSubscription?.cancel();
    _audioMetricsSubscription = null;
    progressNotifier.dispose();
    errorNotifier.dispose();
    guidanceNotifier.dispose();
    isCalibratingNotifier.dispose();
    audioLevelNotifier.dispose();
    sampleCollectedNotifier.dispose();
    manualAcceptAvailableNotifier.dispose();
  }

  /// Handle progress update from calibration stream.
  void _handleProgressUpdate(CalibrationProgress progress) {
    debugPrint(
      '[CalibrationController] Progress update: ${progress.currentSound} '
      '${progress.samplesCollected}/${progress.samplesNeeded} '
      '(waitingForConfirmation: ${progress.waitingForConfirmation})',
    );

    // Trigger sample collected animation when samples increase
    final previousSamples = _currentProgress?.samplesCollected ?? 0;
    if (progress.samplesCollected > previousSamples) {
      sampleCollectedNotifier.value++;
    }

    _currentProgress = progress;
    progressNotifier.value = progress;
    manualAcceptAvailableNotifier.value = progress.manualAcceptAvailable;
    guidanceNotifier.value = _guidanceMessage(progress.guidance);

    // Note: No auto-finish - user must explicitly confirm each step via OK button
    // This allows user to review and retry if needed
  }

  /// Handle stream error.
  void _handleStreamError(dynamic error) {
    debugPrint('[CalibrationController] Stream error: $error');
    _setError('Calibration stream error: $error');
    _setCalibrating(false);
  }

  /// Handle stream completion.
  void _handleStreamDone() {
    debugPrint('[CalibrationController] Stream completed');
    _setCalibrating(false);
  }

  /// Persist calibration state to storage.
  Future<void> _persistCalibrationState(CalibrationState state) async {
    try {
      debugPrint('[CalibrationController] Persisting calibration state');
      // Convert CalibrationState to CalibrationData for storage
      final calibrationData = CalibrationData(
        level: state.level,
        timestamp: DateTime.now(),
        thresholds: state.toThresholdMap(),
      );
      await _storageService.saveCalibration(calibrationData);
      debugPrint(
        '[CalibrationController] Calibration state saved successfully',
      );
    } catch (e) {
      debugPrint('[CalibrationController] Failed to persist state: $e');
      throw Exception('Failed to save calibration: $e');
    }
  }

  /// Set calibration state.
  void _setCalibrating(bool value) {
    _isCalibrating = value;
    isCalibratingNotifier.value = value;
  }

  /// Set error message.
  void _setError(String message) {
    _errorMessage = message;
    errorNotifier.value = message;
  }

  /// Clear error message.
  void _clearError() {
    _errorMessage = null;
    errorNotifier.value = null;
  }

  /// Clear progress.
  void _clearProgress() {
    _currentProgress = null;
    progressNotifier.value = null;
    guidanceNotifier.value = null;
    manualAcceptAvailableNotifier.value = false;
  }

  /// Map guidance payload to user-facing banner copy.
  String? _guidanceMessage(CalibrationGuidance? guidance) {
    if (guidance == null) return null;
    final soundName = guidance.sound.displayName;
    switch (guidance.reason) {
      case CalibrationGuidanceReason.tooQuiet:
        return 'We hear something, but $soundName is too quiet. Get closer to the mic or project a bit more.';
      case CalibrationGuidanceReason.clipped:
        return '$soundName is clipping. Back off the mic slightly or reduce volume.';
      case CalibrationGuidanceReason.stagnation:
        return 'We hear $soundName attempts, but none counted. Try a sharper attack with short pauses.';
    }
  }

  /// Manually count the last buffered calibration hit.
  Future<CalibrationProgress> manualAcceptLastCandidate() async {
    try {
      final progress = await _audioService.manualAcceptLastCandidate();
      _currentProgress = progress;
      progressNotifier.value = progress;
      manualAcceptAvailableNotifier.value = progress.manualAcceptAvailable;
      guidanceNotifier.value = _guidanceMessage(progress.guidance);
      sampleCollectedNotifier.value++;
      return progress;
    } catch (e) {
      debugPrint('[CalibrationController] Manual accept failed: $e');
      rethrow;
    }
  }
}
