// Public API for flutter_rust_bridge integration
// This module provides FFI functions for Flutter to interact with the Rust audio engine

#![allow(dead_code)] // FFI functions are called from Dart, not detected by Rust analyzer

use anyhow::Result;
use once_cell::sync::Lazy;

use crate::analysis::ClassificationResult;
use crate::bridge_generated::StreamSink;
use crate::calibration::CalibrationProgress;
use crate::engine::core::{EngineHandle, ParamPatch};
use crate::error::{AudioError, CalibrationError};
pub mod diagnostics;
pub mod streams;
pub mod types;

pub use diagnostics::{
    fixture_metadata_for_id, load_fixture_catalog, start_fixture_session, stop_fixture_session,
};
pub use streams::{
    audio_metrics_stream, diagnostic_metrics_stream, onset_events_stream, telemetry_stream,
};
use tokio::sync::mpsc::error::TrySendError;
pub use crate::calibration::CalibrationState;
pub use types::{AudioMetrics, CalibrationThresholdKey, OnsetEvent};

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
    crate::debug::pipeline_tracer::init();
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
    eprintln!("[Rust API] start_audio called with bpm={}", bpm);

    // Log current calibration state
    if let Ok(state) = ENGINE_HANDLE.get_calibration_state() {
        eprintln!("[Rust API] Current calibration: is_calibrated={}, level={}, t_kick_centroid={:.1}, t_snare_centroid={:.1}",
                  state.is_calibrated, state.level, state.t_kick_centroid, state.t_snare_centroid);
    } else {
        eprintln!("[Rust API] No calibration state available");
    }

    let result = ENGINE_HANDLE.start_audio(bpm);
    match &result {
        Ok(_) => eprintln!("[Rust API] start_audio succeeded"),
        Err(e) => eprintln!("[Rust API] start_audio failed: {:?}", e),
    }
    result
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

/// Reset calibration session (clears any in-progress procedure and stops audio).
#[flutter_rust_bridge::frb]
pub fn reset_calibration_session() -> Result<(), CalibrationError> {
    ENGINE_HANDLE.reset_calibration_session()
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

/// User confirms current calibration step is OK and wants to advance
///
/// Called when user clicks "OK" after reviewing the collected samples for current sound.
/// Advances to the next sound in the calibration sequence.
///
/// # Returns
/// * `Ok(true)` - Advanced to next sound
/// * `Ok(false)` - Calibration complete (no next sound)
/// * `Err(CalibrationError)` - Error if not waiting for confirmation
#[flutter_rust_bridge::frb]
pub fn confirm_calibration_step() -> Result<bool, CalibrationError> {
    ENGINE_HANDLE.confirm_calibration_step()
}

/// User wants to retry the current calibration step
///
/// Called when user clicks "Retry" to redo sample collection for current sound.
/// Clears collected samples and allows re-collection.
///
/// # Returns
/// * `Ok(())` - Samples cleared, ready to collect again
/// * `Err(CalibrationError)` - Error if not waiting for confirmation
#[flutter_rust_bridge::frb]
pub fn retry_calibration_step() -> Result<(), CalibrationError> {
    ENGINE_HANDLE.retry_calibration_step()
}

/// Manually accept the last rejected-but-valid calibration candidate
///
/// Allows the UI to promote a buffered sample when adaptive gates are too strict.
/// Emits updated progress to the calibration stream.
#[flutter_rust_bridge::frb]
pub fn manual_accept_last_candidate() -> Result<CalibrationProgress, CalibrationError> {
    ENGINE_HANDLE.manual_accept_last_candidate()
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
pub fn load_calibration_state(state: CalibrationState) -> Result<(), CalibrationError> {
    eprintln!("[Rust API] load_calibration_state called");
    eprintln!(
        "[Rust API] State: level={}, is_calibrated={}, t_kick_centroid={}, t_snare_centroid={}, noise_floor_rms={}",
        state.level, state.is_calibrated, state.t_kick_centroid, state.t_snare_centroid, state.noise_floor_rms
    );

    // Load state into EngineHandle
    ENGINE_HANDLE.load_calibration(state)?;
    eprintln!("[Rust API] Calibration state loaded into engine");

    Ok(())
}

/// Get current calibration state
///
/// Retrieves the current calibration state struct.
///
/// # Returns
/// * `Ok(CalibrationState)` - The current calibration state
/// * `Err(CalibrationError)` - Error if lock poisoning
///
/// # Errors
/// - Lock poisoning on calibration state
///
/// # Usage
/// ```dart
/// try {
///   final state = await getCalibrationState();
///   // Use state object directly
/// } catch (e) {
///   print('Failed to get calibration state: $e');
/// }
/// ```
#[flutter_rust_bridge::frb]
pub fn get_calibration_state() -> Result<CalibrationState, CalibrationError> {
    // Get calibration state from EngineHandle
    let state = ENGINE_HANDLE.get_calibration_state()?;
    eprintln!(
        "[Rust API] get_calibration_state: level={}, is_calibrated={}, noise_floor_rms={}",
        state.level, state.is_calibrated, state.noise_floor_rms
    );

    Ok(state)
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

/// Update a single calibration threshold value in the active calibration state.
///
/// This enables manual threshold tweaking for debugging and tuning without
/// requiring a full recalibration cycle.
///
/// # Parameters
/// - `key`: The threshold key to update. Valid keys:
///   - "t_kick_centroid"
///   - "t_kick_zcr"
///   - "t_snare_centroid"
///   - "t_hihat_zcr"
///   - "noise_floor_rms"
/// - `value`: The new threshold value
///
/// # Returns
/// * `Ok(())` - Threshold updated successfully
/// * `Err(CalibrationError)` - If key is invalid or lock fails
#[flutter_rust_bridge::frb]
pub fn update_calibration_threshold(
    key: CalibrationThresholdKey,
    value: f64,
) -> Result<(), CalibrationError> {
    eprintln!(
        "[Rust API] update_calibration_threshold: key={:?}, value={}",
        key, value
    );

    let mut state = ENGINE_HANDLE.get_calibration_state()?;

    match key {
        CalibrationThresholdKey::KickCentroid => state.t_kick_centroid = value as f32,
        CalibrationThresholdKey::KickZcr => state.t_kick_zcr = value as f32,
        CalibrationThresholdKey::SnareCentroid => state.t_snare_centroid = value as f32,
        CalibrationThresholdKey::HihatZcr => state.t_hihat_zcr = value as f32,
        CalibrationThresholdKey::NoiseFloorRms => state.noise_floor_rms = value,
    }

    ENGINE_HANDLE.load_calibration(state)?;
    eprintln!("[Rust API] Threshold {:?} updated to {}", key, value);
    Ok(())
}

/// Get current audio level metrics for real-time display.
///
/// Returns the latest RMS and peak values from the audio engine.
/// This is a lightweight call suitable for UI updates.
///
/// # Returns
/// * `Ok((rms, peak, noise_gate))` - Current audio metrics
/// * `Err(CalibrationError)` - If state cannot be read
#[flutter_rust_bridge::frb]
pub fn get_current_audio_level() -> Result<(f64, f64, f64), CalibrationError> {
    let state = ENGINE_HANDLE.get_calibration_state()?;
    let noise_gate = state.noise_floor_rms * 2.0;
    // Note: RMS/peak would need to come from the analysis thread
    // For now return the noise gate threshold for debugging
    Ok((0.0, 0.0, noise_gate))
}

/// Enable or disable pipeline tracing at runtime
///
/// When enabled, detailed trace logs are emitted for each pipeline stage:
/// - AUDIO_CB: Audio callback receives samples
/// - BUF_QUEUE: Buffer queued to analysis thread
/// - ANALYSIS_RX: Analysis thread receives buffer
/// - RMS: RMS level computed
/// - GATE: Gate decision (above/below threshold)
/// - ONSET: Onset detected by spectral flux
/// - LEVEL_X: Level crossing detected
/// - FEATURES: Features extracted from audio window
/// - CLASSIFY: Classification decision made
/// - RESULT_TX: Result sent to Dart
///
/// # Arguments
/// * `enabled` - true to enable tracing, false to disable
///
/// # Returns
/// * Previous tracing state (true if was enabled)
#[flutter_rust_bridge::frb(sync)]
pub fn set_pipeline_tracing(enabled: bool) -> bool {
    let was_enabled = crate::debug::pipeline_tracer::is_enabled();
    if enabled {
        crate::debug::pipeline_tracer::enable();
    } else {
        crate::debug::pipeline_tracer::disable();
    }
    was_enabled
}

/// Check if pipeline tracing is currently enabled
#[flutter_rust_bridge::frb(sync)]
pub fn is_pipeline_tracing_enabled() -> bool {
    crate::debug::pipeline_tracer::is_enabled()
}

#[cfg(test)]
mod tests;
