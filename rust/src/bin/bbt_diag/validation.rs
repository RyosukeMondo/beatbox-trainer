#![cfg(feature = "diagnostics_fixtures")]

use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

use anyhow::{bail, Context, Result};
use beatbox_trainer::analysis::ClassificationResult;
use beatbox_trainer::testing::fixture_engine::{self, FixtureRunStats, FixtureValidation};
use beatbox_trainer::testing::fixture_manifest::{FixtureManifestCatalog, FixtureManifestEntry};
use tokio::sync::mpsc::{error::TryRecvError, UnboundedReceiver};

pub fn enforce_fixture_metadata(
    fixture_id: &str,
    events: &[ClassificationResult],
    source: &str,
) -> Result<()> {
    let Some(entry) = load_manifest_entry(fixture_id)? else {
        eprintln!(
            "bbt-diag: fixture metadata for {} not found; skipping validation",
            fixture_id
        );
        return Ok(());
    };

    let stats = FixtureRunStats::from_events(events);
    let validation = fixture_engine::validate_fixture_run(&entry, stats);
    if validation.anomalies.is_empty() {
        return Ok(());
    }

    let log_path = append_anomaly_log(fixture_id, &validation, source)?;
    let summary = validation
        .anomalies
        .iter()
        .map(|anomaly| anomaly.message.clone())
        .collect::<Vec<_>>()
        .join("; ");
    bail!(
        "Fixture {} violated metadata expectations: {} (see {})",
        fixture_id,
        summary,
        log_path.display()
    );
}

pub fn drain_classification_events(
    rx: &mut UnboundedReceiver<ClassificationResult>,
    sink: &mut Vec<ClassificationResult>,
) {
    loop {
        match rx.try_recv() {
            Ok(event) => sink.push(event),
            Err(TryRecvError::Empty) | Err(TryRecvError::Disconnected) => break,
        }
    }
}

fn append_anomaly_log(
    fixture_id: &str,
    validation: &FixtureValidation,
    source: &str,
) -> Result<PathBuf> {
    let dir = PathBuf::from("logs").join("smoke");
    fs::create_dir_all(&dir).context("creating logs/smoke directory")?;
    let path = dir.join("debug_lab_anomalies.log");
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .with_context(|| format!("opening anomaly log {}", path.display()))?;
    let entry = serde_json::json!({
        "timestamp_ms": current_timestamp_ms(),
        "fixture_id": fixture_id,
        "source": source,
        "stats": validation.stats,
        "anomalies": validation.anomalies,
    });
    let serialized = serde_json::to_string(&entry)?;
    writeln!(file, "{}", serialized).context("writing anomaly log entry")?;
    Ok(path)
}

fn current_timestamp_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
}

fn load_manifest_entry(fixture_id: &str) -> Result<Option<FixtureManifestEntry>> {
    let catalog =
        FixtureManifestCatalog::load_from_default().context("loading fixture metadata catalog")?;
    Ok(catalog.find(fixture_id).cloned())
}
