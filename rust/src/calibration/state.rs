// CalibrationState - threshold storage for sound classification
//
// This module stores threshold values used by the Classifier to distinguish
// between different beatbox sounds. Thresholds can be either default values
// or calibrated based on user-specific sound characteristics.
//
// This is a minimal implementation for task 3.3. Full implementation in task 3.5.

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
}
