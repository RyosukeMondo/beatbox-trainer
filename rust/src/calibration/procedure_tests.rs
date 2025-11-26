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

    let result = procedure.add_sample(features, 0.05);
    assert!(result.is_ok());
    assert_eq!(procedure.kick_samples.len(), 1);
}

#[test]
fn test_add_sample_invalid_centroid_low() {
    // Use new_for_test which skips noise floor
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let features = create_test_features(30.0, 0.05); // Too low

    let result = procedure.add_sample(features, 0.05);
    assert!(result.is_err());
    match result.unwrap_err() {
        CalibrationError::InvalidFeatures { reason } => {
            assert!(reason.contains("Centroid") && reason.contains("30"));
        }
        _ => panic!("Expected InvalidFeatures error"),
    }
}

#[test]
fn test_add_sample_invalid_centroid_high() {
    // Use new_for_test which skips noise floor
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let features = create_test_features(25000.0, 0.05); // Too high

    let result = procedure.add_sample(features, 0.05);
    assert!(result.is_err());
    match result.unwrap_err() {
        CalibrationError::InvalidFeatures { reason } => {
            assert!(reason.contains("Centroid") && reason.contains("25000"));
        }
        _ => panic!("Expected InvalidFeatures error"),
    }
}

#[test]
fn test_add_sample_invalid_zcr_low() {
    // Use new_for_test which skips noise floor
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let features = create_test_features(1000.0, -0.1); // Too low

    let result = procedure.add_sample(features, 0.05);
    assert!(result.is_err());
    match result.unwrap_err() {
        CalibrationError::InvalidFeatures { reason } => {
            assert!(reason.contains("ZCR") && reason.contains("-0.1"));
        }
        _ => panic!("Expected InvalidFeatures error"),
    }
}

#[test]
fn test_add_sample_invalid_zcr_high() {
    // Use new_for_test which skips noise floor
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let features = create_test_features(1000.0, 1.5); // Too high

    let result = procedure.add_sample(features, 0.05);
    assert!(result.is_err());
    match result.unwrap_err() {
        CalibrationError::InvalidFeatures { reason } => {
            assert!(reason.contains("ZCR") && reason.contains("1.5"));
        }
        _ => panic!("Expected InvalidFeatures error"),
    }
}

#[test]
fn test_add_sample_confirmation_flow() {
    let mut procedure = CalibrationProcedure::new_for_test(10);
    let kick_features = create_test_features(1000.0, 0.05);

    // Add 10 kick samples
    for _ in 0..10 {
        procedure.add_sample(kick_features, 0.05).unwrap();
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
        procedure.add_sample(kick_features, 0.05).unwrap();
    }

    // Should be waiting for confirmation
    assert!(procedure.is_waiting_for_confirmation());
    procedure.confirm_and_advance().unwrap();
    assert_eq!(procedure.current_sound, CalibrationSound::Snare);

    // Add 10 snare samples
    for _ in 0..10 {
        procedure.add_sample(snare_features, 0.05).unwrap();
    }

    // Should be waiting for confirmation
    assert!(procedure.is_waiting_for_confirmation());
    procedure.confirm_and_advance().unwrap();
    assert_eq!(procedure.current_sound, CalibrationSound::HiHat);

    // Add 10 hi-hat samples
    for _ in 0..10 {
        procedure.add_sample(hihat_features, 0.05).unwrap();
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
        procedure.add_sample(features, 0.05).unwrap();
    }

    // Now waiting for confirmation - try to add another sample
    assert!(procedure.is_waiting_for_confirmation());
    let result = procedure.add_sample(features, 0.05);
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
        procedure.add_sample(features, 0.05).unwrap();
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
        procedure.add_sample(kick_features, 0.05).unwrap();
    }
    assert!(!procedure.is_complete());
    procedure.confirm_and_advance().unwrap();

    // Add snare samples and confirm
    for _ in 0..10 {
        procedure.add_sample(snare_features, 0.05).unwrap();
    }
    assert!(!procedure.is_complete());
    procedure.confirm_and_advance().unwrap();

    // Add hihat samples and confirm
    for _ in 0..10 {
        procedure.add_sample(hihat_features, 0.05).unwrap();
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
        procedure.add_sample(kick_features, 0.05).unwrap();
    }
    procedure.confirm_and_advance().unwrap();

    // Add 10 snare samples and confirm
    for _ in 0..10 {
        procedure.add_sample(snare_features, 0.05).unwrap();
    }
    procedure.confirm_and_advance().unwrap();

    // Add 10 hi-hat samples and confirm
    for _ in 0..10 {
        procedure.add_sample(hihat_features, 0.05).unwrap();
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
        procedure.add_sample(features, 0.05).unwrap();
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
        procedure.add_sample(features, 0.05).unwrap();
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
        procedure.add_sample(features, 0.05).unwrap();
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
        procedure.add_sample(features, 0.05).unwrap();
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
    procedure.add_sample(features, 0.05).unwrap();
    assert_eq!(procedure.kick_samples.len(), 1);
}

#[test]
fn test_backoff_relaxes_and_resets_on_success() {
    let mut procedure = CalibrationProcedure::new_for_test(3);
    let features = create_test_features(1000.0, 0.05);
    let base_gate = procedure
        .backoff
        .gate_state(CalibrationSound::Kick)
        .unwrap()
        .rms_gate;

    for _ in 0..BACKOFF_TRIGGER {
        assert!(procedure.add_sample(features, base_gate * 0.5).is_err());
    }

    let state = procedure
        .backoff
        .gate_state(CalibrationSound::Kick)
        .unwrap();
    assert!(state.step >= 1);
    assert!(state.rms_gate < base_gate);

    procedure.add_sample(features, base_gate * 2.0).unwrap();
    let state = procedure
        .backoff
        .gate_state(CalibrationSound::Kick)
        .unwrap();
    assert_eq!(state.step, 0);
    assert_eq!(state.rejects, 0);
    assert!((state.rms_gate - base_gate).abs() < 1e-6);
}

#[test]
fn test_backoff_respects_rms_floor() {
    let mut procedure = CalibrationProcedure::new_for_test(3);
    let features = create_test_features(1000.0, 0.05);
    let floor = procedure.backoff.gate_floor();

    for _ in 0..(BACKOFF_TRIGGER as usize * (MAX_BACKOFF_STEPS as usize + 2)) {
        let _ = procedure.add_sample(features, 0.0001);
    }

    let state = procedure
        .backoff
        .gate_state(CalibrationSound::Kick)
        .unwrap();
    assert!(state.rms_gate >= floor - 1e-6);
    assert_eq!(state.step, MAX_BACKOFF_STEPS);
}
