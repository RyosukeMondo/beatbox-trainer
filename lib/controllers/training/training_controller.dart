import '../../models/classification_result.dart';
import '../../services/audio/i_audio_service.dart';
import '../../services/permission/i_permission_service.dart';
import '../../services/settings/i_settings_service.dart';

/// Training screen business logic controller.
///
/// Handles audio lifecycle, BPM updates, permission requests, and state management.
/// Decoupled from UI for independent testing.
///
/// Example:
/// ```dart
/// final controller = TrainingController(
///   audioService: audioService,
///   permissionService: permissionService,
///   settingsService: settingsService,
/// );
///
/// await controller.startTraining();
/// await controller.updateBpm(140);
/// await controller.stopTraining();
/// ```
class TrainingController {
  final IAudioService _audioService;
  final IPermissionService _permissionService;
  final ISettingsService _settingsService;

  bool _isTraining = false;
  int _currentBpm = 120;

  /// Creates a new TrainingController with required service dependencies.
  ///
  /// All parameters are required to enforce proper dependency injection.
  TrainingController({
    required IAudioService audioService,
    required IPermissionService permissionService,
    required ISettingsService settingsService,
  }) : _audioService = audioService,
       _permissionService = permissionService,
       _settingsService = settingsService;

  /// Current training state.
  ///
  /// Returns true if training session is active, false otherwise.
  bool get isTraining => _isTraining;

  /// Current BPM value.
  ///
  /// Returns the current beats per minute setting (40-240 range).
  int get currentBpm => _currentBpm;

  /// Classification result stream.
  ///
  /// Provides real-time classification results from the audio engine.
  /// Only emits results when training is active.
  Stream<ClassificationResult> get classificationStream =>
      _audioService.getClassificationStream();

  /// Get debug mode setting.
  ///
  /// Returns true if debug mode is enabled, false otherwise.
  Future<bool> getDebugMode() async {
    return await _settingsService.getDebugMode();
  }

  /// Start training session.
  ///
  /// Requests microphone permission if needed, loads BPM from settings,
  /// and starts the audio engine.
  ///
  /// Throws [StateError] if training is already in progress.
  /// Throws [PermissionException] if microphone permission is denied.
  /// Throws [AudioServiceException] if audio engine fails to start.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await controller.startTraining();
  /// } on PermissionException catch (e) {
  ///   // Handle permission denied
  /// } on AudioServiceException catch (e) {
  ///   // Handle audio engine error
  /// }
  /// ```
  Future<void> startTraining() async {
    if (_isTraining) {
      throw StateError('Training already in progress');
    }

    // Request permission if not granted
    final hasPermission = await _requestMicrophonePermission();
    if (!hasPermission) {
      throw PermissionException('Microphone permission denied');
    }

    // Load BPM from settings
    _currentBpm = await _settingsService.getBpm();

    // Start audio engine
    await _audioService.startAudio(bpm: _currentBpm);
    _isTraining = true;
  }

  /// Stop training session.
  ///
  /// Stops the audio engine gracefully. This is a no-op if training
  /// is not currently active.
  ///
  /// Throws [AudioServiceException] if audio engine fails to stop.
  ///
  /// Example:
  /// ```dart
  /// await controller.stopTraining();
  /// ```
  Future<void> stopTraining() async {
    if (!_isTraining) {
      return; // No-op if not training
    }

    await _audioService.stopAudio();
    _isTraining = false;
  }

  /// Update BPM during training.
  ///
  /// Validates BPM range (40-240), updates audio engine if training is active,
  /// and saves the new value to settings.
  ///
  /// Throws [ArgumentError] if BPM is outside valid range.
  /// Throws [AudioServiceException] if audio engine fails to update BPM.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await controller.updateBpm(140);
  /// } on ArgumentError catch (e) {
  ///   // Handle invalid BPM value
  /// }
  /// ```
  Future<void> updateBpm(int newBpm) async {
    if (newBpm < 40 || newBpm > 240) {
      throw ArgumentError('BPM must be between 40 and 240');
    }

    if (_isTraining) {
      await _audioService.setBpm(bpm: newBpm);
    }

    _currentBpm = newBpm;
    await _settingsService.setBpm(newBpm);
  }

  /// Request microphone permission.
  ///
  /// Returns true if permission is granted, false if denied.
  /// Opens app settings if permission is permanently denied.
  Future<bool> _requestMicrophonePermission() async {
    final status = await _permissionService.checkMicrophonePermission();

    if (status == PermissionStatus.granted) {
      return true;
    }

    if (status == PermissionStatus.denied) {
      final newStatus = await _permissionService.requestMicrophonePermission();
      return newStatus == PermissionStatus.granted;
    }

    if (status == PermissionStatus.permanentlyDenied) {
      await _permissionService.openAppSettings();
      return false;
    }

    return false;
  }

  /// Dispose resources.
  ///
  /// Stops training if active and cleans up resources.
  /// Should be called when the controller is no longer needed.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   controller.dispose();
  ///   super.dispose();
  /// }
  /// ```
  Future<void> dispose() async {
    if (_isTraining) {
      await stopTraining();
    }
  }
}

/// Exception thrown when microphone permission is denied.
class PermissionException implements Exception {
  /// User-friendly error message
  final String message;

  const PermissionException(this.message);

  @override
  String toString() => message;
}
