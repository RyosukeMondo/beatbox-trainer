# Requirements Document

## Introduction
The multi-layer-quality-hardening initiative elevates Beatbox Trainer's Android stack (C++ Oboe → Rust DSP → Java/Kotlin JNI → Dart/Flutter UI) to an industry-grade state where every layer is testable, observable, and debuggable without stubs. It eliminates unfinished FFI streams, introduces deterministic native harnesses (CLI + HTTP debug server), and adds comprehensive logging plus a Flutter Debug Lab so QA and UAT teams can validate functionality before user acceptance testing.

## Alignment with Product Vision
These enhancements uphold the "Uncompromising Real-Time Performance" and "Transparency Over Black Boxes" principles by making the native-first architecture measurable from any layer. They allow beatboxers to trust timing feedback because engineers can now reproduce, inspect, and certify every pathway—from Oboe callbacks to UI widgets—under realistic conditions, ensuring sub-20 ms latency with full accountability.

## Requirements

### Requirement 1: Deterministic Native CLI Harness
**User Story:** As a QA engineer, I want to run the Rust DSP pipeline from the command line with canned PCM fixtures, so that I can validate sound classification and timing behavior without deploying the Flutter app.

#### Acceptance Criteria
1. WHEN I execute `cargo run -p beatbox_cli classify --fixture=<name>` THEN the CLI SHALL load the PCM sample, run the full DSP/classifier pipeline, and print structured JSON containing detected sound classes, onset timestamps, and quantization deltas.
2. IF a fixture defines expected labels/timing in an adjacent `.expect.json` file THEN the CLI SHALL compare actual results and exit with a non-zero status when mismatches occur.
3. WHEN the CLI runs on macOS/Linux desktops THEN it SHALL use a cross-platform audio-engine stub that mirrors Android behavior so fixtures are identical regardless of host OS.

### Requirement 2: HTTP Debug & Control Server
**User Story:** As a developer, I want a built-in HTTP debug server that exposes the engine’s runtime state and tuning parameters, so that I can inspect and tweak the system from a browser or `curl` while the app runs on-device.

#### Acceptance Criteria
1. WHEN the app launches in debug mode AND the debug server flag is enabled THEN a local HTTP endpoint (`http://127.0.0.1:<port>`) SHALL expose `/health`, `/metrics`, `/classification-stream`, and `/params` routes documented in OpenAPI.
2. IF I POST updated calibration or classifier thresholds to `/params` THEN the server SHALL apply them at runtime and emit confirmation events to both HTTP clients and the Dart Debug Lab UI within 200 ms.
3. WHEN I GET `/classification-stream` THEN the server SHALL stream Server-Sent Events (SSE) mirroring the flutter_rust_bridge stream payloads used by the UI so remote observers can watch live detections.

### Requirement 3: Fully Implemented FRB Streams & Cross-Layer Contracts
**User Story:** As a training-mode user, I want the calibration and classification streams wired end-to-end without stub exceptions, so that the training screen never crashes and always shows live feedback.

#### Acceptance Criteria
1. WHEN Dart calls `audioService.getClassificationStream()` THEN the method SHALL return a broadcast stream backed by flutter_rust_bridge that relays Rust `ClassificationResult` structs with no `UnimplementedError` branches.
2. WHEN the Rust engine emits calibration phase updates THEN FRB SHALL serialize them through the JNI bridge and Dart SHALL render state transitions within 100 ms of emission.
3. IF the native layer disconnects or errors THEN the streams SHALL surface domain-specific exceptions (`AudioStreamFailure`, `CalibrationTimeout`) with actionable error codes rather than generic failures.

### Requirement 4: Injectable Services & Router Configuration
**User Story:** As a Flutter test author, I want to inject mock services and routers into widgets, so that widget tests can run without spinning up real audio hardware or permissions prompts.

#### Acceptance Criteria
1. WHEN `main()` boots the app THEN a DI container (e.g., `GetIt` or Riverpod provider graph) SHALL register every `I*Service` implementation exactly once and expose factory constructors (e.g., `TrainingScreen.create()`) that resolve dependencies from the container instead of instantiating concretes.
2. IF I construct `TrainingScreen` or `CalibrationScreen` in a test and pass fake service implementations THEN the widget SHALL use the injected mocks without touching real hardware APIs.
3. WHEN `MyApp` is created with a custom `GoRouter` THEN the app SHALL render using that router, enabling route-specific tests without mutating global state.

### Requirement 5: Debug Lab UI & Telemetry Surfaces
**User Story:** As a support engineer, I want an in-app Debug Lab screen with live metrics, stream inspection, and parameter sliders, so that I can triage issues on physical devices without connecting external tooling.

#### Acceptance Criteria
1. WHEN I open the Debug Lab from the hidden menu THEN I SHALL see live classification logs, timing offsets, and audio buffer health sourced from the same FRB streams used by production screens.
2. IF I change a parameter slider (e.g., centroid threshold) or toggle synthetic input playback THEN the adjustment SHALL propagate to the Rust engine within 150 ms and the UI SHALL show confirmation.
3. WHEN a warning or error occurs in Rust (`tracing` warnings) THEN the message SHALL appear in the Debug Lab log view with timestamps and severity levels, matching entries written to persistent debug logs.

### Requirement 6: Coverage & Test Gating for Multi-Layer Quality
**User Story:** As a release manager, I want automated gates ensuring there are no untested features or stubs before UAT, so that builds are blocked unless the CLI, HTTP server, FRB streams, and debug UI are fully exercised.

#### Acceptance Criteria
1. WHEN `./scripts/coverage.sh` runs with default settings THEN it SHALL combine Rust (`cargo tarpaulin` or cov tooling) and Dart (`flutter test --coverage`) results, enforcing ≥80 % overall coverage and ≥90 % for `rust/src/context.rs`, `rust/src/error.rs`, and `lib/services/audio/`.
2. IF any `TODO`, `FIXME`, or stub implementation exists in the bridged pathways (Dart services, Rust FRB API, Java JNI) THEN the pre-commit gate SHALL fail with a descriptive message referencing the offending file and line.
3. WHEN UAT readiness reports are generated (`UAT_READINESS_REPORT.md`) THEN they SHALL include automated evidence (CLI fixture logs, HTTP trace captures, coverage summary) generated by the new tooling.

## Non-Functional Requirements

### Code Architecture and Modularity
- **Dependency Direction**: UI widgets depend on interfaces only; implementations live in `lib/di/` wiring modules.
- **Bridge Contracts**: FRB schemas and JNI structs must be versioned and documented in `docs/bridge_contracts.md` with checksum validation in CI.
- **Isolation**: CLI, HTTP server, and Debug Lab share engine APIs through reusable Rust traits so adding new front-ends does not require duplicating DSP logic.

### Performance
- HTTP debug endpoints must add <2 ms overhead per classification event in debug builds and be fully disabled in release builds.
- CLI fixture runs must process one minute of audio in <5 s on a 2023 MacBook Pro (M2) to keep feedback loops tight.

### Security
- Debug HTTP server binds to loopback only and requires an opt-in flag; sensitive endpoints require a randomly generated session token printed to the debug console.
- Logs must redact microphone permission prompts and any personally identifiable session names before persistence/export.

### Reliability
- All new services must expose health probes (CLI exit codes, HTTP `/health`, FRB heartbeat) that CI can poll; absence of heartbeats should fail builds.
- Debug Lab should gracefully degrade (show “native stream unavailable” states) without crashing when native layers restart or are missing.

### Usability
- Debug Lab controls need accessibility labels and must operate with screen readers.
- CLI and HTTP APIs require human-readable docs (`docs/TESTING.md`, OpenAPI spec) and copy-pastable examples so QA can adopt them without developer assistance.
