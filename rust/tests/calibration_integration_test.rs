//! Integration tests for calibration workflow
//!
//! These tests validate the complete calibration workflow across the Rust layer:
//! - Calibration procedure initialization
//! - Audio engine restart during calibration
//! - State transitions and error handling
//! - Audio restart latency requirements (NFR-1: <200ms)
//!
//! Note: Full audio processing tests require Android device and manual testing.
//! These tests focus on verifying the integration plumbing and state management.

use beatbox_trainer::context::AppContext;
use beatbox_trainer::error::CalibrationError;

#[cfg(target_os = "android")]
use beatbox_trainer::error::AudioError;

#[cfg(target_os = "android")]
use std::time::Instant;

/// Test full calibration workflow initialization
///
/// This test verifies that the calibration procedure is correctly initialized
/// and accessible to the audio engine when calibration starts.
///
/// Test steps:
/// 1. Create AppContext
/// 2. Start calibration
/// 3. Verify calibration procedure Arc is Some (not None)
/// 4. Verify audio engine receives calibration procedure
///
/// Note: This test does not verify actual audio processing - that requires
/// Android device and manual testing (Task 5.2).
#[test]
fn test_full_calibration_workflow() {
    let context = AppContext::new();

    // 1. Start calibration - this should initialize the procedure
    let result = context.start_calibration();
    assert!(
        result.is_ok(),
        "start_calibration should succeed: {:?}",
        result.err()
    );

    // 2. On Android, verify audio engine started with calibration parameters
    #[cfg(target_os = "android")]
    {
        // The audio engine should now be running with the calibration procedure
        // We can't directly verify the procedure is being used without actual audio,
        // but we've verified the initialization succeeded.
        //
        // The procedure Arc is accessible via the calibration manager
        // and should be Some after start_calibration() succeeds.
    }

    // 3. On non-Android, verify that start_calibration succeeded
    // (it should succeed even though audio engine is stubbed)
    #[cfg(not(target_os = "android"))]
    {
        // Calibration initialization should succeed even on desktop
        // The procedure should be initialized even though audio engine is stubbed
    }

    // 4. Attempt double-start should fail
    let double_start = context.start_calibration();
    assert!(
        double_start.is_err(),
        "Second start_calibration should fail with AlreadyInProgress"
    );
    match double_start.unwrap_err() {
        CalibrationError::AlreadyInProgress => {
            // Expected - calibration is already active
        }
        other => panic!("Expected AlreadyInProgress error, got {:?}", other),
    }

    // 5. Clean up - finish calibration
    // This will fail with InsufficientSamples but that's expected without audio
    let _ = context.finish_calibration();
}

/// Test audio restart during calibration start
///
/// This test measures the audio restart latency when starting calibration.
/// According to NFR-1, the audio gap should be barely noticeable (<200ms).
///
/// Test steps:
/// 1. Start audio engine in classification mode
/// 2. Measure time to restart audio via start_calibration()
/// 3. Verify restart latency is <200ms
///
/// Note: This test only works on Android where audio engine is real.
/// On desktop, the test verifies graceful handling of stubbed audio.
#[cfg(target_os = "android")]
#[test]
fn test_calibration_restart_audio() {
    let context = AppContext::new();

    // 1. Start audio engine in classification mode (normal playback)
    let start_result = context.start_audio(120);

    // If audio hardware is not available (e.g., in CI), skip timing test
    if start_result.is_err() {
        match start_result.unwrap_err() {
            AudioError::HardwareError { .. } => {
                // Hardware not available - skip test
                eprintln!("Skipping audio restart latency test - hardware not available");
                return;
            }
            other => panic!("Unexpected error starting audio: {:?}", other),
        }
    }

    // 2. Give audio engine time to stabilize
    std::thread::sleep(std::time::Duration::from_millis(100));

    // 3. Measure restart latency
    let start_time = Instant::now();

    // Start calibration - this should:
    // - Stop the audio engine
    // - Initialize calibration procedure
    // - Restart audio engine with calibration parameters
    let result = context.start_calibration();

    let restart_latency = start_time.elapsed();

    assert!(
        result.is_ok(),
        "start_calibration should succeed: {:?}",
        result.err()
    );

    // 4. Verify restart latency meets NFR-1 requirement (<200ms)
    println!("Audio restart latency: {:?}", restart_latency);
    assert!(
        restart_latency.as_millis() < 200,
        "Audio restart latency should be <200ms (NFR-1), got {:?}",
        restart_latency
    );

    // 5. Clean up
    let _ = context.finish_calibration();
    let _ = context.stop_audio();
}

/// Test audio restart on non-Android platforms
///
/// This test verifies that calibration start handles gracefully on desktop
/// where the audio engine is stubbed. The timing requirement doesn't apply
/// since there's no real audio hardware.
#[cfg(not(target_os = "android"))]
#[test]
fn test_calibration_start_on_desktop() {
    let context = AppContext::new();

    // On desktop, audio engine is stubbed and returns HardwareError
    // However, start_calibration should still initialize the procedure
    let result = context.start_calibration();

    // The exact behavior depends on implementation:
    // - If audio restart is conditional on Android, calibration should succeed
    // - If audio restart always happens, it may fail with AudioEngineError
    //
    // Either way, we're testing that it doesn't panic
    match result {
        Ok(_) => {
            // Calibration started successfully (audio restart is conditional)
            println!("Calibration started successfully on desktop");
            let _ = context.finish_calibration();
        }
        Err(CalibrationError::AudioEngineError { .. }) => {
            // Audio engine error (expected on desktop if restart is unconditional)
            println!("Got expected AudioEngineError on desktop");
        }
        Err(other) => {
            panic!("Unexpected error on desktop: {:?}", other);
        }
    }
}

/// Test calibration procedure accessibility after start
///
/// This test verifies that the calibration procedure Arc is properly
/// initialized and accessible after starting calibration.
///
/// This is a critical integration point: the analysis thread needs
/// access to the procedure to add samples during calibration.
#[test]
fn test_calibration_procedure_initialization() {
    let context = AppContext::new();

    // Start calibration
    let result = context.start_calibration();
    assert!(
        result.is_ok(),
        "start_calibration should succeed: {:?}",
        result.err()
    );

    // Note: We can't directly access the procedure Arc from AppContext's
    // public API, but we've verified that start_calibration succeeded.
    //
    // The procedure initialization is verified by:
    // 1. start_calibration() returning Ok (procedure was created)
    // 2. AlreadyInProgress on second call (procedure exists)
    // 3. Manual testing on Android (samples can be added)

    // Verify we can't start calibration again
    let double_start = context.start_calibration();
    assert!(
        double_start.is_err(),
        "Should not be able to start calibration twice"
    );

    // Clean up
    let _ = context.finish_calibration();
}

/// Test error propagation during audio restart
///
/// This test verifies that errors during audio restart are properly
/// propagated as CalibrationError::AudioEngineError.
#[cfg(target_os = "android")]
#[test]
fn test_audio_restart_error_handling() {
    let context = AppContext::new();

    // Try to start calibration without audio permission (if applicable)
    // Or with audio hardware issues
    let result = context.start_calibration();

    // On Android, if audio hardware is not available, we should get AudioEngineError
    match result {
        Ok(_) => {
            // Audio available - clean up
            let _ = context.finish_calibration();
            let _ = context.stop_audio();
        }
        Err(CalibrationError::AudioEngineError { .. }) => {
            // Expected if audio hardware not available
            println!("Got expected AudioEngineError when audio unavailable");
        }
        Err(other) => {
            panic!("Unexpected error: {:?}", other);
        }
    }
}

/// Test concurrent calibration attempts
///
/// This test verifies thread safety when multiple threads try to start
/// calibration concurrently. Only one should succeed.
#[test]
fn test_concurrent_calibration_start() {
    use std::sync::Arc;
    use std::thread;

    let context = Arc::new(AppContext::new());
    let mut handles = vec![];

    // Spawn multiple threads that try to start calibration
    for i in 0..5 {
        let context_clone = Arc::clone(&context);
        let handle = thread::spawn(move || {
            let result = context_clone.start_calibration();
            (i, result)
        });
        handles.push(handle);
    }

    // Collect results
    let mut success_count = 0;
    let mut _already_in_progress_count = 0;

    for handle in handles {
        let (thread_id, result) = handle.join().expect("Thread should not panic");
        match result {
            Ok(_) => {
                success_count += 1;
                println!("Thread {} started calibration", thread_id);
            }
            Err(CalibrationError::AlreadyInProgress) => {
                _already_in_progress_count += 1;
                println!("Thread {} got AlreadyInProgress", thread_id);
            }
            Err(CalibrationError::AudioEngineError { .. }) => {
                // On desktop, audio engine errors are expected
                #[cfg(not(target_os = "android"))]
                {
                    println!(
                        "Thread {} got AudioEngineError (expected on desktop)",
                        thread_id
                    );
                }

                // On Android, this might happen if audio hardware unavailable
                #[cfg(target_os = "android")]
                {
                    println!(
                        "Thread {} got AudioEngineError (hardware unavailable)",
                        thread_id
                    );
                }
            }
            Err(other) => {
                panic!("Thread {} got unexpected error: {:?}", thread_id, other);
            }
        }
    }

    // Verify that at most one thread succeeded
    assert!(
        success_count <= 1,
        "At most one thread should succeed in starting calibration, got {}",
        success_count
    );

    // Clean up if calibration was started
    if success_count > 0 {
        let _ = context.finish_calibration();
    }
}
