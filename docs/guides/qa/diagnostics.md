# Diagnostics & Testability Guide

The diagnostics platform stitches together the Rust fixture engine, Flutter
Debug Lab UI, telemetry collectors, and scripted smoke checks so QA can prove
audio fixes without touching live microphones. This document explains how to
enable the feature flags, drive fixtures, expose HTTP endpoints, and capture
the evidence packets that ship with every pull request.

## Architecture Summary

- **Fixture Engine (`rust/src/testing/fixture_engine.rs`)** — reuses the
  production analysis threads but replaces live audio with deterministic
  `FixtureAudioSource` implementations (WAV loader, synthetic generator,
  microphone passthrough stub). Protected by the `diagnostics_fixtures`
  Cargo feature.
- **FRB Entry Points (`start_fixture_session`, `stop_fixture_session`)** —
  exported via `lib/bridge/api.dart` so Dart services can swap in PCM fixtures
  during widget tests or Debug Lab scenarios.
- **CLI Harness (`rust/src/bin/beatbox_cli.rs`)** — wraps the fixture catalog
  for deterministic `classify`, `stream`, and `dump-fixtures` commands that
  CI/QA can replay verbatim.
- **Debug HTTP Server (`rust/src/debug/http.rs`)** — Axum router with `/healthz`,
  `/metrics`, `/trace`, `/classification-stream`, and `/params` endpoints guarded
  by the `debug_http` feature and an auth token.
- **Debug Lab (Flutter)** — `lib/ui/screens/debug_lab_screen.dart` visualizes
  the HTTP + FRB telemetry streams, parameter patches, and synthetic fixture
  toggle within the app.
- **Automation Hooks** — `scripts/pre-commit`, `.vscode/launch.json`, and
  `scripts/coverage.sh` ensure the diagnostics surface ships with reproducible
  logs and coverage gates.

## Feature Flags & Build Modes

| Feature flag | Purpose | Default | How to enable |
| --- | --- | --- | --- |
| `diagnostics_fixtures` | Allow fixture engine & FRB calls | Off | `cd rust && cargo build --features diagnostics_fixtures` |
| `debug_http` | Serve Axum HTTP endpoints | On for FRB builds (see `flutter_rust_bridge.yaml`) | `cd rust && cargo build --features debug_http` |

- **Local Flutter run:** set `CARGO_FEATURES="debug_http diagnostics_fixtures"`
  before invoking `flutter run` so the generated Rust library exposes both
  surfaces:
  ```bash
  CARGO_FEATURES="debug_http diagnostics_fixtures" flutter run -d macos
  ```
- **Direct Rust usage:** append `--features "debug_http diagnostics_fixtures"`
  to any `cargo build`, `cargo test`, or `cargo run` invocation when you need
  the diagnostics tooling.
- **Environment variables:**
  - `BEATBOX_DEBUG_HTTP_ADDR` – overrides the Axum bind address (default
    `127.0.0.1:8787`).
  - `BEATBOX_DEBUG_TOKEN` – replaces the default `beatbox-debug` token.
  - `RUST_LOG=info` – surfaces HTTP routing + fixture lifecycle logs.

## Fixture Execution Paths

### Rust fixture engine (headless)

The fixture engine consumes `FixtureSpec` payloads defined in
`rust/src/testing/fixtures.rs`. Each spec includes the source type, duration,
loop count, and metadata:

```json
{
  "id": "basic_hits",
  "source": { "kind": "wav_file", "path": "rust/fixtures/basic_hits.wav" },
  "sample_rate": 48000,
  "channels": 1,
  "loop_count": 1,
  "metadata": { "expected_latency_ms": "18" }
}
```

Spawn a fixture session inside Rust by calling
`testing::fixture_engine::start_fixture_session_internal(&ENGINE_HANDLE, spec)`
and hold on to the returned `FixtureHandle` until teardown. The handle stops
both the PCM feeder and the reused analysis thread, ensuring zero-allocation
behavior through `audio::buffer_pool`.

### Flutter / FRB integration

When built with `diagnostics_fixtures`, the FRB layer exposes two functions:

```dart
await api.startFixtureSession(
  FixtureSpec(
    id: 'basic_hits',
    source: FixtureSource.wavFile(path: 'rust/fixtures/basic_hits.wav'),
    loopCount: 2,
  ),
);

await api.stopFixtureSession();
```

Inject these calls through your diagnostics-specific service layer or manually
from Debug Lab experiments. If the feature flag is disabled the calls
return `AudioError(StreamFailure)` so automated tests can fail fast.

## CLI Harness Workflows

### `bbt-diag` (telemetry + diagnostics control)

The new `bbt-diag` binary drives fixture playback, telemetry summaries, and
recording pipelines directly inside the diagnostics feature set. Commands:

- `run` – start a fixture source (`--fixture`, `--synthetic`, or `--loopback`)
  and emit telemetry summaries in either `table` (default) or `json` format via
  `--telemetry-format`.
- `record` – capture raw `ClassificationResult` payloads to disk:
  `bbt-diag record --synthetic sine --watch-ms 300 --max-events 8 --output logs/smoke/diag.json`.
- `serve` – launch the existing debug HTTP server with token/port overrides
  (`--host`, `--metrics-port`, `--token`) when compiled with `debug_http`.

Helpful flags shared by `run`/`record`:

| Flag | Description |
| --- | --- |
| `--fixture <wav>` | Stream PCM from a WAV asset. |
| `--synthetic <pattern>` | Generate deterministic SINE/SQUARE/WHITE_NOISE/IMPULSE patterns. |
| `--loopback` | Exercise the microphone passthrough stub without external audio. |
| `--watch-ms <ms>` | Duration before the CLI tears down the fixture session. |
| `--duration-ms <ms>` | Override `FixtureSpec` duration (per loop). |
| `--telemetry-format json|table` | Output format for telemetry summaries (run command). |

Wrap the binary through `tools/cli/diagnostics/run.sh` to align with CI
defaults. The script automatically enables the `diagnostics_fixtures` feature,
captures logs under `logs/diagnostics/`, and supports overrides:

```bash
# default synthetic impulse stream
tools/cli/diagnostics/run.sh

# run beat triggered fixture + HTTP server simultaneously
BBT_DIAG_FEATURES="diagnostics_fixtures debug_http" \
tools/cli/diagnostics/run.sh serve --metrics-port 9090 --token my-token
```

Use `tools/cli/diagnostics/run.sh record ...` inside CI smoke jobs so the JSON
artifacts land next to other QA evidence.

### `beatbox_cli` (expectation diff runner)

All fixture assets still live under `rust/fixtures/` with optional
`<name>.expect.json` expectation files. The legacy CLI wraps these assets so QA
can generate diffable JSON reports:

```bash
cd rust
cargo run --bin beatbox_cli --features diagnostics_fixtures -- classify \
  --fixture basic_hits \
  --expect fixtures/basic_hits.expect.json \
  --output ../logs/smoke/classify_basic_hits.json \
  --bpm 110
```

Other handy commands:

- Stream JSON events for live demos:
  ```bash
  cargo run --bin beatbox_cli --features diagnostics_fixtures -- stream \
    --fixture basic_hits --bpm 110
  ```
- List available fixtures and expectation files:
  ```bash
  cargo run --bin beatbox_cli --features diagnostics_fixtures -- dump-fixtures
  ```

Each run appends stdout/stderr to `logs/smoke/cli_smoke.log`, and the JSON
report under `logs/smoke/classify_basic_hits.json` becomes the artifact linked
from user-facing QA docs.

## Debug HTTP Server

The Axum server starts automatically in debug/profile builds when the
`debug_http` feature is enabled (see `rust/src/debug/http.rs`). It binds to
`BEATBOX_DEBUG_HTTP_ADDR`, authenticates via `BEATBOX_DEBUG_TOKEN`, and
publishes telemetry snapshots described in `docs/api/diagnostics-http.md`.

Endpoints:

| Endpoint | Method | Description |
| --- | --- | --- |
| `/healthz` | GET | JSON payload with uptime, watchdog state, fixture handle activity, and last error/JNI phase. `/health` aliases the same handler. |
| `/metrics` | GET | Prometheus text with latency gauges, lifecycle timestamps, watchdog status, and classification counters. |
| `/trace` | GET | SSE stream of serialized `MetricEvent` telemetry for dashboards or log shippers. |
| `/classification-stream` | GET | Existing SSE feed of `ClassificationResult` payloads for Debug Lab parity. |
| `/params` | GET | Supported live parameters + calibration snapshot for quick reference. |
| `/params` | POST | Apply `ParamPatch` (BPM, centroid threshold, ZCR) in-flight. |

Sample requests:

```bash
curl "http://127.0.0.1:8787/healthz?token=beatbox-debug" | jq
curl -H "Authorization: Bearer beatbox-debug" \
  http://127.0.0.1:8787/metrics
curl -N -H "Accept:text/event-stream" \
  -H "X-Debug-Token: beatbox-debug" \
  http://127.0.0.1:8787/trace
curl -X POST http://127.0.0.1:8787/params \
  -H "Authorization: Bearer beatbox-debug" \
  -H "Content-Type: application/json" \
  -d '{"bpm":110}'
```

Use the SSE endpoint inside Debug Lab or with `curl -N` to keep telemetry
mirrored alongside FRB streams.

## Debug Lab & Telemetry Streams

1. Open **Settings ▸ Debug Lab** in the Flutter app (tap the build number five
   times to unlock if hidden).
2. Enter the HTTP server base URL (default `http://127.0.0.1:8787`) and token.
   The UI reuses the token for FRB retries.
3. Toggle **Synthetic fixtures** to drive deterministic events without using
   the CLI. Under the hood this calls `startFixtureSession`.
4. Watch the **Audio Metrics** card, **TelemetryChart**, and **Event Log** to
   confirm parity with the CLI JSON and the Prometheus text emitted by the
   HTTP `/metrics` endpoint.
5. Use the **Param sliders** to send live `ParamPatch` commands over HTTP and
   verify the responses in `logs/smoke/http_smoke.log`.

Export logs via the notebook icon; the `ILogExporter` implementation stores
attachments next to existing smoke logs for easy upload to QA tickets.

## Evidence & Automation

- `scripts/pre-commit` (see comments at the end of the hook) automatically runs
  Flutter tests, Rust tests, both CLI smokes (`cargo run --bin beatbox_cli ...`
  plus `cargo run --features diagnostics_fixtures --bin bbt-diag -- run/record`), and
  HTTP smoke (`cargo test --features debug_http http::routes::tests::`). Logs
  land in `logs/smoke/cli_smoke.log` and `logs/smoke/http_smoke.log`.
- Use `tools/cli/diagnostics/run.sh` locally or in CI to capture repeatable
  telemetry snapshots; the wrapper persists stdout to
  `logs/diagnostics/bbt-diag-<timestamp>.log` and mirrors the arguments that
  pre-commit uses.
- `scripts/coverage.sh` now treats diagnostics harnesses as critical paths:
  - Rust coverage must keep `testing/fixture_engine.rs` and
    `api/diagnostics.rs` above 90%.
  - Dart coverage enforces the same 90% threshold for
    `lib/services/audio/` (including `test_harness/` once added).
  - Run `./scripts/coverage.sh --open` to generate HTML reports and the unified
    `coverage/COVERAGE_REPORT.md`. A JSON summary is emitted to
    `logs/smoke/coverage_summary.json`.
- `.vscode/launch.json` ships three launchers:
  1. `Diagnostics CLI • classify fixture` – reproduces the smoke command with
     debugger hooks.
  2. `Diagnostics CLI • stream fixture` – tails fixture events live.
  3. `Debug HTTP smoke tests` – runs `cargo test` with the `debug_http` feature
     and surfaces log output.

Attach the smoke logs, coverage summary, and any exported Debug Lab transcripts
whenever you demo diagnostics functionality or close out spec tasks.

### Debug Lab evidence exports

- Tap the **notebook** icon in Debug Lab to generate a ZIP under
  `logs/smoke/export/debug_lab_<timestamp>.zip`. Each archive bundles FRB audio
  metrics, onset samples, `/metrics` snapshots, fixture metadata, anomaly logs,
  and ParamPatch history.
- A companion `debug_lab_<timestamp>.txt` file mirrors the CLI references stored
  inside the ZIP (for keynote decks). Tokens are automatically redacted to `***`.
- CLI references default to `bbt-diag run --fixture <id> --telemetry-format json`
  plus a cURL snippet for `/metrics`. Update the fixture field before exporting
  so the manifest reflects the correct metadata row.
- Evidence exports are safe to attach to PRs and demo invites—file names never
  include raw tokens, and the manifest always links back to `logs/smoke/`.

## Troubleshooting Checklist

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `AudioError(StreamFailure: diagnostics fixtures disabled)` when calling FRB | Crate built without `diagnostics_fixtures` | Rebuild with `CARGO_FEATURES="debug_http diagnostics_fixtures"` and rerun `flutter pub run build_runner` if needed |
| Debug Lab banner says “Token rejected” | HTTP token mismatch | Restart the app after updating `BEATBOX_DEBUG_TOKEN`; curl `/health?token=...` to validate |
| CLI smoke log empty | Hook skipped because CLI binary missing | Re-run `cargo build --bin beatbox_cli` or install Rust toolchain |
| Coverage script fails critical thresholds | Diagnostics files under 90% | Add/repair tests in `rust/src/testing/*` or `lib/services/audio/**` then rerun `./scripts/coverage.sh` |
