# Requirements Document: Code Quality Refactoring

## Introduction

This specification addresses critical code quality, architectural, and testability issues identified in the comprehensive code audit conducted on 2025-11-13. The current codebase violates multiple SOLID principles, contains testability blockers (global state, hard dependencies), lacks error handling infrastructure, and has significant code duplication. This refactoring will establish a maintainable, testable architecture that aligns with professional development standards while preserving the real-time audio performance guarantees that are core to the product.

**Value Proposition**: Reducing technical debt, enabling comprehensive test coverage (target: 80%), preventing production crashes (eliminating panic risks), and accelerating future feature development through clean architecture patterns.

## Alignment with Product Vision

This refactoring directly supports the product principles outlined in product.md:

1. **Uncompromising Real-Time Performance**: Refactoring will maintain zero-allocation audio path while making non-audio code testable through dependency injection
2. **Transparency Over Black Boxes**: Custom error types with error codes make system behavior more interpretable and debuggable
3. **Native-First Architecture**: Enhancing the Rust FFI layer with proper abstractions while preserving low-latency guarantees
4. **Progressive Complexity**: Establishing modular architecture enables easier feature additions without increasing coupling

The refactoring enables reliable scaling as the product grows from 3 sound categories to 8+ categories and eventually user-defined sounds.

## Requirements

### Requirement 1: Eliminate Global State Testability Blockers

**User Story**: As a developer, I want to unit test Rust backend components in isolation, so that I can verify correctness without side effects and run tests in parallel.

#### Acceptance Criteria

1. WHEN rust backend modules are tested THEN the system SHALL NOT depend on global static variables for core business logic
2. WHEN multiple tests execute in parallel THEN the system SHALL NOT experience race conditions or shared state contamination
3. WHEN testing audio engine lifecycle THEN the system SHALL support dependency injection for mocks and stubs
4. IF a test requires audio engine state THEN the system SHALL provide an injectable `AudioContext` struct instead of global statics
5. WHEN tests complete THEN the system SHALL properly cleanup resources without requiring process restart

**Current Violations**:
- `rust/src/api.rs` lines 25-43: 5 global `Lazy<Arc<Mutex<...>>>` variables
- Cannot mock or stub dependencies
- Tests cannot run in parallel safely
- No way to inject test doubles

### Requirement 2: Implement Comprehensive Error Handling Infrastructure

**User Story**: As a developer, I want structured error types with error codes, so that I can handle failures appropriately and users receive meaningful feedback.

#### Acceptance Criteria

1. WHEN an error occurs in Rust code THEN the system SHALL return a custom error enum instead of `Result<T, String>`
2. WHEN errors are propagated across FFI boundary THEN the system SHALL include error codes and context information
3. WHEN errors reach the UI layer THEN the system SHALL translate technical errors to user-friendly messages
4. IF a lock is poisoned or panic occurs THEN the system SHALL recover gracefully instead of crashing
5. WHEN errors are logged THEN the system SHALL use structured JSON format with timestamp, level, service name, and context fields
6. WHEN validation fails THEN the system SHALL provide specific error details (e.g., "BPM 300 exceeds maximum 240" vs "Invalid BPM")

**Current Violations**:
- All Rust functions return `Result<T, String>`
- 11+ `.unwrap()` calls that can panic
- Raw technical errors shown to users
- No error codes or hierarchy

### Requirement 3: Enforce Dependency Injection Pattern

**User Story**: As a developer, I want all external dependencies injected through constructors, so that I can swap implementations for testing and maintain loose coupling.

#### Acceptance Criteria

1. WHEN Dart screens are created THEN the system SHALL inject audio service abstractions instead of directly importing `api.dart`
2. WHEN Rust components are initialized THEN the system SHALL receive dependencies via constructor parameters
3. WHEN testing UI components THEN the system SHALL support mock service implementations
4. IF a component needs audio engine access THEN the system SHALL use an `AudioService` interface with injectable concrete implementations
5. WHEN permission handling is needed THEN the system SHALL use an injectable `PermissionService` abstraction

**Current Violations**:
- All Dart screens directly import concrete `../../bridge/api.dart`
- No service layer or repository pattern
- Hard-coded dependencies throughout
- Cannot test UI without real audio engine

### Requirement 4: Extract Reusable UI Components and Utilities

**User Story**: As a developer, I want shared UI patterns extracted into reusable components, so that I reduce duplication and ensure consistent behavior.

#### Acceptance Criteria

1. WHEN displaying error dialogs THEN the system SHALL use a shared `ErrorDialog` widget instead of duplicating AlertDialog code
2. WHEN showing loading states THEN the system SHALL use a shared `LoadingIndicator` widget
3. WHEN decorating containers THEN the system SHALL use shared decoration utilities instead of repeating BoxDecoration patterns
4. WHEN formatting display strings THEN the system SHALL use utility functions in a `DisplayFormatter` class
5. WHEN code duplication is measured THEN the system SHALL reduce duplicated lines by at least 100 lines (current: ~150 lines duplicated)

**Current Violations**:
- Error dialog pattern repeated 6+ times
- Loading indicator boilerplate duplicated 4+ times
- Container decoration patterns repeated 5+ times
- Permission handling logic duplicated

### Requirement 5: Refactor Oversized Functions

**User Story**: As a developer, I want functions under 50 lines, so that I can understand, test, and maintain code more easily.

#### Acceptance Criteria

1. WHEN measuring function length THEN the system SHALL have no functions exceeding 50 lines
2. WHEN `AudioEngine::start()` is analyzed THEN the system SHALL be refactored into helper functions (callback creation, stream setup, thread spawning)
3. WHEN widget builders are analyzed THEN the system SHALL extract complex widget trees into separate methods or widgets
4. IF a function has multiple responsibilities THEN the system SHALL split it according to Single Responsibility Principle
5. WHEN refactoring is complete THEN the system SHALL maintain identical behavior with improved testability

**Current Violations**:
- `AudioEngine::start()`: 112 lines
- `_buildProgressContent()`: 169 lines
- `_buildClassificationDisplay()`: 90 lines

### Requirement 6: Split Oversized Files

**User Story**: As a developer, I want files under 500 lines, so that I can navigate and understand codebases more efficiently.

#### Acceptance Criteria

1. WHEN measuring file length THEN the system SHALL have no source files exceeding 500 lines (excluding test code)
2. WHEN `calibration/procedure.rs` is analyzed THEN the system SHALL split into separate modules (validation, progress, finalization)
3. WHEN `analysis/features.rs` is analyzed THEN the system SHALL split feature computation into separate modules per feature type
4. IF a file contains multiple logical components THEN the system SHALL organize into sub-modules
5. WHEN files are split THEN the system SHALL maintain public API compatibility

**Current Violations**:
- `calibration/procedure.rs`: 581 lines
- `analysis/features.rs`: 576 lines
- `calibration_screen.dart`: 464 lines (near limit)
- `training_screen.dart`: 452 lines (near limit)

### Requirement 7: Establish Pre-Commit Quality Gates

**User Story**: As a developer, I want automated quality checks before commits, so that code quality violations are prevented from entering the repository.

#### Acceptance Criteria

1. WHEN committing code THEN the system SHALL automatically run linting checks and reject commits with violations
2. WHEN committing code THEN the system SHALL automatically run formatters and reject improperly formatted code
3. WHEN committing code THEN the system SHALL run all tests and reject commits with test failures
4. IF code exceeds size limits THEN the system SHALL reject the commit with a clear error message
5. WHEN pre-commit hooks are configured THEN the system SHALL check:
   - `flutter analyze` passes
   - `dart format --set-exit-if-changed` passes
   - `cargo fmt -- --check` passes
   - `cargo clippy -- -D warnings` passes
   - `flutter test` passes
   - No files > 500 lines
   - No functions > 50 lines

**Current Violations**:
- No pre-commit hooks configured
- No automated quality enforcement
- Manual quality checks only

### Requirement 8: Achieve Minimum Test Coverage

**User Story**: As a developer, I want 80% minimum test coverage, so that I can confidently refactor and detect regressions early.

#### Acceptance Criteria

1. WHEN measuring test coverage THEN the system SHALL achieve at least 80% line coverage overall
2. WHEN measuring critical path coverage THEN the system SHALL achieve at least 90% coverage for audio engine, calibration, and classification modules
3. WHEN Dart code is analyzed THEN the system SHALL have unit tests for business logic (services, utilities)
4. WHEN Dart UI is analyzed THEN the system SHALL have widget tests for screens and custom widgets
5. WHEN Rust code is analyzed THEN the system SHALL have unit tests for all public APIs in `api.rs`
6. IF global state is required for FFI THEN the system SHALL provide test helpers that initialize state safely

**Current Violations**:
- Dart: 0% coverage (no unit/widget tests)
- Rust api.rs: Untestable due to global state
- Overall: ~40% coverage (backend DSP only)

## Non-Functional Requirements

### Code Architecture and Modularity

- **Single Responsibility Principle**: Each module has one clear purpose (e.g., `PermissionService` only handles permissions, `AudioService` only wraps audio API)
- **Modular Design**: Services, utilities, and UI components are isolated and reusable
- **Dependency Management**: All external dependencies injected via constructors or factory patterns
- **Clear Interfaces**: Abstract interfaces defined for all services (e.g., `abstract class IAudioService`)
- **Loose Coupling**: UI components depend on abstractions, not concrete implementations
- **High Cohesion**: Related functionality grouped together (e.g., all error types in `errors.rs`)

### Performance

- **No Performance Regression**: Refactoring SHALL NOT increase audio latency beyond current < 20ms target
- **Real-Time Safety Preserved**: Audio callback SHALL remain allocation-free and lock-free after refactoring
- **DI Overhead**: Dependency injection SHALL add < 1ms overhead to startup time
- **Memory Footprint**: Refactored code SHALL NOT increase memory usage by more than 5MB
- **Build Time**: Refactoring SHALL NOT increase clean build time by more than 10%

### Security

- **Error Information Disclosure**: Error messages SHALL NOT expose sensitive implementation details to end users
- **Input Validation**: All user inputs (BPM, audio samples) SHALL be validated before processing
- **Panic Safety**: Production code SHALL contain zero `.unwrap()` or `.expect()` calls without documented safety invariants
- **Thread Safety**: Shared state SHALL be protected by appropriate synchronization primitives or lock-free patterns

### Reliability

- **Graceful Degradation**: System SHALL handle errors without crashing (eliminate panic risks)
- **Resource Cleanup**: All resources (audio streams, threads, locks) SHALL be properly cleaned up on error paths
- **Error Recovery**: System SHALL attempt recovery from transient failures (e.g., retry audio stream initialization)
- **Deterministic Behavior**: System SHALL produce identical results for identical inputs (no undefined behavior)

### Maintainability

- **Code Readability**: Functions under 50 lines, files under 500 lines
- **Documentation**: All public APIs documented with doc comments
- **Change Impact**: Localized changes (modifying one service doesn't require changes across multiple screens)
- **Onboarding**: New developers can understand module boundaries within 1 day
- **Debugging**: Structured logging enables tracing issues through the system

### Testability

- **Unit Test Isolation**: All components testable without external dependencies
- **Mock Support**: All services have mockable interfaces
- **Test Speed**: Unit test suite completes in < 10 seconds
- **Test Reliability**: Tests produce deterministic results (no flaky tests)
- **Coverage Metrics**: Automated coverage reporting integrated into CI/CD

### Compatibility

- **Backward Compatibility**: FFI bridge API remains compatible with existing Dart code during refactoring
- **Real-Time Compatibility**: Refactored audio path maintains Oboe real-time guarantees
- **Platform Support**: Changes SHALL NOT break Android 7.0+ (API 24+) compatibility
- **Architecture Support**: ARM64-v8a and armeabi-v7a builds remain functional

## Success Metrics

- **Testability**: 0 global state variables in core business logic (currently 5)
- **Test Coverage**: 80% overall, 90% for critical paths (currently ~40%)
- **Code Duplication**: < 50 duplicated lines (currently ~150)
- **Error Handling**: 100% of error paths return typed errors (currently 0%)
- **Panic Safety**: 0 unwrap/expect calls in production code (currently 11+)
- **Function Size**: 0 functions > 50 lines (currently 3)
- **File Size**: 0 source files > 500 lines excluding tests (currently 2)
- **Build Time**: Clean build < 2 minutes (monitor for regression)
- **Performance**: Audio latency remains < 20ms (no regression)
- **Quality Gates**: 100% of commits pass pre-commit checks after setup

## Out of Scope

The following are explicitly OUT OF SCOPE for this refactoring:

- **New Features**: No new sound categories, difficulty levels, or UI capabilities
- **Performance Optimization**: No improvements to DSP algorithms or audio latency beyond maintaining current performance
- **Platform Expansion**: No iOS, Windows, or web platform support
- **UI/UX Redesign**: No changes to visual design or user workflows
- **Persistent Storage**: No database or file-based calibration profile saving
- **Analytics**: No usage tracking or telemetry infrastructure
- **Internationalization**: No multi-language support
- **Accessibility**: No screen reader or accessibility enhancements
- **Background Operation**: No wake lock or audio focus management changes

This refactoring focuses exclusively on internal code quality, architecture, and testability improvements that enable future feature development.
