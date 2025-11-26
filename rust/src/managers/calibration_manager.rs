// CalibrationManager: Focused manager for calibration workflow
//
// Single Responsibility: Calibration procedure and state management
// Extracted from AppContext to reduce complexity and improve testability

use std::sync::{Arc, Mutex, RwLock};
use tokio::sync::broadcast;

use crate::calibration::{CalibrationProcedure, CalibrationProgress, CalibrationState};
use crate::config::CalibrationConfig;
use crate::error::{log_calibration_error, CalibrationError};

/// Manages calibration workflow and state persistence
///
/// Single Responsibility: Calibration lifecycle and state management
///
/// This manager handles:
/// - Starting/finishing calibration procedure
/// - Managing calibration procedure state
/// - Loading/retrieving calibration state
/// - Integration with calibration progress broadcast channel
/// - Thread-safe lock management
///
/// # Example
/// ```ignore
/// let manager = CalibrationManager::new(CalibrationConfig::default());
/// manager.start(broadcast_tx)?;
/// // ... collect samples ...
/// manager.finish()?;
/// let state = manager.get_state()?;
/// ```
#[allow(dead_code)] // Methods will be used when integrated into AppContext (task 5.4)
pub struct CalibrationManager {
    procedure: Arc<Mutex<Option<CalibrationProcedure>>>,
    state: Arc<RwLock<CalibrationState>>,
    calibration_config: CalibrationConfig,
}

#[allow(dead_code)] // Methods will be used when integrated into AppContext (task 5.4)
impl CalibrationManager {
    /// Create a new CalibrationManager
    ///
    /// Initializes with no calibration in progress and default calibration state.
    pub fn new(calibration_config: CalibrationConfig) -> Self {
        Self {
            procedure: Arc::new(Mutex::new(None)),
            state: Arc::new(RwLock::new(CalibrationState::new_default())),
            calibration_config,
        }
    }

    /// Start calibration workflow
    ///
    /// Begins collecting samples for calibration. The system will detect onsets
    /// and extract features without classifying. Collects the configured number of
    /// samples per sound type (default: 10).
    ///
    /// Calibration sequence: KICK → SNARE → HI-HAT
    ///
    /// # Arguments
    /// * `_broadcast_tx` - Broadcast channel for progress updates (reserved for future use)
    ///
    /// # Returns
    /// * `Ok(())` - Calibration started
    /// * `Err(CalibrationError)` - Error if calibration cannot start
    ///
    /// # Errors
    /// - Calibration already in progress
    /// - Lock poisoning on calibration procedure state
    pub fn start(
        &self,
        _broadcast_tx: broadcast::Sender<CalibrationProgress>,
    ) -> Result<(), CalibrationError> {
        let mut procedure_guard = self.lock_procedure()?;

        self.check_not_in_progress(&procedure_guard)?;

        let samples_needed = self.samples_per_sound();
        let procedure = CalibrationProcedure::new(samples_needed);
        *procedure_guard = Some(procedure);

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
    pub fn finish(&self) -> Result<(), CalibrationError> {
        let mut procedure_guard = self.lock_procedure()?;

        if let Some(procedure) = procedure_guard.take() {
            let new_state = procedure.finalize().inspect_err(|err| {
                log_calibration_error(err, "finish_calibration");
            })?;

            self.update_state(new_state)?;

            Ok(())
        } else {
            let err = CalibrationError::NotComplete;
            log_calibration_error(&err, "finish_calibration");
            Err(err)
        }
    }

    /// Get current calibration state for serialization
    ///
    /// Retrieves the current calibration state to be serialized and saved
    /// to persistent storage.
    ///
    /// # Returns
    /// * `Ok(CalibrationState)` - Clone of current calibration state
    /// * `Err(CalibrationError)` - Error if lock poisoning occurs
    ///
    /// # Errors
    /// - Lock poisoning on calibration state
    pub fn get_state(&self) -> Result<CalibrationState, CalibrationError> {
        let state_guard = self.read_state().inspect_err(|err| {
            log_calibration_error(err, "get_calibration_state");
        })?;

        Ok(state_guard.clone())
    }

    /// Get Arc reference to calibration state
    ///
    /// Returns an Arc reference to the calibration state for sharing with
    /// audio engine or other components that need concurrent access.
    ///
    /// # Returns
    /// `Arc<RwLock<CalibrationState>>` - Thread-safe reference to calibration state
    pub fn get_state_arc(&self) -> Arc<std::sync::RwLock<CalibrationState>> {
        Arc::clone(&self.state)
    }

    /// Get Arc reference to calibration procedure
    ///
    /// Returns an Arc reference to the calibration procedure for sharing with
    /// audio engine or analysis thread. The Arc can be cloned and shared across
    /// threads for concurrent access to the calibration procedure state.
    ///
    /// # Returns
    /// `Arc<Mutex<Option<CalibrationProcedure>>>` - Thread-safe reference to calibration procedure
    ///
    /// # Thread Safety
    /// The returned Arc can be safely cloned and shared across threads. Access to
    /// the inner `Option<CalibrationProcedure>` is protected by a Mutex.
    pub fn get_procedure_arc(&self) -> Arc<Mutex<Option<CalibrationProcedure>>> {
        Arc::clone(&self.procedure)
    }

    /// User confirms current calibration step is OK and wants to advance
    ///
    /// Called when user clicks "OK" after reviewing current sound samples.
    /// Advances to the next sound in the calibration sequence.
    ///
    /// # Returns
    /// * `Ok(true)` - Advanced to next sound
    /// * `Ok(false)` - Calibration complete (no next sound)
    /// * `Err(CalibrationError)` - Error if not waiting for confirmation or lock fails
    pub fn confirm_step(&self) -> Result<bool, CalibrationError> {
        let mut procedure_guard = self.lock_procedure()?;

        if let Some(procedure) = procedure_guard.as_mut() {
            procedure.confirm_and_advance()
        } else {
            let err = CalibrationError::NotComplete;
            log_calibration_error(&err, "confirm_step");
            Err(err)
        }
    }

    /// User wants to retry the current calibration step
    ///
    /// Called when user clicks "Retry" to redo current sound samples.
    /// Clears collected samples for the current sound.
    ///
    /// # Returns
    /// * `Ok(())` - Samples cleared, ready to collect again
    /// * `Err(CalibrationError)` - Error if not waiting for confirmation or lock fails
    pub fn retry_step(&self) -> Result<(), CalibrationError> {
        let mut procedure_guard = self.lock_procedure()?;

        if let Some(procedure) = procedure_guard.as_mut() {
            procedure.retry_current_sound()
        } else {
            let err = CalibrationError::NotComplete;
            log_calibration_error(&err, "retry_step");
            Err(err)
        }
    }

    /// Manually accept the last rejected-but-valid candidate for the current sound
    ///
    /// Allows UI to promote a buffered candidate when adaptive gates are too strict.
    ///
    /// # Returns
    /// * `Ok(CalibrationProgress)` - Updated progress after manual acceptance
    /// * `Err(CalibrationError)` - No candidate available or calibration inactive
    pub fn manual_accept_last_candidate(&self) -> Result<CalibrationProgress, CalibrationError> {
        let mut procedure_guard = self.lock_procedure()?;

        if let Some(procedure) = procedure_guard.as_mut() {
            procedure.manual_accept_last_candidate()
        } else {
            let err = CalibrationError::NotComplete;
            log_calibration_error(&err, "manual_accept_last_candidate");
            Err(err)
        }
    }

    /// Load calibration state from persistent storage
    ///
    /// Updates the calibration state with values loaded from storage.
    /// Typically called on app startup to restore previously calibrated thresholds.
    ///
    /// # Arguments
    /// * `state` - Calibration state to load
    ///
    /// # Returns
    /// * `Ok(())` - Calibration state loaded successfully
    /// * `Err(CalibrationError)` - Error if lock poisoning occurs
    ///
    /// # Errors
    /// - Lock poisoning on calibration state
    pub fn load_state(&self, state: CalibrationState) -> Result<(), CalibrationError> {
        let mut state_guard = self.write_state().inspect_err(|err| {
            log_calibration_error(err, "load_calibration");
        })?;

        *state_guard = state;
        Ok(())
    }

    // ========================================================================
    // HELPER METHODS - Lock management and validation
    // ========================================================================

    /// Determine configured sample count per sound, clamped to [1, u8::MAX]
    fn samples_per_sound(&self) -> u8 {
        let raw = self.calibration_config.samples_per_sound;
        let clamped = raw.clamp(1, u8::MAX as usize);
        if raw != clamped {
            log::warn!(
                "[CalibrationManager] samples_per_sound={} is out of u8 range, clamped to {}",
                raw,
                clamped
            );
        }
        clamped as u8
    }

    /// Safely acquire lock on calibration procedure
    fn lock_procedure(
        &self,
    ) -> Result<std::sync::MutexGuard<'_, Option<CalibrationProcedure>>, CalibrationError> {
        self.procedure
            .lock()
            .map_err(|_| CalibrationError::StatePoisoned)
    }

    /// Safely acquire read lock on calibration state
    fn read_state(
        &self,
    ) -> Result<std::sync::RwLockReadGuard<'_, CalibrationState>, CalibrationError> {
        self.state
            .read()
            .map_err(|_| CalibrationError::StatePoisoned)
    }

    /// Safely acquire write lock on calibration state
    fn write_state(
        &self,
    ) -> Result<std::sync::RwLockWriteGuard<'_, CalibrationState>, CalibrationError> {
        self.state
            .write()
            .map_err(|_| CalibrationError::StatePoisoned)
    }

    /// Check that calibration is not already in progress
    fn check_not_in_progress(
        &self,
        procedure_guard: &std::sync::MutexGuard<'_, Option<CalibrationProcedure>>,
    ) -> Result<(), CalibrationError> {
        if procedure_guard.is_some() {
            let err = CalibrationError::AlreadyInProgress;
            log_calibration_error(&err, "start_calibration");
            return Err(err);
        }
        Ok(())
    }

    /// Update calibration state with new state
    fn update_state(&self, new_state: CalibrationState) -> Result<(), CalibrationError> {
        let mut state_guard = self.write_state().inspect_err(|err| {
            log_calibration_error(err, "finish_calibration");
        })?;
        *state_guard = new_state;
        Ok(())
    }
}

impl Default for CalibrationManager {
    fn default() -> Self {
        Self::new(CalibrationConfig::default())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_manager() -> CalibrationManager {
        CalibrationManager::new(CalibrationConfig::default())
    }

    #[test]
    fn test_new() {
        let manager = create_manager();

        // Verify initial state
        let procedure_guard = manager.lock_procedure().unwrap();
        assert!(procedure_guard.is_none());

        let state = manager.get_state().unwrap();
        assert!(!state.is_calibrated);
    }

    #[test]
    fn test_start_calibration() {
        let manager = create_manager();
        let (broadcast_tx, _) = broadcast::channel(100);

        // Start calibration
        let result = manager.start(broadcast_tx);
        assert!(result.is_ok());

        // Verify procedure is now active
        let procedure_guard = manager.lock_procedure().unwrap();
        assert!(procedure_guard.is_some());
    }

    #[test]
    fn test_start_calibration_already_in_progress() {
        let manager = create_manager();
        let (broadcast_tx, _) = broadcast::channel(100);

        // First start succeeds
        assert!(manager.start(broadcast_tx.clone()).is_ok());

        // Second start fails with AlreadyInProgress
        let result = manager.start(broadcast_tx);
        assert!(matches!(result, Err(CalibrationError::AlreadyInProgress)));
    }

    #[test]
    fn test_finish_without_start() {
        let manager = create_manager();

        // Try to finish without starting
        let result = manager.finish();
        assert!(matches!(result, Err(CalibrationError::NotComplete)));
    }

    #[test]
    fn test_finish_with_insufficient_samples() {
        let manager = create_manager();
        let (broadcast_tx, _) = broadcast::channel(100);

        // Start calibration
        manager.start(broadcast_tx).ok();

        // Finish immediately (no samples collected)
        let result = manager.finish();
        assert!(result.is_err());
    }

    #[test]
    fn test_get_state() {
        let manager = create_manager();

        let state = manager.get_state();
        assert!(state.is_ok());
        assert!(!state.unwrap().is_calibrated);
    }

    #[test]
    fn test_load_state() {
        let manager = create_manager();

        // Create a calibrated state
        let mut new_state = CalibrationState::new_default();
        new_state.is_calibrated = true;
        new_state.t_kick_centroid = 2000.0;

        // Load state
        let result = manager.load_state(new_state.clone());
        assert!(result.is_ok());

        // Verify state was updated
        let loaded_state = manager.get_state().unwrap();
        assert!(loaded_state.is_calibrated);
        assert_eq!(loaded_state.t_kick_centroid, 2000.0);
    }

    #[test]
    fn test_state_persistence_across_operations() {
        let manager = create_manager();

        // Load a calibrated state
        let mut calibrated_state = CalibrationState::new_default();
        calibrated_state.is_calibrated = true;
        manager.load_state(calibrated_state).ok();

        // Start and abandon calibration
        let (broadcast_tx, _) = broadcast::channel(100);
        manager.start(broadcast_tx).ok();

        // State should still be the loaded state (procedure is separate)
        let state = manager.get_state().unwrap();
        assert!(state.is_calibrated);
    }

    #[test]
    fn test_default() {
        let manager = CalibrationManager::default();

        let procedure_guard = manager.lock_procedure().unwrap();
        assert!(procedure_guard.is_none());
    }

    #[test]
    fn test_get_procedure_arc() {
        let manager = create_manager();
        let (broadcast_tx, _) = broadcast::channel(100);

        // Start calibration to initialize procedure
        manager.start(broadcast_tx).ok();

        // Get Arc reference
        let procedure_arc = manager.get_procedure_arc();

        // Verify Arc is Some after calibration started
        let procedure_guard = procedure_arc.lock().unwrap();
        assert!(procedure_guard.is_some());
    }

    #[test]
    fn test_get_procedure_arc_when_not_started() {
        let manager = create_manager();

        // Get Arc reference before starting calibration
        let procedure_arc = manager.get_procedure_arc();

        // Verify Arc is None when calibration not started
        let procedure_guard = procedure_arc.lock().unwrap();
        assert!(procedure_guard.is_none());
    }
}
