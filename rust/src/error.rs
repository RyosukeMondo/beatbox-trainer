// Error types for the beatbox trainer application
//
// This module defines custom error types for audio and calibration operations,
// providing structured error handling with error codes suitable for FFI communication.

use flutter_rust_bridge::frb;
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

/// Audio error code constants exposed to Dart via FFI
///
/// These constants provide a single source of truth for error codes
/// shared between Rust and Dart. The flutter_rust_bridge will automatically
/// generate corresponding Dart constants.
///
/// Error code range: 1001-1009
#[frb]
pub struct AudioErrorCodes;

#[frb]
impl AudioErrorCodes {
    /// BPM value is invalid (must be > 0, typically 40-240)
    pub const BPM_INVALID: i32 = 1001;

    /// Audio engine is already running
    pub const ALREADY_RUNNING: i32 = 1002;

    /// Audio engine is not running
    pub const NOT_RUNNING: i32 = 1003;

    /// Hardware error occurred
    pub const HARDWARE_ERROR: i32 = 1004;

    /// Microphone permission denied
    pub const PERMISSION_DENIED: i32 = 1005;

    /// Failed to open audio stream
    pub const STREAM_OPEN_FAILED: i32 = 1006;

    /// Mutex/RwLock was poisoned
    pub const LOCK_POISONED: i32 = 1007;

    /// JNI initialization failed on Android
    pub const JNI_INIT_FAILED: i32 = 1008;

    /// Android context was not initialized before audio engine start
    pub const CONTEXT_NOT_INITIALIZED: i32 = 1009;
}

/// Calibration error code constants exposed to Dart via FFI
///
/// These constants provide a single source of truth for error codes
/// shared between Rust and Dart. The flutter_rust_bridge will automatically
/// generate corresponding Dart constants.
///
/// Error code range: 2001-2005
#[frb]
pub struct CalibrationErrorCodes;

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
/// Error code ranges: 1001-1009
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

    /// JNI initialization failed on Android
    JniInitFailed { reason: String },

    /// Android context was not initialized before audio engine start
    ContextNotInitialized,
}

impl ErrorCode for AudioError {
    fn code(&self) -> i32 {
        match self {
            AudioError::BpmInvalid { .. } => AudioErrorCodes::BPM_INVALID,
            AudioError::AlreadyRunning => AudioErrorCodes::ALREADY_RUNNING,
            AudioError::NotRunning => AudioErrorCodes::NOT_RUNNING,
            AudioError::HardwareError { .. } => AudioErrorCodes::HARDWARE_ERROR,
            AudioError::PermissionDenied => AudioErrorCodes::PERMISSION_DENIED,
            AudioError::StreamOpenFailed { .. } => AudioErrorCodes::STREAM_OPEN_FAILED,
            AudioError::LockPoisoned { .. } => AudioErrorCodes::LOCK_POISONED,
            AudioError::JniInitFailed { .. } => AudioErrorCodes::JNI_INIT_FAILED,
            AudioError::ContextNotInitialized => AudioErrorCodes::CONTEXT_NOT_INITIALIZED,
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
            AudioError::JniInitFailed { reason } => {
                format!("JNI initialization failed: {}", reason)
            }
            AudioError::ContextNotInitialized => {
                "Android context not initialized. This may indicate the native library was not loaded correctly or JNI_OnLoad failed.".to_string()
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
            CalibrationError::InsufficientSamples { .. } => {
                CalibrationErrorCodes::INSUFFICIENT_SAMPLES
            }
            CalibrationError::InvalidFeatures { .. } => CalibrationErrorCodes::INVALID_FEATURES,
            CalibrationError::NotComplete => CalibrationErrorCodes::NOT_COMPLETE,
            CalibrationError::AlreadyInProgress => CalibrationErrorCodes::ALREADY_IN_PROGRESS,
            CalibrationError::StatePoisoned => CalibrationErrorCodes::STATE_POISONED,
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
        assert_eq!(
            AudioError::BpmInvalid { bpm: 0 }.code(),
            AudioErrorCodes::BPM_INVALID
        );
        assert_eq!(
            AudioError::AlreadyRunning.code(),
            AudioErrorCodes::ALREADY_RUNNING
        );
        assert_eq!(AudioError::NotRunning.code(), AudioErrorCodes::NOT_RUNNING);
        assert_eq!(
            AudioError::HardwareError {
                details: "test".to_string()
            }
            .code(),
            AudioErrorCodes::HARDWARE_ERROR
        );
        assert_eq!(
            AudioError::PermissionDenied.code(),
            AudioErrorCodes::PERMISSION_DENIED
        );
        assert_eq!(
            AudioError::StreamOpenFailed {
                reason: "test".to_string()
            }
            .code(),
            AudioErrorCodes::STREAM_OPEN_FAILED
        );
        assert_eq!(
            AudioError::LockPoisoned {
                component: "test".to_string()
            }
            .code(),
            AudioErrorCodes::LOCK_POISONED
        );
        assert_eq!(
            AudioError::JniInitFailed {
                reason: "test".to_string()
            }
            .code(),
            AudioErrorCodes::JNI_INIT_FAILED
        );
        assert_eq!(
            AudioError::ContextNotInitialized.code(),
            AudioErrorCodes::CONTEXT_NOT_INITIALIZED
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
        assert_eq!(audio_err.code(), AudioErrorCodes::BPM_INVALID);

        let cal_err: &dyn ErrorCode = &CalibrationError::NotComplete;
        assert_eq!(cal_err.code(), CalibrationErrorCodes::NOT_COMPLETE);
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

    #[test]
    fn test_error_logging_functions() {
        // Test audio error logging
        log_audio_error(&AudioError::BpmInvalid { bpm: 0 }, "test_ctx");
        log_audio_error(
            &AudioError::JniInitFailed {
                reason: "test".into(),
            },
            "test_ctx",
        );
        log_audio_error(&AudioError::ContextNotInitialized, "test_ctx");

        // Test calibration error logging
        log_calibration_error(&CalibrationError::NotComplete, "test_ctx");
    }

    #[test]
    fn test_error_messages() {
        // Test key AudioError messages
        assert!(AudioError::BpmInvalid { bpm: 999 }
            .message()
            .contains("999"));
        assert!(AudioError::PermissionDenied
            .message()
            .contains("permission denied"));
        assert!(AudioError::JniInitFailed {
            reason: "ctx err".into()
        }
        .message()
        .contains("ctx err"));
        assert!(AudioError::ContextNotInitialized
            .message()
            .contains("Android context not initialized"));
    }

    #[test]
    fn test_calibration_error_messages() {
        let msg = CalibrationError::InsufficientSamples {
            required: 20,
            collected: 8,
        }
        .message();
        assert!(msg.contains("20") && msg.contains("8"));
        assert!(CalibrationError::NotComplete
            .message()
            .contains("not complete"));
    }

    #[test]
    fn test_error_display_with_codes() {
        // Test key error codes in display
        let d = format!("{}", AudioError::BpmInvalid { bpm: 42 });
        assert!(d.contains("AudioError") && d.contains("1001"));
        assert!(format!(
            "{}",
            AudioError::JniInitFailed {
                reason: "jni".into()
            }
        )
        .contains("1008"));
        assert!(format!("{}", AudioError::ContextNotInitialized).contains("1009"));
    }

    #[test]
    fn test_calibration_error_display_with_codes() {
        let d = format!(
            "{}",
            CalibrationError::InsufficientSamples {
                required: 15,
                collected: 7
            }
        );
        assert!(d.contains("CalibrationError") && d.contains("2001"));
        assert!(format!("{}", CalibrationError::NotComplete).contains("2003"));
    }

    #[test]
    fn test_android_jni_init_failed_error() {
        let jni_error = AudioError::JniInitFailed {
            reason: "Failed to get application context".to_string(),
        };
        assert_eq!(jni_error.code(), AudioErrorCodes::JNI_INIT_FAILED);
        assert!(jni_error.message().contains("JNI initialization failed"));
        assert!(jni_error
            .message()
            .contains("Failed to get application context"));
        let display = format!("{}", jni_error);
        assert!(display.contains("1008"));
        assert!(display.contains("AudioError"));
    }

    #[test]
    fn test_android_context_not_initialized_error() {
        let ctx_error = AudioError::ContextNotInitialized;
        assert_eq!(ctx_error.code(), AudioErrorCodes::CONTEXT_NOT_INITIALIZED);
        assert!(ctx_error
            .message()
            .contains("Android context not initialized"));
        assert!(ctx_error.message().contains("JNI_OnLoad"));
        let display = format!("{}", ctx_error);
        assert!(display.contains("1009"));
        assert!(display.contains("AudioError"));
    }

    #[test]
    fn test_android_error_propagation() {
        fn simulate_jni_failure() -> Result<(), AudioError> {
            Err(AudioError::JniInitFailed {
                reason: "JavaVM pointer is null".to_string(),
            })
        }

        fn simulate_context_check() -> Result<(), AudioError> {
            Err(AudioError::ContextNotInitialized)
        }

        assert!(simulate_jni_failure().is_err());
        assert!(simulate_context_check().is_err());
    }

    #[test]
    fn test_android_error_distinctness() {
        assert_ne!(
            AudioError::JniInitFailed {
                reason: "test".into()
            },
            AudioError::ContextNotInitialized
        );
        assert_ne!(
            AudioError::ContextNotInitialized,
            AudioError::StreamOpenFailed {
                reason: "test".into()
            }
        );
    }
}
