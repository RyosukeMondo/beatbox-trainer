# Design Document

## Overview
The multi-layer-quality-hardening design introduces deterministic tooling and observability spanning the native audio engine and Flutter UI. It adds a reusable Rust Engine Core (traits for audio input/output, classifier, telemetry), multiple front-ends (CLI harness, HTTP debug server, Flutter Debug Lab), and a strict dependency injection layer for Dart. flutter_rust_bridge streams become first-class pipelines, enabling CI, QA, and UAT to exercise the same logic via CLI fixtures, HTTP endpoints, or on-device screens.

## Steering Document Alignment

### Technical Standards (tech.md)
- Honors the 4-layer native stack (C++ Oboe → Rust → Java/Kotlin → Dart) while adding host-agnostic shims for desktop testing via trait-based abstraction in Rust (`AudioBackend` + `TimeSource`).
- Uses `tracing` for structured logging, `axum` for HTTP, `tokio` runtime gated to debug builds, and `flutter_rust_bridge` streams for cross-language contracts.
- Ensures zero allocations on the audio thread by relegating CLI/HTTP hooks to non-real-time worker threads.

### Project Structure (structure.md)
- Rust additions land in `rust/src/engine/` submodules (`backend/`, `cli/`, `http/`, `telemetry/`). CLI binary lives in `rust/src/bin/beatbox_cli.rs`. HTTP server behind feature flag `debug_http`.
- Dart DI container defined in `lib/di/service_locator.dart`; Debug Lab screen in `lib/ui/screens/debug_lab_screen.dart` with shared widgets under `lib/ui/widgets/debug/`.
- Docs updated in `docs/TESTING.md` and `docs/bridge_contracts.md`.

## Code Reuse Analysis

### Existing Components to Leverage
- **`rust/src/audio/engine.rs`**: Reused as the real-time loop; wrapped by new `EngineHandle` that exposes command channels to CLI/HTTP consumers.
- **`lib/services/audio/audio_service_impl.dart`**: Extended to subscribe to implemented FRB streams and forward to UI + Debug Lab; retains permission orchestration.
- **`test/` fixtures**: Existing Dart models reused to deserialize classification/calibration payloads from new streams.

### Integration Points
- **flutter_rust_bridge API**: Add stream methods (`classification_stream`, `calibration_stream`, `telemetry_stream`) and command RPCs for parameter tweaks.
- **Scripts / CI**: `./scripts/pre-commit` invokes CLI harness for golden tests and fails on stub detection. Coverage script aggregates new tooling outputs.
- **Docs**: `UAT_READINESS_REPORT.md` consumes CLI/HTTP logs for evidence.

## Architecture
The architecture centers on the Rust Engine Core providing three surfaces: (1) FFI/FRB API, (2) CLI entry point, (3) HTTP debug server. Each surface communicates via shared async channels and telemetry publishers. On Dart, DI ensures widgets consume abstract services. Debug Lab listens to the same streams plus SSE proxies from HTTP server when connected remotely.

### Modular Design Principles
- Separate `engine_core.rs` (business logic) from adapters (CLI, HTTP, FRB bridge).
- Each Dart service stays within ≤500 lines by splitting FRB adapters, domain services, and view models.
- Utilities (logging formatters, fixture loaders) extracted to `rust/src/util/` and `lib/utils/`.

```mermaid
graph TD
    subgraph Rust
    A[AudioEngine Core] --> B[Telemetry Publisher]
    A --> C[FRB API]
    A --> D[CLI Harness]
    A --> E[HTTP Debug Server]
    end
    subgraph Dart
    F[Service Locator] --> G[AudioServiceImpl]
    F --> H[DebugService]
    G --> I[Training Screen]
    H --> J[Debug Lab Screen]
    E --> K[SSE Client]
    C --> G
```

## Components and Interfaces

### Component 1: Rust Engine Core
- **Purpose:** Provide trait-based audio backend abstraction, run DSP pipeline, emit classification/calibration/telemetry events.
- **Interfaces:**
  - `trait AudioBackend { fn start(&self, cmd_rx, evt_tx); }` (impls: `OboeBackend`, `DesktopStubBackend`).
  - `EngineHandle::new(config) -> EngineHandle` exposing `fn subscribe(&self) -> EngineStreams` and `fn apply_params(&self, delta: ParamPatch)`.
- **Dependencies:** Existing `audio::engine`, `analysis::*`, `calibration::*`, `rtrb` queues.
- **Reuses:** reuses buffer pool, metronome modules.

### Component 2: CLI Harness (`beatbox_cli`)
- **Purpose:** Execute deterministic fixture workflows for DSP validation.
- **Interfaces:** Commands `classify`, `stream`, `dump-fixtures`, with `--fixture`, `--expect`, `--output` flags.
- **Dependencies:** Engine Core (desktop backend), `serde_json` for structured outputs, fixture loader utility.
- **Reuses:** Uses same `EngineHandle` as FRB.

### Component 3: HTTP Debug Server
- **Purpose:** Provide loopback HTTP + SSE endpoints for live inspection and parameter tweaks.
- **Interfaces:**
  - `GET /health` → `{ status, bpm, uptime }`
  - `GET /metrics` → engine stats
  - `GET /classification-stream` → SSE with JSON payloads
  - `POST /params` → apply `ParamPatch`
- **Dependencies:** `axum`, `tokio`, `tower`, shared `EngineHandle`.
- **Reuses:** Telemetry publisher for SSE; parameter schema from calibration module.

### Component 4: flutter_rust_bridge Streams
- **Purpose:** Deliver classification/calibration/telemetry events to Dart.
- **Interfaces:** FRB functions `Stream<ClassificationResult> classification_stream()`, `Stream<CalibrationState> calibration_stream()`, `Stream<TelemetryEvent> telemetry_stream()`; command RPC `void apply_params(ParamPatch)`.
- **Dependencies:** Engine Core channels, FRB codegen pipeline (`flutter_rust_bridge.yaml`).
- **Reuses:** Models defined in `rust/src/api.rs` mirrored in `lib/models/`.

### Component 5: Dart DI & Services
- **Purpose:** Manage service instances, expose FRB streams to UI.
- **Interfaces:**
  - `ServiceLocator` with `registerSingleton<T>()` and `resolve<T>()`.
  - `AudioServiceImpl` implements `IAudioService` with new stream getters and error propagation.
  - `DebugService` fetches HTTP endpoints and SSE proxies.
- **Dependencies:** `get_it` (or Riverpod), FRB bindings, `http` package for SSE fallback.
- **Reuses:** Existing service interfaces, permission manager.

### Component 6: Debug Lab Screen
- **Purpose:** UI dashboard for stream monitoring, parameter tweaking, log viewing.
- **Interfaces:** Widgets `ClassificationLogView`, `TelemetryChart`, `ParamSlider`, `SyntheticInputToggle`.
- **Dependencies:** AudioService streams, DebugService SSE (optional), `provider`/`riverpod` for state.
- **Reuses:** Shared UI components (theme, typography).

## Data Models

### Rust/Dart Shared Models
```
struct ClassificationResult {
    id: u64,
    sound: BeatboxSound,
    offset_ms: f32,
    confidence: f32,
    timestamp_ms: u64,
}

enum CalibrationState {
    Idle,
    Recording { sound: BeatboxSound, samples_captured: u8 },
    Completed { thresholds: ThresholdSet },
}

enum TelemetryEvent {
    BufferHealth { level: f32 },
    LatencySample { capture_ms: f32, render_ms: f32 },
    Warning { code: u32, message: String },
}

struct ParamPatch {
    centroid_threshold: Option<f32>,
    zcr_threshold: Option<f32>,
    bpm: Option<u16>,
}
```
Mirrored Dart classes live in `lib/models/` with `freezed` or manual `fromJson`/`toJson`.

### CLI Fixture Schema
```
struct FixtureSpec {
    name: String,
    input_wav: PathBuf,
    expected: Option<Vec<ExpectedEvent>>,
}

struct ExpectedEvent {
    sound: BeatboxSound,
    offset_ms: f32,
    tolerance_ms: f32,
}
```

## Error Handling

### Error Scenario 1: Stream Disconnection
- **Handling:** Engine core emits `TelemetryEvent::Warning` with `code=2001`; FRB propagates `AudioStreamFailure` exception; Dart services retry connection with exponential backoff.
- **User Impact:** Training UI shows toast “Live audio stream lost, reconnecting…” while Debug Lab indicates degraded state.

### Error Scenario 2: HTTP Debug Auth Failure
- **Handling:** `POST /params` validates session token; missing/invalid token returns `401` JSON payload, logged via `tracing::warn`.
- **User Impact:** Debug Lab shows inline error and prompts user to re-enter token; CLI remains unaffected.

### Error Scenario 3: CLI Fixture Mismatch
- **Handling:** CLI compares actual vs expected, prints diff summary, exits with code 2; CI pipeline fails accordingly.
- **User Impact:** Developers receive actionable diff (expected vs actual events) for the failing fixture.

## Testing Strategy

### Unit Testing
- Rust: unit tests for `ParamPatch` application, telemetry publisher, fixture loader; use `cargo test` on all platforms.
- Dart: unit tests for DI setup, service stream transformations, error mapping.

### Integration Testing
- CLI golden tests run via `cargo test --bin beatbox_cli -- --fixture=<fixtures>` comparing `.expect.json`.
- HTTP server integration tests using `tokio::test` calling endpoints with mock `EngineHandle`.
- FRB integration tests in Dart verifying stream payload decoding and error propagation with fake Rust bindings (via mocks) plus real FRB smoke tests on Android emulator in CI nightly.

### End-to-End Testing
- Full-stack tests triggered by `./scripts/coverage.sh` invoking CLI fixtures, HTTP endpoints, `flutter test` widget suites, and instrumentation tests that open Debug Lab, adjust sliders, and verify parameter effects (via screenshot tests/log assertions).
- UAT checklist references CLI + HTTP logs to prove no stubs remain.
