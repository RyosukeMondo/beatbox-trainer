// Beatbox Trainer Core - Rust Audio Engine
// Real-time audio processing with lock-free DSP pipeline

// Allow flutter_rust_bridge cfg warnings (expected from macro expansion)
#![allow(unexpected_cfgs)]

// Module declarations
pub mod analysis;
pub mod api;
pub mod audio;
pub mod calibration;
pub mod config;
pub mod context;
pub mod debug;
pub mod engine;
pub mod error;
pub mod fixtures;
pub use debug::http;
pub mod managers;
pub mod telemetry;
pub mod testing;

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
#[allow(dead_code)]
fn init_logging() {
    env_logger::init();
}

/// Static storage for JavaVM pointer
/// This is set during JNI_OnLoad and used later when the context is provided
#[cfg(target_os = "android")]
use crate::telemetry::LifecyclePhase;
#[cfg(target_os = "android")]
static JAVA_VM: once_cell::sync::OnceCell<jni::JavaVM> = once_cell::sync::OnceCell::new();

/// JNI_OnLoad is called when the native library is loaded by Android
/// This function stores the JavaVM pointer for later context initialization
///
/// # Safety
/// This function is called by the Android runtime when System.loadLibrary() is executed.
/// The JavaVM pointer provided by the Android runtime is guaranteed to be valid for the
/// lifetime of the process.
#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn JNI_OnLoad(
    vm: jni::JavaVM,
    _reserved: *mut std::ffi::c_void,
) -> jni::sys::jint {
    use log::info;

    // Initialize Android logger
    init_logging();

    info!("JNI_OnLoad called - storing JavaVM pointer");
    crate::telemetry::hub().record_jni_phase(LifecyclePhase::LibraryLoaded);

    // Store the JavaVM pointer for later use when the context is provided
    if JAVA_VM.set(vm).is_err() {
        error::log_audio_error(
            &error::AudioError::HardwareError {
                details: "JavaVM already initialized".to_string(),
            },
            "JNI_OnLoad",
        );
    } else {
        info!("JavaVM pointer stored successfully");
    }

    // Return JNI version 1.6 to indicate successful initialization
    jni::sys::JNI_VERSION_1_6
}

/// Initialize the Android context safely, preventing re-initialization
#[cfg(target_os = "android")]
fn initialize_ndk_context_once(vm: &jni::JavaVM, context_global: &jni::objects::GlobalRef) {
    use log::info;
    use std::sync::atomic::{AtomicBool, Ordering};

    static CONTEXT_INITIALIZED: AtomicBool = AtomicBool::new(false);

    if CONTEXT_INITIALIZED
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .is_ok()
    {
        // SAFETY: JavaVM and context pointers are valid, guaranteed by Android runtime
        unsafe {
            ndk_context::initialize_android_context(
                vm.get_java_vm_pointer() as *mut _,
                context_global.as_raw() as *mut _,
            );
        }
        info!("Android context initialized successfully with JavaVM and Context");
        crate::telemetry::hub().record_jni_phase(LifecyclePhase::ContextInitialized);
    } else {
        info!("Android context already initialized, skipping re-initialization");
    }
}

/// Initialize the Android context with both JavaVM and Context parameters
/// This function must be called by MainActivity after the library is loaded
///
/// # Safety
/// This function is called from Kotlin/Java via JNI. The context parameter must be a valid
/// android.content.Context jobject. This function must be called before any Oboe operations.
#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn Java_com_ryosukemondo_beatbox_1trainer_MainActivity_initializeAudioContext(
    env: jni::JNIEnv,
    _class: jni::objects::JClass,
    context: jni::objects::JObject,
) {
    use log::{error, info};

    info!("initializeAudioContext called from MainActivity");

    let vm = match JAVA_VM.get() {
        Some(vm) => vm,
        None => {
            error!("JavaVM not initialized. JNI_OnLoad must be called first.");
            return;
        }
    };

    let context_global = match env.new_global_ref(context) {
        Ok(global_ref) => global_ref,
        Err(e) => {
            error!("Failed to create global reference for context: {}", e);
            return;
        }
    };

    info!("Created global reference for application context");
    initialize_ndk_context_once(vm, &context_global);
    crate::telemetry::hub().record_jni_phase(LifecyclePhase::PermissionsGranted);
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_module_structure() {
        // Verify all modules are accessible
        // This ensures the crate compiles with proper module hierarchy
    }

    /// Test atomic initialization guard behavior
    ///
    /// This test verifies the fix for the SIGABRT crash that occurred when
    /// the Android context was initialized multiple times (e.g., during app restarts).
    ///
    /// The bug: ndk_context::initialize_android_context() panics if called multiple times
    /// The fix: Use AtomicBool with compare_exchange to ensure single initialization
    #[test]
    fn test_atomic_initialization_guard_pattern() {
        use std::sync::atomic::{AtomicBool, Ordering};

        // Simulate the initialization guard pattern used in initialize_ndk_context_once
        static TEST_INITIALIZED: AtomicBool = AtomicBool::new(false);

        // First call: should succeed (false -> true)
        let first_call = TEST_INITIALIZED
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .is_ok();
        assert!(first_call, "First initialization should succeed");

        // Second call: should fail (already true)
        let second_call = TEST_INITIALIZED
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .is_ok();
        assert!(!second_call, "Second initialization should be skipped");

        // Third call: should also fail
        let third_call = TEST_INITIALIZED
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .is_ok();
        assert!(!third_call, "Third initialization should be skipped");

        // Verify flag is set
        assert!(
            TEST_INITIALIZED.load(Ordering::SeqCst),
            "Initialization flag should be set"
        );
    }

    /// Test that multiple threads cannot initialize simultaneously
    ///
    /// This verifies the atomic guard is thread-safe and prevents race conditions
    /// during concurrent initialization attempts.
    #[test]
    fn test_atomic_guard_prevents_concurrent_initialization() {
        use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
        use std::sync::Arc;
        use std::thread;

        static CONCURRENT_INIT_FLAG: AtomicBool = AtomicBool::new(false);
        let init_count = Arc::new(AtomicUsize::new(0));

        // Spawn 10 threads that all try to initialize
        let handles: Vec<_> = (0..10)
            .map(|_| {
                let counter = Arc::clone(&init_count);
                thread::spawn(move || {
                    if CONCURRENT_INIT_FLAG
                        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
                        .is_ok()
                    {
                        // Only one thread should reach here
                        counter.fetch_add(1, Ordering::SeqCst);
                    }
                })
            })
            .collect();

        // Wait for all threads
        for handle in handles {
            handle.join().unwrap();
        }

        // Verify only one thread initialized
        assert_eq!(
            init_count.load(Ordering::SeqCst),
            1,
            "Only one thread should have successfully initialized"
        );
    }
}
