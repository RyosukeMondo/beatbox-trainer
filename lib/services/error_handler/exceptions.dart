/// Exception types for audio and calibration errors
///
/// These exceptions provide user-friendly error messages translated from
/// Rust error types, suitable for display in the UI.
library;

/// Base exception for audio service operations
///
/// This exception is thrown when audio operations fail, containing both
/// the user-friendly message and the original error for debugging.
class AudioServiceException implements Exception {
  /// User-friendly error message suitable for display
  final String message;

  /// Original error message from Rust FFI for debugging
  final String originalError;

  /// Error code from the underlying Rust error (1001-1007)
  final int? errorCode;

  const AudioServiceException({
    required this.message,
    required this.originalError,
    this.errorCode,
  });

  @override
  String toString() => message;
}

/// Base exception for calibration operations
///
/// This exception is thrown when calibration operations fail, containing both
/// the user-friendly message and the original error for debugging.
class CalibrationServiceException implements Exception {
  /// User-friendly error message suitable for display
  final String message;

  /// Original error message from Rust FFI for debugging
  final String originalError;

  /// Error code from the underlying Rust error (2001-2005)
  final int? errorCode;

  const CalibrationServiceException({
    required this.message,
    required this.originalError,
    this.errorCode,
  });

  @override
  String toString() => message;
}
