//! Test the FFI API functions directly (simulating Flutter calls)
use std::time::{Duration, Instant};

fn main() {
    eprintln!("[test_api] Starting API test...");
    // Initialize tracing
    tracing_subscriber::fmt::init();

    // Test load_calibration_state first (like Flutter does)
    eprintln!("[test_api] Calling load_calibration_state...");
    let json = r#"{"level":1,"t_kick_centroid":2656.7964,"t_kick_zcr":0.022639297,"t_snare_centroid":5948.214,"t_hihat_zcr":0.4505572,"is_calibrated":true,"noise_floor_rms":0.006382522766679049}"#;
    let state: beatbox_trainer::api::CalibrationState = serde_json::from_str(json).unwrap();
    match beatbox_trainer::api::load_calibration_state(state) {
        Ok(()) => eprintln!("[test_api] load_calibration_state succeeded"),
        Err(e) => eprintln!("[test_api] load_calibration_state failed: {:?}", e),
    }

    // Test start_audio
    eprintln!("[test_api] Calling start_audio(120)...");
    let start = Instant::now();
    match beatbox_trainer::api::start_audio(120) {
        Ok(()) => {
            eprintln!("[test_api] start_audio succeeded ({:?})", start.elapsed());

            // Let it run for 3 seconds
            eprintln!("[test_api] Audio running for 3 seconds...");
            std::thread::sleep(Duration::from_secs(3));

            // Stop
            eprintln!("[test_api] Calling stop_audio...");
            let start = Instant::now();
            match beatbox_trainer::api::stop_audio() {
                Ok(()) => eprintln!("[test_api] stop_audio succeeded ({:?})", start.elapsed()),
                Err(e) => eprintln!("[test_api] stop_audio failed: {:?}", e),
            }
        }
        Err(e) => {
            eprintln!(
                "[test_api] start_audio FAILED ({:?}): {:?}",
                start.elapsed(),
                e
            );
        }
    }

    eprintln!("[test_api] Test complete.");
}
