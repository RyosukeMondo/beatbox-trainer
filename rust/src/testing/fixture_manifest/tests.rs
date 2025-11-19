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

#[test]
fn rejects_missing_expected_counts() {
    let json = serde_json::json!({
        "version": 1,
        "fixtures": [
            {
                "id": "missing-counts",
                "source": {"kind": "loopback"},
                "expected_bpm": {"min": 80, "max": 120},
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
            assert!(reason.contains("expected_counts"));
        }
        other => panic!("unexpected error: {other:?}"),
    }
}

#[test]
fn rejects_empty_anomaly_tags() {
    let json = serde_json::json!({
        "version": 1,
        "fixtures": [
            {
                "id": "empty-tags",
                "source": {"kind": "loopback"},
                "expected_bpm": {"min": 100, "max": 140},
                "expected_counts": {"kick": 4},
                "anomaly_tags": [""],
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
            assert!(reason.contains("anomaly tag"));
        }
        other => panic!("unexpected error: {other:?}"),
    }
}
