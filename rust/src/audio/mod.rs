// Audio module - low-latency audio I/O and metronome generation

pub mod buffer_pool;
#[cfg(target_os = "android")]
pub mod callback;
pub mod engine;
#[cfg(not(target_os = "android"))]
pub mod engine_cpal;
pub mod metronome;
#[cfg(not(target_os = "android"))]
pub mod stubs;

// Re-export commonly used types for convenience
pub use buffer_pool::{
    AudioBuffer, BufferPool, BufferPoolChannels, DEFAULT_BUFFER_COUNT, DEFAULT_BUFFER_SIZE,
};
pub use engine::AudioEngine;
