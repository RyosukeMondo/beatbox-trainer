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
pub mod managers;

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

    // Get the stored JavaVM
    let vm = match JAVA_VM.get() {
        Some(vm) => vm,
        None => {
            error!(
                "JavaVM not initialized. JNI_OnLoad must be called before initializeAudioContext."
            );
            return;
        }
    };

    // Convert the context to a global reference to ensure it remains valid
    // across different JNI calls
    let context_global = match env.new_global_ref(context) {
        Ok(global_ref) => global_ref,
        Err(e) => {
            error!(
                "Failed to create global reference for context: {}. Android audio will not work.",
                e
            );
            return;
        }
    };

    info!("Created global reference for application context");

    // Initialize ndk-context with both JavaVM and Context parameters
    // SAFETY: The JavaVM pointer is guaranteed to be valid by the Android runtime.
    // The context jobject is a global reference that will remain valid for the
    // lifetime of the process.
    unsafe {
        ndk_context::initialize_android_context(
            vm.get_java_vm_pointer() as *mut _,
            context_global.as_raw() as *mut _,
        );
    }

    info!("Android context initialized successfully with JavaVM and Context");
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_module_structure() {
        // Verify all modules are accessible
        // This ensures the crate compiles with proper module hierarchy
    }
}
