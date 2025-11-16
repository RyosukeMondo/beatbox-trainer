# Tasks Document

- [x] 1. Establish Rust engine abstraction & shared telemetry channels
  - Files: `rust/src/engine/core.rs`, `rust/src/engine/backend/mod.rs`, `rust/src/audio/engine.rs` (updates), `rust/src/lib.rs`
  - Actions:
    - Introduce `AudioBackend` + `TimeSource` traits with `OboeBackend` (Android) and `DesktopStubBackend` implementations behind cfgs.
    - Create `EngineHandle` struct exposing async streams (classification, calibration, telemetry) and command channel for `ParamPatch`.
    - Wire existing DSP pipeline (`analysis`, `calibration`, `audio::engine`) into the new handle without adding allocations on audio thread.
  - Purpose: Provide reusable core used by CLI, HTTP server, and FRB.
  - _Leverage: `rust/src/audio/engine.rs`, `rust/src/analysis/`, `rust/src/calibration/`_
  - _Requirements: 1, 2, 3_
  - _Prompt: Role: Rust audio engineer focused on lock-free DSP pipelines | Task: Refactor audio engine to expose trait-based backends and telemetry channels per requirements 1–3 while preserving zero-allocation audio thread behavior | Constraints: Maintain latency budgets, keep Android-specific code guarded via cfg, ensure new channels are bounded and lock-free | Success: EngineHandle usable from tests/CLI/FRB with compilation succeeding on desktop + Android targets_

- [x] 2. Implement deterministic CLI harness (`beatbox_cli`)
  - Files: `rust/src/bin/beatbox_cli.rs`, `rust/src/fixtures/mod.rs`, `rust/fixtures/*.wav` (new fixtures directory), `rust/Cargo.toml`
  - Actions:
    - Build clap-based CLI with commands `classify`, `stream`, `dump-fixtures` supporting `--fixture`, `--expect`, `--output` flags.
    - Create fixture loader that reads PCM WAV + optional `.expect.json` and feeds EngineHandle via Desktop backend.
    - Implement JSON diff output + non-zero exit codes on expectation mismatch; add tests in `rust/tests/cli_fixtures.rs`.
  - Purpose: Enable QA/CI to validate DSP deterministically via CLI.
  - _Leverage: Task 1 EngineHandle_
  - _Requirements: 1, 6_
  - _Prompt: Role: Rust tooling engineer specializing in CLI UX | Task: Build fixture-driven CLI harness meeting requirement 1 acceptance criteria and integrate into CI scripts | Constraints: Provide human-readable diff summaries, support headless desktop execution, reuse engine core without duplicating DSP logic | Success: `cargo run -p beatbox_cli classify --fixture=kick_slow` prints classification JSON and exits 0 when expectations met_

- [x] 3. Add HTTP debug/control server (debug feature flag)
  - Files: `rust/src/http/mod.rs`, `rust/src/http/routes.rs`, `rust/src/http/sse.rs`, `rust/src/lib.rs`, `flutter_rust_bridge.yaml` (feature flag toggle), `docs/TESTING.md` (API docs)
  - Actions:
    - Implement `axum` server spawned in debug builds exposing `/health`, `/metrics`, `/classification-stream` (SSE), `/params` endpoints with token auth + loopback binding.
    - Connect endpoints to EngineHandle streams and command channel, ensuring backpressure and <2 ms overhead.
    - Document OpenAPI spec snippet + usage instructions.
  - Purpose: Live inspection + tuning hook accessible via browser/curl.
  - _Leverage: Task 1 EngineHandle, Task 2 telemetry serialization_
  - _Requirements: 2_
  - _Prompt: Role: Systems engineer with expertise in observability | Task: Build lightweight HTTP server for debug builds fulfilling requirement 2, ensuring SSE mirrors FRB payloads and param updates propagate within budget | Constraints: Feature-flag the server, secure with session token, avoid impacting release binaries | Success: `curl http://127.0.0.1:8787/health?token=...` returns engine status; SSE stream emits live JSON events_

- [x] 4. Implement FRB streams and param RPC end-to-end
  - Files: `rust/src/api.rs`, `lib/bridge/api.dart` (regenerated), `lib/services/audio/audio_service_impl.dart`, `lib/models/classification_result.dart`, `lib/models/calibration_state.dart`, `lib/models/telemetry_event.dart`
  - Actions:
    - Extend FRB schema with `classification_stream`, `calibration_stream`, `telemetry_stream`, and `apply_params` RPC using EngineHandle.
    - Regenerate bindings (`flutter_rust_bridge`), update Dart models/deserializers, remove `UnimplementedError` branches.
    - Add error mapping (`AudioStreamFailure`, `CalibrationTimeout`) with actionable codes.
  - Purpose: Deliver live data to Flutter UI without stubs.
  - _Leverage: Task 1 channels, Task 3 telemetry payload definitions_
  - _Requirements: 3, 6_
  - _Prompt: Role: Cross-language FFI engineer | Task: Wire FRB streams per requirement 3 ensuring payload parity with HTTP/CLI outputs, update Dart services to consume them, and add error handling | Constraints: Keep stream decoding efficient, ensure no blocking on UI thread, align models with docs | Success: Training screen receives live data; integration tests confirm FRB streams emit events within latency target_

- [x] 5. Introduce Dart service locator & router injection
  - Files: `lib/di/service_locator.dart`, `lib/main.dart`, `lib/ui/screens/*.dart` (Training/Calibration/Settings), `test/mocks/*.dart`
  - Actions:
    - Choose DI lib (`get_it` or Riverpod) and register all `I*Service` implementations at startup; provide `.create()` factories for production use.
    - Update widgets to require injected services (remove default constructors) and allow router overrides in `MyApp`.
    - Add widget tests verifying mocks can be injected without touching hardware.
  - Purpose: Enable testability + decouple UI from concrete services.
  - _Leverage: Existing service interfaces (`lib/services/*`)_
  - _Requirements: 4_
  - _Prompt: Role: Flutter architect focused on DI | Task: Implement service locator + widget injection per requirement 4, ensuring tests can supply mocks and router overrides | Constraints: Maintain two-space style, avoid global singletons except DI container, update tests accordingly | Success: `TrainingScreenTest` builds with fake AudioService, app boot uses locator factory_

- [x] 6. Build Debug Lab UI & SSE integration
  - Files: `lib/ui/screens/debug_lab_screen.dart`, `lib/ui/widgets/debug/*.dart`, `lib/services/debug/debug_service.dart`, `lib/routes/app_routes.dart`
  - Actions:
    - Create Debug Lab screen with log view, telemetry charts, parameter sliders, synthetic input toggles; feed data from FRB streams and optional HTTP SSE client (for remote sessions).
    - Add hidden activation gesture or settings entry; ensure accessibility labels and theming compliance.
    - Display `tracing` warnings/errors with severity badges and support token input for HTTP server.
  - Purpose: On-device diagnostics for support engineers.
  - _Leverage: Tasks 3–5 streams/services_
  - _Requirements: 2, 3, 5_
  - _Prompt: Role: Flutter UI engineer with observability focus | Task: Implement Debug Lab fulfilling requirement 5, integrating FRB + HTTP data, enabling parameter tweaks with latency feedback | Constraints: Keep file <500 lines by splitting widgets, respect Material accessibility | Success: QA can open Debug Lab, view live metrics, adjust thresholds and see confirmations_

- [ ] 7. Expand scripts, coverage gates, and CI evidence
  - Files: `scripts/pre-commit`, `scripts/coverage.sh`, `CODE_METRICS_REPORT.md`, `UAT_READINESS_REPORT.md`, `docs/TESTING.md`
  - Actions:
    - Integrate CLI harness + HTTP smoke checks into pre-commit (fail on stubs/TODOs in bridged layers).
    - Update coverage script to collect Rust + Dart metrics, enforce ≥80% overall and ≥90% on critical files.
    - Output artifacts (CLI logs, HTTP traces) referenced by UAT readiness docs; document workflows in `docs/TESTING.md`.
  - Purpose: Guarantee no untested code reaches UAT.
  - _Leverage: Tasks 1–6 outputs, existing scripts_
  - _Requirements: 1, 2, 3, 5, 6_
  - _Prompt: Role: DevOps/test engineer | Task: Enhance tooling per requirement 6 ensuring CI fails on coverage/stub gaps and documentation captures evidence | Constraints: Keep scripts POSIX-compliant, avoid flakiness, ensure reports are concise | Success: `./scripts/pre-commit` runs CLI + coverage, fails when thresholds unmet, documentation updated_

- [ ] 8. Documentation & knowledge base updates
  - Files: `docs/TESTING.md`, `docs/bridge_contracts.md`, `UAT_READINESS_REPORT.md`, `UAT_TEST_SCENARIOS.md`, `README.md`
  - Actions:
    - Document CLI usage, HTTP API (OpenAPI snippet), Debug Lab instructions, DI injection patterns.
    - Update UAT scenarios to include Debug Lab verification and fixture evidence capture.
    - Add troubleshooting section for stream errors and token auth.
  - Purpose: Ensure QA/support can operate new tooling autonomously.
  - _Leverage: Outputs from all tasks_
  - _Requirements: All_
  - _Prompt: Role: Technical writer with deep system knowledge | Task: Refresh docs to reflect new tooling and workflows so QA/support teams can self-serve | Constraints: Keep docs concise yet actionable, link to scripts, include token security guidance | Success: QA can follow docs to reproduce tests/logs without dev support_
