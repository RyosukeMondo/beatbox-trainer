// FFT module - Fast Fourier Transform computation
//
// This module handles FFT computation with proper windowing to reduce
// spectral leakage. The magnitude spectrum is used by spectral feature
// extraction functions.

use rustfft::{num_complex::Complex, FftPlanner};
use std::sync::{Arc, Mutex};

/// FFT window size for feature extraction (higher resolution than onset detection)
pub const FFT_SIZE: usize = 1024;

/// FFT processor that computes magnitude spectra from audio windows
pub struct FftProcessor {
    fft_planner: Arc<Mutex<FftPlanner<f32>>>,
    fft_size: usize,
    /// Hann window for FFT (pre-computed)
    window: Vec<f32>,
}

impl FftProcessor {
    /// Create a new FFT processor
    ///
    /// # Arguments
    /// * `fft_size` - FFT window size (typically 1024 for feature extraction)
    pub fn new(fft_size: usize) -> Self {
        // Pre-compute Hann window to reduce spectral leakage
        let window = (0..fft_size)
            .map(|i| {
                0.5 * (1.0
                    - ((2.0 * std::f32::consts::PI * i as f32) / (fft_size as f32 - 1.0)).cos())
            })
            .collect();

        Self {
            fft_planner: Arc::new(Mutex::new(FftPlanner::new())),
            fft_size,
            window,
        }
    }

    /// Compute magnitude spectrum using FFT
    ///
    /// Applies Hann windowing, performs FFT, and returns magnitude spectrum
    /// for positive frequencies only (exploiting symmetry of real-valued FFT).
    ///
    /// # Arguments
    /// * `audio` - Audio window (length <= fft_size)
    ///
    /// # Returns
    /// Magnitude spectrum (size = fft_size / 2 + 1)
    pub fn compute_magnitude_spectrum(&self, audio: &[f32]) -> Vec<f32> {
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
}
