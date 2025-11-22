// Audio error types and constants

use crate::error::ErrorCode;
use flutter_rust_bridge::frb;
use log::error;
use std::fmt;

/// Audio error code constants exposed to Dart via FFI
///
/// These constants provide a single source of truth for error codes
/// shared between Rust and Dart. The flutter_rust_bridge will automatically
/// generate corresponding Dart constants.
///
/// Error code range: 1001-1010
#[frb(unignore)]
pub struct AudioErrorCodes {}

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

    /// Audio stream disconnected or channel closed unexpectedly
    pub const STREAM_FAILURE: i32 = 1010;

    // Getter methods for FFI exposure (flutter_rust_bridge requires methods not const)

    /// Get BPM_INVALID error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn bpm_invalid() -> i32 {
        Self::BPM_INVALID
    }

    /// Get ALREADY_RUNNING error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn already_running() -> i32 {
        Self::ALREADY_RUNNING
    }

    /// Get NOT_RUNNING error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn not_running() -> i32 {
        Self::NOT_RUNNING
    }

    /// Get HARDWARE_ERROR error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn hardware_error() -> i32 {
        Self::HARDWARE_ERROR
    }

    /// Get PERMISSION_DENIED error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn permission_denied() -> i32 {
        Self::PERMISSION_DENIED
    }

    /// Get STREAM_OPEN_FAILED error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn stream_open_failed() -> i32 {
        Self::STREAM_OPEN_FAILED
    }

    /// Get LOCK_POISONED error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn lock_poisoned() -> i32 {
        Self::LOCK_POISONED
    }

    /// Get JNI_INIT_FAILED error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn jni_init_failed() -> i32 {
        Self::JNI_INIT_FAILED
    }

    /// Get CONTEXT_NOT_INITIALIZED error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn context_not_initialized() -> i32 {
        Self::CONTEXT_NOT_INITIALIZED
    }

    /// Get STREAM_FAILURE error code
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn stream_failure() -> i32 {
        Self::STREAM_FAILURE
    }
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

/// Audio-related errors
///
/// These errors cover audio engine operations including initialization,
/// stream management, and hardware access.
///
/// Error code ranges: 1001-1010
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

    /// Stream channel disconnected unexpectedly
    StreamFailure { reason: String },
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
            AudioError::StreamFailure { .. } => AudioErrorCodes::STREAM_FAILURE,
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
            AudioError::PermissionDenied => {
                "Microphone permission denied. Please grant microphone access.".to_string()
            }
            AudioError::StreamOpenFailed { reason } => {
                format!("Failed to open audio stream: {}", reason)
            }
            AudioError::LockPoisoned { component } => {
                format!("Lock poisoned on {}", component)
            }
            AudioError::JniInitFailed { reason } => {
                format!("JNI initialization failed: {}", reason)
            }
            AudioError::ContextNotInitialized => {
                "Android context not initialized. Call init_android_context() first.".to_string()
            }
            AudioError::StreamFailure { reason } => {
                format!("Audio stream failed: {}", reason)
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

impl From<std::io::Error> for AudioError {
    fn from(err: std::io::Error) -> Self {
        AudioError::HardwareError {
            details: err.to_string(),
        }
    }
}

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
        assert_eq!(
            AudioError::StreamFailure {
                reason: "test".to_string()
            }
            .code(),
            AudioErrorCodes::STREAM_FAILURE
        );
    }

    #[test]
    fn test_audio_error_messages() {
        let err = AudioError::BpmInvalid { bpm: 0 };
        assert_eq!(err.message(), "BPM must be greater than 0 (got 0)");

        let err = AudioError::AlreadyRunning;
        assert!(err.message().contains("already running"));

        let err = AudioError::NotRunning;
        assert!(err.message().contains("not running"));

        let err = AudioError::HardwareError {
            details: "test error".to_string(),
        };
        assert_eq!(err.message(), "Hardware error: test error");

        let err = AudioError::PermissionDenied;
        assert!(err.message().contains("permission denied"));
    }

    #[test]
    fn test_audio_error_display() {
        let err = AudioError::BpmInvalid { bpm: 0 };
        let display = format!("{}", err);
        assert!(display.contains("AudioError"));
        assert!(display.contains(&err.code().to_string()));
    }

    #[test]
    fn test_from_io_error() {
        let io_err = std::io::Error::other("test io error");
        let audio_err: AudioError = io_err.into();
        match audio_err {
            AudioError::HardwareError { details } => {
                assert!(details.contains("test io error"));
            }
            _ => panic!("Expected HardwareError"),
        }
    }

    #[test]
    fn test_error_code_getters() {
        assert_eq!(AudioErrorCodes::bpm_invalid(), 1001);
        assert_eq!(AudioErrorCodes::already_running(), 1002);
        assert_eq!(AudioErrorCodes::not_running(), 1003);
        assert_eq!(AudioErrorCodes::hardware_error(), 1004);
        assert_eq!(AudioErrorCodes::permission_denied(), 1005);
        assert_eq!(AudioErrorCodes::stream_open_failed(), 1006);
        assert_eq!(AudioErrorCodes::lock_poisoned(), 1007);
        assert_eq!(AudioErrorCodes::jni_init_failed(), 1008);
        assert_eq!(AudioErrorCodes::context_not_initialized(), 1009);
        assert_eq!(AudioErrorCodes::stream_failure(), 1010);
    }
}
