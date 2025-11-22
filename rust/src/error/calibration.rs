// Calibration error types and constants

use crate::error::ErrorCode;
use flutter_rust_bridge::frb;
use log::error;
use std::fmt;

/// Calibration error code constants exposed to Dart via FFI
///
/// These constants provide a single source of truth for error codes
/// shared between Rust and Dart. The flutter_rust_bridge will automatically
/// generate corresponding Dart constants.
///
/// Error code range: 2001-2006
#[frb(unignore)]
pub struct CalibrationErrorCodes {}

#[frb]
impl CalibrationErrorCodes {
    /// Insufficient samples collected for calibration
    pub const INSUFFICIENT_SAMPLES: i32 = 2001;

    /// Invalid features extracted from samples
    pub const INVALID_FEATURES: i32 = 2002;

    /// Calibration not complete
    pub const NOT_COMPLETE: i32 = 2003;

    /// Calibration already in progress
    pub const ALREADY_IN_PROGRESS: i32 = 2004;

    /// Calibration state RwLock was poisoned
    pub const STATE_POISONED: i32 = 2005;

    /// Calibration timed out waiting for engine coordination
    pub const TIMEOUT: i32 = 2006;

    // Getter methods for FFI exposure (flutter_rust_bridge requires methods not const)

    /// Get INSUFFICIENT_SAMPLES error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn insufficient_samples() -> i32 {
        Self::INSUFFICIENT_SAMPLES
    }

    /// Get INVALID_FEATURES error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn invalid_features() -> i32 {
        Self::INVALID_FEATURES
    }

    /// Get NOT_COMPLETE error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn not_complete() -> i32 {
        Self::NOT_COMPLETE
    }

    /// Get ALREADY_IN_PROGRESS error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn already_in_progress() -> i32 {
        Self::ALREADY_IN_PROGRESS
    }

    /// Get STATE_POISONED error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn state_poisoned() -> i32 {
        Self::STATE_POISONED
    }

    /// Get TIMEOUT error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn timeout() -> i32 {
        Self::TIMEOUT
    }
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

/// Calibration-related errors
///
/// These errors cover calibration procedure operations including sample
/// collection, feature extraction, and state management.
///
/// Error code ranges: 2001-2006
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

    /// Calibration timed out waiting for native engine coordination
    Timeout { reason: String },
}

impl ErrorCode for CalibrationError {
    fn code(&self) -> i32 {
        match self {
            CalibrationError::InsufficientSamples { .. } => {
                CalibrationErrorCodes::INSUFFICIENT_SAMPLES
            }
            CalibrationError::InvalidFeatures { .. } => CalibrationErrorCodes::INVALID_FEATURES,
            CalibrationError::NotComplete => CalibrationErrorCodes::NOT_COMPLETE,
            CalibrationError::AlreadyInProgress => CalibrationErrorCodes::ALREADY_IN_PROGRESS,
            CalibrationError::StatePoisoned => CalibrationErrorCodes::STATE_POISONED,
            CalibrationError::Timeout { .. } => CalibrationErrorCodes::TIMEOUT,
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
            CalibrationError::Timeout { reason } => {
                format!("Calibration timed out: {}", reason)
            }
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
    fn test_calibration_error_codes() {
        assert_eq!(
            CalibrationError::InsufficientSamples {
                required: 5,
                collected: 3
            }
            .code(),
            CalibrationErrorCodes::INSUFFICIENT_SAMPLES
        );
        assert_eq!(
            CalibrationError::InvalidFeatures {
                reason: "test".to_string()
            }
            .code(),
            CalibrationErrorCodes::INVALID_FEATURES
        );
        assert_eq!(
            CalibrationError::NotComplete.code(),
            CalibrationErrorCodes::NOT_COMPLETE
        );
        assert_eq!(
            CalibrationError::AlreadyInProgress.code(),
            CalibrationErrorCodes::ALREADY_IN_PROGRESS
        );
        assert_eq!(
            CalibrationError::StatePoisoned.code(),
            CalibrationErrorCodes::STATE_POISONED
        );
        assert_eq!(
            CalibrationError::Timeout {
                reason: "test".to_string()
            }
            .code(),
            CalibrationErrorCodes::TIMEOUT
        );
    }

    #[test]
    fn test_calibration_error_messages() {
        let err = CalibrationError::InsufficientSamples {
            required: 5,
            collected: 3,
        };
        assert_eq!(err.message(), "Insufficient samples: need 5, got 3");

        let err = CalibrationError::InvalidFeatures {
            reason: "test reason".to_string(),
        };
        assert_eq!(err.message(), "Invalid features: test reason");

        let err = CalibrationError::NotComplete;
        assert!(err.message().contains("not complete"));

        let err = CalibrationError::AlreadyInProgress;
        assert!(err.message().contains("already in progress"));

        let err = CalibrationError::StatePoisoned;
        assert!(err.message().contains("poisoned"));

        let err = CalibrationError::Timeout {
            reason: "took too long".to_string(),
        };
        assert_eq!(err.message(), "Calibration timed out: took too long");
    }

    #[test]
    fn test_calibration_error_display() {
        let err = CalibrationError::NotComplete;
        let display = format!("{}", err);
        assert!(display.contains("CalibrationError"));
        assert!(display.contains(&err.code().to_string()));
    }

    #[test]
    fn test_error_code_getters() {
        assert_eq!(CalibrationErrorCodes::insufficient_samples(), 2001);
        assert_eq!(CalibrationErrorCodes::invalid_features(), 2002);
        assert_eq!(CalibrationErrorCodes::not_complete(), 2003);
        assert_eq!(CalibrationErrorCodes::already_in_progress(), 2004);
        assert_eq!(CalibrationErrorCodes::state_poisoned(), 2005);
        assert_eq!(CalibrationErrorCodes::timeout(), 2006);
    }
}
