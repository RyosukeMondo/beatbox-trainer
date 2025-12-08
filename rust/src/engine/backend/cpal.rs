//! CPAL-based audio backend for desktop platforms (Linux, macOS, Windows)
//!
//! This backend uses CPAL (Cross-Platform Audio Library) to capture audio
//! input from the default microphone and feed it to the analysis pipeline.
//!
//! Since CPAL's Stream is not Send+Sync, we spawn a dedicated thread that
//! owns the stream and runs until signaled to stop.

use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};
use std::sync::Arc;
use std::thread::{self, JoinHandle};

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{SampleFormat, StreamConfig};

use crate::analysis::spawn_analysis_thread;
use crate::audio::buffer_pool::{AudioThreadChannels, BufferPool};
use crate::config::{AudioConfig, OnsetDetectionConfig};
use crate::error::AudioError;

use super::{AudioBackend, EngineStartContext};

/// CPAL-based audio backend for desktop platforms
pub struct CpalBackend {
    /// Configuration for audio processing
    audio_config: AudioConfig,
    /// Configuration for onset detection
    onset_config: OnsetDetectionConfig,
    /// Logging frequency for debug output
    log_every_n_buffers: u64,
    /// Flag to signal shutdown to threads
    shutdown_flag: Arc<AtomicBool>,
    /// Frame counter for timing
    frame_counter: Arc<AtomicU64>,
    /// Current BPM
    bpm: Arc<AtomicU32>,
    /// Sample rate detected from device
    sample_rate: Arc<AtomicU32>,
    /// Stream thread handle
    stream_thread: std::sync::Mutex<Option<JoinHandle<()>>>,
    /// Analysis thread handle
    analysis_handle: std::sync::Mutex<Option<JoinHandle<()>>>,
    /// Running state
    running: AtomicBool,
}

impl CpalBackend {
    /// Create a new CPAL backend
    pub fn new(
        audio_config: AudioConfig,
        onset_config: OnsetDetectionConfig,
        log_every_n_buffers: u64,
    ) -> Self {
        Self {
            audio_config,
            onset_config,
            log_every_n_buffers,
            shutdown_flag: Arc::new(AtomicBool::new(false)),
            frame_counter: Arc::new(AtomicU64::new(0)),
            bpm: Arc::new(AtomicU32::new(120)),
            sample_rate: Arc::new(AtomicU32::new(48000)),
            stream_thread: std::sync::Mutex::new(None),
            analysis_handle: std::sync::Mutex::new(None),
            running: AtomicBool::new(false),
        }
    }

    /// Push samples to the buffer queue for analysis
    fn push_samples_to_queue(
        samples: &[f32],
        audio_channels: &std::sync::Mutex<AudioThreadChannels>,
        frame_counter: &Arc<AtomicU64>,
    ) {
        if let Ok(mut channels) = audio_channels.try_lock() {
            // Try to get an empty buffer from the pool
            if let Ok(mut buffer) = channels.pool_consumer.pop() {
                buffer.clear();
                buffer.extend_from_slice(samples);
                // Push filled buffer to data queue
                let _ = channels.data_producer.push(buffer);
            }
        }

        // Update frame counter
        frame_counter.fetch_add(samples.len() as u64, Ordering::Relaxed);
    }
}

impl AudioBackend for CpalBackend {
    fn start(&self, ctx: EngineStartContext) -> Result<(), AudioError> {
        let _ = ctx.metronome_enabled;
        if ctx.bpm == 0 {
            return Err(AudioError::BpmInvalid { bpm: ctx.bpm });
        }

        // Check if already running
        if self.running.swap(true, Ordering::SeqCst) {
            return Err(AudioError::AlreadyRunning);
        }

        // Reset shutdown flag
        self.shutdown_flag.store(false, Ordering::SeqCst);

        // Store BPM
        self.bpm.store(ctx.bpm, Ordering::SeqCst);

        // Create buffer pool
        let buffer_channels = BufferPool::new(
            self.audio_config.buffer_pool_size,
            self.audio_config.buffer_size,
        );

        // Split channels for audio and analysis threads
        let (audio_channels, analysis_channels) = buffer_channels.split_for_threads();

        // Wrap audio_channels for sharing with the stream callback
        let audio_channels = Arc::new(std::sync::Mutex::new(audio_channels));

        // Clone values needed by the stream thread
        let shutdown_flag = Arc::clone(&self.shutdown_flag);
        let frame_counter = Arc::clone(&self.frame_counter);
        let sample_rate_store = Arc::clone(&self.sample_rate);

        // Channel to communicate sample rate back from the stream thread
        let (sample_rate_tx, sample_rate_rx) =
            std::sync::mpsc::channel::<Result<u32, AudioError>>();

        // Spawn stream thread - this thread owns the CPAL stream
        let stream_handle = thread::spawn(move || {
            // Initialize CPAL in this thread
            eprintln!("[CpalBackend] Stream thread started, getting default host...");
            let host = cpal::default_host();
            eprintln!("[CpalBackend] Got host: {:?}", host.id());

            eprintln!("[CpalBackend] Getting default input device...");
            let device = match host.default_input_device() {
                Some(d) => d,
                None => {
                    eprintln!("[CpalBackend] ERROR: No input device available");
                    let _ = sample_rate_tx.send(Err(AudioError::HardwareError {
                        details: "No input device available".to_string(),
                    }));
                    return;
                }
            };

            eprintln!("[CpalBackend] Using input device: {:?}", device.name());

            eprintln!("[CpalBackend] Getting default input config...");
            let supported_config = match device.default_input_config() {
                Ok(c) => c,
                Err(e) => {
                    eprintln!("[CpalBackend] ERROR: Failed to get input config: {}", e);
                    let _ = sample_rate_tx.send(Err(AudioError::StreamOpenFailed {
                        reason: format!("Failed to get default input config: {}", e),
                    }));
                    return;
                }
            };
            eprintln!("[CpalBackend] Got input config: {:?}", supported_config);

            let sample_rate = supported_config.sample_rate().0;
            let channels = supported_config.channels() as usize;

            log::info!(
                "[CpalBackend] Input config: {} Hz, {} channels, {:?}",
                sample_rate,
                channels,
                supported_config.sample_format()
            );

            // Store sample rate
            sample_rate_store.store(sample_rate, Ordering::SeqCst);

            let config = StreamConfig {
                channels: supported_config.channels(),
                sample_rate: supported_config.sample_rate(),
                buffer_size: cpal::BufferSize::Default,
            };

            let shutdown_flag_cb = Arc::clone(&shutdown_flag);
            let frame_counter_cb = Arc::clone(&frame_counter);
            let audio_channels_cb = Arc::clone(&audio_channels);

            let err_fn = |err| log::error!("[CpalBackend] Stream error: {}", err);

            // Build the input stream based on sample format
            eprintln!(
                "[CpalBackend] Building input stream with format {:?}...",
                supported_config.sample_format()
            );
            let stream = match supported_config.sample_format() {
                SampleFormat::F32 => {
                    device.build_input_stream(
                        &config,
                        move |data: &[f32], _: &cpal::InputCallbackInfo| {
                            if shutdown_flag_cb.load(Ordering::Relaxed) {
                                return;
                            }
                            // Convert to mono if needed
                            let mono_samples: Vec<f32> = if channels == 1 {
                                data.to_vec()
                            } else {
                                data.chunks(channels)
                                    .map(|chunk| chunk.iter().sum::<f32>() / channels as f32)
                                    .collect()
                            };
                            Self::push_samples_to_queue(
                                &mono_samples,
                                &audio_channels_cb,
                                &frame_counter_cb,
                            );
                        },
                        err_fn,
                        None,
                    )
                }
                SampleFormat::I16 => {
                    device.build_input_stream(
                        &config,
                        move |data: &[i16], _: &cpal::InputCallbackInfo| {
                            if shutdown_flag_cb.load(Ordering::Relaxed) {
                                return;
                            }
                            // Convert to mono f32
                            let mono_samples: Vec<f32> = if channels == 1 {
                                data.iter().map(|&s| s as f32 / 32768.0).collect()
                            } else {
                                data.chunks(channels)
                                    .map(|chunk| {
                                        let sum: f32 =
                                            chunk.iter().map(|&s| s as f32 / 32768.0).sum();
                                        sum / channels as f32
                                    })
                                    .collect()
                            };
                            Self::push_samples_to_queue(
                                &mono_samples,
                                &audio_channels_cb,
                                &frame_counter_cb,
                            );
                        },
                        err_fn,
                        None,
                    )
                }
                SampleFormat::U16 => {
                    device.build_input_stream(
                        &config,
                        move |data: &[u16], _: &cpal::InputCallbackInfo| {
                            if shutdown_flag_cb.load(Ordering::Relaxed) {
                                return;
                            }
                            // Convert to mono f32 (u16 is centered at 32768)
                            let mono_samples: Vec<f32> = if channels == 1 {
                                data.iter()
                                    .map(|&s| (s as f32 - 32768.0) / 32768.0)
                                    .collect()
                            } else {
                                data.chunks(channels)
                                    .map(|chunk| {
                                        let sum: f32 = chunk
                                            .iter()
                                            .map(|&s| (s as f32 - 32768.0) / 32768.0)
                                            .sum();
                                        sum / channels as f32
                                    })
                                    .collect()
                            };
                            Self::push_samples_to_queue(
                                &mono_samples,
                                &audio_channels_cb,
                                &frame_counter_cb,
                            );
                        },
                        err_fn,
                        None,
                    )
                }
                _ => {
                    let _ = sample_rate_tx.send(Err(AudioError::StreamOpenFailed {
                        reason: format!(
                            "Unsupported sample format: {:?}",
                            supported_config.sample_format()
                        ),
                    }));
                    return;
                }
            };

            eprintln!("[CpalBackend] build_input_stream returned, checking result...");
            let stream = match stream {
                Ok(s) => {
                    eprintln!("[CpalBackend] Stream built successfully");
                    s
                }
                Err(e) => {
                    eprintln!("[CpalBackend] ERROR: Failed to build stream: {}", e);
                    let _ = sample_rate_tx.send(Err(AudioError::StreamOpenFailed {
                        reason: format!("Failed to build input stream: {}", e),
                    }));
                    return;
                }
            };

            // Start the stream
            eprintln!("[CpalBackend] Starting stream (play)...");
            if let Err(e) = stream.play() {
                let _ = sample_rate_tx.send(Err(AudioError::HardwareError {
                    details: format!("Failed to start stream: {}", e),
                }));
                return;
            }

            log::info!("[CpalBackend] Audio stream started at {} Hz", sample_rate);

            // Signal success with sample rate
            let _ = sample_rate_tx.send(Ok(sample_rate));

            // Keep the thread alive until shutdown is signaled
            // The stream lives in this thread's scope
            while !shutdown_flag.load(Ordering::Relaxed) {
                std::thread::sleep(std::time::Duration::from_millis(50));
            }

            // Stream will be dropped when this thread exits
            log::info!("[CpalBackend] Stream thread exiting");
        });

        // Wait for sample rate or error from stream thread
        let sample_rate = match sample_rate_rx.recv_timeout(std::time::Duration::from_secs(5)) {
            Ok(Ok(sr)) => sr,
            Ok(Err(e)) => {
                self.running.store(false, Ordering::SeqCst);
                return Err(e);
            }
            Err(_) => {
                self.running.store(false, Ordering::SeqCst);
                return Err(AudioError::HardwareError {
                    details: "Timeout waiting for audio stream to start".to_string(),
                });
            }
        };

        // Spawn analysis thread
        let analysis_handle = spawn_analysis_thread(
            analysis_channels,
            ctx.calibration_state,
            ctx.calibration_procedure,
            ctx.calibration_progress_tx,
            Arc::clone(&self.frame_counter),
            Arc::clone(&self.bpm),
            sample_rate,
            ctx.classification_tx,
            self.onset_config.clone(),
            self.log_every_n_buffers,
            Some(Arc::clone(&self.shutdown_flag)),
            ctx.audio_metrics_tx,
        );

        // Store handles
        {
            let mut handle_guard =
                self.stream_thread
                    .lock()
                    .map_err(|_| AudioError::LockPoisoned {
                        component: "stream_thread".to_string(),
                    })?;
            *handle_guard = Some(stream_handle);
        }

        {
            let mut handle_guard =
                self.analysis_handle
                    .lock()
                    .map_err(|_| AudioError::LockPoisoned {
                        component: "analysis_handle".to_string(),
                    })?;
            *handle_guard = Some(analysis_handle);
        }

        Ok(())
    }

    fn stop(&self) -> Result<(), AudioError> {
        if !self.running.swap(false, Ordering::SeqCst) {
            // Already stopped
            return Ok(());
        }

        // Signal shutdown
        self.shutdown_flag.store(true, Ordering::SeqCst);

        // Wait for stream thread to finish
        {
            let mut handle_guard =
                self.stream_thread
                    .lock()
                    .map_err(|_| AudioError::LockPoisoned {
                        component: "stream_thread".to_string(),
                    })?;
            if let Some(handle) = handle_guard.take() {
                let _ = handle.join();
                log::info!("[CpalBackend] Stream thread stopped");
            }
        }

        // Wait for analysis thread to finish
        {
            let mut handle_guard =
                self.analysis_handle
                    .lock()
                    .map_err(|_| AudioError::LockPoisoned {
                        component: "analysis_handle".to_string(),
                    })?;
            if let Some(handle) = handle_guard.take() {
                let _ = handle.join();
                log::info!("[CpalBackend] Analysis thread stopped");
            }
        }

        Ok(())
    }

    fn set_bpm(&self, bpm: u32) -> Result<(), AudioError> {
        if bpm == 0 {
            return Err(AudioError::BpmInvalid { bpm });
        }

        if !self.running.load(Ordering::SeqCst) {
            return Err(AudioError::NotRunning);
        }

        self.bpm.store(bpm, Ordering::Relaxed);
        Ok(())
    }
}

impl Default for CpalBackend {
    fn default() -> Self {
        Self::new(AudioConfig::default(), OnsetDetectionConfig::default(), 100)
    }
}
