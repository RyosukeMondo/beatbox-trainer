import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/calibration_progress.dart';
import '../../models/calibration_state.dart';
import '../../services/audio/i_audio_service.dart';
import '../../services/error_handler/exceptions.dart';
import '../../services/storage/i_storage_service.dart';

/// Calibration screen business logic controller.
///
/// Handles calibration workflow, progress tracking, and state persistence.
/// Decoupled from UI for independent testing.
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

  /// Value notifier for progress updates (for UI reactivity)
  final ValueNotifier<CalibrationProgress?> progressNotifier =
      ValueNotifier<CalibrationProgress?>(null);

  /// Value notifier for error updates (for UI reactivity)
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);

  /// Value notifier for calibration state (for UI reactivity)
  final ValueNotifier<bool> isCalibratingNotifier = ValueNotifier<bool>(false);

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
  /// Starts the 3-step calibration procedure and subscribes to progress updates.
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
      // Start calibration procedure
      debugPrint(
        '[CalibrationController] Calling audioService.startCalibration()',
      );
      await _audioService.startCalibration();
      debugPrint(
        '[CalibrationController] startCalibration() completed successfully',
      );

      // Subscribe to calibration progress stream
      debugPrint('[CalibrationController] Getting calibration stream');
      final stream = _audioService.getCalibrationStream();
      debugPrint('[CalibrationController] Got calibration stream');

      final subscription = stream.listen(
        _handleProgressUpdate,
        onError: _handleStreamError,
        onDone: _handleStreamDone,
      );
      _progressSubscription = subscription;

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
      final result = await _audioService.finishCalibration();
      debugPrint('[CalibrationController] Calibration finished successfully');

      // Persist calibration state
      final calibrationData = CalibrationData(
        level: result.level,
        timestamp: DateTime.now(),
        thresholds: result.toThresholdMap(),
      );
      await _storageService.saveCalibration(calibrationData);
      debugPrint('[CalibrationController] Calibration state persisted');

      _setCalibrating(false);
      _clearProgress();
    } catch (e) {
      debugPrint('[CalibrationController] Finish calibration error: $e');
      _setError('Failed to finish calibration: $e');
      _setCalibrating(false);
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
    progressNotifier.dispose();
    errorNotifier.dispose();
    isCalibratingNotifier.dispose();
  }

  /// Handle progress update from calibration stream.
  void _handleProgressUpdate(CalibrationProgress progress) {
    debugPrint(
      '[CalibrationController] Progress update: ${progress.currentSound} ${progress.samplesCollected}/${progress.samplesNeeded}',
    );
    _currentProgress = progress;
    progressNotifier.value = progress;

    // Auto-finish when calibration is complete
    if (progress.isCalibrationComplete) {
      debugPrint(
        '[CalibrationController] All samples collected, auto-finishing',
      );
      finishCalibration().catchError((e) {
        debugPrint('[CalibrationController] Auto-finish error: $e');
      });
    }
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
  }
}
