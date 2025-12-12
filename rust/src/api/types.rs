use crate::analysis::ClassificationResult;

/// Audio metrics for debug visualization
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct AudioMetrics {
    pub rms: f64,
    pub spectral_centroid: f64,
    pub spectral_flux: f64,
    pub frame_number: u64,
    pub timestamp: u64,
}

/// Onset event with classification details
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct OnsetEvent {
    pub timestamp: u64,
    pub energy: f64,
    pub centroid: f64,
    pub zcr: f64,
    pub flatness: f64,
    pub rolloff: f64,
    pub decay_time_ms: f64,
    pub classification: Option<ClassificationResult>,
}

/// Keys for updating calibration thresholds
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum CalibrationThresholdKey {
    KickCentroid,
    KickZcr,
    SnareCentroid,
    HihatZcr,
    NoiseFloorRms,
}
