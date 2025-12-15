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
use std::time::{Duration, Instant};

use crate::audio::buffer_pool::AnalysisThreadChannels;
use crate::calibration::procedure::CalibrationProcedure;
use crate::calibration::progress::{
    CalibrationGuidance, CalibrationGuidanceReason, CalibrationProgress,
};
use crate::calibration::state::CalibrationState;
use crate::config::OnsetDetectionConfig;
use crate::telemetry;
use rtrb::PopError;

pub mod classifier;
pub mod features;
pub mod level_crossing;
pub mod onset;
pub mod quantizer;

use classifier::{BeatboxHit, Classifier};
use features::FeatureExtractor;
use level_crossing::LevelCrossingDetector;
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

#[derive(Debug)]
struct GuidanceRateLimiter {
    last_reason: Option<CalibrationGuidanceReason>,
    last_at: Option<Instant>,
    rate_limit: Duration,
}

impl GuidanceRateLimiter {
    fn new(rate_limit: Duration) -> Self {
        Self {
            last_reason: None,
            last_at: None,
            rate_limit,
        }
    }

    fn has_active(&self) -> bool {
        self.last_reason.is_some()
    }

    fn clear(&mut self) {
        self.last_reason = None;
        self.last_at = None;
    }

    fn should_emit(&mut self, reason: CalibrationGuidanceReason, now: Instant) -> bool {
        let reason_changed = self.last_reason.map(|r| r != reason).unwrap_or(true);
        let past_rate_limit = self
            .last_at
            .map(|ts| now.saturating_duration_since(ts) >= self.rate_limit)
            .unwrap_or(true);

        if reason_changed || past_rate_limit {
            self.last_reason = Some(reason);
            self.last_at = Some(now);
            true
        } else {
            false
        }
    }
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
        eprintln!("[AnalysisThread] Thread started");
        // Initialize DSP components (all allocations happen here, not in loop)
        let mut onset_detector = OnsetDetector::with_config(sample_rate, onset_config.clone());
        eprintln!("[AnalysisThread] OnsetDetector created");
        let feature_extractor = FeatureExtractor::new(sample_rate);
        eprintln!("[AnalysisThread] FeatureExtractor created");
        let classifier = Classifier::new(Arc::clone(&calibration_state));
        eprintln!("[AnalysisThread] Classifier created");
        let quantizer = Quantizer::new(Arc::clone(&frame_counter), Arc::clone(&bpm), sample_rate);
        eprintln!("[AnalysisThread] Quantizer created, entering loop");

        // Main analysis loop - runs until sender is dropped (audio engine stops)
        tracing::info!("[AnalysisThread] Starting analysis loop");

        // Log initial noise floor gate for debugging
        if let Ok(state) = calibration_state.read() {
            tracing::info!(
                "[AnalysisThread] Noise floor RMS from calibration: {:.4}, gate threshold: {:.4}",
                state.noise_floor_rms,
                state.noise_floor_rms * 2.0
            );
        }

        // Accumulation buffer for combining small buffers into larger chunks
        let min_buffer_size = onset_config.min_buffer_size.max(64);
        let mut accumulator: Vec<f32> = Vec::with_capacity(min_buffer_size.max(2048));
        let log_interval = if log_every_n_buffers == 0 {
            None
        } else {
            Some(log_every_n_buffers)
        };
        let mut last_noise_floor_samples: usize = 0;
        let mut guidance_limiter = GuidanceRateLimiter::new(Duration::from_secs(5));
        let mut last_progress_heartbeat = Instant::now();
        let mut debug_emit_counter: u64 = 0;
        let mut last_debug_probe = Instant::now();
        let mut processed_samples: u64 = 0;
        const LEVEL_CROSSING_DEBOUNCE_MS: u64 = 150;
        let debounce_samples = (LEVEL_CROSSING_DEBOUNCE_MS * sample_rate as u64) / 1000;
        let mut level_crossing_detector =
            LevelCrossingDetector::new(sample_rate, LEVEL_CROSSING_DEBOUNCE_MS);

        loop {
            // Attempt to pop from queue
            let buffer = match analysis_channels.data_consumer.pop() {
                Ok(buf) => {
                    eprintln!("[AnalysisThread] Popped buffer len {}", buf.len());
                    buf
                }
                Err(PopError::Empty) => {
                    // Check shutdown flag only when queue is empty
                    if let Some(flag) = shutdown_flag.as_ref() {
                        if !flag.load(Ordering::SeqCst) {
                            tracing::info!(
                                "[AnalysisThread] Shutdown flag set and queue empty, exiting"
                            );
                            break;
                        }
                    }
                    // Small sleep to avoid busy loop when empty
                    std::thread::sleep(std::time::Duration::from_millis(1));
                    continue;
                }
            };

            processed_samples += buffer.len() as u64;

            // Accumulate small buffers into larger chunks
            accumulator.extend_from_slice(&buffer);
            let occupancy = (accumulator.len().min(min_buffer_size) as f32
                / min_buffer_size as f32)
                .clamp(0.0, 1.0)
                * 100.0;
            telemetry::hub().record_buffer_occupancy("analysis_accumulator", occupancy);

            // Return buffer to pool immediately
            if analysis_channels.pool_producer.push(buffer).is_err() {
                tracing::warn!("[AnalysisThread] Pool queue full, dropping buffer");
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
            // More responsive RMS from the most recent window (used for gating)
            let window_rms: f64 = if accumulator.len() >= 1024 {
                let window = &accumulator[accumulator.len() - 1024..];
                let sum_squares: f64 = window.iter().map(|&x| (x as f64) * (x as f64)).sum();
                (sum_squares / window.len() as f64).sqrt()
            } else {
                rms
            };

            // Emit audio metrics for live level meter display
            if let Some(ref tx) = audio_metrics_tx {
                let current_frame = frame_counter.load(Ordering::Relaxed);
                let timestamp_ms = (current_frame as f64 / sample_rate as f64 * 1000.0) as u64;

                // Extract features for spectral centroid (only if we have enough samples)
                let features = if accumulator.len() >= 1024 {
                    Some(feature_extractor.extract(&accumulator[accumulator.len() - 1024..]))
                } else if !accumulator.is_empty() {
                    Some(feature_extractor.extract(&accumulator))
                } else {
                    None
                };

                let metrics = AudioMetrics {
                    rms,
                    spectral_centroid: features.map(|f| f.centroid as f64).unwrap_or(0.0),
                    spectral_flux: onset_detector.last_spectral_flux() as f64,
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
                                    tracing::info!(
                                        "[AnalysisThread] Noise floor calibration complete! Threshold: {:?}",
                                        procedure.noise_floor_threshold()
                                    );
                                }
                            }
                            Err(e) => {
                                tracing::warn!(
                                    "[AnalysisThread] Noise floor sample rejected: {:?}",
                                    e
                                );
                            }
                        }
                    }
                }
                // Clear accumulator for next batch
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
                        tracing::info!(
                            "[AnalysisThread] Max amplitude in accumulated buffer: {}, RMS: {}",
                            max_amplitude,
                            rms
                        );
                    }
                }
            }

            let (calibration_active_snapshot, quiet_clear_gate) =
                if let Ok(procedure_guard) = calibration_procedure.try_lock() {
                    (
                        procedure_guard.is_some(),
                        procedure_guard
                            .as_ref()
                            .and_then(|p| p.noise_floor_threshold())
                            .unwrap_or(0.02)
                            * 1.05,
                    )
                } else {
                    (false, 0.02)
                };

            let detection_threshold_snapshot = if calibration_active_snapshot {
                if let Ok(procedure_guard) = calibration_procedure.try_lock() {
                    procedure_guard
                        .as_ref()
                        .map(|procedure| procedure.detection_threshold())
                } else {
                    None
                }
            } else {
                None
            };

            if calibration_active_snapshot
                && guidance_limiter.has_active()
                && rms < quiet_clear_gate
            {
                if let Ok(mut procedure_guard) = calibration_procedure.try_lock() {
                    if let Some(ref mut procedure) = *procedure_guard {
                        if let Some(ref tx) = calibration_progress_tx {
                            let _ =
                                tx.send(procedure.get_progress_with_guidance_and_features(
                                    None, None, None, None,
                                ));
                        }
                    }
                }
                guidance_limiter.clear();
            }

            // Push a light-weight debug probe so UI can see live feature readings even when
            // onsets are not firing (e.g., user making sounds that don't cross the gate).
            // Update at ~30fps for smooth visual feedback
            if calibration_active_snapshot
                && last_debug_probe.elapsed() >= Duration::from_millis(33)
            {
                let debug_window = if accumulator.len() >= 1024 {
                    &accumulator[accumulator.len() - 1024..]
                } else {
                    &accumulator[..]
                };
                let debug_features = feature_extractor.extract(debug_window);
                let debug_max_amp = debug_window
                    .iter()
                    .map(|sample| sample.abs())
                    .fold(0.0f32, f32::max);
                if let Ok(mut procedure_guard) = calibration_procedure.try_lock() {
                    if let Some(ref mut procedure) = *procedure_guard {
                        procedure.update_last_features_for_debug(
                            &debug_features,
                            window_rms,
                            debug_max_amp,
                        );
                    }
                }
                last_debug_probe = Instant::now();
            }

            // Periodic heartbeat to keep UI updated with last-known debug values even if no onsets
            // Update at ~10fps for responsive UI feedback
            if calibration_active_snapshot
                && last_progress_heartbeat.elapsed() >= Duration::from_millis(100)
            {
                if let Ok(mut procedure_guard) = calibration_procedure.try_lock() {
                    if let Some(ref mut procedure) = *procedure_guard {
                        let progress = procedure
                            .get_progress_with_guidance_and_features(None, None, None, None);
                        debug_emit_counter = debug_emit_counter.wrapping_add(1);
                        tracing::debug!(
                            "[AnalysisThread] Progress heartbeat [{}]: gate_rms {:?}, last_rms {:?}, last_centroid {:?}, last_zcr {:?}, misses {}",
                            debug_emit_counter,
                            progress.debug.as_ref().and_then(|d| d.rms_gate),
                            progress.debug.as_ref().and_then(|d| d.last_rms),
                            progress.debug.as_ref().and_then(|d| d.last_centroid),
                            progress.debug.as_ref().and_then(|d| d.last_zcr),
                            progress.debug.as_ref().map(|d| d.misses).unwrap_or(0),
                        );
                        if let Some(ref tx) = calibration_progress_tx {
                            let _ = tx.send(progress);
                        }
                    }
                }
                last_progress_heartbeat = Instant::now();
            }

            // ====== LEVEL-CROSSING DETECTOR FOR CALIBRATION ======
            // Simpler detection: capture sample when RMS crosses from below to above threshold
            // This runs IN ADDITION to onset detection, catching sounds that spectral flux misses
            if calibration_active_snapshot && accumulator.len() >= 1024 {
                let detection_threshold =
                    detection_threshold_snapshot.unwrap_or(quiet_clear_gate * 2.0); // 2x noise floor fallback

                if let Some(event) = level_crossing_detector.process_calibration(
                    window_rms,
                    detection_threshold,
                    processed_samples,
                ) {
                    let capture_window = &accumulator[accumulator.len() - 1024..];
                    let capture_rms = window_rms;
                    let capture_max_amp = capture_window
                        .iter()
                        .map(|sample| sample.abs())
                        .fold(0.0f32, f32::max);
                    let capture_features = feature_extractor.extract(capture_window);
                    let capture_features_for_progress = capture_features;

                    if let Ok(mut procedure_guard) = calibration_procedure.lock() {
                        if let Some(ref mut procedure) = *procedure_guard {
                            match procedure.add_sample(
                                capture_features,
                                capture_rms,
                                capture_max_amp,
                            ) {
                                Ok(()) => {
                                    tracing::info!(
                                        "[AnalysisThread] Level-crossing event {:?} accepted (rms {:.4}, gate {:.4})",
                                        event,
                                        capture_rms,
                                        detection_threshold
                                    );
                                    let progress = procedure
                                        .get_progress_with_guidance_and_features(
                                            None,
                                            Some(&capture_features_for_progress),
                                            Some(capture_rms),
                                            Some(capture_max_amp),
                                        );
                                    if let Some(ref tx) = calibration_progress_tx {
                                        let _ = tx.send(progress);
                                    }
                                    guidance_limiter.clear();
                                }
                                Err(err) => {
                                    tracing::info!(
                                        "[AnalysisThread] Level-crossing event {:?} rejected: {:?} (rms {:.4})",
                                        event,
                                        err,
                                        capture_rms
                                    );
                                }
                            }
                        }
                    }
                }
            }

            // ====== LEVEL-CROSSING DETECTOR FOR CLASSIFICATION ======
            // Same approach as calibration: detect when RMS crosses from below to above threshold
            // This is more reliable than onset detection which can fire on spectral changes in quiet audio
            if !calibration_active_snapshot && accumulator.len() >= 1024 {
                let noise_floor_gate = match calibration_state.read() {
                    Ok(state) => state.noise_floor_rms * 2.0,
                    Err(_) => 0.02, // Conservative fallback
                };

                if let Some(event) = level_crossing_detector.process_classification(
                    window_rms,
                    noise_floor_gate,
                    processed_samples,
                ) {
                    tracing::info!(
                        "[AnalysisThread] Level crossing event {:?} for classification (rms {:.4}, gate {:.4})",
                        event,
                        window_rms,
                        noise_floor_gate
                    );

                    // Extract features from the most recent 1024 samples
                    let crossing_window = &accumulator[accumulator.len() - 1024..];
                    let crossing_features = feature_extractor.extract(crossing_window);

                    // Classify sound (returns tuple of (BeatboxHit, confidence))
                    let (sound, confidence) = classifier.classify_level1(&crossing_features);

                    // Timing feedback
                    // Note: For level-crossing detection, we don't have precise onset timestamps.
                    // Return neutral "on-time" feedback. Future improvement: track sample counter.
                    let current_bpm = bpm.load(std::sync::atomic::Ordering::Relaxed);
                    let timing = if current_bpm > 0 {
                        quantizer.quantize(processed_samples)
                    } else {
                        // No metronome - no timing feedback
                        TimingFeedback {
                            classification: quantizer::TimingClassification::OnTime,
                            error_ms: 0.0,
                        }
                    };

                    // Timestamp is approximate for level-crossing detection
                    let timestamp_ms =
                        (processed_samples as f64 / sample_rate as f64 * 1000.0) as u64;

                    // Create result and send to Dart UI
                    let result = ClassificationResult {
                        sound,
                        timing,
                        timestamp_ms,
                        confidence,
                    };

                    eprintln!(
                        "[AnalysisThread] CLASSIFIED via level-crossing: {:?} (confidence {:.2})",
                        sound, confidence
                    );

                    // Send result to broadcast channel
                    telemetry::hub().record_classification(&result);
                    let _ = result_sender.send(result);
                }
            }

            // Process accumulated buffer through onset detection
            let onsets = onset_detector.process(&accumulator);

            if !onsets.is_empty() {
                tracing::info!("[AnalysisThread] Detected {} onsets", onsets.len());
            }

            // For each detected onset, run pipeline (calibration or classification mode)
            // IMPORTANT: Process onsets BEFORE clearing accumulator!
            //
            // Note: The onset detector returns timestamps relative to its total frames processed,
            // but since we clear the accumulator after each processing cycle, the timestamps
            // don't directly map to positions in the current buffer. Instead, we use the same
            // approach as level-crossing detection: extract the most recent 1024 samples,
            // which contain the onset (due to the onset detector's look-ahead delay).
            for onset_timestamp in onsets {
                // Avoid double-triggering if level-crossing detector already captured this event
                if processed_samples.saturating_sub(level_crossing_detector.last_capture_sample())
                    < debounce_samples
                {
                    tracing::debug!(
                        "[AnalysisThread] Skipping onset duplicate (captured via level-crossing)"
                    );
                    continue;
                }

                // Skip if accumulator doesn't have enough samples
                if accumulator.len() < 1024 {
                    tracing::debug!(
                        "[AnalysisThread] Skipping onset - accumulator too small: {} < 1024",
                        accumulator.len()
                    );
                    continue;
                }

                // Use the most recent 1024 samples (the onset is in this region due to detection delay)
                let onset_window = &accumulator[accumulator.len() - 1024..];
                let onset_rms = {
                    let sum_squares: f64 = onset_window
                        .iter()
                        .map(|&sample| (sample as f64) * (sample as f64))
                        .sum();
                    (sum_squares / onset_window.len() as f64).sqrt()
                };

                let max_amplitude = onset_window
                    .iter()
                    .map(|sample| sample.abs())
                    .fold(0.0f32, f32::max);
                // Extract DSP features (always needed for both modes)
                let features = feature_extractor.extract(onset_window);
                let features_for_progress = features;
                tracing::debug!(
                    "[AnalysisThread] Onset features: centroid {:.1} Hz, zcr {:.3}, rms {:.4}, max_amp {:.3}",
                    features.centroid,
                    features.zcr,
                    onset_rms,
                    max_amplitude
                );

                if calibration_active_snapshot {
                    // If we already captured in this gate window, skip to avoid double counts
                    if level_crossing_detector.is_captured_in_gate() {
                        continue;
                    }
                    // ====== CALIBRATION MODE ======
                    // Forward features to calibration procedure
                    if let Ok(mut procedure_guard) = calibration_procedure.lock() {
                        if let Some(ref mut procedure) = *procedure_guard {
                            let quiet_gate =
                                detection_threshold_snapshot.unwrap_or(quiet_clear_gate);
                            match procedure.add_sample(features, onset_rms, max_amplitude) {
                                Ok(()) => {
                                    tracing::info!(
                                        "[AnalysisThread] Onset sample accepted (rms {:.4}, max_amp {:.3})",
                                        onset_rms,
                                        max_amplitude
                                    );
                                    // Sample accepted - broadcast progress with debug snapshot
                                    let progress = procedure
                                        .get_progress_with_guidance_and_features(
                                            None,
                                            Some(&features_for_progress),
                                            Some(onset_rms),
                                            Some(max_amplitude),
                                        );
                                    debug_emit_counter = debug_emit_counter.wrapping_add(1);
                                    tracing::debug!(
                                        "[AnalysisThread] Progress debug [{}]: gate_rms {:?}, last_rms {:?}, last_centroid {:?}, last_zcr {:?}, last_max_amp {:?}, misses {}",
                                        debug_emit_counter,
                                        progress.debug.as_ref().and_then(|d| d.rms_gate),
                                        progress.debug.as_ref().and_then(|d| d.last_rms),
                                        progress.debug.as_ref().and_then(|d| d.last_centroid),
                                        progress.debug.as_ref().and_then(|d| d.last_zcr),
                                        progress.debug.as_ref().and_then(|d| d.last_max_amp),
                                        progress.debug.as_ref().map(|d| d.misses).unwrap_or(0),
                                    );
                                    if let Some(ref tx) = calibration_progress_tx {
                                        let _ = tx.send(progress);
                                    }
                                    guidance_limiter.clear();
                                }
                                Err(err) => {
                                    // Sample rejected (validation error) - keep warning to a minimum
                                    tracing::info!(
                                        "[AnalysisThread] Sample rejected: {:?} (misses: {}, gate_rms: {:?}, rms {:.4})",
                                        err,
                                        procedure.rejects_for_current_sound(),
                                        procedure.rms_gate_for_current(),
                                        onset_rms
                                    );
                                    let reason = if onset_rms < quiet_gate {
                                        CalibrationGuidanceReason::TooQuiet
                                    } else if max_amplitude >= 0.98 {
                                        CalibrationGuidanceReason::Clipped
                                    } else {
                                        CalibrationGuidanceReason::Stagnation
                                    };

                                    let mut guidance_payload = None;
                                    let now = Instant::now();

                                    if guidance_limiter.should_emit(reason, now) {
                                        guidance_payload = Some(CalibrationGuidance {
                                            sound: procedure.current_sound(),
                                            reason,
                                            level: onset_rms as f32,
                                            misses: procedure.rejects_for_current_sound(),
                                        });
                                    }

                                    let progress = procedure
                                        .get_progress_with_guidance_and_features(
                                            guidance_payload,
                                            Some(&features_for_progress),
                                            Some(onset_rms),
                                            Some(max_amplitude),
                                        );
                                    debug_emit_counter = debug_emit_counter.wrapping_add(1);
                                    tracing::debug!(
                                        "[AnalysisThread] Progress debug [{}]: gate_rms {:?}, last_rms {:?}, last_centroid {:?}, last_zcr {:?}, last_max_amp {:?}, misses {}",
                                        debug_emit_counter,
                                        progress.debug.as_ref().and_then(|d| d.rms_gate),
                                        progress.debug.as_ref().and_then(|d| d.last_rms),
                                        progress.debug.as_ref().and_then(|d| d.last_centroid),
                                        progress.debug.as_ref().and_then(|d| d.last_zcr),
                                        progress.debug.as_ref().and_then(|d| d.last_max_amp),
                                        progress.debug.as_ref().map(|d| d.misses).unwrap_or(0),
                                    );
                                    if let Some(ref tx) = calibration_progress_tx {
                                        let _ = tx.send(progress);
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // ====== CLASSIFICATION MODE ======
                    // Gate onset by noise floor to prevent false positives from ambient noise
                    // Use 2x noise floor as detection threshold (same as calibration)
                    let noise_floor_gate = match calibration_state.read() {
                        Ok(state) => state.noise_floor_rms * 2.0,
                        Err(_) => 0.02, // Conservative fallback
                    };

                    // Log every onset attempt for debugging
                    /*
                    eprintln!(
                        "[AnalysisThread] Onset: rms={:.4}, gate={:.4}, pass={}",
                        onset_rms,
                        noise_floor_gate,
                        onset_rms >= noise_floor_gate
                    );
                    */

                    if onset_rms < noise_floor_gate {
                        // Below noise floor - skip classification to avoid false positives
                        /*
                        eprintln!(
                            "[AnalysisThread] SKIPPED onset below noise floor: rms {:.4} < gate {:.4}",
                            onset_rms,
                            noise_floor_gate
                        );
                        */
                        continue;
                    }

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
            }

            // Clear accumulator for next batch (AFTER processing all onsets!)
            accumulator.clear();
        }
    })
}
