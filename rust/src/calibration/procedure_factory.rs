#[cfg(test)]
use super::MIN_RMS_THRESHOLD;
use super::{
    AdaptiveBackoff, CalibrationProcedure, CalibrationSound, CandidateBuffer,
    DEFAULT_MIN_SAMPLE_INTERVAL_MS,
};

impl CalibrationProcedure {
    /// Create a new calibration procedure
    ///
    /// # Arguments
    /// * `samples_needed` - Number of samples to collect per sound type (default: 10)
    pub fn new(samples_needed: u8) -> Self {
        Self::with_debounce(samples_needed, DEFAULT_MIN_SAMPLE_INTERVAL_MS)
    }

    /// Create with custom debounce interval
    ///
    /// # Arguments
    /// * `samples_needed` - Number of samples to collect per sound type
    /// * `min_sample_interval_ms` - Minimum milliseconds between samples (0 to disable)
    pub fn with_debounce(samples_needed: u8, min_sample_interval_ms: u128) -> Self {
        Self {
            kick_samples: Vec::new(),
            snare_samples: Vec::new(),
            hihat_samples: Vec::new(),
            current_sound: CalibrationSound::NoiseFloor, // Start with noise floor
            samples_needed,
            last_sample_time: None,
            min_sample_interval_ms,
            noise_floor_samples: Vec::new(),
            noise_floor_threshold: None,
            waiting_for_confirmation: false,
            backoff: AdaptiveBackoff::new(None),
            last_candidates: CandidateBuffer::default(),
            last_centroid: None,
            last_zcr: None,
            last_rms: None,
            last_max_amp: None,
            debug_seq: 0,
        }
    }

    /// Create with default configuration (10 samples per sound)
    pub fn new_default() -> Self {
        Self::new(10)
    }

    /// Create for testing with no debounce and skip noise floor
    #[cfg(test)]
    pub fn new_for_test(samples_needed: u8) -> Self {
        let mut proc = Self::with_debounce(samples_needed, 0);
        // Skip noise floor phase for tests - set a default threshold
        proc.noise_floor_threshold = Some(MIN_RMS_THRESHOLD);
        proc.current_sound = CalibrationSound::Kick;
        proc.backoff.update_noise_floor(proc.noise_floor_threshold);
        proc
    }
}
