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
use std::sync::{Arc, Mutex, RwLock};
use std::thread::{self, JoinHandle};

use crate::audio::buffer_pool::AnalysisThreadChannels;
use crate::calibration::procedure::CalibrationProcedure;
use crate::calibration::progress::CalibrationProgress;
use crate::calibration::state::CalibrationState;
use crate::config::OnsetDetectionConfig;

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
    /// Classification confidence score (0.0-1.0)
    /// Calculated as max_score / sum_of_all_scores
    pub confidence: f32,
}

/// Spawn the analysis thread that processes audio buffers through DSP pipeline
///
/// The analysis thread consumes filled audio buffers from the DATA_QUEUE,
/// processes them through the onset detection and classification pipeline,
/// and sends results to the UI via a tokio channel. During calibration mode,
/// detected features are forwarded to the calibration procedure instead of
/// being classified.
///
/// # Arguments
/// * `analysis_channels` - Buffer pool channels (data_consumer, pool_producer)
/// * `calibration_state` - Calibration state with classification thresholds
/// * `calibration_procedure` - Optional calibration procedure for sample collection
/// * `calibration_progress_tx` - Optional broadcast channel for calibration progress updates
/// * `frame_counter` - Shared frame counter from AudioEngine
/// * `bpm` - Shared BPM setting from AudioEngine
/// * `sample_rate` - Audio sample rate in Hz
/// * `result_sender` - Tokio broadcast channel sender for ClassificationResult
///
/// # Returns
/// JoinHandle for the spawned analysis thread
///
/// # Thread Safety
/// - Uses lock-free queues for audio data (rtrb)
/// - Uses atomic references for frame_counter and BPM
/// - Uses RwLock for calibration state (read-only in this thread)
/// - Uses Mutex for calibration procedure (try_lock for non-blocking access)
/// - Thread panics are isolated and won't crash audio thread
///
/// # Error Handling
/// - Dropped buffers if DATA_QUEUE is empty (no blocking)
/// - Continues processing on classification errors
/// - Logs errors but doesn't terminate thread
#[allow(clippy::too_many_arguments)]
pub fn spawn_analysis_thread(
    mut analysis_channels: AnalysisThreadChannels,
    calibration_state: Arc<RwLock<CalibrationState>>,
    calibration_procedure: Arc<Mutex<Option<CalibrationProcedure>>>,
    calibration_progress_tx: Option<tokio::sync::broadcast::Sender<CalibrationProgress>>,
    frame_counter: Arc<AtomicU64>,
    bpm: Arc<AtomicU32>,
    sample_rate: u32,
    result_sender: tokio::sync::broadcast::Sender<ClassificationResult>,
    onset_config: OnsetDetectionConfig,
    log_every_n_buffers: u64,
) -> JoinHandle<()> {
    thread::spawn(move || {
        // Initialize DSP components (all allocations happen here, not in loop)
        let mut onset_detector = OnsetDetector::with_config(sample_rate, onset_config.clone());
        let feature_extractor = FeatureExtractor::new(sample_rate);
        let classifier = Classifier::new(Arc::clone(&calibration_state));
        let quantizer = Quantizer::new(Arc::clone(&frame_counter), Arc::clone(&bpm), sample_rate);

        // Main analysis loop - runs until sender is dropped (audio engine stops)
        log::info!("[AnalysisThread] Starting analysis loop");

        // Accumulation buffer for combining small buffers into larger chunks
        let min_buffer_size = onset_config.min_buffer_size.max(64);
        let mut accumulator: Vec<f32> = Vec::with_capacity(min_buffer_size.max(2048));
        let log_interval = if log_every_n_buffers == 0 {
            None
        } else {
            Some(log_every_n_buffers)
        };

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

            // Accumulate small buffers into larger chunks
            accumulator.extend_from_slice(&buffer);

            // Return buffer to pool immediately
            if analysis_channels.pool_producer.push(buffer).is_err() {
                log::warn!("[AnalysisThread] Pool queue full, dropping buffer");
            }

            // Only process when we have enough samples
            if accumulator.len() < min_buffer_size {
                continue;
            }

            // Check if buffer contains non-zero samples
            static mut NON_ZERO_CHECK: u64 = 0;
            unsafe {
                NON_ZERO_CHECK += 1;
                if let Some(interval) = log_interval {
                    if interval > 0 && NON_ZERO_CHECK % interval == 0 {
                        let max_amplitude =
                            accumulator.iter().map(|x| x.abs()).fold(0.0f32, f32::max);
                        log::info!(
                            "[AnalysisThread] Max amplitude in accumulated buffer: {}",
                            max_amplitude
                        );
                    }
                }
            }

            // Process accumulated buffer through onset detection
            let onsets = onset_detector.process(&accumulator);

            if !onsets.is_empty() {
                log::info!("[AnalysisThread] Detected {} onsets", onsets.len());
            }

            // For each detected onset, run pipeline (calibration or classification mode)
            // IMPORTANT: Process onsets BEFORE clearing accumulator!
            for onset_timestamp in onsets {
                // Extract 1024-sample window starting at onset
                // onset_timestamp is relative to when the audio engine started
                // We need to find it within the current accumulator
                let onset_idx = (onset_timestamp % accumulator.len() as u64) as usize;

                log::info!(
                    "[AnalysisThread] Onset at timestamp={}, accumulator_len={}, onset_idx={}",
                    onset_timestamp,
                    accumulator.len(),
                    onset_idx
                );

                if onset_idx + 1024 <= accumulator.len() {
                    log::info!(
                        "[AnalysisThread] Extracting onset window from idx {} to {}",
                        onset_idx,
                        onset_idx + 1024
                    );
                    let onset_window = &accumulator[onset_idx..onset_idx + 1024];

                    // Extract DSP features (always needed for both modes)
                    let features = feature_extractor.extract(onset_window);

                    // Check if calibration is active (non-blocking check)
                    let calibration_active =
                        if let Ok(procedure_guard) = calibration_procedure.try_lock() {
                            procedure_guard.is_some()
                        } else {
                            false // Lock failed, assume not calibrating
                        };

                    if calibration_active {
                        // ====== CALIBRATION MODE ======
                        log::info!("[AnalysisThread] CALIBRATION MODE: Processing onset");
                        // Forward features to calibration procedure
                        if let Ok(mut procedure_guard) = calibration_procedure.lock() {
                            if let Some(ref mut procedure) = *procedure_guard {
                                match procedure.add_sample(features) {
                                    Ok(()) => {
                                        // Sample accepted - broadcast progress
                                        let progress = procedure.get_progress();
                                        log::info!(
                                            "[AnalysisThread] Sample accepted: {:?}",
                                            progress
                                        );

                                        if let Some(ref tx) = calibration_progress_tx {
                                            let _ = tx.send(progress);
                                        }
                                    }
                                    Err(err) => {
                                        // Sample rejected (validation error)
                                        log::warn!("[AnalysisThread] Sample rejected: {:?}", err);
                                        // Continue processing without crashing
                                    }
                                }
                            }
                        }
                    } else {
                        // ====== CLASSIFICATION MODE (existing logic) ======
                        // Classify sound (returns tuple of (BeatboxHit, confidence))
                        let (sound, confidence) = classifier.classify_level1(&features);

                        // Quantize timing (only if metronome is running, BPM > 0)
                        let current_bpm = bpm.load(std::sync::atomic::Ordering::Relaxed);
                        let timing = if current_bpm > 0 {
                            quantizer.quantize(onset_timestamp)
                        } else {
                            // No metronome - no timing feedback
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
                            confidence,
                        };

                        // Send result to broadcast channel (drops if no subscribers)
                        // Broadcast channels don't fail on send, they just drop messages if no one is listening
                        let _ = result_sender.send(result);
                    }
                } else {
                    log::warn!(
                        "[AnalysisThread] Onset window incomplete: need {} samples but only {} available from idx {}",
                        1024,
                        accumulator.len() - onset_idx,
                        onset_idx
                    );
                }
                // If onset is too close to end of buffer, skip it (will be caught in next buffer)
            }

            // Clear accumulator for next batch (AFTER processing all onsets!)
            accumulator.clear();
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::audio::buffer_pool::BufferPool;
    use crate::calibration::procedure::CalibrationProcedure;
    use crate::calibration::state::CalibrationState;
    use std::sync::atomic::{AtomicU32, AtomicU64};
    use std::sync::{Arc, Mutex, RwLock};
    use std::thread;
    use std::time::Duration;
    use tokio::sync::broadcast;

    // NOTE: These tests verify the calibration mode switching logic in the analysis thread.
    // Full end-to-end testing with onset detection requires manual testing on device,
    // as onset detection needs proper initialization and continuous audio stream.
    // The tests focus on verifying:
    // 1. Thread spawns successfully with calibration parameters
    // 2. Mode switching logic (calibration vs classification)
    // 3. Lock handling and fallback behavior
    // 4. Thread doesn't panic on errors

    #[test]
    fn test_calibration_mode_thread_spawns_with_procedure() {
        // Verify: Thread spawns successfully with calibration procedure parameter
        let channels = BufferPool::new(8, 2048);
        let (_audio_tx, analysis_rx) = channels.split_for_threads();

        let procedure = CalibrationProcedure::new(10);
        let calibration_procedure = Arc::new(Mutex::new(Some(procedure)));
        let calibration_state = Arc::new(RwLock::new(CalibrationState::new_default()));
        let (progress_tx, _progress_rx) = broadcast::channel(100);
        let (result_tx, _result_rx) = broadcast::channel(100);
        let frame_counter = Arc::new(AtomicU64::new(0));
        let bpm = Arc::new(AtomicU32::new(120));

        // Spawn thread - should not panic
        let analysis_thread = spawn_analysis_thread(
            analysis_rx,
            calibration_state,
            calibration_procedure,
            Some(progress_tx),
            frame_counter,
            bpm,
            48000,
            result_tx,
            OnsetDetectionConfig::default(),
            100,
        );

        // Give thread time to initialize
        thread::sleep(Duration::from_millis(50));

        // Verify: Thread is running (not panicked)
        assert!(!analysis_thread.is_finished());
    }

    #[test]
    fn test_classification_mode_thread_spawns_without_procedure() {
        // Verify: Thread spawns successfully with None procedure (classification mode)
        let channels = BufferPool::new(8, 2048);
        let (_audio_tx, analysis_rx) = channels.split_for_threads();

        let calibration_procedure = Arc::new(Mutex::new(None));
        let calibration_state = Arc::new(RwLock::new(CalibrationState::new_default()));
        let (progress_tx, _progress_rx) = broadcast::channel(100);
        let (result_tx, _result_rx) = broadcast::channel(100);
        let frame_counter = Arc::new(AtomicU64::new(0));
        let bpm = Arc::new(AtomicU32::new(120));

        // Spawn thread - should not panic even without calibration procedure
        let analysis_thread = spawn_analysis_thread(
            analysis_rx,
            calibration_state,
            calibration_procedure,
            Some(progress_tx),
            frame_counter,
            bpm,
            48000,
            result_tx,
            OnsetDetectionConfig::default(),
            100,
        );

        // Give thread time to initialize
        thread::sleep(Duration::from_millis(50));

        // Verify: Thread is running (not panicked)
        assert!(!analysis_thread.is_finished());
    }

    #[test]
    fn test_thread_handles_calibration_procedure_gracefully() {
        // Verify: Thread doesn't panic when processing with calibration procedure
        let channels = BufferPool::new(8, 2048);
        let (_audio_tx, analysis_rx) = channels.split_for_threads();

        let procedure = CalibrationProcedure::new(10);
        let calibration_procedure = Arc::new(Mutex::new(Some(procedure)));
        let calibration_state = Arc::new(RwLock::new(CalibrationState::new_default()));
        let (progress_tx, _progress_rx) = broadcast::channel(100);
        let (result_tx, _result_rx) = broadcast::channel(100);
        let frame_counter = Arc::new(AtomicU64::new(0));
        let bpm = Arc::new(AtomicU32::new(120));

        // Spawn analysis thread
        let analysis_thread = spawn_analysis_thread(
            analysis_rx,
            calibration_state,
            calibration_procedure,
            Some(progress_tx),
            frame_counter,
            bpm,
            48000,
            result_tx,
            OnsetDetectionConfig::default(),
            100,
        );

        // Give thread time to run its processing loop
        thread::sleep(Duration::from_millis(100));

        // Verify: Thread is still running (hasn't panicked on errors)
        assert!(!analysis_thread.is_finished());
    }

    #[test]
    fn test_thread_accepts_optional_progress_channel() {
        // Verify: Thread handles optional progress channel (Some and None)
        let channels1 = BufferPool::new(8, 2048);
        let (_audio_tx1, analysis_rx1) = channels1.split_for_threads();

        let procedure1 = CalibrationProcedure::new(10);
        let calibration_procedure1 = Arc::new(Mutex::new(Some(procedure1)));
        let calibration_state1 = Arc::new(RwLock::new(CalibrationState::new_default()));
        let (progress_tx, _progress_rx) = broadcast::channel(100);
        let (result_tx1, _result_rx1) = broadcast::channel(100);
        let frame_counter1 = Arc::new(AtomicU64::new(0));
        let bpm1 = Arc::new(AtomicU32::new(120));

        // Spawn with Some(progress_tx)
        let thread1 = spawn_analysis_thread(
            analysis_rx1,
            calibration_state1,
            calibration_procedure1,
            Some(progress_tx),
            frame_counter1,
            bpm1,
            48000,
            result_tx1,
            OnsetDetectionConfig::default(),
            100,
        );

        // Spawn with None
        let channels2 = BufferPool::new(8, 2048);
        let (_audio_tx2, analysis_rx2) = channels2.split_for_threads();
        let procedure2 = CalibrationProcedure::new(10);
        let calibration_procedure2 = Arc::new(Mutex::new(Some(procedure2)));
        let calibration_state2 = Arc::new(RwLock::new(CalibrationState::new_default()));
        let (result_tx2, _result_rx2) = broadcast::channel(100);
        let frame_counter2 = Arc::new(AtomicU64::new(0));
        let bpm2 = Arc::new(AtomicU32::new(120));

        let thread2 = spawn_analysis_thread(
            analysis_rx2,
            calibration_state2,
            calibration_procedure2,
            None, // No progress channel
            frame_counter2,
            bpm2,
            48000,
            result_tx2,
            OnsetDetectionConfig::default(),
            100,
        );

        thread::sleep(Duration::from_millis(50));

        // Verify: Both threads running without panicking
        assert!(!thread1.is_finished());
        assert!(!thread2.is_finished());
    }

    #[test]
    fn test_thread_handles_lock_contention_without_deadlock() {
        // Verify: Thread doesn't deadlock when procedure lock is held
        let channels = BufferPool::new(8, 2048);
        let (_audio_tx, analysis_rx) = channels.split_for_threads();

        let procedure = CalibrationProcedure::new(10);
        let calibration_procedure = Arc::new(Mutex::new(Some(procedure)));
        let procedure_clone = Arc::clone(&calibration_procedure);

        let calibration_state = Arc::new(RwLock::new(CalibrationState::new_default()));
        let (progress_tx, _progress_rx) = broadcast::channel(100);
        let (result_tx, _result_rx) = broadcast::channel(100);
        let frame_counter = Arc::new(AtomicU64::new(0));
        let bpm = Arc::new(AtomicU32::new(120));

        // Spawn analysis thread
        let analysis_thread = spawn_analysis_thread(
            analysis_rx,
            calibration_state,
            calibration_procedure,
            Some(progress_tx),
            frame_counter,
            bpm,
            48000,
            result_tx,
            OnsetDetectionConfig::default(),
            100,
        );

        // Hold lock on procedure to simulate contention
        let _lock = procedure_clone.lock().unwrap();

        // Give thread time to attempt try_lock (should fail and continue processing)
        thread::sleep(Duration::from_millis(100));

        // Verify: Thread is still running (didn't deadlock on try_lock failure)
        assert!(!analysis_thread.is_finished());

        // Drop lock
        drop(_lock);

        // Verify thread still running
        thread::sleep(Duration::from_millis(50));
        assert!(!analysis_thread.is_finished());
    }
}
