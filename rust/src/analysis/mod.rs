// Analysis module - DSP pipeline for onset detection and classification
//
// This module orchestrates the complete DSP analysis pipeline, processing
// audio buffers from the audio thread and generating classification results
// for the UI thread.
//
// Architecture:
// - AnalysisThread: Main loop that consumes buffers from DATA_QUEUE
// - Pipeline: OnsetDetector → FeatureExtractor → Classifier → Quantizer
// - Output: ClassificationResult sent via tokio channel to Dart Stream

use std::sync::atomic::{AtomicU32, AtomicU64};
use std::sync::{Arc, RwLock};
use std::thread::{self, JoinHandle};
use tokio::sync::mpsc;

use crate::audio::buffer_pool::AnalysisThreadChannels;
use crate::calibration::state::CalibrationState;

pub mod classifier;
pub mod features;
pub mod onset;
pub mod quantizer;

use classifier::{BeatboxHit, Classifier};
use features::FeatureExtractor;
use onset::OnsetDetector;
use quantizer::{Quantizer, TimingFeedback};

/// Classification result combining sound type and timing feedback
///
/// This struct is sent to the Dart UI via flutter_rust_bridge Stream
/// for real-time display of detected sounds and timing accuracy.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ClassificationResult {
    /// Detected beatbox sound type
    pub sound: BeatboxHit,
    /// Timing accuracy relative to metronome grid
    pub timing: TimingFeedback,
    /// Timestamp in milliseconds since engine start
    pub timestamp_ms: u64,
}

/// Spawn the analysis thread that processes audio buffers through DSP pipeline
///
/// The analysis thread consumes filled audio buffers from the DATA_QUEUE,
/// processes them through the onset detection and classification pipeline,
/// and sends results to the UI via a tokio channel.
///
/// # Arguments
/// * `buffer_channels` - Buffer pool channels (data_consumer, pool_producer)
/// * `calibration` - Calibration state with classification thresholds
/// * `frame_counter` - Shared frame counter from AudioEngine
/// * `bpm` - Shared BPM setting from AudioEngine
/// * `sample_rate` - Audio sample rate in Hz
/// * `result_sender` - Tokio channel sender for ClassificationResult
///
/// # Returns
/// JoinHandle for the spawned analysis thread
///
/// # Thread Safety
/// - Uses lock-free queues for audio data (rtrb)
/// - Uses atomic references for frame_counter and BPM
/// - Uses RwLock for calibration state (read-only in this thread)
/// - Thread panics are isolated and won't crash audio thread
///
/// # Error Handling
/// - Dropped buffers if DATA_QUEUE is empty (no blocking)
/// - Continues processing on classification errors
/// - Logs errors but doesn't terminate thread
pub fn spawn_analysis_thread(
    mut analysis_channels: AnalysisThreadChannels,
    calibration: Arc<RwLock<CalibrationState>>,
    frame_counter: Arc<AtomicU64>,
    bpm: Arc<AtomicU32>,
    sample_rate: u32,
    result_sender: mpsc::UnboundedSender<ClassificationResult>,
) -> JoinHandle<()> {
    thread::spawn(move || {
        // Initialize DSP components (all allocations happen here, not in loop)
        let mut onset_detector = OnsetDetector::new(sample_rate);
        let feature_extractor = FeatureExtractor::new(sample_rate);
        let classifier = Classifier::new(Arc::clone(&calibration));
        let quantizer = Quantizer::new(Arc::clone(&frame_counter), Arc::clone(&bpm), sample_rate);

        // Main analysis loop - runs until sender is dropped (audio engine stops)
        loop {
            // Blocking pop from DATA_QUEUE (this is NOT the audio thread, so blocking is OK)
            let buffer = match analysis_channels.data_consumer.pop() {
                Ok(buf) => buf,
                Err(_) => {
                    // Queue is empty, try again
                    // Small sleep to avoid busy-waiting
                    std::thread::sleep(std::time::Duration::from_millis(1));
                    continue;
                }
            };

            // Process buffer through onset detection
            let onsets = onset_detector.process(&buffer);

            // For each detected onset, run classification pipeline
            for onset_timestamp in onsets {
                // Extract 1024-sample window starting at onset
                // Note: We need to handle the case where onset is near the end of buffer
                let onset_idx = (onset_timestamp % buffer.len() as u64) as usize;

                if onset_idx + 1024 <= buffer.len() {
                    let onset_window = &buffer[onset_idx..onset_idx + 1024];

                    // Extract DSP features
                    let features = feature_extractor.extract(onset_window);

                    // Classify sound
                    let sound = classifier.classify_level1(&features);

                    // Quantize timing (only if metronome is running, BPM > 0)
                    let current_bpm = bpm.load(std::sync::atomic::Ordering::Relaxed);
                    let timing = if current_bpm > 0 {
                        quantizer.quantize(onset_timestamp)
                    } else {
                        // Calibration mode - no timing feedback
                        TimingFeedback {
                            classification: quantizer::TimingClassification::OnTime,
                            error_ms: 0.0,
                        }
                    };

                    // Convert timestamp to milliseconds
                    let timestamp_ms =
                        (onset_timestamp as f64 / sample_rate as f64 * 1000.0) as u64;

                    // Create result and send to Dart UI
                    let result = ClassificationResult {
                        sound,
                        timing,
                        timestamp_ms,
                    };

                    // Send result (non-blocking, drops if channel is full)
                    if result_sender.send(result).is_err() {
                        // Channel closed, audio engine stopped
                        // Return buffer and exit thread
                        let _ = analysis_channels.pool_producer.push(buffer);
                        return;
                    }
                }
                // If onset is too close to end of buffer, skip it (will be caught in next buffer)
            }

            // Return buffer to POOL_QUEUE for reuse
            if analysis_channels.pool_producer.push(buffer).is_err() {
                // Pool queue is full (shouldn't happen with proper sizing)
                // Drop the buffer (will be reallocated if needed)
                eprintln!("Warning: POOL_QUEUE full, dropping buffer");
            }
        }
    })
}
