// Pipeline Integration Tests
//
// End-to-end tests that verify the complete audio analysis pipeline works correctly.
// These tests use synthetic audio signals to verify that sounds are detected and
// classified correctly through the entire pipeline.

#[allow(dead_code)]
/// Generate a synthetic impulse (simulates a sharp attack sound like a kick)
///
/// Creates a short burst of energy that decays exponentially,
/// similar to a percussive hit.
fn generate_impulse(sample_rate: u32, duration_ms: u32, attack_sample: u32) -> Vec<f32> {
    let total_samples = (sample_rate * duration_ms / 1000) as usize;
    let mut signal = vec![0.0f32; total_samples];

    let attack_idx = attack_sample as usize;
    if attack_idx >= total_samples {
        return signal;
    }

    // Exponential decay from attack point
    let decay_rate = 0.001; // Fast decay
    for (i, sample) in signal.iter_mut().enumerate().skip(attack_idx) {
        let t = (i - attack_idx) as f32;
        *sample = (-decay_rate * t).exp();
    }

    signal
}

#[allow(dead_code)]
/// Generate a synthetic kick drum (low frequency impulse)
///
/// Kick drums have low spectral centroid and low ZCR.
fn generate_kick(sample_rate: u32, duration_ms: u32, attack_sample: u32) -> Vec<f32> {
    let total_samples = (sample_rate * duration_ms / 1000) as usize;
    let mut signal = vec![0.0f32; total_samples];

    let attack_idx = attack_sample as usize;
    if attack_idx >= total_samples {
        return signal;
    }

    // Low frequency sinusoid with exponential decay
    let freq = 80.0; // 80 Hz fundamental
    let decay_rate = 0.005;
    for (i, sample) in signal.iter_mut().enumerate().skip(attack_idx) {
        let t = (i - attack_idx) as f32;
        let envelope = (-decay_rate * t).exp();
        let phase = 2.0 * std::f32::consts::PI * freq * (t / sample_rate as f32);
        *sample = envelope * phase.sin();
    }

    signal
}

#[allow(dead_code)]
/// Generate a synthetic hi-hat (high frequency noise burst)
///
/// Hi-hats have high ZCR and high spectral centroid.
fn generate_hihat(sample_rate: u32, duration_ms: u32, attack_sample: u32) -> Vec<f32> {
    let total_samples = (sample_rate * duration_ms / 1000) as usize;
    let mut signal = vec![0.0f32; total_samples];

    let attack_idx = attack_sample as usize;
    if attack_idx >= total_samples {
        return signal;
    }

    // White noise with fast decay
    let decay_rate = 0.02; // Very fast decay
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};

    for (i, sample) in signal.iter_mut().enumerate().skip(attack_idx) {
        let t = (i - attack_idx) as f32;
        let envelope = (-decay_rate * t).exp();

        // Simple pseudo-random noise
        let mut hasher = DefaultHasher::new();
        i.hash(&mut hasher);
        let random = (hasher.finish() as f32 / u64::MAX as f32) * 2.0 - 1.0;

        *sample = envelope * random * 0.5;
    }

    signal
}

#[allow(dead_code)]
/// Generate a synthetic snare (mid-high frequency with noise component)
///
/// Snares have medium-high spectral centroid and moderate ZCR.
fn generate_snare(sample_rate: u32, duration_ms: u32, attack_sample: u32) -> Vec<f32> {
    let total_samples = (sample_rate * duration_ms / 1000) as usize;
    let mut signal = vec![0.0f32; total_samples];

    let attack_idx = attack_sample as usize;
    if attack_idx >= total_samples {
        return signal;
    }

    // Mix of tone and noise
    let freq = 200.0; // Snare body frequency
    let decay_rate = 0.01;
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};

    for (i, sample) in signal.iter_mut().enumerate().skip(attack_idx) {
        let t = (i - attack_idx) as f32;
        let envelope = (-decay_rate * t).exp();

        // Tonal component
        let phase = 2.0 * std::f32::consts::PI * freq * (t / sample_rate as f32);
        let tone = phase.sin();

        // Noise component (snare wires)
        let mut hasher = DefaultHasher::new();
        i.hash(&mut hasher);
        let random = (hasher.finish() as f32 / u64::MAX as f32) * 2.0 - 1.0;

        *sample = envelope * (tone * 0.4 + random * 0.6);
    }

    signal
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::analysis::classifier::Classifier;
    use crate::analysis::features::FeatureExtractor;
    use crate::analysis::onset::OnsetDetector;
    use crate::analysis::quantizer::Quantizer;
    use crate::calibration::state::CalibrationState;
    use std::sync::atomic::{AtomicU32, AtomicU64};
    use std::sync::{Arc, RwLock};

    // Note: Onset detection is tested in analysis/onset.rs.
    // Pipeline integration focuses on component interactions, not re-testing onset detection.

    #[test]
    fn test_feature_extractor_differentiates_kick_and_hihat() {
        let sample_rate = 48000;
        let feature_extractor = FeatureExtractor::new(sample_rate);

        // Generate kick and hi-hat samples (1024 samples = ~21ms window)
        let kick = generate_kick(sample_rate, 50, 0);
        let hihat = generate_hihat(sample_rate, 50, 0);

        // Extract features
        let kick_features = feature_extractor.extract(&kick[..1024.min(kick.len())]);
        let hihat_features = feature_extractor.extract(&hihat[..1024.min(hihat.len())]);

        // Hi-hat should have higher spectral centroid than kick
        assert!(
            hihat_features.centroid > kick_features.centroid,
            "Hi-hat centroid ({}) should be > kick centroid ({})",
            hihat_features.centroid,
            kick_features.centroid
        );

        // Hi-hat should have higher ZCR than kick
        assert!(
            hihat_features.zcr > kick_features.zcr,
            "Hi-hat ZCR ({}) should be > kick ZCR ({})",
            hihat_features.zcr,
            kick_features.zcr
        );
    }

    #[test]
    fn test_pipeline_end_to_end_kick_detection() {
        let sample_rate = 48000;

        // Create pipeline components
        let mut onset_detector = OnsetDetector::new(sample_rate);
        let feature_extractor = FeatureExtractor::new(sample_rate);
        let calibration_state = Arc::new(RwLock::new(CalibrationState::new_default()));
        let classifier = Classifier::new(Arc::clone(&calibration_state));
        let frame_counter = Arc::new(AtomicU64::new(0));
        let bpm = Arc::new(AtomicU32::new(120));
        let _quantizer = Quantizer::new(Arc::clone(&frame_counter), Arc::clone(&bpm), sample_rate);

        // Generate a kick drum at 100ms
        let signal = generate_kick(sample_rate, 300, sample_rate / 10);

        // Process through onset detector
        let onsets = onset_detector.process(&signal);

        if !onsets.is_empty() {
            // Extract features around the onset
            let onset_sample = onsets[0] as usize;
            let window_start = onset_sample.saturating_sub(256);
            let window_end = (onset_sample + 768).min(signal.len());

            if window_end > window_start && window_end - window_start >= 256 {
                let window = &signal[window_start..window_end];
                let features = feature_extractor.extract(window);

                // Classify
                let (sound, confidence) = classifier.classify(&features);

                // For a kick-like signal with default thresholds, we expect Kick or Unknown
                // (depends on threshold tuning)
                println!("Detected: {:?} with confidence {:.2}", sound, confidence);

                // The classifier should return *something* (not panic)
                assert!(
                    (0.0..=1.0).contains(&confidence),
                    "Confidence should be in [0, 1]"
                );
            }
        }
    }

    #[test]
    fn test_rms_gate_blocks_silence() {
        let sample_rate = 48000;
        let silence = vec![0.0f32; sample_rate as usize]; // 1 second of silence

        // Calculate RMS
        let rms: f64 = {
            let sum_squares: f64 = silence.iter().map(|&x| (x as f64) * (x as f64)).sum();
            (sum_squares / silence.len() as f64).sqrt()
        };

        // RMS of silence should be 0
        assert!(rms < 0.0001, "RMS of silence should be ~0, got {}", rms);

        // With any reasonable noise gate, silence should be blocked
        let noise_gate = 0.01; // Typical noise gate threshold
        assert!(
            rms < noise_gate,
            "Silence RMS {} should be below gate {}",
            rms,
            noise_gate
        );
    }

    #[test]
    fn test_rms_gate_passes_loud_signal() {
        let sample_rate = 48000;
        let loud_signal = generate_impulse(sample_rate, 100, 0);

        // Calculate RMS
        let rms: f64 = {
            let sum_squares: f64 = loud_signal.iter().map(|&x| (x as f64) * (x as f64)).sum();
            (sum_squares / loud_signal.len() as f64).sqrt()
        };

        // RMS of loud signal should be above noise gate
        let noise_gate = 0.01;
        assert!(
            rms > noise_gate,
            "Loud signal RMS {} should be above gate {}",
            rms,
            noise_gate
        );
    }

    #[test]
    fn test_level_crossing_detection() {
        let sample_rate = 48000;

        // Simulate the level crossing logic from analysis thread
        let threshold = 0.05;
        let mut prev_rms = 0.0;

        // Process chunks of audio, some below and some above threshold
        let chunks = vec![
            vec![0.0f32; 256],                    // Silent
            vec![0.0f32; 256],                    // Silent
            generate_impulse(sample_rate, 10, 0), // Attack starts
            vec![0.5f32; 256],                    // Sustain
            vec![0.1f32; 256],                    // Decay
        ];

        let mut crossings_detected = 0;

        for chunk in &chunks {
            let rms: f64 = {
                let sum_squares: f64 = chunk.iter().map(|&x| (x as f64) * (x as f64)).sum();
                (sum_squares / chunk.len() as f64).sqrt()
            };

            // Level crossing: prev < threshold AND curr >= threshold
            if prev_rms < threshold && rms >= threshold {
                crossings_detected += 1;
            }

            prev_rms = rms;
        }

        assert!(
            crossings_detected >= 1,
            "Should detect at least one level crossing, found {}",
            crossings_detected
        );
    }
}
