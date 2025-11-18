//! Runtime fixture execution harness that feeds PCM buffers into the existing
//! DSP pipeline without depending on live hardware.
//!
//! The real audio backend is only available on Android which makes local
//! desktop testing painful. This module creates a miniature runtime that
//! reuses the `analysis::spawn_analysis_thread` stack, pre-allocates audio
//! buffers via `audio::buffer_pool`, and drives them with deterministic
//! [`FixtureAudioSource`] implementations.

use crate::engine::EngineHandle;
use crate::error::AudioError;
use crate::testing::fixtures::FixtureSpec;

cfg_if::cfg_if! {
    if #[cfg(any(test, feature = "diagnostics_fixtures"))] {
        mod enabled {
            use super::*;
            use crate::analysis;
            use crate::audio::buffer_pool::BufferPool;
            use crate::testing::fixtures::{FixtureAudioSource, FixtureRead, ENGINE_SAMPLE_RATE};
            use rtrb::PopError;
            use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};
            use std::sync::Arc;
            use std::thread::JoinHandle;
            use std::time::Duration;

            pub struct FixtureHandle {
                running: Arc<AtomicBool>,
                feeder: Option<JoinHandle<()>>,
                analysis: Option<JoinHandle<()>>,
            }

            impl FixtureHandle {
                pub fn stop(&mut self) -> Result<(), AudioError> {
                    self.running.store(false, Ordering::SeqCst);
                    if let Some(handle) = self.feeder.take() {
                        let _ = handle.join();
                    }
                    if let Some(handle) = self.analysis.take() {
                        let _ = handle.join();
                    }
                    Ok(())
                }

                pub fn is_running(&self) -> bool {
                    self.running.load(Ordering::SeqCst)
                }
            }

            impl Drop for FixtureHandle {
                fn drop(&mut self) {
                    let _ = self.stop();
                }
            }

            pub fn start_fixture_session_internal(
                handle: &'static EngineHandle,
                spec: FixtureSpec,
            ) -> Result<FixtureHandle, AudioError> {
                if handle.is_audio_running() {
                    return Err(AudioError::AlreadyRunning);
                }

                let config = handle.config_snapshot();
                let source = spec.build_source()?;
                let buffer_pool = BufferPool::new(
                    config.audio.buffer_pool_size,
                    config.audio.buffer_size,
                );
                let (audio_channels, analysis_channels) = buffer_pool.split_for_threads();

                let classification_tx = handle.broadcasts.init_classification();
                let cal_state = handle.calibration_state_handle();
                let cal_proc = handle.calibration_procedure_handle();
                let cal_progress_tx = handle.broadcasts.get_calibration_sender();

                let frame_counter = Arc::new(AtomicU64::new(0));
                let bpm = Arc::new(AtomicU32::new(120));

                let running = Arc::new(AtomicBool::new(true));

                let analysis_handle = analysis::spawn_analysis_thread(
                    analysis_channels,
                    cal_state,
                    cal_proc,
                    cal_progress_tx,
                    Arc::clone(&frame_counter),
                    Arc::clone(&bpm),
                    ENGINE_SAMPLE_RATE,
                    classification_tx,
                    config.onset_detection.clone(),
                    config.calibration.log_every_n_buffers,
                    Some(Arc::clone(&running)),
                );

                let feeder_handle = spawn_feeder_thread(
                    audio_channels,
                    source,
                    Arc::clone(&running),
                    frame_counter,
                );

                Ok(FixtureHandle {
                    running,
                    feeder: Some(feeder_handle),
                    analysis: Some(analysis_handle),
                })
            }

            fn spawn_feeder_thread(
                mut channels: crate::audio::buffer_pool::AudioThreadChannels,
                mut source: Box<dyn FixtureAudioSource>,
                running: Arc<AtomicBool>,
                frame_counter: Arc<AtomicU64>,
            ) -> JoinHandle<()> {
                std::thread::spawn(move || {
                    while running.load(Ordering::SeqCst) {
                        let mut buffer = match channels.pool_consumer.pop() {
                            Ok(buf) => buf,
                            Err(PopError::Empty) => {
                                if !running.load(Ordering::SeqCst) {
                                    break;
                                }
                                std::thread::sleep(Duration::from_micros(200));
                                continue;
                            }
                        };

                        match source.read_into(ENGINE_SAMPLE_RATE, &mut buffer) {
                            FixtureRead::Data {
                                frames_written,
                                finished,
                            } => {
                                if frames_written < buffer.len() {
                                    buffer[frames_written..].fill(0.0);
                                }
                                frame_counter.fetch_add(frames_written as u64, Ordering::SeqCst);

                                if channels.data_producer.push(buffer).is_err() {
                                    break;
                                }

                                if finished {
                                    running.store(false, Ordering::SeqCst);
                                }
                            }
                            FixtureRead::Finished => {
                                running.store(false, Ordering::SeqCst);
                                break;
                            }
                        }
                    }
                })
            }

        }
    } else {
        mod enabled {
            use super::*;

            pub struct FixtureHandle;

            impl FixtureHandle {
                pub fn stop(&mut self) -> Result<(), AudioError> {
                    Ok(())
                }

                pub fn is_running(&self) -> bool {
                    false
                }
            }

            pub fn start_fixture_session_internal(
                _handle: &'static EngineHandle,
                _spec: FixtureSpec,
            ) -> Result<FixtureHandle, AudioError> {
                Err(AudioError::StreamFailure {
                    reason: "diagnostics fixtures feature disabled".to_string(),
                })
            }
        }
    }
}

pub use enabled::{start_fixture_session_internal, FixtureHandle};

#[cfg(test)]
mod tests {
    use super::*;
    use crate::testing::fixtures::{FixtureSource, SyntheticPattern, SyntheticSpec};
    use std::collections::HashMap;
    use std::thread;
    use std::time::Duration;

    #[test]
    fn fixture_session_teardown_stops_threads() {
        let engine: &'static EngineHandle = Box::leak(Box::new(EngineHandle::new()));
        let spec = FixtureSpec {
            id: "test-fixture".into(),
            source: FixtureSource::Synthetic(SyntheticSpec {
                pattern: SyntheticPattern::ImpulseTrain,
                frequency_hz: 100.0,
                amplitude: 0.2,
            }),
            sample_rate: 24_000,
            channels: 1,
            duration_ms: 20,
            loop_count: 1,
            metadata: HashMap::new(),
        };

        let mut handle =
            start_fixture_session_internal(engine, spec).expect("fixture session starts");
        thread::sleep(Duration::from_millis(5));
        assert!(handle.stop().is_ok());
    }
}
