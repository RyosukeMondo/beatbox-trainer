// Audio module - low-latency audio I/O and metronome generation

pub mod buffer_pool;
pub mod engine;
pub mod metronome;

// Re-export commonly used types for convenience
pub use buffer_pool::{
    AudioBuffer, BufferPool, BufferPoolChannels, DEFAULT_BUFFER_COUNT, DEFAULT_BUFFER_SIZE,
};
pub use engine::AudioEngine;
