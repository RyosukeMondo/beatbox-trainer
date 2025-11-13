// Sample validation logic for calibration
//
// This module provides validation functionality for audio feature samples
// during the calibration workflow. Validates that features are within
// acceptable ranges before acceptance.

use crate::analysis::features::Features;
use crate::error::CalibrationError;

/// Validator for calibration samples
pub struct SampleValidator;

impl SampleValidator {
    /// Validate a single sample
    ///
    /// # Arguments
    /// * `features` - Features to validate
    ///
    /// # Returns
    /// * `Ok(())` - Sample valid
    /// * `Err(CalibrationError)` - Validation error with details
    ///
    /// # Validation Rules
    /// * Centroid must be in range [50.0, 20000.0] Hz
    /// * ZCR must be in range [0.0, 1.0]
    pub fn validate(features: &Features) -> Result<(), CalibrationError> {
        // Validate centroid range [50 Hz, 20000 Hz]
        if features.centroid < 50.0 || features.centroid > 20000.0 {
            return Err(CalibrationError::InvalidFeatures {
                reason: format!("Centroid {} Hz out of range [50, 20000]", features.centroid),
            });
        }

        // Validate ZCR range [0.0, 1.0]
        if features.zcr < 0.0 || features.zcr > 1.0 {
            return Err(CalibrationError::InvalidFeatures {
                reason: format!("ZCR {} out of range [0.0, 1.0]", features.zcr),
            });
        }

        Ok(())
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
    fn test_validate_valid_sample() {
        let features = create_test_features(1000.0, 0.05);
        let result = SampleValidator::validate(&features);
        assert!(result.is_ok());
    }

    #[test]
    fn test_validate_invalid_centroid_low() {
        let features = create_test_features(30.0, 0.05);
        let result = SampleValidator::validate(&features);
        assert!(result.is_err());
        match result.unwrap_err() {
            CalibrationError::InvalidFeatures { reason } => {
                assert!(reason.contains("Centroid") && reason.contains("30"));
            }
            _ => panic!("Expected InvalidFeatures error"),
        }
    }

    #[test]
    fn test_validate_invalid_centroid_high() {
        let features = create_test_features(25000.0, 0.05);
        let result = SampleValidator::validate(&features);
        assert!(result.is_err());
        match result.unwrap_err() {
            CalibrationError::InvalidFeatures { reason } => {
                assert!(reason.contains("Centroid") && reason.contains("25000"));
            }
            _ => panic!("Expected InvalidFeatures error"),
        }
    }

    #[test]
    fn test_validate_invalid_zcr_low() {
        let features = create_test_features(1000.0, -0.1);
        let result = SampleValidator::validate(&features);
        assert!(result.is_err());
        match result.unwrap_err() {
            CalibrationError::InvalidFeatures { reason } => {
                assert!(reason.contains("ZCR") && reason.contains("-0.1"));
            }
            _ => panic!("Expected InvalidFeatures error"),
        }
    }

    #[test]
    fn test_validate_invalid_zcr_high() {
        let features = create_test_features(1000.0, 1.5);
        let result = SampleValidator::validate(&features);
        assert!(result.is_err());
        match result.unwrap_err() {
            CalibrationError::InvalidFeatures { reason } => {
                assert!(reason.contains("ZCR") && reason.contains("1.5"));
            }
            _ => panic!("Expected InvalidFeatures error"),
        }
    }

    #[test]
    fn test_validate_boundary_values() {
        // Test exact boundaries - should be valid
        let features_low = create_test_features(50.0, 0.0);
        assert!(SampleValidator::validate(&features_low).is_ok());

        let features_high = create_test_features(20000.0, 1.0);
        assert!(SampleValidator::validate(&features_high).is_ok());
    }
}
