//! Test the actual EngineHandle start_audio to find the hang
use beatbox_trainer::engine::EngineHandle;
use std::time::{Duration, Instant};

fn main() {
    eprintln!("[test_engine] Starting engine test...");
    env_logger::init();

    // Create engine handle
    eprintln!("[test_engine] Creating EngineHandle...");
    let start = Instant::now();
    let handle = EngineHandle::new();
    eprintln!("[test_engine] EngineHandle created ({:?})", start.elapsed());

    // Test start_audio
    eprintln!("[test_engine] Calling start_audio(120)...");
    let start = Instant::now();
    match handle.start_audio(120) {
        Ok(()) => {
            eprintln!(
                "[test_engine] start_audio succeeded ({:?})",
                start.elapsed()
            );

            // Let it run for a bit
            eprintln!("[test_engine] Audio running for 3 seconds...");
            std::thread::sleep(Duration::from_secs(3));

            // Stop
            eprintln!("[test_engine] Calling stop_audio...");
            let start = Instant::now();
            match handle.stop_audio() {
                Ok(()) => eprintln!("[test_engine] stop_audio succeeded ({:?})", start.elapsed()),
                Err(e) => eprintln!("[test_engine] stop_audio failed: {:?}", e),
            }
        }
        Err(e) => {
            eprintln!(
                "[test_engine] start_audio FAILED ({:?}): {:?}",
                start.elapsed(),
                e
            );
        }
    }

    eprintln!("[test_engine] Test complete.");
}
