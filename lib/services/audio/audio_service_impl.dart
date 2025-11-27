import 'package:flutter/foundation.dart';
import '../../models/calibration_progress.dart';
import '../../models/classification_result.dart';
import '../../models/telemetry_event.dart';
import '../../models/timing_feedback.dart';
import '../../bridge/api.dart/api.dart' as api;
import '../../bridge/api.dart/api/streams.dart' as api_streams;
import '../../bridge/api.dart/analysis.dart' as ffi_analysis;
import '../../bridge/api.dart/analysis/classifier.dart' as ffi_classifier;
import '../../bridge/api.dart/analysis/quantizer.dart' as ffi_quantizer;
import '../../bridge/api.dart/calibration/progress.dart' as ffi_calibration;
import '../../bridge/api.dart/engine/core.dart' as ffi_engine;
import '../../bridge/extensions/error_code_extensions.dart';
import '../error_handler/error_handler.dart';
import '../error_handler/exceptions.dart';
import 'i_audio_service.dart';
import 'telemetry_stream.dart';

/// Concrete implementation of [IAudioService] wrapping FFI bridge
///
/// This implementation provides a Dart service layer over the Rust FFI bridge,
/// adding input validation and error translation for user-friendly error messages.
///
/// All methods delegate to the FFI bridge (lib/bridge/api.dart) and translate
/// Rust errors to [AudioServiceException] or [CalibrationServiceException].
class AudioServiceImpl implements IAudioService {
  /// Error handler for translating Rust errors to user-friendly messages
  final ErrorHandler _errorHandler;

  /// Create a new AudioServiceImpl instance
  ///
  /// Parameters:
  /// - [errorHandler]: Optional error handler for dependency injection.
  ///   Defaults to a new [ErrorHandler] instance.
  AudioServiceImpl({ErrorHandler? errorHandler})
    : _errorHandler = errorHandler ?? ErrorHandler();

  /// Valid BPM range (40-240)
  static const int minBpm = 40;
  static const int maxBpm = 240;

  /// Validate BPM is within acceptable range
  ///
  /// Throws [AudioServiceException] if BPM is outside 40-240 range.
  void _validateBpm(int bpm) {
    if (bpm < minBpm || bpm > maxBpm) {
      throw AudioServiceException(
        message: 'Please choose a tempo between $minBpm and $maxBpm BPM.',
        originalError: 'BPM validation failed: $bpm outside [$minBpm, $maxBpm]',
        errorCode: 1001, // BpmInvalid error code
      );
    }
  }

  @override
  Future<void> startAudio({required int bpm}) async {
    debugPrint('[AudioServiceImpl] startAudio called with bpm=$bpm');
    // Validate BPM before making FFI call
    _validateBpm(bpm);

    try {
      // Delegate to FFI bridge
      await api.startAudio(bpm: bpm);
      debugPrint('[AudioServiceImpl] startAudio completed successfully');
    } catch (e) {
      debugPrint('[AudioServiceImpl] startAudio error: $e');
      // Translate Rust error to user-friendly exception
      throw _errorHandler.createAudioException(e.toString());
    }
  }

  @override
  Future<void> stopAudio() async {
    try {
      // Delegate to FFI bridge
      await api.stopAudio();
    } catch (e) {
      // Translate Rust error to user-friendly exception
      throw _errorHandler.createAudioException(e.toString());
    }
  }

  @override
  Future<void> setBpm({required int bpm}) async {
    // Validate BPM before making FFI call
    _validateBpm(bpm);

    try {
      // Delegate to FFI bridge
      await api.setBpm(bpm: bpm);
    } catch (e) {
      // Translate Rust error to user-friendly exception
      throw _errorHandler.createAudioException(e.toString());
    }
  }

  @override
  Stream<ClassificationResult> getClassificationStream() {
    debugPrint('[AudioServiceImpl] getClassificationStream called');
    try {
      // Get stream from FFI bridge and map FFI types to model types
      // The FFI stream uses StreamSink pattern for real-time classification results
      return api
          .classificationStream()
          .map((result) {
            debugPrint(
              '[AudioServiceImpl] Classification: ${result.sound} conf=${result.confidence.toStringAsFixed(2)}',
            );
            return _mapFfiToModelClassificationResult(result);
          })
          .handleError((error) {
            debugPrint(
              '[AudioServiceImpl] Classification stream error: $error',
            );
            // Translate Rust errors to user-friendly exceptions
            throw _errorHandler.createAudioException(error.toString());
          });
    } catch (e) {
      debugPrint('[AudioServiceImpl] getClassificationStream setup error: $e');
      // Handle synchronous errors during stream creation
      throw _errorHandler.createAudioException(e.toString());
    }
  }

  @override
  Stream<TelemetryEvent> getTelemetryStream() {
    try {
      return api_streams
          .telemetryStream()
          .map(_mapFfiToTelemetryEvent)
          .handleError((error) {
            throw _errorHandler.createAudioException(error.toString());
          });
    } catch (e) {
      throw _errorHandler.createAudioException(e.toString());
    }
  }

  @override
  Stream<DiagnosticMetric> getDiagnosticMetricsStream() {
    try {
      return mapDiagnosticMetrics(
        api_streams.diagnosticMetricsStream(),
      ).handleError((error) {
        throw _errorHandler.createAudioException(error.toString());
      });
    } catch (e) {
      throw _errorHandler.createAudioException(e.toString());
    }
  }

  /// Map FFI ClassificationResult to model ClassificationResult
  ///
  /// Converts flutter_rust_bridge generated types to application model types,
  /// handling BigInt to int conversion for timestamp.
  ClassificationResult _mapFfiToModelClassificationResult(
    ffi_analysis.ClassificationResult ffiResult,
  ) {
    return ClassificationResult(
      sound: _mapFfiToModelBeatboxHit(ffiResult.sound),
      timing: _mapFfiToModelTimingFeedback(ffiResult.timing),
      timestampMs: ffiResult.timestampMs.toInt(),
      confidence: ffiResult.confidence,
    );
  }

  /// Map FFI BeatboxHit to model BeatboxHit
  BeatboxHit _mapFfiToModelBeatboxHit(ffi_classifier.BeatboxHit ffiHit) {
    switch (ffiHit) {
      case ffi_classifier.BeatboxHit.kick:
        return BeatboxHit.kick;
      case ffi_classifier.BeatboxHit.snare:
        return BeatboxHit.snare;
      case ffi_classifier.BeatboxHit.hiHat:
        return BeatboxHit.hiHat;
      case ffi_classifier.BeatboxHit.closedHiHat:
        return BeatboxHit.closedHiHat;
      case ffi_classifier.BeatboxHit.openHiHat:
        return BeatboxHit.openHiHat;
      case ffi_classifier.BeatboxHit.kSnare:
        return BeatboxHit.kSnare;
      case ffi_classifier.BeatboxHit.unknown:
        return BeatboxHit.unknown;
    }
  }

  /// Map FFI TimingFeedback to model TimingFeedback
  TimingFeedback _mapFfiToModelTimingFeedback(
    ffi_quantizer.TimingFeedback ffiTiming,
  ) {
    return TimingFeedback(
      classification: _mapFfiToModelTimingClassification(
        ffiTiming.classification,
      ),
      errorMs: ffiTiming.errorMs,
    );
  }

  /// Map FFI TimingClassification to model TimingClassification
  TimingClassification _mapFfiToModelTimingClassification(
    ffi_quantizer.TimingClassification ffiClassification,
  ) {
    switch (ffiClassification) {
      case ffi_quantizer.TimingClassification.onTime:
        return TimingClassification.onTime;
      case ffi_quantizer.TimingClassification.early:
        return TimingClassification.early;
      case ffi_quantizer.TimingClassification.late_:
        return TimingClassification.late;
    }
  }

  @override
  Future<void> startCalibration() async {
    try {
      // Delegate to FFI bridge
      await api.startCalibration();
    } catch (e) {
      // Check if this is a calibration error or audio error
      final errorStr = e.toString();
      if (errorStr.toLowerCase().contains('calibration')) {
        throw _errorHandler.createCalibrationException(errorStr);
      } else {
        throw _errorHandler.createAudioException(errorStr);
      }
    }
  }

  @override
  Future<void> finishCalibration() async {
    try {
      // Delegate to FFI bridge
      await api.finishCalibration();
    } catch (e) {
      // Translate Rust error to user-friendly exception
      throw _errorHandler.createCalibrationException(e.toString());
    }
  }

  @override
  Stream<CalibrationProgress> getCalibrationStream() {
    try {
      // Get stream from FFI bridge and map FFI types to model types
      // The FFI stream uses StreamSink pattern for real-time calibration progress
      return api
          .calibrationStream()
          .map(_mapFfiToModelCalibrationProgress)
          .handleError((error) {
            // Translate Rust errors to user-friendly exceptions
            throw _errorHandler.createCalibrationException(error.toString());
          });
    } catch (e) {
      // Handle synchronous errors during stream creation
      throw _errorHandler.createCalibrationException(e.toString());
    }
  }

  @override
  Future<CalibrationProgress> manualAcceptLastCandidate() async {
    try {
      final progress = await api.manualAcceptLastCandidate();
      return _mapFfiToModelCalibrationProgress(progress);
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.toLowerCase().contains('calibration')) {
        throw _errorHandler.createCalibrationException(errorStr);
      } else {
        throw _errorHandler.createAudioException(errorStr);
      }
    }
  }

  @override
  Future<void> applyParamPatch({
    int? bpm,
    double? centroidThreshold,
    double? zcrThreshold,
  }) async {
    if (bpm == null && centroidThreshold == null && zcrThreshold == null) {
      throw AudioServiceException(
        message: 'Provide at least one value to update.',
        originalError: 'applyParamPatch invoked without any fields',
        errorCode: AudioErrorCodesExtension.streamFailure,
      );
    }

    try {
      await api.applyParams(
        patch: ffi_engine.ParamPatch(
          bpm: bpm,
          centroidThreshold: centroidThreshold,
          zcrThreshold: zcrThreshold,
        ),
      );
    } catch (e) {
      throw _errorHandler.createAudioException(e.toString());
    }
  }

  /// Map FFI CalibrationProgress to model CalibrationProgress
  ///
  /// Converts flutter_rust_bridge generated types to application model types.
  CalibrationProgress _mapFfiToModelCalibrationProgress(
    ffi_calibration.CalibrationProgress ffiProgress,
  ) {
    return CalibrationProgress(
      currentSound: _mapFfiToModelCalibrationSound(ffiProgress.currentSound),
      samplesCollected: ffiProgress.samplesCollected,
      samplesNeeded: ffiProgress.samplesNeeded,
      waitingForConfirmation: ffiProgress.waitingForConfirmation,
      guidance: _mapFfiToModelGuidance(ffiProgress.guidance),
      manualAcceptAvailable: ffiProgress.manualAcceptAvailable,
      debug: _mapFfiToModelDebug(ffiProgress.debug),
    );
  }

  /// Map FFI CalibrationSound to model CalibrationSound
  CalibrationSound _mapFfiToModelCalibrationSound(
    ffi_calibration.CalibrationSound ffiSound,
  ) {
    switch (ffiSound) {
      case ffi_calibration.CalibrationSound.noiseFloor:
        return CalibrationSound.noiseFloor;
      case ffi_calibration.CalibrationSound.kick:
        return CalibrationSound.kick;
      case ffi_calibration.CalibrationSound.snare:
        return CalibrationSound.snare;
      case ffi_calibration.CalibrationSound.hiHat:
        return CalibrationSound.hiHat;
    }
  }

  CalibrationGuidance? _mapFfiToModelGuidance(
    ffi_calibration.CalibrationGuidance? guidance,
  ) {
    if (guidance == null) return null;
    return CalibrationGuidance(
      sound: _mapFfiToModelCalibrationSound(guidance.sound),
      reason: _mapFfiGuidanceReason(guidance.reason),
      level: guidance.level,
      misses: guidance.misses,
    );
  }

  CalibrationGuidanceReason _mapFfiGuidanceReason(
    ffi_calibration.CalibrationGuidanceReason reason,
  ) {
    switch (reason) {
      case ffi_calibration.CalibrationGuidanceReason.stagnation:
        return CalibrationGuidanceReason.stagnation;
      case ffi_calibration.CalibrationGuidanceReason.tooQuiet:
        return CalibrationGuidanceReason.tooQuiet;
      case ffi_calibration.CalibrationGuidanceReason.clipped:
        return CalibrationGuidanceReason.clipped;
    }
  }

  CalibrationProgressDebug? _mapFfiToModelDebug(
    ffi_calibration.CalibrationProgressDebug? debug,
  ) {
    if (debug == null) return null;
    return CalibrationProgressDebug(
      seq: debug.seq.toInt(),
      rmsGate: debug.rmsGate,
      centroidMin: debug.centroidMin,
      centroidMax: debug.centroidMax,
      zcrMin: debug.zcrMin,
      zcrMax: debug.zcrMax,
      misses: debug.misses,
      lastCentroid: debug.lastCentroid,
      lastZcr: debug.lastZcr,
      lastRms: debug.lastRms,
      lastMaxAmp: debug.lastMaxAmp,
    );
  }

  TelemetryEvent _mapFfiToTelemetryEvent(ffi_engine.TelemetryEvent ffiEvent) {
    final timestamp = ffiEvent.timestampMs.toInt();
    final detail = ffiEvent.detail;
    final kind = ffiEvent.kind;

    if (kind is ffi_engine.TelemetryEventKind_EngineStarted) {
      return TelemetryEvent(
        timestampMs: timestamp,
        type: TelemetryEventType.engineStarted,
        bpm: kind.bpm,
        detail: detail,
      );
    }
    if (kind is ffi_engine.TelemetryEventKind_BpmChanged) {
      return TelemetryEvent(
        timestampMs: timestamp,
        type: TelemetryEventType.bpmChanged,
        bpm: kind.bpm,
        detail: detail,
      );
    }
    if (kind is ffi_engine.TelemetryEventKind_EngineStopped) {
      return TelemetryEvent(
        timestampMs: timestamp,
        type: TelemetryEventType.engineStopped,
        detail: detail,
      );
    }

    return TelemetryEvent(
      timestampMs: timestamp,
      type: TelemetryEventType.warning,
      detail: detail,
    );
  }

  @override
  Future<void> loadCalibrationState(String json) async {
    debugPrint('[AudioServiceImpl] loadCalibrationState called');
    debugPrint('[AudioServiceImpl] JSON: $json');
    try {
      await api.loadCalibrationState(json: json);
      debugPrint(
        '[AudioServiceImpl] loadCalibrationState completed successfully',
      );
    } catch (e) {
      debugPrint('[AudioServiceImpl] loadCalibrationState error: $e');
      throw _errorHandler.createCalibrationException(e.toString());
    }
  }

  @override
  Future<void> updateCalibrationThreshold(String key, double value) async {
    debugPrint('[AudioServiceImpl] updateCalibrationThreshold: $key = $value');
    try {
      await api.updateCalibrationThreshold(key: key, value: value);
      debugPrint('[AudioServiceImpl] Threshold updated successfully');
    } catch (e) {
      debugPrint('[AudioServiceImpl] updateCalibrationThreshold error: $e');
      throw _errorHandler.createCalibrationException(e.toString());
    }
  }

  @override
  Future<String> getCalibrationState() async {
    debugPrint('[AudioServiceImpl] getCalibrationState called');
    try {
      final json = await api.getCalibrationState();
      debugPrint('[AudioServiceImpl] getCalibrationState: $json');
      return json;
    } catch (e) {
      debugPrint('[AudioServiceImpl] getCalibrationState error: $e');
      throw _errorHandler.createCalibrationException(e.toString());
    }
  }
}
