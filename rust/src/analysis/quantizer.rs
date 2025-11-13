//! Quantizer - Timing analysis and feedback
//!
//! This module provides rhythm timing quantization against a metronome grid.
//! Key features:
//! - Sample-accurate timing error calculation
//! - ON_TIME/EARLY/LATE classification with 50ms tolerance
//! - Thread-safe access to shared audio engine timing state
//! - Zero allocations in quantization calculations
//!
//! The quantizer uses atomic references to frame_counter and BPM from AudioEngine
//! to compute timing error between detected onsets and the metronome beat grid.

use std::sync::atomic::{AtomicU32, AtomicU64, Ordering};
use std::sync::Arc;

use crate::audio::metronome::samples_per_beat;

/// Timing classification for onset accuracy relative to metronome grid
///
/// Determines whether a detected onset is on-time, early, or late relative
/// to the nearest beat boundary.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum TimingClassification {
    /// Onset is within 50ms of a beat boundary
    OnTime,
    /// Onset is too early (more than 50ms before nearest beat, but closer to previous beat)
    Early,
    /// Onset is too late (more than 50ms after beat boundary)
    Late,
}

/// Timing feedback with classification and millisecond error
///
/// Provides detailed timing feedback for display to the user, including
/// the classification (ON_TIME/EARLY/LATE) and the signed error in milliseconds.
#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct TimingFeedback {
    /// Classification of timing accuracy
    pub classification: TimingClassification,
    /// Timing error in milliseconds
    /// - Positive values indicate late (after beat)
    /// - Negative values indicate early (before beat)
    /// - Zero indicates exactly on beat
    pub error_ms: f32,
}

/// Quantizer for rhythm timing analysis
///
/// The Quantizer computes timing errors between detected onsets and the metronome
/// beat grid. It uses shared atomic references to the audio engine's frame counter
/// and BPM to perform sample-accurate timing calculations.
///
/// # Thread Safety
/// - Safe to use from any thread (analysis thread typically)
/// - Uses atomic operations for lock-free access to shared state
/// - No allocations in quantize() method
///
/// # Example
/// ```ignore
/// let quantizer = Quantizer::new(frame_counter_ref, bpm_ref, 48000);
/// let feedback = quantizer.quantize(onset_timestamp);
/// if feedback.classification == TimingClassification::OnTime {
///     println!("Perfect timing!");
/// } else {
///     println!("Off by {} ms", feedback.error_ms);
/// }
/// ```
pub struct Quantizer {
    /// Shared reference to audio engine frame counter (total samples processed)
    frame_counter: Arc<AtomicU64>,
    /// Shared reference to current BPM setting
    bpm: Arc<AtomicU32>,
    /// Sample rate in Hz (used for time conversions)
    sample_rate: u32,
}

impl Quantizer {
    /// Tolerance for ON_TIME classification in milliseconds
    /// Onsets within ±50ms of a beat are considered "on time"
    const TOLERANCE_MS: f32 = 50.0;

    /// Create a new Quantizer with shared references to audio engine timing state
    ///
    /// # Arguments
    /// * `frame_counter` - Arc reference to AudioEngine frame counter
    /// * `bpm` - Arc reference to current BPM setting
    /// * `sample_rate` - Sample rate in Hz (typically 48000)
    ///
    /// # Returns
    /// A new Quantizer instance ready for timing analysis
    pub fn new(frame_counter: Arc<AtomicU64>, bpm: Arc<AtomicU32>, sample_rate: u32) -> Self {
        Self {
            frame_counter,
            bpm,
            sample_rate,
        }
    }

    /// Quantize an onset timestamp to the metronome grid and compute timing feedback
    ///
    /// This method calculates the timing error between a detected onset and the nearest
    /// beat boundary, then classifies the timing as ON_TIME, EARLY, or LATE.
    ///
    /// # Algorithm
    /// 1. Load current BPM from atomic reference
    /// 2. Calculate samples_per_beat from BPM and sample rate
    /// 3. Compute beat_error = onset_timestamp % samples_per_beat
    /// 4. Convert beat_error to milliseconds
    /// 5. Classify timing based on error magnitude and position
    ///
    /// # Arguments
    /// * `onset_timestamp` - Sample index of detected onset (from OnsetDetector)
    ///
    /// # Returns
    /// TimingFeedback with classification and signed error in milliseconds
    ///
    /// # Examples
    /// ```ignore
    /// // Onset exactly on beat
    /// let feedback = quantizer.quantize(24000); // At 120 BPM, 48kHz: beat boundary
    /// assert_eq!(feedback.classification, TimingClassification::OnTime);
    /// assert_eq!(feedback.error_ms, 0.0);
    ///
    /// // Onset 100ms after beat (late)
    /// let feedback = quantizer.quantize(24000 + 4800); // +100ms
    /// assert_eq!(feedback.classification, TimingClassification::Late);
    /// assert_eq!(feedback.error_ms, 100.0);
    ///
    /// // Onset 30ms before next beat (early)
    /// let feedback = quantizer.quantize(24000 - 1440); // -30ms from next beat
    /// assert_eq!(feedback.classification, TimingClassification::Early);
    /// ```
    pub fn quantize(&self, onset_timestamp: u64) -> TimingFeedback {
        // Load current BPM (atomic read, lock-free)
        let current_bpm = self.bpm.load(Ordering::Relaxed);

        // Calculate samples per beat for current tempo
        let spb = samples_per_beat(current_bpm, self.sample_rate);

        // Compute timing error: distance from nearest beat boundary
        // beat_error = onset_timestamp % samples_per_beat
        let beat_error = onset_timestamp % spb;

        // Convert samples to milliseconds
        // error_ms = (beat_error / sample_rate) × 1000
        let error_ms = (beat_error as f32 / self.sample_rate as f32) * 1000.0;

        // Calculate beat period in milliseconds for comparison
        let beat_period_ms = (spb as f32 / self.sample_rate as f32) * 1000.0;

        // Classify timing based on error magnitude and position within beat
        let classification = if error_ms < Self::TOLERANCE_MS {
            // Within 50ms after beat boundary → ON_TIME
            TimingClassification::OnTime
        } else if error_ms > (beat_period_ms - Self::TOLERANCE_MS) {
            // Within 50ms before next beat → EARLY (treat as early relative to next beat)
            // This onset is closer to the next beat than the previous beat
            TimingClassification::Early
        } else {
            // More than 50ms after beat, but not close to next beat → LATE
            TimingClassification::Late
        };

        // Adjust error_ms sign for early classification
        // For early onsets, report negative error (distance to next beat)
        let signed_error_ms = if classification == TimingClassification::Early {
            // Onset is closer to next beat, so error is negative
            error_ms - beat_period_ms
        } else {
            // Onset is after beat, error is positive
            error_ms
        };

        TimingFeedback {
            classification,
            error_ms: signed_error_ms,
        }
    }

    /// Get current frame counter value (for debugging/testing)
    ///
    /// # Returns
    /// Current frame counter value from audio engine
    #[allow(dead_code)]
    pub fn get_frame_counter(&self) -> u64 {
        self.frame_counter.load(Ordering::Relaxed)
    }

    /// Get current BPM value (for debugging/testing)
    ///
    /// # Returns
    /// Current BPM from audio engine
    #[allow(dead_code)]
    pub fn get_bpm(&self) -> u32 {
        self.bpm.load(Ordering::Relaxed)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Helper to create a test Quantizer with specified BPM
    fn create_test_quantizer(bpm: u32, sample_rate: u32) -> Quantizer {
        let frame_counter = Arc::new(AtomicU64::new(0));
        let bpm_atomic = Arc::new(AtomicU32::new(bpm));
        Quantizer::new(frame_counter, bpm_atomic, sample_rate)
    }

    #[test]
    fn test_quantizer_creation() {
        let quantizer = create_test_quantizer(120, 48000);
        assert_eq!(quantizer.get_bpm(), 120);
        assert_eq!(quantizer.sample_rate, 48000);
    }

    #[test]
    fn test_onset_exactly_on_beat() {
        let quantizer = create_test_quantizer(120, 48000);
        // At 120 BPM, 48kHz: samples_per_beat = 24000
        // Test onsets exactly on beat boundaries

        let feedback = quantizer.quantize(0);
        assert_eq!(feedback.classification, TimingClassification::OnTime);
        assert_eq!(feedback.error_ms, 0.0);

        let feedback = quantizer.quantize(24000);
        assert_eq!(feedback.classification, TimingClassification::OnTime);
        assert_eq!(feedback.error_ms, 0.0);

        let feedback = quantizer.quantize(48000);
        assert_eq!(feedback.classification, TimingClassification::OnTime);
        assert_eq!(feedback.error_ms, 0.0);
    }

    #[test]
    fn test_onset_within_tolerance_after_beat() {
        let quantizer = create_test_quantizer(120, 48000);
        // 50ms tolerance = 2400 samples at 48kHz

        // 10ms after beat (480 samples) → ON_TIME
        let feedback = quantizer.quantize(24000 + 480);
        assert_eq!(feedback.classification, TimingClassification::OnTime);
        assert!((feedback.error_ms - 10.0).abs() < 0.1);

        // 30ms after beat (1440 samples) → ON_TIME
        let feedback = quantizer.quantize(24000 + 1440);
        assert_eq!(feedback.classification, TimingClassification::OnTime);
        assert!((feedback.error_ms - 30.0).abs() < 0.1);

        // 49ms after beat (2352 samples) → ON_TIME
        let feedback = quantizer.quantize(24000 + 2352);
        assert_eq!(feedback.classification, TimingClassification::OnTime);
        assert!((feedback.error_ms - 49.0).abs() < 0.5);
    }

    #[test]
    fn test_onset_late() {
        let quantizer = create_test_quantizer(120, 48000);

        // 100ms after beat (4800 samples) → LATE
        let feedback = quantizer.quantize(24000 + 4800);
        assert_eq!(feedback.classification, TimingClassification::Late);
        assert!((feedback.error_ms - 100.0).abs() < 0.1);

        // 150ms after beat (7200 samples) → LATE
        let feedback = quantizer.quantize(24000 + 7200);
        assert_eq!(feedback.classification, TimingClassification::Late);
        assert!((feedback.error_ms - 150.0).abs() < 0.1);

        // 200ms after beat (9600 samples) → LATE
        let feedback = quantizer.quantize(24000 + 9600);
        assert_eq!(feedback.classification, TimingClassification::Late);
        assert!((feedback.error_ms - 200.0).abs() < 0.1);
    }

    #[test]
    fn test_onset_early() {
        let quantizer = create_test_quantizer(120, 48000);
        // At 120 BPM: beat_period = 500ms, samples_per_beat = 24000
        // Early classification: within 50ms before next beat

        // 30ms before next beat (24000 - 1440 samples from beat 0) → EARLY
        // This is 22560 samples from beat 0, which is 470ms into the beat
        let feedback = quantizer.quantize(22560);
        assert_eq!(feedback.classification, TimingClassification::Early);
        assert!((feedback.error_ms + 30.0).abs() < 0.1); // Negative error for early

        // 20ms before next beat → EARLY
        let feedback = quantizer.quantize(23040); // 24000 - 960
        assert_eq!(feedback.classification, TimingClassification::Early);
        assert!((feedback.error_ms + 20.0).abs() < 0.1);

        // 10ms before next beat → EARLY
        let feedback = quantizer.quantize(23520); // 24000 - 480
        assert_eq!(feedback.classification, TimingClassification::Early);
        assert!((feedback.error_ms + 10.0).abs() < 0.1);
    }

    #[test]
    fn test_tolerance_boundary_conditions() {
        let quantizer = create_test_quantizer(120, 48000);
        // Test exact tolerance boundaries (50ms = 2400 samples)

        // Exactly 50ms after beat → ON_TIME (at boundary)
        let feedback = quantizer.quantize(24000 + 2400);
        assert!(
            feedback.classification == TimingClassification::OnTime
                || feedback.classification == TimingClassification::Late
        );

        // 51ms after beat → LATE (just outside tolerance)
        let feedback = quantizer.quantize(24000 + 2448);
        assert_eq!(feedback.classification, TimingClassification::Late);

        // Exactly 50ms before next beat (450ms after beat) → EARLY (at boundary)
        let feedback = quantizer.quantize(24000 + 21600); // 450ms = 21600 samples
        assert!(
            feedback.classification == TimingClassification::Early
                || feedback.classification == TimingClassification::Late
        );
    }

    #[test]
    fn test_different_bpm_values() {
        // Test quantization at various tempos

        // 60 BPM: beat_period = 1000ms, samples_per_beat = 48000
        let quantizer = create_test_quantizer(60, 48000);
        let feedback = quantizer.quantize(48000 + 9600); // +200ms
        assert_eq!(feedback.classification, TimingClassification::Late);
        assert!((feedback.error_ms - 200.0).abs() < 0.1);

        // 240 BPM: beat_period = 250ms, samples_per_beat = 12000
        let quantizer = create_test_quantizer(240, 48000);
        let feedback = quantizer.quantize(12000 + 1920); // +40ms (within tolerance)
        assert_eq!(feedback.classification, TimingClassification::OnTime);

        // 100 BPM: beat_period = 600ms, samples_per_beat = 28800
        let quantizer = create_test_quantizer(100, 48000);
        let feedback = quantizer.quantize(28800); // Exactly on second beat
        assert_eq!(feedback.classification, TimingClassification::OnTime);
        assert_eq!(feedback.error_ms, 0.0);
    }

    #[test]
    fn test_error_ms_sign_convention() {
        let quantizer = create_test_quantizer(120, 48000);

        // Late onsets should have positive error_ms
        let feedback = quantizer.quantize(24000 + 4800); // +100ms
        assert_eq!(feedback.classification, TimingClassification::Late);
        assert!(feedback.error_ms > 0.0);

        // Early onsets should have negative error_ms
        let feedback = quantizer.quantize(22560); // -30ms from next beat
        assert_eq!(feedback.classification, TimingClassification::Early);
        assert!(feedback.error_ms < 0.0);

        // On-time onsets should have ~0 error_ms
        let feedback = quantizer.quantize(24000);
        assert_eq!(feedback.classification, TimingClassification::OnTime);
        assert_eq!(feedback.error_ms, 0.0);
    }

    #[test]
    fn test_multiple_beats() {
        let quantizer = create_test_quantizer(120, 48000);
        // Verify quantization works correctly for onsets at different beat positions

        // Test beats at 0, 1, 2, 3, 5, 10 seconds
        let beat_positions = vec![0, 24000, 48000, 72000, 120000, 240000];

        for &beat in &beat_positions {
            let feedback = quantizer.quantize(beat);
            assert_eq!(
                feedback.classification,
                TimingClassification::OnTime,
                "Beat at sample {} should be on time",
                beat
            );
            assert_eq!(feedback.error_ms, 0.0);
        }
    }

    #[test]
    fn test_dynamic_bpm_update() {
        // Test that quantizer respects BPM changes via atomic reference
        let frame_counter = Arc::new(AtomicU64::new(0));
        let bpm_atomic = Arc::new(AtomicU32::new(120));
        let quantizer = Quantizer::new(Arc::clone(&frame_counter), Arc::clone(&bpm_atomic), 48000);

        // At 120 BPM: samples_per_beat = 24000
        let feedback = quantizer.quantize(24000);
        assert_eq!(feedback.classification, TimingClassification::OnTime);

        // Change BPM to 60 (samples_per_beat = 48000)
        bpm_atomic.store(60, Ordering::Relaxed);

        // Now 24000 should be off-beat for 60 BPM (halfway through beat)
        let feedback = quantizer.quantize(24000);
        assert_eq!(feedback.classification, TimingClassification::Late);

        // But 48000 should be on-beat for 60 BPM
        let feedback = quantizer.quantize(48000);
        assert_eq!(feedback.classification, TimingClassification::OnTime);
    }

    #[test]
    fn test_sample_rate_44100() {
        // Test quantization at 44.1kHz sample rate
        let quantizer = create_test_quantizer(120, 44100);
        // At 120 BPM, 44.1kHz: samples_per_beat = 22050

        let feedback = quantizer.quantize(0);
        assert_eq!(feedback.classification, TimingClassification::OnTime);

        let feedback = quantizer.quantize(22050);
        assert_eq!(feedback.classification, TimingClassification::OnTime);

        // 100ms late = 4410 samples
        let feedback = quantizer.quantize(22050 + 4410);
        assert_eq!(feedback.classification, TimingClassification::Late);
        assert!((feedback.error_ms - 100.0).abs() < 0.1);
    }

    #[test]
    fn test_timing_feedback_struct() {
        let feedback = TimingFeedback {
            classification: TimingClassification::Late,
            error_ms: 123.5,
        };

        assert_eq!(feedback.classification, TimingClassification::Late);
        assert!((feedback.error_ms - 123.5).abs() < 0.01);

        // Test clone and copy
        let feedback2 = feedback;
        assert_eq!(feedback.classification, feedback2.classification);
        assert_eq!(feedback.error_ms, feedback2.error_ms);
    }

    #[test]
    fn test_timing_classification_equality() {
        assert_eq!(TimingClassification::OnTime, TimingClassification::OnTime);
        assert_ne!(TimingClassification::OnTime, TimingClassification::Late);
        assert_ne!(TimingClassification::Early, TimingClassification::Late);
    }
}
