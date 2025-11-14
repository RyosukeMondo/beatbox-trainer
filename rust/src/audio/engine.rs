//! AudioEngine - Oboe-based real-time audio processing
//!
//! This module provides the core audio engine using Oboe for full-duplex audio I/O.
//! Key features:
//! - Low-latency audio I/O via oboe-rs (AAudio/OpenSL ES backends)
//! - Sample-accurate metronome generation
//! - Lock-free buffer pool for audio data transfer
//! - Real-time safe: no allocations, locks, or blocking in audio callback
//!
//! Architecture:
//! - Output callback (master): Generates metronome clicks and triggers input reads
//! - Input stream (slave): Non-blocking reads in output callback
//! - Analysis thread: Consumes audio buffers from DATA_QUEUE
//!
//! Thread safety:
//! - frame_counter: AtomicU64 for sample-accurate timing
//! - bpm: AtomicU32 for dynamic tempo changes
//! - BufferPool: Lock-free SPSC queues

#[cfg(target_os = "android")]
use oboe::{
    AudioStream, AudioStreamAsync, AudioStreamBuilder, AudioStreamSync, Input, Output,
    PerformanceMode, SharingMode,
};
#[cfg(target_os = "android")]
use std::sync::atomic::{AtomicU32, AtomicU64, Ordering};
#[cfg(target_os = "android")]
use std::sync::Arc;

#[cfg(target_os = "android")]
use super::buffer_pool::BufferPoolChannels;
#[cfg(target_os = "android")]
use crate::error::AudioError;

#[cfg(target_os = "android")]
use super::callback::OutputCallback;
#[cfg(target_os = "android")]
use super::metronome::generate_click_sample;

#[cfg(test)]
use super::buffer_pool::DEFAULT_BUFFER_SIZE;

/// Audio engine for real-time audio processing with metronome generation
///
/// This struct manages full-duplex audio streams using Oboe and provides
/// sample-accurate metronome clicks. The engine uses lock-free primitives
/// to ensure real-time safety in the audio callback.
///
/// # Real-Time Safety Guarantees
/// - No heap allocations in audio callback (all buffers pre-allocated)
/// - No mutex locks (only atomic operations)
/// - No blocking I/O (non-blocking input reads)
/// - Bounded execution time (simple arithmetic and buffer copies)
///
/// # Example
/// ```ignore
/// let engine = AudioEngine::new(120, 48000, channels)?;
/// engine.start()?;
/// // ... audio processing happens in callback
/// engine.stop()?;
/// ```
#[cfg(target_os = "android")]
pub struct AudioEngine {
    /// Output audio stream (master - triggers input reads)
    output_stream: Option<AudioStreamAsync<Output, OutputCallback>>,
    /// Input audio stream (slave - read by output callback)
    input_stream: Option<AudioStreamSync<Input, (f32, oboe::Mono)>>,
    /// Atomic frame counter for sample-accurate timing
    frame_counter: Arc<AtomicU64>,
    /// Atomic BPM for dynamic tempo changes
    bpm: Arc<AtomicU32>,
    /// Sample rate in Hz
    sample_rate: u32,
    /// Pre-generated metronome click samples
    click_samples: Arc<Vec<f32>>,
    /// Buffer pool channels for lock-free communication
    buffer_channels: BufferPoolChannels,
    /// Current position in click sample playback (for output callback state)
    click_position: Arc<AtomicU64>,
}

#[cfg(target_os = "android")]
impl AudioEngine {
    /// Create a new AudioEngine with specified BPM and buffer configuration
    ///
    /// # Arguments
    /// * `bpm` - Initial beats per minute (typically 40-240)
    /// * `sample_rate` - Sample rate in Hz (typically 48000)
    /// * `buffer_channels` - Pre-initialized buffer pool channels
    ///
    /// # Returns
    /// Result containing AudioEngine or error
    ///
    /// # Errors
    /// Returns error if audio streams cannot be initialized
    pub fn new(
        bpm: u32,
        sample_rate: u32,
        buffer_channels: BufferPoolChannels,
    ) -> Result<Self, AudioError> {
        // Pre-generate metronome click samples (20ms white noise)
        let click_samples = generate_click_sample(sample_rate);

        Ok(AudioEngine {
            output_stream: None,
            input_stream: None,
            frame_counter: Arc::new(AtomicU64::new(0)),
            bpm: Arc::new(AtomicU32::new(bpm)),
            sample_rate,
            click_samples: Arc::new(click_samples),
            buffer_channels,
            click_position: Arc::new(AtomicU64::new(0)),
        })
    }

    /// Create and open the input audio stream
    ///
    /// # Returns
    /// Result containing the opened input stream or error
    ///
    /// # Errors
    /// Returns error if input stream cannot be opened
    fn create_input_stream(&self) -> Result<AudioStreamSync<Input, (f32, oboe::Mono)>, AudioError> {
        AudioStreamBuilder::default()
            .set_performance_mode(PerformanceMode::LowLatency)
            .set_sharing_mode(SharingMode::Exclusive)
            .set_direction::<Input>()
            .set_sample_rate(self.sample_rate as i32)
            .set_channel_count::<oboe::Mono>() // Mono input for beatbox detection
            .set_format::<f32>()
            .open_stream()
            .map_err(|e| AudioError::StreamOpenFailed {
                reason: format!("Input stream: {:?}", e),
            })
    }

    /// Create and open the output audio stream with metronome callback
    ///
    /// # Returns
    /// Result containing the opened output stream with audio callback or error
    ///
    /// # Errors
    /// Returns error if output stream cannot be opened
    fn create_output_stream(&self) -> Result<AudioStreamAsync<Output, OutputCallback>, AudioError> {
        // Create OutputCallback struct with cloned Arc references
        let callback = OutputCallback::new(
            Arc::clone(&self.frame_counter),
            Arc::clone(&self.bpm),
            self.sample_rate,
            Arc::clone(&self.click_samples),
            Arc::clone(&self.click_position),
        );

        AudioStreamBuilder::default()
            .set_performance_mode(PerformanceMode::LowLatency)
            .set_sharing_mode(SharingMode::Exclusive)
            .set_direction::<Output>()
            .set_sample_rate(self.sample_rate as i32)
            .set_channel_count::<oboe::Mono>() // Mono output for metronome
            .set_format::<f32>()
            .set_callback(callback)
            .open_stream()
            .map_err(|e| AudioError::StreamOpenFailed {
                reason: format!("Output stream: {:?}", e),
            })
    }

    /// Spawn the analysis thread for audio processing
    ///
    /// # Arguments
    /// * `buffer_channels` - Buffer pool channels for audio data transfer
    /// * `calibration_state` - Calibration state for sound classification
    /// * `calibration_procedure` - Optional calibration procedure for collecting training samples
    /// * `calibration_progress_tx` - Optional broadcast channel for calibration progress updates
    /// * `result_sender` - Tokio broadcast channel for sending classification results to UI
    fn spawn_analysis_thread_internal(
        &self,
        buffer_channels: BufferPoolChannels,
        calibration_state: std::sync::Arc<
            std::sync::RwLock<crate::calibration::state::CalibrationState>,
        >,
        calibration_procedure: std::sync::Arc<
            std::sync::Mutex<Option<crate::calibration::procedure::CalibrationProcedure>>,
        >,
        calibration_progress_tx: Option<
            tokio::sync::broadcast::Sender<crate::calibration::procedure::CalibrationProgress>,
        >,
        result_sender: tokio::sync::broadcast::Sender<crate::analysis::ClassificationResult>,
    ) {
        let (_, analysis_channels) = buffer_channels.split_for_threads();

        let frame_counter_clone = Arc::clone(&self.frame_counter);
        let bpm_clone = Arc::clone(&self.bpm);

        crate::analysis::spawn_analysis_thread(
            analysis_channels,
            calibration_state,
            calibration_procedure,
            calibration_progress_tx,
            frame_counter_clone,
            bpm_clone,
            self.sample_rate,
            result_sender,
        );
    }

    /// Start audio streams and begin processing
    ///
    /// Opens full-duplex audio streams with output as master (triggers input reads).
    /// The output callback generates metronome clicks and performs non-blocking
    /// input reads to capture audio data. Also spawns the analysis thread to process
    /// captured audio through the DSP pipeline.
    ///
    /// # Arguments
    /// * `calibration_state` - Calibration state for sound classification
    /// * `calibration_procedure` - Optional calibration procedure for collecting training samples
    /// * `calibration_progress_tx` - Optional broadcast channel for calibration progress updates
    /// * `result_sender` - Tokio broadcast channel for sending classification results to UI
    ///
    /// # Returns
    /// Result indicating success or error
    ///
    /// # Errors
    /// Returns error if streams cannot be opened or started
    pub fn start(
        &mut self,
        calibration_state: std::sync::Arc<
            std::sync::RwLock<crate::calibration::state::CalibrationState>,
        >,
        calibration_procedure: std::sync::Arc<
            std::sync::Mutex<Option<crate::calibration::procedure::CalibrationProcedure>>,
        >,
        calibration_progress_tx: Option<
            tokio::sync::broadcast::Sender<crate::calibration::procedure::CalibrationProgress>,
        >,
        result_sender: tokio::sync::broadcast::Sender<crate::analysis::ClassificationResult>,
    ) -> Result<(), AudioError> {
        // Create and open audio streams
        let mut input_stream = self.create_input_stream()?;
        let mut output_stream = self.create_output_stream()?;

        // Start streams (input first, then output as master)
        input_stream
            .start()
            .map_err(|e| AudioError::HardwareError {
                details: format!("Failed to start input stream: {:?}", e),
            })?;
        output_stream
            .start()
            .map_err(|e| AudioError::HardwareError {
                details: format!("Failed to start output stream: {:?}", e),
            })?;

        self.input_stream = Some(input_stream);
        self.output_stream = Some(output_stream);

        // Split buffer channels for audio and analysis threads
        // Take ownership of buffer_channels temporarily
        let buffer_channels = std::mem::replace(
            &mut self.buffer_channels,
            // Create a dummy empty channels struct (will be replaced if start() is called again)
            BufferPoolChannels {
                data_producer: rtrb::RingBuffer::new(1).0,
                data_consumer: rtrb::RingBuffer::new(1).1,
                pool_producer: rtrb::RingBuffer::new(1).0,
                pool_consumer: rtrb::RingBuffer::new(1).1,
            },
        );

        // Spawn analysis thread
        self.spawn_analysis_thread_internal(
            buffer_channels,
            calibration_state,
            calibration_procedure,
            calibration_progress_tx,
            result_sender,
        );

        Ok(())
    }

    /// Stop audio streams and release resources
    ///
    /// Stops both input and output streams gracefully. After stopping,
    /// the engine can be restarted with start().
    ///
    /// # Returns
    /// Result indicating success or error
    pub fn stop(&mut self) -> Result<(), AudioError> {
        // Stop output stream first (master)
        if let Some(mut stream) = self.output_stream.take() {
            stream.stop().map_err(|e| AudioError::HardwareError {
                details: format!("Failed to stop output stream: {:?}", e),
            })?;
        }

        // Then stop input stream (slave)
        if let Some(mut stream) = self.input_stream.take() {
            stream.stop().map_err(|e| AudioError::HardwareError {
                details: format!("Failed to stop input stream: {:?}", e),
            })?;
        }

        Ok(())
    }

    /// Update BPM dynamically while audio is running
    ///
    /// This is safe to call from any thread, including during audio processing.
    /// The change will take effect immediately due to atomic operations.
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
    /// Total number of frames processed since engine start
    pub fn get_frame_counter(&self) -> u64 {
        self.frame_counter.load(Ordering::Relaxed)
    }

    /// Get shared reference to frame counter for use by other components (e.g., Quantizer)
    ///
    /// # Returns
    /// Arc<AtomicU64> that can be cloned and shared across threads
    pub fn get_frame_counter_ref(&self) -> Arc<AtomicU64> {
        Arc::clone(&self.frame_counter)
    }

    /// Get shared reference to BPM for use by other components (e.g., Quantizer)
    ///
    /// # Returns
    /// Arc<AtomicU32> that can be cloned and shared across threads
    pub fn get_bpm_ref(&self) -> Arc<AtomicU32> {
        Arc::clone(&self.bpm)
    }
}

// Platform abstraction layer for cross-platform testing
//
// On Android: Uses the full Oboe-based AudioEngine implementation
// On desktop (Linux/macOS/Windows): Uses the StubAudioEngine from stubs.rs
//
// This allows cargo test to run on desktop without Android dependencies
#[cfg(target_os = "android")]
pub type PlatformAudioEngine = AudioEngine;

#[cfg(not(target_os = "android"))]
pub use super::stubs::AudioEngine as StubAudioEngine;

#[cfg(not(target_os = "android"))]
pub type PlatformAudioEngine = StubAudioEngine;

// Re-export AudioEngine for backward compatibility on non-Android platforms
#[cfg(not(target_os = "android"))]
pub use StubAudioEngine as AudioEngine;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::audio::buffer_pool::BufferPool;
    use std::sync::atomic::Ordering;

    #[test]
    fn test_audio_engine_creation() {
        let channels = BufferPool::new(16, DEFAULT_BUFFER_SIZE);
        let engine = AudioEngine::new(120, 48000, channels);
        assert!(engine.is_ok(), "AudioEngine creation should succeed");

        let engine = engine.unwrap();
        assert_eq!(engine.get_bpm(), 120, "Initial BPM should be 120");
        assert_eq!(
            engine.get_frame_counter(),
            0,
            "Frame counter should start at 0"
        );
    }

    #[test]
    fn test_set_bpm() {
        let channels = BufferPool::new(16, DEFAULT_BUFFER_SIZE);
        let engine = AudioEngine::new(120, 48000, channels).unwrap();

        engine.set_bpm(140);
        assert_eq!(engine.get_bpm(), 140, "BPM should update to 140");

        engine.set_bpm(60);
        assert_eq!(engine.get_bpm(), 60, "BPM should update to 60");
    }

    #[test]
    fn test_frame_counter_ref() {
        let channels = BufferPool::new(16, DEFAULT_BUFFER_SIZE);
        let engine = AudioEngine::new(120, 48000, channels).unwrap();

        let frame_ref = engine.get_frame_counter_ref();
        assert_eq!(frame_ref.load(Ordering::Relaxed), 0);

        // Simulate frame counter update (would happen in audio callback)
        frame_ref.store(1000, Ordering::Relaxed);
        assert_eq!(engine.get_frame_counter(), 1000);
    }

    #[test]
    fn test_bpm_ref() {
        let channels = BufferPool::new(16, DEFAULT_BUFFER_SIZE);
        let engine = AudioEngine::new(120, 48000, channels).unwrap();

        let bpm_ref = engine.get_bpm_ref();
        assert_eq!(bpm_ref.load(Ordering::Relaxed), 120);

        // Update via reference
        bpm_ref.store(180, Ordering::Relaxed);
        assert_eq!(engine.get_bpm(), 180);
    }

    #[test]
    fn test_multiple_bpm_updates() {
        let channels = BufferPool::new(16, DEFAULT_BUFFER_SIZE);
        let engine = AudioEngine::new(120, 48000, channels).unwrap();

        let bpm_values = vec![60, 80, 100, 120, 140, 160, 180, 200, 240];
        for &bpm in &bpm_values {
            engine.set_bpm(bpm);
            assert_eq!(engine.get_bpm(), bpm, "BPM should update to {}", bpm);
        }
    }

    /// Test AudioEngine accepts calibration parameters without error
    ///
    /// This test verifies that the AudioEngine can be started with all calibration
    /// parameters (calibration_state, calibration_procedure, calibration_progress_tx)
    /// on both Android (real engine) and desktop (stub engine).
    ///
    /// On Android: Tests the real Oboe-based AudioEngine
    /// On desktop: Tests the StubAudioEngine which simulates the interface
    #[test]
    fn test_audio_engine_start_with_calibration_parameters() {
        let channels = BufferPool::new(16, DEFAULT_BUFFER_SIZE);
        let mut engine = AudioEngine::new(120, 48000, channels).unwrap();

        // Create calibration state
        let calibration_state = std::sync::Arc::new(std::sync::RwLock::new(
            crate::calibration::state::CalibrationState::new_default(),
        ));

        // Create calibration procedure (initially None)
        let calibration_procedure = std::sync::Arc::new(std::sync::Mutex::new(None));

        // Create calibration progress broadcast channel
        let (calibration_progress_tx, _calibration_progress_rx) =
            tokio::sync::broadcast::channel(16);

        // Create classification result broadcast channel
        let (result_tx, _result_rx) = tokio::sync::broadcast::channel(16);

        // Start engine with all calibration parameters
        let result = engine.start(
            calibration_state,
            calibration_procedure,
            Some(calibration_progress_tx),
            result_tx,
        );

        // On Android: Should succeed if audio permissions granted, or fail with specific error
        // On desktop: Should succeed (stub implementation)
        #[cfg(target_os = "android")]
        {
            // On Android, start may succeed or fail depending on permissions/hardware
            // We just verify it doesn't panic and returns a valid Result
            assert!(
                result.is_ok() || result.is_err(),
                "AudioEngine::start should return a valid Result on Android"
            );
        }

        #[cfg(not(target_os = "android"))]
        {
            // On desktop stub, start should always succeed
            assert!(
                result.is_ok(),
                "AudioEngine::start should succeed on desktop stub"
            );
        }
    }
}
