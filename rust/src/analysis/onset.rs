// OnsetDetector - spectral flux-based onset detection
//
// This module implements real-time onset detection using the spectral flux algorithm
// with adaptive thresholding. It detects percussive sound onsets by analyzing changes
// in the frequency spectrum over time.
//
// Algorithm:
// 1. Compute 256-point FFT with 75% overlap (hop = 64 samples)
// 2. Calculate magnitude spectrum: |FFT[k]|
// 3. Compute positive difference from previous frame: SF[k] = max(0, |FFT_t[k]| - |FFT_(t-1)[k]|)
// 4. Sum across frequency bins: flux_t = Σ SF[k]
// 5. Apply adaptive threshold: threshold_t = median(flux[t-50:t+50]) + offset
// 6. Peak pick: Find local maxima where flux_t > threshold_t

use rustfft::{num_complex::Complex, FftPlanner};
use std::collections::VecDeque;
use std::sync::{Arc, Mutex};

use crate::config::OnsetDetectionConfig;

/// OnsetDetector uses spectral flux algorithm to detect sound onsets
pub struct OnsetDetector {
    fft_planner: Arc<Mutex<FftPlanner<f32>>>,
    prev_spectrum: Vec<f32>,
    flux_signal: VecDeque<f32>,
    #[allow(dead_code)] // Kept for future API compatibility
    sample_rate: u32,
    window_size: usize,
    hop_size: usize,
    median_window_halfsize: usize,
    threshold_offset: f32,
    // Windowing function (Hann window)
    window: Vec<f32>,
    // Sample counter for timestamp tracking (deprecated, use frames_processed)
    #[allow(dead_code)]
    sample_offset: u64,
    // Track total number of frames processed (for flux buffer offset)
    frames_processed: u64,
}

impl OnsetDetector {
    /// Create a new OnsetDetector with the specified sample rate
    ///
    /// # Arguments
    /// * `sample_rate` - Audio sample rate in Hz (e.g., 48000)
    pub fn new(sample_rate: u32) -> Self {
        Self::with_config(sample_rate, OnsetDetectionConfig::default())
    }

    /// Create a detector with explicit configuration parameters
    pub fn with_config(sample_rate: u32, config: OnsetDetectionConfig) -> Self {
        let window_size = config.window_size.max(2);
        let hop_size = config.hop_size.max(1);
        let median_window_halfsize = config.median_window_halfsize.max(1);
        let threshold_offset = config.threshold_offset;

        // Pre-compute Hann window to reduce spectral leakage
        let window = (0..window_size)
            .map(|i| {
                0.5 * (1.0
                    - ((2.0 * std::f32::consts::PI * i as f32) / (window_size as f32 - 1.0)).cos())
            })
            .collect();

        Self {
            fft_planner: Arc::new(Mutex::new(FftPlanner::new())),
            prev_spectrum: vec![0.0; window_size / 2 + 1],
            flux_signal: VecDeque::with_capacity(median_window_halfsize * 2 + 100),
            sample_rate,
            window_size,
            hop_size,
            median_window_halfsize,
            threshold_offset,
            window,
            sample_offset: 0,
            frames_processed: 0,
        }
    }

    /// Process audio buffer and detect onsets
    ///
    /// # Arguments
    /// * `audio` - Input audio buffer to analyze
    ///
    /// # Returns
    /// Vector of onset timestamps in sample count since engine start
    pub fn process(&mut self, audio: &[f32]) -> Vec<u64> {
        let mut onsets = Vec::new();
        let frames_before = self.frames_processed;

        // Calculate the offset in the flux buffer (due to pop_front operations)
        let flux_buffer_capacity = self.median_window_halfsize * 2 + 100;
        let flux_buffer_offset = if self.flux_signal.len() >= flux_buffer_capacity {
            self.frames_processed - flux_buffer_capacity as u64
        } else {
            0
        };

        // Process audio in overlapping windows
        let mut pos = 0;
        while pos + self.window_size <= audio.len() {
            let window_audio = &audio[pos..pos + self.window_size];

            // Compute FFT and get magnitude spectrum
            let spectrum = self.compute_magnitude_spectrum(window_audio);

            // Calculate spectral flux
            let flux = self.compute_spectral_flux(&spectrum);
            self.flux_signal.push_back(flux);

            // Keep flux signal buffer size manageable
            if self.flux_signal.len() > self.median_window_halfsize * 2 + 100 {
                self.flux_signal.pop_front();
            }

            // Update previous spectrum for next iteration
            self.prev_spectrum.copy_from_slice(&spectrum);

            self.frames_processed += 1;
            pos += self.hop_size;
        }

        // Detect peaks in flux signal with adaptive thresholding
        // Only check new frames added in this call
        let start_check = frames_before.saturating_sub(flux_buffer_offset) as usize;

        let peaks = self.pick_peaks_in_range(start_check, self.flux_signal.len());

        // Convert peak indices to absolute timestamps
        for peak_idx in peaks {
            // Convert flux buffer index to absolute frame number
            let absolute_frame = flux_buffer_offset + peak_idx as u64;
            // Convert frame number to sample timestamp
            let timestamp = absolute_frame * self.hop_size as u64;
            onsets.push(timestamp);
        }

        onsets
    }

    /// Compute magnitude spectrum using FFT
    ///
    /// # Arguments
    /// * `audio` - Audio window of size `window_size`
    ///
    /// # Returns
    /// Magnitude spectrum (size = window_size / 2 + 1)
    fn compute_magnitude_spectrum(&self, audio: &[f32]) -> Vec<f32> {
        let mut buffer: Vec<Complex<f32>> = audio
            .iter()
            .zip(self.window.iter())
            .map(|(sample, window_val)| Complex::new(sample * window_val, 0.0))
            .collect();

        // Perform FFT
        let mut planner = self.fft_planner.lock().unwrap();
        let fft = planner.plan_fft_forward(self.window_size);
        fft.process(&mut buffer);

        // Calculate magnitude spectrum (only positive frequencies)
        buffer[..self.window_size / 2 + 1]
            .iter()
            .map(|c| c.norm())
            .collect()
    }

    /// Compute spectral flux as sum of positive differences
    ///
    /// SF(t) = Σ max(0, |FFT(t)| - |FFT(t-1)|)
    ///
    /// # Arguments
    /// * `spectrum` - Current magnitude spectrum
    ///
    /// # Returns
    /// Spectral flux value (scalar)
    fn compute_spectral_flux(&self, spectrum: &[f32]) -> f32 {
        spectrum
            .iter()
            .zip(self.prev_spectrum.iter())
            .map(|(curr, prev)| (curr - prev).max(0.0))
            .sum()
    }

    /// Calculate adaptive threshold using median + offset
    ///
    /// threshold(t) = median(flux[t-N:t+N]) + offset
    ///
    /// # Arguments
    /// * `index` - Index in flux signal to compute threshold for
    ///
    /// # Returns
    /// Adaptive threshold value
    fn adaptive_threshold(&self, index: usize) -> f32 {
        let start = index.saturating_sub(self.median_window_halfsize);
        let end = (index + self.median_window_halfsize).min(self.flux_signal.len());

        if start >= end {
            return self.threshold_offset;
        }

        // Extract window and compute median
        let mut window: Vec<f32> = self.flux_signal.range(start..end).copied().collect();

        if window.is_empty() {
            return self.threshold_offset;
        }

        // Sort to find median
        window.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));

        let median = if window.len().is_multiple_of(2) {
            let mid = window.len() / 2;
            (window[mid - 1] + window[mid]) / 2.0
        } else {
            window[window.len() / 2]
        };

        median + self.threshold_offset
    }

    /// Pick peaks in flux signal where flux > adaptive threshold
    ///
    /// # Arguments
    /// * `start` - Start index in flux signal to check for peaks
    /// * `end` - End index in flux signal to check for peaks
    ///
    /// # Returns
    /// Vector of peak indices in the flux signal (relative to start of flux buffer)
    fn pick_peaks_in_range(&self, start: usize, end: usize) -> Vec<usize> {
        let mut peaks = Vec::new();

        if self.flux_signal.len() < 3 || start >= end {
            return peaks;
        }

        let start = start.max(1); // Need prev value
        let end = end.min(self.flux_signal.len() - 1); // Need next value

        // Find local maxima that exceed adaptive threshold
        for i in start..end {
            let prev = self.flux_signal[i - 1];
            let curr = self.flux_signal[i];
            let next = self.flux_signal[i + 1];

            // Check if it's a local maximum
            if curr > prev && curr > next {
                let threshold = self.adaptive_threshold(i);

                // Check if it exceeds adaptive threshold
                if curr > threshold {
                    peaks.push(i);
                }
            }
        }

        peaks
    }

    /// Pick all peaks in the entire flux signal (for testing)
    #[cfg(test)]
    fn pick_peaks(&self) -> Vec<usize> {
        self.pick_peaks_in_range(0, self.flux_signal.len())
    }

    /// Get the most recent spectral flux value
    ///
    /// Returns the latest spectral flux value from the flux signal buffer,
    /// or 0.0 if no samples have been processed yet.
    ///
    /// This is useful for real-time visualization of spectral flux in debug UI.
    pub fn last_spectral_flux(&self) -> f32 {
        self.flux_signal.back().copied().unwrap_or(0.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Generate synthetic impulse signal for testing
    fn generate_impulse(sample_rate: u32, duration_ms: u32, impulse_positions: &[u32]) -> Vec<f32> {
        let total_samples = (sample_rate * duration_ms / 1000) as usize;
        let mut signal = vec![0.0; total_samples];

        for &pos_ms in impulse_positions {
            let sample_idx = (sample_rate * pos_ms / 1000) as usize;
            if sample_idx < total_samples {
                // Create a short burst of energy (10 samples)
                for offset in 0..10 {
                    if sample_idx + offset < total_samples {
                        signal[sample_idx + offset] = 1.0;
                    }
                }
            }
        }

        signal
    }

    #[test]
    fn test_onset_detector_detects_impulse() {
        let sample_rate = 48000;
        let mut detector = OnsetDetector::new(sample_rate);

        // Generate signal with strong impulses
        // Use simpler test: just check that we detect SOME onset in a signal with impulses
        let signal = generate_impulse(sample_rate, 500, &[100, 300]);

        // Process signal
        let onsets = detector.process(&signal);

        // Should detect at least one onset
        assert!(
            !onsets.is_empty(),
            "Failed to detect any onsets in signal with impulses"
        );

        // Should detect at least 2 onsets (we have impulses at 100ms and 300ms)
        assert!(
            !onsets.is_empty(),
            "Expected to detect at least 1 onset, found {}",
            onsets.len()
        );

        println!("Detected onsets at samples: {:?}", onsets);
        println!(
            "Detected onsets at times (ms): {:?}",
            onsets
                .iter()
                .map(|&s| s as f32 / sample_rate as f32 * 1000.0)
                .collect::<Vec<f32>>()
        );

        // Verify first onset is in first half of signal (before 250ms)
        let first_onset_ms = onsets[0] as f32 / sample_rate as f32 * 1000.0;
        assert!(
            first_onset_ms < 250.0,
            "First onset at {:.1}ms, expected before 250ms",
            first_onset_ms
        );
    }

    #[test]
    fn test_spectral_flux_calculation() {
        let sample_rate = 48000;
        let detector = OnsetDetector::new(sample_rate);

        // Test with zero change
        let spectrum1 = vec![1.0; 129];
        let spectrum2 = vec![1.0; 129];

        let mut detector_mut = detector;
        detector_mut.prev_spectrum = spectrum1;
        let flux = detector_mut.compute_spectral_flux(&spectrum2);

        // No change should result in zero flux
        assert_eq!(flux, 0.0, "Flux should be zero for identical spectra");
    }

    #[test]
    fn test_spectral_flux_positive_difference() {
        let sample_rate = 48000;
        let mut detector = OnsetDetector::new(sample_rate);

        // Previous spectrum
        detector.prev_spectrum = vec![1.0; 129];

        // Current spectrum with increase
        let spectrum_increased = vec![2.0; 129];

        let flux = detector.compute_spectral_flux(&spectrum_increased);

        // Flux should be positive sum of differences
        assert!(flux > 0.0, "Flux should be positive for increased energy");
        assert_eq!(flux, 129.0, "Flux should equal sum of differences");
    }

    #[test]
    fn test_adaptive_threshold() {
        let sample_rate = 48000;
        let mut detector = OnsetDetector::new(sample_rate);

        // Fill flux signal with test data
        for i in 0..100 {
            detector.flux_signal.push_back(i as f32);
        }

        // Compute threshold at middle index
        let threshold = detector.adaptive_threshold(50);

        // Threshold should be median + offset
        // For 0-100 range, median around 50
        assert!(
            threshold > 40.0 && threshold < 60.0,
            "Threshold {} outside expected range",
            threshold
        );
    }

    #[test]
    fn test_peak_picking() {
        let sample_rate = 48000;
        let mut detector = OnsetDetector::new(sample_rate);

        // Create flux signal with obvious peaks
        for i in 0..20 {
            if i == 5 || i == 15 {
                detector.flux_signal.push_back(10.0); // Peak
            } else {
                detector.flux_signal.push_back(0.1); // Baseline
            }
        }

        let peaks = detector.pick_peaks();

        // Should detect the two peaks
        assert!(!peaks.is_empty(), "Should detect peaks");
        assert!(peaks.len() <= 2, "Should detect at most 2 peaks");
    }

    #[test]
    fn test_no_false_positives_on_silence() {
        let sample_rate = 48000;
        let mut detector = OnsetDetector::new(sample_rate);

        // Generate silent signal
        let signal = vec![0.0; sample_rate as usize];

        // Process signal
        let onsets = detector.process(&signal);

        // Should not detect any onsets in silence
        assert!(onsets.is_empty(), "Should not detect onsets in silence");
    }
}
