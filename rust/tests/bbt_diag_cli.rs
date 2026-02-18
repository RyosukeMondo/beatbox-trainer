#![cfg(feature = "diagnostics_fixtures")]

use std::path::PathBuf;
use std::process::Command;

use serde_json::Value;

fn cli() -> Command {
    Command::new(env!("CARGO_BIN_EXE_bbt-diag"))
}

#[test]
fn synthetic_run_outputs_json() {
    let output = cli()
        .args([
            "run",
            "--synthetic",
            "sine",
            "--watch-ms",
            "150",
            "--telemetry-format",
            "json",
        ])
        .output()
        .expect("run command");

    assert!(
        output.status.success(),
        "run exited with {:?}",
        output.status.code()
    );
    let stdout = String::from_utf8(output.stdout).expect("stdout utf8");
    assert!(
        stdout.contains("observed_events"),
        "expected telemetry JSON payload, got {stdout}"
    );
}

#[test]
fn record_command_writes_payload() {
    let output_path = std::env::temp_dir()
        .join(format!("bbt-diag-record-{}.json", std::process::id()));

    let output = cli()
        .args([
            "record",
            "--synthetic",
            "sine",
            "--watch-ms",
            "150",
            "--max-events",
            "8",
            "--output",
            output_path.to_str().unwrap(),
        ])
        .output()
        .expect("record command");

    assert!(
        output.status.success(),
        "record exited with {:?}",
        output.status.code()
    );
    let data =
        std::fs::read_to_string(&output_path).expect("classification payload written to disk");
    let json: Value = serde_json::from_str(&data).expect("valid JSON payload");
    assert_eq!(json["fixture_id"], "synthetic-Sine");
    assert!(
        json["event_count"].as_u64().unwrap_or_default() >= 1,
        "expected at least one event"
    );
}
