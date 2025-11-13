// Beatbox Trainer Core - Rust Audio Engine
// Real-time audio processing with lock-free DSP pipeline

// Allow flutter_rust_bridge cfg warnings (expected from macro expansion)
#![allow(unexpected_cfgs)]

// Module declarations
pub mod analysis;
pub mod api;
pub mod audio;
pub mod calibration;
pub mod context;
pub mod error;

// Generated FFI bridge code (created by flutter_rust_bridge codegen)
#[allow(
    clippy::all,
    non_snake_case,
    non_camel_case_types,
    non_upper_case_globals,
    unused_imports,
    unused_variables,
    dead_code
)]
mod bridge_generated;

// Re-exports for convenience
pub use api::*;

/// Initialize Android logging
#[cfg(target_os = "android")]
fn init_logging() {
    use log::info;
    android_logger::init_once(
        android_logger::Config::default()
            .with_max_level(log::LevelFilter::Debug)
            .with_tag("BeatboxTrainer"),
    );
    info!("Android logger initialized");
}

#[cfg(not(target_os = "android"))]
fn init_logging() {
    env_logger::init();
}

/// JNI_OnLoad is called when the native library is loaded by Android
/// This function initializes the Android context required by oboe-rs
///
/// # Safety
/// This function is called by the Android runtime when System.loadLibrary() is executed.
/// The JavaVM pointer provided by the Android runtime is guaranteed to be valid for the
/// lifetime of the process. We must initialize ndk-context before any Oboe operations
/// to prevent "android context was not initialized" panics.
#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn JNI_OnLoad(
    vm: jni::JavaVM,
    _reserved: *mut std::ffi::c_void,
) -> jni::sys::jint {
    use log::info;

    // Initialize Android logger
    init_logging();

    info!("JNI_OnLoad called - initializing Android context");

    // Initialize ndk-context for oboe-rs to access Android audio subsystem
    // SAFETY: The JavaVM pointer is guaranteed to be valid by the Android runtime
    // and will remain valid for the lifetime of the process.
    // We extract the raw pointer and pass it to ndk_context::initialize_android_context.
    unsafe {
        ndk_context::initialize_android_context(vm.get_java_vm_pointer() as *mut _);
    }

    info!("Android context initialized successfully");

    // Return JNI version 1.6 to indicate successful initialization
    jni::sys::JNI_VERSION_1_6
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_module_structure() {
        // Verify all modules are accessible
        // This ensures the crate compiles with proper module hierarchy
    }
}
