# Testing Documentation

## Overview

This project maintains comprehensive test coverage with automated quality gates enforced through pre-commit hooks. Testing follows a multi-layered strategy covering unit tests, integration tests, and widget tests for both Rust and Dart codebases.

## Test Coverage Requirements

**Minimum Coverage Targets**:
- **Overall Coverage**: 80% minimum
- **Critical Paths**: 90% minimum
  - `rust/src/context.rs` (AppContext)
  - `rust/src/error.rs` (Error types)
  - `lib/services/audio/` (AudioService)
  - `lib/services/error_handler/` (ErrorHandler)

**Current Coverage**: See `coverage/COVERAGE_REPORT.md` after running coverage script

## Quick Start

### Run All Tests

```bash
# Dart tests only
flutter test

# Rust tests only
cd rust && cargo test

# All tests (Dart + Rust)
flutter test && cd rust && cargo test

# All tests with coverage
./scripts/coverage.sh
```

### Generate Coverage Reports

```bash
# Full coverage with HTML reports
./scripts/coverage.sh

# Rust coverage only
./scripts/coverage.sh --rust-only

# Dart coverage only
./scripts/coverage.sh --dart-only

# Skip threshold enforcement
./scripts/coverage.sh --no-threshold

# Open HTML reports in browser
./scripts/coverage.sh --open
```

**Coverage Report Locations**:
- Rust HTML: `coverage/rust/index.html`
- Dart HTML: `coverage/dart/index.html`
- Unified Report: `coverage/COVERAGE_REPORT.md`

## Test Organization

### Rust Tests

```
rust/
├── src/
│   ├── context.rs           # Business logic unit tests (#[cfg(test)] mod tests)
│   ├── error.rs             # Error type unit tests
│   ├── audio/engine.rs      # Audio engine unit tests
│   └── calibration/
│       ├── procedure.rs     # Calibration logic tests
│       └── validation.rs    # Validation tests
└── tests/
    └── integration_test.rs  # FFI bridge integration tests
```

### Dart Tests

```
test/
├── services/
│   ├── audio_service_test.dart        # AudioServiceImpl unit tests
│   ├── permission_service_test.dart   # PermissionServiceImpl unit tests
│   └── error_handler_test.dart        # ErrorHandler unit tests
├── ui/
│   ├── screens/
│   │   ├── training_screen_test.dart      # TrainingScreen widget tests
│   │   └── calibration_screen_test.dart   # CalibrationScreen widget tests
│   └── widgets/
│       ├── error_dialog_test.dart         # ErrorDialog widget tests
│       ├── loading_overlay_test.dart      # LoadingOverlay widget tests
│       └── status_card_test.dart          # StatusCard widget tests
└── integration/
    └── audio_integration_test.dart    # End-to-end service integration tests
```

## Test Types and Strategies

### 1. Rust Unit Tests

**Purpose**: Test business logic in isolation

**Location**: `#[cfg(test)] mod tests` within source files

**Example: AppContext BPM Validation**

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_start_audio_validates_bpm_range() {
        let ctx = AppContext::new_test();

        // Test below minimum
        let result = ctx.start_audio(0);
        assert!(matches!(result, Err(AudioError::BpmInvalid { value: 0, min: 40, max: 240 })));

        // Test above maximum
        let result = ctx.start_audio(300);
        assert!(matches!(result, Err(AudioError::BpmInvalid { value: 300, .. })));

        // Test valid range
        let result = ctx.start_audio(120);
        assert!(result.is_ok() || matches!(result, Err(AudioError::HardwareError(_))));
    }

    #[test]
    fn test_prevents_double_start() {
        let ctx = AppContext::new_test();

        ctx.start_audio(120).ok(); // First start may fail on CI (no audio hardware)

        // Second start should return AlreadyRunning
        let result = ctx.start_audio(120);
        assert!(matches!(result, Err(AudioError::AlreadyRunning)) ||
                matches!(result, Err(AudioError::HardwareError(_))));
    }
}
```

**Running Rust Tests**:

```bash
cd rust

# Run all tests
cargo test

# Run with output
cargo test -- --nocapture

# Run specific test
cargo test test_start_audio_validates_bpm_range

# Run tests in specific module
cargo test context::tests
```

### 2. Rust Integration Tests

**Purpose**: Test full system flows across FFI boundary

**Location**: `rust/tests/integration_test.rs`

**Example: Audio Lifecycle**

```rust
#[tokio::test]
async fn test_full_audio_lifecycle() {
    let ctx = AppContext::new();

    // Start audio engine
    ctx.start_audio(120).expect("Failed to start audio");

    // Subscribe to classification stream
    let mut stream = ctx.classification_stream().await;

    // Stop audio engine
    ctx.stop_audio().expect("Failed to stop audio");

    // Verify stream closes
    tokio::time::timeout(Duration::from_secs(1), async {
        let result = stream.next().await;
        assert!(result.is_none());
    }).await.expect("Stream did not close");
}
```

**Running Integration Tests**:

```bash
cd rust
cargo test --test integration_test
```

### 3. Dart Service Unit Tests

**Purpose**: Test service layer with mocked dependencies

**Tools**: `flutter_test`, `mocktail`

**Example: AudioServiceImpl**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFFIBridge extends Mock implements FFIBridge {}
class MockErrorHandler extends Mock implements ErrorHandler {}

void main() {
  late MockFFIBridge mockBridge;
  late MockErrorHandler mockErrorHandler;
  late AudioServiceImpl service;

  setUp(() {
    mockBridge = MockFFIBridge();
    mockErrorHandler = MockErrorHandler();
    service = AudioServiceImpl(
      errorHandler: mockErrorHandler,
    );
  });

  test('startAudio throws AudioServiceException on error', () async {
    // Arrange
    when(() => mockBridge.startAudio(bpm: any(named: 'bpm')))
        .thenThrow(Exception('AudioError::StreamOpenFailed'));
    when(() => mockErrorHandler.translateAudioError(any()))
        .thenReturn('Unable to access audio hardware');

    // Act & Assert
    expect(
      () => service.startAudio(bpm: 120),
      throwsA(isA<AudioServiceException>()
          .having((e) => e.message, 'message', contains('audio hardware'))),
    );
  });

  test('getClassificationStream returns FFI stream', () {
    // Arrange
    final mockStream = Stream<ClassificationResult>.empty();
    when(() => mockBridge.classificationStream()).thenAnswer((_) => mockStream);

    // Act
    final stream = service.getClassificationStream();

    // Assert
    expect(stream, equals(mockStream));
    verify(() => mockBridge.classificationStream()).called(1);
  });
}
```

**Running Dart Unit Tests**:

```bash
# All tests
flutter test

# Specific test file
flutter test test/services/audio_service_test.dart

# With coverage
flutter test --coverage

# Watch mode (rerun on changes)
flutter test --watch
```

### 4. Dart Widget Tests

**Purpose**: Test UI behavior with mocked services

**Tools**: `flutter_test`, `mocktail`

**Example: TrainingScreen**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAudioService extends Mock implements IAudioService {}
class MockPermissionService extends Mock implements IPermissionService {}

void main() {
  late MockAudioService mockAudioService;
  late MockPermissionService mockPermissionService;

  setUp(() {
    mockAudioService = MockAudioService();
    mockPermissionService = MockPermissionService();
  });

  testWidgets('shows error dialog on audio start failure', (tester) async {
    // Arrange
    when(() => mockPermissionService.requestMicrophonePermission())
        .thenAnswer((_) async => PermissionStatus.granted);
    when(() => mockAudioService.startAudio(bpm: any(named: 'bpm')))
        .thenThrow(AudioServiceException(
          message: 'Audio hardware unavailable',
          originalError: 'StreamOpenFailed',
        ));

    // Act
    await tester.pumpWidget(MaterialApp(
      home: TrainingScreen(
        audioService: mockAudioService,
        permissionService: mockPermissionService,
      ),
    ));

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Audio hardware unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows permission denied dialog', (tester) async {
    // Arrange
    when(() => mockPermissionService.requestMicrophonePermission())
        .thenAnswer((_) async => PermissionStatus.denied);

    // Act
    await tester.pumpWidget(MaterialApp(
      home: TrainingScreen(
        audioService: mockAudioService,
        permissionService: mockPermissionService,
      ),
    ));

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Microphone Permission Required'), findsOneWidget);
  });
}
```

**Running Widget Tests**:

```bash
# All widget tests
flutter test test/ui/

# Specific screen
flutter test test/ui/screens/training_screen_test.dart

# With coverage
flutter test test/ui/ --coverage
```

### 5. Dart Integration Tests

**Purpose**: Test service layer with real FFI bridge (not mocked)

**Example: Service Integration**

```dart
void main() {
  test('AudioServiceImpl propagates FFI errors correctly', () async {
    final service = AudioServiceImpl(); // Real implementation

    // Invalid BPM should throw
    expect(
      () => service.startAudio(bpm: 0),
      throwsA(isA<AudioServiceException>()),
    );
  });

  test('PermissionServiceImpl handles all permission states', () async {
    final service = PermissionServiceImpl();

    // This will return actual permission status
    final status = await service.checkMicrophonePermission();

    expect(status, isIn([
      PermissionStatus.granted,
      PermissionStatus.denied,
      PermissionStatus.permanentlyDenied,
    ]));
  });
}
```

## Coverage Reporting

### Prerequisites

**Rust Coverage Tool** (choose one):

```bash
# Option 1: cargo-llvm-cov (recommended)
cargo install cargo-llvm-cov

# Option 2: cargo-tarpaulin
cargo install cargo-tarpaulin
```

**Dart Coverage Tool** (for HTML reports):

```bash
# Linux
sudo apt install lcov

# macOS
brew install lcov
```

### Generating Coverage

The `scripts/coverage.sh` script automates coverage generation:

```bash
#!/bin/bash
# Run Rust tests with coverage
cd rust
cargo llvm-cov --html --open

# Run Dart tests with coverage
cd ..
flutter test --coverage
lcov --list coverage/lcov.info

# Check thresholds
./scripts/check_coverage_threshold.sh
```

**Manual Coverage Commands**:

```bash
# Rust coverage (cargo-llvm-cov)
cd rust
cargo llvm-cov --html
cargo llvm-cov --text  # Terminal output
open target/llvm-cov/html/index.html

# Dart coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Coverage Thresholds

The coverage script enforces minimum thresholds:

```bash
# Critical paths (90% minimum):
# - rust/src/context.rs
# - rust/src/error.rs
# - lib/services/audio/audio_service_impl.dart
# - lib/services/error_handler/error_handler.dart

# Overall (80% minimum):
# - All non-generated code
# - Excluding UI widgets (70% acceptable)
```

**Bypassing Thresholds** (use sparingly):

```bash
./scripts/coverage.sh --no-threshold
```

## Pre-Commit Quality Gates

### What Gets Checked

The pre-commit hook (`.git/hooks/pre-commit`) runs automatically before each commit:

1. **Code Formatting**:
   - Dart: `dart format --set-exit-if-changed`
   - Rust: `cargo fmt -- --check`

2. **Linting**:
   - Dart: `flutter analyze` (zero warnings)
   - Rust: `cargo clippy -- -D warnings` (zero warnings)

3. **File Size**:
   - Source files: ≤ 500 lines (excluding tests)

4. **Function Size**:
   - Functions: ≤ 50 lines (warning, not blocking)

5. **Tests**:
   - All tests must pass: `flutter test && cargo test`

### Installing the Pre-Commit Hook

```bash
# Copy hook to .git/hooks/
cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Verify installation
.git/hooks/pre-commit
```

### Running Pre-Commit Checks Manually

```bash
# Run all checks
.git/hooks/pre-commit

# Run specific checks
dart format --set-exit-if-changed lib/ test/
flutter analyze
cargo fmt -- --check
cargo clippy -- -D warnings
```

### Bypassing Pre-Commit Hook

**Not recommended**, but available for emergencies:

```bash
git commit --no-verify
```

## Test Execution in CI/CD

### GitHub Actions Workflow

See `.github/workflows/test-coverage.yml` (if using CI):

```yaml
name: Test Coverage

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2

      - name: Setup Rust
        uses: actions-rs/toolchain@v1

      - name: Install coverage tools
        run: |
          cargo install cargo-llvm-cov
          sudo apt install lcov

      - name: Run tests with coverage
        run: ./scripts/coverage.sh

      - name: Upload coverage reports
        uses: codecov/codecov-action@v3
        with:
          files: coverage/rust/lcov.info,coverage/dart/lcov.info
```

## Debugging Tests

### Rust Test Debugging

**Print debugging**:

```rust
#[test]
fn test_with_output() {
    println!("Debug value: {:?}", some_value);
    // Run with: cargo test -- --nocapture
}
```

**Conditional logging**:

```rust
#[test]
fn test_with_logging() {
    env_logger::init();
    log::debug!("Debug message");
    // Run with: RUST_LOG=debug cargo test
}
```

### Dart Test Debugging

**Print debugging**:

```dart
test('test with output', () {
  print('Debug value: $someValue');
  // Output appears in test results
});
```

**Debugger**:

```bash
# Run with debugger in VS Code
# Set breakpoint, then F5 (Debug Test)
```

## Common Testing Patterns

### Testing Async Code (Rust)

```rust
#[tokio::test]
async fn test_async_function() {
    let result = async_function().await;
    assert!(result.is_ok());
}
```

### Testing Streams (Rust)

```rust
#[tokio::test]
async fn test_stream() {
    let mut stream = get_stream().await;

    let item = stream.next().await;
    assert!(item.is_some());
}
```

### Testing Async Code (Dart)

```dart
test('async function', () async {
  final result = await asyncFunction();
  expect(result, isNotNull);
});
```

### Testing Streams (Dart)

```dart
test('stream emits values', () async {
  final stream = getStream();

  expect(stream, emits(expectedValue));
  // Or with StreamMatcher:
  expect(stream, emitsInOrder([value1, value2, emitsDone]));
});
```

### Mocking with Mocktail

```dart
class MockService extends Mock implements IService {}

test('with mock', () {
  final mock = MockService();

  // Stub method
  when(() => mock.method(any())).thenReturn(result);

  // Verify call
  verify(() => mock.method(any())).called(1);
});
```

## Troubleshooting

### "Tests Pass Locally But Fail in CI"

**Common causes**:
- Hardware-dependent tests (audio device access)
- Timezone differences
- Race conditions in async tests

**Solution**: Use conditional compilation for hardware tests:

```rust
#[test]
#[cfg(not(ci))]  // Skip in CI
fn test_requiring_audio_hardware() {
    // ...
}
```

### "Coverage Report Shows 0% for File"

**Common causes**:
- File not imported by tests
- Conditional compilation excludes file
- Generated code (ignored by coverage)

**Solution**: Check if file is actually tested:

```bash
# Rust: Check test imports
cargo test --no-run --message-format=json | grep "file.rs"

# Dart: Check test coverage
flutter test --coverage
lcov --list coverage/lcov.info | grep file.dart
```

### "Pre-Commit Hook Fails on Formatting"

**Solution**: Auto-format before committing:

```bash
# Dart
dart format lib/ test/

# Rust
cargo fmt

# Then commit
git commit
```

### "Clippy Warnings Block Commit"

**Solution**: Fix warnings or add allow annotation:

```rust
#[allow(clippy::warning_name)]
fn function_with_acceptable_pattern() {
    // ...
}
```

## Best Practices

1. **Write Tests First** (TDD): Define expected behavior before implementation
2. **Test One Thing**: Each test should verify a single behavior
3. **Descriptive Names**: `test_start_audio_validates_bpm` not `test1`
4. **Arrange-Act-Assert**: Structure tests clearly
5. **Mock External Dependencies**: Services, FFI, hardware
6. **Test Error Paths**: Happy path + all error scenarios
7. **Avoid Test Interdependence**: Tests should run independently
8. **Use Test Helpers**: `AppContext::new_test()` for isolated instances
9. **Clean Up Resources**: Close streams, stop audio in teardown
10. **Maintain Coverage**: Add tests when adding features

## Resources

- **Rust Testing**: https://doc.rust-lang.org/book/ch11-00-testing.html
- **Flutter Testing**: https://docs.flutter.dev/testing
- **Mocktail Guide**: https://pub.dev/packages/mocktail
- **cargo-llvm-cov**: https://github.com/taiki-e/cargo-llvm-cov
- **Coverage Report**: `coverage/COVERAGE_REPORT.md` (generated)
