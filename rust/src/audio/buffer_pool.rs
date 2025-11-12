// BufferPool - lock-free buffer pool with dual SPSC queues
//
// Implements an object pool pattern using two lock-free SPSC (Single Producer Single Consumer)
// ring buffers for real-time audio processing. This design avoids heap allocations in the
// audio callback thread, ensuring glitch-free audio processing.
//
// Architecture:
// - DATA_QUEUE: Audio thread pushes filled buffers, analysis thread consumes
// - POOL_QUEUE: Analysis thread returns empty buffers, audio thread recycles
//
// Buffer flow:
// 1. Audio thread pops empty buffer from POOL_QUEUE
// 2. Audio thread fills buffer with audio data
// 3. Audio thread pushes filled buffer to DATA_QUEUE
// 4. Analysis thread pops filled buffer from DATA_QUEUE
// 5. Analysis thread processes data
// 6. Analysis thread pushes empty buffer back to POOL_QUEUE

use rtrb::{Consumer, Producer};

/// Configuration constants for buffer pool
pub const DEFAULT_BUFFER_COUNT: usize = 16;
pub const DEFAULT_BUFFER_SIZE: usize = 2048;

/// Audio buffer type - pre-allocated vector of f32 samples
pub type AudioBuffer = Vec<f32>;

/// Split buffer pool channels for producer/consumer separation
///
/// This struct is returned by BufferPool::split() and provides
/// ownership-based access to the dual-queue system.
pub struct BufferPoolChannels {
    /// Producer for sending filled audio buffers to analysis thread
    pub data_producer: Producer<AudioBuffer>,
    /// Consumer for receiving filled audio buffers in analysis thread
    pub data_consumer: Consumer<AudioBuffer>,
    /// Producer for returning empty buffers from analysis thread
    pub pool_producer: Producer<AudioBuffer>,
    /// Consumer for retrieving empty buffers in audio thread
    pub pool_consumer: Consumer<AudioBuffer>,
}

/// Lock-free buffer pool using dual SPSC ring buffers
///
/// Pre-allocates a fixed number of audio buffers and manages them through
/// two lock-free queues. This design is safe for real-time audio threads
/// because all heap allocations happen during initialization.
///
/// # Thread Safety
/// - Lock-free: No mutex locks in queue operations
/// - Wait-free: Push/pop operations have bounded execution time
///
/// # Example
/// ```ignore
/// let channels = BufferPool::new(16, 2048);
///
/// // In audio thread:
/// if let Ok(buffer) = channels.pool_consumer.pop() {
///     // Fill buffer with audio data
///     channels.data_producer.push(buffer).ok();
/// }
///
/// // In analysis thread:
/// if let Ok(buffer) = channels.data_consumer.pop() {
///     // Process buffer
///     channels.pool_producer.push(buffer).ok();
/// }
/// ```
pub struct BufferPool;

impl BufferPool {
    /// Create a new BufferPool with specified buffer count and size
    ///
    /// Returns BufferPoolChannels directly with pre-allocated buffers.
    ///
    /// # Arguments
    /// * `buffer_count` - Number of buffers to pre-allocate (typical: 8-32)
    /// * `buffer_size` - Size of each buffer in f32 samples (typical: 1024-4096)
    ///
    /// # Panics
    /// Panics if buffer_count is 0 or buffer_size is 0
    ///
    /// # Performance
    /// - Time complexity: O(buffer_count × buffer_size) for allocations
    /// - Space complexity: O(buffer_count × buffer_size × sizeof(f32))
    /// - All allocations happen here, ensuring audio thread is allocation-free
    #[allow(clippy::new_ret_no_self)]
    pub fn new(buffer_count: usize, buffer_size: usize) -> BufferPoolChannels {
        assert!(buffer_count > 0, "buffer_count must be greater than 0");
        assert!(buffer_size > 0, "buffer_size must be greater than 0");

        // Create ring buffers with capacity for all pre-allocated buffers
        let (mut pool_producer, pool_consumer) = rtrb::RingBuffer::new(buffer_count);
        let (data_producer, data_consumer) = rtrb::RingBuffer::new(buffer_count);

        // Pre-allocate all buffers and fill the pool queue
        // This is the only place where heap allocation occurs
        for _ in 0..buffer_count {
            let buffer = vec![0.0_f32; buffer_size];
            pool_producer
                .push(buffer)
                .expect("Failed to push buffer to pool queue during initialization");
        }

        BufferPoolChannels {
            data_producer,
            data_consumer,
            pool_producer,
            pool_consumer,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_buffer_pool_creation() {
        let mut channels = BufferPool::new(16, 2048);

        // All buffers should be in the pool queue initially
        let mut available_buffers = 0;
        while channels.pool_consumer.pop().is_ok() {
            available_buffers += 1;
        }
        assert_eq!(
            available_buffers, 16,
            "Expected 16 buffers in pool queue"
        );

        // Data queue should be empty
        assert!(
            channels.data_consumer.pop().is_err(),
            "Data queue should be empty initially"
        );
    }

    #[test]
    fn test_buffer_size() {
        let buffer_size = 2048;
        let mut channels = BufferPool::new(1, buffer_size);

        let buffer = channels
            .pool_consumer
            .pop()
            .expect("Should have one buffer in pool");
        assert_eq!(
            buffer.len(),
            buffer_size,
            "Buffer should have correct size"
        );
        assert_eq!(buffer.capacity(), buffer_size, "Buffer capacity mismatch");
    }

    #[test]
    fn test_buffer_circulation() {
        let mut channels = BufferPool::new(4, 1024);

        // Simulate audio thread: pop from pool, push to data
        let mut buffer = channels
            .pool_consumer
            .pop()
            .expect("Should have buffer in pool");
        buffer[0] = 1.0; // Simulate filling with audio data
        channels
            .data_producer
            .push(buffer)
            .expect("Should push to data queue");

        // Simulate analysis thread: pop from data, process, return to pool
        let buffer = channels
            .data_consumer
            .pop()
            .expect("Should have buffer in data queue");
        assert_eq!(buffer[0], 1.0, "Buffer data should be preserved");
        channels
            .pool_producer
            .push(buffer)
            .expect("Should return buffer to pool");

        // Verify buffer is back in pool
        let buffer = channels
            .pool_consumer
            .pop()
            .expect("Buffer should be back in pool");
        assert_eq!(buffer.len(), 1024, "Buffer size should be unchanged");
    }

    #[test]
    fn test_send() {
        fn assert_send<T: Send>() {}
        // Producer and Consumer are Send (can be moved between threads)
        // but not Sync (cannot be shared between threads via &T)
        // This is correct for SPSC (Single Producer Single Consumer) pattern
        assert_send::<Producer<AudioBuffer>>();
        assert_send::<Consumer<AudioBuffer>>();
        assert_send::<BufferPoolChannels>();
    }

    #[test]
    fn test_full_pipeline() {
        let mut channels = BufferPool::new(2, 512);

        // Fill both buffers
        for i in 0..2 {
            let mut buffer = channels.pool_consumer.pop().unwrap();
            buffer[0] = i as f32;
            channels.data_producer.push(buffer).unwrap();
        }

        // Pool should be empty now
        assert!(
            channels.pool_consumer.pop().is_err(),
            "Pool should be exhausted"
        );

        // Process both buffers
        for i in 0..2 {
            let buffer = channels.data_consumer.pop().unwrap();
            assert_eq!(buffer[0], i as f32);
            channels.pool_producer.push(buffer).unwrap();
        }

        // Data queue should be empty now
        assert!(
            channels.data_consumer.pop().is_err(),
            "Data queue should be empty"
        );

        // Pool should have both buffers back
        assert!(channels.pool_consumer.pop().is_ok());
        assert!(channels.pool_consumer.pop().is_ok());
        assert!(channels.pool_consumer.pop().is_err());
    }

    #[test]
    #[should_panic(expected = "buffer_count must be greater than 0")]
    fn test_zero_buffer_count_panics() {
        BufferPool::new(0, 1024);
    }

    #[test]
    #[should_panic(expected = "buffer_size must be greater than 0")]
    fn test_zero_buffer_size_panics() {
        BufferPool::new(16, 0);
    }

    #[test]
    fn test_default_constants() {
        assert_eq!(DEFAULT_BUFFER_COUNT, 16);
        assert_eq!(DEFAULT_BUFFER_SIZE, 2048);

        // Verify defaults work
        let mut channels = BufferPool::new(DEFAULT_BUFFER_COUNT, DEFAULT_BUFFER_SIZE);
        let buffer = channels.pool_consumer.pop().unwrap();
        assert_eq!(buffer.len(), DEFAULT_BUFFER_SIZE);
    }
}
