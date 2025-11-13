// FeatureExtractor - DSP feature extraction for beatbox sound classification
//
// This module extracts audio features used for distinguishing between different
// beatbox sounds (kick, snare, hi-hat). Features are computed from time-domain
// and frequency-domain representations of audio signals.
//
// Module organization:
// - types: Data structures (Features struct)
// - fft: FFT computation with windowing
// - spectral: Frequency-domain features (centroid, flatness, rolloff)
// - temporal: Time-domain features (ZCR, decay time)
// - mod.rs: Coordinator (FeatureExtractor)
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

mod fft;
mod spectral;
mod temporal;
mod types;

pub use types::Features;

use fft::{FftProcessor, FFT_SIZE};
use spectral::SpectralFeatures;
use temporal::TemporalFeatures;

/// FeatureExtractor coordinates DSP feature extraction pipeline
///
/// This struct combines FFT processing, spectral feature extraction,
/// and temporal feature extraction into a single unified interface.
pub struct FeatureExtractor {
    fft_processor: FftProcessor,
    spectral_features: SpectralFeatures,
    temporal_features: TemporalFeatures,
    fft_size: usize,
}

impl FeatureExtractor {
    /// Create a new FeatureExtractor with the specified sample rate
    ///
    /// # Arguments
    /// * `sample_rate` - Audio sample rate in Hz (e.g., 48000)
    pub fn new(sample_rate: u32) -> Self {
        let fft_size = FFT_SIZE;

        Self {
            fft_processor: FftProcessor::new(fft_size),
            spectral_features: SpectralFeatures::new(sample_rate, fft_size),
            temporal_features: TemporalFeatures::new(sample_rate),
            fft_size,
        }
    }

    /// Extract all features from an audio window
    ///
    /// This method coordinates the entire feature extraction pipeline:
    /// 1. Compute magnitude spectrum via FFT
    /// 2. Extract spectral features from spectrum
    /// 3. Extract temporal features from time-domain signal
    /// 4. Combine into Features struct
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
        let spectrum = self.fft_processor.compute_magnitude_spectrum(audio_window);

        // Extract frequency-domain features
        let centroid = self.spectral_features.compute_centroid(&spectrum);
        let flatness = self.spectral_features.compute_flatness(&spectrum);
        let rolloff = self.spectral_features.compute_rolloff(&spectrum);

        // Extract time-domain features
        let zcr = self.temporal_features.compute_zcr(audio_window);
        let decay_time_ms = self.temporal_features.compute_decay_time(audio_window);

        Features {
            centroid,
            zcr,
            flatness,
            rolloff,
            decay_time_ms,
        }
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
    fn generate_decaying_signal(
        sample_rate: u32,
        duration_samples: usize,
        decay_time_ms: f32,
    ) -> Vec<f32> {
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
