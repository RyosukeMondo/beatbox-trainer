# Tasks Document

- [x] 1. Implement Rust fixture execution layer
  - Files: `rust/src/testing/fixture_engine.rs`, `rust/src/testing/fixtures.rs`, updates to `rust/src/api.rs`
  - Actions:
    - Define `FixtureSpec`, `FixtureHandle`, and fixture source abstractions (WAV loader, synthetic generator, microphone passthrough stubs).
    - Instrument `AudioEngine` entrypoints to accept injected `AudioSource` implementations behind feature flag and expose FRB-callable methods (`start_fixture_session`, `stop_fixture_session`).
    - Ensure zero-allocation behavior by integrating with `audio::buffer_pool` and reusing rtrb queues; add unit tests covering sample rate conversion, looping, and teardown.
  - Requirements: Requirement 1 (all acceptance criteria)

- [ ] 2. Build telemetry collector and FRB surfaces
  - Files: `rust/src/telemetry/mod.rs`, `rust/src/telemetry/events.rs`, `lib/bridge/api.dart` (generated), `lib/services/audio/telemetry_stream.dart`
  - Actions:
    - Hook latency, classification, buffer occupancy, JNI lifecycle emitters into telemetry bus with bounded queues.
    - Serialize `MetricEvent` snapshots for CLI/HTTP and expose async streams through flutter_rust_bridge; add Dart side model `DiagnosticMetric` + parsing helpers.
    - Write Rust + Dart unit tests ensuring event order guarantees and drop-handling warnings.
  - Requirements: Requirements 1 & 2 (telemetry logging portions), Requirement 3 (log consolidation)

- [ ] 3. Deliver diagnostics CLI tooling
  - Files: `rust/src/bin/bbt-diag.rs`, `tools/cli/diagnostics/run.sh`, `scripts/pre-commit`
  - Actions:
    - Implement clap-based CLI supporting `run`, `serve`, `record` commands with flags for fixture paths, synthetic patterns, metrics port, telemetry format.
    - Wire CLI to fixture engine + telemetry collector; ensure structured stdout and exit codes surfaced for CI smoke tests.
    - Add shell wrapper + documentation for invoking CLI locally and from CI; include unit/integration tests for argument parsing and happy-path executions via `cargo test`/`cargo run`.
  - Requirements: Requirement 2 (CLI criteria), Requirement 1.3 (logs/metrics)

- [ ] 4. Provide HTTP debug server
  - Files: `rust/src/debug/http.rs`, `rust/src/debug/routes.rs`, `docs/api/diagnostics-http.md`
  - Actions:
    - Add optional `debug-http` feature enabling Axum-based server with `/healthz`, `/metrics`, `/trace` endpoints returning JSON/Prometheus/SSE payloads.
    - Integrate with telemetry collector snapshots and ensure graceful shutdown via fixture handles; include error propagation + watchdog timers.
    - Document endpoint schemas + example responses; add integration tests hitting routes with mocked telemetry data.
  - Requirements: Requirement 2 (HTTP server criteria)

- [ ] 5. Create Dart harness + bridge mocks
  - Files: `lib/services/audio/test_harness/harness_audio_source.dart`, `lib/services/audio/test_harness/diagnostics_controller.dart`, `test/services/audio/test_harness/...`, updates to `lib/services/audio/audio_controller.dart`
  - Actions:
    - Define abstract `HarnessAudioSource` plus implementations for microphone proxy, fixture file, and synthetic pattern; allow injection into `AudioController`.
    - Implement `DiagnosticsController` managing FRB fixture sessions and exposing `Stream<DiagnosticMetric>` for widget/controllers tests.
    - Write unit + widget-level tests using new harness utilities to validate classification/timing UI updates, mocking FRB streams where needed.
  - Requirements: Requirement 1 (Dart layer swap), Requirement 3.1 (mocked bridge adapters)

- [ ] 6. Add Android instrumentation hooks
  - Files: `android/app/src/main/kotlin/.../DiagnosticsReceiver.kt`, `android/app/src/androidTest/.../DiagnosticsLifecycleTest.kt`, updates to `MainActivity.kt`
  - Actions:
    - Implement broadcast receiver / logging utility that captures JNI load/unload, permission callbacks, and forwards to shared log buffer.
    - Create instrumentation tests (Robolectric or Espresso) verifying callback order, failure handling, and bridging into telemetry aggregator (via adb-accessible logs).
    - Update Gradle test configs so these tests run in CI emulators and produce artifacts (logs + repro commands).
  - Requirements: Requirement 3 (all acceptance criteria)

- [ ] 7. Documentation and developer enablement
  - Files: `docs/guides/qa/diagnostics.md`, updates to `docs/guides/qa/TESTING.md`, `README.md`, IDE launch configs under `.vscode/` or `tools/`
  - Actions:
    - Author guide covering fixture execution, CLI usage, HTTP server endpoints, interpreting metrics, and attaching logs.
    - Provide sample CLI/IDE commands plus instructions for enabling debug features safely (build flags, environment vars).
    - Ensure pre-commit/CI scripts run new suites; update `scripts/coverage.sh` to include harness modules and enforce coverage thresholds.
  - Requirements: Non-functional (Usability, Reliability, Security), Requirements 1-3 doc aspects
