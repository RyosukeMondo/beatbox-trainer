# beatbox_trainer

A Flutter-based beatbox training application with real-time audio analysis, built with a modern architecture featuring dependency injection, typed error handling, and comprehensive testing.

## Architecture Overview

This project follows a layered architecture with strict separation of concerns:

- **Layer 1 (Oboe C++)**: Low-latency audio I/O
- **Layer 2 (Rust)**: Real-time audio processing with lock-free algorithms
- **Layer 3 (FFI Bridge)**: Type-safe Rust-Dart communication via flutter_rust_bridge
- **Layer 4 (Dart/Flutter)**: Service layer abstractions and reactive UI

Key architectural patterns:
- **Dependency Injection**: Services injected via constructor for testability
- **Typed Error Handling**: Custom error types with user-friendly translation
- **Service Abstractions**: Interface-based design for mockable dependencies
- **Lock-Free Audio Path**: Zero-allocation audio callback for <20ms latency

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed architecture documentation.

## Getting Started

### Prerequisites

- Flutter SDK (3.0+)
- Rust toolchain (for native audio processing)
- Android SDK (for mobile deployment)
- Android NDK r25c+ (for Android builds)
- cargo-ndk (for Rust cross-compilation)

### Development Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   cd rust && cargo build
   ```

3. Install the pre-commit hook for code quality enforcement:
   ```bash
   cp scripts/pre-commit .git/hooks/pre-commit
   chmod +x .git/hooks/pre-commit
   ```

### Building for Android

For complete Android build setup, including cargo-ndk installation, troubleshooting, and deployment, see **[docs/ANDROID_BUILD.md](docs/ANDROID_BUILD.md)**.

**Quick start for Android:**
```bash
# Install required tools
cargo install cargo-ndk
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android

# Build APK
flutter build apk

# Deploy to device
flutter install -d <device-id>
```

### Pre-Commit Quality Gates

This project uses a pre-commit hook to enforce code quality standards. The hook automatically runs before each commit and checks:

- **Code Formatting**: Dart code must be formatted with `dart format`, Rust code with `cargo fmt`
- **Linting**: Flutter analyzer and Clippy must pass with no warnings
- **File Size**: Source files must not exceed 500 lines (excluding tests)
- **Function Size**: Functions should not exceed 50 lines (warning only)
- **Tests**: All tests must pass

If any check fails, the commit will be blocked. You can see detailed error messages to help fix the issues.

To bypass the hook (not recommended):
```bash
git commit --no-verify
```

### Running Tests

For comprehensive testing instructions, see [docs/TESTING.md](docs/TESTING.md).

**Quick Start:**

```bash
# Run all tests (Rust + Dart)
flutter test && cd rust && cargo test

# Run with coverage
./scripts/coverage.sh
```

### Test Coverage

The project uses comprehensive test coverage reporting for both Rust and Dart code.

**Quick Start:**

```bash
# Run all coverage (Rust + Dart)
./scripts/coverage.sh

# Rust coverage only
./scripts/coverage.sh --rust-only

# Dart coverage only
./scripts/coverage.sh --dart-only

# Generate reports without threshold enforcement
./scripts/coverage.sh --no-threshold

# Open HTML reports in browser
./scripts/coverage.sh --open
```

**Coverage Thresholds:**
- Overall coverage: 80% minimum
- Critical paths: 90% minimum (AppContext, ErrorHandler, AudioService)

**Requirements:**
- `cargo-llvm-cov` for Rust: `cargo install cargo-llvm-cov`
- `lcov` for Dart HTML reports (optional but recommended):
  - Linux: `sudo apt install lcov`
  - macOS: `brew install lcov`

**Reports:**
- Rust HTML Report: `coverage/rust/index.html`
- Dart HTML Report: `coverage/dart/index.html`
- Unified Report: `coverage/COVERAGE_REPORT.md`

The coverage script automatically:
- Runs all tests with instrumentation
- Generates HTML and text reports
- Enforces coverage thresholds
- Identifies files below threshold
- Provides actionable improvement suggestions

### Code Quality Metrics

The project enforces the following quality standards:

- Maximum file size: 500 lines (excluding tests)
- Maximum function size: 50 lines (guideline)
- Test coverage: 80% overall, 90% for critical paths
- Zero unwrap/expect calls in production code
- Zero global state in business logic

## Diagnostics & Observability Tooling

- **CLI Harness (`beatbox_cli`)** – Deterministically drives the DSP from WAV
  fixtures so QA can produce auditable JSON transcripts. Typical commands:
  `cargo run -p beatbox_cli classify --fixture basic_hits --expect fixtures/basic_hits.expect.json --output ../logs/smoke/classify_basic_hits.json`.
  Fixture WAV/expectation pairs live under `rust/fixtures/`; see
  [docs/TESTING.md](docs/TESTING.md#cli-fixture-harness-beatbox_cli) for
  regeneration tips and evidence-handling requirements.
- **HTTP Debug/Control Server** – Available in debug/profile builds via the
  `debug_http` Cargo feature. Endpoints (`/health`, `/metrics`,
  `/classification-stream`, `/params`) bind to `127.0.0.1:8787` and require the
  token from `BEATBOX_DEBUG_TOKEN` (default `beatbox-debug`). A trimmed OpenAPI
  snippet lives in [docs/TESTING.md](docs/TESTING.md#debug-http-control-server-feature-debug_http).
- **Debug Lab Screen** – Hidden settings entry (tap the build number 5×) that
  visualizes FRB streams, mirrors the HTTP SSE feed, and sends live
  `ParamPatch` updates. Use it to correlate headset captures, CLI fixture
  results, and HTTP payloads. More detailed operator docs are under
  [Debug Lab Workflows](docs/TESTING.md#debug-lab-workflows).

## Dependency Injection Patterns

The app relies on `GetIt` for service location (`lib/di/service_locator.dart`).

- Call `await setupServiceLocator(router)` before `runApp` to register
  `IAudioService`, `IPermissionService`, `ISettingsService`, `IStorageService`,
  `INavigationService`, and Debug Lab providers. Services are lazy singletons
  and share the same `ErrorHandler` instance for consistent translation.
- In widget tests, invoke `resetServiceLocator()` inside `setUp`/`tearDown`
  blocks, then register mocks: `getIt.registerSingleton<IAudioService>(MockAudioService());`.
- Screens consume services via constructor injection (see
  `TrainingScreen({required IAudioService audioService, ...})`), making it easy
  to supply stubs in integration tests or to drive the Debug Lab without
  touching device hardware.

For the full FRB and Flutter contract (streams, payload shapes, error codes),
consult [docs/bridge_contracts.md](docs/bridge_contracts.md).

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Rust Documentation](https://doc.rust-lang.org/)
