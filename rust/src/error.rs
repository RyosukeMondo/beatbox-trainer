// Error types for the beatbox trainer application
//
// This module defines custom error types for audio and calibration operations,
// providing structured error handling with error codes suitable for FFI communication.

use log::error;
use std::fmt;

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

/// Log an audio error with structured context
///
/// This function logs audio errors with structured fields including:
/// - error_code: Numeric error code for programmatic handling
/// - component: The component where the error occurred
/// - message: Human-readable error message
/// - context: Additional contextual information
///
/// The logging is non-blocking and will not panic on failure.
pub fn log_audio_error(err: &AudioError, context: &str) {
    error!(
        "Audio error in {}: code={}, component=AudioEngine, message={}",
        context,
        err.code(),
        err.message()
    );
}

/// Log a calibration error with structured context
///
/// This function logs calibration errors with structured fields including:
/// - error_code: Numeric error code for programmatic handling
/// - component: The component where the error occurred
/// - message: Human-readable error message
/// - context: Additional contextual information
///
/// The logging is non-blocking and will not panic on failure.
pub fn log_calibration_error(err: &CalibrationError, context: &str) {
    error!(
        "Calibration error in {}: code={}, component=CalibrationProcedure, message={}",
        context,
        err.code(),
        err.message()
    );
}

/// Audio-related errors
///
/// These errors cover audio engine operations including initialization,
/// stream management, and hardware access.
///
/// Error code ranges: 1001-1007
#[derive(Debug, Clone, PartialEq)]
pub enum AudioError {
    /// BPM value is invalid (must be > 0, typically 40-240)
    BpmInvalid { bpm: u32 },

    /// Audio engine is already running
    AlreadyRunning,

    /// Audio engine is not running
    NotRunning,

    /// Hardware error occurred
    HardwareError { details: String },

    /// Microphone permission denied
    PermissionDenied,

    /// Failed to open audio stream
    StreamOpenFailed { reason: String },

    /// Mutex/RwLock was poisoned
    LockPoisoned { component: String },
}

impl ErrorCode for AudioError {
    fn code(&self) -> i32 {
        match self {
            AudioError::BpmInvalid { .. } => 1001,
            AudioError::AlreadyRunning => 1002,
            AudioError::NotRunning => 1003,
            AudioError::HardwareError { .. } => 1004,
            AudioError::PermissionDenied => 1005,
            AudioError::StreamOpenFailed { .. } => 1006,
            AudioError::LockPoisoned { .. } => 1007,
        }
    }

    fn message(&self) -> String {
        match self {
            AudioError::BpmInvalid { bpm } => {
                format!("BPM must be greater than 0 (got {})", bpm)
            }
            AudioError::AlreadyRunning => {
                "Audio engine already running. Call stop_audio() first.".to_string()
            }
            AudioError::NotRunning => {
                "Audio engine not running. Call start_audio() first.".to_string()
            }
            AudioError::HardwareError { details } => {
                format!("Hardware error: {}", details)
            }
            AudioError::PermissionDenied => "Microphone permission denied".to_string(),
            AudioError::StreamOpenFailed { reason } => {
                format!("Failed to open audio stream: {}", reason)
            }
            AudioError::LockPoisoned { component } => {
                format!("Lock poisoned for component: {}", component)
            }
        }
    }
}

impl fmt::Display for AudioError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "AudioError::{:?} (code {}): {}",
            self,
            self.code(),
            self.message()
        )
    }
}

impl std::error::Error for AudioError {}

/// Convert from std::io::Error to AudioError
impl From<std::io::Error> for AudioError {
    fn from(err: std::io::Error) -> Self {
        AudioError::HardwareError {
            details: err.to_string(),
        }
    }
}

/// Calibration-related errors
///
/// These errors cover calibration procedure operations including sample
/// collection, feature extraction, and state management.
///
/// Error code ranges: 2001-2005
#[derive(Debug, Clone, PartialEq)]
pub enum CalibrationError {
    /// Insufficient samples collected for calibration
    InsufficientSamples { required: usize, collected: usize },

    /// Invalid features extracted from samples
    InvalidFeatures { reason: String },

    /// Calibration not complete
    NotComplete,

    /// Calibration already in progress
    AlreadyInProgress,

    /// Calibration state RwLock was poisoned
    StatePoisoned,
}

impl ErrorCode for CalibrationError {
    fn code(&self) -> i32 {
        match self {
            CalibrationError::InsufficientSamples { .. } => 2001,
            CalibrationError::InvalidFeatures { .. } => 2002,
            CalibrationError::NotComplete => 2003,
            CalibrationError::AlreadyInProgress => 2004,
            CalibrationError::StatePoisoned => 2005,
        }
    }

    fn message(&self) -> String {
        match self {
            CalibrationError::InsufficientSamples {
                required,
                collected,
            } => {
                format!("Insufficient samples: need {}, got {}", required, collected)
            }
            CalibrationError::InvalidFeatures { reason } => {
                format!("Invalid features: {}", reason)
            }
            CalibrationError::NotComplete => "Calibration not complete".to_string(),
            CalibrationError::AlreadyInProgress => "Calibration already in progress".to_string(),
            CalibrationError::StatePoisoned => "Calibration state lock poisoned".to_string(),
        }
    }
}

impl fmt::Display for CalibrationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "CalibrationError::{:?} (code {}): {}",
            self,
            self.code(),
            self.message()
        )
    }
}

impl std::error::Error for CalibrationError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_audio_error_codes() {
        assert_eq!(AudioError::BpmInvalid { bpm: 0 }.code(), 1001);
        assert_eq!(AudioError::AlreadyRunning.code(), 1002);
        assert_eq!(AudioError::NotRunning.code(), 1003);
        assert_eq!(
            AudioError::HardwareError {
                details: "test".to_string()
            }
            .code(),
            1004
        );
        assert_eq!(AudioError::PermissionDenied.code(), 1005);
        assert_eq!(
            AudioError::StreamOpenFailed {
                reason: "test".to_string()
            }
            .code(),
            1006
        );
        assert_eq!(
            AudioError::LockPoisoned {
                component: "test".to_string()
            }
            .code(),
            1007
        );
    }

    #[test]
    fn test_calibration_error_codes() {
        assert_eq!(
            CalibrationError::InsufficientSamples {
                required: 10,
                collected: 5
            }
            .code(),
            2001
        );
        assert_eq!(
            CalibrationError::InvalidFeatures {
                reason: "test".to_string()
            }
            .code(),
            2002
        );
        assert_eq!(CalibrationError::NotComplete.code(), 2003);
        assert_eq!(CalibrationError::AlreadyInProgress.code(), 2004);
        assert_eq!(CalibrationError::StatePoisoned.code(), 2005);
    }

    #[test]
    fn test_audio_error_display() {
        let err = AudioError::BpmInvalid { bpm: 0 };
        assert!(err.message().contains("BPM must be greater than 0"));

        let err = AudioError::AlreadyRunning;
        assert!(err.message().contains("already running"));

        let err = AudioError::LockPoisoned {
            component: "AudioEngine".to_string(),
        };
        assert!(err.message().contains("AudioEngine"));
    }

    #[test]
    fn test_calibration_error_display() {
        let err = CalibrationError::InsufficientSamples {
            required: 10,
            collected: 5,
        };
        assert!(err.message().contains("need 10"));
        assert!(err.message().contains("got 5"));

        let err = CalibrationError::AlreadyInProgress;
        assert!(err.message().contains("already in progress"));
    }

    #[test]
    fn test_error_code_trait() {
        let audio_err: &dyn ErrorCode = &AudioError::BpmInvalid { bpm: 0 };
        assert_eq!(audio_err.code(), 1001);

        let cal_err: &dyn ErrorCode = &CalibrationError::NotComplete;
        assert_eq!(cal_err.code(), 2003);
    }

    #[test]
    fn test_io_error_conversion() {
        let io_err = std::io::Error::new(std::io::ErrorKind::PermissionDenied, "test error");
        let audio_err: AudioError = io_err.into();

        match audio_err {
            AudioError::HardwareError { details } => {
                assert!(details.contains("test error"));
            }
            _ => panic!("Expected HardwareError variant"),
        }
    }

    #[test]
    fn test_error_propagation() {
        fn may_fail() -> Result<(), AudioError> {
            Err(AudioError::BpmInvalid { bpm: 0 })
        }

        fn caller() -> Result<(), AudioError> {
            may_fail()?;
            Ok(())
        }

        assert!(caller().is_err());
    }
}
