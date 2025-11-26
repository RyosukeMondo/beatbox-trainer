//! Configuration management for dynamic parameter tuning
//!
//! This module provides runtime configuration loading from JSON files,
//! enabling fast iteration without recompilation. Key parameters for
//! onset detection, calibration, and audio processing can be adjusted
//! via the config file for rapid experimentation.

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

/// Complete application configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub onset_detection: OnsetDetectionConfig,
    pub calibration: CalibrationConfig,
    pub audio: AudioConfig,
}

/// Onset detection algorithm parameters
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OnsetDetectionConfig {
    /// Threshold offset added to median for adaptive thresholding
    pub threshold_offset: f32,
    /// FFT window size in samples
    pub window_size: usize,
    /// Hop size for overlapping windows
    pub hop_size: usize,
    /// Half-size of median filter window (full window = 2 * this + 1)
    pub median_window_halfsize: usize,
    /// Minimum buffer size before processing onset detection
    pub min_buffer_size: usize,
}

impl Default for OnsetDetectionConfig {
    fn default() -> Self {
        Self {
            // Increased from 0.01 to 0.15 to avoid triggering on background noise
            // This is added to the median spectral flux for adaptive thresholding
            threshold_offset: 0.15,
            window_size: 256,
            hop_size: 64,
            median_window_halfsize: 50,
            min_buffer_size: 512,
        }
    }
}

/// Calibration procedure configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CalibrationConfig {
    /// Number of samples to collect per sound type
    pub samples_per_sound: usize,
    /// Enable debug overlay in UI
    pub enable_debug_overlay: bool,
    /// Log statistics every N buffers
    pub log_every_n_buffers: u64,
}

impl Default for CalibrationConfig {
    fn default() -> Self {
        Self {
            samples_per_sound: 10,
            enable_debug_overlay: true,
            log_every_n_buffers: 100,
        }
    }
}

/// Audio engine configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioConfig {
    /// Size of buffer pool for real-time audio transfer
    pub buffer_pool_size: usize,
    /// Size of each audio buffer in samples
    pub buffer_size: usize,
}

impl Default for AudioConfig {
    fn default() -> Self {
        Self {
            buffer_pool_size: 64,
            buffer_size: 2048,
        }
    }
}

impl Default for AppConfig {
    /// Default configuration values (fallback if config file not found)
    fn default() -> Self {
        Self {
            onset_detection: OnsetDetectionConfig::default(),
            calibration: CalibrationConfig::default(),
            audio: AudioConfig::default(),
        }
    }
}

impl AppConfig {
    /// Load configuration from JSON file
    ///
    /// # Arguments
    /// * `path` - Path to JSON config file
    ///
    /// # Returns
    /// * `Ok(AppConfig)` - Loaded configuration
    /// * `Err` - If file doesn't exist or JSON is invalid, returns default config
    pub fn load_from_file<P: AsRef<Path>>(path: P) -> Self {
        match fs::read_to_string(&path) {
            Ok(contents) => match serde_json::from_str(&contents) {
                Ok(config) => {
                    log::info!("[Config] Loaded configuration from {:?}", path.as_ref());
                    config
                }
                Err(err) => {
                    log::warn!(
                        "[Config] Failed to parse JSON from {:?}: {}. Using defaults.",
                        path.as_ref(),
                        err
                    );
                    Self::default()
                }
            },
            Err(err) => {
                log::warn!(
                    "[Config] Failed to read config file {:?}: {}. Using defaults.",
                    path.as_ref(),
                    err
                );
                Self::default()
            }
        }
    }

    /// Load configuration from Android assets directory
    ///
    /// This attempts to load from the Flutter assets directory
    /// which is bundled with the APK.
    #[cfg(target_os = "android")]
    pub fn load_android() -> Self {
        // Try to load from Flutter assets (bundled with APK)
        // Note: flutter_rust_bridge automatically bundles assets/ directory
        // into the APK, but accessing it requires going through Android AssetManager
        // For now, we'll just use defaults and add asset loading later
        log::info!(
            "[Config] Using default configuration (Android asset loading not yet implemented)"
        );
        Self::default()
    }

    /// Load configuration for non-Android platforms
    #[cfg(not(target_os = "android"))]
    pub fn load() -> Self {
        Self::load_from_file("assets/onset_config.json")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = AppConfig::default();
        assert_eq!(config.onset_detection.threshold_offset, 0.15);
        assert_eq!(config.onset_detection.window_size, 256);
        assert_eq!(config.calibration.samples_per_sound, 10);
        assert_eq!(config.audio.buffer_pool_size, 64);
    }

    #[test]
    fn test_json_roundtrip() {
        let config = AppConfig::default();
        let json = serde_json::to_string_pretty(&config).unwrap();
        let parsed: AppConfig = serde_json::from_str(&json).unwrap();

        assert_eq!(
            parsed.onset_detection.threshold_offset,
            config.onset_detection.threshold_offset
        );
        assert_eq!(
            parsed.calibration.samples_per_sound,
            config.calibration.samples_per_sound
        );
    }
}
