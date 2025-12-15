pub mod analysis;
pub mod api;
mod audio;
mod bridge_generated;
mod calibration;
mod config;
pub mod context;
mod debug;
pub mod engine;
pub mod error;
pub mod fixtures;
mod managers;
mod telemetry;
// Unconditionally expose testing to satisfy bridge_generated.rs dependencies
// The module itself might handle feature gating internally if needed, or we accept it for now.
pub mod testing;

#[cfg(target_os = "android")]
use jni::{JavaVM, JNIEnv};
#[cfg(target_os = "android")]
use std::ffi::c_void;

#[cfg(target_os = "android")]
#[no_mangle]
pub extern "C" fn JNI_OnLoad(vm: JavaVM, _res: *mut c_void) -> jni::sys::jint {
    use std::sync::Once;
    static INIT: Once = Once::new();

    INIT.call_once(|| {
        // Initialize tracing for Android
        use tracing_subscriber::layer::SubscriberExt;
        use tracing_subscriber::util::SubscriberInitExt;

        let android_layer = tracing_android::layer("beatbox_trainer")
            .unwrap_or_else(|_| panic!("Failed to create android tracing layer"));

        tracing_subscriber::registry()
            .with(android_layer)
            .with(tracing_subscriber::filter::LevelFilter::INFO)
            .try_init()
            .expect("Failed to initialize tracing subscriber");
            
        tracing::info!("JNI_OnLoad: Tracing initialized");
    });

    // Initialize ndk_context
    let env = vm.get_env().expect("Failed to get JNIEnv");

    match get_android_context(&env) {
        Ok(context) => {
             // Safety: We are passing valid pointers from JNI
             unsafe {
                 ndk_context::initialize_android_context(
                     vm.get_java_vm_pointer() as *mut _,
                     context.as_raw() as *mut _,
                 );
             }
             tracing::info!("ndk_context initialized with Application Context");
        }
        Err(e) => {
            tracing::error!("Failed to get Android Context: {}", e);
            // Fallback to null context, might fail for OpenSL ES
             unsafe {
                 ndk_context::initialize_android_context(
                     vm.get_java_vm_pointer() as *mut _,
                     std::ptr::null_mut(),
                 );
             }
        }
    }

    jni::sys::JNI_VERSION_1_6
}

#[cfg(target_os = "android")]
fn get_android_context(env: &JNIEnv) -> jni::errors::Result<jni::objects::JObject<'static>> {
    let activity_thread_class = env.find_class("android/app/ActivityThread")?;
    let current_activity_thread = env.call_static_method(
        activity_thread_class,
        "currentActivityThread",
        "()Landroid/app/ActivityThread;",
        &[],
    )?.l()?;
    
    let application = env.call_method(
        current_activity_thread,
        "getApplication",
        "()Landroid/app/Application;",
        &[],
    )?.l()?;
    
    let global_ref = env.new_global_ref(application)?;
    Ok(jni::objects::JObject::from(global_ref.into_raw()))
}

// Function to initialize logging on non-Android platforms (e.g. for tests or desktop run)
#[cfg(not(target_os = "android"))]
pub fn setup_logging() {
    use std::sync::Once;
    static INIT: Once = Once::new();

    INIT.call_once(|| {
        tracing_subscriber::fmt::init();
    });
}