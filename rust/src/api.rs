// Public API for flutter_rust_bridge integration
// This module provides FFI functions for Flutter to interact with the Rust audio engine

#![allow(dead_code)] // FFI functions are called from Dart, not detected by Rust analyzer

use anyhow::Result;
use once_cell::sync::Lazy;

use crate::analysis::ClassificationResult;
use crate::calibration::CalibrationProgress;
use crate::context::AppContext;
use crate::error::{AudioError, CalibrationError};

/// Global AppContext instance - Single dependency injection container
///
/// Consolidates all application state (audio engine, calibration, broadcast channels)
/// into a single, testable context. This replaces 5 separate global statics.
///
/// Benefits:
/// - Single point of truth for application state
/// - Testable with mock dependencies
/// - Graceful error handling (no unwrap/expect)
/// - Clear ownership and lifecycle management
static APP_CONTEXT: Lazy<AppContext> = Lazy::new(AppContext::new);

/// Initialize and greet from Rust
///
/// This is a simple stub function to verify flutter_rust_bridge integration works.
/// Returns a greeting message.
///
/// # Returns
///
/// * `Result<String>` - Success message or error
#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> Result<String> {
    Ok(format!("Hello, {}! Flutter Rust Bridge is working.", name))
}

/// Get the version of the audio engine
///
/// Returns the current version of the beatbox trainer audio engine.
///
/// # Returns
///
/// * `Result<String>` - Version string
#[flutter_rust_bridge::frb(sync)]
pub fn get_version() -> Result<String> {
    Ok(env!("CARGO_PKG_VERSION").to_string())
}

/// Start the audio engine with specified BPM
///
/// Initializes the audio engine, starts full-duplex audio streams with Oboe,
/// spawns the analysis thread, and begins metronome generation.
///
/// # Arguments
/// * `bpm` - Beats per minute (typically 40-240)
///
/// # Returns
/// * `Ok(())` - Audio engine started successfully
/// * `Err(AudioError)` - Error if initialization fails
///
/// # Errors
/// - Audio streams cannot be opened (device busy, permissions denied)
/// - Audio engine already running (call stop_audio first)
/// - Invalid BPM value (must be > 0)
/// - Lock poisoning on shared state
#[flutter_rust_bridge::frb]
pub fn start_audio(bpm: u32) -> Result<(), AudioError> {
    APP_CONTEXT.start_audio(bpm)
}

/// Stop the audio engine
///
/// Stops audio streams, shuts down the analysis thread, and releases resources.
/// Safe to call even if audio engine is not running.
///
/// # Returns
/// * `Ok(())` - Audio engine stopped successfully or was not running
/// * `Err(AudioError)` - Error if shutdown fails or lock poisoning
#[flutter_rust_bridge::frb]
pub fn stop_audio() -> Result<(), AudioError> {
    APP_CONTEXT.stop_audio()
}

/// Set BPM dynamically during audio playback
///
/// Updates the metronome tempo. Note: This currently requires audio engine restart
/// to maintain real-time safety guarantees.
///
/// # Arguments
/// * `bpm` - New beats per minute (typically 40-240)
///
/// # Returns
/// * `Ok(())` - BPM updated successfully
/// * `Err(AudioError)` - Error if update fails
///
/// # Errors
/// - Audio engine not running
/// - Invalid BPM value (must be > 0)
/// - Lock poisoning on audio engine state
#[flutter_rust_bridge::frb]
pub fn set_bpm(bpm: u32) -> Result<(), AudioError> {
    APP_CONTEXT.set_bpm(bpm)
}

/// Stream of classification results
///
/// Returns a stream that yields ClassificationResult on each detected onset.
/// Each result contains the detected sound type (KICK/SNARE/HIHAT/UNKNOWN)
/// and timing feedback (ON_TIME/EARLY/LATE with error in milliseconds).
///
/// # Returns
/// Stream<ClassificationResult> that yields results until audio engine stops
///
/// # Usage
/// ```dart
/// final stream = await classificationStream();
/// await for (final result in stream) {
///   print('Sound: ${result.sound}, Timing: ${result.timing}');
/// }
/// ```
#[flutter_rust_bridge::frb(stream)]
pub async fn classification_stream() -> impl futures::Stream<Item = ClassificationResult> {
    APP_CONTEXT.classification_stream().await
}

/// Start calibration workflow
///
/// Begins collecting samples for calibration. The system will detect onsets
/// and extract features without classifying. Collect 10 samples per sound type.
///
/// Calibration sequence: KICK → SNARE → HI-HAT
///
/// # Returns
/// * `Ok(())` - Calibration started
/// * `Err(CalibrationError)` - Error if calibration cannot start
///
/// # Errors
/// - Calibration already in progress
/// - Lock poisoning on calibration procedure state
#[flutter_rust_bridge::frb]
pub fn start_calibration() -> Result<(), CalibrationError> {
    APP_CONTEXT.start_calibration()
}

/// Finish calibration and compute thresholds
///
/// Completes the calibration process, computes thresholds from collected samples,
/// and updates the global CalibrationState used by the classifier.
///
/// # Returns
/// * `Ok(())` - Calibration completed successfully
/// * `Err(CalibrationError)` - Error if calibration incomplete or invalid
///
/// # Errors
/// - Calibration not in progress
/// - Insufficient samples collected (need 10 per sound type)
/// - Sample validation failed (out of range features)
/// - Lock poisoning on calibration state
#[flutter_rust_bridge::frb]
pub fn finish_calibration() -> Result<(), CalibrationError> {
    APP_CONTEXT.finish_calibration()
}

/// Stream of calibration progress updates
///
/// Returns a stream that yields CalibrationProgress as samples are collected.
/// Each progress update contains the current sound being calibrated and
/// the number of samples collected (0-10).
///
/// # Returns
/// Stream<CalibrationProgress> that yields progress updates
///
/// # Usage
/// ```dart
/// final stream = await calibrationStream();
/// await for (final progress in stream) {
///   print('${progress.currentSound}: ${progress.samplesCollected}/10');
/// }
/// ```
#[flutter_rust_bridge::frb(stream)]
pub async fn calibration_stream() -> impl futures::Stream<Item = CalibrationProgress> {
    APP_CONTEXT.calibration_stream().await
}

/// Load calibration state from JSON
///
/// Restores a previously saved calibration state from JSON string.
/// This allows users to skip calibration on subsequent app launches.
///
/// # Arguments
/// * `json` - JSON string containing serialized CalibrationState
///
/// # Returns
/// * `Ok(())` - Calibration state loaded successfully
/// * `Err(CalibrationError)` - Error if deserialization fails or lock poisoning
///
/// # Errors
/// - JSON deserialization error (invalid format)
/// - Lock poisoning on calibration state
///
/// # Usage
/// ```dart
/// try {
///   await loadCalibrationState(jsonString);
///   print('Calibration loaded successfully');
/// } catch (e) {
///   print('Failed to load calibration: $e');
/// }
/// ```
#[flutter_rust_bridge::frb]
pub fn load_calibration_state(json: String) -> Result<(), CalibrationError> {
    use crate::calibration::CalibrationState;

    // Deserialize JSON to CalibrationState
    let state: CalibrationState =
        serde_json::from_str(&json).map_err(|e| CalibrationError::InvalidFeatures {
            reason: format!("Failed to deserialize calibration JSON: {}", e),
        })?;

    // Load state into AppContext
    APP_CONTEXT.load_calibration(state)?;

    Ok(())
}

/// Get current calibration state as JSON
///
/// Retrieves the current calibration state serialized to JSON string.
/// This JSON can be saved to persistent storage and restored later using
/// `load_calibration_state`.
///
/// # Returns
/// * `Ok(String)` - JSON string containing serialized CalibrationState
/// * `Err(CalibrationError)` - Error if serialization fails or lock poisoning
///
/// # Errors
/// - JSON serialization error (should be rare)
/// - Lock poisoning on calibration state
///
/// # Usage
/// ```dart
/// try {
///   final jsonString = await getCalibrationState();
///   // Save jsonString to SharedPreferences
/// } catch (e) {
///   print('Failed to get calibration state: $e');
/// }
/// ```
#[flutter_rust_bridge::frb]
pub fn get_calibration_state() -> Result<String, CalibrationError> {
    // Get calibration state from AppContext
    let state = APP_CONTEXT.get_calibration_state()?;

    // Serialize to JSON
    serde_json::to_string(&state).map_err(|e| CalibrationError::InvalidFeatures {
        reason: format!("Failed to serialize calibration state to JSON: {}", e),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_greet() {
        let result = greet("World".to_string()).unwrap();
        assert_eq!(result, "Hello, World! Flutter Rust Bridge is working.");
    }

    #[test]
    fn test_get_version() {
        let result = get_version().unwrap();
        assert_eq!(result, "0.1.0");
    }

    // Removed: add_numbers test (stub function removed)
}
