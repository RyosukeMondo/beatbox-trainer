// AppContext: Dependency Injection Container (Facade Pattern)
//
// Refactored to compose focused manager classes following Single Responsibility Principle.
// Reduced from 1495 lines to < 200 lines by delegating to:
// - AudioEngineManager: Audio engine lifecycle and BPM management
// - CalibrationManager: Calibration workflow and state persistence
// - BroadcastChannelManager: Tokio broadcast channel management

use tokio::sync::mpsc;
use tokio_stream::wrappers::UnboundedReceiverStream;

use crate::analysis::ClassificationResult;
use crate::api::{AudioMetrics, OnsetEvent};
use crate::calibration::{CalibrationProgress, CalibrationState};
use crate::error::{AudioError, CalibrationError};
use crate::managers::{AudioEngineManager, BroadcastChannelManager, CalibrationManager};

/// AppContext: Dependency injection container for all application state
///
/// Facade pattern: delegates to focused managers for each responsibility.
/// Maintains the same public API as before refactoring.
///
/// Benefits:
/// - Single point of truth for application state
/// - Testable with mock dependencies
/// - Clear separation of concerns
/// - Reduced complexity (< 200 lines vs 1495 lines)
pub struct AppContext {
    #[cfg_attr(not(target_os = "android"), allow(dead_code))]
    audio: AudioEngineManager,
    calibration: CalibrationManager,
    pub(crate) broadcasts: BroadcastChannelManager,
}

impl AppContext {
    /// Create a new AppContext with default initialization
    ///
    /// Initializes all managers with empty/default state:
    /// - No audio engine running
    /// - No calibration in progress
    /// - Default calibration state
    /// - No broadcast channels active
    pub fn new() -> Self {
        Self {
            audio: AudioEngineManager::new(),
            calibration: CalibrationManager::new(),
            broadcasts: BroadcastChannelManager::new(),
        }
    }

    // ========================================================================
    // AUDIO ENGINE METHODS (delegate to AudioEngineManager)
    // ========================================================================

    /// Start the audio engine with specified BPM
    ///
    /// Validates BPM, creates engine with buffer pool, starts audio streams.
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
    #[cfg_attr(not(target_os = "android"), allow(unused_variables))]
    pub fn start_audio(&self, bpm: u32) -> Result<(), AudioError> {
        #[cfg(not(target_os = "android"))]
        {
            use crate::error::log_audio_error;
            let err = AudioError::HardwareError {
                details: "Audio engine only supported on Android".to_string(),
            };
            log_audio_error(&err, "start_audio");
            Err(err)
        }

        #[cfg(target_os = "android")]
        {
            // Initialize classification broadcast channel
            let broadcast_tx = self.broadcasts.init_classification();

            // Get calibration state for classification
            let calibration_state = self.calibration.get_state_arc();

            // Get calibration procedure for analysis thread
            let calibration_procedure = self.calibration.get_procedure_arc();

            // Get optional calibration progress sender
            let calibration_progress_tx = self.broadcasts.get_calibration_sender();

            // Start audio engine (delegates to AudioEngineManager)
            // Audio engine now sends directly to broadcast channel, eliminating mpsc → broadcast forwarding
            self.audio.start(
                bpm,
                calibration_state,
                calibration_procedure,
                calibration_progress_tx,
                broadcast_tx,
            )
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
            use crate::error::log_audio_error;
            let err = AudioError::HardwareError {
                details: "Audio engine only supported on Android".to_string(),
            };
            log_audio_error(&err, "stop_audio");
            Err(err)
        }

        #[cfg(target_os = "android")]
        {
            self.audio.stop()
        }
    }

    /// Set BPM dynamically during audio playback
    ///
    /// Updates the metronome tempo. Note: This currently requires audio engine restart
    /// to maintain real-time safety guarantees.
    ///
    /// # Arguments
    /// * `bpm` - New tempo in beats per minute (typically 40-240)
    ///
    /// # Returns
    /// * `Ok(())` - BPM updated successfully
    /// * `Err(AudioError)` - Error if update fails
    ///
    /// # Errors
    /// - Invalid BPM value (must be > 0)
    /// - Audio engine not running
    /// - Lock poisoning on shared state
    #[cfg_attr(not(target_os = "android"), allow(unused_variables))]
    pub fn set_bpm(&self, bpm: u32) -> Result<(), AudioError> {
        #[cfg(not(target_os = "android"))]
        {
            use crate::error::log_audio_error;
            let err = AudioError::HardwareError {
                details: "Audio engine only supported on Android".to_string(),
            };
            log_audio_error(&err, "set_bpm");
            Err(err)
        }

        #[cfg(target_os = "android")]
        {
            self.audio.set_bpm(bpm)
        }
    }

    // ========================================================================
    // CALIBRATION METHODS (delegate to CalibrationManager)
    // ========================================================================

    /// Load existing calibration state
    ///
    /// Updates the calibration state used by the classifier.
    ///
    /// # Arguments
    /// * `state` - Calibration state to load
    ///
    /// # Returns
    /// * `Ok(())` - Calibration state loaded
    /// * `Err(CalibrationError)` - Error if load fails
    pub fn load_calibration(&self, state: CalibrationState) -> Result<(), CalibrationError> {
        self.calibration.load_state(state)
    }

    /// Get current calibration state
    ///
    /// Returns the calibration state used by the classifier.
    ///
    /// # Returns
    /// * `Ok(CalibrationState)` - Current calibration state
    /// * `Err(CalibrationError)` - Error if retrieval fails
    pub fn get_calibration_state(&self) -> Result<CalibrationState, CalibrationError> {
        self.calibration.get_state()
    }

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
        // Initialize calibration broadcast channel
        let broadcast_tx = self.broadcasts.init_calibration();

        // Start calibration (delegates to CalibrationManager)
        self.calibration.start(broadcast_tx)?;

        // Restart audio engine to ensure analysis thread receives calibration procedure
        #[cfg(target_os = "android")]
        {
            // Stop audio engine if currently running
            // Log errors as warnings but don't fail - engine may not be running
            if let Err(err) = self.stop_audio() {
                eprintln!(
                    "Warning: Failed to stop audio engine during calibration start: {:?}",
                    err
                );
            }

            // Start audio engine with calibration procedure active
            const DEFAULT_CALIBRATION_BPM: u32 = 120;
            self.start_audio(DEFAULT_CALIBRATION_BPM)
                .map_err(|audio_err| CalibrationError::AudioEngineError {
                    details: format!(
                        "Failed to start audio engine for calibration: {:?}",
                        audio_err
                    ),
                })?;
        }

        Ok(())
    }

    /// Finish calibration and compute thresholds
    ///
    /// Completes the calibration process, computes thresholds from collected samples,
    /// and updates the calibration state used by the classifier.
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
        self.calibration.finish()
    }

    // ========================================================================
    // STREAM SUBSCRIPTION METHODS (delegate to BroadcastChannelManager)
    // ========================================================================

    /// Subscribe to classification result stream
    ///
    /// Returns a receiver for consuming real-time classification results from the
    /// audio engine. Each subscriber receives independent copies via broadcast channel.
    ///
    /// The audio engine sends directly to the broadcast channel, and this method forwards
    /// to an mpsc channel for Flutter FFI compatibility.
    ///
    /// # Returns
    /// `mpsc::UnboundedReceiver<ClassificationResult>` - Stream of classification results
    ///
    /// # Notes
    /// - Returns receiver immediately (creates mpsc channel on-demand)
    /// - If classification broadcast not initialized, receiver will never receive messages
    /// - Stream ends when audio engine stops
    pub fn subscribe_classification(&self) -> mpsc::UnboundedReceiver<ClassificationResult> {
        let (tx, rx) = mpsc::unbounded_channel();

        if let Some(mut broadcast_rx) = self.broadcasts.subscribe_classification() {
            tokio::spawn(async move {
                while let Ok(result) = broadcast_rx.recv().await {
                    if tx.send(result).is_err() {
                        // Subscriber dropped, stop forwarding
                        break;
                    }
                }
            });
        }

        rx
    }

    /// Subscribe to calibration progress stream
    ///
    /// Returns a receiver for consuming calibration progress updates during the
    /// calibration workflow. Each subscriber receives independent copies.
    ///
    /// The stream forwards progress updates from the calibration procedure using
    /// a tokio broadcast → mpsc pattern for Flutter compatibility.
    ///
    /// # Returns
    /// `mpsc::UnboundedReceiver<CalibrationProgress>` - Stream of progress updates
    ///
    /// # Notes
    /// - Returns receiver immediately (creates mpsc channel on-demand)
    /// - If calibration broadcast not initialized, receiver will never receive messages
    /// - Stream ends when calibration finishes or is cancelled
    pub fn subscribe_calibration(&self) -> mpsc::UnboundedReceiver<CalibrationProgress> {
        let (tx, rx) = mpsc::unbounded_channel();

        if let Some(mut broadcast_rx) = self.broadcasts.subscribe_calibration() {
            tokio::spawn(async move {
                while let Ok(progress) = broadcast_rx.recv().await {
                    if tx.send(progress).is_err() {
                        // Subscriber dropped, stop forwarding
                        break;
                    }
                }
            });
        }

        rx
    }

    // ========================================================================
    // DEBUG STREAM METHODS (delegate to BroadcastChannelManager)
    // ========================================================================

    /// Subscribe to audio metrics stream (debug)
    ///
    /// Returns a stream for consuming real-time audio analysis metrics.
    /// Used for debugging and visualization.
    ///
    /// # Returns
    /// Stream that yields AudioMetrics while audio engine is running
    ///
    /// # Notes
    /// - Stream initialized automatically when audio engine starts
    /// - Returns empty stream if audio engine not running
    pub async fn audio_metrics_stream(&self) -> impl futures::Stream<Item = AudioMetrics> + Unpin {
        let (tx, rx) = mpsc::unbounded_channel();

        if let Some(mut broadcast_rx) = self.broadcasts.subscribe_audio_metrics() {
            tokio::spawn(async move {
                while let Ok(metrics) = broadcast_rx.recv().await {
                    if tx.send(metrics).is_err() {
                        break;
                    }
                }
            });
        }

        UnboundedReceiverStream::new(rx)
    }

    /// Subscribe to onset events stream (debug)
    ///
    /// Returns a stream for consuming onset detection events.
    /// Used for debugging and visualization.
    ///
    /// # Returns
    /// Stream that yields OnsetEvent while audio engine is running
    ///
    /// # Notes
    /// - Stream initialized automatically when audio engine starts
    /// - Returns empty stream if audio engine not running
    pub async fn onset_events_stream(&self) -> impl futures::Stream<Item = OnsetEvent> + Unpin {
        let (tx, rx) = mpsc::unbounded_channel();

        if let Some(mut broadcast_rx) = self.broadcasts.subscribe_onset_events() {
            tokio::spawn(async move {
                while let Ok(event) = broadcast_rx.recv().await {
                    if tx.send(event).is_err() {
                        break;
                    }
                }
            });
        }

        UnboundedReceiverStream::new(rx)
    }

    // ========================================================================
    // ASYNC STREAM METHODS (for FFI/testing compatibility)
    // ========================================================================

    /// Get classification stream as async stream
    ///
    /// Returns a stream for consuming real-time classification results.
    /// This is an async wrapper around subscribe_classification() for FFI compatibility.
    ///
    /// # Returns
    /// Stream that yields ClassificationResult while audio engine is running
    pub async fn classification_stream(
        &self,
    ) -> impl futures::Stream<Item = ClassificationResult> + Unpin {
        UnboundedReceiverStream::new(self.subscribe_classification())
    }

    /// Get calibration stream as async stream
    ///
    /// Returns a stream for consuming calibration progress updates.
    /// This is an async wrapper around subscribe_calibration() for FFI compatibility.
    ///
    /// # Returns
    /// Stream that yields CalibrationProgress during calibration
    pub async fn calibration_stream(
        &self,
    ) -> impl futures::Stream<Item = CalibrationProgress> + Unpin {
        UnboundedReceiverStream::new(self.subscribe_calibration())
    }
}

// ========================================================================
// TEST HELPERS
// ========================================================================

#[cfg(test)]
impl AppContext {
    /// Create AppContext for testing (same as new())
    pub fn new_test() -> Self {
        Self::new()
    }

    /// Reset all state for test isolation
    ///
    /// Stops audio engine, clears calibration, resets to default state.
    /// Used between test cases to ensure clean state.
    pub fn reset(&self) {
        // Stop audio if running (ignore errors in test cleanup)
        let _ = self.stop_audio();

        // Reset calibration to default
        let _ = self.load_calibration(CalibrationState::new_default());
    }

    /// Create AppContext with mock calibration state for testing
    pub fn with_mock_calibration(state: CalibrationState) -> Self {
        let ctx = Self::new();
        let _ = ctx.load_calibration(state);
        ctx
    }

    /// Get calibration state for testing (returns copy)
    pub fn get_calibration_state_for_test(&self) -> Option<CalibrationState> {
        self.get_calibration_state().ok()
    }

    /// Check if audio engine is running (test helper)
    pub fn is_audio_running_for_test(&self) -> Option<bool> {
        // Audio engine doesn't expose running state directly
        // Attempt to start with invalid BPM will fail if running
        match self.start_audio(0) {
            Err(AudioError::AlreadyRunning) => Some(true),
            Err(AudioError::BpmInvalid { .. }) => Some(false),
            _ => None,
        }
    }

    /// Check if calibration is active (test helper)
    pub fn is_calibration_active_for_test(&self) -> Option<bool> {
        // Attempt to start calibration will fail if already in progress
        match self.start_calibration() {
            Err(CalibrationError::AlreadyInProgress) => Some(true),
            Ok(()) => {
                // Started successfully, so wasn't active before
                // Clean up by finishing it
                let _ = self.finish_calibration();
                Some(false)
            }
            _ => None,
        }
    }

    /// Create AppContext with channels pre-initialized for testing
    pub fn new_test_with_channels() -> Self {
        let ctx = Self::new();
        let _ = ctx.broadcasts.init_classification();
        let _ = ctx.broadcasts.init_calibration();
        ctx
    }
}

impl Default for AppContext {
    fn default() -> Self {
        Self::new()
    }
}
