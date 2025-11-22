// Error types for the beatbox trainer application
//
// This module defines custom error types for audio and calibration operations,
// providing structured error handling with error codes suitable for FFI communication.

mod audio;
mod calibration;

pub use audio::{log_audio_error, AudioError, AudioErrorCodes};
pub use calibration::{log_calibration_error, CalibrationError, CalibrationErrorCodes};

/// Error codes for structured error reporting
///
/// This trait provides a standard way to get error codes and messages
/// from custom error types, enabling consistent error handling across
/// the FFI boundary.
pub trait ErrorCode {
    /// Get the numeric error code
    fn code(&self) -> i32;

    /// Get the human-readable error message
    fn message(&self) -> String;
}
