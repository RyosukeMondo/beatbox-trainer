// Public API for flutter_rust_bridge integration
// This module provides FFI functions for Flutter to interact with the Rust audio engine

#![allow(dead_code)] // FFI functions are called from Dart, not detected by Rust analyzer

use anyhow::Result;
use once_cell::sync::Lazy;
use std::sync::{Arc, Mutex, RwLock};
use tokio::sync::mpsc;
use tokio_stream::wrappers::UnboundedReceiverStream;

#[cfg(target_os = "android")]
use crate::audio::{buffer_pool::BufferPool, engine::AudioEngine};
use crate::analysis::ClassificationResult;
use crate::calibration::{
    procedure::{CalibrationProcedure, CalibrationProgress},
    state::CalibrationState,
};

/// Global AudioEngine instance with lifecycle management
///
/// Uses Lazy initialization to defer creation until first use.
/// Mutex ensures thread-safe access across FFI boundary.
/// Option allows for None state when audio engine is not running.
static AUDIO_ENGINE: Lazy<Arc<Mutex<Option<AudioEngineState>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));

/// Global CalibrationProcedure instance for calibration workflow
static CALIBRATION_PROCEDURE: Lazy<Arc<Mutex<Option<CalibrationProcedure>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));

/// Global CalibrationState shared between calibration and classification
static CALIBRATION_STATE: Lazy<Arc<RwLock<CalibrationState>>> =
    Lazy::new(|| Arc::new(RwLock::new(CalibrationState::new_default())));

/// Classification result broadcast channel (for classification_stream)
/// Using broadcast to allow multiple subscribers
static CLASSIFICATION_BROADCAST: Lazy<Arc<Mutex<Option<tokio::sync::broadcast::Sender<ClassificationResult>>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));

/// Calibration progress broadcast channel (for calibration_stream)
static CALIBRATION_BROADCAST: Lazy<Arc<Mutex<Option<tokio::sync::broadcast::Sender<CalibrationProgress>>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));

/// AudioEngine state container for lifecycle management
struct AudioEngineState {
    #[cfg(target_os = "android")]
    engine: AudioEngine,
    #[cfg(not(target_os = "android"))]
    _dummy: (),
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
/// * `Err(String)` - Error message if initialization fails
///
/// # Errors
/// - Audio streams cannot be opened (device busy, permissions denied)
/// - Audio engine already running (call stop_audio first)
/// - Invalid BPM value (must be > 0)
#[flutter_rust_bridge::frb]
pub fn start_audio(_bpm: u32) -> Result<(), String> {
    #[cfg(not(target_os = "android"))]
    {
        return Err("Audio engine only supported on Android".to_string());
    }

    #[cfg(target_os = "android")]
    let bpm = _bpm;

    #[cfg(target_os = "android")]
    {
        if bpm == 0 {
            return Err("BPM must be greater than 0".to_string());
        }

        let mut engine_guard = AUDIO_ENGINE.lock().map_err(|e| e.to_string())?;

        if engine_guard.is_some() {
            return Err("Audio engine already running. Call stop_audio() first.".to_string());
        }

        // Create classification result channels
        // - mpsc channel for analysis thread to send results
        // - broadcast channel for multiple UI subscribers
        let (classification_tx, mut classification_rx) = mpsc::unbounded_channel();
        let (broadcast_tx, _broadcast_rx) = tokio::sync::broadcast::channel(100);

        // Store broadcast sender for classification_stream
        {
            let mut sender_guard = CLASSIFICATION_BROADCAST.lock().map_err(|e| e.to_string())?;
            *sender_guard = Some(broadcast_tx.clone());
        }

        // Spawn forwarder task: mpsc → broadcast
        let broadcast_tx_clone = broadcast_tx.clone();
        tokio::spawn(async move {
            while let Some(result) = classification_rx.recv().await {
                // Broadcast to all subscribers (ignore if no subscribers)
                let _ = broadcast_tx_clone.send(result);
            }
        });

        // Initialize buffer pool (16 buffers of 2048 samples)
        let buffer_pool = BufferPool::new(16, 2048);
        let buffer_channels = buffer_pool;

        // Create AudioEngine (takes ownership of buffer_channels)
        let sample_rate = 48000; // Standard sample rate for Android
        let mut engine = AudioEngine::new(bpm, sample_rate, buffer_channels)
            .map_err(|e| format!("Failed to create AudioEngine: {}", e))?;

        // Get calibration state for AudioEngine::start()
        let calibration = Arc::clone(&CALIBRATION_STATE);

        // Start audio streams (AudioEngine::start spawns analysis thread internally)
        engine.start(calibration, classification_tx)
            .map_err(|e| format!("Failed to start audio: {}", e))?;

        // Store engine state
        *engine_guard = Some(AudioEngineState {
            engine,
        });

        Ok(())
    }
}

/// Stop the audio engine
///
/// Stops audio streams, shuts down the analysis thread, and releases resources.
/// Safe to call even if audio engine is not running.
///
/// # Returns
/// * `Ok(())` - Audio engine stopped successfully or was not running
/// * `Err(String)` - Error message if shutdown fails
#[flutter_rust_bridge::frb]
pub fn stop_audio() -> Result<(), String> {
    #[cfg(not(target_os = "android"))]
    {
        return Err("Audio engine only supported on Android".to_string());
    }

    #[cfg(target_os = "android")]
    {
        let mut engine_guard = AUDIO_ENGINE.lock().map_err(|e| e.to_string())?;

        if let Some(mut state) = engine_guard.take() {
            // Stop audio streams (AudioEngine manages analysis thread cleanup)
            state.engine.stop().map_err(|e| format!("Failed to stop audio: {}", e))?;

            // Clear classification broadcast sender to signal stream end
            {
                let mut sender_guard = CLASSIFICATION_BROADCAST.lock().map_err(|e| e.to_string())?;
                *sender_guard = None;
            }
        }

        Ok(())
    }
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
/// * `Err(String)` - Error message if update fails
///
/// # Errors
/// - Audio engine not running
/// - Invalid BPM value (must be > 0)
#[flutter_rust_bridge::frb]
pub fn set_bpm(_bpm: u32) -> Result<(), String> {
    #[cfg(not(target_os = "android"))]
    {
        return Err("Audio engine only supported on Android".to_string());
    }

    #[cfg(target_os = "android")]
    let bpm = _bpm;

    #[cfg(target_os = "android")]
    {
        if bpm == 0 {
            return Err("BPM must be greater than 0".to_string());
        }

        let engine_guard = AUDIO_ENGINE.lock().map_err(|e| e.to_string())?;

        if let Some(state) = engine_guard.as_ref() {
            state.engine.set_bpm(bpm);
            Ok(())
        } else {
            Err("Audio engine not running. Call start_audio() first.".to_string())
        }
    }
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
    use futures::stream::StreamExt;

    // Subscribe to broadcast channel
    let receiver = {
        let sender_guard = CLASSIFICATION_BROADCAST.lock().unwrap();
        if let Some(broadcast_sender) = sender_guard.as_ref() {
            Some(broadcast_sender.subscribe())
        } else {
            None
        }
    };

    if let Some(rx) = receiver {
        // Create stream from broadcast receiver
        futures::stream::unfold(rx, |mut rx| async move {
            match rx.recv().await {
                Ok(result) => Some((result, rx)),
                Err(_) => None, // Channel closed or lagged
            }
        })
        .boxed()
    } else {
        // Return empty stream if broadcast not initialized
        futures::stream::empty().boxed()
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
/// * `Err(String)` - Error message if calibration cannot start
///
/// # Errors
/// - Calibration already in progress
#[flutter_rust_bridge::frb]
pub fn start_calibration() -> Result<(), String> {
    let mut procedure_guard = CALIBRATION_PROCEDURE.lock().map_err(|e| e.to_string())?;

    if procedure_guard.is_some() {
        return Err("Calibration already in progress. Call finish_calibration() first.".to_string());
    }

    // Create new calibration procedure (starts with KICK by default)
    let procedure = CalibrationProcedure::new_default();
    *procedure_guard = Some(procedure);

    Ok(())
}

/// Finish calibration and compute thresholds
///
/// Completes the calibration process, computes thresholds from collected samples,
/// and updates the global CalibrationState used by the classifier.
///
/// # Returns
/// * `Ok(())` - Calibration completed successfully
/// * `Err(String)` - Error message if calibration incomplete or invalid
///
/// # Errors
/// - Calibration not in progress
/// - Insufficient samples collected (need 10 per sound type)
/// - Sample validation failed (out of range features)
#[flutter_rust_bridge::frb]
pub fn finish_calibration() -> Result<(), String> {
    let mut procedure_guard = CALIBRATION_PROCEDURE.lock().map_err(|e| e.to_string())?;

    if let Some(procedure) = procedure_guard.take() {
        // Compute calibrated state from collected samples
        let new_state = procedure.finalize()
            .map_err(|e| format!("Calibration failed: {}", e))?;

        // Update global calibration state
        let mut state_guard = CALIBRATION_STATE.write().map_err(|e| e.to_string())?;
        *state_guard = new_state;

        Ok(())
    } else {
        Err("No calibration in progress. Call start_calibration() first.".to_string())
    }
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
    let (tx, rx) = mpsc::unbounded_channel();

    // Spawn task to poll calibration progress and broadcast updates
    tokio::spawn(async move {
        let mut last_progress: Option<CalibrationProgress> = None;

        loop {
            let progress = {
                let procedure_guard = CALIBRATION_PROCEDURE.lock().unwrap();
                if let Some(procedure) = procedure_guard.as_ref() {
                    Some(procedure.get_progress())
                } else {
                    None
                }
            };

            // Only send if progress changed or this is the first update
            if let Some(current_progress) = progress {
                let should_send = match &last_progress {
                    None => true,
                    Some(last) => {
                        last.current_sound != current_progress.current_sound
                            || last.samples_collected != current_progress.samples_collected
                    }
                };

                if should_send {
                    if tx.send(current_progress.clone()).is_err() {
                        break; // Stream closed
                    }
                    last_progress = Some(current_progress);
                }
            } else if last_progress.is_some() {
                // Calibration procedure ended
                break;
            }

            tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
        }
    });

    UnboundedReceiverStream::new(rx)
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
