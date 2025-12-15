#[cfg(not(target_os = "android"))]
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
#[cfg(not(target_os = "android"))]
use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};
#[cfg(not(target_os = "android"))]
use std::sync::Arc;

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
    /// Input audio stream
    input_stream: Option<cpal::Stream>,
    /// Output audio stream
    output_stream: Option<cpal::Stream>,

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
            input_stream: None,
            output_stream: None,
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

    fn create_input_stream(
        &self,
        mut channels: AudioThreadChannels,
    ) -> Result<cpal::Stream, AudioError> {
        let host = cpal::default_host();
        let device = host
            .default_input_device()
            .ok_or_else(|| AudioError::StreamOpenFailed {
                reason: "No default input device found".to_string(),
            })?;

        let config = device
            .default_input_config()
            .map_err(|e| AudioError::StreamOpenFailed {
                reason: format!("Failed to get default input config: {:?}", e),
            })?;

        let stream_config: cpal::StreamConfig = config.clone().into();
        let channels_count = stream_config.channels as usize;

        // Callback closure
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
                return Err(AudioError::StreamOpenFailed {
                    reason: "Only F32 sample format is currently supported for input".to_string(),
                })
            }
        }
        .map_err(|e| AudioError::StreamOpenFailed {
            reason: format!("{:?}", e),
        })?;

        Ok(stream)
    }

    fn create_output_stream(&self) -> Result<cpal::Stream, AudioError> {
        let host = cpal::default_host();
        let device = host
            .default_output_device()
            .ok_or_else(|| AudioError::StreamOpenFailed {
                reason: "No default output device found".to_string(),
            })?;

        let config = device
            .default_output_config()
            .map_err(|e| AudioError::StreamOpenFailed {
                reason: format!("Failed to get default output config: {:?}", e),
            })?;

        let stream_config: cpal::StreamConfig = config.clone().into();
        let channels_count = stream_config.channels as usize;

        let frame_counter = Arc::clone(&self.frame_counter);
        let bpm = Arc::clone(&self.bpm);
        let sample_rate = self.sample_rate;
        let click_samples = Arc::clone(&self.click_samples);
        let click_position = Arc::clone(&self.click_position);
        let metronome_enabled = Arc::clone(&self.metronome_enabled);

        let err_fn = |err| eprintln!("Output stream error: {}", err);

        let stream = match config.sample_format() {
            cpal::SampleFormat::F32 => device.build_output_stream(
                &stream_config,
                move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                    let current_bpm = bpm.load(Ordering::Relaxed);
                    let clicks_enabled = metronome_enabled.load(Ordering::Relaxed);
                    let mut click_pos = click_position.load(Ordering::Relaxed) as usize;

                    // data.len() = frames * channels
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

                        // Write to all channels
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
                return Err(AudioError::StreamOpenFailed {
                    reason: "Only F32 sample format is currently supported for output".to_string(),
                })
            }
        }
        .map_err(|e| AudioError::StreamOpenFailed {
            reason: format!("{:?}", e),
        })?;

        Ok(stream)
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

        // Create streams
        let input_stream = self.create_input_stream(audio_channels)?;
        let output_stream = self.create_output_stream()?;

        input_stream.play().map_err(|e| AudioError::HardwareError {
            details: format!("Input start failed: {}", e),
        })?;
        output_stream
            .play()
            .map_err(|e| AudioError::HardwareError {
                details: format!("Output start failed: {}", e),
            })?;

        self.input_stream = Some(input_stream);
        self.output_stream = Some(output_stream);

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
        if let Some(stream) = self.input_stream.take() {
            drop(stream);
        }
        if let Some(stream) = self.output_stream.take() {
            drop(stream);
        }
        Ok(())
    }
}
