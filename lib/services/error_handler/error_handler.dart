import 'exceptions.dart';

/// Utility class for translating Rust errors to user-friendly messages
///
/// This class provides methods to translate technical error messages from
/// the Rust FFI layer into user-friendly messages suitable for display
/// in the UI. It parses error codes and variants from the Rust error
/// format: "AudioError::{variant} (code {code}): {message}"
class ErrorHandler {
  /// Regular expression to extract error code from Rust error messages
  static final _errorCodePattern = RegExp(r'\(code (\d+)\)');

  /// Extract error code from Rust error string
  ///
  /// Parses the error code from the format: "ErrorType::Variant (code 1001): message"
  /// Returns null if no code is found.
  int? _extractErrorCode(String rustError) {
    final match = _errorCodePattern.firstMatch(rustError);
    if (match != null && match.groupCount >= 1) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Translate audio-related errors to user-friendly messages
  ///
  /// This method pattern matches on Rust AudioError variants and provides
  /// actionable, user-friendly error messages.
  ///
  /// Supported error codes:
  /// - 1001: BpmInvalid - Invalid tempo value
  /// - 1002: AlreadyRunning - Audio engine already active
  /// - 1003: NotRunning - Audio engine not active
  /// - 1004: HardwareError - Audio hardware issues
  /// - 1005: PermissionDenied - Microphone permission denied
  /// - 1006: StreamOpenFailed - Failed to open audio stream
  /// - 1007: LockPoisoned - Internal synchronization error
  ///
  /// For unknown errors, returns a generic fallback message.
  String translateAudioError(String rustError) {
    final errorCode = _extractErrorCode(rustError);

    // Match by error code for precise handling
    switch (errorCode) {
      case 1001: // BpmInvalid
        return 'Please choose a tempo between 40 and 240 BPM.';

      case 1002: // AlreadyRunning
        return 'Audio is already active. Please stop it first.';

      case 1003: // NotRunning
        return 'Audio engine is not running. Please start it first.';

      case 1004: // HardwareError
        return 'Audio hardware error occurred. Please check your device settings.';

      case 1005: // PermissionDenied
        return 'Microphone access required. Please enable in settings.';

      case 1006: // StreamOpenFailed
        return 'Unable to access audio hardware. Please check if another app is using the microphone.';

      case 1007: // LockPoisoned
        return 'Internal error occurred. Please restart the app.';

      default:
        // Fallback pattern matching on error text
        final lowerError = rustError.toLowerCase();

        if (lowerError.contains('bpm') &&
            (lowerError.contains('invalid') || lowerError.contains('range'))) {
          return 'Please choose a tempo between 40 and 240 BPM.';
        }

        if (lowerError.contains('already running')) {
          return 'Audio is already active. Please stop it first.';
        }

        if (lowerError.contains('not running')) {
          return 'Audio engine is not running. Please start it first.';
        }

        if (lowerError.contains('permission')) {
          return 'Microphone access required. Please enable in settings.';
        }

        if (lowerError.contains('hardware') || lowerError.contains('stream')) {
          return 'Unable to access audio hardware. Please check if another app is using the microphone.';
        }

        if (lowerError.contains('lock')) {
          return 'Internal error occurred. Please restart the app.';
        }

        // Generic fallback
        return 'Audio engine error occurred. Please try restarting.';
    }
  }

  /// Translate calibration-related errors to user-friendly messages
  ///
  /// This method pattern matches on Rust CalibrationError variants and provides
  /// actionable, user-friendly error messages.
  ///
  /// Supported error codes:
  /// - 2001: InsufficientSamples - Not enough samples collected
  /// - 2002: InvalidFeatures - Poor quality audio samples
  /// - 2003: NotComplete - Calibration incomplete
  /// - 2004: AlreadyInProgress - Calibration already running
  /// - 2005: StatePoisoned - Internal synchronization error
  ///
  /// For unknown errors, returns a generic fallback message.
  String translateCalibrationError(String rustError) {
    final errorCode = _extractErrorCode(rustError);

    // Match by error code for precise handling
    switch (errorCode) {
      case 2001: // InsufficientSamples
        return 'Not enough samples collected. Please continue making sounds.';

      case 2002: // InvalidFeatures
        return 'Sound quality too low. Please speak louder or move closer to the microphone.';

      case 2003: // NotComplete
        return 'Calibration not finished. Please complete all steps.';

      case 2004: // AlreadyInProgress
        return 'Calibration is already in progress. Please finish or cancel it first.';

      case 2005: // StatePoisoned
        return 'Internal error occurred. Please restart the app.';

      default:
        // Fallback pattern matching on error text
        final lowerError = rustError.toLowerCase();

        if (lowerError.contains('insufficient') ||
            lowerError.contains('samples')) {
          return 'Not enough samples collected. Please continue making sounds.';
        }

        if (lowerError.contains('invalid') ||
            lowerError.contains('features') ||
            lowerError.contains('quality')) {
          return 'Sound quality too low. Please speak louder or move closer to the microphone.';
        }

        if (lowerError.contains('not complete')) {
          return 'Calibration not finished. Please complete all steps.';
        }

        if (lowerError.contains('already') ||
            lowerError.contains('in progress')) {
          return 'Calibration is already in progress. Please finish or cancel it first.';
        }

        if (lowerError.contains('lock') || lowerError.contains('poison')) {
          return 'Internal error occurred. Please restart the app.';
        }

        // Generic fallback
        return 'Calibration error occurred. Please try again.';
    }
  }

  /// Create an AudioServiceException with translated message
  ///
  /// This helper method translates the error and wraps it in an
  /// AudioServiceException with the error code extracted.
  AudioServiceException createAudioException(String rustError) {
    return AudioServiceException(
      message: translateAudioError(rustError),
      originalError: rustError,
      errorCode: _extractErrorCode(rustError),
    );
  }

  /// Create a CalibrationServiceException with translated message
  ///
  /// This helper method translates the error and wraps it in a
  /// CalibrationServiceException with the error code extracted.
  CalibrationServiceException createCalibrationException(String rustError) {
    return CalibrationServiceException(
      message: translateCalibrationError(rustError),
      originalError: rustError,
      errorCode: _extractErrorCode(rustError),
    );
  }
}
