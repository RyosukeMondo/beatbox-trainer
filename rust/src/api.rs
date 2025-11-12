// Public API for flutter_rust_bridge integration
// This module provides FFI functions for Flutter to interact with the Rust audio engine

use anyhow::Result;

/// Initialize and greet from Rust
///
/// This is a simple stub function to verify flutter_rust_bridge integration works.
/// Returns a greeting message.
///
/// # Returns
///
/// * `Result<String>` - Success message or error
#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> Result<String> {
    Ok(format!("Hello, {}! Flutter Rust Bridge is working.", name))
}

/// Get the version of the audio engine
///
/// Returns the current version of the beatbox trainer audio engine.
/// This stub function will be expanded in Phase 4.
///
/// # Returns
///
/// * `Result<String>` - Version string
#[flutter_rust_bridge::frb(sync)]
pub fn get_version() -> Result<String> {
    Ok(env!("CARGO_PKG_VERSION").to_string())
}

/// Add two numbers (stub function for testing)
///
/// This function demonstrates basic parameter passing and return values
/// through the FFI boundary. Will be removed in Phase 4.
///
/// # Arguments
///
/// * `a` - First number
/// * `b` - Second number
///
/// # Returns
///
/// * `Result<i32>` - Sum of a and b
#[flutter_rust_bridge::frb(sync)]
pub fn add_numbers(a: i32, b: i32) -> Result<i32> {
    Ok(a + b)
}

// Future API functions to be implemented in Phase 4:
// - start_audio(bpm: u32) -> Result<()>
// - stop_audio() -> Result<()>
// - set_bpm(bpm: u32) -> Result<()>
// - classification_stream() -> impl Stream<Item = ClassificationResult>
// - start_calibration(sound: CalibrationSound) -> Result<()>
// - finish_calibration() -> Result<()>
// - calibration_stream() -> impl Stream<Item = CalibrationProgress>

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_greet() {
        let result = greet("World".to_string()).unwrap();
        assert_eq!(result, "Hello, World! Flutter Rust Bridge is working.");
    }

    #[test]
    fn test_get_version() {
        let result = get_version().unwrap();
        assert_eq!(result, "0.1.0");
    }

    #[test]
    fn test_add_numbers() {
        assert_eq!(add_numbers(2, 3).unwrap(), 5);
        assert_eq!(add_numbers(-1, 1).unwrap(), 0);
        assert_eq!(add_numbers(100, 200).unwrap(), 300);
    }
}
