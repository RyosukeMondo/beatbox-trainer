//! Fixture specification + audio source abstractions for diagnostics harnesses.
//!
//! The diagnostics platform relies on deterministic PCM sources that can feed
//! into the existing DSP pipeline without touching live audio hardware. This
//! module defines the shared data structures (`FixtureSpec`) that flutter_rust_bridge
//! exports as well as the concrete source implementations (WAV loader,
//! synthetic generator, microphone passthrough stubs).

use rand::{rngs::StdRng, Rng, SeedableRng};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::f32::consts::PI;
use std::path::{Path, PathBuf};

use crate::error::AudioError;

/// Engine-facing sample rate used by the analysis pipeline.
pub const ENGINE_SAMPLE_RATE: u32 = 48_000;

/// Declarative description of a runnable diagnostics fixture.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FixtureSpec {
    pub id: String,
    pub source: FixtureSource,
    #[serde(default = "default_spec_sample_rate")]
    pub sample_rate: u32,
    #[serde(default = "default_channels")]
    pub channels: u8,
    #[serde(default = "default_duration_ms")]
    pub duration_ms: u32,
    #[serde(default = "default_loop_count")]
    pub loop_count: u16,
    #[serde(default)]
    pub metadata: HashMap<String, String>,
}

/// Audio source definition for fixture playback.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum FixtureSource {
    /// Load PCM data from a WAV file on disk.
    WavFile { path: PathBuf },
    /// Generate PCM procedurally using deterministic patterns.
    Synthetic(SyntheticSpec),
    /// Stubbed microphone proxy (silence) to exercise wiring.
    MicrophonePassthrough,
}

/// Configuration for synthetic fixtures.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SyntheticSpec {
    pub pattern: SyntheticPattern,
    #[serde(default = "default_frequency_hz")]
    pub frequency_hz: f32,
    #[serde(default = "default_amplitude")]
    pub amplitude: f32,
}

/// Supported deterministic waveform patterns.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum SyntheticPattern {
    Sine,
    Square,
    WhiteNoise,
    ImpulseTrain,
}

/// Result of filling a buffer from a [`FixtureAudioSource`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FixtureRead {
    /// Buffer contains `frames_written` samples; `finished` indicates end-of-stream.
    Data {
        frames_written: usize,
        finished: bool,
    },
    /// No more samples available (source exhausted).
    Finished,
}

/// Trait implemented by fixture sources that can fill PCM buffers.
pub trait FixtureAudioSource: Send {
    fn read_into(&mut self, target_sample_rate: u32, buffer: &mut [f32]) -> FixtureRead;
    fn rewind(&mut self);
}

impl FixtureSpec {
    /// Validate invariant expectations for downstream pipelines.
    pub fn validate(&self) -> Result<(), AudioError> {
        if self.sample_rate == 0 {
            return Err(AudioError::StreamFailure {
                reason: "fixture sample rate must be > 0".to_string(),
            });
        }

        if self.channels == 0 {
            return Err(AudioError::StreamFailure {
                reason: "fixture must have at least one channel".to_string(),
            });
        }

        Ok(())
    }

    /// Convert spec + source into a runtime audio source implementation.
    pub fn build_source(&self) -> Result<Box<dyn FixtureAudioSource>, AudioError> {
        self.validate()?;
        match &self.source {
            FixtureSource::WavFile { path } => Ok(Box::new(WavFixtureSource::new(
                path,
                normalized_loop_count(self.loop_count),
            )?)),
            FixtureSource::Synthetic(spec) => Ok(Box::new(SyntheticFixtureSource::new(
                spec.clone(),
                self.sample_rate,
                normalized_loop_count(self.loop_count),
                self.duration_ms,
            ))),
            FixtureSource::MicrophonePassthrough => Ok(Box::new(MicrophoneSource::new(
                self.sample_rate,
                normalized_loop_count(self.loop_count),
                self.duration_ms,
            ))),
        }
    }
}

fn normalized_loop_count(loop_count: u16) -> u16 {
    if loop_count == 0 {
        1
    } else {
        loop_count
    }
}

fn default_spec_sample_rate() -> u32 {
    ENGINE_SAMPLE_RATE
}

fn default_duration_ms() -> u32 {
    1_000
}

fn default_channels() -> u8 {
    1
}

fn default_loop_count() -> u16 {
    1
}

fn default_frequency_hz() -> f32 {
    220.0
}

fn default_amplitude() -> f32 {
    0.8
}

struct WavFixtureSource {
    samples: Vec<f32>,
    sample_rate: u32,
    cursor: f32,
    loop_count: u16,
    loops_completed: u16,
}

impl WavFixtureSource {
    fn new(path: &Path, loop_count: u16) -> Result<Self, AudioError> {
        let (samples, sample_rate) = read_wav(path)?;
        Ok(Self {
            samples,
            sample_rate,
            cursor: 0.0,
            loop_count,
            loops_completed: 0,
        })
    }
}

impl FixtureAudioSource for WavFixtureSource {
    fn read_into(&mut self, target_sample_rate: u32, buffer: &mut [f32]) -> FixtureRead {
        if self.samples.is_empty() || self.loops_completed >= self.loop_count {
            buffer.fill(0.0);
            return FixtureRead::Finished;
        }

        let ratio = self.sample_rate as f32 / target_sample_rate as f32;
        let mut frames_written = 0usize;

        while frames_written < buffer.len() {
            if self.loops_completed >= self.loop_count {
                break;
            }

            let idx = self.cursor.floor() as usize;
            if idx >= self.samples.len() {
                self.cursor -= self.samples.len() as f32;
                self.loops_completed += 1;
                continue;
            }

            let frac = self.cursor - idx as f32;
            let next_idx = (idx + 1).min(self.samples.len().saturating_sub(1));
            let sample = if next_idx == idx {
                self.samples[idx]
            } else {
                let a = self.samples[idx];
                let b = self.samples[next_idx];
                (1.0 - frac) * a + frac * b
            };

            buffer[frames_written] = sample;
            frames_written += 1;
            self.cursor += ratio;
        }

        let finished = self.loops_completed >= self.loop_count;
        if frames_written < buffer.len() {
            buffer[frames_written..].fill(0.0);
        }

        if frames_written == 0 {
            FixtureRead::Finished
        } else {
            FixtureRead::Data {
                frames_written,
                finished,
            }
        }
    }

    fn rewind(&mut self) {
        self.cursor = 0.0;
        self.loops_completed = 0;
    }
}

struct SyntheticFixtureSource {
    pattern: SyntheticPattern,
    amplitude: f32,
    rng: StdRng,
    sample_rate: u32,
    loop_count: u16,
    loops_completed: u16,
    total_frames_per_loop: usize,
    frames_emitted_in_loop: usize,
    impulse_interval: usize,
    phase: f32,
    frequency_hz: f32,
}

impl SyntheticFixtureSource {
    fn new(spec: SyntheticSpec, sample_rate: u32, loop_count: u16, duration_ms: u32) -> Self {
        let total_frames_per_loop = duration_frames(duration_ms, sample_rate);
        let impulse_interval = if spec.frequency_hz <= 0.0 {
            sample_rate as usize
        } else {
            (sample_rate as f32 / spec.frequency_hz.max(1.0)).max(1.0) as usize
        };

        Self {
            pattern: spec.pattern,
            amplitude: spec.amplitude,
            rng: StdRng::seed_from_u64(0x5A5A_FFF0),
            sample_rate,
            loop_count,
            loops_completed: 0,
            total_frames_per_loop: total_frames_per_loop.max(1),
            frames_emitted_in_loop: 0,
            impulse_interval: impulse_interval.max(1),
            phase: 0.0,
            frequency_hz: spec.frequency_hz.max(1.0),
        }
    }

    fn mark_frame_emitted(&mut self) {
        self.frames_emitted_in_loop += 1;
        if self.frames_emitted_in_loop >= self.total_frames_per_loop {
            self.frames_emitted_in_loop = 0;
            self.loops_completed += 1;
        }
    }
}

impl FixtureAudioSource for SyntheticFixtureSource {
    fn read_into(&mut self, _target_sample_rate: u32, buffer: &mut [f32]) -> FixtureRead {
        if self.loops_completed >= self.loop_count {
            buffer.fill(0.0);
            return FixtureRead::Finished;
        }

        buffer.iter_mut().for_each(|sample| {
            if self.loops_completed >= self.loop_count {
                *sample = 0.0;
                return;
            }

            *sample = match self.pattern {
                SyntheticPattern::Sine => {
                    let value = (2.0 * PI * self.phase).sin() * self.amplitude;
                    self.phase += self.frequency_hz / self.sample_rate as f32;
                    if self.phase >= 1.0 {
                        self.phase -= 1.0;
                    }
                    value
                }
                SyntheticPattern::Square => {
                    let value = if self.phase < 0.5 {
                        self.amplitude
                    } else {
                        -self.amplitude
                    };
                    self.phase += self.frequency_hz / self.sample_rate as f32;
                    if self.phase >= 1.0 {
                        self.phase -= 1.0;
                    }
                    value
                }
                SyntheticPattern::WhiteNoise => self.rng.gen_range(-self.amplitude..self.amplitude),
                SyntheticPattern::ImpulseTrain => {
                    if self
                        .frames_emitted_in_loop
                        .is_multiple_of(self.impulse_interval)
                    {
                        self.amplitude
                    } else {
                        0.0
                    }
                }
            };

            self.mark_frame_emitted();
        });

        let finished = self.loops_completed >= self.loop_count;
        FixtureRead::Data {
            frames_written: buffer.len(),
            finished,
        }
    }

    fn rewind(&mut self) {
        self.frames_emitted_in_loop = 0;
        self.loops_completed = 0;
        self.phase = 0.0;
    }
}

struct MicrophoneSource {
    _sample_rate: u32,
    loop_count: u16,
    loops_completed: u16,
    total_frames_per_loop: usize,
    frames_emitted_in_loop: usize,
}

impl MicrophoneSource {
    fn new(sample_rate: u32, loop_count: u16, duration_ms: u32) -> Self {
        Self {
            _sample_rate: sample_rate,
            loop_count,
            loops_completed: 0,
            total_frames_per_loop: duration_frames(duration_ms, sample_rate).max(1),
            frames_emitted_in_loop: 0,
        }
    }

    fn emit_frame(&mut self) {
        self.frames_emitted_in_loop += 1;
        if self.frames_emitted_in_loop >= self.total_frames_per_loop {
            self.frames_emitted_in_loop = 0;
            self.loops_completed += 1;
        }
    }
}

impl FixtureAudioSource for MicrophoneSource {
    fn read_into(&mut self, _target_sample_rate: u32, buffer: &mut [f32]) -> FixtureRead {
        if self.loops_completed >= self.loop_count {
            buffer.fill(0.0);
            return FixtureRead::Finished;
        }

        for sample in buffer.iter_mut() {
            if self.loops_completed >= self.loop_count {
                *sample = 0.0;
                continue;
            }

            // Silence to emulate passthrough wiring while still exercising the
            // buffer recycling logic.
            *sample = 0.0;
            self.emit_frame();
        }

        FixtureRead::Data {
            frames_written: buffer.len(),
            finished: self.loops_completed >= self.loop_count,
        }
    }

    fn rewind(&mut self) {
        self.frames_emitted_in_loop = 0;
        self.loops_completed = 0;
    }
}

fn duration_frames(duration_ms: u32, sample_rate: u32) -> usize {
    ((duration_ms as f32 / 1_000.0) * sample_rate as f32).round() as usize
}

fn read_wav(path: &Path) -> Result<(Vec<f32>, u32), AudioError> {
    let mut reader = hound::WavReader::open(path).map_err(|err| AudioError::StreamFailure {
        reason: format!("failed to open {}: {err}", path.display()),
    })?;
    let spec = reader.spec();
    if spec.channels == 0 {
        return Err(AudioError::StreamFailure {
            reason: format!("{} has zero channels", path.display()),
        });
    }

    let samples = match spec.sample_format {
        hound::SampleFormat::Float => reader
            .samples::<f32>()
            .map(|sample| {
                sample.map_err(|err| AudioError::StreamFailure {
                    reason: format!("error reading {}: {err}", path.display()),
                })
            })
            .collect::<Result<Vec<f32>, _>>()?,
        hound::SampleFormat::Int => match spec.bits_per_sample {
            16 => reader
                .samples::<i16>()
                .map(|sample| {
                    sample.map(|v| v as f32 / i16::MAX as f32).map_err(|err| {
                        AudioError::StreamFailure {
                            reason: format!("error reading {}: {err}", path.display()),
                        }
                    })
                })
                .collect::<Result<Vec<f32>, _>>()?,
            24 | 32 => reader
                .samples::<i32>()
                .map(|sample| {
                    sample.map(|v| v as f32 / i32::MAX as f32).map_err(|err| {
                        AudioError::StreamFailure {
                            reason: format!("error reading {}: {err}", path.display()),
                        }
                    })
                })
                .collect::<Result<Vec<f32>, _>>()?,
            bits => {
                return Err(AudioError::StreamFailure {
                    reason: format!(
                        "unsupported bits_per_sample={} for {}",
                        bits,
                        path.display()
                    ),
                })
            }
        },
    };

    if spec.channels == 1 {
        return Ok((samples, spec.sample_rate));
    }

    let mut mono = Vec::with_capacity(samples.len() / spec.channels as usize);
    for chunk in samples.chunks(spec.channels as usize) {
        let sum: f32 = chunk.iter().copied().sum();
        mono.push(sum / spec.channels as f32);
    }

    Ok((mono, spec.sample_rate))
}

#[cfg(test)]
mod tests;
