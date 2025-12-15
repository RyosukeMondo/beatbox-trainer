#[cfg(not(target_os = "android"))]
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
#[cfg(not(target_os = "android"))]
use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};
#[cfg(not(target_os = "android"))]
use std::sync::Arc;
#[cfg(not(target_os = "android"))]
use std::thread::{self, JoinHandle};

#[cfg(not(target_os = "android"))]
use super::buffer_pool::{AudioThreadChannels, BufferPoolChannels};
#[cfg(not(target_os = "android"))]
use super::metronome::{generate_click_sample, is_on_beat};
#[cfg(not(target_os = "android"))]
use crate::config::OnsetDetectionConfig;
#[cfg(not(target_os = "android"))]
use crate::error::AudioError;

#[cfg(not(target_os = "android"))]
pub struct AudioEngine {
    // We cannot hold cpal::Stream directly because it is !Send on Linux (ALSA).
    // Instead, we hold handles to threads that own the streams.
    input_thread: Option<JoinHandle<()>>,
    output_thread: Option<JoinHandle<()>>,

    // Flag to signal threads to stop
    shutdown_flag: Arc<AtomicBool>,

    /// Atomic frame counter for sample-accurate timing
    frame_counter: Arc<AtomicU64>,
    /// Atomic BPM for dynamic tempo changes
    bpm: Arc<AtomicU32>,
    /// Sample rate in Hz
    sample_rate: u32,
    /// Pre-generated metronome click samples
    click_samples: Arc<Vec<f32>>,
    /// Buffer pool channels for lock-free communication
    buffer_channels: BufferPoolChannels,
    /// Current position in click sample playback
    click_position: Arc<AtomicU64>,
    /// Whether metronome output is enabled
    metronome_enabled: Arc<AtomicBool>,
}

#[cfg(not(target_os = "android"))]
impl AudioEngine {
    pub fn new(
        bpm: u32,
        sample_rate: u32,
        buffer_channels: BufferPoolChannels,
    ) -> Result<Self, AudioError> {
        let click_samples = generate_click_sample(sample_rate);

        Ok(AudioEngine {
            input_thread: None,
            output_thread: None,
            shutdown_flag: Arc::new(AtomicBool::new(false)),
            frame_counter: Arc::new(AtomicU64::new(0)),
            bpm: Arc::new(AtomicU32::new(bpm)),
            sample_rate,
            click_samples: Arc::new(click_samples),
            buffer_channels,
            click_position: Arc::new(AtomicU64::new(0)),
            metronome_enabled: Arc::new(AtomicBool::new(true)),
        })
    }

    pub fn set_metronome_enabled(&mut self, enabled: bool) {
        self.metronome_enabled.store(enabled, Ordering::Relaxed);
    }

    pub fn set_bpm(&self, new_bpm: u32) {
        self.bpm.store(new_bpm, Ordering::Relaxed);
    }

    pub fn get_bpm(&self) -> u32 {
        self.bpm.load(Ordering::Relaxed)
    }

    pub fn get_frame_counter(&self) -> u64 {
        self.frame_counter.load(Ordering::Relaxed)
    }

    pub fn get_frame_counter_ref(&self) -> Arc<AtomicU64> {
        Arc::clone(&self.frame_counter)
    }

    pub fn get_bpm_ref(&self) -> Arc<AtomicU32> {
        Arc::clone(&self.bpm)
    }

    // Helper to run input stream in a thread
    fn spawn_input_stream_thread(
        shutdown_flag: Arc<AtomicBool>,
        mut channels: AudioThreadChannels,
    ) -> JoinHandle<()> {
        thread::spawn(move || {
            let host = cpal::default_host();
            let device = match host.default_input_device() {
                Some(d) => d,
                None => {
                    eprintln!("No input device available");
                    return;
                }
            };

            let config = match device.default_input_config() {
                Ok(c) => c,
                Err(e) => {
                    eprintln!("Failed to get input config: {:?}", e);
                    return;
                }
            };

            let stream_config: cpal::StreamConfig = config.clone().into();
            let channels_count = stream_config.channels as usize;
            let err_fn = |err| eprintln!("Input stream error: {}", err);

            let stream = match config.sample_format() {
                cpal::SampleFormat::F32 => device.build_input_stream(
                    &stream_config,
                    move |data: &[f32], _: &cpal::InputCallbackInfo| {
                        if let Ok(mut buffer) = channels.pool_consumer.pop() {
                            buffer.clear();
                            if channels_count == 1 {
                                buffer.extend_from_slice(data);
                            } else {
                                // De-interleave: take first channel
                                for frame in data.chunks(channels_count) {
                                    if !frame.is_empty() {
                                        buffer.push(frame[0]);
                                    } else {
                                        buffer.push(0.0);
                                    }
                                }
                            }
                            let _ = channels.data_producer.push(buffer);
                        }
                    },
                    err_fn,
                    None,
                ),
                _ => {
                    eprintln!("Only F32 sample format supported for input");
                    return;
                }
            };

            if let Ok(s) = stream {
                if let Err(e) = s.play() {
                    eprintln!("Failed to play input stream: {:?}", e);
                    return;
                }

                // Keep thread alive
                while !shutdown_flag.load(Ordering::Relaxed) {
                    thread::sleep(std::time::Duration::from_millis(100));
                }
            } else {
                eprintln!("Failed to build input stream");
            }
        })
    }

    // Helper to run output stream in a thread
    fn spawn_output_stream_thread(
        shutdown_flag: Arc<AtomicBool>,
        frame_counter: Arc<AtomicU64>,
        bpm: Arc<AtomicU32>,
        sample_rate: u32,
        click_samples: Arc<Vec<f32>>,
        click_position: Arc<AtomicU64>,
        metronome_enabled: Arc<AtomicBool>,
    ) -> JoinHandle<()> {
        thread::spawn(move || {
            let host = cpal::default_host();
            let device = match host.default_output_device() {
                Some(d) => d,
                None => {
                    eprintln!("No output device available");
                    return;
                }
            };

            let config = match device.default_output_config() {
                Ok(c) => c,
                Err(e) => {
                    eprintln!("Failed to get output config: {:?}", e);
                    return;
                }
            };

            let stream_config: cpal::StreamConfig = config.clone().into();
            let channels_count = stream_config.channels as usize;
            let err_fn = |err| eprintln!("Output stream error: {}", err);

            let stream = match config.sample_format() {
                cpal::SampleFormat::F32 => device.build_output_stream(
                    &stream_config,
                    move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                        let current_bpm = bpm.load(Ordering::Relaxed);
                        let clicks_enabled = metronome_enabled.load(Ordering::Relaxed);
                        let mut click_pos = click_position.load(Ordering::Relaxed) as usize;

                        let frame_count = data.len() / channels_count;
                        let current_frame_start = frame_counter.load(Ordering::Relaxed);

                        for i in 0..frame_count {
                            let frame_idx = current_frame_start + i as u64;
                            let mut sample_val = 0.0;

                            if clicks_enabled && is_on_beat(frame_idx, current_bpm, sample_rate) {
                                click_pos = 0;
                            }

                            if clicks_enabled && click_pos < click_samples.len() {
                                sample_val = click_samples[click_pos];
                                click_pos += 1;
                            }

                            for ch in 0..channels_count {
                                data[i * channels_count + ch] = sample_val;
                            }
                        }

                        click_position.store(click_pos as u64, Ordering::Relaxed);
                        frame_counter.fetch_add(frame_count as u64, Ordering::Relaxed);
                    },
                    err_fn,
                    None,
                ),
                _ => {
                    eprintln!("Only F32 sample format supported for output");
                    return;
                }
            };

            if let Ok(s) = stream {
                if let Err(e) = s.play() {
                    eprintln!("Failed to play output stream: {:?}", e);
                    return;
                }

                while !shutdown_flag.load(Ordering::Relaxed) {
                    thread::sleep(std::time::Duration::from_millis(100));
                }
            } else {
                eprintln!("Failed to build output stream");
            }
        })
    }

    #[allow(clippy::too_many_arguments)]
    fn spawn_analysis_thread_internal(
        &self,
        buffer_channels: BufferPoolChannels,
        calibration_state: std::sync::Arc<
            std::sync::RwLock<crate::calibration::state::CalibrationState>,
        >,
        calibration_procedure: std::sync::Arc<
            std::sync::Mutex<Option<crate::calibration::procedure::CalibrationProcedure>>,
        >,
        calibration_progress_tx: Option<
            tokio::sync::broadcast::Sender<crate::calibration::CalibrationProgress>,
        >,
        result_sender: tokio::sync::broadcast::Sender<crate::analysis::ClassificationResult>,
        onset_config: OnsetDetectionConfig,
        log_every_n_buffers: u64,
    ) {
        let (_, analysis_channels) = buffer_channels.split_for_threads();

        let frame_counter_clone = Arc::clone(&self.frame_counter);
        let bpm_clone = Arc::clone(&self.bpm);

        crate::analysis::spawn_analysis_thread(
            analysis_channels,
            calibration_state,
            calibration_procedure,
            calibration_progress_tx,
            frame_counter_clone,
            bpm_clone,
            self.sample_rate,
            result_sender,
            onset_config,
            log_every_n_buffers,
            None,
            None,
        );
    }

    pub fn start(
        &mut self,
        calibration_state: std::sync::Arc<
            std::sync::RwLock<crate::calibration::state::CalibrationState>,
        >,
        calibration_procedure: std::sync::Arc<
            std::sync::Mutex<Option<crate::calibration::procedure::CalibrationProcedure>>,
        >,
        calibration_progress_tx: Option<
            tokio::sync::broadcast::Sender<crate::calibration::CalibrationProgress>,
        >,
        result_sender: tokio::sync::broadcast::Sender<crate::analysis::ClassificationResult>,
        onset_config: OnsetDetectionConfig,
        log_every_n_buffers: u64,
    ) -> Result<(), AudioError> {
        // Reset shutdown flag
        self.shutdown_flag.store(false, Ordering::SeqCst);

        // Split buffer channels
        let buffer_channels = std::mem::replace(
            &mut self.buffer_channels,
            BufferPoolChannels {
                data_producer: rtrb::RingBuffer::new(1).0,
                data_consumer: rtrb::RingBuffer::new(1).1,
                pool_producer: rtrb::RingBuffer::new(1).0,
                pool_consumer: rtrb::RingBuffer::new(1).1,
            },
        );

        let (audio_channels, analysis_channels) = buffer_channels.split_for_threads();

        // Spawn threads
        // We need to pass data to threads. Threads will handle stream creation.
        // If stream creation fails, it will log error but this function returns Ok.
        // Ideally we should wait for stream status, but for now this fixes Send/Sync.

        let input_thread =
            Self::spawn_input_stream_thread(self.shutdown_flag.clone(), audio_channels);

        let output_thread = Self::spawn_output_stream_thread(
            self.shutdown_flag.clone(),
            self.frame_counter.clone(),
            self.bpm.clone(),
            self.sample_rate,
            self.click_samples.clone(),
            self.click_position.clone(),
            self.metronome_enabled.clone(),
        );

        self.input_thread = Some(input_thread);
        self.output_thread = Some(output_thread);

        // Spawn analysis
        self.spawn_analysis_thread_internal(
            BufferPoolChannels {
                data_producer: rtrb::RingBuffer::new(1).0,
                data_consumer: analysis_channels.data_consumer,
                pool_producer: analysis_channels.pool_producer,
                pool_consumer: rtrb::RingBuffer::new(1).1,
            },
            calibration_state,
            calibration_procedure,
            calibration_progress_tx,
            result_sender,
            onset_config,
            log_every_n_buffers,
        );

        Ok(())
    }

    pub fn stop(&mut self) -> Result<(), AudioError> {
        // Signal shutdown
        self.shutdown_flag.store(true, Ordering::SeqCst);

        if let Some(thread) = self.input_thread.take() {
            let _ = thread.join();
        }
        if let Some(thread) = self.output_thread.take() {
            let _ = thread.join();
        }
        Ok(())
    }
}
