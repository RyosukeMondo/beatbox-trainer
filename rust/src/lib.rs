// Beatbox Trainer Core - Rust Audio Engine
// Real-time audio processing with lock-free DSP pipeline

// Module declarations
pub mod api;
pub mod audio;
pub mod analysis;
pub mod calibration;

// Re-exports for convenience
pub use api::*;

use log::info;

/// Initialize Android logging
#[cfg(target_os = "android")]
fn init_logging() {
    android_logger::init_once(
        android_logger::Config::default()
            .with_max_level(log::LevelFilter::Debug)
            .with_tag("BeatboxTrainer"),
    );
}

#[cfg(not(target_os = "android"))]
fn init_logging() {
    env_logger::init();
}

/// JNI_OnLoad is called when the native library is loaded by Android
/// This function initializes the Android context required by oboe-rs
#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn JNI_OnLoad(vm: jni::JavaVM, _reserved: *mut std::ffi::c_void) -> jni::sys::jint {
    // Initialize Android logger
    init_logging();

    info!("JNI_OnLoad called - initializing Android context");

    // Initialize ndk-context for oboe-rs to access Android audio subsystem
    // SAFETY: This function must be called before any Oboe operations
    // The JavaVM pointer is guaranteed to be valid by the Android runtime
    let ctx = ndk_context::AndroidContext::new_with_vm(unsafe {
        jni::JavaVM::from_raw(vm.get_java_vm_pointer()).unwrap()
    });

    ndk_context::initialize_android_context(ctx.vm(), ctx.context());

    info!("Android context initialized successfully");

    // Return JNI version
    jni::sys::JNI_VERSION_1_6
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_module_structure() {
        // Verify all modules are accessible
        // This ensures the crate compiles with proper module hierarchy
    }
}
