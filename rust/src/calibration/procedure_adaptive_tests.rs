use super::*;

fn create_test_features(centroid: f32, zcr: f32) -> Features {
    Features {
        centroid,
        zcr,
        flatness: 0.5,
        rolloff: 5000.0,
        decay_time_ms: 50.0,
    }
}

// NOTE: Backoff restart test removed - user-centric calibration no longer uses
// adaptive backoff during sample collection. All sounds above noise floor are accepted.

#[test]
fn test_user_centric_calibration_accepts_varied_sounds() {
    // User-centric calibration should accept sounds with varied features
    // as long as they're above the noise floor
    let mut procedure = CalibrationProcedure::new_for_test(5);

    // Different "kick" sounds from a user - all should be accepted
    let kick1 = create_test_features(200.0, 0.02); // Deep kick
    let kick2 = create_test_features(400.0, 0.05); // Mid kick
    let kick3 = create_test_features(150.0, 0.03); // Very deep kick
    let kick4 = create_test_features(600.0, 0.08); // Punchy kick
    let kick5 = create_test_features(300.0, 0.04); // Normal kick

    // All should be accepted (RMS 0.05 is above noise floor 0.01)
    assert!(procedure.add_sample(kick1, 0.05, 0.3).is_ok());
    assert!(procedure.add_sample(kick2, 0.06, 0.4).is_ok());
    assert!(procedure.add_sample(kick3, 0.04, 0.25).is_ok());
    assert!(procedure.add_sample(kick4, 0.07, 0.5).is_ok());
    assert!(procedure.add_sample(kick5, 0.05, 0.35).is_ok());

    assert_eq!(procedure.kick_samples.len(), 5);
    assert!(procedure.is_waiting_for_confirmation());
}

#[test]
fn test_manual_accept_available_tracks_candidate_state() {
    let mut procedure = CalibrationProcedure::new_for_test(2);
    let features = create_test_features(1000.0, 0.05);

    assert!(!procedure.manual_accept_available());

    // Store candidate via noise floor rejection (below threshold)
    // new_for_test sets noise_floor_threshold to MIN_RMS_THRESHOLD (0.0025)
    assert!(procedure.add_sample(features, 0.001, 0.0).is_err());
    assert!(procedure.manual_accept_available());

    procedure.clear_candidate_for_sound(CalibrationSound::Kick);
    assert!(!procedure.manual_accept_available());

    // Store and promote candidate, availability should reset
    assert!(procedure.add_sample(features, 0.001, 0.0).is_err());
    let progress = procedure.manual_accept_last_candidate().unwrap();
    assert_eq!(progress.samples_collected, 1);
    assert!(!progress.waiting_for_confirmation);
    assert!(!procedure.manual_accept_available());

    // Completing the phase clears any remaining candidate state
    procedure.add_sample(features, 1.0, 1.0).unwrap();
    assert!(procedure.is_waiting_for_confirmation());
    assert!(!procedure.manual_accept_available());
    procedure.confirm_and_advance().unwrap();
    assert_eq!(procedure.current_sound, CalibrationSound::Snare);
    assert!(!procedure.manual_accept_available());
}
