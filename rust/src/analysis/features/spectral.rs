// Spectral module - Frequency-domain feature extraction
//
// This module computes spectral features from magnitude spectra.
// All features are based on the magnitude spectrum (absolute values of FFT bins).
//
// References:
// - Peeters, G. (2004). A large set of audio features for sound description
// - Lerch, A. (2012). An Introduction to Audio Content Analysis

/// Spectral rolloff threshold (85% of spectral energy)
const ROLLOFF_THRESHOLD: f32 = 0.85;

/// Spectral feature computation functions
pub struct SpectralFeatures {
    sample_rate: u32,
    fft_size: usize,
}

impl SpectralFeatures {
    /// Create a new spectral features processor
    ///
    /// # Arguments
    /// * `sample_rate` - Audio sample rate in Hz
    /// * `fft_size` - FFT window size
    pub fn new(sample_rate: u32, fft_size: usize) -> Self {
        Self {
            sample_rate,
            fft_size,
        }
    }

    /// Compute spectral centroid (weighted mean frequency)
    ///
    /// Formula: centroid = Σ(f_i × |X[i]|) / Σ|X[i]|
    ///
    /// The spectral centroid represents the "center of mass" of the spectrum,
    /// and is a measure of the brightness of a sound.
    ///
    /// # Arguments
    /// * `spectrum` - Magnitude spectrum
    ///
    /// # Returns
    /// Spectral centroid in Hz
    pub fn compute_centroid(&self, spectrum: &[f32]) -> f32 {
        let freq_bin_width = self.sample_rate as f32 / self.fft_size as f32;

        let weighted_sum: f32 = spectrum
            .iter()
            .enumerate()
            .map(|(i, &mag)| {
                let freq = i as f32 * freq_bin_width;
                freq * mag
            })
            .sum();

        let magnitude_sum: f32 = spectrum.iter().sum();

        if magnitude_sum > 1e-10 {
            weighted_sum / magnitude_sum
        } else {
            0.0
        }
    }

    /// Compute spectral flatness (tonality measure)
    ///
    /// Formula: flatness = geometric_mean(|X[i]|) / arithmetic_mean(|X[i]|)
    ///
    /// Returns value between 0 (tonal, e.g., sine wave) and 1 (noise-like).
    /// This is also known as the Wiener entropy.
    ///
    /// # Arguments
    /// * `spectrum` - Magnitude spectrum
    ///
    /// # Returns
    /// Spectral flatness (0.0 to 1.0)
    pub fn compute_flatness(&self, spectrum: &[f32]) -> f32 {
        if spectrum.is_empty() {
            return 0.0;
        }

        // Filter out zero or near-zero values for geometric mean
        let non_zero_spectrum: Vec<f32> = spectrum
            .iter()
            .filter(|&&mag| mag > 1e-10)
            .copied()
            .collect();

        if non_zero_spectrum.is_empty() {
            return 0.0;
        }

        // Geometric mean: exp(mean(log(x)))
        let log_sum: f32 = non_zero_spectrum.iter().map(|&mag| mag.ln()).sum();
        let geometric_mean = (log_sum / non_zero_spectrum.len() as f32).exp();

        // Arithmetic mean
        let arithmetic_mean: f32 =
            non_zero_spectrum.iter().sum::<f32>() / non_zero_spectrum.len() as f32;

        if arithmetic_mean > 1e-10 {
            (geometric_mean / arithmetic_mean).min(1.0)
        } else {
            0.0
        }
    }

    /// Compute spectral rolloff (85% energy threshold frequency)
    ///
    /// Finds the frequency below which 85% of the spectral energy is contained.
    /// This indicates the frequency range where most of the signal energy is concentrated.
    ///
    /// # Arguments
    /// * `spectrum` - Magnitude spectrum
    ///
    /// # Returns
    /// Rolloff frequency in Hz
    pub fn compute_rolloff(&self, spectrum: &[f32]) -> f32 {
        // Compute total energy
        let total_energy: f32 = spectrum.iter().map(|&mag| mag * mag).sum();

        if total_energy < 1e-10 {
            return 0.0;
        }

        let threshold = ROLLOFF_THRESHOLD * total_energy;
        let freq_bin_width = self.sample_rate as f32 / self.fft_size as f32;

        let mut cumulative_energy = 0.0;
        for (i, &mag) in spectrum.iter().enumerate() {
            cumulative_energy += mag * mag;
            if cumulative_energy >= threshold {
                return i as f32 * freq_bin_width;
            }
        }

        // If we reach here, return Nyquist frequency
        (spectrum.len() - 1) as f32 * freq_bin_width
    }
}
