use std::collections::HashMap;

use serde::Serialize;

use crate::analysis::classifier::BeatboxHit;
use crate::analysis::ClassificationResult;
use crate::testing::fixture_manifest::FixtureManifestEntry;

/// Aggregated classification statistics for a fixture session.
#[derive(Debug, Clone, Serialize, Default)]
pub struct FixtureRunStats {
    pub observed_bpm: Option<f32>,
    pub total_events: u32,
    pub duration_ms: Option<u64>,
    pub counts: HashMap<String, u32>,
}

impl FixtureRunStats {
    pub fn from_events(events: &[ClassificationResult]) -> Self {
        let mut counts = HashMap::new();
        let mut first_ts = None;
        let mut last_ts = None;

        for event in events {
            let label = canonical_label(&event.sound).to_string();
            *counts.entry(label).or_default() += 1;
            let ts = event.timestamp_ms;
            if first_ts.is_none() {
                first_ts = Some(ts);
            }
            last_ts = Some(ts);
        }

        let duration_ms = match (first_ts, last_ts) {
            (Some(start), Some(end)) if end > start => Some(end - start),
            _ => None,
        };

        let total_events = counts.values().copied().sum::<u32>();
        let observed_bpm = duration_ms.and_then(|window| {
            if total_events > 1 {
                let avg_interval = window as f32 / (total_events - 1) as f32;
                if avg_interval > 0.0 {
                    Some(60_000.0_f32 / avg_interval)
                } else {
                    None
                }
            } else {
                None
            }
        });

        Self {
            observed_bpm,
            total_events,
            duration_ms,
            counts,
        }
    }

    pub fn count_for(&self, label: &str) -> u32 {
        let normalized = normalize_label(label);
        *self.counts.get(&normalized).unwrap_or(&0)
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct FixtureValidation {
    pub stats: FixtureRunStats,
    pub anomalies: Vec<FixtureAnomaly>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum FixtureAnomalyKind {
    BpmOutOfRange,
    ClassificationDrop,
    InsufficientObservations,
}

#[derive(Debug, Clone, Serialize)]
pub struct FixtureAnomaly {
    pub kind: FixtureAnomalyKind,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub label: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub expected_min_bpm: Option<f32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub expected_max_bpm: Option<f32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub observed_bpm: Option<f32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub expected_count: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub observed_count: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub drop_pct: Option<f32>,
}

impl FixtureValidation {
    pub fn has_anomalies(&self) -> bool {
        !self.anomalies.is_empty()
    }
}

impl FixtureAnomaly {
    fn bpm_out_of_range(observed: Option<f32>, min: f32, max: f32) -> Self {
        Self {
            kind: FixtureAnomalyKind::BpmOutOfRange,
            message: match observed {
                Some(value) => format!(
                    "Observed BPM {:.1} outside allowed range {:.1}-{:.1}",
                    value, min, max
                ),
                None => "Unable to compute BPM for fixture session".to_string(),
            },
            label: None,
            expected_min_bpm: Some(min),
            expected_max_bpm: Some(max),
            observed_bpm: observed,
            expected_count: None,
            observed_count: None,
            drop_pct: None,
        }
    }

    fn classification_drop(label: &str, expected: u32, observed: u32, drop_pct: f32) -> Self {
        Self {
            kind: FixtureAnomalyKind::ClassificationDrop,
            message: format!(
                "Fixture reported {observed} {label} events (expected {expected}, drop {:.1}%)",
                drop_pct
            ),
            label: Some(label.to_string()),
            expected_min_bpm: None,
            expected_max_bpm: None,
            observed_bpm: None,
            expected_count: Some(expected),
            observed_count: Some(observed),
            drop_pct: Some(drop_pct),
        }
    }

    fn insufficient_events() -> Self {
        Self {
            kind: FixtureAnomalyKind::InsufficientObservations,
            message: "Fixture session did not produce enough events to derive BPM".into(),
            label: None,
            expected_min_bpm: None,
            expected_max_bpm: None,
            observed_bpm: None,
            expected_count: None,
            observed_count: None,
            drop_pct: None,
        }
    }
}

pub fn validate_fixture_run(
    entry: &FixtureManifestEntry,
    stats: FixtureRunStats,
) -> FixtureValidation {
    let mut anomalies = Vec::new();

    let tolerance_pct = entry.tolerances.bpm_deviation_pct.max.max(0.0);
    let expected_min = entry.bpm.min as f32;
    let expected_max = entry.bpm.max as f32;
    let padded_min = (expected_min - expected_min * tolerance_pct / 100.0).max(0.0);
    let padded_max = expected_max + expected_max * tolerance_pct / 100.0;

    match stats.observed_bpm {
        Some(value) => {
            if value < padded_min || value > padded_max {
                anomalies.push(FixtureAnomaly::bpm_out_of_range(
                    Some(value),
                    padded_min,
                    padded_max,
                ));
            }
        }
        None => anomalies.push(FixtureAnomaly::bpm_out_of_range(
            None, padded_min, padded_max,
        )),
    }

    let drop_tolerance = entry.tolerances.classification_drop_pct.max.max(0.0);
    for (label, expected) in &entry.expected_counts {
        let normalized = normalize_label(label);
        let observed = stats.count_for(&normalized);
        if *expected == 0 {
            continue;
        }
        if observed < *expected {
            let drop_pct = ((*expected - observed) as f32 / *expected as f32) * 100.0;
            if drop_pct > drop_tolerance {
                anomalies.push(FixtureAnomaly::classification_drop(
                    &normalized,
                    *expected,
                    observed,
                    drop_pct,
                ));
            }
        }
    }

    if stats.total_events == 0 {
        anomalies.push(FixtureAnomaly::insufficient_events());
    }

    FixtureValidation { stats, anomalies }
}

fn canonical_label(hit: &BeatboxHit) -> &'static str {
    match hit {
        BeatboxHit::Kick => "kick",
        BeatboxHit::Snare | BeatboxHit::KSnare => "snare",
        BeatboxHit::HiHat | BeatboxHit::ClosedHiHat | BeatboxHit::OpenHiHat => "hihat",
        BeatboxHit::Unknown => "unknown",
    }
}

fn normalize_label(label: &str) -> String {
    let lower = label.trim().to_ascii_lowercase();
    let collapsed = lower.replace([' ', '-'], "_");
    match collapsed.as_str() {
        "hi_hat" | "hihat" | "hi_hats" => "hihat".to_string(),
        "closed_hi_hat" | "open_hi_hat" | "closed_hihat" | "open_hihat" => "hihat".to_string(),
        "k_snare" | "ksnare" => "snare".to_string(),
        _ => collapsed,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::analysis::quantizer::{TimingClassification, TimingFeedback};
    use crate::testing::fixture_manifest::{
        FixtureBpmRange, FixtureSourceDescriptor, FixtureThreshold, FixtureToleranceEnvelope,
        ManifestSyntheticPattern,
    };

    fn sample_result(sound: BeatboxHit, timestamp_ms: u64) -> ClassificationResult {
        ClassificationResult {
            sound,
            timing: TimingFeedback {
                classification: TimingClassification::OnTime,
                error_ms: 0.0,
            },
            timestamp_ms,
            confidence: 0.9,
        }
    }

    #[test]
    fn stats_capture_counts_and_bpm() {
        let events = vec![
            sample_result(BeatboxHit::Kick, 0),
            sample_result(BeatboxHit::Snare, 500),
            sample_result(BeatboxHit::HiHat, 1_000),
        ];
        let stats = FixtureRunStats::from_events(&events);
        assert_eq!(stats.count_for("kick"), 1);
        assert_eq!(stats.count_for("snare"), 1);
        assert_eq!(stats.count_for("hihat"), 1);
        assert!(stats.observed_bpm.unwrap() > 100.0);
    }

    #[test]
    fn validation_flags_bpm_outliers() {
        let entry = manifest_entry();
        let stats = FixtureRunStats {
            observed_bpm: Some(200.0),
            total_events: 4,
            duration_ms: Some(1_000),
            counts: HashMap::from([(String::from("kick"), 4)]),
        };
        let validation = validate_fixture_run(&entry, stats);
        assert!(validation.has_anomalies());
        assert!(matches!(
            validation.anomalies[0].kind,
            FixtureAnomalyKind::BpmOutOfRange
        ));
    }

    fn manifest_entry() -> FixtureManifestEntry {
        FixtureManifestEntry {
            id: "test".into(),
            description: None,
            source: FixtureSourceDescriptor::Synthetic {
                pattern: ManifestSyntheticPattern::Sine,
                frequency_hz: 1.0,
                amplitude: 0.5,
            },
            sample_rate: 48_000,
            duration_ms: 1_000,
            loop_count: 1,
            channels: 1,
            metadata: HashMap::new(),
            bpm: FixtureBpmRange { min: 100, max: 120 },
            expected_counts: HashMap::from([(String::from("kick"), 4)]),
            anomaly_tags: vec!["smoke".into()],
            tolerances: FixtureToleranceEnvelope {
                latency_ms: FixtureThreshold { max: 10.0 },
                classification_drop_pct: FixtureThreshold { max: 5.0 },
                bpm_deviation_pct: FixtureThreshold { max: 2.0 },
            },
        }
    }
}
