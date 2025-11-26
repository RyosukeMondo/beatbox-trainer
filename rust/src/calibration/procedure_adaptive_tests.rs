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

#[test]
fn test_backoff_restarts_when_noise_floor_changes() {
    let mut procedure = CalibrationProcedure::new_for_test(2);
    let features = create_test_features(1000.0, 0.05);
    let initial_gate = procedure
        .backoff
        .gate_state(CalibrationSound::Kick)
        .unwrap()
        .rms_gate;

    for _ in 0..BACKOFF_TRIGGER {
        let _ = procedure.add_sample(features, initial_gate * 0.1);
    }

    let before_update = procedure
        .backoff
        .gate_state(CalibrationSound::Kick)
        .unwrap();
    assert!(before_update.step > 0);

    procedure.backoff.update_noise_floor(Some(0.25));
    let after_update = procedure
        .backoff
        .gate_state(CalibrationSound::Kick)
        .unwrap();

    assert_eq!(after_update.step, 0);
    assert_eq!(after_update.rejects, 0);
    assert!(
        (after_update.rms_gate - 0.4).abs() < 1e-6,
        "RMS gate should restart from updated noise floor"
    );
}

#[test]
fn test_manual_accept_available_tracks_candidate_state() {
    let mut procedure = CalibrationProcedure::new_for_test(2);
    let features = create_test_features(1000.0, 0.05);

    assert!(!procedure.manual_accept_available());

    // Store candidate via rejection path
    assert!(procedure.add_sample(features, 0.001).is_err());
    assert!(procedure.manual_accept_available());

    procedure.clear_candidate_for_sound(CalibrationSound::Kick);
    assert!(!procedure.manual_accept_available());

    // Store and promote candidate, availability should reset
    assert!(procedure.add_sample(features, 0.001).is_err());
    let progress = procedure.manual_accept_last_candidate().unwrap();
    assert_eq!(progress.samples_collected, 1);
    assert!(!progress.waiting_for_confirmation);
    assert!(!procedure.manual_accept_available());

    // Completing the phase clears any remaining candidate state
    procedure.add_sample(features, 1.0).unwrap();
    assert!(procedure.is_waiting_for_confirmation());
    assert!(!procedure.manual_accept_available());
    procedure.confirm_and_advance().unwrap();
    assert_eq!(procedure.current_sound, CalibrationSound::Snare);
    assert!(!procedure.manual_accept_available());
}
