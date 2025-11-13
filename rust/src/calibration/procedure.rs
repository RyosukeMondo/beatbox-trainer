// CalibrationProcedure - sample collection workflow
//
// This module manages the calibration workflow state machine for collecting
// user samples. The procedure follows a 3-step workflow:
// 1. Collect 10 kick drum samples
// 2. Collect 10 snare drum samples
// 3. Collect 10 hi-hat samples
//
// Each sample is validated before acceptance to ensure quality calibration.

use crate::analysis::features::Features;
use crate::calibration::progress::{CalibrationProgress, CalibrationSound};
use crate::calibration::state::CalibrationState;
use crate::calibration::validation::SampleValidator;
use crate::error::CalibrationError;

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
}

impl CalibrationProcedure {
    /// Create a new calibration procedure
    ///
    /// # Arguments
    /// * `samples_needed` - Number of samples to collect per sound type (default: 10)
    pub fn new(samples_needed: u8) -> Self {
        Self {
            kick_samples: Vec::new(),
            snare_samples: Vec::new(),
            hihat_samples: Vec::new(),
            current_sound: CalibrationSound::Kick,
            samples_needed,
        }
    }

    /// Create with default configuration (10 samples per sound)
    pub fn new_default() -> Self {
        Self::new(10)
    }

    /// Add a sample for the current sound
    ///
    /// # Arguments
    /// * `features` - Features extracted from the sound sample
    ///
    /// # Returns
    /// * `Ok(())` - Sample accepted
    /// * `Err(CalibrationError)` - Sample rejected (validation error)
    ///
    /// # Note
    /// Automatically advances to next sound when current sound is complete
    pub fn add_sample(&mut self, features: Features) -> Result<(), CalibrationError> {
        // Validate the sample
        SampleValidator::validate(&features)?;

        // Add to current sound collection
        match self.current_sound {
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

        // Auto-advance to next sound if current is complete
        if self.is_current_sound_complete() {
            if let Some(next_sound) = self.current_sound.next() {
                self.current_sound = next_sound;
            }
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
    pub fn get_progress(&self) -> CalibrationProgress {
        let samples_collected = self.get_current_sound_count();

        CalibrationProgress::new(
            self.current_sound,
            samples_collected as u8,
            self.samples_needed,
        )
    }

    /// Get the count of samples for the current sound
    fn get_current_sound_count(&self) -> usize {
        match self.current_sound {
            CalibrationSound::Kick => self.kick_samples.len(),
            CalibrationSound::Snare => self.snare_samples.len(),
            CalibrationSound::HiHat => self.hihat_samples.len(),
        }
    }

    /// Check if current sound collection is complete
    fn is_current_sound_complete(&self) -> bool {
        self.get_current_sound_count() >= self.samples_needed as usize
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

        CalibrationState::from_samples(&self.kick_samples, &self.snare_samples, &self.hihat_samples)
    }

    /// Reset the calibration procedure
    pub fn reset(&mut self) {
        self.kick_samples.clear();
        self.snare_samples.clear();
        self.hihat_samples.clear();
        self.current_sound = CalibrationSound::Kick;
    }

    /// Get the current sound being calibrated
    pub fn current_sound(&self) -> CalibrationSound {
        self.current_sound
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Helper function to create valid test features
    fn create_test_features(centroid: f32, zcr: f32) -> Features {
        Features {
            centroid,
            zcr,
            flatness: 0.5,
            rolloff: 5000.0,
            decay_time_ms: 50.0,
        }
    }

    #[test]
    fn test_new_default() {
        let procedure = CalibrationProcedure::new_default();
        assert_eq!(procedure.current_sound, CalibrationSound::Kick);
        assert_eq!(procedure.samples_needed, 10);
        assert_eq!(procedure.kick_samples.len(), 0);
    }

    #[test]
    fn test_add_sample_valid() {
        let mut procedure = CalibrationProcedure::new_default();
        let features = create_test_features(1000.0, 0.05);

        let result = procedure.add_sample(features);
        assert!(result.is_ok());
        assert_eq!(procedure.kick_samples.len(), 1);
    }

    #[test]
    fn test_add_sample_invalid_centroid_low() {
        let mut procedure = CalibrationProcedure::new_default();
        let features = create_test_features(30.0, 0.05); // Too low

        let result = procedure.add_sample(features);
        assert!(result.is_err());
        match result.unwrap_err() {
            CalibrationError::InvalidFeatures { reason } => {
                assert!(reason.contains("Centroid") && reason.contains("30"));
            }
            _ => panic!("Expected InvalidFeatures error"),
        }
    }

    #[test]
    fn test_add_sample_invalid_centroid_high() {
        let mut procedure = CalibrationProcedure::new_default();
        let features = create_test_features(25000.0, 0.05); // Too high

        let result = procedure.add_sample(features);
        assert!(result.is_err());
        match result.unwrap_err() {
            CalibrationError::InvalidFeatures { reason } => {
                assert!(reason.contains("Centroid") && reason.contains("25000"));
            }
            _ => panic!("Expected InvalidFeatures error"),
        }
    }

    #[test]
    fn test_add_sample_invalid_zcr_low() {
        let mut procedure = CalibrationProcedure::new_default();
        let features = create_test_features(1000.0, -0.1); // Too low

        let result = procedure.add_sample(features);
        assert!(result.is_err());
        match result.unwrap_err() {
            CalibrationError::InvalidFeatures { reason } => {
                assert!(reason.contains("ZCR") && reason.contains("-0.1"));
            }
            _ => panic!("Expected InvalidFeatures error"),
        }
    }

    #[test]
    fn test_add_sample_invalid_zcr_high() {
        let mut procedure = CalibrationProcedure::new_default();
        let features = create_test_features(1000.0, 1.5); // Too high

        let result = procedure.add_sample(features);
        assert!(result.is_err());
        match result.unwrap_err() {
            CalibrationError::InvalidFeatures { reason } => {
                assert!(reason.contains("ZCR") && reason.contains("1.5"));
            }
            _ => panic!("Expected InvalidFeatures error"),
        }
    }

    #[test]
    fn test_add_sample_auto_advance() {
        let mut procedure = CalibrationProcedure::new_default();
        let kick_features = create_test_features(1000.0, 0.05);

        // Add 10 kick samples
        for _ in 0..10 {
            procedure.add_sample(kick_features).unwrap();
        }

        // Should auto-advance to snare
        assert_eq!(procedure.current_sound, CalibrationSound::Snare);
        assert_eq!(procedure.kick_samples.len(), 10);
    }

    #[test]
    fn test_add_sample_full_workflow() {
        let mut procedure = CalibrationProcedure::new_default();
        let kick_features = create_test_features(1000.0, 0.05);
        let snare_features = create_test_features(3000.0, 0.15);
        let hihat_features = create_test_features(8000.0, 0.5);

        // Add 10 kick samples
        assert_eq!(procedure.current_sound, CalibrationSound::Kick);
        for _ in 0..10 {
            procedure.add_sample(kick_features).unwrap();
        }

        // Should advance to snare
        assert_eq!(procedure.current_sound, CalibrationSound::Snare);

        // Add 10 snare samples
        for _ in 0..10 {
            procedure.add_sample(snare_features).unwrap();
        }

        // Should advance to hi-hat
        assert_eq!(procedure.current_sound, CalibrationSound::HiHat);

        // Add 10 hi-hat samples
        for _ in 0..10 {
            procedure.add_sample(hihat_features).unwrap();
        }

        // Should still be on hi-hat (no next sound)
        assert_eq!(procedure.current_sound, CalibrationSound::HiHat);
        assert!(procedure.is_complete());
    }

    #[test]
    fn test_add_sample_reject_when_full() {
        let mut procedure = CalibrationProcedure::new_default();
        let features = create_test_features(1000.0, 0.05);

        // Fill up kick samples
        for _ in 0..10 {
            procedure.add_sample(features).unwrap();
        }

        // Manually set back to kick (simulating error condition)
        procedure.current_sound = CalibrationSound::Kick;

        // Try to add another kick sample - should fail
        let result = procedure.add_sample(features);
        assert!(result.is_err());
        assert!(matches!(
            result.unwrap_err(),
            CalibrationError::InsufficientSamples { .. }
        ));
    }

    #[test]
    fn test_get_progress() {
        let mut procedure = CalibrationProcedure::new_default();
        let features = create_test_features(1000.0, 0.05);

        // Initial progress
        let progress = procedure.get_progress();
        assert_eq!(progress.current_sound, CalibrationSound::Kick);
        assert_eq!(progress.samples_collected, 0);
        assert_eq!(progress.samples_needed, 10);

        // Add 5 samples
        for _ in 0..5 {
            procedure.add_sample(features).unwrap();
        }

        let progress = procedure.get_progress();
        assert_eq!(progress.samples_collected, 5);
        assert!(!progress.is_sound_complete());
    }

    #[test]
    fn test_is_complete() {
        let mut procedure = CalibrationProcedure::new_default();
        assert!(!procedure.is_complete());

        let kick_features = create_test_features(1000.0, 0.05);
        let snare_features = create_test_features(3000.0, 0.15);
        let hihat_features = create_test_features(8000.0, 0.5);

        // Add all samples
        for _ in 0..10 {
            procedure.add_sample(kick_features).unwrap();
        }
        assert!(!procedure.is_complete());

        for _ in 0..10 {
            procedure.add_sample(snare_features).unwrap();
        }
        assert!(!procedure.is_complete());

        for _ in 0..10 {
            procedure.add_sample(hihat_features).unwrap();
        }
        assert!(procedure.is_complete());
    }

    #[test]
    fn test_finalize_success() {
        let mut procedure = CalibrationProcedure::new_default();
        let kick_features = create_test_features(1000.0, 0.05);
        let snare_features = create_test_features(3000.0, 0.15);
        let hihat_features = create_test_features(8000.0, 0.5);

        // Add 10 kick samples
        for _ in 0..10 {
            procedure.add_sample(kick_features).unwrap();
        }

        // Add 10 snare samples
        for _ in 0..10 {
            procedure.add_sample(snare_features).unwrap();
        }

        // Add 10 hi-hat samples
        for _ in 0..10 {
            procedure.add_sample(hihat_features).unwrap();
        }

        let result = procedure.finalize();
        assert!(result.is_ok());

        let state = result.unwrap();
        // Use floating point tolerance
        assert!((state.t_kick_centroid - 1000.0 * 1.2).abs() < 0.01);
        assert!((state.t_kick_zcr - 0.05 * 1.2).abs() < 0.0001);
        assert!((state.t_snare_centroid - 3000.0 * 1.2).abs() < 0.01);
        assert!((state.t_hihat_zcr - 0.5 * 1.2).abs() < 0.0001);
        assert!(state.is_calibrated);
    }

    #[test]
    fn test_finalize_incomplete() {
        let mut procedure = CalibrationProcedure::new_default();
        let features = create_test_features(1000.0, 0.05);

        // Add only 5 kick samples
        for _ in 0..5 {
            procedure.add_sample(features).unwrap();
        }

        let result = procedure.finalize();
        assert!(result.is_err());
        assert!(matches!(
            result.unwrap_err(),
            CalibrationError::InsufficientSamples { .. }
        ));
    }

    #[test]
    fn test_reset() {
        let mut procedure = CalibrationProcedure::new_default();
        let features = create_test_features(1000.0, 0.05);

        // Add some samples
        for _ in 0..5 {
            procedure.add_sample(features).unwrap();
        }

        // Reset
        procedure.reset();

        assert_eq!(procedure.current_sound, CalibrationSound::Kick);
        assert_eq!(procedure.kick_samples.len(), 0);
        assert_eq!(procedure.snare_samples.len(), 0);
        assert_eq!(procedure.hihat_samples.len(), 0);
        assert!(!procedure.is_complete());
    }

    #[test]
    fn test_custom_sample_count() {
        let mut procedure = CalibrationProcedure::new(5); // 5 samples per sound
        let features = create_test_features(1000.0, 0.05);

        // Add 5 kick samples
        for _ in 0..5 {
            procedure.add_sample(features).unwrap();
        }

        // Should auto-advance to snare
        assert_eq!(procedure.current_sound, CalibrationSound::Snare);

        let progress = procedure.get_progress();
        assert_eq!(progress.samples_needed, 5);
    }
}
