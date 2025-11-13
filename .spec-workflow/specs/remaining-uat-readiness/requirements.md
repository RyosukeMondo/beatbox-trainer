# Requirements Document: UAT Readiness - Code Quality Remediation

## Introduction

This specification addresses the 58 code quality issues identified in the comprehensive audit report, prioritizing Critical and High severity issues that block production readiness. The focus is on establishing testability, enforcing SOLID principles, and meeting code metrics standards to ensure the Beatbox Trainer application is production-ready for User Acceptance Testing (UAT).

The remediation follows a three-phase approach focusing on Week 1-3 action items from the audit:
- **Phase 1 (Week 1)**: Critical testability blockers preventing core functionality
- **Phase 2 (Week 2-3)**: High priority SOLID violations impacting maintainability
- **Phase 3 (Week 4-5)**: Medium priority code quality improvements

This work directly supports the product's uncompromising performance and transparency principles by establishing a clean, testable, and maintainable codebase foundation.

## Alignment with Product Vision

The code quality remediation aligns with core product principles:

1. **Uncompromising Real-Time Performance**: Refactoring the AppContext god object and implementing lock-free patterns ensures deterministic execution without sacrificing clean architecture.

2. **Transparency Over Black Boxes**: Breaking down complex functions and establishing clear separation of concerns makes the codebase interpretable and debuggable - mirroring the product's heuristic DSP philosophy.

3. **Native-First Architecture**: Implementing proper dependency injection and abstraction layers strengthens the 4-layer stack (Dart → Rust → C++ Oboe) without introducing performance overhead.

4. **Progressive Complexity**: The phased approach mirrors the product's progressive difficulty levels - start with critical fixes, then layer on architectural improvements.

By addressing testability blockers and SOLID violations, we enable the comprehensive testing required to meet the product's success metrics (90%+ classification accuracy, <20ms latency, 0 jitter).

## Requirements

### Requirement 1: Implement Missing Stream Methods

**User Story:** As a developer, I want the classification and calibration stream methods fully implemented so that the training and calibration screens function without crashing.

#### Acceptance Criteria

1. WHEN `getClassificationStream()` is called THEN the system SHALL return a functioning `Stream<ClassificationResult>` that emits real-time classification data from the Rust audio engine.

2. WHEN `getCalibrationStream()` is called THEN the system SHALL return a functioning `Stream<CalibrationProgress>` that emits calibration progress updates during the calibration procedure.

3. WHEN the training screen subscribes to classification stream THEN the system SHALL deliver classification results within 100ms of onset detection.

4. WHEN the calibration screen subscribes to calibration stream THEN the system SHALL deliver progress updates for each sound sample collection event.

5. IF the audio engine is not running THEN the streams SHALL emit appropriate error states rather than crashing.

6. WHEN stream implementations are complete THEN the system SHALL pass integration tests verifying classification and calibration workflows end-to-end.

### Requirement 2: Establish Dependency Injection Container

**User Story:** As a developer, I want a centralized service locator pattern so that I can inject mock dependencies for testing and eliminate direct service instantiation in widget constructors.

#### Acceptance Criteria

1. WHEN the application initializes THEN the system SHALL register all services (AudioService, PermissionService, SettingsService, DebugService, StorageService) in a dependency injection container.

2. WHEN a widget requires a service dependency THEN the system SHALL inject the service via constructor parameter WITHOUT default instantiation fallbacks.

3. WHEN writing widget tests THEN developers SHALL be able to register mock service implementations in the DI container.

4. IF a required service is not registered THEN the system SHALL fail fast at application startup with a clear error message.

5. WHEN services are registered THEN the system SHALL use singleton pattern for stateful services (AudioService, SettingsService, StorageService).

6. WHEN the DI container is implemented THEN all widget constructors SHALL require services as constructor parameters with no default values.

### Requirement 3: Remove Service Default Instantiation from Widgets

**User Story:** As a QA engineer, I want widgets to accept only injected dependencies so that I can write isolated unit tests with mock services.

#### Acceptance Criteria

1. WHEN TrainingScreen is constructed THEN the system SHALL require all service dependencies (audioService, permissionService, settingsService, debugService) as non-nullable constructor parameters.

2. WHEN CalibrationScreen is constructed THEN the system SHALL require all service dependencies as non-nullable constructor parameters.

3. WHEN SettingsScreen is constructed THEN the system SHALL require all service dependencies as non-nullable constructor parameters.

4. WHEN any screen widget is instantiated in production THEN the system SHALL use a factory constructor that retrieves services from the DI container.

5. WHEN any screen widget is instantiated in tests THEN developers SHALL pass mock implementations directly to the constructor.

6. IF a widget attempts to instantiate a concrete service implementation THEN the static analyzer SHALL produce a lint warning.

### Requirement 4: Abstract Router for Testability

**User Story:** As a developer, I want navigation logic abstracted behind an interface so that I can test navigation flows without depending on go_router.

#### Acceptance Criteria

1. WHEN the application initializes THEN the system SHALL provide an injectable router instance to MyApp widget.

2. WHEN widget tests run THEN developers SHALL be able to inject a mock router with custom route configurations.

3. WHEN production code runs THEN the system SHALL use the default GoRouter configuration.

4. WHEN a widget needs to navigate THEN it SHALL use the injected router instance rather than accessing a global variable.

5. IF the router is not provided THEN MyApp SHALL create a default router instance as fallback.

### Requirement 5: Refactor AppContext God Object

**User Story:** As a Rust developer, I want AppContext split into focused manager classes so that each component has a single, clear responsibility.

#### Acceptance Criteria

1. WHEN the refactor is complete THEN the system SHALL have an `AudioEngineManager` responsible solely for audio engine lifecycle (start, stop, state management).

2. WHEN the refactor is complete THEN the system SHALL have a `CalibrationManager` responsible solely for calibration workflow, state persistence, and progress tracking.

3. WHEN the refactor is complete THEN the system SHALL have a `BroadcastChannelManager` responsible solely for managing all tokio broadcast channels (classification, calibration, metrics, onsets).

4. WHEN AppContext is instantiated THEN it SHALL compose the three managers without containing their implementation logic.

5. WHEN any manager method is called THEN it SHALL only access state and dependencies owned by that manager.

6. WHEN the refactor is complete THEN the Rust file `context.rs` SHALL be under 500 lines (currently 1392 lines).

7. IF managers need to coordinate THEN they SHALL use well-defined interfaces rather than sharing internal state.

### Requirement 6: Extract Business Logic from TrainingScreen

**User Story:** As a Flutter developer, I want TrainingScreen to delegate business logic to a controller so that the widget focuses solely on rendering UI.

#### Acceptance Criteria

1. WHEN the refactor is complete THEN the system SHALL have a `TrainingController` class handling audio lifecycle, BPM updates, and state management.

2. WHEN TrainingScreen is constructed THEN it SHALL receive a TrainingController instance via dependency injection.

3. WHEN the user starts training THEN TrainingScreen SHALL call `controller.startTraining()` without directly invoking audio service methods.

4. WHEN the user changes BPM THEN TrainingScreen SHALL call `controller.updateBpm(int bpm)` without managing validation logic.

5. WHEN the refactor is complete THEN TrainingScreen SHALL contain only UI rendering code (build methods, widget composition).

6. WHEN the refactor is complete THEN the file `training_screen.dart` SHALL be under 500 lines (currently 614 lines).

7. WHEN writing tests THEN developers SHALL be able to test TrainingController business logic independently from widget rendering.

### Requirement 7: Consolidate Error Code Definitions

**User Story:** As a developer, I want error codes defined in a single source of truth so that Rust and Dart error handling remain synchronized.

#### Acceptance Criteria

1. WHEN error codes are defined in Rust THEN the system SHALL expose them to Dart via FFI as named constants.

2. WHEN Dart error handler translates errors THEN it SHALL reference the FFI-exposed constants rather than hardcoded magic numbers.

3. WHEN a new error code is added in Rust THEN Dart SHALL automatically gain access to the constant through bridge regeneration.

4. WHEN error translation occurs THEN the system SHALL use the constant names (e.g., `AudioErrorCodes.bpmInvalid`) rather than numeric literals (e.g., `1001`).

5. IF Rust error definitions change THEN the Dart error handler SHALL remain compatible through named constant references.

### Requirement 8: Refactor Large Functions

**User Story:** As a code reviewer, I want all functions under 50 lines so that code is readable, testable, and adheres to Single Level of Abstraction Principle.

#### Acceptance Criteria

1. WHEN `context.rs::start_audio()` is refactored THEN it SHALL be under 50 lines by extracting helper methods for validation, channel setup, and engine creation.

2. WHEN `context.rs::classification_stream()` is refactored THEN it SHALL be under 50 lines by extracting stream transformation logic.

3. WHEN `context.rs::calibration_stream()` is refactored THEN it SHALL be under 50 lines by extracting progress computation logic.

4. WHEN `calibration_screen.dart::_finishCalibration()` is refactored THEN it SHALL separate high-level workflow from low-level JSON parsing/deserialization.

5. WHEN any function exceeds 50 lines THEN the static analyzer SHALL produce a warning.

6. WHEN helper methods are extracted THEN they SHALL operate at a single level of abstraction.

### Requirement 9: Implement Navigation Service Abstraction

**User Story:** As a developer, I want navigation logic abstracted behind an interface so that I can test navigation flows without depending on go_router implementation details.

#### Acceptance Criteria

1. WHEN the system is initialized THEN it SHALL provide an `INavigationService` interface with methods `goTo(String route)`, `goBack()`, and `replace(String route)`.

2. WHEN production code runs THEN the system SHALL use `GoRouterNavigationService` implementing `INavigationService`.

3. WHEN tests run THEN developers SHALL be able to inject a `MockNavigationService` to verify navigation calls.

4. WHEN CalibrationScreen completes calibration THEN it SHALL call `navigationService.goTo('/training')` instead of `context.go('/training')`.

5. WHEN TrainingScreen handles errors THEN it SHALL call `navigationService.goBack()` instead of `context.pop()`.

6. WHEN the refactor is complete THEN no widget SHALL directly import or reference `go_router` package except in the navigation service implementation.

### Requirement 10: Split Fat Interfaces

**User Story:** As a developer implementing debug features, I want focused interfaces so that I only depend on the specific capabilities I need.

#### Acceptance Criteria

1. WHEN `IDebugService` is refactored THEN the system SHALL provide separate interfaces: `IAudioMetricsProvider`, `IOnsetEventProvider`, and `ILogExporter`.

2. WHEN a widget needs only audio metrics THEN it SHALL depend on `IAudioMetricsProvider` interface rather than the full `IDebugService`.

3. WHEN the DebugServiceImpl is implemented THEN it SHALL implement all three focused interfaces as a composition.

4. WHEN dependency injection is configured THEN the system SHALL allow registering providers for each interface independently.

5. IF a component depends on multiple capabilities THEN it SHALL accept multiple interface dependencies rather than a single fat interface.

### Requirement 11: Simplify Stream Plumbing

**User Story:** As a Rust developer, I want classification results delivered via broadcast channels directly so that I eliminate unnecessary mpsc forwarding complexity.

#### Acceptance Criteria

1. WHEN the audio engine generates classification results THEN it SHALL send them directly to a tokio broadcast channel.

2. WHEN the refactor is complete THEN the system SHALL eliminate the mpsc → broadcast forwarding layer and associated tokio::spawn tasks.

3. WHEN multiple subscribers consume classification results THEN the broadcast channel SHALL support fan-out without additional plumbing.

4. WHEN the refactor is complete THEN the code SHALL have fewer lines of stream setup logic (currently 20+ lines per stream).

5. WHEN developers read the stream setup code THEN the control flow SHALL be immediately obvious without tracing through forwarding tasks.

### Requirement 12: Add Platform Stubs for Desktop Testing

**User Story:** As a Rust developer, I want to run audio engine tests on desktop machines so that I don't require an Android device for development iteration.

#### Acceptance Criteria

1. WHEN Rust tests run on non-Android platforms THEN the system SHALL compile using stub implementations of platform-specific audio code.

2. WHEN audio engine tests execute on desktop THEN they SHALL use mock audio I/O that simulates callbacks without requiring hardware.

3. WHEN the `#[cfg(target_os = "android")]` conditional compilation is evaluated on desktop THEN alternative implementations SHALL be selected.

4. WHEN `cargo test` runs on Linux/macOS/Windows THEN all Rust tests SHALL pass without Android emulator or device.

5. IF platform-specific functionality is required THEN tests SHALL use trait-based abstractions allowing mock implementations.

## Non-Functional Requirements

### Code Architecture and Modularity

- **Single Responsibility Principle**: Each file SHALL have a single, well-defined purpose. No file SHALL exceed 500 lines excluding comments and blank lines.
- **Function Length**: All functions SHALL be under 50 lines excluding comments and blank lines.
- **Modular Design**: Components, utilities, and services SHALL be isolated and reusable with minimal interdependencies.
- **Dependency Management**: All external dependencies SHALL be injected via constructors or DI container, never instantiated as default parameters.
- **Clear Interfaces**: Each layer in the 4-layer architecture (Dart UI → Bridge → Rust Engine → C++ Oboe) SHALL communicate through well-defined interfaces.

### Performance

- **Zero Performance Regression**: All refactoring SHALL maintain existing performance characteristics (< 20ms latency, 0 jitter metronome, < 15% CPU usage).
- **Lock-Free Audio Path**: Refactored Rust managers SHALL NOT introduce any locks, allocations, or blocking operations in audio callbacks.
- **Stream Overhead**: Classification and calibration stream implementations SHALL add < 5ms overhead to result delivery.
- **Compilation Time**: Rust refactoring SHALL NOT increase clean build time by more than 10%.

### Testability

- **Test Coverage**: After remediation, unit test coverage SHALL reach minimum 80% for business logic (services, controllers, managers).
- **Widget Testing**: All screen widgets SHALL be testable with injected mock services.
- **Rust Testing**: All Rust managers SHALL have unit tests executable on desktop without Android device.
- **Integration Testing**: End-to-end integration tests SHALL verify stream functionality, calibration workflow, and training session lifecycle.

### Maintainability

- **Code Duplication**: DRY violations SHALL be eliminated (e.g., duplicate BeatboxHit.displayName implementations, duplicate BPM validation).
- **Magic Numbers**: All magic numbers SHALL be replaced with named constants (error codes, sample counts, BPM ranges).
- **Documentation**: All extracted managers, controllers, and interfaces SHALL have dartdoc/rustdoc comments explaining their purpose and usage.
- **Linting**: Code SHALL pass `dart analyze` and `cargo clippy` with zero warnings after remediation.

### Reliability

- **Fail Fast**: Invalid dependency injection configurations SHALL be detected at application startup, not during runtime.
- **Error Handling**: Stream implementations SHALL handle error cases gracefully (engine not running, FFI failures) without crashing.
- **Thread Safety**: Refactored Rust managers SHALL maintain existing thread safety guarantees using Arc, RwLock, and atomics appropriately.

### Compliance with Development Guidelines

- **SOLID Principles**: All code SHALL adhere to Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, and Dependency Inversion principles.
- **SLAP (Single Level of Abstraction Principle)**: All functions SHALL operate at a single level of abstraction, extracting helper methods as needed.
- **SSOT (Single Source of Truth)**: Error codes, validation rules, and configuration constants SHALL be defined in exactly one location.
- **KISS (Keep It Simple)**: Unnecessary complexity (defensive null checks, manual JSON serialization where codegen is available) SHALL be eliminated.
