//! Registry + schema for fixture metadata consumed by diagnostics clients.
//!
//! The fixture catalog declares how WAV/synthetic assets should behave along with
//! the tolerances Debug Lab and CLI overlays enforce. Consumers can ask for the
//! entire catalog or for a single fixture entry which can then be converted into
//! a [`FixtureSpec`] for playback.

use crate::error::AudioError;
use crate::testing::fixtures::{
    FixtureSource, FixtureSpec, SyntheticPattern, SyntheticSpec, ENGINE_SAMPLE_RATE,
};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;

/// Default catalog path bundled with the crate sources.
const CATALOG_PATH: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/fixtures/catalog.json");

/// Machine-readable catalog containing all known fixtures.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FixtureManifestCatalog {
    pub version: u32,
    pub fixtures: Vec<FixtureManifestEntry>,
}

impl FixtureManifestCatalog {
    /// Load catalog from disk when available, falling back to the embedded copy.
    pub fn load_from_default() -> Result<Self, AudioError> {
        match std::fs::read_to_string(CATALOG_PATH) {
            Ok(contents) => Self::from_json(&contents),
            Err(err) => {
                if err.kind() == std::io::ErrorKind::NotFound {
                    Self::from_json(include_str!("../../fixtures/catalog.json"))
                } else {
                    Err(manifest_error(format!(
                        "failed to read fixture catalog: {err}"
                    )))
                }
            }
        }
    }

    /// Parse catalog contents from JSON and validate invariants.
    pub fn from_json(data: &str) -> Result<Self, AudioError> {
        let mut catalog: FixtureManifestCatalog = serde_json::from_str(data).map_err(|err| {
            manifest_error(format!("failed to parse fixture catalog JSON: {err}"))
        })?;
        catalog.validate()?;
        Ok(catalog)
    }

    /// Return a single fixture entry by id, if present.
    pub fn find(&self, id: &str) -> Option<&FixtureManifestEntry> {
        self.fixtures.iter().find(|fixture| fixture.id == id)
    }

    fn validate(&mut self) -> Result<(), AudioError> {
        if self.version == 0 {
            return Err(manifest_error("catalog version must be > 0"));
        }
        if self.fixtures.is_empty() {
            return Err(manifest_error("catalog must contain at least one fixture"));
        }

        let mut seen = HashSet::new();
        for entry in &mut self.fixtures {
            if !seen.insert(entry.id.clone()) {
                return Err(manifest_error(format!(
                    "duplicate fixture id detected: {}",
                    entry.id
                )));
            }
            entry.normalize();
            entry.validate()?;
        }
        Ok(())
    }
}

/// Rich metadata describing how a fixture should behave.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FixtureManifestEntry {
    pub id: String,
    #[serde(default)]
    pub description: Option<String>,
    pub source: FixtureSourceDescriptor,
    #[serde(default = "default_sample_rate")]
    pub sample_rate: u32,
    #[serde(default = "default_duration_ms")]
    pub duration_ms: u32,
    #[serde(default = "default_loop_count")]
    pub loop_count: u16,
    #[serde(default = "default_channels")]
    pub channels: u8,
    #[serde(default)]
    pub metadata: HashMap<String, String>,
    #[serde(rename = "expected_bpm")]
    pub bpm: FixtureBpmRange,
    #[serde(default)]
    pub expected_counts: HashMap<String, u32>,
    #[serde(default)]
    pub anomaly_tags: Vec<String>,
    #[serde(default)]
    pub tolerances: FixtureToleranceEnvelope,
}

impl FixtureManifestEntry {
    /// Convert metadata entry into a runnable [`FixtureSpec`].
    pub fn to_fixture_spec(&self) -> FixtureSpec {
        FixtureSpec {
            id: self.id.clone(),
            source: self.source.to_fixture_source(),
            sample_rate: self.sample_rate,
            channels: self.channels,
            duration_ms: self.duration_ms,
            loop_count: self.loop_count,
            metadata: self.metadata.clone(),
        }
    }

    fn normalize(&mut self) {
        self.anomaly_tags.retain(|tag| !tag.trim().is_empty());
    }

    fn validate(&self) -> Result<(), AudioError> {
        if self.id.trim().is_empty() {
            return Err(manifest_error("fixture id cannot be empty"));
        }
        if self.sample_rate == 0 {
            return Err(manifest_error(format!(
                "fixture {} has invalid sample_rate",
                self.id
            )));
        }
        if self.channels == 0 {
            return Err(manifest_error(format!(
                "fixture {} must declare at least one channel",
                self.id
            )));
        }
        if self.duration_ms == 0 {
            return Err(manifest_error(format!(
                "fixture {} must have non-zero duration",
                self.id
            )));
        }
        if self.loop_count == 0 {
            return Err(manifest_error(format!(
                "fixture {} must loop at least once",
                self.id
            )));
        }
        if self.expected_counts.is_empty() {
            return Err(manifest_error(format!(
                "fixture {} must define expected_counts",
                self.id
            )));
        }
        if self.anomaly_tags.is_empty() {
            return Err(manifest_error(format!(
                "fixture {} must include at least one anomaly tag",
                self.id
            )));
        }
        self.source.validate(&self.id)?;
        self.bpm.validate(&self.id)?;
        self.tolerances.validate(&self.id)?;
        Ok(())
    }
}

/// Declarative BPM bounds enforced by diagnostics consumers.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FixtureBpmRange {
    pub min: u32,
    pub max: u32,
}

impl FixtureBpmRange {
    fn validate(&self, id: &str) -> Result<(), AudioError> {
        if self.min == 0 || self.max == 0 {
            return Err(manifest_error(format!(
                "fixture {} bpm bounds must be > 0",
                id
            )));
        }
        if self.min > self.max {
            return Err(manifest_error(format!(
                "fixture {} has min BPM greater than max BPM",
                id
            )));
        }
        Ok(())
    }

    /// Returns true when bpm value is within configured bounds.
    pub fn contains(&self, bpm: u32) -> bool {
        bpm >= self.min && bpm <= self.max
    }
}

/// Envelope describing the allowed drift for latency + classification accuracy.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FixtureToleranceEnvelope {
    #[serde(default = "default_latency_threshold")]
    pub latency_ms: FixtureThreshold,
    #[serde(default = "default_classification_drop")]
    pub classification_drop_pct: FixtureThreshold,
    #[serde(default = "default_bpm_deviation")]
    pub bpm_deviation_pct: FixtureThreshold,
}

impl Default for FixtureToleranceEnvelope {
    fn default() -> Self {
        Self {
            latency_ms: default_latency_threshold(),
            classification_drop_pct: default_classification_drop(),
            bpm_deviation_pct: default_bpm_deviation(),
        }
    }
}

impl FixtureToleranceEnvelope {
    fn validate(&self, id: &str) -> Result<(), AudioError> {
        self.latency_ms.validate("latency_ms", id)?;
        self.classification_drop_pct
            .validate("classification_drop_pct", id)?;
        self.bpm_deviation_pct.validate("bpm_deviation_pct", id)?;
        Ok(())
    }
}

/// Simple threshold descriptor with upper-bound semantics.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FixtureThreshold {
    pub max: f32,
}

impl FixtureThreshold {
    fn validate(&self, label: &str, id: &str) -> Result<(), AudioError> {
        if self.max <= 0.0 {
            return Err(manifest_error(format!(
                "fixture {id} threshold {label} must be > 0"
            )));
        }
        Ok(())
    }
}

/// Declarative description of the asset powering a fixture.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum FixtureSourceDescriptor {
    WavFile {
        path: String,
    },
    Synthetic {
        pattern: ManifestSyntheticPattern,
        #[serde(default = "default_frequency_hz")]
        frequency_hz: f32,
        #[serde(default = "default_amplitude")]
        amplitude: f32,
    },
    Loopback {
        #[serde(default)]
        device: Option<String>,
    },
}

impl FixtureSourceDescriptor {
    fn validate(&self, id: &str) -> Result<(), AudioError> {
        match self {
            FixtureSourceDescriptor::WavFile { path } => {
                if path.trim().is_empty() {
                    return Err(manifest_error(format!(
                        "fixture {id} wav_file path cannot be empty"
                    )));
                }
            }
            FixtureSourceDescriptor::Synthetic { .. } => {
                // No-op, serde ensures enums are valid
            }
            FixtureSourceDescriptor::Loopback { .. } => {}
        }
        Ok(())
    }

    fn to_fixture_source(&self) -> FixtureSource {
        match self {
            FixtureSourceDescriptor::WavFile { path } => FixtureSource::WavFile {
                path: PathBuf::from(path),
            },
            FixtureSourceDescriptor::Synthetic {
                pattern,
                frequency_hz,
                amplitude,
            } => FixtureSource::Synthetic(SyntheticSpec {
                pattern: pattern.to_fixture_pattern(),
                frequency_hz: *frequency_hz,
                amplitude: *amplitude,
            }),
            FixtureSourceDescriptor::Loopback { .. } => FixtureSource::MicrophonePassthrough,
        }
    }
}

/// Mirror of [`SyntheticPattern`] for manifest-friendly serde.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum ManifestSyntheticPattern {
    Sine,
    Square,
    WhiteNoise,
    ImpulseTrain,
}

impl ManifestSyntheticPattern {
    fn to_fixture_pattern(&self) -> SyntheticPattern {
        match self {
            ManifestSyntheticPattern::Sine => SyntheticPattern::Sine,
            ManifestSyntheticPattern::Square => SyntheticPattern::Square,
            ManifestSyntheticPattern::WhiteNoise => SyntheticPattern::WhiteNoise,
            ManifestSyntheticPattern::ImpulseTrain => SyntheticPattern::ImpulseTrain,
        }
    }
}

fn manifest_error(message: impl Into<String>) -> AudioError {
    AudioError::StreamFailure {
        reason: message.into(),
    }
}

fn default_sample_rate() -> u32 {
    ENGINE_SAMPLE_RATE
}

fn default_duration_ms() -> u32 {
    1_000
}

fn default_loop_count() -> u16 {
    1
}

fn default_channels() -> u8 {
    1
}

fn default_frequency_hz() -> f32 {
    220.0
}

fn default_amplitude() -> f32 {
    0.8
}

fn default_latency_threshold() -> FixtureThreshold {
    FixtureThreshold { max: 10.0 }
}

fn default_classification_drop() -> FixtureThreshold {
    FixtureThreshold { max: 5.0 }
}

fn default_bpm_deviation() -> FixtureThreshold {
    FixtureThreshold { max: 2.0 }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_catalog_json() -> String {
        serde_json::json!({
            "version": 1,
            "fixtures": [
                {
                    "id": "basic",
                    "source": {
                        "kind": "synthetic",
                        "pattern": "sine"
                    },
                    "expected_bpm": {"min": 100, "max": 120},
                    "expected_counts": {"kick": 16},
                    "anomaly_tags": ["smoke"],
                    "tolerances": {
                        "latency_ms": {"max": 10.0},
                        "classification_drop_pct": {"max": 5.0},
                        "bpm_deviation_pct": {"max": 2.0}
                    }
                }
            ]
        })
        .to_string()
    }

    #[test]
    fn parses_valid_catalog() {
        let catalog = FixtureManifestCatalog::from_json(&sample_catalog_json()).unwrap();
        assert_eq!(catalog.fixtures.len(), 1);
        let entry = &catalog.fixtures[0];
        assert_eq!(entry.id, "basic");
        assert!(entry.bpm.contains(110));
    }

    #[test]
    fn rejects_duplicate_ids() {
        let json = serde_json::json!({
            "version": 1,
            "fixtures": [
                {
                    "id": "dup",
                    "source": {"kind": "loopback"},
                    "expected_bpm": {"min": 100, "max": 120},
                    "expected_counts": {"kick": 4},
                    "anomaly_tags": ["smoke"],
                    "tolerances": {
                        "latency_ms": {"max": 10.0},
                        "classification_drop_pct": {"max": 5.0},
                        "bpm_deviation_pct": {"max": 2.0}
                    }
                },
                {
                    "id": "dup",
                    "source": {"kind": "loopback"},
                    "expected_bpm": {"min": 100, "max": 120},
                    "expected_counts": {"kick": 4},
                    "anomaly_tags": ["smoke"],
                    "tolerances": {
                        "latency_ms": {"max": 10.0},
                        "classification_drop_pct": {"max": 5.0},
                        "bpm_deviation_pct": {"max": 2.0}
                    }
                }
            ]
        })
        .to_string();
        let err = FixtureManifestCatalog::from_json(&json).unwrap_err();
        match err {
            AudioError::StreamFailure { reason } => {
                assert!(reason.contains("duplicate"));
            }
            other => panic!("unexpected error: {other:?}"),
        }
    }

    #[test]
    fn rejects_invalid_bpm_bounds() {
        let json = serde_json::json!({
            "version": 1,
            "fixtures": [
                {
                    "id": "bad-bpm",
                    "source": {"kind": "loopback"},
                    "expected_bpm": {"min": 150, "max": 120},
                    "expected_counts": {"kick": 4},
                    "anomaly_tags": ["smoke"],
                    "tolerances": {
                        "latency_ms": {"max": 10.0},
                        "classification_drop_pct": {"max": 5.0},
                        "bpm_deviation_pct": {"max": 2.0}
                    }
                }
            ]
        })
        .to_string();
        let err = FixtureManifestCatalog::from_json(&json).unwrap_err();
        match err {
            AudioError::StreamFailure { reason } => {
                assert!(reason.contains("min BPM"));
            }
            other => panic!("unexpected error: {other:?}"),
        }
    }

    #[test]
    fn converts_manifest_to_fixture_spec() {
        let catalog = FixtureManifestCatalog::from_json(&sample_catalog_json()).unwrap();
        let spec = catalog.fixtures[0].to_fixture_spec();
        assert_eq!(spec.id, "basic");
        assert_eq!(spec.sample_rate, ENGINE_SAMPLE_RATE);
    }
}
