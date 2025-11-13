//! Integration tests for FFI bridge and AppContext
//!
//! These tests validate the full audio lifecycle across the Rust layer,
//! including:
//! - Audio engine start/stop lifecycle
//! - Stream behavior (subscribe, receive, close)
//! - Error propagation and typed error handling
//! - Calibration workflow integration
//!
//! Note: These tests are non-Android compatible and test the non-Android code paths.

use beatbox_trainer::context::AppContext;
use beatbox_trainer::error::{AudioError, CalibrationError};

/// Test that AppContext can be created successfully
#[test]
fn test_app_context_creation() {
    let context = AppContext::new();
    // Simply verify that creation doesn't panic
    // The context should be in a clean initial state
    drop(context);
}

/// Test audio lifecycle: start → stop
///
/// On non-Android platforms, start_audio should return HardwareError
#[test]
fn test_audio_lifecycle_non_android() {
    let context = AppContext::new();

    // Attempt to start audio (should fail on non-Android)
    let result = context.start_audio(120);

    // Verify we get the expected error on non-Android
    #[cfg(not(target_os = "android"))]
    {
        assert!(result.is_err(), "start_audio should fail on non-Android");
        match result.unwrap_err() {
            AudioError::HardwareError { details } => {
                assert!(
                    details.contains("only supported on Android"),
                    "Error should mention Android requirement"
                );
            }
            other => panic!("Expected HardwareError, got {:?}", other),
        }
    }

    // On Android, we can't test full lifecycle without real hardware
    #[cfg(target_os = "android")]
    {
        // Just verify the call doesn't panic
        let _ = result;
    }
}

/// Test BPM validation in start_audio
#[cfg(target_os = "android")]
#[test]
fn test_bpm_validation() {
    let context = AppContext::new();

    // Test invalid BPM (0)
    let result = context.start_audio(0);
    assert!(result.is_err(), "start_audio should reject BPM = 0");
    match result.unwrap_err() {
        AudioError::BpmInvalid { bpm } => {
            assert_eq!(bpm, 0, "Error should report the invalid BPM value");
        }
        other => panic!("Expected BpmInvalid, got {:?}", other),
    }
}

/// Test double-start prevention (AlreadyRunning error)
#[cfg(target_os = "android")]
#[test]
fn test_double_start_prevention() {
    let context = AppContext::new();

    // First start (may fail due to hardware, but that's ok)
    let first_result = context.start_audio(120);

    // If first start succeeded, verify second start fails with AlreadyRunning
    if first_result.is_ok() {
        let second_result = context.start_audio(120);
        assert!(
            second_result.is_err(),
            "Second start_audio should fail with AlreadyRunning"
        );
        match second_result.unwrap_err() {
            AudioError::AlreadyRunning => {
                // Expected error
            }
            other => panic!("Expected AlreadyRunning, got {:?}", other),
        }

        // Clean up
        let _ = context.stop_audio();
    }
}

/// Test that stop_audio is safe to call when not running
#[test]
fn test_stop_audio_when_not_running() {
    let context = AppContext::new();

    // Stop audio when not running should succeed (graceful handling)
    let result = context.stop_audio();

    #[cfg(not(target_os = "android"))]
    {
        // On non-Android, stop_audio returns HardwareError
        assert!(
            result.is_err(),
            "stop_audio should return error on non-Android"
        );
        match result.unwrap_err() {
            AudioError::HardwareError { details } => {
                assert!(
                    details.contains("only supported on Android"),
                    "Error should mention Android requirement"
                );
            }
            other => panic!("Expected HardwareError, got {:?}", other),
        }
    }

    #[cfg(target_os = "android")]
    {
        // On Android, stop_audio when not running should succeed
        assert!(
            result.is_ok(),
            "stop_audio should succeed even when not running"
        );
    }
}

/// Test calibration lifecycle: start → add samples → finish
#[test]
fn test_calibration_lifecycle() {
    let context = AppContext::new();

    // Start calibration
    let result = context.start_calibration();
    assert!(result.is_ok(), "start_calibration should succeed");

    // Attempt to start calibration again (should fail with AlreadyInProgress)
    let double_start = context.start_calibration();
    assert!(
        double_start.is_err(),
        "Second start_calibration should fail"
    );
    match double_start.unwrap_err() {
        CalibrationError::AlreadyInProgress => {
            // Expected error
        }
        other => panic!("Expected AlreadyInProgress, got {:?}", other),
    }

    // Note: We can't add samples without a running audio engine,
    // so we'll just test the state transitions

    // Finish calibration (will fail with InsufficientSamples, but that's expected)
    let finish_result = context.finish_calibration();
    assert!(
        finish_result.is_err(),
        "finish_calibration should fail without samples"
    );
    match finish_result.unwrap_err() {
        CalibrationError::InsufficientSamples { .. } => {
            // Expected error - we didn't collect any samples
        }
        other => panic!("Expected InsufficientSamples, got {:?}", other),
    }
}

/// Test calibration stream subscription
#[tokio::test]
async fn test_calibration_stream() {
    let context = AppContext::new();

    // Start calibration to enable stream
    let _ = context.start_calibration();

    // Subscribe to calibration stream (returns stream directly, not Result)
    let stream = context.calibration_stream().await;

    // We won't receive any progress updates without a running audio engine,
    // but we've verified the stream can be created

    // Stream should be valid (we can't easily test async reception without audio engine)
    drop(stream);
}

/// Test classification stream when audio is not running
///
/// The stream method itself succeeds, but returns an empty stream
/// when audio is not running (no broadcast sender available).
#[tokio::test]
async fn test_classification_stream_when_not_running() {
    use futures::stream::StreamExt;

    let context = AppContext::new();

    // Get classification stream without starting audio
    // Stream creation succeeds, but it will be empty
    let mut stream = context.classification_stream().await;

    // Try to get one item from the stream with a timeout
    // Should return None immediately since audio is not running
    let result = tokio::time::timeout(std::time::Duration::from_millis(100), stream.next()).await;

    // Should timeout or return None because audio is not running
    match result {
        Ok(Some(_)) => panic!("Should not receive results when audio not running"),
        Ok(None) => {
            // Expected: empty stream
        }
        Err(_) => {
            // Also acceptable: timeout
        }
    }
}

/// Test error handling for set_bpm when not running
#[test]
fn test_set_bpm_when_not_running() {
    let context = AppContext::new();

    // Try to set BPM without starting audio
    let result = context.set_bpm(140);

    #[cfg(not(target_os = "android"))]
    {
        // On non-Android, should fail with HardwareError
        assert!(result.is_err(), "set_bpm should fail on non-Android");
        match result.unwrap_err() {
            AudioError::HardwareError { details } => {
                assert!(
                    details.contains("only supported on Android"),
                    "Error should mention Android requirement"
                );
            }
            other => panic!("Expected HardwareError, got {:?}", other),
        }
    }

    #[cfg(target_os = "android")]
    {
        // On Android, should fail with NotRunning
        assert!(
            result.is_err(),
            "set_bpm should fail when audio not running"
        );
        match result.unwrap_err() {
            AudioError::NotRunning => {
                // Expected error
            }
            other => panic!("Expected NotRunning, got {:?}", other),
        }
    }
}

/// Test that BPM validation works in set_bpm
#[cfg(target_os = "android")]
#[test]
fn test_set_bpm_validation() {
    let context = AppContext::new();

    // Start audio first
    let start_result = context.start_audio(120);

    if start_result.is_ok() {
        // Test invalid BPM (0)
        let result = context.set_bpm(0);
        assert!(result.is_err(), "set_bpm should reject BPM = 0");
        match result.unwrap_err() {
            AudioError::BpmInvalid { bpm } => {
                assert_eq!(bpm, 0, "Error should report the invalid BPM value");
            }
            other => panic!("Expected BpmInvalid, got {:?}", other),
        }

        // Clean up
        let _ = context.stop_audio();
    }
}

/// Test concurrent access safety (multiple threads)
///
/// This test verifies that AppContext can be safely used from multiple threads
/// without panicking or deadlocking.
#[test]
fn test_concurrent_access() {
    use std::sync::Arc;
    use std::thread;

    let context = Arc::new(AppContext::new());
    let mut handles = vec![];

    // Spawn multiple threads that try to use the context
    for i in 0..5 {
        let context_clone = Arc::clone(&context);
        let handle = thread::spawn(move || {
            if i % 2 == 0 {
                // Even threads try to start/stop audio
                let _ = context_clone.start_audio(120);
                let _ = context_clone.stop_audio();
            } else {
                // Odd threads try to start/finish calibration
                let _ = context_clone.start_calibration();
                let _ = context_clone.finish_calibration();
            }
        });
        handles.push(handle);
    }

    // Wait for all threads to complete
    for handle in handles {
        handle.join().expect("Thread should not panic");
    }

    // If we got here, concurrent access is safe
}
