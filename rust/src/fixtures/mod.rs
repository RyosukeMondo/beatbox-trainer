//! Fixture utilities for the deterministic CLI harness.
//!
//! This module discovers fixture assets, loads PCM WAV input data,
//! parses optional expectation JSON, and runs the DSP pipeline against
//! the shared `EngineHandle`. It is intentionally desktop-focused to
//! support CI and QA workflows.

use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU32, AtomicU64, Ordering};
use std::sync::Arc;

use anyhow::{anyhow, Context, Result};
use serde::{Deserialize, Serialize};

use crate::analysis::classifier::{BeatboxHit, Classifier};
use crate::analysis::features::FeatureExtractor;
use crate::analysis::onset::OnsetDetector;
use crate::analysis::quantizer::Quantizer;
use crate::analysis::ClassificationResult;
use crate::calibration::CalibrationState;
use crate::config::{AppConfig, OnsetDetectionConfig};

/// Default location for fixture WAV/JSON assets.
pub const DEFAULT_FIXTURE_ROOT: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/fixtures");

/// Metadata describing an available fixture.
#[derive(Clone, Debug)]
pub struct FixtureMetadata {
    pub name: String,
    pub wav_path: PathBuf,
    pub expect_path: Option<PathBuf>,
}

/// Loaded fixture data with decoded PCM samples.
pub struct FixtureData {
    pub metadata: FixtureMetadata,
    pub sample_rate: u32,
    pub samples: Vec<f32>,
    pub expectations: Option<FixtureExpectations>,
}

/// JSON expectation schema for fixture verification.
#[derive(Debug, Clone, Deserialize)]
pub struct FixtureExpectations {
    pub fixture: String,
    #[serde(default)]
    pub notes: Option<String>,
    pub events: Vec<ExpectedEvent>,
}

impl FixtureExpectations {
    pub fn verify(
        &self,
        actual: &[ClassificationResult],
    ) -> std::result::Result<(), ExpectationDiff> {
        let mut failures = Vec::new();

        for (idx, expected) in self.events.iter().enumerate() {
            match actual.get(idx) {
                Some(event) => {
                    let delta = (event.timestamp_ms as f32 - expected.offset_ms).abs();
                    if event.sound != expected.sound || delta > expected.tolerance_ms {
                        failures.push(ExpectationFailure {
                            index: idx,
                            expected: expected.clone(),
                            actual: Some(event.clone()),
                            delta_ms: Some(delta),
                        });
                    }
                }
                None => failures.push(ExpectationFailure {
                    index: idx,
                    expected: expected.clone(),
                    actual: None,
                    delta_ms: None,
                }),
            }
        }

        if actual.len() > self.events.len() {
            for (idx, event) in actual.iter().enumerate().skip(self.events.len()) {
                failures.push(ExpectationFailure {
                    index: idx,
                    expected: ExpectedEvent {
                        sound: BeatboxHit::Unknown,
                        offset_ms: event.timestamp_ms as f32,
                        tolerance_ms: 0.0,
                    },
                    actual: Some(event.clone()),
                    delta_ms: Some(0.0),
                });
            }
        }

        if failures.is_empty() {
            Ok(())
        } else {
            Err(ExpectationDiff { failures })
        }
    }
}

/// Expected classification event definition.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExpectedEvent {
    pub sound: BeatboxHit,
    pub offset_ms: f32,
    #[serde(default = "default_tolerance")]
    pub tolerance_ms: f32,
}

fn default_tolerance() -> f32 {
    50.0
}

/// Outcome of comparing actual results with expectations.
#[derive(Debug)]
pub struct ExpectationDiff {
    pub failures: Vec<ExpectationFailure>,
}

impl ExpectationDiff {
    pub fn to_json(&self) -> serde_json::Value {
        serde_json::json!({
            "failures": self.failures.iter().map(|failure| {
                serde_json::json!({
                    "index": failure.index,
                    "expected": {
                        "sound": failure.expected.sound,
                        "offset_ms": failure.expected.offset_ms,
                        "tolerance_ms": failure.expected.tolerance_ms,
                    },
                    "actual": failure.actual,
                    "delta_ms": failure.delta_ms,
                })
            }).collect::<Vec<_>>()
        })
    }
}

/// Detailed diff entry for a single failure.
#[derive(Debug)]
pub struct ExpectationFailure {
    pub index: usize,
    pub expected: ExpectedEvent,
    pub actual: Option<ClassificationResult>,
    pub delta_ms: Option<f32>,
}

/// Catalog responsible for discovering fixtures on disk.
pub struct FixtureCatalog {
    root: PathBuf,
}

impl FixtureCatalog {
    pub fn new<P: Into<PathBuf>>(root: P) -> Self {
        Self { root: root.into() }
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    /// List all fixtures by their metadata.
    pub fn discover(&self) -> Result<Vec<FixtureMetadata>> {
        let mut fixtures = Vec::new();
        if !self.root.exists() {
            return Ok(fixtures);
        }

        for entry in fs::read_dir(&self.root)? {
            let entry = entry?;
            if entry.file_type()?.is_file() {
                let path = entry.path();
                if path.extension().and_then(|ext| ext.to_str()) == Some("wav") {
                    let expect = path.with_extension("expect.json");
                    fixtures.push(FixtureMetadata {
                        name: path
                            .file_stem()
                            .and_then(|s| s.to_str())
                            .unwrap_or_default()
                            .to_string(),
                        wav_path: path.clone(),
                        expect_path: expect.exists().then_some(expect),
                    });
                }
            }
        }

        fixtures.sort_by(|a, b| a.name.cmp(&b.name));
        Ok(fixtures)
    }

    /// Load fixture samples + expectations for provided name or path.
    pub fn load(&self, fixture: &str, override_expect: Option<PathBuf>) -> Result<FixtureData> {
        let wav_path = self.resolve_fixture_path(fixture)?;
        let metadata = self.metadata_for_path(&wav_path)?;
        let (samples, sample_rate) = read_wav(&wav_path)?;

        let expectation_path = override_expect.or(metadata.expect_path.clone());
        let expectations = match expectation_path {
            Some(path) => {
                let json = fs::read_to_string(&path)
                    .with_context(|| format!("reading expectation {}", path.display()))?;
                Some(
                    serde_json::from_str(&json)
                        .with_context(|| format!("parsing {}", path.display()))?,
                )
            }
            None => None,
        };

        Ok(FixtureData {
            metadata,
            sample_rate,
            samples,
            expectations,
        })
    }

    fn resolve_fixture_path(&self, fixture: &str) -> Result<PathBuf> {
        let as_path = Path::new(fixture);
        if as_path.exists() {
            return Ok(as_path.to_path_buf());
        }

        let candidate = self.root.join(format!("{fixture}.wav"));
        if candidate.exists() {
            Ok(candidate)
        } else {
            Err(anyhow!(
                "Fixture '{fixture}' not found in {}",
                self.root.display()
            ))
        }
    }

    fn metadata_for_path(&self, wav_path: &Path) -> Result<FixtureMetadata> {
        let name = wav_path
            .file_stem()
            .and_then(|s| s.to_str())
            .ok_or_else(|| anyhow!("Invalid fixture name for {}", wav_path.display()))?
            .to_string();
        let expect_path = wav_path.with_extension("expect.json");
        Ok(FixtureMetadata {
            name,
            wav_path: wav_path.to_path_buf(),
            expect_path: expect_path.exists().then_some(expect_path),
        })
    }
}

impl Default for FixtureCatalog {
    fn default() -> Self {
        Self::new(DEFAULT_FIXTURE_ROOT)
    }
}

/// Executes fixtures by feeding decoded PCM samples through the DSP pipeline.
pub struct FixtureProcessor {
    onset_config: OnsetDetectionConfig,
    calibration_state: Arc<std::sync::RwLock<CalibrationState>>,
    bpm: u32,
}

impl FixtureProcessor {
    pub fn new(
        app_config: AppConfig,
        calibration_state: Arc<std::sync::RwLock<CalibrationState>>,
    ) -> Self {
        Self {
            onset_config: app_config.onset_detection,
            calibration_state,
            bpm: 120,
        }
    }

    pub fn with_bpm(mut self, bpm: u32) -> Self {
        if bpm > 0 {
            self.bpm = bpm;
        }
        self
    }

    pub fn run(&self, data: &FixtureData) -> Result<Vec<ClassificationResult>> {
        if data.samples.is_empty() {
            return Ok(Vec::new());
        }

        let mut detector = OnsetDetector::with_config(data.sample_rate, self.onset_config.clone());
        let extractor = FeatureExtractor::new(data.sample_rate);
        let classifier = Classifier::new(Arc::clone(&self.calibration_state));
        let frame_counter = Arc::new(AtomicU64::new(0));
        let bpm = Arc::new(AtomicU32::new(self.bpm));
        let quantizer = Quantizer::new(Arc::clone(&frame_counter), bpm, data.sample_rate);

        frame_counter.store(data.samples.len() as u64, Ordering::Relaxed);

        let mut onsets = detector.process(&data.samples);
        if onsets.is_empty() {
            onsets = detect_energy_onsets(&data.samples, data.sample_rate);
        }
        let mut results = Vec::with_capacity(onsets.len());

        for onset in onsets {
            let idx = onset as usize;
            if idx + FEATURE_WINDOW > data.samples.len() {
                continue;
            }

            let window = &data.samples[idx..idx + FEATURE_WINDOW];
            let features = extractor.extract(window);
            let level = self
                .calibration_state
                .read()
                .map(|state| state.level)
                .unwrap_or(1);
            let (sound, confidence) = if level >= 2 {
                classifier.classify_level2(&features)
            } else {
                classifier.classify_level1(&features)
            };

            let timing = quantizer.quantize(onset);
            let timestamp_ms = ((onset as f32 / data.sample_rate as f32) * 1000.0)
                .round()
                .max(0.0) as u64;

            results.push(ClassificationResult {
                sound,
                timing,
                timestamp_ms,
                confidence,
            });
        }

        Ok(results)
    }
}

const FEATURE_WINDOW: usize = 1024;

fn detect_energy_onsets(samples: &[f32], sample_rate: u32) -> Vec<u64> {
    if samples.is_empty() {
        return Vec::new();
    }

    let window = ((sample_rate as f32 * 0.01) as usize).max(32);
    let min_gap = ((sample_rate as f32 * 0.12) as usize).max(window);
    let mut idx = 0usize;
    let mut onsets = Vec::new();

    while idx + window <= samples.len() {
        let slice = &samples[idx..idx + window];
        let rms = (slice.iter().map(|s| s * s).sum::<f32>() / window as f32).sqrt();
        if rms > 0.15 {
            onsets.push(idx as u64);
            idx += min_gap;
        } else {
            idx += window;
        }
    }

    onsets
}

fn read_wav(path: &Path) -> Result<(Vec<f32>, u32)> {
    let mut reader =
        hound::WavReader::open(path).with_context(|| format!("opening {}", path.display()))?;
    let spec = reader.spec();
    if spec.channels != 1 {
        return Err(anyhow!(
            "Fixture {} must be mono (found {} channels)",
            path.display(),
            spec.channels
        ));
    }

    let sample_rate = spec.sample_rate;

    let samples = match spec.sample_format {
        hound::SampleFormat::Float => reader
            .samples::<f32>()
            .map(|sample| sample.map_err(|err| anyhow!(err)))
            .collect::<Result<Vec<f32>>>()?,
        hound::SampleFormat::Int => {
            let max = (1i64 << (spec.bits_per_sample - 1)) - 1;
            match spec.bits_per_sample {
                16 => reader
                    .samples::<i16>()
                    .map(|sample| {
                        sample
                            .map(|value| value as f32 / max as f32)
                            .map_err(|err| anyhow!(err))
                    })
                    .collect::<Result<Vec<f32>>>()?,
                24 | 32 => reader
                    .samples::<i32>()
                    .map(|sample| {
                        sample
                            .map(|value| value as f32 / max as f32)
                            .map_err(|err| anyhow!(err))
                    })
                    .collect::<Result<Vec<f32>>>()?,
                other => {
                    return Err(anyhow!(
                        "Unsupported bits per sample {} in {}",
                        other,
                        path.display()
                    ))
                }
            }
        }
    };

    Ok((samples, sample_rate))
}
