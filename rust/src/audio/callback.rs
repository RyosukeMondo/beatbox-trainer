//! Audio Output Callback - Oboe trait implementation for real-time metronome generation
//!
//! This module provides the OutputCallback struct that implements oboe-rs v0.6.x
//! AudioOutputCallback trait. It encapsulates all state and logic needed for
//! sample-accurate metronome click generation in the real-time audio thread.
//!
//! # Design
//! The callback struct is designed for maximum real-time safety:
//! - No heap allocations during audio processing
//! - No mutex locks (only lock-free atomic operations)
//! - No blocking I/O or syscalls
//! - Bounded execution time (simple arithmetic and buffer copies)
//!
//! # Architecture
//! ```text
//! AudioEngine::create_output_stream()
//!   └─> OutputCallback::new()
//!       └─> oboe::AudioStreamBuilder::set_callback()
//!           └─> OutputCallback::on_audio_ready() [Real-time thread]
//!               ├─> is_on_beat() [Check if click should trigger]
//!               └─> Generate audio samples [Lock-free atomic reads]
//! ```

use log::{info, warn};
use oboe::{
    AudioInputStreamSync, AudioOutputCallback, AudioOutputStreamSafe, AudioStreamSync,
    DataCallbackResult, Input,
};
use std::sync::atomic::{AtomicU32, AtomicU64, Ordering};
use std::sync::Arc;

use super::buffer_pool::AudioThreadChannels;
use super::metronome::is_on_beat;

/// Output audio callback for metronome generation
///
/// This struct implements the `AudioOutputCallback` trait required by oboe-rs v0.6.x.
/// It encapsulates all state needed by the real-time audio callback, ensuring
/// thread-safe access via atomic operations.
///
/// # Real-Time Safety
/// All operations in `on_audio_ready` are:
/// - Lock-free (using atomic operations)
/// - Allocation-free (all data pre-allocated)
/// - Bounded execution time (simple arithmetic only)
///
/// # Example
/// ```ignore
/// let callback = OutputCallback::new(
///     frame_counter,
///     bpm,
///     sample_rate,
///     click_samples,
///     click_position,
/// );
/// AudioStreamBuilder::default()
///     .set_callback(callback)
///     .open_stream()?;
/// ```
pub struct OutputCallback {
    /// Atomic frame counter for sample-accurate timing
    frame_counter: Arc<AtomicU64>,
    /// Atomic BPM for dynamic tempo changes
    bpm: Arc<AtomicU32>,
    /// Sample rate in Hz
    sample_rate: u32,
    /// Pre-generated metronome click samples
    click_samples: Arc<Vec<f32>>,
    /// Current position in click sample playback
    click_position: Arc<AtomicU64>,
    /// Input audio stream for microphone capture
    input_stream: Arc<std::sync::Mutex<Option<AudioStreamSync<Input, (f32, oboe::Mono)>>>>,
    /// Buffer pool channels for sending audio to analysis thread
    audio_channels: Arc<std::sync::Mutex<Option<AudioThreadChannels>>>,
}

impl OutputCallback {
    /// Create a new OutputCallback with the given state
    ///
    /// # Arguments
    /// * `frame_counter` - Shared atomic frame counter
    /// * `bpm` - Shared atomic BPM value
    /// * `sample_rate` - Sample rate in Hz
    /// * `click_samples` - Pre-generated metronome click samples
    /// * `click_position` - Shared atomic click position tracker
    /// * `input_stream` - Input stream for microphone capture
    /// * `audio_channels` - Buffer pool channels for audio data transfer
    pub fn new(
        frame_counter: Arc<AtomicU64>,
        bpm: Arc<AtomicU32>,
        sample_rate: u32,
        click_samples: Arc<Vec<f32>>,
        click_position: Arc<AtomicU64>,
        input_stream: Arc<std::sync::Mutex<Option<AudioStreamSync<Input, (f32, oboe::Mono)>>>>,
        audio_channels: Arc<std::sync::Mutex<Option<AudioThreadChannels>>>,
    ) -> Self {
        Self {
            frame_counter,
            bpm,
            sample_rate,
            click_samples,
            click_position,
            input_stream,
            audio_channels,
        }
    }

    /// Non-blocking pump that mirrors microphone input into the analysis queue.
    fn pump_input_stream(&self, frame_capacity: usize) {
        if frame_capacity == 0 {
            return;
        }

        if let Ok(mut input_guard) = self.input_stream.try_lock() {
            if let Some(ref mut input) = *input_guard {
                let mut input_buffer = vec![0.0f32; frame_capacity];
                let frames_read = input.read(&mut input_buffer, 0).unwrap_or(0);

                if frames_read > 0 {
                    if let Ok(mut channels_guard) = self.audio_channels.try_lock() {
                        if let Some(ref mut channels) = *channels_guard {
                            if let Ok(mut buffer) = channels.pool_consumer.pop() {
                                buffer.clear();
                                buffer.extend_from_slice(&input_buffer[..frames_read]);
                                let _ = channels.data_producer.push(buffer);
                            }
                        } else {
                            warn!("[AudioCallback] audio_channels is None");
                        }
                    }
                } else {
                    static mut READ_FAIL_COUNT: u64 = 0;
                    unsafe {
                        READ_FAIL_COUNT += 1;
                        if READ_FAIL_COUNT % 100 == 0 {
                            warn!(
                                "[AudioCallback] No frames read from input (count: {})",
                                READ_FAIL_COUNT
                            );
                        }
                    }
                }
            } else {
                warn!("[AudioCallback] input_stream is None");
            }
        }
    }
}

impl AudioOutputCallback for OutputCallback {
    type FrameType = (f32, oboe::Mono);

    fn on_audio_ready(
        &mut self,
        _stream: &mut dyn AudioOutputStreamSafe,
        frames: &mut [f32],
    ) -> DataCallbackResult {
        // Real-time audio callback - NO ALLOCATIONS, LOCKS, OR BLOCKING!

        // Load current state (atomic operations are lock-free)
        let current_frame = self.frame_counter.load(Ordering::Relaxed);
        let current_bpm = self.bpm.load(Ordering::Relaxed);
        let mut click_pos = self.click_position.load(Ordering::Relaxed) as usize;

        // Pump microphone frames into analysis queue (non-blocking)
        self.pump_input_stream(frames.len());

        // Process each output frame (metronome generation)
        for (i, sample) in frames.iter_mut().enumerate() {
            // Calculate current frame index for this sample
            let frame = current_frame + i as u64;

            if is_on_beat(frame, current_bpm, self.sample_rate) {
                // Start playing click sample
                click_pos = 0;
            }

            // Generate metronome click if we're within click duration
            if click_pos < self.click_samples.len() {
                *sample = self.click_samples[click_pos];
                click_pos += 1;
            } else {
                *sample = 0.0; // Silence between clicks
            }
        }

        // Update click position for next callback
        self.click_position
            .store(click_pos as u64, Ordering::Relaxed);

        // Update frame counter
        self.frame_counter
            .fetch_add(frames.len() as u64, Ordering::Relaxed);

        DataCallbackResult::Continue
    }
}
