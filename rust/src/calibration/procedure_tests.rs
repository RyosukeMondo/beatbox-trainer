use super::*;

/// Helper function to create valid test features
fn create_test_features(centroid: f32, zcr: f32) -> Features {
    Features {
        centroid,
        zcr,
        flatness: 0.5,
        rolloff: 5000.0,
        decay_time_ms: 50.0,
    }
}

#[test]
fn test_new_default() {
    let procedure = CalibrationProcedure::new_default();
    // new_default() now starts with NoiseFloor phase
    assert_eq!(procedure.current_sound, CalibrationSound::NoiseFloor);
    assert_eq!(procedure.samples_needed, 10);
    assert_eq!(procedure.kick_samples.len(), 0);
    assert!(procedure.noise_floor_threshold.is_none());
}

#[test]
fn test_add_sample_valid() {
    // Use new_for_test which skips noise floor
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let features = create_test_features(1000.0, 0.05);

    let result = procedure.add_sample(features, 0.05, 0.0);
    assert!(result.is_ok());
    assert_eq!(procedure.kick_samples.len(), 1);
}

// USER-CENTRIC CALIBRATION: We now accept most sounds and learn from them
// Only reject truly invalid signals (hardware glitches, below noise floor)

#[test]
fn test_add_sample_low_centroid_accepted() {
    // Low centroid is now accepted - user might have a unique kick style
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let features = create_test_features(30.0, 0.05);

    let result = procedure.add_sample(features, 0.05, 0.0);
    assert!(
        result.is_ok(),
        "Low centroid should be accepted in user-centric calibration"
    );
    assert_eq!(procedure.kick_samples.len(), 1);
}

#[test]
fn test_add_sample_invalid_centroid_hardware_glitch() {
    // Only reject truly invalid frequencies (hardware glitches > 20kHz)
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let features = create_test_features(25000.0, 0.05); // > 20kHz = hardware glitch

    let result = procedure.add_sample(features, 0.05, 0.0);
    assert!(result.is_err());
    match result.unwrap_err() {
        CalibrationError::InvalidFeatures { reason } => {
            assert!(reason.contains("Invalid frequency"));
        }
        _ => panic!("Expected InvalidFeatures error"),
    }
}

#[test]
fn test_add_sample_zcr_variants_accepted() {
    // ZCR variants are now accepted - we learn from user's sounds
    let mut procedure = CalibrationProcedure::new_for_test(10);

    // Low ZCR accepted
    let low_zcr = create_test_features(1000.0, 0.01);
    assert!(procedure.add_sample(low_zcr, 0.05, 0.0).is_ok());

    // High ZCR accepted
    let high_zcr = create_test_features(1000.0, 0.9);
    assert!(procedure.add_sample(high_zcr, 0.05, 0.0).is_ok());

    assert_eq!(procedure.kick_samples.len(), 2);
}

#[test]
fn test_add_sample_below_noise_floor_rejected() {
    // Sounds below noise floor should be rejected
    let mut procedure = CalibrationProcedure::new_for_test(10);
    // new_for_test sets noise_floor_threshold to MIN_RMS_THRESHOLD (0.0025)
    let features = create_test_features(1000.0, 0.05);

    // RMS 0.001 is below noise floor 0.0025
    let result = procedure.add_sample(features, 0.001, 0.0);
    assert!(result.is_err());
    match result.unwrap_err() {
        CalibrationError::InvalidFeatures { reason } => {
            assert!(reason.contains("too quiet") || reason.contains("noise floor"));
        }
        _ => panic!("Expected InvalidFeatures error for below noise floor"),
    }
}

#[test]
fn test_add_sample_confirmation_flow() {
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let kick_features = create_test_features(1000.0, 0.05);

    // Add 10 kick samples
    for _ in 0..10 {
        procedure.add_sample(kick_features, 0.05, 0.2).unwrap();
    }

    // Should be waiting for confirmation now
    assert!(procedure.is_waiting_for_confirmation());
    assert_eq!(procedure.current_sound, CalibrationSound::Kick);
    assert_eq!(procedure.kick_samples.len(), 10);

    // User confirms OK - advance to snare
    procedure.confirm_and_advance().unwrap();
    assert_eq!(procedure.current_sound, CalibrationSound::Snare);
    assert!(!procedure.is_waiting_for_confirmation());
}

#[test]
fn test_add_sample_full_workflow() {
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let kick_features = create_test_features(1000.0, 0.05);
    let snare_features = create_test_features(3000.0, 0.15);
    let hihat_features = create_test_features(8000.0, 0.5);

    // Add 10 kick samples
    assert_eq!(procedure.current_sound, CalibrationSound::Kick);
    for _ in 0..10 {
        procedure.add_sample(kick_features, 0.05, 0.2).unwrap();
    }

    // Should be waiting for confirmation
    assert!(procedure.is_waiting_for_confirmation());
    procedure.confirm_and_advance().unwrap();
    assert_eq!(procedure.current_sound, CalibrationSound::Snare);

    // Add 10 snare samples
    for _ in 0..10 {
        procedure.add_sample(snare_features, 0.05, 0.2).unwrap();
    }

    // Should be waiting for confirmation
    assert!(procedure.is_waiting_for_confirmation());
    procedure.confirm_and_advance().unwrap();
    assert_eq!(procedure.current_sound, CalibrationSound::HiHat);

    // Add 10 hi-hat samples
    for _ in 0..10 {
        procedure.add_sample(hihat_features, 0.05, 0.2).unwrap();
    }

    // Should be waiting for final confirmation
    assert!(procedure.is_waiting_for_confirmation());
    let complete = procedure.confirm_and_advance().unwrap();
    assert!(!complete); // false = calibration complete (no next sound)
    assert_eq!(procedure.current_sound, CalibrationSound::HiHat);
    assert!(procedure.is_complete());
}

#[test]
fn test_add_sample_reject_when_waiting() {
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let features = create_test_features(1000.0, 0.05);

    // Fill up kick samples
    for _ in 0..10 {
        procedure.add_sample(features, 0.05, 0.0).unwrap();
    }

    // Now waiting for confirmation - try to add another sample
    assert!(procedure.is_waiting_for_confirmation());
    let result = procedure.add_sample(features, 0.05, 0.0);
    assert!(result.is_err());
    assert!(matches!(
        result.unwrap_err(),
        CalibrationError::InvalidFeatures { .. }
    ));
}

#[test]
fn test_get_progress() {
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let features = create_test_features(1000.0, 0.05);

    // Initial progress
    let progress = procedure.get_progress();
    assert_eq!(progress.current_sound, CalibrationSound::Kick);
    assert_eq!(progress.samples_collected, 0);
    assert_eq!(progress.samples_needed, 10);

    // Add 5 samples
    for _ in 0..5 {
        procedure.add_sample(features, 0.05, 0.0).unwrap();
    }

    let progress = procedure.get_progress();
    assert_eq!(progress.samples_collected, 5);
    assert!(!progress.is_sound_complete());
}

#[test]
fn test_is_complete() {
    let mut procedure = CalibrationProcedure::new_for_test(10);
    assert!(!procedure.is_complete());

    let kick_features = create_test_features(1000.0, 0.05);
    let snare_features = create_test_features(3000.0, 0.15);
    let hihat_features = create_test_features(8000.0, 0.5);

    // Add kick samples and confirm
    for _ in 0..10 {
        procedure.add_sample(kick_features, 0.05, 0.2).unwrap();
    }
    assert!(!procedure.is_complete());
    procedure.confirm_and_advance().unwrap();

    // Add snare samples and confirm
    for _ in 0..10 {
        procedure.add_sample(snare_features, 0.05, 0.2).unwrap();
    }
    assert!(!procedure.is_complete());
    procedure.confirm_and_advance().unwrap();

    // Add hihat samples and confirm
    for _ in 0..10 {
        procedure.add_sample(hihat_features, 0.05, 0.2).unwrap();
    }
    procedure.confirm_and_advance().unwrap();
    assert!(procedure.is_complete());
}

#[test]
fn test_finalize_success() {
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let kick_features = create_test_features(1000.0, 0.05);
    let snare_features = create_test_features(3000.0, 0.15);
    let hihat_features = create_test_features(8000.0, 0.5);

    // Add 10 kick samples and confirm
    for _ in 0..10 {
        procedure.add_sample(kick_features, 0.05, 0.2).unwrap();
    }
    procedure.confirm_and_advance().unwrap();

    // Add 10 snare samples and confirm
    for _ in 0..10 {
        procedure.add_sample(snare_features, 0.05, 0.2).unwrap();
    }
    procedure.confirm_and_advance().unwrap();

    // Add 10 hi-hat samples and confirm
    for _ in 0..10 {
        procedure.add_sample(hihat_features, 0.05, 0.2).unwrap();
    }
    procedure.confirm_and_advance().unwrap();

    let result = procedure.finalize();
    assert!(result.is_ok());

    let state = result.unwrap();
    // Use floating point tolerance
    assert!((state.t_kick_centroid - 1000.0 * 1.2).abs() < 0.01);
    assert!((state.t_kick_zcr - 0.05 * 1.2).abs() < 0.0001);
    assert!((state.t_snare_centroid - 3000.0 * 1.2).abs() < 0.01);
    assert!((state.t_hihat_zcr - 0.5 * 1.2).abs() < 0.0001);
    assert!(state.is_calibrated);
}

#[test]
fn test_finalize_incomplete() {
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let features = create_test_features(1000.0, 0.05);

    // Add only 5 kick samples
    for _ in 0..5 {
        procedure.add_sample(features, 0.05, 0.0).unwrap();
    }

    let result = procedure.finalize();
    assert!(result.is_err());
    assert!(matches!(
        result.unwrap_err(),
        CalibrationError::InsufficientSamples { .. }
    ));
}

#[test]
fn test_reset() {
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let features = create_test_features(1000.0, 0.05);

    // Add some samples
    for _ in 0..5 {
        procedure.add_sample(features, 0.05, 0.0).unwrap();
    }

    // Reset
    procedure.reset();

    // After reset, procedure goes back to NoiseFloor phase
    assert_eq!(procedure.current_sound, CalibrationSound::NoiseFloor);
    assert_eq!(procedure.kick_samples.len(), 0);
    assert_eq!(procedure.snare_samples.len(), 0);
    assert_eq!(procedure.hihat_samples.len(), 0);
    assert!(procedure.noise_floor_threshold.is_none());
    assert!(!procedure.is_complete());
}

#[test]
fn test_custom_sample_count() {
    let mut procedure = CalibrationProcedure::new_for_test(5); // 5 samples per sound, no debounce
    let features = create_test_features(1000.0, 0.05);

    // Add 5 kick samples
    for _ in 0..5 {
        procedure.add_sample(features, 0.05, 0.0).unwrap();
    }

    // Should be waiting for confirmation
    assert!(procedure.is_waiting_for_confirmation());
    assert_eq!(procedure.current_sound, CalibrationSound::Kick);

    // Confirm to advance to snare
    procedure.confirm_and_advance().unwrap();
    assert_eq!(procedure.current_sound, CalibrationSound::Snare);

    let progress = procedure.get_progress();
    assert_eq!(progress.samples_needed, 5);
}

#[test]
fn test_retry_current_sound() {
    let mut procedure = CalibrationProcedure::new_for_test(5);
    let features = create_test_features(1000.0, 0.05);

    // Add 5 kick samples
    for _ in 0..5 {
        procedure.add_sample(features, 0.05, 0.0).unwrap();
    }

    // Should be waiting for confirmation
    assert!(procedure.is_waiting_for_confirmation());
    assert_eq!(procedure.kick_samples.len(), 5);

    // User wants to retry
    procedure.retry_current_sound().unwrap();

    // Should clear samples and allow re-collection
    assert!(!procedure.is_waiting_for_confirmation());
    assert_eq!(procedure.kick_samples.len(), 0);
    assert_eq!(procedure.current_sound, CalibrationSound::Kick);

    // Can add samples again
    procedure.add_sample(features, 0.05, 0.0).unwrap();
    assert_eq!(procedure.kick_samples.len(), 1);
}

// NOTE: Adaptive backoff tests removed - user-centric calibration accepts all sounds
// above noise floor. The backoff module is kept for potential future use but not
// actively used in sample validation.

#[test]
fn test_noise_floor_rejection_threshold() {
    // Test that we properly reject sounds below noise floor
    let mut procedure = CalibrationProcedure::new_for_test(3);
    let features = create_test_features(1000.0, 0.05);

    // new_for_test sets noise_floor_threshold to MIN_RMS_THRESHOLD (0.0025)
    // Sounds above threshold should be accepted
    assert!(procedure.add_sample(features, 0.01, 0.2).is_ok());
    assert_eq!(procedure.kick_samples.len(), 1);

    // Sounds below threshold should be rejected (0.001 < 0.0025)
    assert!(procedure.add_sample(features, 0.001, 0.1).is_err());
    assert_eq!(procedure.kick_samples.len(), 1); // Still 1, rejected sample not added
}

#[test]
fn test_manual_accept_uses_last_candidate() {
    let mut procedure = CalibrationProcedure::new_for_test(2);
    let features = create_test_features(1000.0, 0.05);

    // Store candidate via noise floor rejection (RMS below threshold)
    // new_for_test sets noise_floor_threshold to MIN_RMS_THRESHOLD (0.0025)
    let result = procedure.add_sample(features, 0.001, 0.0);
    assert!(result.is_err());

    let progress = procedure.manual_accept_last_candidate().unwrap();
    assert_eq!(progress.samples_collected, 1);
    assert_eq!(progress.current_sound, CalibrationSound::Kick);
    assert!(!progress.waiting_for_confirmation);

    // Candidate should be cleared after manual accept
    assert!(procedure.manual_accept_last_candidate().is_err());

    // Accept final sample to reach confirmation state
    procedure.add_sample(features, 1.0, 1.0).unwrap();
    assert!(procedure.is_waiting_for_confirmation());
}

#[test]
fn test_manual_accept_errors_without_candidate_or_when_complete() {
    let mut procedure = CalibrationProcedure::new_for_test(1);
    let features = create_test_features(1000.0, 0.05);

    // No candidate yet
    let err = procedure.manual_accept_last_candidate().unwrap_err();
    match err {
        CalibrationError::InvalidFeatures { reason } => {
            assert!(reason.contains("No candidate"));
        }
        _ => panic!("Expected InvalidFeatures error"),
    }

    // Move to waiting state then manual accept should fail
    procedure.add_sample(features, 1.0, 1.0).unwrap();
    assert!(procedure.is_waiting_for_confirmation());
    let err = procedure.manual_accept_last_candidate().unwrap_err();
    match err {
        CalibrationError::InvalidFeatures { reason } => {
            assert!(reason.contains("Current sound already complete"));
        }
        _ => panic!("Expected InvalidFeatures error"),
    }
}

#[test]
fn test_candidates_cleared_on_confirm_and_retry() {
    let mut procedure = CalibrationProcedure::new_for_test(1);
    let features = create_test_features(1000.0, 0.05);

    // Simulate stored candidate then confirm
    procedure
        .last_candidates
        .store(CalibrationSound::Kick, features);
    procedure.waiting_for_confirmation = true;
    procedure.confirm_and_advance().unwrap();
    assert!(procedure.last_candidates.kick.is_none());
    assert!(procedure.last_candidates.snare.is_none());

    // Store candidate for snare and ensure retry clears it
    procedure.waiting_for_confirmation = true;
    procedure.current_sound = CalibrationSound::Snare;
    procedure
        .last_candidates
        .store(CalibrationSound::Snare, features);
    procedure.retry_current_sound().unwrap();
    assert!(procedure.last_candidates.snare.is_none());
}

/// Test that noise_floor_rms is correctly preserved through finalize
#[test]
fn test_finalize_preserves_noise_floor_rms() {
    // Use new_default to start from NoiseFloor phase (NOT new_for_test which skips it)
    let mut procedure = CalibrationProcedure::with_debounce(10, 0); // 10 samples, no debounce

    // Collect 30 noise floor samples with known RMS values
    let noise_rms = 0.005; // Simulated ambient noise level
    for _ in 0..30 {
        let result = procedure.add_noise_floor_sample(noise_rms);
        assert!(result.is_ok());
    }

    // Noise floor should now be complete and threshold set
    assert!(procedure.noise_floor_threshold.is_some());
    let expected_threshold = noise_rms * 1.3; // max(mean*1.2, max*1.3, MIN) = max(0.006, 0.0065, 0.0025)
    let actual_threshold = procedure.noise_floor_threshold.unwrap();
    eprintln!(
        "Expected threshold: {}, Actual threshold: {}",
        expected_threshold, actual_threshold
    );
    // The threshold should be >= MIN_RMS_THRESHOLD and based on the noise samples
    assert!(
        actual_threshold >= 0.0025,
        "Threshold should be >= MIN_RMS_THRESHOLD"
    );
    assert!(
        actual_threshold < 0.02,
        "Threshold should be reasonable for low noise"
    );

    // Confirm noise floor to advance to Kick
    assert!(procedure.is_waiting_for_confirmation());
    procedure.confirm_and_advance().unwrap();
    assert_eq!(procedure.current_sound, CalibrationSound::Kick);

    // The noise_floor_threshold should still be set!
    assert!(
        procedure.noise_floor_threshold.is_some(),
        "noise_floor_threshold should persist after advancing to Kick"
    );

    // Complete the rest of calibration
    let kick_features = create_test_features(1000.0, 0.05);
    let snare_features = create_test_features(3000.0, 0.15);
    let hihat_features = create_test_features(8000.0, 0.5);

    // Add kick samples
    for _ in 0..10 {
        procedure.add_sample(kick_features, 0.05, 0.2).unwrap();
    }
    procedure.confirm_and_advance().unwrap();

    // Add snare samples
    for _ in 0..10 {
        procedure.add_sample(snare_features, 0.05, 0.2).unwrap();
    }
    procedure.confirm_and_advance().unwrap();

    // Add hi-hat samples
    for _ in 0..10 {
        procedure.add_sample(hihat_features, 0.05, 0.2).unwrap();
    }
    procedure.confirm_and_advance().unwrap();

    // Verify noise_floor_threshold is STILL set before finalize
    assert!(
        procedure.noise_floor_threshold.is_some(),
        "noise_floor_threshold should persist through all calibration phases"
    );
    let threshold_before_finalize = procedure.noise_floor_threshold.unwrap();
    eprintln!("Threshold before finalize: {}", threshold_before_finalize);

    // Finalize and check the result
    let result = procedure.finalize();
    assert!(result.is_ok(), "finalize should succeed");

    let state = result.unwrap();
    eprintln!("Final state.noise_floor_rms: {}", state.noise_floor_rms);

    // THIS IS THE KEY ASSERTION - noise_floor_rms should match the calibrated threshold
    assert!(
        (state.noise_floor_rms - threshold_before_finalize).abs() < 0.0001,
        "noise_floor_rms ({}) should match calibrated threshold ({})",
        state.noise_floor_rms,
        threshold_before_finalize
    );

    // Should NOT be the default value
    assert!(
        state.noise_floor_rms != 0.01,
        "noise_floor_rms should NOT be the default 0.01"
    );
}
