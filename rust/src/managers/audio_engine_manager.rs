// AudioEngineManager: Focused manager for audio engine lifecycle
//
// Single Responsibility: Audio engine start/stop/configuration
// Extracted from AppContext to reduce complexity and improve testability

use std::sync::{Arc, Mutex, RwLock};
use tokio::sync::broadcast;

use crate::analysis::ClassificationResult;
use crate::calibration::CalibrationState;
use crate::error::{log_audio_error, AudioError};

#[cfg(target_os = "android")]
use crate::audio::{buffer_pool::{BufferPool, BufferPoolChannels}, engine::AudioEngine};

/// AudioEngine state container for lifecycle management
struct AudioEngineState {
    #[cfg(target_os = "android")]
    engine: AudioEngine,
    #[cfg(not(target_os = "android"))]
    _dummy: (),
}

/// Manages audio engine lifecycle and state
///
/// Single Responsibility: Audio engine start/stop/configuration
///
/// This manager handles:
/// - Audio engine lifecycle (start/stop)
/// - BPM validation and updates
/// - Integration with classification broadcast channel
/// - Lock management for thread-safe access
///
/// # Example
/// ```ignore
/// let manager = AudioEngineManager::new();
/// manager.start(120, calibration_state, classification_tx, broadcast_tx)?;
/// manager.set_bpm(140)?;
/// manager.stop()?;
/// ```
#[allow(dead_code)] // Methods will be used when integrated into AppContext (task 5.4)
pub struct AudioEngineManager {
    engine: Arc<Mutex<Option<AudioEngineState>>>,
}

#[allow(dead_code)] // Methods will be used when integrated into AppContext (task 5.4)
impl AudioEngineManager {
    /// Create a new AudioEngineManager
    ///
    /// Initializes with no audio engine running.
    pub fn new() -> Self {
        Self {
            engine: Arc::new(Mutex::new(None)),
        }
    }

    /// Start audio engine with specified BPM
    ///
    /// Validates BPM, creates engine with buffer pool, starts audio streams.
    /// Simplified from 86-line method to focused orchestration.
    ///
    /// # Arguments
    /// * `bpm` - Beats per minute (must be > 0)
    /// * `calibration` - Calibration state for classification
    /// * `broadcast_tx` - Broadcast channel for classification results
    ///
    /// # Returns
    /// * `Ok(())` - Audio engine started successfully
    /// * `Err(AudioError)` - Error if validation fails, already running, or start fails
    ///
    /// # Errors
    /// - Invalid BPM (must be > 0)
    /// - Audio engine already running
    /// - Lock poisoning
    /// - Hardware/platform errors
    #[cfg_attr(not(target_os = "android"), allow(unused_variables))]
    pub fn start(
        &self,
        bpm: u32,
        calibration: Arc<RwLock<CalibrationState>>,
        broadcast_tx: broadcast::Sender<ClassificationResult>,
    ) -> Result<(), AudioError> {
        #[cfg(not(target_os = "android"))]
        {
            let err = AudioError::HardwareError {
                details: "Audio engine only supported on Android".to_string(),
            };
            log_audio_error(&err, "start_audio");
            Err(err)
        }

        #[cfg(target_os = "android")]
        {
            self.validate_bpm(bpm)?;

            let mut guard = self.lock_engine()?;
            self.check_not_running(&guard)?;

            let buffer_pool = self.create_buffer_pool();
            let mut engine = self.create_engine(bpm, buffer_pool)?;

            engine.start(calibration, broadcast_tx).map_err(|err| {
                log_audio_error(&err, "start_audio");
                err
            })?;

            *guard = Some(AudioEngineState { engine });

            Ok(())
        }
    }

    /// Stop audio engine gracefully
    ///
    /// Stops audio streams and releases resources.
    /// Safe to call even if engine is not running.
    ///
    /// # Returns
    /// * `Ok(())` - Audio engine stopped successfully or was not running
    /// * `Err(AudioError)` - Error if shutdown fails or lock poisoning
    pub fn stop(&self) -> Result<(), AudioError> {
        #[cfg(not(target_os = "android"))]
        {
            let err = AudioError::HardwareError {
                details: "Audio engine only supported on Android".to_string(),
            };
            log_audio_error(&err, "stop_audio");
            Err(err)
        }

        #[cfg(target_os = "android")]
        {
            let mut guard = self.lock_engine()?;

            if let Some(mut state) = guard.take() {
                state.engine.stop().map_err(|err| {
                    log_audio_error(&err, "stop_audio");
                    err
                })?;
            }

            Ok(())
        }
    }

    /// Update BPM dynamically (engine must be running)
    ///
    /// Updates the metronome tempo. The audio engine must be running.
    ///
    /// # Arguments
    /// * `bpm` - New beats per minute (must be > 0)
    ///
    /// # Returns
    /// * `Ok(())` - BPM updated successfully
    /// * `Err(AudioError)` - Error if validation fails or engine not running
    ///
    /// # Errors
    /// - Invalid BPM (must be > 0)
    /// - Audio engine not running
    /// - Lock poisoning
    #[cfg_attr(not(target_os = "android"), allow(unused_variables))]
    pub fn set_bpm(&self, bpm: u32) -> Result<(), AudioError> {
        #[cfg(not(target_os = "android"))]
        {
            let err = AudioError::HardwareError {
                details: "Audio engine only supported on Android".to_string(),
            };
            log_audio_error(&err, "set_bpm");
            Err(err)
        }

        #[cfg(target_os = "android")]
        {
            self.validate_bpm(bpm)?;

            let guard = self.lock_engine()?;
            let state = guard.as_ref().ok_or_else(|| {
                let err = AudioError::NotRunning;
                log_audio_error(&err, "set_bpm");
                err
            })?;

            state.engine.set_bpm(bpm);
            Ok(())
        }
    }

    // ========================================================================
    // PRIVATE HELPER METHODS
    // Each helper is focused and under 10 lines
    // ========================================================================

    /// Validate BPM is within acceptable range
    ///
    /// # Arguments
    /// * `bpm` - Beats per minute to validate
    ///
    /// # Returns
    /// * `Ok(())` - BPM is valid
    /// * `Err(AudioError::BpmInvalid)` - BPM is 0
    fn validate_bpm(&self, bpm: u32) -> Result<(), AudioError> {
        if bpm == 0 {
            let err = AudioError::BpmInvalid { bpm };
            log_audio_error(&err, "validate_bpm");
            return Err(err);
        }
        Ok(())
    }

    /// Safely acquire lock on audio engine state
    ///
    /// # Returns
    /// * `Ok(MutexGuard)` - Lock acquired successfully
    /// * `Err(AudioError::LockPoisoned)` - Lock is poisoned
    fn lock_engine(
        &self,
    ) -> Result<std::sync::MutexGuard<'_, Option<AudioEngineState>>, AudioError> {
        self.engine.lock().map_err(|_| {
            let err = AudioError::LockPoisoned {
                component: "audio_engine".to_string(),
            };
            log_audio_error(&err, "lock_engine");
            err
        })
    }

    /// Check that audio engine is not already running
    ///
    /// # Arguments
    /// * `guard` - Current engine state
    ///
    /// # Returns
    /// * `Ok(())` - Engine is not running
    /// * `Err(AudioError::AlreadyRunning)` - Engine is already running
    fn check_not_running(&self, guard: &Option<AudioEngineState>) -> Result<(), AudioError> {
        if guard.is_some() {
            let err = AudioError::AlreadyRunning;
            log_audio_error(&err, "check_not_running");
            return Err(err);
        }
        Ok(())
    }

    /// Create buffer pool for audio processing
    ///
    /// # Returns
    /// BufferPoolChannels with 16 buffers of 2048 samples each
    #[cfg(target_os = "android")]
    fn create_buffer_pool(&self) -> BufferPoolChannels {
        BufferPool::new(16, 2048)
    }

    /// Create audio engine instance
    ///
    /// # Arguments
    /// * `bpm` - Beats per minute
    /// * `buffer_channels` - Pre-allocated buffer pool channels
    ///
    /// # Returns
    /// * `Ok(AudioEngine)` - Engine created successfully
    /// * `Err(AudioError)` - Error during engine creation
    #[cfg(target_os = "android")]
    fn create_engine(&self, bpm: u32, buffer_channels: BufferPoolChannels) -> Result<AudioEngine, AudioError> {
        let sample_rate = 48000; // Standard sample rate for Android
        AudioEngine::new(bpm, sample_rate, buffer_channels).map_err(|err| {
            log_audio_error(&err, "create_engine");
            err
        })
    }
}

impl Default for AudioEngineManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_bpm_rejects_zero() {
        let manager = AudioEngineManager::new();
        let result = manager.validate_bpm(0);
        assert!(result.is_err());
        assert!(matches!(
            result.unwrap_err(),
            AudioError::BpmInvalid { bpm: 0 }
        ));
    }

    #[test]
    fn test_validate_bpm_accepts_valid() {
        let manager = AudioEngineManager::new();
        assert!(manager.validate_bpm(120).is_ok());
        assert!(manager.validate_bpm(1).is_ok());
        assert!(manager.validate_bpm(240).is_ok());
    }

    #[test]
    fn test_new_creates_empty_engine() {
        let manager = AudioEngineManager::new();
        let guard = manager.engine.lock().unwrap();
        assert!(guard.is_none());
    }

    #[test]
    fn test_check_not_running_passes_when_empty() {
        let manager = AudioEngineManager::new();
        let result = manager.check_not_running(&None);
        assert!(result.is_ok());
    }
}
