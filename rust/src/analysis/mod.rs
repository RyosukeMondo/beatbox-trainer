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

struct AnalysisWorker {
    // Channels & Config
    analysis_channels: AnalysisThreadChannels,
    calibration_state: Arc<RwLock<CalibrationState>>,
    calibration_procedure: Arc<Mutex<Option<CalibrationProcedure>>>,
    calibration_progress_tx: Option<tokio::sync::broadcast::Sender<CalibrationProgress>>,
    frame_counter: Arc<AtomicU64>,
    bpm: Arc<AtomicU32>,
    sample_rate: u32,
    result_sender: tokio::sync::broadcast::Sender<ClassificationResult>,
    audio_metrics_tx: Option<tokio::sync::broadcast::Sender<AudioMetrics>>,
    log_every_n_buffers: u64,
    shutdown_flag: Option<Arc<AtomicBool>>,
    onset_config: OnsetDetectionConfig,

    // DSP Components
    onset_detector: OnsetDetector,
    feature_extractor: FeatureExtractor,
    classifier: Classifier,
    quantizer: Quantizer,
    level_crossing_detector: LevelCrossingDetector,

    // State
    accumulator: Vec<f32>,
    guidance_limiter: GuidanceRateLimiter,
    processed_samples: u64,
    last_noise_floor_samples: usize,
    debug_emit_counter: u64,
    last_progress_heartbeat: Instant,
    last_debug_probe: Instant,
}

impl AnalysisWorker {
    #[allow(clippy::too_many_arguments)]
    fn new(
        analysis_channels: AnalysisThreadChannels,
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
    ) -> Self {
        let onset_detector = OnsetDetector::with_config(sample_rate, onset_config.clone());
        let feature_extractor = FeatureExtractor::new(sample_rate);
        let classifier = Classifier::new(Arc::clone(&calibration_state));
        let quantizer = Quantizer::new(Arc::clone(&frame_counter), Arc::clone(&bpm), sample_rate);
        const LEVEL_CROSSING_DEBOUNCE_MS: u64 = 150;
        let level_crossing_detector =
            LevelCrossingDetector::new(sample_rate, LEVEL_CROSSING_DEBOUNCE_MS);

        let min_buffer_size = onset_config.min_buffer_size.max(64);
        let accumulator = Vec::with_capacity(min_buffer_size.max(2048));
        let guidance_limiter = GuidanceRateLimiter::new(Duration::from_secs(5));

        Self {
            analysis_channels,
            calibration_state,
            calibration_procedure,
            calibration_progress_tx,
            frame_counter,
            bpm,
            sample_rate,
            result_sender,
            audio_metrics_tx,
            log_every_n_buffers,
            shutdown_flag,
            onset_config,
            onset_detector,
            feature_extractor,
            classifier,
            quantizer,
            level_crossing_detector,
            accumulator,
            guidance_limiter,
            processed_samples: 0,
            last_noise_floor_samples: 0,
            debug_emit_counter: 0,
            last_progress_heartbeat: Instant::now(),
            last_debug_probe: Instant::now(),
        }
    }

    fn process_audio_metrics(&mut self, rms: f64) {
        if let Some(ref tx) = self.audio_metrics_tx {
            let current_frame = self.frame_counter.load(Ordering::Relaxed);
            let timestamp_ms = (current_frame as f64 / self.sample_rate as f64 * 1000.0) as u64;

            // Extract features for spectral centroid (only if we have enough samples)
            let features = if self.accumulator.len() >= 1024 {
                Some(
                    self.feature_extractor
                        .extract(&self.accumulator[self.accumulator.len() - 1024..]),
                )
            } else if !self.accumulator.is_empty() {
                Some(self.feature_extractor.extract(&self.accumulator))
            } else {
                None
            };

            let metrics = AudioMetrics {
                rms,
                spectral_centroid: features.map(|f| f.centroid as f64).unwrap_or(0.0),
                spectral_flux: self.onset_detector.last_spectral_flux() as f64,
                frame_number: current_frame,
                timestamp: timestamp_ms,
            };
            let _ = tx.send(metrics);
        }
    }

    fn process_noise_floor_calibration(&mut self, rms: f64) -> bool {
        let in_noise_floor_phase =
            if let Ok(procedure_guard) = self.calibration_procedure.try_lock() {
                procedure_guard
                    .as_ref()
                    .map(|p| p.is_in_noise_floor_phase())
                    .unwrap_or(false)
            } else {
                false
            };

        if in_noise_floor_phase {
            if let Ok(mut procedure_guard) = self.calibration_procedure.lock() {
                if let Some(ref mut procedure) = *procedure_guard {
                    match procedure.add_noise_floor_sample(rms) {
                        Ok(complete) => {
                            let progress = procedure.get_progress();
                            let samples = progress.samples_collected as usize;
                            if samples != self.last_noise_floor_samples {
                                if let Some(ref tx) = self.calibration_progress_tx {
                                    let _ = tx.send(progress.clone());
                                }
                                self.last_noise_floor_samples = samples;
                            }

                            if complete {
                                tracing::info!(
                                    "[AnalysisThread] Noise floor calibration complete! Threshold: {:?}",
                                    procedure.noise_floor_threshold()
                                );
                            }
                        }
                        Err(e) => {
                            tracing::warn!("[AnalysisThread] Noise floor sample rejected: {:?}", e);
                        }
                    }
                }
            }
            self.accumulator.clear();
            true
        } else {
            false
        }
    }

    fn process_level_crossing_calibration(&mut self, window_rms: f64, detection_threshold: f64) {
        if let Some(event) = self.level_crossing_detector.process_calibration(
            window_rms,
            detection_threshold,
            self.processed_samples,
        ) {
            let capture_window = &self.accumulator[self.accumulator.len() - 1024..];
            let capture_rms = window_rms;
            let capture_max_amp = capture_window
                .iter()
                .map(|sample| sample.abs())
                .fold(0.0f32, f32::max);
            let capture_features = self.feature_extractor.extract(capture_window);
            let capture_features_for_progress = capture_features;

            if let Ok(mut procedure_guard) = self.calibration_procedure.lock() {
                if let Some(ref mut procedure) = *procedure_guard {
                    match procedure.add_sample(capture_features, capture_rms, capture_max_amp) {
                        Ok(()) => {
                            tracing::info!(
                                "[AnalysisThread] Level-crossing event {:?} accepted (rms {:.4}, gate {:.4})",
                                event,
                                capture_rms,
                                detection_threshold
                            );
                            let progress = procedure.get_progress_with_guidance_and_features(
                                None,
                                Some(&capture_features_for_progress),
                                Some(capture_rms),
                                Some(capture_max_amp),
                            );
                            if let Some(ref tx) = self.calibration_progress_tx {
                                let _ = tx.send(progress);
                            }
                            self.guidance_limiter.clear();
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

    fn process_level_crossing_classification(&mut self, window_rms: f64, noise_floor_gate: f64) {
        if let Some(event) = self.level_crossing_detector.process_classification(
            window_rms,
            noise_floor_gate,
            self.processed_samples,
        ) {
            tracing::info!(
                "[AnalysisThread] Level crossing event {:?} for classification (rms {:.4}, gate {:.4})",
                event,
                window_rms,
                noise_floor_gate
            );

            // Extract features from the most recent 1024 samples
            let crossing_window = &self.accumulator[self.accumulator.len() - 1024..];
            let crossing_features = self.feature_extractor.extract(crossing_window);

            // Classify sound (returns tuple of (BeatboxHit, confidence))
            let (sound, confidence) = self.classifier.classify_level1(&crossing_features);

            // Timing feedback
            // Note: For level-crossing detection, we don't have precise onset timestamps.
            // Return neutral "on-time" feedback. Future improvement: track sample counter.
            let current_bpm = self.bpm.load(std::sync::atomic::Ordering::Relaxed);
            let timing = if current_bpm > 0 {
                self.quantizer.quantize(self.processed_samples)
            } else {
                // No metronome - no timing feedback
                TimingFeedback {
                    classification: quantizer::TimingClassification::OnTime,
                    error_ms: 0.0,
                }
            };

            // Timestamp is approximate for level-crossing detection
            let timestamp_ms =
                (self.processed_samples as f64 / self.sample_rate as f64 * 1000.0) as u64;

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
            let _ = self.result_sender.send(result);
        }
    }

    fn process_onsets(
        &mut self,
        onsets: Vec<u64>,
        calibration_active: bool,
        detection_threshold: Option<f64>,
        quiet_gate: f64,
        debounce_samples: u64,
    ) {
        for onset_timestamp in onsets {
            if self
                .processed_samples
                .saturating_sub(self.level_crossing_detector.last_capture_sample())
                < debounce_samples
            {
                tracing::debug!(
                    "[AnalysisThread] Skipping onset duplicate (captured via level-crossing)"
                );
                continue;
            }

            if self.accumulator.len() < 1024 {
                tracing::debug!(
                    "[AnalysisThread] Skipping onset - accumulator too small: {} < 1024",
                    self.accumulator.len()
                );
                continue;
            }

            let onset_window = &self.accumulator[self.accumulator.len() - 1024..];
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
            let features = self.feature_extractor.extract(onset_window);
            let features_for_progress = features;
            tracing::debug!(
                "[AnalysisThread] Onset features: centroid {:.1} Hz, zcr {:.3}, rms {:.4}, max_amp {:.3}",
                features.centroid,
                features.zcr,
                onset_rms,
                max_amplitude
            );

            if calibration_active {
                if self.level_crossing_detector.is_captured_in_gate() {
                    continue;
                }
                if let Ok(mut procedure_guard) = self.calibration_procedure.lock() {
                    if let Some(ref mut procedure) = *procedure_guard {
                        let quiet_gate = detection_threshold.unwrap_or(quiet_gate);
                        match procedure.add_sample(features, onset_rms, max_amplitude) {
                            Ok(()) => {
                                tracing::info!(
                                    "[AnalysisThread] Onset sample accepted (rms {:.4}, max_amp {:.3})",
                                    onset_rms,
                                    max_amplitude
                                );
                                let progress = procedure.get_progress_with_guidance_and_features(
                                    None,
                                    Some(&features_for_progress),
                                    Some(onset_rms),
                                    Some(max_amplitude),
                                );
                                self.debug_emit_counter = self.debug_emit_counter.wrapping_add(1);
                                tracing::debug!(
                                    "[AnalysisThread] Progress debug [{}]: gate_rms {:?}, last_rms {:?}, last_centroid {:?}, last_zcr {:?}, last_max_amp {:?}, misses {}",
                                    self.debug_emit_counter,
                                    progress.debug.as_ref().and_then(|d| d.rms_gate),
                                    progress.debug.as_ref().and_then(|d| d.last_rms),
                                    progress.debug.as_ref().and_then(|d| d.last_centroid),
                                    progress.debug.as_ref().and_then(|d| d.last_zcr),
                                    progress.debug.as_ref().and_then(|d| d.last_max_amp),
                                    progress.debug.as_ref().map(|d| d.misses).unwrap_or(0),
                                );
                                if let Some(ref tx) = self.calibration_progress_tx {
                                    let _ = tx.send(progress);
                                }
                                self.guidance_limiter.clear();
                            }
                            Err(err) => {
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

                                if self.guidance_limiter.should_emit(reason, now) {
                                    guidance_payload = Some(CalibrationGuidance {
                                        sound: procedure.current_sound(),
                                        reason,
                                        level: onset_rms as f32,
                                        misses: procedure.rejects_for_current_sound(),
                                    });
                                }

                                let progress = procedure.get_progress_with_guidance_and_features(
                                    guidance_payload,
                                    Some(&features_for_progress),
                                    Some(onset_rms),
                                    Some(max_amplitude),
                                );
                                self.debug_emit_counter = self.debug_emit_counter.wrapping_add(1);
                                tracing::debug!(
                                    "[AnalysisThread] Progress debug [{}]: gate_rms {:?}, last_rms {:?}, last_centroid {:?}, last_zcr {:?}, last_max_amp {:?}, misses {}",
                                    self.debug_emit_counter,
                                    progress.debug.as_ref().and_then(|d| d.rms_gate),
                                    progress.debug.as_ref().and_then(|d| d.last_rms),
                                    progress.debug.as_ref().and_then(|d| d.last_centroid),
                                    progress.debug.as_ref().and_then(|d| d.last_zcr),
                                    progress.debug.as_ref().and_then(|d| d.last_max_amp),
                                    progress.debug.as_ref().map(|d| d.misses).unwrap_or(0),
                                );
                                if let Some(ref tx) = self.calibration_progress_tx {
                                    let _ = tx.send(progress);
                                }
                            }
                        }
                    }
                }
            } else {
                let noise_floor_gate = match self.calibration_state.read() {
                    Ok(state) => state.noise_floor_rms * 2.0,
                    Err(_) => 0.02,
                };

                if onset_rms < noise_floor_gate {
                    continue;
                }

                let (sound, confidence) = self.classifier.classify_level1(&features);
                let current_bpm = self.bpm.load(std::sync::atomic::Ordering::Relaxed);
                let timing = if current_bpm > 0 {
                    self.quantizer.quantize(onset_timestamp)
                } else {
                    TimingFeedback {
                        classification: quantizer::TimingClassification::OnTime,
                        error_ms: 0.0,
                    }
                };

                let timestamp_ms =
                    (onset_timestamp as f64 / self.sample_rate as f64 * 1000.0) as u64;

                let result = ClassificationResult {
                    sound,
                    timing,
                    timestamp_ms,
                    confidence,
                };

                telemetry::hub().record_classification(&result);
                let _ = self.result_sender.send(result);
            }
        }
    }

    fn process_periodic_updates(&mut self, calibration_active: bool, window_rms: f64) {
        if !calibration_active {
            return;
        }

        if self.last_debug_probe.elapsed() >= Duration::from_millis(33) {
            let debug_window = if self.accumulator.len() >= 1024 {
                &self.accumulator[self.accumulator.len() - 1024..]
            } else {
                &self.accumulator[..]
            };
            let debug_features = self.feature_extractor.extract(debug_window);
            let debug_max_amp = debug_window
                .iter()
                .map(|sample| sample.abs())
                .fold(0.0f32, f32::max);
            if let Ok(mut procedure_guard) = self.calibration_procedure.try_lock() {
                if let Some(ref mut procedure) = *procedure_guard {
                    procedure.update_last_features_for_debug(
                        &debug_features,
                        window_rms,
                        debug_max_amp,
                    );
                }
            }
            self.last_debug_probe = Instant::now();
        }

        if self.last_progress_heartbeat.elapsed() >= Duration::from_millis(100) {
            if let Ok(mut procedure_guard) = self.calibration_procedure.try_lock() {
                if let Some(ref mut procedure) = *procedure_guard {
                    let progress =
                        procedure.get_progress_with_guidance_and_features(None, None, None, None);
                    self.debug_emit_counter = self.debug_emit_counter.wrapping_add(1);
                    tracing::debug!(
                        "[AnalysisThread] Progress heartbeat [{}]: gate_rms {:?}, last_rms {:?}, last_centroid {:?}, last_zcr {:?}, misses {}",
                        self.debug_emit_counter,
                        progress.debug.as_ref().and_then(|d| d.rms_gate),
                        progress.debug.as_ref().and_then(|d| d.last_rms),
                        progress.debug.as_ref().and_then(|d| d.last_centroid),
                        progress.debug.as_ref().and_then(|d| d.last_zcr),
                        progress.debug.as_ref().map(|d| d.misses).unwrap_or(0),
                    );
                    if let Some(ref tx) = self.calibration_progress_tx {
                        let _ = tx.send(progress);
                    }
                }
            }
            self.last_progress_heartbeat = Instant::now();
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn run(mut self) {
        eprintln!("[AnalysisThread] Thread started");
        eprintln!("[AnalysisThread] OnsetDetector created");
        eprintln!("[AnalysisThread] FeatureExtractor created");
        eprintln!("[AnalysisThread] Classifier created");
        eprintln!("[AnalysisThread] Quantizer created, entering loop");

        // Main analysis loop - runs until sender is dropped (audio engine stops)
        tracing::info!("[AnalysisThread] Starting analysis loop");

        // Log initial noise floor gate for debugging
        if let Ok(state) = self.calibration_state.read() {
            tracing::info!(
                "[AnalysisThread] Noise floor RMS from calibration: {:.4}, gate threshold: {:.4}",
                state.noise_floor_rms,
                state.noise_floor_rms * 2.0
            );
        }

        let min_buffer_size = self.onset_config.min_buffer_size.max(64);
        let log_interval = if self.log_every_n_buffers == 0 {
            None
        } else {
            Some(self.log_every_n_buffers)
        };

        let debounce_samples = (150 * self.sample_rate as u64) / 1000;

        loop {
            // Attempt to pop from queue
            let buffer = match self.analysis_channels.data_consumer.pop() {
                Ok(buf) => {
                    eprintln!("[AnalysisThread] Popped buffer len {}", buf.len());
                    buf
                }
                Err(PopError::Empty) => {
                    // Check shutdown flag only when queue is empty
                    if let Some(flag) = self.shutdown_flag.as_ref() {
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

            self.processed_samples += buffer.len() as u64;

            // Accumulate small buffers into larger chunks
            self.accumulator.extend_from_slice(&buffer);
            let occupancy = (self.accumulator.len().min(min_buffer_size) as f32
                / min_buffer_size as f32)
                .clamp(0.0, 1.0)
                * 100.0;
            telemetry::hub().record_buffer_occupancy("analysis_accumulator", occupancy);

            // Return buffer to pool immediately
            if self.analysis_channels.pool_producer.push(buffer).is_err() {
                tracing::warn!("[AnalysisThread] Pool queue full, dropping buffer");
            }

            // Only process when we have enough samples
            if self.accumulator.len() < min_buffer_size {
                continue;
            }

            // Calculate RMS for audio metrics (level meter)
            let rms: f64 = {
                let sum_squares: f64 = self
                    .accumulator
                    .iter()
                    .map(|&x| (x as f64) * (x as f64))
                    .sum();
                (sum_squares / self.accumulator.len() as f64).sqrt()
            };
            // More responsive RMS from the most recent window (used for gating)
            let window_rms: f64 = if self.accumulator.len() >= 1024 {
                let window = &self.accumulator[self.accumulator.len() - 1024..];
                let sum_squares: f64 = window.iter().map(|&x| (x as f64) * (x as f64)).sum();
                (sum_squares / window.len() as f64).sqrt()
            } else {
                rms
            };

            // Emit audio metrics for live level meter display
            self.process_audio_metrics(rms);

            // ====== NOISE FLOOR CALIBRATION PHASE ======
            if self.process_noise_floor_calibration(rms) {
                continue;
            }

            // Check if buffer contains non-zero samples
            static mut NON_ZERO_CHECK: u64 = 0;
            unsafe {
                NON_ZERO_CHECK += 1;
                if let Some(interval) = log_interval {
                    if interval > 0 && NON_ZERO_CHECK.is_multiple_of(interval) {
                        let max_amplitude = self
                            .accumulator
                            .iter()
                            .map(|x| x.abs())
                            .fold(0.0f32, f32::max);
                        tracing::info!(
                            "[AnalysisThread] Max amplitude in accumulated buffer: {}, RMS: {}",
                            max_amplitude,
                            rms
                        );
                    }
                }
            }

            let (calibration_active_snapshot, quiet_clear_gate) =
                if let Ok(procedure_guard) = self.calibration_procedure.try_lock() {
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
                if let Ok(procedure_guard) = self.calibration_procedure.try_lock() {
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
                && self.guidance_limiter.has_active()
                && rms < quiet_clear_gate
            {
                if let Ok(mut procedure_guard) = self.calibration_procedure.try_lock() {
                    if let Some(ref mut procedure) = *procedure_guard {
                        if let Some(ref tx) = self.calibration_progress_tx {
                            let _ =
                                tx.send(procedure.get_progress_with_guidance_and_features(
                                    None, None, None, None,
                                ));
                        }
                    }
                }
                self.guidance_limiter.clear();
            }

            // Push a light-weight debug probe and heartbeat
            self.process_periodic_updates(calibration_active_snapshot, window_rms);

            // ====== LEVEL-CROSSING DETECTOR FOR CALIBRATION ======
            // Simpler detection: capture sample when RMS crosses from below to above threshold
            // This runs IN ADDITION to onset detection, catching sounds that spectral flux misses
            if calibration_active_snapshot && self.accumulator.len() >= 1024 {
                let detection_threshold =
                    detection_threshold_snapshot.unwrap_or(quiet_clear_gate * 2.0); // 2x noise floor fallback

                self.process_level_crossing_calibration(window_rms, detection_threshold);
            }

            // ====== LEVEL-CROSSING DETECTOR FOR CLASSIFICATION ======
            // Same approach as calibration: detect when RMS crosses from below to above threshold
            // This is more reliable than onset detection which can fire on spectral changes in quiet audio
            if !calibration_active_snapshot && self.accumulator.len() >= 1024 {
                let noise_floor_gate = match self.calibration_state.read() {
                    Ok(state) => state.noise_floor_rms * 2.0,
                    Err(_) => 0.02, // Conservative fallback
                };

                self.process_level_crossing_classification(window_rms, noise_floor_gate);
            }

            // Process accumulated buffer through onset detection
            let onsets = self.onset_detector.process(&self.accumulator);

            if !onsets.is_empty() {
                tracing::info!("[AnalysisThread] Detected {} onsets", onsets.len());
            }

            self.process_onsets(
                onsets,
                calibration_active_snapshot,
                detection_threshold_snapshot,
                quiet_clear_gate,
                debounce_samples,
            );

            // Clear accumulator for next batch (AFTER processing all onsets!)
            self.accumulator.clear();
        }
    }
}

pub fn spawn_analysis_thread(
    analysis_channels: AnalysisThreadChannels,
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
        let worker = AnalysisWorker::new(
            analysis_channels,
            calibration_state,
            calibration_procedure,
            calibration_progress_tx,
            frame_counter,
            bpm,
            sample_rate,
            result_sender,
            onset_config,
            log_every_n_buffers,
            shutdown_flag,
            audio_metrics_tx,
        );
        worker.run();
    })
}
