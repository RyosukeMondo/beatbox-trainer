use std::collections::HashMap;

use super::*;

#[test]
fn synthetic_source_loops_and_finishes() {
    let spec = FixtureSpec {
        id: "synthetic".into(),
        source: FixtureSource::Synthetic(SyntheticSpec {
            pattern: SyntheticPattern::Sine,
            frequency_hz: 110.0,
            amplitude: 0.5,
        }),
        sample_rate: 24_000,
        channels: 1,
        duration_ms: 10,
        loop_count: 2,
        metadata: HashMap::new(),
    };

    let mut source = spec.build_source().unwrap();
    let mut buffer = vec![0.0; 512];
    let mut finished_seen = false;
    for _ in 0..10 {
        match source.read_into(ENGINE_SAMPLE_RATE, &mut buffer) {
            FixtureRead::Data { finished, .. } => {
                if finished {
                    finished_seen = true;
                    break;
                }
            }
            FixtureRead::Finished => {
                finished_seen = true;
                break;
            }
        }
    }

    assert!(
        finished_seen,
        "fixture should complete after configured loops"
    );
}

#[test]
fn sample_rate_conversion_emits_non_zero_data() {
    let spec = FixtureSpec {
        id: "sine".into(),
        source: FixtureSource::Synthetic(SyntheticSpec {
            pattern: SyntheticPattern::Sine,
            frequency_hz: 220.0,
            amplitude: 1.0,
        }),
        sample_rate: 12_000,
        channels: 1,
        duration_ms: 100,
        loop_count: 1,
        metadata: HashMap::new(),
    };

    let mut source = spec.build_source().unwrap();
    let mut buffer = vec![0.0; 256];
    let read = source.read_into(ENGINE_SAMPLE_RATE, &mut buffer);
    assert!(matches!(read, FixtureRead::Data { .. }));
    assert!(buffer.iter().any(|sample| sample.abs() > 0.0));
}

#[test]
fn rewind_resets_sources() {
    let spec = FixtureSpec {
        id: "noise".into(),
        source: FixtureSource::Synthetic(SyntheticSpec {
            pattern: SyntheticPattern::WhiteNoise,
            frequency_hz: 0.0,
            amplitude: 0.4,
        }),
        sample_rate: 44_100,
        channels: 1,
        duration_ms: 5,
        loop_count: 1,
        metadata: HashMap::new(),
    };

    let mut source = spec.build_source().unwrap();
    let mut buffer = vec![0.0; 64];
    let _ = source.read_into(ENGINE_SAMPLE_RATE, &mut buffer);
    source.rewind();
    let again = source.read_into(ENGINE_SAMPLE_RATE, &mut buffer);
    assert!(matches!(again, FixtureRead::Data { .. }));
}
