// Temporal module - Time-domain feature extraction
//
// This module computes features directly from time-domain audio signals.
// These features capture temporal characteristics like zero-crossing rate
// and amplitude envelope decay.
//
// References:
// - Peeters, G. (2004). A large set of audio features for sound description
// - Lerch, A. (2012). An Introduction to Audio Content Analysis

/// Temporal feature computation functions
pub struct TemporalFeatures {
    sample_rate: u32,
}

impl TemporalFeatures {
    /// Create a new temporal features processor
    ///
    /// # Arguments
    /// * `sample_rate` - Audio sample rate in Hz
    pub fn new(sample_rate: u32) -> Self {
        Self { sample_rate }
    }

    /// Compute zero-crossing rate (ZCR)
    ///
    /// Formula: ZCR = (1 / (2N)) × Σ|sign(x[n]) - sign(x[n-1])|
    ///
    /// ZCR measures how often the signal changes sign (crosses zero).
    /// High ZCR indicates high-frequency or noise-like content.
    /// Low ZCR indicates low-frequency or tonal content.
    ///
    /// # Arguments
    /// * `audio` - Time-domain audio signal
    ///
    /// # Returns
    /// Zero-crossing rate (0.0 to 1.0)
    pub fn compute_zcr(&self, audio: &[f32]) -> f32 {
        if audio.len() < 2 {
            return 0.0;
        }

        let mut crossings = 0;
        for i in 1..audio.len() {
            // Check if sign changed (zero crossing)
            if (audio[i] >= 0.0 && audio[i - 1] < 0.0) || (audio[i] < 0.0 && audio[i - 1] >= 0.0) {
                crossings += 1;
            }
        }

        // Normalize by signal length
        crossings as f32 / (audio.len() - 1) as f32
    }

    /// Compute temporal envelope decay time
    ///
    /// Measures how quickly the signal amplitude decays from its peak.
    /// This is useful for distinguishing between percussive sounds with
    /// different attack/decay characteristics (e.g., kick vs. hi-hat).
    ///
    /// Method: Find time from peak amplitude to -20dB decay point
    /// (-20dB corresponds to 10% of peak amplitude in linear scale)
    ///
    /// # Arguments
    /// * `audio` - Time-domain audio signal
    ///
    /// # Returns
    /// Decay time in milliseconds
    pub fn compute_decay_time(&self, audio: &[f32]) -> f32 {
        if audio.is_empty() {
            return 0.0;
        }

        // Compute envelope (simple method: absolute values with smoothing)
        let envelope: Vec<f32> = audio.iter().map(|&x| x.abs()).collect();

        // Find peak position and amplitude
        let (peak_idx, &peak_amp) = envelope
            .iter()
            .enumerate()
            .max_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal))
            .unwrap_or((0, &0.0));

        if peak_amp < 1e-6 {
            return 0.0;
        }

        // Calculate -20dB threshold (10% of peak amplitude in linear scale)
        let decay_threshold = peak_amp * 0.1;

        // Find first point after peak that crosses threshold
        for (i, &amp) in envelope[peak_idx..].iter().enumerate() {
            if amp < decay_threshold {
                let decay_samples = i as f32;
                let decay_time_ms = (decay_samples / self.sample_rate as f32) * 1000.0;
                return decay_time_ms;
            }
        }

        // If no decay found, return duration from peak to end
        let remaining_samples = (audio.len() - peak_idx) as f32;
        (remaining_samples / self.sample_rate as f32) * 1000.0
    }
}
