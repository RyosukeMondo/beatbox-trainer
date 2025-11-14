//! Stub audio engine for desktop testing
//!
//! This module provides a stub implementation of AudioEngine that can run on
//! non-Android platforms (Linux, macOS, Windows). The stub maintains the same
//! interface as the real AudioEngine but does not perform actual audio I/O.
//!
//! This enables running `cargo test` on desktop machines without requiring an
//! Android emulator or device, significantly speeding up development iteration.
//!
//! # Usage
//! The stub is automatically used on non-Android platforms via conditional
//! compilation. Tests can use the same AudioEngine interface regardless of
//! platform.

use std::sync::atomic::{AtomicU32, AtomicU64, Ordering};
use std::sync::Arc;

use super::buffer_pool::BufferPoolChannels;
use crate::error::AudioError;

/// Stub audio engine for desktop testing
///
/// This provides a minimal implementation of the AudioEngine interface
/// without actual audio hardware access. State changes (start/stop/set_bpm)
/// are tracked for testing purposes.
///
/// # Real-Time Safety
/// While this stub doesn't have actual real-time constraints, it maintains
/// the same atomic primitives as the real engine to ensure behavioral
/// consistency in tests.
#[cfg(not(target_os = "android"))]
pub struct AudioEngine {
    /// Atomic BPM for dynamic tempo changes
    bpm: Arc<AtomicU32>,
    /// Atomic frame counter for compatibility with real engine
    frame_counter: Arc<AtomicU64>,
    /// Track whether engine is running
    is_running: Arc<AtomicU64>, // 0 = stopped, 1 = running
    /// Sample rate in Hz (unused but maintained for interface compatibility)
    #[allow(dead_code)]
    sample_rate: u32,
    /// Buffer pool channels (unused but maintained for interface compatibility)
    _buffer_channels: BufferPoolChannels,
}

#[cfg(not(target_os = "android"))]
impl AudioEngine {
    /// Create a new stub AudioEngine
    ///
    /// # Arguments
    /// * `bpm` - Initial beats per minute (typically 40-240)
    /// * `sample_rate` - Sample rate in Hz (typically 48000)
    /// * `buffer_channels` - Pre-initialized buffer pool channels (unused in stub)
    ///
    /// # Returns
    /// Result containing AudioEngine stub
    pub fn new(
        bpm: u32,
        sample_rate: u32,
        buffer_channels: BufferPoolChannels,
    ) -> Result<Self, AudioError> {
        Ok(AudioEngine {
            bpm: Arc::new(AtomicU32::new(bpm)),
            frame_counter: Arc::new(AtomicU64::new(0)),
            is_running: Arc::new(AtomicU64::new(0)),
            sample_rate,
            _buffer_channels: buffer_channels,
        })
    }

    /// Start stub audio engine
    ///
    /// # Arguments
    /// * `_calibration` - Calibration state (unused in stub)
    /// * `_result_sender` - Result broadcast channel (unused in stub)
    ///
    /// # Returns
    /// Result indicating success or error
    ///
    /// # Errors
    /// Returns AudioError::AlreadyRunning if engine is already started
    pub fn start(
        &mut self,
        _calibration: std::sync::Arc<
            std::sync::RwLock<crate::calibration::state::CalibrationState>,
        >,
        _result_sender: tokio::sync::broadcast::Sender<crate::analysis::ClassificationResult>,
    ) -> Result<(), AudioError> {
        let current = self.is_running.load(Ordering::Relaxed);
        if current == 1 {
            return Err(AudioError::AlreadyRunning);
        }
        self.is_running.store(1, Ordering::Relaxed);
        Ok(())
    }

    /// Stop stub audio engine
    ///
    /// # Returns
    /// Result indicating success
    pub fn stop(&mut self) -> Result<(), AudioError> {
        self.is_running.store(0, Ordering::Relaxed);
        Ok(())
    }

    /// Update BPM dynamically
    ///
    /// # Arguments
    /// * `new_bpm` - New beats per minute (typically 40-240)
    pub fn set_bpm(&self, new_bpm: u32) {
        self.bpm.store(new_bpm, Ordering::Relaxed);
    }

    /// Get current BPM
    ///
    /// # Returns
    /// Current beats per minute
    pub fn get_bpm(&self) -> u32 {
        self.bpm.load(Ordering::Relaxed)
    }

    /// Get current frame counter
    ///
    /// # Returns
    /// Total number of frames processed
    pub fn get_frame_counter(&self) -> u64 {
        self.frame_counter.load(Ordering::Relaxed)
    }

    /// Get shared reference to frame counter
    ///
    /// # Returns
    /// Arc<AtomicU64> that can be cloned and shared across threads
    pub fn get_frame_counter_ref(&self) -> Arc<AtomicU64> {
        Arc::clone(&self.frame_counter)
    }

    /// Get shared reference to BPM
    ///
    /// # Returns
    /// Arc<AtomicU32> that can be cloned and shared across threads
    pub fn get_bpm_ref(&self) -> Arc<AtomicU32> {
        Arc::clone(&self.bpm)
    }

    /// Check if engine is running
    ///
    /// # Returns
    /// True if engine is running, false otherwise
    pub fn is_running(&self) -> bool {
        self.is_running.load(Ordering::Relaxed) == 1
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::audio::buffer_pool::{BufferPool, DEFAULT_BUFFER_COUNT, DEFAULT_BUFFER_SIZE};

    #[test]
    fn test_new_engine_created_successfully() {
        let channels = BufferPool::new(DEFAULT_BUFFER_COUNT, DEFAULT_BUFFER_SIZE);
        let result = AudioEngine::new(120, 48000, channels);

        assert!(result.is_ok());
        let engine = result.unwrap();
        assert_eq!(engine.get_bpm(), 120);
        assert!(!engine.is_running());
    }

    #[test]
    fn test_start_engine_success() {
        let channels = BufferPool::new(DEFAULT_BUFFER_COUNT, DEFAULT_BUFFER_SIZE);
        let mut engine = AudioEngine::new(120, 48000, channels).unwrap();

        let calibration = Arc::new(std::sync::RwLock::new(
            crate::calibration::state::CalibrationState::new_default(),
        ));
        let (tx, _rx) = tokio::sync::broadcast::channel(16);

        let result = engine.start(calibration, tx);

        assert!(result.is_ok());
        assert!(engine.is_running());
    }

    #[test]
    fn test_start_engine_already_running_fails() {
        let channels = BufferPool::new(DEFAULT_BUFFER_COUNT, DEFAULT_BUFFER_SIZE);
        let mut engine = AudioEngine::new(120, 48000, channels).unwrap();

        let calibration = Arc::new(std::sync::RwLock::new(
            crate::calibration::state::CalibrationState::new_default(),
        ));
        let (tx, _rx) = tokio::sync::broadcast::channel(16);

        // Start first time - should succeed
        engine.start(calibration.clone(), tx.clone()).unwrap();

        // Start second time - should fail
        let result = engine.start(calibration, tx);

        assert!(matches!(result, Err(AudioError::AlreadyRunning)));
    }

    #[test]
    fn test_stop_engine_success() {
        let channels = BufferPool::new(DEFAULT_BUFFER_COUNT, DEFAULT_BUFFER_SIZE);
        let mut engine = AudioEngine::new(120, 48000, channels).unwrap();

        let calibration = Arc::new(std::sync::RwLock::new(
            crate::calibration::state::CalibrationState::new_default(),
        ));
        let (tx, _rx) = tokio::sync::broadcast::channel(16);

        engine.start(calibration, tx).unwrap();
        assert!(engine.is_running());

        let result = engine.stop();

        assert!(result.is_ok());
        assert!(!engine.is_running());
    }

    #[test]
    fn test_set_bpm_updates_value() {
        let channels = BufferPool::new(DEFAULT_BUFFER_COUNT, DEFAULT_BUFFER_SIZE);
        let engine = AudioEngine::new(120, 48000, channels).unwrap();

        assert_eq!(engine.get_bpm(), 120);

        engine.set_bpm(140);

        assert_eq!(engine.get_bpm(), 140);
    }

    #[test]
    fn test_get_bpm_returns_current_value() {
        let channels = BufferPool::new(DEFAULT_BUFFER_COUNT, DEFAULT_BUFFER_SIZE);
        let engine = AudioEngine::new(100, 48000, channels).unwrap();

        assert_eq!(engine.get_bpm(), 100);
    }
}
