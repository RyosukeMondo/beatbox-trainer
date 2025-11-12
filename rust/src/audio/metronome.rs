//! Metronome - Sample-accurate click generation
//!
//! This module provides deterministic metronome click generation for rhythm training.
//! Key features:
//! - Sample-accurate timing (0 jitter) using frame counter arithmetic
//! - 20ms white noise burst click samples
//! - Pure functions (no side effects, deterministic output)
//! - Zero allocations in timing check functions

use rand::{Rng, SeedableRng};
use rand::rngs::StdRng;

/// Duration of metronome click in milliseconds
const CLICK_DURATION_MS: f32 = 20.0;

/// Generates a metronome click sample (20ms white noise burst).
///
/// This function creates a deterministic white noise burst for use as a metronome click.
/// The noise is generated using a fixed seed to ensure identical output across calls.
///
/// # Arguments
/// * `sample_rate` - Sample rate in Hz (typically 48000)
///
/// # Returns
/// A `Vec<f32>` containing exactly 20ms worth of white noise samples in range [-1.0, 1.0]
///
/// # Examples
/// ```
/// let sample_rate = 48000;
/// let click = generate_click_sample(sample_rate);
/// assert_eq!(click.len(), (sample_rate as f32 * 0.02) as usize);
/// ```
pub fn generate_click_sample(sample_rate: u32) -> Vec<f32> {
    // Calculate exact number of samples for 20ms
    let num_samples = (sample_rate as f32 * CLICK_DURATION_MS / 1000.0) as usize;

    // Use fixed seed for deterministic noise generation
    let mut rng = StdRng::seed_from_u64(42);

    // Generate white noise in range [-1.0, 1.0]
    let mut samples = Vec::with_capacity(num_samples);
    for _ in 0..num_samples {
        samples.push(rng.gen_range(-1.0..1.0));
    }

    samples
}

/// Converts BPM (beats per minute) to samples per beat.
///
/// This function computes the exact number of audio samples between consecutive beats
/// at a given tempo. Formula: samples_per_beat = (sample_rate × 60) / BPM
///
/// # Arguments
/// * `bpm` - Beats per minute (typically 40-240)
/// * `sample_rate` - Sample rate in Hz (typically 48000)
///
/// # Returns
/// Number of samples between beats
///
/// # Examples
/// ```
/// let samples = samples_per_beat(120, 48000);
/// assert_eq!(samples, 24000); // At 120 BPM: 48000 * 60 / 120 = 24000 samples per beat
/// ```
#[inline]
pub fn samples_per_beat(bpm: u32, sample_rate: u32) -> u64 {
    (sample_rate as u64 * 60) / bpm as u64
}

/// Checks if the current frame is exactly on a beat boundary.
///
/// Uses modulo arithmetic to determine if frame_counter aligns with beat timing.
/// This function has zero allocations and is safe for real-time use.
///
/// # Arguments
/// * `frame_counter` - Total frames processed since audio engine start
/// * `bpm` - Current beats per minute
/// * `sample_rate` - Sample rate in Hz
///
/// # Returns
/// `true` if current frame is exactly on a beat (error = 0 samples), `false` otherwise
///
/// # Examples
/// ```
/// // At 120 BPM, 48kHz: beat every 24000 samples
/// assert!(is_on_beat(0, 120, 48000));      // First beat
/// assert!(is_on_beat(24000, 120, 48000));  // Second beat
/// assert!(is_on_beat(48000, 120, 48000));  // Third beat
/// assert!(!is_on_beat(12000, 120, 48000)); // Not on beat
/// ```
#[inline]
pub fn is_on_beat(frame_counter: u64, bpm: u32, sample_rate: u32) -> bool {
    let spb = samples_per_beat(bpm, sample_rate);
    frame_counter.is_multiple_of(spb)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_click_sample_duration() {
        // Test at common sample rates
        let sample_rates = [44100, 48000, 96000];

        for &sr in &sample_rates {
            let click = generate_click_sample(sr);
            let expected_samples = (sr as f32 * CLICK_DURATION_MS / 1000.0) as usize;
            assert_eq!(
                click.len(),
                expected_samples,
                "Click duration should be exactly 20ms at {} Hz",
                sr
            );
        }
    }

    #[test]
    fn test_generate_click_sample_range() {
        let click = generate_click_sample(48000);

        // Verify all samples are in valid range [-1.0, 1.0]
        for (i, &sample) in click.iter().enumerate() {
            assert!(
                (-1.0..=1.0).contains(&sample),
                "Sample {} at index {} is out of range [-1.0, 1.0]",
                sample,
                i
            );
        }
    }

    #[test]
    fn test_generate_click_sample_deterministic() {
        // Same input should produce identical output (fixed seed)
        let click1 = generate_click_sample(48000);
        let click2 = generate_click_sample(48000);

        assert_eq!(
            click1.len(),
            click2.len(),
            "Deterministic generation should produce same length"
        );

        for (i, (&s1, &s2)) in click1.iter().zip(click2.iter()).enumerate() {
            assert_eq!(
                s1, s2,
                "Sample {} differs: {} vs {}. Generation should be deterministic.",
                i, s1, s2
            );
        }
    }

    #[test]
    fn test_samples_per_beat_formula() {
        // Verify formula: samples_per_beat = (sample_rate × 60) / BPM

        // At 120 BPM, 48kHz: (48000 * 60) / 120 = 24000
        assert_eq!(samples_per_beat(120, 48000), 24000);

        // At 60 BPM, 48kHz: (48000 * 60) / 60 = 48000
        assert_eq!(samples_per_beat(60, 48000), 48000);

        // At 240 BPM, 48kHz: (48000 * 60) / 240 = 12000
        assert_eq!(samples_per_beat(240, 48000), 12000);

        // At 100 BPM, 44.1kHz: (44100 * 60) / 100 = 26460
        assert_eq!(samples_per_beat(100, 44100), 26460);
    }

    #[test]
    fn test_is_on_beat_exact_boundaries() {
        let bpm = 120;
        let sample_rate = 48000;
        let spb = samples_per_beat(bpm, sample_rate); // 24000

        // Test exact beat boundaries
        assert!(is_on_beat(0, bpm, sample_rate), "Frame 0 should be on beat");
        assert!(is_on_beat(spb, bpm, sample_rate), "Frame {} should be on beat", spb);
        assert!(is_on_beat(spb * 2, bpm, sample_rate), "Frame {} should be on beat", spb * 2);
        assert!(is_on_beat(spb * 10, bpm, sample_rate), "Frame {} should be on beat", spb * 10);
    }

    #[test]
    fn test_is_on_beat_off_boundaries() {
        let bpm = 120;
        let sample_rate = 48000;
        let spb = samples_per_beat(bpm, sample_rate); // 24000

        // Test frames that are NOT on beat boundaries
        assert!(!is_on_beat(1, bpm, sample_rate), "Frame 1 should NOT be on beat");
        assert!(!is_on_beat(spb - 1, bpm, sample_rate), "Frame {} should NOT be on beat", spb - 1);
        assert!(!is_on_beat(spb + 1, bpm, sample_rate), "Frame {} should NOT be on beat", spb + 1);
        assert!(!is_on_beat(spb / 2, bpm, sample_rate), "Frame {} should NOT be on beat", spb / 2);
    }

    #[test]
    fn test_is_on_beat_different_bpms() {
        let sample_rate = 48000;

        // Test various BPM values
        let test_cases = vec![
            (60, vec![0, 48000, 96000]),         // 60 BPM: beat every 48000 samples
            (80, vec![0, 36000, 72000]),         // 80 BPM: beat every 36000 samples
            (140, vec![0, 20571, 41142]),        // 140 BPM: beat every ~20571 samples
        ];

        for (bpm, beat_frames) in test_cases {
            for &frame in &beat_frames {
                assert!(
                    is_on_beat(frame, bpm, sample_rate),
                    "Frame {} should be on beat at {} BPM",
                    frame,
                    bpm
                );
            }
        }
    }

    #[test]
    fn test_is_on_beat_zero_sample_error() {
        // Verify that is_on_beat has exactly 0 sample error (sample-accurate)
        let bpm = 120;
        let sample_rate = 48000;
        let spb = samples_per_beat(bpm, sample_rate);

        // Check that only exact boundaries return true
        for offset in 1..100 {
            assert!(
                !is_on_beat(spb + offset, bpm, sample_rate),
                "Frame {} is not exactly on beat",
                spb + offset
            );
            assert!(
                !is_on_beat(spb - offset, bpm, sample_rate),
                "Frame {} is not exactly on beat",
                spb - offset
            );
        }
    }
}
