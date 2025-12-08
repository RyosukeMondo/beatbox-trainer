import '../../models/calibration_progress.dart';
import '../../models/classification_result.dart';
import '../../models/telemetry_event.dart';
import 'telemetry_stream.dart';

/// Audio service interface for dependency injection and testing.
///
/// This interface abstracts audio engine operations and calibration workflow,
/// enabling dependency injection in screens and mocking in tests.
///
/// All methods delegate to the Rust FFI bridge (lib/bridge/api.dart).
abstract class IAudioService {
  /// Start audio engine with specified BPM.
  ///
  /// Starts the audio input stream for microphone capture, audio output stream
  /// for metronome playback, and analysis thread for real-time classification.
  ///
  /// Parameters:
  /// - [bpm]: Beats per minute for metronome (valid range: 40-240)
  ///
  /// Throws:
  /// - [AudioServiceException] if BPM is invalid (outside 40-240 range)
  /// - [AudioServiceException] if audio engine is already running
  /// - [AudioServiceException] if hardware error occurs (device unavailable)
  /// - [AudioServiceException] if permission denied (microphone not granted)
  /// - [AudioServiceException] if stream fails to open
  ///
  /// Example:
  /// ```dart
  /// await audioService.startAudio(bpm: 120);
  /// ```
  Future<void> startAudio({required int bpm});

  /// Stop audio engine.
  ///
  /// Gracefully stops audio streams and analysis thread. Safe to call
  /// even if audio engine is not running (no-op in that case).
  ///
  /// Example:
  /// ```dart
  /// await audioService.stopAudio();
  /// ```
  Future<void> stopAudio();

  /// Set BPM dynamically during audio playback.
  ///
  /// Updates metronome tempo without stopping/restarting the audio engine.
  /// Must be called while audio engine is running.
  ///
  /// Parameters:
  /// - [bpm]: New beats per minute for metronome (valid range: 40-240)
  ///
  /// Throws:
  /// - [AudioServiceException] if BPM is invalid (outside 40-240 range)
  /// - [AudioServiceException] if audio engine is not running
  ///
  /// Example:
  /// ```dart
  /// await audioService.setBpm(bpm: 140);
  /// ```
  Future<void> setBpm({required int bpm});

  /// Stream of real-time classification results.
  ///
  /// Emits [ClassificationResult] for each detected beatbox sound, including
  /// sound type identification and timing feedback relative to metronome grid.
  ///
  /// Stream is active while audio engine is running. Automatically closes
  /// when audio engine stops.
  ///
  /// Returns:
  /// - Stream of [ClassificationResult] objects
  ///
  /// Example:
  /// ```dart
  /// audioService.getClassificationStream().listen((result) {
  ///   print('Detected: ${result.sound}, Timing: ${result.timing}');
  /// });
  /// ```
  Stream<ClassificationResult> getClassificationStream();

  /// Stream of telemetry events emitted by the Rust engine.
  ///
  /// Consumers can subscribe to receive engine start/stop notifications,
  /// BPM adjustments, and warning signals for debug overlays.
  Stream<TelemetryEvent> getTelemetryStream();

  /// Stream of detailed diagnostic metrics used by the harness tooling.
  ///
  /// Exposes latency samples, buffer occupancy gauges, and JNI lifecycle
  /// events for automated tests and developer overlays.
  Stream<DiagnosticMetric> getDiagnosticMetricsStream();

  /// Start calibration workflow.
  ///
  /// Begins the 3-step calibration process to learn user's beatbox sounds:
  /// 1. Collect 10 kick drum samples
  /// 2. Collect 10 snare drum samples
  /// 3. Collect 10 hi-hat samples
  ///
  /// Must be called while audio engine is running. Use [getCalibrationStream]
  /// to receive progress updates.
  ///
  /// Throws:
  /// - [CalibrationServiceException] if calibration is already in progress
  /// - [AudioServiceException] if audio engine is not running
  ///
  /// Example:
  /// ```dart
  /// await audioService.startCalibration();
  /// ```
  Future<void> startCalibration();

  /// Finish calibration and compute classification thresholds.
  ///
  /// Completes calibration workflow by computing feature thresholds from
  /// collected samples and training the classifier. After this call,
  /// classification results will reflect the user's calibrated beatbox sounds.
  ///
  /// Throws:
  /// - [CalibrationServiceException] if insufficient samples collected (< 10 per sound)
  /// - [CalibrationServiceException] if feature extraction fails (invalid audio data)
  /// - [CalibrationServiceException] if calibration is not in progress
  ///
  /// Example:
  /// ```dart
  /// await audioService.finishCalibration();
  /// ```
  Future<void> finishCalibration();

  /// Stream of calibration progress updates.
  ///
  /// Emits [CalibrationProgress] after each sample is collected, showing
  /// current sound being calibrated and sample count.
  ///
  /// Stream is active during calibration workflow. Automatically closes
  /// when calibration completes or is cancelled.
  ///
  /// Returns:
  /// - Stream of [CalibrationProgress] objects
  ///
  /// Example:
  /// ```dart
  /// audioService.getCalibrationStream().listen((progress) {
  ///   print('${progress.currentSound}: ${progress.samplesCollected}/${progress.samplesNeeded}');
  /// });
  /// ```
  Stream<CalibrationProgress> getCalibrationStream();

  /// Manually accept the last buffered calibration candidate.
  ///
  /// Returns updated [CalibrationProgress] when successful.
  Future<CalibrationProgress> manualAcceptLastCandidate();

  /// Apply parameter overrides to the running engine.
  ///
  /// Parameters are optional but at least one must be provided.
  /// Throws [AudioServiceException] when the command queue rejects the patch.
  Future<void> applyParamPatch({
    int? bpm,
    double? centroidThreshold,
    double? zcrThreshold,
  });

  /// Load calibration state from JSON into the Rust engine.
  ///
  /// Restores previously saved calibration thresholds so the classifier
  /// can detect sounds correctly. Must be called before startAudio when
  /// restoring from saved calibration.
  ///
  /// Parameters:
  /// - [json]: JSON string containing serialized CalibrationState
  ///
  /// Throws:
  /// - [CalibrationServiceException] if JSON is invalid or parsing fails
  ///
  /// Example:
  /// ```dart
  /// final calibData = await storageService.loadCalibration();
  /// if (calibData != null) {
  ///   await audioService.loadCalibrationState(jsonEncode(calibData.toRustJson()));
  /// }
  /// await audioService.startAudio(bpm: 120);
  /// ```
  Future<void> loadCalibrationState(String json);

  /// Update a single calibration threshold value.
  ///
  /// Enables manual threshold tweaking for debugging without full recalibration.
  ///
  /// Parameters:
  /// - [key]: Threshold key (t_kick_centroid, t_kick_zcr, t_snare_centroid,
  ///   t_hihat_zcr, noise_floor_rms)
  /// - [value]: New threshold value
  ///
  /// Throws:
  /// - [CalibrationServiceException] if key is invalid
  Future<void> updateCalibrationThreshold(String key, double value);

  /// Get current calibration state as JSON string.
  ///
  /// Returns the active calibration parameters for display/debugging.
  Future<String> getCalibrationState();

  /// Reset calibration session (clears in-progress state and stops audio).
  Future<void> resetCalibrationSession();
}
