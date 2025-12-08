//! Standalone CPAL test to diagnose audio initialization hangs
use std::time::{Duration, Instant};

fn main() {
    eprintln!("[test_cpal] Starting CPAL test...");

    // Test 1: Get available hosts
    eprintln!("[test_cpal] Step 1: Getting available hosts...");
    let start = Instant::now();
    let hosts = cpal::available_hosts();
    eprintln!(
        "[test_cpal] Available hosts ({:?}): {:?}",
        start.elapsed(),
        hosts
    );

    // Test 2: Get default host
    eprintln!("[test_cpal] Step 2: Getting default host...");
    let start = Instant::now();
    let host = cpal::default_host();
    eprintln!(
        "[test_cpal] Default host ({:?}): {:?}",
        start.elapsed(),
        host.id()
    );

    // Test 3: Get default input device
    eprintln!("[test_cpal] Step 3: Getting default input device...");
    let start = Instant::now();
    use cpal::traits::HostTrait;
    let device = host.default_input_device();
    eprintln!(
        "[test_cpal] Default input device ({:?}): {:?}",
        start.elapsed(),
        device.is_some()
    );

    let device = match device {
        Some(d) => d,
        None => {
            eprintln!("[test_cpal] ERROR: No input device found!");
            return;
        }
    };

    // Test 4: Get device name
    eprintln!("[test_cpal] Step 4: Getting device name...");
    let start = Instant::now();
    use cpal::traits::DeviceTrait;
    let name = device.name();
    eprintln!(
        "[test_cpal] Device name ({:?}): {:?}",
        start.elapsed(),
        name
    );

    // Test 5: Get default input config
    eprintln!("[test_cpal] Step 5: Getting default input config...");
    let start = Instant::now();
    let config = device.default_input_config();
    eprintln!(
        "[test_cpal] Default input config ({:?}): {:?}",
        start.elapsed(),
        config
    );

    let config = match config {
        Ok(c) => c,
        Err(e) => {
            eprintln!("[test_cpal] ERROR: Failed to get config: {}", e);
            return;
        }
    };

    // Test 6: Build input stream
    eprintln!("[test_cpal] Step 6: Building input stream...");
    let start = Instant::now();
    let stream_config = cpal::StreamConfig {
        channels: config.channels(),
        sample_rate: config.sample_rate(),
        buffer_size: cpal::BufferSize::Default,
    };

    let stream = device.build_input_stream(
        &stream_config,
        |_data: &[f32], _info: &cpal::InputCallbackInfo| {
            // Callback - do nothing
        },
        |err| eprintln!("[test_cpal] Stream error: {}", err),
        Some(Duration::from_secs(2)),
    );
    eprintln!(
        "[test_cpal] build_input_stream returned ({:?}): {:?}",
        start.elapsed(),
        stream.is_ok()
    );

    let stream = match stream {
        Ok(s) => s,
        Err(e) => {
            eprintln!("[test_cpal] ERROR: Failed to build stream: {}", e);
            return;
        }
    };

    // Test 7: Play stream
    eprintln!("[test_cpal] Step 7: Starting stream (play)...");
    let start = Instant::now();
    use cpal::traits::StreamTrait;
    let play_result = stream.play();
    eprintln!(
        "[test_cpal] stream.play() returned ({:?}): {:?}",
        start.elapsed(),
        play_result
    );

    match play_result {
        Ok(()) => {
            eprintln!("[test_cpal] SUCCESS: Audio stream is running!");
            std::thread::sleep(Duration::from_secs(2));
            eprintln!("[test_cpal] Stopping stream...");
        }
        Err(e) => {
            eprintln!("[test_cpal] ERROR: Failed to play stream: {}", e);
        }
    }

    eprintln!("[test_cpal] Test complete.");
}
