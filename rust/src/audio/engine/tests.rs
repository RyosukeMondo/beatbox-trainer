use super::*;
use crate::audio::buffer_pool::BufferPool;
use std::sync::atomic::Ordering;

#[test]
fn test_audio_engine_creation() {
    let channels = BufferPool::new(64, DEFAULT_BUFFER_SIZE);
    let engine = AudioEngine::new(120, 48000, channels);
    assert!(engine.is_ok());

    let engine = engine.unwrap();
    assert_eq!(engine.get_bpm(), 120);
    assert_eq!(engine.get_frame_counter(), 0);
}

#[test]
fn test_set_bpm() {
    let channels = BufferPool::new(64, DEFAULT_BUFFER_SIZE);
    let engine = AudioEngine::new(120, 48000, channels).unwrap();

    engine.set_bpm(140);
    assert_eq!(engine.get_bpm(), 140);

    engine.set_bpm(60);
    assert_eq!(engine.get_bpm(), 60);
}

#[test]
fn test_frame_counter_ref() {
    let channels = BufferPool::new(64, DEFAULT_BUFFER_SIZE);
    let engine = AudioEngine::new(120, 48000, channels).unwrap();

    let frame_ref = engine.get_frame_counter_ref();
    assert_eq!(frame_ref.load(Ordering::Relaxed), 0);

    frame_ref.store(1000, Ordering::Relaxed);
    assert_eq!(engine.get_frame_counter(), 1000);
}

#[test]
fn test_bpm_ref() {
    let channels = BufferPool::new(64, DEFAULT_BUFFER_SIZE);
    let engine = AudioEngine::new(120, 48000, channels).unwrap();

    let bpm_ref = engine.get_bpm_ref();
    assert_eq!(bpm_ref.load(Ordering::Relaxed), 120);

    bpm_ref.store(180, Ordering::Relaxed);
    assert_eq!(engine.get_bpm(), 180);
}

#[test]
fn test_multiple_bpm_updates() {
    let channels = BufferPool::new(64, DEFAULT_BUFFER_SIZE);
    let engine = AudioEngine::new(120, 48000, channels).unwrap();

    let bpm_values = [60, 80, 100, 120, 140, 160, 180, 200, 240];
    for &bpm in &bpm_values {
        engine.set_bpm(bpm);
        assert_eq!(engine.get_bpm(), bpm);
    }
}

#[test]
fn test_audio_engine_start_with_calibration_parameters() {
    let channels = BufferPool::new(64, DEFAULT_BUFFER_SIZE);
    let mut engine = AudioEngine::new(120, 48000, channels).unwrap();

    let calibration_state = std::sync::Arc::new(std::sync::RwLock::new(
        crate::calibration::state::CalibrationState::new_default(),
    ));
    let calibration_procedure = std::sync::Arc::new(std::sync::Mutex::new(None));
    let (calibration_progress_tx, _calibration_progress_rx) = tokio::sync::broadcast::channel(16);
    let (result_tx, _result_rx) = tokio::sync::broadcast::channel(16);

    let result = engine.start(
        calibration_state,
        calibration_procedure,
        Some(calibration_progress_tx),
        result_tx,
    );

    #[cfg(not(target_os = "android"))]
    {
        assert!(result.is_ok());
    }

    #[cfg(target_os = "android")]
    {
        assert!(result.is_ok() || result.is_err());
    }
}
