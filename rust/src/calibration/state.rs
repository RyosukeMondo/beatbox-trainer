// CalibrationState - threshold storage for sound classification
//
// This module stores threshold values used by the Classifier to distinguish
// between different beatbox sounds. Thresholds can be either default values
// or calibrated based on user-specific sound characteristics.
//
// Thresholds are calculated from calibration samples using mean + 20% margin.
// This provides a balance between accuracy and robustness.

use crate::analysis::features::Features;
use crate::error::CalibrationError;

/// CalibrationState stores thresholds for sound classification
#[derive(Debug, Clone)]
pub struct CalibrationState {
    /// Threshold for kick drum centroid (Hz)
    pub t_kick_centroid: f32,
    /// Threshold for kick drum ZCR
    pub t_kick_zcr: f32,
    /// Threshold for snare drum centroid (Hz)
    pub t_snare_centroid: f32,
    /// Threshold for hi-hat ZCR
    pub t_hihat_zcr: f32,
    /// Whether the system has been calibrated
    pub is_calibrated: bool,
}

impl CalibrationState {
    /// Create default calibration state with hardcoded thresholds
    ///
    /// Default values from design.md:
    /// - t_kick_centroid = 1500 Hz
    /// - t_kick_zcr = 0.1
    /// - t_snare_centroid = 4000 Hz
    /// - t_hihat_zcr = 0.3
    pub fn new_default() -> Self {
        Self {
            t_kick_centroid: 1500.0,
            t_kick_zcr: 0.1,
            t_snare_centroid: 4000.0,
            t_hihat_zcr: 0.3,
            is_calibrated: false,
        }
    }

    /// Create calibrated state from user samples
    ///
    /// Computes thresholds from calibration samples using mean + 20% margin.
    /// Each sound type must provide exactly 10 samples for robust calibration.
    ///
    /// # Arguments
    /// * `kick_samples` - Features extracted from 10 kick drum sounds
    /// * `snare_samples` - Features extracted from 10 snare drum sounds
    /// * `hihat_samples` - Features extracted from 10 hi-hat sounds
    ///
    /// # Returns
    /// * `Ok(CalibrationState)` - Successfully calibrated state
    /// * `Err(CalibrationError)` - Validation error (wrong sample count or out-of-range features)
    ///
    /// # Validation
    /// - Requires exactly 10 samples per sound type
    /// - Centroid must be in range [50 Hz, 20000 Hz]
    /// - ZCR must be in range [0.0, 1.0]
    pub fn from_samples(
        kick_samples: &[Features],
        snare_samples: &[Features],
        hihat_samples: &[Features],
    ) -> Result<Self, CalibrationError> {
        // Validate sample counts
        if kick_samples.len() != 10 {
            return Err(CalibrationError::InsufficientSamples {
                required: 10,
                collected: kick_samples.len(),
            });
        }
        if snare_samples.len() != 10 {
            return Err(CalibrationError::InsufficientSamples {
                required: 10,
                collected: snare_samples.len(),
            });
        }
        if hihat_samples.len() != 10 {
            return Err(CalibrationError::InsufficientSamples {
                required: 10,
                collected: hihat_samples.len(),
            });
        }

        // Validate and compute kick thresholds
        Self::validate_samples(kick_samples, "kick")?;
        let kick_centroid_mean = Self::compute_mean_centroid(kick_samples);
        let kick_zcr_mean = Self::compute_mean_zcr(kick_samples);

        // Validate and compute snare thresholds
        Self::validate_samples(snare_samples, "snare")?;
        let snare_centroid_mean = Self::compute_mean_centroid(snare_samples);

        // Validate and compute hi-hat thresholds
        Self::validate_samples(hihat_samples, "hi-hat")?;
        let hihat_zcr_mean = Self::compute_mean_zcr(hihat_samples);

        // Apply 20% margin to thresholds
        // Thresholds are positioned between the sound types
        Ok(Self {
            t_kick_centroid: kick_centroid_mean * 1.2,
            t_kick_zcr: kick_zcr_mean * 1.2,
            t_snare_centroid: snare_centroid_mean * 1.2,
            t_hihat_zcr: hihat_zcr_mean * 1.2,
            is_calibrated: true,
        })
    }

    /// Validate that all samples are within acceptable ranges
    ///
    /// # Arguments
    /// * `samples` - Features to validate
    /// * `sound_name` - Name of sound type for error messages
    ///
    /// # Returns
    /// * `Ok(())` - All samples valid
    /// * `Err(CalibrationError)` - Validation error with details
    fn validate_samples(samples: &[Features], sound_name: &str) -> Result<(), CalibrationError> {
        for (i, features) in samples.iter().enumerate() {
            // Validate centroid range [50 Hz, 20000 Hz]
            if features.centroid < 50.0 || features.centroid > 20000.0 {
                return Err(CalibrationError::InvalidFeatures {
                    reason: format!(
                        "{} sample {}: centroid {} Hz out of range [50, 20000]",
                        sound_name, i, features.centroid
                    ),
                });
            }

            // Validate ZCR range [0.0, 1.0]
            if features.zcr < 0.0 || features.zcr > 1.0 {
                return Err(CalibrationError::InvalidFeatures {
                    reason: format!(
                        "{} sample {}: ZCR {} out of range [0.0, 1.0]",
                        sound_name, i, features.zcr
                    ),
                });
            }
        }
        Ok(())
    }

    /// Compute mean centroid from feature samples
    fn compute_mean_centroid(samples: &[Features]) -> f32 {
        let sum: f32 = samples.iter().map(|f| f.centroid).sum();
        sum / samples.len() as f32
    }

    /// Compute mean zero-crossing rate from feature samples
    fn compute_mean_zcr(samples: &[Features]) -> f32 {
        let sum: f32 = samples.iter().map(|f| f.zcr).sum();
        sum / samples.len() as f32
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

    /// Helper function to create 10 identical features
    fn create_test_samples(centroid: f32, zcr: f32) -> Vec<Features> {
        vec![create_test_features(centroid, zcr); 10]
    }

    #[test]
    fn test_new_default() {
        let state = CalibrationState::new_default();

        assert_eq!(state.t_kick_centroid, 1500.0);
        assert_eq!(state.t_kick_zcr, 0.1);
        assert_eq!(state.t_snare_centroid, 4000.0);
        assert_eq!(state.t_hihat_zcr, 0.3);
        assert!(!state.is_calibrated);
    }

    #[test]
    fn test_from_samples_valid() {
        // Create valid samples with known values
        let kick_samples = create_test_samples(1000.0, 0.05);
        let snare_samples = create_test_samples(3000.0, 0.15);
        let hihat_samples = create_test_samples(8000.0, 0.5);

        let result = CalibrationState::from_samples(&kick_samples, &snare_samples, &hihat_samples);

        assert!(result.is_ok());
        let state = result.unwrap();

        // Check that thresholds are mean * 1.2 (with floating point tolerance)
        assert!((state.t_kick_centroid - 1000.0 * 1.2).abs() < 0.01);
        assert!((state.t_kick_zcr - 0.05 * 1.2).abs() < 0.0001);
        assert!((state.t_snare_centroid - 3000.0 * 1.2).abs() < 0.01);
        assert!((state.t_hihat_zcr - 0.5 * 1.2).abs() < 0.0001);
        assert!(state.is_calibrated);
    }

    #[test]
    fn test_from_samples_wrong_count_kick() {
        let kick_samples = create_test_samples(1000.0, 0.05)[..5].to_vec(); // Only 5 samples
        let snare_samples = create_test_samples(3000.0, 0.15);
        let hihat_samples = create_test_samples(8000.0, 0.5);

        let result = CalibrationState::from_samples(&kick_samples, &snare_samples, &hihat_samples);

        assert!(result.is_err());
        match result.unwrap_err() {
            crate::error::CalibrationError::InsufficientSamples {
                required: 10,
                collected: 5,
            } => {}
            e => panic!("Expected InsufficientSamples error, got: {:?}", e),
        }
    }

    #[test]
    fn test_from_samples_wrong_count_snare() {
        let kick_samples = create_test_samples(1000.0, 0.05);
        let snare_samples = create_test_samples(3000.0, 0.15)[..8].to_vec(); // Only 8 samples
        let hihat_samples = create_test_samples(8000.0, 0.5);

        let result = CalibrationState::from_samples(&kick_samples, &snare_samples, &hihat_samples);

        assert!(result.is_err());
        match result.unwrap_err() {
            crate::error::CalibrationError::InsufficientSamples {
                required: 10,
                collected: 8,
            } => {}
            e => panic!("Expected InsufficientSamples error, got: {:?}", e),
        }
    }

    #[test]
    fn test_from_samples_wrong_count_hihat() {
        let kick_samples = create_test_samples(1000.0, 0.05);
        let snare_samples = create_test_samples(3000.0, 0.15);
        // Create 12 samples explicitly
        let mut hihat_samples = create_test_samples(8000.0, 0.5);
        hihat_samples.push(create_test_features(8000.0, 0.5));
        hihat_samples.push(create_test_features(8000.0, 0.5));

        let result = CalibrationState::from_samples(&kick_samples, &snare_samples, &hihat_samples);

        assert!(result.is_err());
        match result.unwrap_err() {
            crate::error::CalibrationError::InsufficientSamples {
                required: 10,
                collected: 12,
            } => {}
            e => panic!("Expected InsufficientSamples error, got: {:?}", e),
        }
    }

    #[test]
    fn test_from_samples_centroid_too_low() {
        let kick_samples = create_test_samples(30.0, 0.05); // Centroid too low (< 50 Hz)
        let snare_samples = create_test_samples(3000.0, 0.15);
        let hihat_samples = create_test_samples(8000.0, 0.5);

        let result = CalibrationState::from_samples(&kick_samples, &snare_samples, &hihat_samples);

        assert!(result.is_err());
        match result.unwrap_err() {
            crate::error::CalibrationError::InvalidFeatures { reason } => {
                assert!(reason.contains("centroid") && reason.contains("30"));
            }
            e => panic!("Expected InvalidFeatures error, got: {:?}", e),
        }
    }

    #[test]
    fn test_from_samples_centroid_too_high() {
        let kick_samples = create_test_samples(1000.0, 0.05);
        let snare_samples = create_test_samples(25000.0, 0.15); // Centroid too high (> 20000 Hz)
        let hihat_samples = create_test_samples(8000.0, 0.5);

        let result = CalibrationState::from_samples(&kick_samples, &snare_samples, &hihat_samples);

        assert!(result.is_err());
        match result.unwrap_err() {
            crate::error::CalibrationError::InvalidFeatures { reason } => {
                assert!(reason.contains("centroid") && reason.contains("25000"));
            }
            e => panic!("Expected InvalidFeatures error, got: {:?}", e),
        }
    }

    #[test]
    fn test_from_samples_zcr_too_low() {
        let kick_samples = create_test_samples(1000.0, -0.1); // ZCR too low (< 0.0)
        let snare_samples = create_test_samples(3000.0, 0.15);
        let hihat_samples = create_test_samples(8000.0, 0.5);

        let result = CalibrationState::from_samples(&kick_samples, &snare_samples, &hihat_samples);

        assert!(result.is_err());
        match result.unwrap_err() {
            crate::error::CalibrationError::InvalidFeatures { reason } => {
                assert!(reason.contains("ZCR") && reason.contains("-0.1"));
            }
            e => panic!("Expected InvalidFeatures error, got: {:?}", e),
        }
    }

    #[test]
    fn test_from_samples_zcr_too_high() {
        let kick_samples = create_test_samples(1000.0, 0.05);
        let snare_samples = create_test_samples(3000.0, 0.15);
        let hihat_samples = create_test_samples(8000.0, 1.5); // ZCR too high (> 1.0)

        let result = CalibrationState::from_samples(&kick_samples, &snare_samples, &hihat_samples);

        assert!(result.is_err());
        match result.unwrap_err() {
            crate::error::CalibrationError::InvalidFeatures { reason } => {
                assert!(reason.contains("ZCR") && reason.contains("1.5"));
            }
            e => panic!("Expected InvalidFeatures error, got: {:?}", e),
        }
    }

    #[test]
    fn test_from_samples_mean_calculation() {
        // Create samples with varying values to test mean calculation
        let mut kick_samples = Vec::new();
        for i in 0..10 {
            kick_samples.push(create_test_features(1000.0 + i as f32 * 10.0, 0.05));
        }

        let snare_samples = create_test_samples(3000.0, 0.15);
        let hihat_samples = create_test_samples(8000.0, 0.5);

        let result = CalibrationState::from_samples(&kick_samples, &snare_samples, &hihat_samples);

        assert!(result.is_ok());
        let state = result.unwrap();

        // Mean of 1000, 1010, 1020, ..., 1090 = 1045
        let expected_kick_centroid = 1045.0 * 1.2;
        assert!((state.t_kick_centroid - expected_kick_centroid).abs() < 0.01);
    }

    #[test]
    fn test_from_samples_20_percent_margin() {
        let kick_samples = create_test_samples(1000.0, 0.1);
        let snare_samples = create_test_samples(2000.0, 0.2);
        let hihat_samples = create_test_samples(5000.0, 0.4);

        let result = CalibrationState::from_samples(&kick_samples, &snare_samples, &hihat_samples);

        assert!(result.is_ok());
        let state = result.unwrap();

        // Verify 20% margin (multiply by 1.2) with floating point tolerance
        assert!((state.t_kick_centroid - 1000.0 * 1.2).abs() < 0.01); // 1200.0
        assert!((state.t_kick_zcr - 0.1 * 1.2).abs() < 0.0001); // 0.12
        assert!((state.t_snare_centroid - 2000.0 * 1.2).abs() < 0.01); // 2400.0
        assert!((state.t_hihat_zcr - 0.4 * 1.2).abs() < 0.0001); // 0.48
    }

    #[test]
    fn test_validate_samples_edge_cases() {
        // Test samples at exact boundaries (should be valid)
        let kick_samples = create_test_samples(50.0, 0.0); // Min valid values
        let snare_samples = create_test_samples(20000.0, 1.0); // Max valid values
        let hihat_samples = create_test_samples(10000.0, 0.5);

        let result = CalibrationState::from_samples(&kick_samples, &snare_samples, &hihat_samples);

        assert!(result.is_ok());
    }
}
