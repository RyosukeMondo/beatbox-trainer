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

use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, RwLock};
use std::thread::{self, JoinHandle};

use crate::audio::buffer_pool::AnalysisThreadChannels;
use crate::calibration::procedure::CalibrationProcedure;
use crate::calibration::progress::CalibrationProgress;
use crate::calibration::state::CalibrationState;
use crate::config::OnsetDetectionConfig;
use crate::telemetry;
use rtrb::PopError;

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

use crate::api::AudioMetrics;

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
/// * `audio_metrics_tx` - Optional broadcast channel for audio metrics (level meter)
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
    shutdown_flag: Option<Arc<AtomicBool>>,
    audio_metrics_tx: Option<tokio::sync::broadcast::Sender<AudioMetrics>>,
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
        let mut last_noise_floor_samples: usize = 0;

        loop {
            // Blocking pop from DATA_QUEUE (this is NOT the audio thread, so blocking is OK)
            let buffer = match analysis_channels.data_consumer.pop() {
                Ok(buf) => buf,
                Err(PopError::Empty) => {
                    // Check shutdown flag - exit if shutdown requested (flag is true)
                    if let Some(flag) = shutdown_flag.as_ref() {
                        if flag.load(Ordering::SeqCst) {
                            log::info!("[AnalysisThread] Shutdown flag set, exiting");
                            break;
                        }
                    }
                    std::thread::sleep(std::time::Duration::from_millis(1));
                    continue;
                }
            };

            // Accumulate small buffers into larger chunks
            accumulator.extend_from_slice(&buffer);
            let occupancy = (accumulator.len().min(min_buffer_size) as f32
                / min_buffer_size as f32)
                .clamp(0.0, 1.0)
                * 100.0;
            telemetry::hub().record_buffer_occupancy("analysis_accumulator", occupancy);

            // Return buffer to pool immediately
            if analysis_channels.pool_producer.push(buffer).is_err() {
                log::warn!("[AnalysisThread] Pool queue full, dropping buffer");
            }

            // Only process when we have enough samples
            if accumulator.len() < min_buffer_size {
                continue;
            }

            // Calculate RMS for audio metrics (level meter)
            let rms: f64 = {
                let sum_squares: f64 = accumulator.iter().map(|&x| (x as f64) * (x as f64)).sum();
                (sum_squares / accumulator.len() as f64).sqrt()
            };

            // Emit audio metrics for live level meter display
            if let Some(ref tx) = audio_metrics_tx {
                let current_frame = frame_counter.load(Ordering::Relaxed);
                let timestamp_ms = (current_frame as f64 / sample_rate as f64 * 1000.0) as u64;
                let metrics = AudioMetrics {
                    rms,
                    spectral_centroid: 0.0, // Could compute from feature_extractor if needed
                    spectral_flux: 0.0,
                    frame_number: current_frame,
                    timestamp: timestamp_ms,
                };
                let _ = tx.send(metrics);
            }

            // ====== NOISE FLOOR CALIBRATION PHASE ======
            // During noise floor phase, collect RMS samples WITHOUT onset detection
            let in_noise_floor_phase = if let Ok(procedure_guard) = calibration_procedure.try_lock()
            {
                procedure_guard
                    .as_ref()
                    .map(|p| p.is_in_noise_floor_phase())
                    .unwrap_or(false)
            } else {
                false
            };

            if in_noise_floor_phase {
                // Feed RMS to noise floor calibration
                if let Ok(mut procedure_guard) = calibration_procedure.lock() {
                    if let Some(ref mut procedure) = *procedure_guard {
                        match procedure.add_noise_floor_sample(rms) {
                            Ok(complete) => {
                                // Broadcast progress
                                let progress = procedure.get_progress();
                                let samples = progress.samples_collected as usize;
                                // Only emit when sample count changes to avoid log spam while waiting
                                if samples != last_noise_floor_samples {
                                    if let Some(ref tx) = calibration_progress_tx {
                                        let _ = tx.send(progress.clone());
                                    }
                                    last_noise_floor_samples = samples;
                                }

                                if complete {
                                    log::info!(
                                        "[AnalysisThread] Noise floor calibration complete! Threshold: {:?}",
                                        procedure.noise_floor_threshold()
                                    );
                                }
                            }
                            Err(e) => {
                                log::warn!("[AnalysisThread] Noise floor sample rejected: {:?}", e);
                            }
                        }
                    }
                }
                // Clear accumulator and skip onset detection during noise floor phase
                accumulator.clear();
                continue;
            }

            // Check if buffer contains non-zero samples
            static mut NON_ZERO_CHECK: u64 = 0;
            unsafe {
                NON_ZERO_CHECK += 1;
                if let Some(interval) = log_interval {
                    if interval > 0 && NON_ZERO_CHECK.is_multiple_of(interval) {
                        let max_amplitude =
                            accumulator.iter().map(|x| x.abs()).fold(0.0f32, f32::max);
                        log::info!(
                            "[AnalysisThread] Max amplitude in accumulated buffer: {}, RMS: {}",
                            max_amplitude,
                            rms
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
                    let onset_rms = {
                        let sum_squares: f64 = onset_window
                            .iter()
                            .map(|&sample| (sample as f64) * (sample as f64))
                            .sum();
                        (sum_squares / onset_window.len() as f64).sqrt()
                    };

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
                                match procedure.add_sample(features, onset_rms) {
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
                        telemetry::hub().record_classification(&result);
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
mod tests;
