import '../../models/classification_result.dart';
import '../../models/calibration_progress.dart';
import '../../bridge/api.dart/api.dart' as api;
import '../error_handler/error_handler.dart';
import '../error_handler/exceptions.dart';
import 'i_audio_service.dart';

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
    // Validate BPM before making FFI call
    _validateBpm(bpm);

    try {
      // Delegate to FFI bridge
      await api.startAudio(bpm: bpm);
    } catch (e) {
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
    try {
      // Delegate to FFI bridge
      return api.classificationStream();
    } catch (e) {
      // Translate Rust error to user-friendly exception
      throw _errorHandler.createAudioException(e.toString());
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
      // Delegate to FFI bridge
      return api.calibrationStream();
    } catch (e) {
      // Translate Rust error to user-friendly exception
      throw _errorHandler.createCalibrationException(e.toString());
    }
  }
}
