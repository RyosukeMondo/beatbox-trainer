use super::*;
use crate::audio::buffer_pool::BufferPool;
use crate::calibration::procedure::CalibrationProcedure;
use crate::calibration::state::CalibrationState;
use std::sync::atomic::{AtomicU32, AtomicU64};
use std::sync::{Arc, Mutex, RwLock};
use std::thread;
use std::time::Duration;
use tokio::sync::broadcast;

#[test]
fn test_calibration_mode_thread_spawns_with_procedure() {
    let channels = BufferPool::new(8, 2048);
    let (_audio_tx, analysis_rx) = channels.split_for_threads();

    let procedure = CalibrationProcedure::new(10);
    let calibration_procedure = Arc::new(Mutex::new(Some(procedure)));
    let calibration_state = Arc::new(RwLock::new(CalibrationState::new_default()));
    let (progress_tx, _progress_rx) = broadcast::channel(100);
    let (result_tx, _result_rx) = broadcast::channel(100);
    let frame_counter = Arc::new(AtomicU64::new(0));
    let bpm = Arc::new(AtomicU32::new(120));

    let analysis_thread = spawn_analysis_thread(
        analysis_rx,
        calibration_state,
        calibration_procedure,
        Some(progress_tx),
        frame_counter,
        bpm,
        48000,
        result_tx,
        OnsetDetectionConfig::default(),
        100,
        None,
    );

    thread::sleep(Duration::from_millis(50));
    assert!(!analysis_thread.is_finished());
}

#[test]
fn test_classification_mode_thread_spawns_without_procedure() {
    let channels = BufferPool::new(8, 2048);
    let (_audio_tx, analysis_rx) = channels.split_for_threads();

    let calibration_procedure = Arc::new(Mutex::new(None));
    let calibration_state = Arc::new(RwLock::new(CalibrationState::new_default()));
    let (progress_tx, _progress_rx) = broadcast::channel(100);
    let (result_tx, _result_rx) = broadcast::channel(100);
    let frame_counter = Arc::new(AtomicU64::new(0));
    let bpm = Arc::new(AtomicU32::new(120));

    let analysis_thread = spawn_analysis_thread(
        analysis_rx,
        calibration_state,
        calibration_procedure,
        Some(progress_tx),
        frame_counter,
        bpm,
        48000,
        result_tx,
        OnsetDetectionConfig::default(),
        100,
        None,
    );

    thread::sleep(Duration::from_millis(50));
    assert!(!analysis_thread.is_finished());
}

#[test]
fn test_thread_handles_calibration_procedure_gracefully() {
    let channels = BufferPool::new(8, 2048);
    let (_audio_tx, analysis_rx) = channels.split_for_threads();

    let procedure = CalibrationProcedure::new(10);
    let calibration_procedure = Arc::new(Mutex::new(Some(procedure)));
    let calibration_state = Arc::new(RwLock::new(CalibrationState::new_default()));
    let (progress_tx, _progress_rx) = broadcast::channel(100);
    let (result_tx, _result_rx) = broadcast::channel(100);
    let frame_counter = Arc::new(AtomicU64::new(0));
    let bpm = Arc::new(AtomicU32::new(120));

    let analysis_thread = spawn_analysis_thread(
        analysis_rx,
        calibration_state,
        calibration_procedure,
        Some(progress_tx),
        frame_counter,
        bpm,
        48000,
        result_tx,
        OnsetDetectionConfig::default(),
        100,
        None,
    );

    thread::sleep(Duration::from_millis(100));
    assert!(!analysis_thread.is_finished());
}

#[test]
fn test_thread_accepts_optional_progress_channel() {
    let channels1 = BufferPool::new(8, 2048);
    let (_audio_tx1, analysis_rx1) = channels1.split_for_threads();

    let procedure1 = CalibrationProcedure::new(10);
    let calibration_procedure1 = Arc::new(Mutex::new(Some(procedure1)));
    let calibration_state1 = Arc::new(RwLock::new(CalibrationState::new_default()));
    let (progress_tx, _progress_rx) = broadcast::channel(100);
    let (result_tx1, _result_rx1) = broadcast::channel(100);
    let frame_counter1 = Arc::new(AtomicU64::new(0));
    let bpm1 = Arc::new(AtomicU32::new(120));

    let thread1 = spawn_analysis_thread(
        analysis_rx1,
        calibration_state1,
        calibration_procedure1,
        Some(progress_tx),
        frame_counter1,
        bpm1,
        48000,
        result_tx1,
        OnsetDetectionConfig::default(),
        100,
        None,
    );

    let channels2 = BufferPool::new(8, 2048);
    let (_audio_tx2, analysis_rx2) = channels2.split_for_threads();
    let procedure2 = CalibrationProcedure::new(10);
    let calibration_procedure2 = Arc::new(Mutex::new(Some(procedure2)));
    let calibration_state2 = Arc::new(RwLock::new(CalibrationState::new_default()));
    let (result_tx2, _result_rx2) = broadcast::channel(100);
    let frame_counter2 = Arc::new(AtomicU64::new(0));
    let bpm2 = Arc::new(AtomicU32::new(120));

    let thread2 = spawn_analysis_thread(
        analysis_rx2,
        calibration_state2,
        calibration_procedure2,
        None,
        frame_counter2,
        bpm2,
        48000,
        result_tx2,
        OnsetDetectionConfig::default(),
        100,
        None,
    );

    thread::sleep(Duration::from_millis(50));
    assert!(!thread1.is_finished());
    assert!(!thread2.is_finished());
}

#[test]
fn test_thread_handles_lock_contention_without_deadlock() {
    let channels = BufferPool::new(8, 2048);
    let (_audio_tx, analysis_rx) = channels.split_for_threads();

    let procedure = CalibrationProcedure::new(10);
    let calibration_procedure = Arc::new(Mutex::new(Some(procedure)));
    let procedure_clone = Arc::clone(&calibration_procedure);

    let calibration_state = Arc::new(RwLock::new(CalibrationState::new_default()));
    let (progress_tx, _progress_rx) = broadcast::channel(100);
    let (result_tx, _result_rx) = broadcast::channel(100);
    let frame_counter = Arc::new(AtomicU64::new(0));
    let bpm = Arc::new(AtomicU32::new(120));

    let analysis_thread = spawn_analysis_thread(
        analysis_rx,
        calibration_state,
        calibration_procedure,
        Some(progress_tx),
        frame_counter,
        bpm,
        48000,
        result_tx,
        OnsetDetectionConfig::default(),
        100,
        None,
    );

    let _lock = procedure_clone.lock().unwrap();
    thread::sleep(Duration::from_millis(100));
    assert!(!analysis_thread.is_finished());

    drop(_lock);
    thread::sleep(Duration::from_millis(50));
    assert!(!analysis_thread.is_finished());
}
