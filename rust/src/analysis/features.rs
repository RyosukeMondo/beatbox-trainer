// FeatureExtractor - DSP feature extraction for beatbox sound classification
//
// This module extracts audio features used for distinguishing between different
// beatbox sounds (kick, snare, hi-hat). Features are computed from time-domain
// and frequency-domain representations of audio signals.
//
// Features extracted:
// 1. Spectral Centroid: Weighted mean frequency (brightness measure)
// 2. Zero-Crossing Rate (ZCR): Rate of sign changes (noise/tonality measure)
// 3. Spectral Flatness: Ratio of geometric to arithmetic mean (tonality measure)
// 4. Spectral Rolloff: Frequency below which 85% of energy is contained
// 5. Decay Time: Temporal envelope decay time (attack characteristics)
//
// References:
// - Peeters, G. (2004). A large set of audio features for sound description
// - Lerch, A. (2012). An Introduction to Audio Content Analysis

use rustfft::{FftPlanner, num_complex::Complex};
use std::sync::{Arc, Mutex};

/// FFT window size for feature extraction (higher resolution than onset detection)
const FFT_SIZE: usize = 1024;

/// Spectral rolloff threshold (85% of spectral energy)
const ROLLOFF_THRESHOLD: f32 = 0.85;

/// Features extracted from an audio window
#[derive(Debug, Clone, Copy)]
pub struct Features {
    /// Spectral centroid in Hz (weighted mean frequency)
    pub centroid: f32,
    /// Zero-crossing rate (0.0 to 1.0, normalized)
    pub zcr: f32,
    /// Spectral flatness (0.0 to 1.0, geometric/arithmetic mean ratio)
    pub flatness: f32,
    /// Spectral rolloff in Hz (85% energy threshold)
    pub rolloff: f32,
    /// Decay time in milliseconds (temporal envelope)
    pub decay_time_ms: f32,
}

/// FeatureExtractor computes DSP features for audio classification
pub struct FeatureExtractor {
    fft_planner: Arc<Mutex<FftPlanner<f32>>>,
    sample_rate: u32,
    fft_size: usize,
    // Hann window for FFT
    window: Vec<f32>,
}

impl FeatureExtractor {
    /// Create a new FeatureExtractor with the specified sample rate
    ///
    /// # Arguments
    /// * `sample_rate` - Audio sample rate in Hz (e.g., 48000)
    pub fn new(sample_rate: u32) -> Self {
        let fft_size = FFT_SIZE;

        // Pre-compute Hann window to reduce spectral leakage
        let window = (0..fft_size)
            .map(|i| {
                0.5 * (1.0 - ((2.0 * std::f32::consts::PI * i as f32) / (fft_size as f32 - 1.0)).cos())
            })
            .collect();

        Self {
            fft_planner: Arc::new(Mutex::new(FftPlanner::new())),
            sample_rate,
            fft_size,
            window,
        }
    }

    /// Extract all features from an audio window
    ///
    /// # Arguments
    /// * `audio` - Audio window (must be at least FFT_SIZE samples)
    ///
    /// # Returns
    /// Features struct containing all extracted features
    ///
    /// # Note
    /// If audio is longer than FFT_SIZE, only the first FFT_SIZE samples are used
    pub fn extract(&self, audio: &[f32]) -> Features {
        // Ensure we have enough samples
        let audio_window = if audio.len() >= self.fft_size {
            &audio[..self.fft_size]
        } else {
            // Pad with zeros if needed
            audio
        };

        // Compute magnitude spectrum
        let spectrum = self.compute_magnitude_spectrum(audio_window);

        // Extract frequency-domain features
        let centroid = self.compute_centroid(&spectrum);
        let flatness = self.compute_flatness(&spectrum);
        let rolloff = self.compute_rolloff(&spectrum);

        // Extract time-domain features
        let zcr = self.compute_zcr(audio_window);
        let decay_time_ms = self.compute_decay_time(audio_window);

        Features {
            centroid,
            zcr,
            flatness,
            rolloff,
            decay_time_ms,
        }
    }

    /// Compute magnitude spectrum using FFT
    ///
    /// # Arguments
    /// * `audio` - Audio window (length <= fft_size)
    ///
    /// # Returns
    /// Magnitude spectrum (size = fft_size / 2 + 1)
    fn compute_magnitude_spectrum(&self, audio: &[f32]) -> Vec<f32> {
        // Create zero-padded buffer if needed
        let mut buffer: Vec<Complex<f32>> = Vec::with_capacity(self.fft_size);

        for (i, &sample) in audio.iter().enumerate() {
            if i < self.fft_size {
                let windowed = sample * self.window[i];
                buffer.push(Complex::new(windowed, 0.0));
            }
        }

        // Pad with zeros if needed
        while buffer.len() < self.fft_size {
            buffer.push(Complex::new(0.0, 0.0));
        }

        // Perform FFT
        let mut planner = self.fft_planner.lock().unwrap();
        let fft = planner.plan_fft_forward(self.fft_size);
        fft.process(&mut buffer);

        // Calculate magnitude spectrum (only positive frequencies)
        buffer[..self.fft_size / 2 + 1]
            .iter()
            .map(|c| c.norm())
            .collect()
    }

    /// Compute spectral centroid (weighted mean frequency)
    ///
    /// Formula: centroid = Σ(f_i × |X[i]|) / Σ|X[i]|
    ///
    /// # Arguments
    /// * `spectrum` - Magnitude spectrum
    ///
    /// # Returns
    /// Spectral centroid in Hz
    fn compute_centroid(&self, spectrum: &[f32]) -> f32 {
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

    /// Compute zero-crossing rate (ZCR)
    ///
    /// Formula: ZCR = (1 / (2N)) × Σ|sign(x[n]) - sign(x[n-1])|
    ///
    /// # Arguments
    /// * `audio` - Time-domain audio signal
    ///
    /// # Returns
    /// Zero-crossing rate (0.0 to 1.0)
    fn compute_zcr(&self, audio: &[f32]) -> f32 {
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

    /// Compute spectral flatness (tonality measure)
    ///
    /// Formula: flatness = geometric_mean(|X[i]|) / arithmetic_mean(|X[i]|)
    ///
    /// Returns value between 0 (tonal, e.g., sine wave) and 1 (noise-like)
    ///
    /// # Arguments
    /// * `spectrum` - Magnitude spectrum
    ///
    /// # Returns
    /// Spectral flatness (0.0 to 1.0)
    fn compute_flatness(&self, spectrum: &[f32]) -> f32 {
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
        let arithmetic_mean: f32 = non_zero_spectrum.iter().sum::<f32>() / non_zero_spectrum.len() as f32;

        if arithmetic_mean > 1e-10 {
            (geometric_mean / arithmetic_mean).min(1.0)
        } else {
            0.0
        }
    }

    /// Compute spectral rolloff (85% energy threshold frequency)
    ///
    /// Finds the frequency below which 85% of the spectral energy is contained
    ///
    /// # Arguments
    /// * `spectrum` - Magnitude spectrum
    ///
    /// # Returns
    /// Rolloff frequency in Hz
    fn compute_rolloff(&self, spectrum: &[f32]) -> f32 {
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

    /// Compute temporal envelope decay time
    ///
    /// Measures how quickly the signal amplitude decays. Useful for distinguishing
    /// between percussive sounds with different attack/decay characteristics.
    ///
    /// Method: Find time from peak amplitude to -20dB decay point
    ///
    /// # Arguments
    /// * `audio` - Time-domain audio signal
    ///
    /// # Returns
    /// Decay time in milliseconds
    fn compute_decay_time(&self, audio: &[f32]) -> f32 {
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

#[cfg(test)]
mod tests {
    use super::*;

    /// Generate pure sine wave for testing
    fn generate_sine_wave(sample_rate: u32, frequency: f32, duration_samples: usize) -> Vec<f32> {
        (0..duration_samples)
            .map(|i| {
                let t = i as f32 / sample_rate as f32;
                (2.0 * std::f32::consts::PI * frequency * t).sin()
            })
            .collect()
    }

    /// Generate white noise for testing
    fn generate_white_noise(duration_samples: usize) -> Vec<f32> {
        use rand::Rng;
        let mut rng = rand::thread_rng();
        (0..duration_samples)
            .map(|_| rng.gen_range(-1.0..1.0))
            .collect()
    }

    /// Generate exponentially decaying envelope for testing
    fn generate_decaying_signal(sample_rate: u32, duration_samples: usize, decay_time_ms: f32) -> Vec<f32> {
        let decay_time_samples = (decay_time_ms / 1000.0) * sample_rate as f32;
        (0..duration_samples)
            .map(|i| {
                let t = i as f32;
                (-t / decay_time_samples).exp()
            })
            .collect()
    }

    #[test]
    fn test_feature_extractor_creation() {
        let sample_rate = 48000;
        let extractor = FeatureExtractor::new(sample_rate);
        assert_eq!(extractor.sample_rate, sample_rate);
        assert_eq!(extractor.fft_size, FFT_SIZE);
    }

    #[test]
    fn test_centroid_low_frequency() {
        let sample_rate = 48000;
        let extractor = FeatureExtractor::new(sample_rate);

        // Generate 100 Hz sine wave
        let signal = generate_sine_wave(sample_rate, 100.0, FFT_SIZE);
        let features = extractor.extract(&signal);

        // Centroid should be around 100 Hz (low frequency)
        assert!(
            features.centroid < 500.0,
            "Expected centroid < 500 Hz for 100 Hz sine, got {} Hz",
            features.centroid
        );
        println!("100 Hz sine centroid: {} Hz", features.centroid);
    }

    #[test]
    fn test_centroid_high_frequency() {
        let sample_rate = 48000;
        let extractor = FeatureExtractor::new(sample_rate);

        // Generate 5000 Hz sine wave
        let signal = generate_sine_wave(sample_rate, 5000.0, FFT_SIZE);
        let features = extractor.extract(&signal);

        // Centroid should be around 5000 Hz (high frequency)
        assert!(
            features.centroid > 3000.0,
            "Expected centroid > 3000 Hz for 5000 Hz sine, got {} Hz",
            features.centroid
        );
        println!("5000 Hz sine centroid: {} Hz", features.centroid);
    }

    #[test]
    fn test_zcr_sine_vs_noise() {
        let sample_rate = 48000;
        let extractor = FeatureExtractor::new(sample_rate);

        // Low-frequency sine wave (100 Hz) should have low ZCR
        let sine_signal = generate_sine_wave(sample_rate, 100.0, FFT_SIZE);
        let sine_features = extractor.extract(&sine_signal);

        // White noise should have high ZCR (around 0.5 for random noise)
        let noise_signal = generate_white_noise(FFT_SIZE);
        let noise_features = extractor.extract(&noise_signal);

        println!("Sine (100 Hz) ZCR: {}", sine_features.zcr);
        println!("White noise ZCR: {}", noise_features.zcr);

        // Noise should have significantly higher ZCR than sine
        assert!(
            noise_features.zcr > 0.3,
            "Expected noise ZCR > 0.3, got {}",
            noise_features.zcr
        );
        assert!(
            sine_features.zcr < 0.1,
            "Expected sine ZCR < 0.1, got {}",
            sine_features.zcr
        );
    }

    #[test]
    fn test_flatness_sine_vs_noise() {
        let sample_rate = 48000;
        let extractor = FeatureExtractor::new(sample_rate);

        // Pure sine wave should have low flatness (tonal)
        let sine_signal = generate_sine_wave(sample_rate, 1000.0, FFT_SIZE);
        let sine_features = extractor.extract(&sine_signal);

        // White noise should have high flatness (noise-like)
        let noise_signal = generate_white_noise(FFT_SIZE);
        let noise_features = extractor.extract(&noise_signal);

        println!("Sine flatness: {}", sine_features.flatness);
        println!("Noise flatness: {}", noise_features.flatness);

        // Sine should be more tonal (lower flatness)
        assert!(
            sine_features.flatness < 0.2,
            "Expected sine flatness < 0.2, got {}",
            sine_features.flatness
        );
        // Noise should be more noise-like (higher flatness)
        assert!(
            noise_features.flatness > 0.5,
            "Expected noise flatness > 0.5, got {}",
            noise_features.flatness
        );
    }

    #[test]
    fn test_rolloff_calculation() {
        let sample_rate = 48000;
        let extractor = FeatureExtractor::new(sample_rate);

        // Low-frequency signal should have low rolloff
        let low_freq_signal = generate_sine_wave(sample_rate, 200.0, FFT_SIZE);
        let low_features = extractor.extract(&low_freq_signal);

        // High-frequency signal should have higher rolloff
        let high_freq_signal = generate_sine_wave(sample_rate, 8000.0, FFT_SIZE);
        let high_features = extractor.extract(&high_freq_signal);

        println!("Low freq (200 Hz) rolloff: {} Hz", low_features.rolloff);
        println!("High freq (8000 Hz) rolloff: {} Hz", high_features.rolloff);

        // High frequency signal should have higher rolloff
        assert!(
            high_features.rolloff > low_features.rolloff,
            "Expected high freq rolloff > low freq rolloff"
        );
    }

    #[test]
    fn test_decay_time_calculation() {
        let sample_rate = 48000;
        let extractor = FeatureExtractor::new(sample_rate);

        // Generate decaying signal with known decay time (50ms)
        let signal = generate_decaying_signal(sample_rate, FFT_SIZE, 50.0);
        let features = extractor.extract(&signal);

        println!("Measured decay time: {} ms", features.decay_time_ms);

        // Decay time should be roughly in expected range (with tolerance)
        assert!(
            features.decay_time_ms > 10.0 && features.decay_time_ms < 100.0,
            "Expected decay time 10-100ms, got {} ms",
            features.decay_time_ms
        );
    }

    #[test]
    fn test_features_in_valid_ranges() {
        let sample_rate = 48000;
        let extractor = FeatureExtractor::new(sample_rate);

        // Test with real-world-like signal (sine wave)
        let signal = generate_sine_wave(sample_rate, 1000.0, FFT_SIZE);
        let features = extractor.extract(&signal);

        // All features should be in valid ranges
        assert!(
            features.centroid >= 50.0 && features.centroid <= 20000.0,
            "Centroid {} Hz out of range [50, 20000]",
            features.centroid
        );
        assert!(
            features.zcr >= 0.0 && features.zcr <= 1.0,
            "ZCR {} out of range [0, 1]",
            features.zcr
        );
        assert!(
            features.flatness >= 0.0 && features.flatness <= 1.0,
            "Flatness {} out of range [0, 1]",
            features.flatness
        );
        assert!(
            features.rolloff >= 0.0 && features.rolloff <= sample_rate as f32 / 2.0,
            "Rolloff {} Hz out of range [0, {}]",
            features.rolloff,
            sample_rate / 2
        );
        assert!(
            features.decay_time_ms >= 0.0,
            "Decay time {} ms should be non-negative",
            features.decay_time_ms
        );

        println!("Features: {:?}", features);
    }

    #[test]
    fn test_extract_with_short_audio() {
        let sample_rate = 48000;
        let extractor = FeatureExtractor::new(sample_rate);

        // Test with audio shorter than FFT size (should pad with zeros)
        let short_signal = generate_sine_wave(sample_rate, 1000.0, 512);
        let features = extractor.extract(&short_signal);

        // Should still compute features without crashing
        assert!(features.centroid > 0.0);
        assert!(features.zcr >= 0.0);
        assert!(features.flatness >= 0.0);
        println!("Short audio features: {:?}", features);
    }

    #[test]
    fn test_extract_with_silence() {
        let sample_rate = 48000;
        let extractor = FeatureExtractor::new(sample_rate);

        // Test with silence
        let silence = vec![0.0; FFT_SIZE];
        let features = extractor.extract(&silence);

        // Silence should have zero or near-zero features
        assert_eq!(features.centroid, 0.0, "Centroid should be 0 for silence");
        assert_eq!(features.zcr, 0.0, "ZCR should be 0 for silence");
        println!("Silence features: {:?}", features);
    }
}
