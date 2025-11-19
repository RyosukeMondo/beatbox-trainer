# Requirements Document

## Introduction
The diagnostics-and-testability-platform initiative equips Beatbox Trainer with end-to-end validation and debugging utilities spanning C++ audio entrypoints, Rust DSP, the JNI bridge, and Flutter UI facades. It removes the current dependence on on-device manual debugging by providing deterministic harnesses, synthetic/mocked audio inputs, and observability surfaces reachable from local desktops. This enables developers to iterate quickly, reproduce regressions, and validate latency-sensitive changes before committing.

## Alignment with Product Vision
Improving instrumentation and automated coverage upholds the product principles of transparency, low-latency fidelity, and native-first control. By enabling deterministic harnesses and rapid debug tooling, we can guarantee the "uncompromising real-time performance" promise, document calibration transparency, and keep the stack lightweight without depending on opaque vendor profilers. Faster iteration also accelerates delivery on future rhythm-training features highlighted in the steering docs.

## Requirements

### Requirement 1

**User Story:** As a DSP engineer, I want to execute the full audio pipeline in unit and integration tests with recorded or synthetic PCM data so that I can verify latency, classification, and quantization logic without redeploying to a device.

#### Acceptance Criteria

1. WHEN a developer runs `flutter test` or `cargo test` THEN the suite SHALL include harnesses that feed canned PCM buffers through C++, Rust, JNI, and Dart layers, asserting on timing, classification, and error propagation.
2. IF a test provides sample data (fixtures, mocks, or stubs) THEN the system SHALL allow swapping between real microphone input, pre-recorded WAV fixtures, and algorithmic noise via dependency injection.
3. WHEN coverage reports are generated AND include these harnesses THEN the toolchain SHALL surface latency, classification, and quantization metrics for each fixture in test logs artifacts.

### Requirement 2

**User Story:** As a mobile developer, I want controllable CLI and HTTP debug entrypoints that exercise the engine, emit structured logs, and expose health metrics so that I can debug bridge failures or timing regressions without a running Flutter UI.

#### Acceptance Criteria

1. WHEN the new CLI command is invoked with flags (e.g., `--fixture`, `--loopback`, `--metrics-port`) THEN the native layers SHALL start the audio engine, publish metrics (latency, buffer occupancies, classification tallies), and exit deterministically or keep streaming until interrupted.
2. IF the HTTP debug server is enabled THEN it SHALL provide at least `/healthz`, `/metrics`, and `/trace` endpoints returning JSON or Prometheus-friendly payloads that include latest classification decisions, latency histograms, and JNI bridge status.
3. WHEN the CLI or HTTP tooling encounters an error THEN the layers SHALL emit structured, timestamped logs that can be tailed locally and attached to bug reports without needing device logcat access.

### Requirement 3

**User Story:** As a QA engineer, I want mocked bridge adapters and Android instrumentation hooks so that I can validate Dart↔Rust contracts and JNI lifecycle events inside CI without attaching a device.

#### Acceptance Criteria

1. WHEN integration tests run in CI THEN mocked bridge adapters SHALL simulate flutter_rust_bridge streams, exercising Dart controllers with deterministic sequences and asserting UI state updates.
2. IF JNI lifecycle hooks (load/unload, permission handshake) change THEN instrumentation tests SHALL detect regressions by verifying ordered callbacks and failure handling paths.
3. WHEN CI completes THEN artifacts SHALL include consolidated logs (Dart, Rust, JNI) and failing test repro commands for any bridge-related failure.

## Non-Functional Requirements

### Code Architecture and Modularity
- **Single Responsibility Principle**: Separate harness configuration, fixture loading, telemetry collection, and UI bindings into dedicated modules across Dart, Rust, and Android layers.
- **Modular Design**: Provide reusable fixture/mocking utilities shared by both CLI and automated test suites to avoid duplicated infrastructure.
- **Dependency Management**: Introduce new dev-only dependencies (e.g., HTTP server crates, Dart mocks) behind feature flags so production builds remain lean.
- **Clear Interfaces**: Document the contracts for audio sources, bridge adapters, and telemetry sinks to ease future extension (e.g., WebSocket dashboards).

### Performance
- Harness executions SHALL process at least 1 minute of audio fixtures in < 10 seconds on a mid-range laptop.
- CLI/debug server SHALL not exceed +5ms latency overhead compared to production audio path when instrumentation is disabled.

### Security
- Expose CLI and HTTP debug server only in development builds with authentication disabled by default but guard against accidental production shipping via build flags and CI checks.
- Prevent debug endpoints from writing arbitrary files or leaking user audio data without explicit opt-in.

### Reliability
- Automated tests SHALL reach ≥85% coverage for `rust/src/audio/`, `rust/src/analysis/`, `lib/services/audio/`, and any new harness modules.
- CLI/debug server SHALL include watchdogs to tear down native resources cleanly to avoid audio device starvation.

### Usability
- Provide developer docs in `docs/guides/qa/` describing how to run fixtures, interpret metrics, and attach logs to issues.
- Offer sample commands and IDE launch configurations so engineers can trigger harness runs or start the debug server with one click.
