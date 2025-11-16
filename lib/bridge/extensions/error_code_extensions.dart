// Error code constant extensions for AudioErrorCodes and CalibrationErrorCodes
//
// This file provides convenient getters to access error code constants from Dart.
// The constants are defined in Rust (rust/src/error.rs) and exposed via FFI.

import '../api.dart/error.dart';

/// Extension on AudioErrorCodes to provide constant accessors
///
/// These constants match the error codes defined in rust/src/error.rs
extension AudioErrorCodesExtension on AudioErrorCodes {
  /// BPM value is invalid (must be > 0, typically 40-240)
  static const int bpmInvalid = 1001;

  /// Audio engine is already running
  static const int alreadyRunning = 1002;

  /// Audio engine is not running
  static const int notRunning = 1003;

  /// Hardware error occurred
  static const int hardwareError = 1004;

  /// Microphone permission denied
  static const int permissionDenied = 1005;

  /// Failed to open audio stream
  static const int streamOpenFailed = 1006;

  /// Mutex/RwLock was poisoned
  static const int lockPoisoned = 1007;

  /// JNI initialization failed on Android
  static const int jniInitFailed = 1008;

  /// Android context was not initialized before audio engine start
  static const int contextNotInitialized = 1009;

  /// Live stream disconnected or command queue closed
  static const int streamFailure = 1010;
}

/// Extension on CalibrationErrorCodes to provide constant accessors
///
/// These constants match the error codes defined in rust/src/error.rs
extension CalibrationErrorCodesExtension on CalibrationErrorCodes {
  /// Insufficient samples collected for calibration
  static const int insufficientSamples = 2001;

  /// Invalid features extracted from samples
  static const int invalidFeatures = 2002;

  /// Calibration not complete
  static const int notComplete = 2003;

  /// Calibration already in progress
  static const int alreadyInProgress = 2004;

  /// Calibration state RwLock was poisoned
  static const int statePoisoned = 2005;

  /// Calibration timed out waiting for the engine
  static const int timeout = 2006;
}
