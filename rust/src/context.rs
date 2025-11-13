// AppContext: Dependency Injection Container
// Centralizes all global state for testability and clean architecture

use std::sync::{Arc, Mutex, RwLock};
use tokio::sync::{broadcast, mpsc};
use tokio_stream::wrappers::UnboundedReceiverStream;

use crate::analysis::ClassificationResult;
#[cfg(target_os = "android")]
use crate::audio::{buffer_pool::BufferPool, engine::AudioEngine};
use crate::calibration::{
    procedure::{CalibrationProcedure, CalibrationProgress},
    state::CalibrationState,
};
use crate::error::{log_audio_error, log_calibration_error, AudioError, CalibrationError};

/// AudioEngine state container for lifecycle management
struct AudioEngineState {
    #[cfg(target_os = "android")]
    engine: AudioEngine,
    #[cfg(not(target_os = "android"))]
    _dummy: (),
}

/// AppContext: Dependency injection container for all application state
///
/// Consolidates 5 global statics into a single, testable context:
/// - AudioEngine lifecycle management
/// - CalibrationProcedure workflow
/// - CalibrationState shared between calibration and classification
/// - Classification result broadcast channel
/// - Calibration progress broadcast channel
///
/// Benefits:
/// - Single point of truth for application state
/// - Testable with mock dependencies
/// - Graceful lock error handling (no unwrap/expect)
/// - Clear ownership and lifecycle management
pub struct AppContext {
    audio_engine: Arc<Mutex<Option<AudioEngineState>>>,
    calibration_procedure: Arc<Mutex<Option<CalibrationProcedure>>>,
    calibration_state: Arc<RwLock<CalibrationState>>,
    classification_broadcast: Arc<Mutex<Option<broadcast::Sender<ClassificationResult>>>>,
    calibration_broadcast: Arc<Mutex<Option<broadcast::Sender<CalibrationProgress>>>>,
}

impl AppContext {
    /// Create a new AppContext with default initialization
    ///
    /// Initializes all state containers to empty/default values:
    /// - No audio engine running
    /// - No calibration in progress
    /// - Default calibration state
    /// - No broadcast channels active
    pub fn new() -> Self {
        Self {
            audio_engine: Arc::new(Mutex::new(None)),
            calibration_procedure: Arc::new(Mutex::new(None)),
            calibration_state: Arc::new(RwLock::new(CalibrationState::new_default())),
            classification_broadcast: Arc::new(Mutex::new(None)),
            calibration_broadcast: Arc::new(Mutex::new(None)),
        }
    }

    // ========================================================================
    // LOCK HELPER METHODS
    // Safe lock acquisition with typed error handling (no unwrap/expect)
    // ========================================================================

    /// Safely acquire lock on audio engine state
    ///
    /// Returns MutexGuard or AudioError::LockPoisoned on lock failure
    fn lock_audio_engine(
        &self,
    ) -> Result<std::sync::MutexGuard<Option<AudioEngineState>>, AudioError> {
        self.audio_engine
            .lock()
            .map_err(|_| AudioError::LockPoisoned {
                component: "audio_engine".to_string(),
            })
    }

    /// Safely acquire lock on calibration procedure
    ///
    /// Returns MutexGuard or CalibrationError::StatePoisoned on lock failure
    fn lock_calibration_procedure(
        &self,
    ) -> Result<std::sync::MutexGuard<Option<CalibrationProcedure>>, CalibrationError> {
        self.calibration_procedure
            .lock()
            .map_err(|_| CalibrationError::StatePoisoned)
    }

    /// Safely acquire read lock on calibration state
    ///
    /// Returns RwLockReadGuard or CalibrationError::StatePoisoned on lock failure
    fn read_calibration(
        &self,
    ) -> Result<std::sync::RwLockReadGuard<CalibrationState>, CalibrationError> {
        self.calibration_state
            .read()
            .map_err(|_| CalibrationError::StatePoisoned)
    }

    /// Safely acquire write lock on calibration state
    ///
    /// Returns RwLockWriteGuard or CalibrationError::StatePoisoned on lock failure
    fn write_calibration(
        &self,
    ) -> Result<std::sync::RwLockWriteGuard<'_, CalibrationState>, CalibrationError> {
        self.calibration_state
            .write()
            .map_err(|_| CalibrationError::StatePoisoned)
    }

    /// Safely acquire lock on classification broadcast sender
    fn lock_classification_broadcast(
        &self,
    ) -> Result<
        std::sync::MutexGuard<'_, Option<broadcast::Sender<ClassificationResult>>>,
        AudioError,
    > {
        self.classification_broadcast
            .lock()
            .map_err(|_| AudioError::LockPoisoned {
                component: "classification_broadcast".to_string(),
            })
    }

    // ========================================================================
    // BUSINESS LOGIC METHODS - AUDIO ENGINE
    // ========================================================================

    /// Start the audio engine with specified BPM
    ///
    /// Initializes the audio engine, starts full-duplex audio streams with Oboe,
    /// spawns the analysis thread, and begins metronome generation.
    ///
    /// # Arguments
    /// * `bpm` - Beats per minute (typically 40-240)
    ///
    /// # Returns
    /// * `Ok(())` - Audio engine started successfully
    /// * `Err(AudioError)` - Error if initialization fails
    ///
    /// # Errors
    /// - Audio streams cannot be opened (device busy, permissions denied)
    /// - Audio engine already running (call stop_audio first)
    /// - Invalid BPM value (must be > 0)
    /// - Lock poisoning on shared state
    pub fn start_audio(&self, bpm: u32) -> Result<(), AudioError> {
        #[cfg(not(target_os = "android"))]
        {
            let err = AudioError::HardwareError {
                details: "Audio engine only supported on Android".to_string(),
            };
            log_audio_error(&err, "start_audio");
            return Err(err);
        }

        #[cfg(target_os = "android")]
        {
            // Validate BPM
            if bpm == 0 {
                let err = AudioError::BpmInvalid { bpm };
                log_audio_error(&err, "start_audio");
                return Err(err);
            }

            // Acquire engine lock
            let mut engine_guard = self.lock_audio_engine().map_err(|err| {
                log_audio_error(&err, "start_audio");
                err
            })?;

            // Check if already running
            if engine_guard.is_some() {
                let err = AudioError::AlreadyRunning;
                log_audio_error(&err, "start_audio");
                return Err(err);
            }

            // Create classification result channels
            // - mpsc channel for analysis thread to send results
            // - broadcast channel for multiple UI subscribers
            let (classification_tx, mut classification_rx) = mpsc::unbounded_channel();
            let (broadcast_tx, _broadcast_rx) = broadcast::channel(100);

            // Store broadcast sender for classification_stream
            {
                let mut sender_guard = self.lock_classification_broadcast().map_err(|err| {
                    log_audio_error(&err, "start_audio");
                    err
                })?;
                *sender_guard = Some(broadcast_tx.clone());
            }

            // Spawn forwarder task: mpsc → broadcast
            let broadcast_tx_clone = broadcast_tx.clone();
            tokio::spawn(async move {
                while let Some(result) = classification_rx.recv().await {
                    // Broadcast to all subscribers (ignore if no subscribers)
                    let _ = broadcast_tx_clone.send(result);
                }
            });

            // Initialize buffer pool (16 buffers of 2048 samples)
            let buffer_pool = BufferPool::new(16, 2048);
            let buffer_channels = buffer_pool;

            // Create AudioEngine (takes ownership of buffer_channels)
            let sample_rate = 48000; // Standard sample rate for Android
            let mut engine =
                AudioEngine::new(bpm, sample_rate, buffer_channels).map_err(|err| {
                    log_audio_error(&err, "start_audio");
                    err
                })?;

            // Get calibration state for AudioEngine::start()
            let calibration = Arc::clone(&self.calibration_state);

            // Start audio streams (AudioEngine::start spawns analysis thread internally)
            engine
                .start(calibration, classification_tx)
                .map_err(|err| {
                    log_audio_error(&err, "start_audio");
                    err
                })?;

            // Store engine state
            *engine_guard = Some(AudioEngineState { engine });

            Ok(())
        }
    }

    /// Stop the audio engine
    ///
    /// Stops audio streams, shuts down the analysis thread, and releases resources.
    /// Safe to call even if audio engine is not running.
    ///
    /// # Returns
    /// * `Ok(())` - Audio engine stopped successfully or was not running
    /// * `Err(AudioError)` - Error if shutdown fails or lock poisoning
    pub fn stop_audio(&self) -> Result<(), AudioError> {
        #[cfg(not(target_os = "android"))]
        {
            let err = AudioError::HardwareError {
                details: "Audio engine only supported on Android".to_string(),
            };
            log_audio_error(&err, "stop_audio");
            return Err(err);
        }

        #[cfg(target_os = "android")]
        {
            let mut engine_guard = self.lock_audio_engine().map_err(|err| {
                log_audio_error(&err, "stop_audio");
                err
            })?;

            if let Some(mut state) = engine_guard.take() {
                // Stop audio streams (AudioEngine manages analysis thread cleanup)
                state.engine.stop().map_err(|err| {
                    log_audio_error(&err, "stop_audio");
                    err
                })?;

                // Clear classification broadcast sender to signal stream end
                {
                    let mut sender_guard = self.lock_classification_broadcast().map_err(|err| {
                        log_audio_error(&err, "stop_audio");
                        err
                    })?;
                    *sender_guard = None;
                }
            }

            Ok(())
        }
    }

    /// Set BPM dynamically during audio playback
    ///
    /// Updates the metronome tempo. Note: This currently requires audio engine restart
    /// to maintain real-time safety guarantees.
    ///
    /// # Arguments
    /// * `bpm` - New beats per minute (typically 40-240)
    ///
    /// # Returns
    /// * `Ok(())` - BPM updated successfully
    /// * `Err(AudioError)` - Error if update fails
    ///
    /// # Errors
    /// - Audio engine not running
    /// - Invalid BPM value (must be > 0)
    /// - Lock poisoning on audio engine state
    pub fn set_bpm(&self, bpm: u32) -> Result<(), AudioError> {
        #[cfg(not(target_os = "android"))]
        {
            let err = AudioError::HardwareError {
                details: "Audio engine only supported on Android".to_string(),
            };
            log_audio_error(&err, "set_bpm");
            return Err(err);
        }

        #[cfg(target_os = "android")]
        {
            if bpm == 0 {
                let err = AudioError::BpmInvalid { bpm };
                log_audio_error(&err, "set_bpm");
                return Err(err);
            }

            let engine_guard = self.lock_audio_engine().map_err(|err| {
                log_audio_error(&err, "set_bpm");
                err
            })?;

            if let Some(state) = engine_guard.as_ref() {
                state.engine.set_bpm(bpm);
                Ok(())
            } else {
                let err = AudioError::NotRunning;
                log_audio_error(&err, "set_bpm");
                Err(err)
            }
        }
    }

    // ========================================================================
    // BUSINESS LOGIC METHODS - CALIBRATION
    // ========================================================================

    /// Start calibration workflow
    ///
    /// Begins collecting samples for calibration. The system will detect onsets
    /// and extract features without classifying. Collect 10 samples per sound type.
    ///
    /// Calibration sequence: KICK → SNARE → HI-HAT
    ///
    /// # Returns
    /// * `Ok(())` - Calibration started
    /// * `Err(CalibrationError)` - Error if calibration cannot start
    ///
    /// # Errors
    /// - Calibration already in progress
    /// - Lock poisoning on calibration procedure state
    pub fn start_calibration(&self) -> Result<(), CalibrationError> {
        let mut procedure_guard = self.lock_calibration_procedure().map_err(|err| {
            log_calibration_error(&err, "start_calibration");
            err
        })?;

        if procedure_guard.is_some() {
            let err = CalibrationError::AlreadyInProgress;
            log_calibration_error(&err, "start_calibration");
            return Err(err);
        }

        // Create new calibration procedure (starts with KICK by default)
        let procedure = CalibrationProcedure::new_default();
        *procedure_guard = Some(procedure);

        Ok(())
    }

    /// Finish calibration and compute thresholds
    ///
    /// Completes the calibration process, computes thresholds from collected samples,
    /// and updates the global CalibrationState used by the classifier.
    ///
    /// # Returns
    /// * `Ok(())` - Calibration completed successfully
    /// * `Err(CalibrationError)` - Error if calibration incomplete or invalid
    ///
    /// # Errors
    /// - Calibration not in progress
    /// - Insufficient samples collected (need 10 per sound type)
    /// - Sample validation failed (out of range features)
    /// - Lock poisoning on calibration state
    pub fn finish_calibration(&self) -> Result<(), CalibrationError> {
        let mut procedure_guard = self.lock_calibration_procedure().map_err(|err| {
            log_calibration_error(&err, "finish_calibration");
            err
        })?;

        if let Some(procedure) = procedure_guard.take() {
            // Compute calibrated state from collected samples
            let new_state = procedure.finalize().map_err(|err| {
                log_calibration_error(&err, "finish_calibration");
                err
            })?;

            // Update global calibration state
            let mut state_guard = self.write_calibration().map_err(|err| {
                log_calibration_error(&err, "finish_calibration");
                err
            })?;
            *state_guard = new_state;

            Ok(())
        } else {
            let err = CalibrationError::NotComplete;
            log_calibration_error(&err, "finish_calibration");
            Err(err)
        }
    }

    // ========================================================================
    // STREAM METHODS
    // ========================================================================

    /// Stream of classification results
    ///
    /// Returns a stream that yields ClassificationResult on each detected onset.
    /// Each result contains the detected sound type (KICK/SNARE/HIHAT/UNKNOWN)
    /// and timing feedback (ON_TIME/EARLY/LATE with error in milliseconds).
    ///
    /// # Returns
    /// Stream<ClassificationResult> that yields results until audio engine stops
    pub async fn classification_stream(&self) -> impl futures::Stream<Item = ClassificationResult> {
        use futures::stream::StreamExt;

        // Subscribe to broadcast channel
        let receiver = {
            match self.classification_broadcast.lock() {
                Ok(sender_guard) => {
                    if let Some(broadcast_sender) = sender_guard.as_ref() {
                        Some(broadcast_sender.subscribe())
                    } else {
                        None
                    }
                }
                Err(_) => {
                    // Lock poisoned - return None to produce empty stream
                    log::error!("Classification broadcast lock poisoned");
                    None
                }
            }
        };

        if let Some(rx) = receiver {
            // Create stream from broadcast receiver
            futures::stream::unfold(rx, |mut rx| async move {
                match rx.recv().await {
                    Ok(result) => Some((result, rx)),
                    Err(_) => None, // Channel closed or lagged
                }
            })
            .boxed()
        } else {
            // Return empty stream if broadcast not initialized
            futures::stream::empty().boxed()
        }
    }

    /// Stream of calibration progress updates
    ///
    /// Returns a stream that yields CalibrationProgress as samples are collected.
    /// Each progress update contains the current sound being calibrated and
    /// the number of samples collected (0-10).
    ///
    /// # Returns
    /// Stream<CalibrationProgress> that yields progress updates
    pub async fn calibration_stream(&self) -> impl futures::Stream<Item = CalibrationProgress> {
        let (tx, rx) = mpsc::unbounded_channel();

        // Clone Arc for the spawned task
        let procedure = Arc::clone(&self.calibration_procedure);

        // Spawn task to poll calibration progress and broadcast updates
        tokio::spawn(async move {
            let mut last_progress: Option<CalibrationProgress> = None;

            loop {
                let progress = {
                    match procedure.lock() {
                        Ok(procedure_guard) => {
                            if let Some(procedure) = procedure_guard.as_ref() {
                                Some(procedure.get_progress())
                            } else {
                                None
                            }
                        }
                        Err(_) => {
                            // Lock poisoned - log error and break to end the polling loop
                            log::error!("Calibration procedure lock poisoned");
                            break;
                        }
                    }
                };

                // Only send if progress changed or this is the first update
                if let Some(current_progress) = progress {
                    let should_send = match &last_progress {
                        None => true,
                        Some(last) => {
                            last.current_sound != current_progress.current_sound
                                || last.samples_collected != current_progress.samples_collected
                        }
                    };

                    if should_send {
                        if tx.send(current_progress.clone()).is_err() {
                            break; // Stream closed
                        }
                        last_progress = Some(current_progress);
                    }
                } else if last_progress.is_some() {
                    // Calibration procedure ended
                    break;
                }

                tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
            }
        });

        UnboundedReceiverStream::new(rx)
    }
}

impl Default for AppContext {
    fn default() -> Self {
        Self::new()
    }
}

// ========================================================================
// TEST SUPPORT
// ========================================================================

#[cfg(test)]
impl AppContext {
    /// Create a new AppContext for isolated testing
    ///
    /// Each test gets its own independent context, preventing state leakage
    /// between tests and enabling parallel test execution.
    ///
    /// # Example
    /// ```
    /// let ctx = AppContext::new_test();
    /// // Test with isolated state
    /// assert!(ctx.lock_audio_engine().unwrap().is_none());
    /// ```
    pub fn new_test() -> Self {
        Self::new()
    }

    /// Reset AppContext to initial state (cleanup between tests)
    ///
    /// Useful for test cleanup or when reusing a context across test scenarios.
    /// In practice, prefer new_test() for better isolation.
    ///
    /// # Example
    /// ```
    /// let ctx = AppContext::new_test();
    /// ctx.start_calibration().ok();
    /// ctx.reset(); // Clean slate
    /// assert!(ctx.lock_calibration_procedure().unwrap().is_none());
    /// ```
    #[allow(dead_code)]
    pub fn reset(&self) {
        // Clean up audio engine (stopping if necessary)
        #[cfg(target_os = "android")]
        {
            if let Ok(mut guard) = self.audio_engine.lock() {
                if let Some(mut state) = guard.take() {
                    let _ = state.engine.stop(); // Gracefully stop before cleanup
                }
            }
        }
        #[cfg(not(target_os = "android"))]
        {
            if let Ok(mut guard) = self.audio_engine.lock() {
                *guard = None;
            }
        }

        // Clean up calibration procedure
        if let Ok(mut guard) = self.calibration_procedure.lock() {
            *guard = None;
        }

        // Reset calibration state to default
        if let Ok(mut guard) = self.calibration_state.write() {
            *guard = CalibrationState::new_default();
        }

        // Clear classification broadcast channel
        if let Ok(mut guard) = self.classification_broadcast.lock() {
            *guard = None;
        }

        // Clear calibration broadcast channel
        if let Ok(mut guard) = self.calibration_broadcast.lock() {
            *guard = None;
        }
    }

    /// Create AppContext with mock calibration state for testing
    ///
    /// Useful for testing classification logic without running full calibration.
    /// The provided calibration state is immediately available for use.
    ///
    /// # Arguments
    /// * `state` - Pre-configured CalibrationState to use
    ///
    /// # Example
    /// ```
    /// let mock_state = CalibrationState::new_default();
    /// let ctx = AppContext::with_mock_calibration(mock_state);
    /// // Classification can proceed without calibration workflow
    /// ```
    #[allow(dead_code)]
    pub fn with_mock_calibration(state: CalibrationState) -> Self {
        Self {
            audio_engine: Arc::new(Mutex::new(None)),
            calibration_procedure: Arc::new(Mutex::new(None)),
            calibration_state: Arc::new(RwLock::new(state)),
            classification_broadcast: Arc::new(Mutex::new(None)),
            calibration_broadcast: Arc::new(Mutex::new(None)),
        }
    }

    /// Get a clone of the current calibration state (for test assertions)
    ///
    /// Useful for verifying calibration state changes in tests.
    ///
    /// # Returns
    /// * `Some(CalibrationState)` - Clone of current state
    /// * `None` - If lock is poisoned
    ///
    /// # Example
    /// ```
    /// let ctx = AppContext::new_test();
    /// ctx.start_calibration().ok();
    /// ctx.finish_calibration().ok();
    /// let state = ctx.get_calibration_state_for_test();
    /// assert!(state.is_some());
    /// ```
    #[allow(dead_code)]
    pub fn get_calibration_state_for_test(&self) -> Option<CalibrationState> {
        self.calibration_state
            .read()
            .ok()
            .map(|guard| guard.clone())
    }

    /// Check if audio engine is currently running (for test assertions)
    ///
    /// # Returns
    /// * `Some(true)` - Engine is running
    /// * `Some(false)` - Engine is not running
    /// * `None` - If lock is poisoned
    ///
    /// # Example
    /// ```
    /// let ctx = AppContext::new_test();
    /// assert_eq!(ctx.is_audio_running_for_test(), Some(false));
    /// ```
    #[allow(dead_code)]
    pub fn is_audio_running_for_test(&self) -> Option<bool> {
        self.audio_engine.lock().ok().map(|guard| guard.is_some())
    }

    /// Check if calibration is currently in progress (for test assertions)
    ///
    /// # Returns
    /// * `Some(true)` - Calibration in progress
    /// * `Some(false)` - No calibration in progress
    /// * `None` - If lock is poisoned
    ///
    /// # Example
    /// ```
    /// let ctx = AppContext::new_test();
    /// ctx.start_calibration().ok();
    /// assert_eq!(ctx.is_calibration_active_for_test(), Some(true));
    /// ```
    #[allow(dead_code)]
    pub fn is_calibration_active_for_test(&self) -> Option<bool> {
        self.calibration_procedure
            .lock()
            .ok()
            .map(|guard| guard.is_some())
    }

    /// Create isolated test context with all channels initialized
    ///
    /// Pre-initializes broadcast channels for testing stream behavior
    /// without starting the full audio engine.
    ///
    /// # Example
    /// ```
    /// let ctx = AppContext::new_test_with_channels();
    /// // Can test stream subscription without audio engine
    /// ```
    #[allow(dead_code)]
    pub fn new_test_with_channels() -> Self {
        let ctx = Self::new();

        // Pre-initialize classification broadcast channel
        let (broadcast_tx, _) = broadcast::channel(100);
        if let Ok(mut guard) = ctx.classification_broadcast.lock() {
            *guard = Some(broadcast_tx);
        }

        ctx
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_appcontext_new() {
        let ctx = AppContext::new();
        // Verify initial state
        assert!(ctx.lock_audio_engine().unwrap().is_none());
        assert!(ctx.lock_calibration_procedure().unwrap().is_none());
        assert!(ctx.lock_classification_broadcast().unwrap().is_none());
    }

    #[test]
    fn test_appcontext_new_test() {
        let ctx = AppContext::new_test();
        assert!(ctx.lock_audio_engine().unwrap().is_none());
        assert!(ctx.lock_calibration_procedure().unwrap().is_none());
    }

    #[test]
    fn test_lock_helpers_return_errors() {
        let ctx = AppContext::new();
        // All lock helpers should succeed on non-poisoned locks
        assert!(ctx.lock_audio_engine().is_ok());
        assert!(ctx.lock_calibration_procedure().is_ok());
        assert!(ctx.read_calibration().is_ok());
        assert!(ctx.write_calibration().is_ok());
        assert!(ctx.lock_classification_broadcast().is_ok());
    }

    // ========================================================================
    // TEST HELPER TESTS
    // ========================================================================

    #[test]
    fn test_reset_clears_all_state() {
        let ctx = AppContext::new_test();

        // Start calibration to populate state
        ctx.start_calibration().ok();
        assert!(ctx.lock_calibration_procedure().unwrap().is_some());

        // Reset should clear everything
        ctx.reset();
        assert!(ctx.lock_calibration_procedure().unwrap().is_none());
        assert!(ctx.lock_audio_engine().unwrap().is_none());
        assert!(ctx.lock_classification_broadcast().unwrap().is_none());
    }

    #[test]
    fn test_with_mock_calibration() {
        let mut mock_state = CalibrationState::new_default();
        mock_state.is_calibrated = true; // Mark as calibrated for testing
        let ctx = AppContext::with_mock_calibration(mock_state);

        // Verify calibration state is available
        let state = ctx.read_calibration().unwrap();
        assert!(state.is_calibrated); // Verify the mock state is set
    }

    #[test]
    fn test_get_calibration_state_for_test() {
        let ctx = AppContext::new_test();
        let state = ctx.get_calibration_state_for_test();
        assert!(state.is_some());
    }

    #[test]
    fn test_is_audio_running_for_test() {
        let ctx = AppContext::new_test();
        assert_eq!(ctx.is_audio_running_for_test(), Some(false));
    }

    #[test]
    fn test_is_calibration_active_for_test() {
        let ctx = AppContext::new_test();
        assert_eq!(ctx.is_calibration_active_for_test(), Some(false));

        ctx.start_calibration().ok();
        assert_eq!(ctx.is_calibration_active_for_test(), Some(true));
    }

    #[test]
    fn test_new_test_with_channels() {
        let ctx = AppContext::new_test_with_channels();
        // Verify classification broadcast channel is initialized
        assert!(ctx.lock_classification_broadcast().unwrap().is_some());
    }

    #[test]
    fn test_parallel_test_isolation() {
        // Test that multiple test contexts don't interfere
        let ctx1 = AppContext::new_test();
        let ctx2 = AppContext::new_test();

        ctx1.start_calibration().ok();
        // ctx2 should still be independent
        assert_eq!(ctx1.is_calibration_active_for_test(), Some(true));
        assert_eq!(ctx2.is_calibration_active_for_test(), Some(false));
    }

    #[test]
    fn test_reset_idempotent() {
        let ctx = AppContext::new_test();
        ctx.reset();
        ctx.reset(); // Should not panic or cause issues
        assert!(ctx.lock_audio_engine().unwrap().is_none());
    }
}
