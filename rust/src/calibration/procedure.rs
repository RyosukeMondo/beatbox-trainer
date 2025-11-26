// CalibrationProcedure - sample collection workflow
//
// This module manages the calibration workflow state machine for collecting
// user samples. The procedure follows a 4-step workflow:
// 1. Measure noise floor (user stays quiet for ~3 seconds)
// 2. Collect 10 kick drum samples
// 3. Collect 10 snare drum samples
// 4. Collect 10 hi-hat samples
//
// Each sample is validated before acceptance to ensure quality calibration.

use std::time::Instant;

use crate::analysis::features::Features;
use crate::calibration::progress::{
    CalibrationGuidance, CalibrationProgress, CalibrationProgressDebug, CalibrationSound,
};
use crate::calibration::state::CalibrationState;
use crate::error::CalibrationError;

#[path = "procedure_backoff.rs"]
mod procedure_backoff;
#[path = "procedure_factory.rs"]
mod procedure_factory;
#[path = "procedure_manual_accept.rs"]
mod procedure_manual_accept;

use procedure_backoff::AdaptiveBackoff;
use procedure_manual_accept::CandidateBuffer;

/// Default minimum time between accepting samples (milliseconds)
/// This prevents rapid-fire detection from noise
const DEFAULT_MIN_SAMPLE_INTERVAL_MS: u128 = 250;

/// Number of RMS samples needed for noise floor calibration
const NOISE_FLOOR_SAMPLES_NEEDED: u8 = 30;

/// Multiplier applied to noise floor RMS to set onset threshold (keep conservative)
const NOISE_FLOOR_THRESHOLD_MULTIPLIER: f64 = 1.2;

/// Minimum RMS threshold to prevent complete silence from being too sensitive
const MIN_RMS_THRESHOLD: f64 = 0.0025;

/// CalibrationProcedure manages the sample collection workflow
pub struct CalibrationProcedure {
    /// Collected kick samples
    kick_samples: Vec<Features>,
    /// Collected snare samples
    snare_samples: Vec<Features>,
    /// Collected hi-hat samples
    hihat_samples: Vec<Features>,
    /// Current sound being calibrated
    current_sound: CalibrationSound,
    /// Samples needed per sound (default: 10)
    samples_needed: u8,
    /// Last time a sample was accepted (for debouncing)
    last_sample_time: Option<Instant>,
    /// Minimum interval between samples in milliseconds (0 to disable debouncing)
    min_sample_interval_ms: u128,
    /// Collected RMS values during noise floor phase
    noise_floor_samples: Vec<f64>,
    /// Calculated noise floor RMS threshold (set after noise floor phase)
    noise_floor_threshold: Option<f64>,
    /// Whether waiting for user confirmation to proceed to next phase
    waiting_for_confirmation: bool,
    /// Adaptive gate state per sound (kick, snare, hi-hat)
    backoff: AdaptiveBackoff,
    /// Last rejected-but-valid candidate per sound
    last_candidates: CandidateBuffer,
    /// Last observed centroid for instrumentation
    last_centroid: Option<f32>,
    /// Last observed ZCR for instrumentation
    last_zcr: Option<f32>,
    /// Last observed RMS for instrumentation
    last_rms: Option<f64>,
    /// Last observed max amplitude for instrumentation
    last_max_amp: Option<f32>,
    /// Debug sequence counter
    debug_seq: u64,
}

impl CalibrationProcedure {
    /// Add an RMS sample during noise floor calibration
    ///
    /// # Arguments
    /// * `rms` - RMS value from the current audio buffer
    ///
    /// # Returns
    /// * `Ok(true)` - Noise floor calibration complete, ready for sound collection
    /// * `Ok(false)` - Still collecting noise floor samples
    /// * `Err` - Not in noise floor phase
    pub fn add_noise_floor_sample(&mut self, rms: f64) -> Result<bool, CalibrationError> {
        if self.current_sound != CalibrationSound::NoiseFloor {
            return Err(CalibrationError::InvalidFeatures {
                reason: "Not in noise floor calibration phase".to_string(),
            });
        }

        // If we've already collected enough and are waiting on the user, ignore
        // further samples to prevent unbounded progress counts.
        if self.waiting_for_confirmation {
            return Ok(true);
        }

        self.noise_floor_samples.push(rms);

        // Check if we have enough samples
        if self.noise_floor_samples.len() >= NOISE_FLOOR_SAMPLES_NEEDED as usize {
            // Calculate threshold: mean RMS * multiplier, with minimum floor
            let mean_rms: f64 = self.noise_floor_samples.iter().sum::<f64>()
                / self.noise_floor_samples.len() as f64;
            let max_rms: f64 = self.noise_floor_samples.iter().cloned().fold(0.0, f64::max);

            // Use whichever is higher: mean * multiplier or max * 1.5
            let threshold = (mean_rms * NOISE_FLOOR_THRESHOLD_MULTIPLIER)
                .max(max_rms * 1.3)
                .max(MIN_RMS_THRESHOLD);

            self.noise_floor_threshold = Some(threshold);
            self.backoff.update_noise_floor(self.noise_floor_threshold);
            self.waiting_for_confirmation = true; // Wait for user confirmation, DON'T auto-advance

            log::info!(
                "[CalibrationProcedure] Noise floor calibration complete. Mean RMS: {:.4}, Max RMS: {:.4}, Threshold: {:.4}. Waiting for user confirmation.",
                mean_rms, max_rms, threshold
            );

            return Ok(true);
        }

        Ok(false)
    }

    /// Get the current noise floor threshold (if calibrated)
    pub fn noise_floor_threshold(&self) -> Option<f64> {
        self.noise_floor_threshold
    }

    /// Check if noise floor calibration is complete
    pub fn is_noise_floor_complete(&self) -> bool {
        self.noise_floor_threshold.is_some()
    }

    /// Check if we're in noise floor phase
    pub fn is_in_noise_floor_phase(&self) -> bool {
        self.current_sound == CalibrationSound::NoiseFloor
    }

    /// Add a sample for the current sound
    ///
    /// # Arguments
    /// * `features` - Features extracted from the sound sample
    /// * `rms` - RMS level for the onset window associated with the sample
    ///
    /// # Returns
    /// * `Ok(())` - Sample accepted
    /// * `Err(CalibrationError)` - Sample rejected (validation error)
    ///
    /// # Note
    /// Sets waiting_for_confirmation when current sound is complete.
    /// User must call confirm_and_advance() to proceed to next sound.
    /// Must complete noise floor calibration first!
    pub fn add_sample(
        &mut self,
        features: Features,
        rms: f64,
        max_amp: f32,
    ) -> Result<(), CalibrationError> {
        let current_sound = self.current_sound;

        // Reject if waiting for user confirmation
        if self.waiting_for_confirmation {
            return Err(CalibrationError::InvalidFeatures {
                reason: "Waiting for user confirmation. Call confirm_and_advance() to proceed."
                    .to_string(),
            });
        }

        // Reject if still in noise floor phase
        if self.current_sound == CalibrationSound::NoiseFloor {
            return Err(CalibrationError::InvalidFeatures {
                reason: "Noise floor calibration not complete. Call add_noise_floor_sample first."
                    .to_string(),
            });
        }

        // Snapshot last observed values for instrumentation
        self.last_centroid = Some(features.centroid);
        self.last_zcr = Some(features.zcr);
        self.last_rms = Some(rms);
        self.last_max_amp = Some(max_amp);

        log::debug!(
            "[CalibrationProcedure] Evaluating {:?}: rms {:.4}, centroid {:.1}, zcr {:.3}, max_amp {:.3}",
            self.current_sound,
            rms,
            features.centroid,
            features.zcr,
            max_amp
        );

        // USER-CENTRIC CALIBRATION: Accept all sounds above noise floor
        // We learn what the user's sounds look like, not force them to match our expectations

        // Only reject if below 2x noise floor (clear separation from background noise)
        // Using 2x multiplier prevents flickering UI from borderline sounds
        if let Some(noise_threshold) = self.noise_floor_threshold {
            let detection_threshold = noise_threshold * 2.0;
            if rms < detection_threshold {
                self.store_candidate(current_sound, features);
                return Err(CalibrationError::InvalidFeatures {
                    reason: format!(
                        "Sound too quiet (RMS {:.4} < threshold {:.4}). Make it louder!",
                        rms, detection_threshold
                    ),
                });
            }
        }

        // Basic sanity check - reject obviously invalid features (hardware glitches)
        if features.centroid <= 0.0 || features.centroid > 20000.0 {
            return Err(CalibrationError::InvalidFeatures {
                reason: "Invalid frequency detected - please try again".to_string(),
            });
        }

        // Debounce: reject samples that come too fast (if debouncing is enabled)
        if self.min_sample_interval_ms > 0 {
            let now = Instant::now();
            if let Some(last_time) = self.last_sample_time {
                let elapsed_ms = now.duration_since(last_time).as_millis();
                if elapsed_ms < self.min_sample_interval_ms {
                    self.backoff.record_reject(self.current_sound, "debounce");
                    self.store_candidate(current_sound, features);
                    return Err(CalibrationError::InvalidFeatures {
                        reason: format!(
                            "Sample rejected: {}ms since last sample (minimum {}ms)",
                            elapsed_ms, self.min_sample_interval_ms
                        ),
                    });
                }
            }
        }

        // Update last sample time after validation passes (if debouncing is enabled)
        if self.min_sample_interval_ms > 0 {
            self.last_sample_time = Some(Instant::now());
        }

        // Add to current sound collection
        match self.current_sound {
            CalibrationSound::NoiseFloor => {
                // Already handled above
                unreachable!()
            }
            CalibrationSound::Kick => {
                Self::add_to_collection(&mut self.kick_samples, features, self.samples_needed)?;
            }
            CalibrationSound::Snare => {
                Self::add_to_collection(&mut self.snare_samples, features, self.samples_needed)?;
            }
            CalibrationSound::HiHat => {
                Self::add_to_collection(&mut self.hihat_samples, features, self.samples_needed)?;
            }
        }
        self.clear_candidate_for_sound(current_sound);

        // Log successful sample collection
        log::info!(
            "[CalibrationProcedure] {:?} sample {} accepted: centroid {:.1} Hz, zcr {:.3}",
            self.current_sound,
            self.get_current_sound_count(),
            features.centroid,
            features.zcr
        );

        // Set waiting_for_confirmation when current sound is complete (DON'T auto-advance)
        if self.is_current_sound_complete() {
            self.waiting_for_confirmation = true;
            log::info!(
                "[CalibrationProcedure] {:?} samples complete! Collected {} samples.",
                self.current_sound,
                self.get_current_sound_count()
            );
        }

        Ok(())
    }

    /// Add a feature to the given collection with capacity check
    fn add_to_collection(
        collection: &mut Vec<Features>,
        features: Features,
        samples_needed: u8,
    ) -> Result<(), CalibrationError> {
        if collection.len() >= samples_needed as usize {
            return Err(CalibrationError::InsufficientSamples {
                required: samples_needed as usize,
                collected: collection.len(),
            });
        }
        collection.push(features);
        Ok(())
    }

    /// Get current calibration progress
    pub fn get_progress(&mut self) -> CalibrationProgress {
        let (samples_collected, samples_needed) = match self.current_sound {
            CalibrationSound::NoiseFloor => (
                self.noise_floor_samples.len() as u8,
                NOISE_FLOOR_SAMPLES_NEEDED,
            ),
            _ => (self.get_current_sound_count() as u8, self.samples_needed),
        };

        CalibrationProgress::new(
            self.current_sound,
            samples_collected,
            samples_needed,
            self.waiting_for_confirmation,
        )
        .with_manual_accept(self.manual_accept_available())
        .with_debug(self.debug_payload(None, None, None))
    }

    /// Get progress with an attached guidance payload
    pub fn get_progress_with_guidance(
        &mut self,
        guidance: Option<CalibrationGuidance>,
    ) -> CalibrationProgress {
        self.get_progress_with_guidance_and_features(guidance, None, None, None)
    }

    /// Get progress with guidance and optional feature snapshot for debug
    pub fn get_progress_with_guidance_and_features(
        &mut self,
        guidance: Option<CalibrationGuidance>,
        features: Option<&Features>,
        rms: Option<f64>,
        max_amp: Option<f32>,
    ) -> CalibrationProgress {
        self.get_progress()
            .with_guidance(guidance)
            .with_debug(self.debug_payload(features, rms, max_amp))
    }

    /// Get the count of samples for the current sound
    fn get_current_sound_count(&self) -> usize {
        match self.current_sound {
            CalibrationSound::NoiseFloor => self.noise_floor_samples.len(),
            CalibrationSound::Kick => self.kick_samples.len(),
            CalibrationSound::Snare => self.snare_samples.len(),
            CalibrationSound::HiHat => self.hihat_samples.len(),
        }
    }

    /// Check if current sound collection is complete
    fn is_current_sound_complete(&self) -> bool {
        match self.current_sound {
            CalibrationSound::NoiseFloor => {
                self.noise_floor_samples.len() >= NOISE_FLOOR_SAMPLES_NEEDED as usize
            }
            _ => self.get_current_sound_count() >= self.samples_needed as usize,
        }
    }

    /// Check if entire calibration is complete
    pub fn is_complete(&self) -> bool {
        self.kick_samples.len() == self.samples_needed as usize
            && self.snare_samples.len() == self.samples_needed as usize
            && self.hihat_samples.len() == self.samples_needed as usize
    }

    /// Finalize calibration and create CalibrationState
    ///
    /// # Returns
    /// * `Ok(CalibrationState)` - Successfully calibrated state
    /// * `Err(CalibrationError)` - Calibration incomplete or invalid
    pub fn finalize(&self) -> Result<CalibrationState, CalibrationError> {
        if !self.is_complete() {
            return Err(CalibrationError::InsufficientSamples {
                required: self.samples_needed as usize * 3, // Total for all sounds
                collected: self.kick_samples.len()
                    + self.snare_samples.len()
                    + self.hihat_samples.len(),
            });
        }

        CalibrationState::from_samples(
            &self.kick_samples,
            &self.snare_samples,
            &self.hihat_samples,
            self.samples_needed as usize,
        )
    }

    /// Reset the calibration procedure
    pub fn reset(&mut self) {
        self.kick_samples.clear();
        self.snare_samples.clear();
        self.hihat_samples.clear();
        self.noise_floor_samples.clear();
        self.noise_floor_threshold = None;
        self.current_sound = CalibrationSound::NoiseFloor; // Start over from noise floor
        self.last_sample_time = None;
        self.waiting_for_confirmation = false;
        self.backoff.update_noise_floor(self.noise_floor_threshold);
        self.clear_all_candidates();
    }

    /// Check if waiting for user confirmation
    pub fn is_waiting_for_confirmation(&self) -> bool {
        self.waiting_for_confirmation
    }

    /// Whether manual accept is available for the current sound
    pub fn manual_accept_available(&self) -> bool {
        self.current_sound.is_sound_phase()
            && !self.waiting_for_confirmation
            && self.last_candidates.has_candidate(self.current_sound)
    }

    /// Get the number of consecutive rejects for the current sound
    pub fn rejects_for_current_sound(&self) -> u8 {
        self.backoff
            .rejects_for(self.current_sound)
            .unwrap_or_default()
    }

    /// User confirms current phase is OK, advance to next sound
    ///
    /// # Returns
    /// * `Ok(true)` - Advanced to next sound
    /// * `Ok(false)` - Calibration complete (was on last sound)
    /// * `Err` - Not waiting for confirmation
    pub fn confirm_and_advance(&mut self) -> Result<bool, CalibrationError> {
        if !self.waiting_for_confirmation {
            return Err(CalibrationError::InvalidFeatures {
                reason: "Not waiting for confirmation".to_string(),
            });
        }

        self.waiting_for_confirmation = false;

        if let Some(next_sound) = self.current_sound.next() {
            log::info!(
                "[CalibrationProcedure] User confirmed {:?}. Advancing to {:?}.",
                self.current_sound,
                next_sound
            );
            self.current_sound = next_sound;
            self.backoff.reset_for_sound(self.current_sound);
            self.clear_all_candidates();
            Ok(true)
        } else {
            log::info!(
                "[CalibrationProcedure] User confirmed {:?}. Calibration complete!",
                self.current_sound
            );
            self.backoff.reset_for_sound(self.current_sound);
            self.clear_all_candidates();
            Ok(false) // Calibration complete
        }
    }

    /// User wants to retry current phase, clear samples and restart
    ///
    /// # Returns
    /// * `Ok(())` - Current phase reset
    /// * `Err` - Not waiting for confirmation
    pub fn retry_current_sound(&mut self) -> Result<(), CalibrationError> {
        if !self.waiting_for_confirmation {
            return Err(CalibrationError::InvalidFeatures {
                reason: "Not waiting for confirmation".to_string(),
            });
        }

        log::info!(
            "[CalibrationProcedure] User requested retry for {:?}. Clearing samples.",
            self.current_sound
        );

        // Clear samples for current phase
        match self.current_sound {
            CalibrationSound::NoiseFloor => {
                self.noise_floor_samples.clear();
                self.noise_floor_threshold = None;
            }
            CalibrationSound::Kick => {
                self.kick_samples.clear();
            }
            CalibrationSound::Snare => {
                self.snare_samples.clear();
            }
            CalibrationSound::HiHat => {
                self.hihat_samples.clear();
            }
        }

        self.waiting_for_confirmation = false;
        self.last_sample_time = None; // Reset debounce timer
        self.backoff.reset_for_sound(self.current_sound);
        self.clear_candidate_for_sound(self.current_sound);
        Ok(())
    }

    /// Get the current sound being calibrated
    pub fn current_sound(&self) -> CalibrationSound {
        self.current_sound
    }

    /// Update last-seen feature snapshot for instrumentation without affecting gates.
    ///
    /// Used by the analysis thread to push live readings even when no onsets
    /// are accepted so the UI can guide the user in real time.
    pub fn update_last_features_for_debug(&mut self, features: &Features, rms: f64, max_amp: f32) {
        if !self.current_sound.is_sound_phase() {
            return;
        }

        self.last_centroid = Some(features.centroid);
        self.last_zcr = Some(features.zcr);
        self.last_rms = Some(rms);
        self.last_max_amp = Some(max_amp);
    }

    /// Current RMS gate for the active sound
    pub fn rms_gate_for_current(&self) -> Option<f64> {
        self.backoff.rms_gate(self.current_sound)
    }

    /// Debug payload for UI instrumentation
    fn debug_payload(
        &mut self,
        features: Option<&Features>,
        rms: Option<f64>,
        max_amp: Option<f32>,
    ) -> Option<CalibrationProgressDebug> {
        // Only emit for sound phases to avoid noise-floor gate confusion
        if !self.current_sound.is_sound_phase() {
            return None;
        }
        let gates = self.backoff.gate_state(self.current_sound)?;
        self.debug_seq = self.debug_seq.wrapping_add(1);
        Some(CalibrationProgressDebug {
            seq: self.debug_seq,
            rms_gate: self.backoff.rms_gate(self.current_sound),
            centroid_min: gates.centroid_min,
            centroid_max: gates.centroid_max,
            zcr_min: gates.zcr_min,
            zcr_max: gates.zcr_max,
            misses: gates.rejects,
            last_centroid: features.map(|f| f.centroid).or(self.last_centroid),
            last_zcr: features.map(|f| f.zcr).or(self.last_zcr),
            last_rms: rms.or(self.last_rms),
            last_max_amp: max_amp.or(self.last_max_amp),
        })
    }
}

#[cfg(test)]
#[path = "procedure_tests.rs"]
mod tests;

#[cfg(test)]
#[path = "procedure_adaptive_tests.rs"]
mod adaptive_tests;
