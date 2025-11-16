use std::path::PathBuf;
use std::process::Command;

use serde_json::Value;

fn cli() -> Command {
    Command::new(env!("CARGO_BIN_EXE_beatbox_cli"))
}

fn fixture_file(name: &str) -> String {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("fixtures")
        .join(name)
        .to_string_lossy()
        .into_owned()
}

#[test]
fn classify_fixture_succeeds() {
    let output = cli()
        .args(["classify", "--fixture", "basic_hits"])
        .output()
        .expect("failed to run beatbox_cli classify");
    assert!(
        output.status.success(),
        "CLI exited with {:?}",
        output.status.code()
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout UTF-8");
    let json: Value =
        serde_json::from_str(stdout.trim()).expect("classification report JSON payload");
    assert_eq!(json["fixture"], "basic_hits");
    assert!(
        json["event_count"].as_u64().unwrap_or_default() >= 1,
        "expected at least one event"
    );
}

#[test]
fn classify_fixture_detects_mismatch() {
    let output = cli()
        .args([
            "classify",
            "--fixture",
            "basic_hits",
            "--expect",
            &fixture_file("basic_hits_incorrect.expect.json"),
        ])
        .output()
        .expect("failed to run mismatch classify");
    assert_eq!(output.status.code(), Some(2));
    let stderr = String::from_utf8(output.stderr).expect("stderr UTF-8");
    assert!(
        stderr.contains("\"failures\""),
        "expected diff JSON in stderr, got {stderr}"
    );
}

#[test]
fn dump_fixtures_lists_assets() {
    let output = cli()
        .arg("dump-fixtures")
        .output()
        .expect("failed to run dump-fixtures");
    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).expect("stdout UTF-8");
    assert!(
        stdout.contains("basic_hits"),
        "expected fixture listing, got {stdout}"
    );
}
