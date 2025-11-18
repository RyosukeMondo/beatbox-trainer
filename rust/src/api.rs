// Public API for flutter_rust_bridge integration
// This module provides FFI functions for Flutter to interact with the Rust audio engine

#![allow(dead_code)] // FFI functions are called from Dart, not detected by Rust analyzer

use anyhow::Result;
use once_cell::sync::Lazy;

use crate::analysis::ClassificationResult;
use crate::bridge_generated::StreamSink;
use crate::calibration::CalibrationProgress;
use crate::engine::core::{EngineHandle, ParamPatch, TelemetryEvent};
use crate::error::{AudioError, CalibrationError};

mod diagnostics;
mod types;

pub use diagnostics::{start_fixture_session, stop_fixture_session};
use tokio::sync::mpsc::error::TrySendError;
pub use types::{AudioMetrics, OnsetEvent};

// Re-export error code constants for FFI exposure
pub use crate::error::{AudioErrorCodes, CalibrationErrorCodes};

/// Global engine handle instance - Single dependency injection container
///
/// Consolidates all application state (audio engine, calibration, broadcast channels)
/// into a single, testable context. This replaces 5 separate global statics.
///
/// Benefits:
/// - Single point of truth for application state
/// - Testable with mock dependencies
/// - Graceful error handling (no unwrap/expect)
/// - Clear ownership and lifecycle management
static ENGINE_HANDLE: Lazy<EngineHandle> = Lazy::new(EngineHandle::new);

/// Initialize flutter_rust_bridge with Tokio runtime
///
/// This function creates a Tokio runtime for async operations (streams, spawn, etc.).
/// It must be called before any async FFI functions are used.
///
/// flutter_rust_bridge will automatically call this during RustLib.init().
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
    crate::http::spawn_if_enabled(&ENGINE_HANDLE);
}

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
    ENGINE_HANDLE.start_audio(bpm)
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
    ENGINE_HANDLE.stop_audio()
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
    ENGINE_HANDLE.set_bpm(bpm)
}

/// Apply parameter patch to running engine (BPM/threshold updates)
#[flutter_rust_bridge::frb]
pub fn apply_params(patch: ParamPatch) -> Result<(), AudioError> {
    if patch.bpm.is_none() && patch.centroid_threshold.is_none() && patch.zcr_threshold.is_none() {
        return Err(AudioError::StreamFailure {
            reason: "at least one parameter must be provided".to_string(),
        });
    }

    ENGINE_HANDLE
        .command_sender()
        .try_send(patch)
        .map_err(|err| match err {
            TrySendError::Full(_) => AudioError::StreamFailure {
                reason: "parameter command queue is full".to_string(),
            },
            TrySendError::Closed(_) => AudioError::StreamFailure {
                reason: "parameter command channel closed".to_string(),
            },
        })
}

/// Stream of classification results
///
/// Returns a stream that yields ClassificationResult on each detected onset.
/// Each result contains the detected sound type (KICK/SNARE/HIHAT/UNKNOWN)
/// and timing feedback (ON_TIME/EARLY/LATE with error in milliseconds).
///
/// The stream is active while the audio engine is running and emits results
/// continuously until the audio engine is stopped.
///
/// # Parameters
/// * `sink` - StreamSink for forwarding classification results to Dart
///
/// # Usage
/// ```dart
/// final stream = classificationStream();
/// await for (final result in stream) {
///   print('Sound: ${result.sound}, Timing: ${result.timing}');
/// }
/// ```
///
/// # Implementation
/// Uses the StreamSink pattern supported by flutter_rust_bridge:
/// - Rust function accepts `StreamSink<T>` parameter
/// - Dart receives `Stream<T>` return type
/// - Function can hold sink and emit results asynchronously
#[allow(unused_must_use)] // frb macro generates code that triggers this lint
#[flutter_rust_bridge::frb]
pub fn classification_stream(sink: StreamSink<ClassificationResult>) {
    // Get a direct subscription to the classification broadcast channel
    // This avoids the tokio::spawn in subscribe_classification()
    let broadcast_rx = ENGINE_HANDLE.broadcasts.subscribe_classification();

    if let Some(mut broadcast_rx) = broadcast_rx {
        std::thread::spawn(move || {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("Failed to create Tokio runtime for classification stream");

            rt.block_on(async move {
                loop {
                    match broadcast_rx.recv().await {
                        Ok(result) => {
                            if sink.add(result).is_err() {
                                break;
                            }
                        }
                        Err(err) => {
                            let _ = sink.add_error(AudioError::StreamFailure {
                                reason: format!("classification channel closed: {}", err),
                            });
                            break;
                        }
                    }
                }
            });
        });
    } else {
        let _ = sink.add_error(AudioError::StreamFailure {
            reason: "classification channel unavailable".to_string(),
        });
    }
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
    ENGINE_HANDLE.start_calibration()
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
    ENGINE_HANDLE.finish_calibration()
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
/// final stream = calibrationStream();
/// await for (final progress in stream) {
///   print('${progress.currentSound}: ${progress.samplesCollected}/10');
/// }
/// ```
///
/// # Implementation
/// Uses the StreamSink pattern supported by flutter_rust_bridge:
/// - Rust function accepts `StreamSink<T>` parameter
/// - Dart receives `Stream<T>` return type
/// - Function can hold sink and emit results asynchronously
#[allow(unused_must_use)] // frb macro generates code that triggers this lint
#[flutter_rust_bridge::frb]
pub fn calibration_stream(sink: StreamSink<CalibrationProgress>) {
    // Get a direct subscription to the calibration broadcast channel
    // This avoids the tokio::spawn in subscribe_calibration()
    let broadcast_rx = ENGINE_HANDLE.broadcasts.subscribe_calibration();

    if let Some(mut broadcast_rx) = broadcast_rx {
        std::thread::spawn(move || {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("Failed to create Tokio runtime for calibration stream");

            rt.block_on(async move {
                loop {
                    match broadcast_rx.recv().await {
                        Ok(progress) => {
                            if sink.add(progress).is_err() {
                                break;
                            }
                        }
                        Err(err) => {
                            let _ = sink.add_error(CalibrationError::Timeout {
                                reason: format!("calibration channel interrupted: {}", err),
                            });
                            break;
                        }
                    }
                }
            });
        });
    } else {
        let _ = sink.add_error(CalibrationError::Timeout {
            reason: "calibration channel unavailable".to_string(),
        });
    }
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

    // Load state into EngineHandle
    ENGINE_HANDLE.load_calibration(state)?;

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
    // Get calibration state from EngineHandle
    let state = ENGINE_HANDLE.get_calibration_state()?;

    // Serialize to JSON
    serde_json::to_string(&state).map_err(|e| CalibrationError::InvalidFeatures {
        reason: format!("Failed to serialize calibration state to JSON: {}", e),
    })
}

/// Stream of audio metrics for debug visualization
///
/// Returns a stream that yields AudioMetrics with real-time DSP metrics
/// from the audio processing pipeline. Useful for debugging and development.
///
/// Metrics include:
/// - RMS amplitude level
/// - Spectral centroid
/// - Spectral flux
/// - Frame numbers and timestamps
///
/// # Returns
/// Stream<AudioMetrics> that yields metrics while audio engine is running
///
/// # Usage
/// ```dart
/// final stream = await audioMetricsStream();
/// await for (final metrics in stream) {
///   print('RMS: ${metrics.rms}, Centroid: ${metrics.spectralCentroid} Hz');
/// }
/// ```
#[flutter_rust_bridge::frb(ignore)]
pub async fn audio_metrics_stream() -> impl futures::Stream<Item = AudioMetrics> {
    ENGINE_HANDLE.audio_metrics_stream().await
}

/// Stream of telemetry events for debug instrumentation
///
/// Emits engine lifecycle events (start/stop, BPM changes) and warnings.
#[allow(unused_must_use)]
#[flutter_rust_bridge::frb]
pub fn telemetry_stream(sink: StreamSink<TelemetryEvent>) {
    let mut telemetry_rx = ENGINE_HANDLE.subscribe_telemetry();

    std::thread::spawn(move || {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("Failed to create Tokio runtime for telemetry stream");

        rt.block_on(async move {
            loop {
                match telemetry_rx.recv().await {
                    Some(event) => {
                        if sink.add(event).is_err() {
                            break;
                        }
                    }
                    None => {
                        let _ = sink.add_error(AudioError::StreamFailure {
                            reason: "telemetry channel closed".to_string(),
                        });
                        break;
                    }
                }
            }
        });
    });
}

/// Stream of onset events for debug visualization
///
/// Returns a stream that yields OnsetEvent whenever an onset (percussive transient)
/// is detected. Each event includes extracted features and classification result.
///
/// Useful for:
/// - Understanding onset detection behavior
/// - Debugging classification issues
/// - Visualizing feature extraction in real-time
///
/// # Returns
/// Stream<OnsetEvent> that yields onset events while audio engine is running
///
/// # Usage
/// ```dart
/// final stream = await onsetEventsStream();
/// await for (final event in stream) {
///   print('Onset at ${event.timestamp}ms: ${event.classification?.sound}');
/// }
/// ```
#[flutter_rust_bridge::frb(ignore)]
pub async fn onset_events_stream() -> impl futures::Stream<Item = OnsetEvent> {
    ENGINE_HANDLE.onset_events_stream().await
}

// Error code constant accessors for Dart/Flutter
// These functions expose error code constants from AudioErrorCodes and CalibrationErrorCodes

/// Get AudioErrorCodes as a structured object with all error code constants
#[flutter_rust_bridge::frb(sync)]
pub fn get_audio_error_codes() -> AudioErrorCodes {
    AudioErrorCodes {}
}

/// Get CalibrationErrorCodes as a structured object with all error code constants
#[flutter_rust_bridge::frb(sync)]
pub fn get_calibration_error_codes() -> CalibrationErrorCodes {
    CalibrationErrorCodes {}
}

#[cfg(test)]
mod tests;
