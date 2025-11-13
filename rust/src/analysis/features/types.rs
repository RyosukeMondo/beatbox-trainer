// Types module - Data structures for audio features
//
// This module defines the core data structures used throughout the feature
// extraction pipeline.

/// Features extracted from an audio window
///
/// These features are used for beatbox sound classification (kick, snare, hi-hat).
/// Each feature captures different acoustic properties of the audio signal.
#[derive(Debug, Clone, Copy)]
pub struct Features {
    /// Spectral centroid in Hz (weighted mean frequency)
    ///
    /// Measures the "brightness" of the sound. Higher values indicate
    /// more high-frequency content.
    pub centroid: f32,

    /// Zero-crossing rate (0.0 to 1.0, normalized)
    ///
    /// Measures how often the signal crosses zero. Higher values indicate
    /// more noise-like or high-frequency content.
    pub zcr: f32,

    /// Spectral flatness (0.0 to 1.0, geometric/arithmetic mean ratio)
    ///
    /// Measures how tonal vs. noise-like the signal is.
    /// 0.0 = pure tone (e.g., sine wave)
    /// 1.0 = white noise
    pub flatness: f32,

    /// Spectral rolloff in Hz (85% energy threshold)
    ///
    /// The frequency below which 85% of the spectral energy is contained.
    /// Indicates the frequency range of the signal.
    pub rolloff: f32,

    /// Decay time in milliseconds (temporal envelope)
    ///
    /// Measures how quickly the signal amplitude decays from its peak.
    /// Useful for distinguishing percussive sounds with different attack/decay.
    pub decay_time_ms: f32,
}
