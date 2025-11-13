# Tasks Document: Code Quality Refactoring

## Phase 1: Error Infrastructure (P0 - Critical)

### Task 1.1: Create Custom Error Types in Rust

- [x] 1.1. Create custom error types in rust/src/error.rs
  - Files: rust/src/error.rs (NEW)
  - Create AudioError enum with variants: BpmInvalid, AlreadyRunning, NotRunning, HardwareError, PermissionDenied, StreamOpenFailed, LockPoisoned
  - Create CalibrationError enum with variants: InsufficientSamples, InvalidFeatures, NotComplete, AlreadyInProgress, StatePoisoned
  - Implement ErrorCode trait with code() and message() methods
  - Implement Display and Error traits for both enums
  - Add From implementations for common error types (std::io::Error, etc.)
  - _Leverage: Rust standard library Error trait, existing error messages from api.rs_
  - _Requirements: Requirement 2 (Comprehensive Error Handling Infrastructure)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer specializing in error handling and type systems | Task: Create comprehensive custom error types in rust/src/error.rs following Requirement 2, defining AudioError and CalibrationError enums with ErrorCode trait for structured error propagation across FFI boundary. Include error codes for each variant (1001-1007 for AudioError, 2001-2005 for CalibrationError). | Restrictions: Do not break existing FFI bridge API, maintain error message clarity, ensure error types are serializable for flutter_rust_bridge | Leverage: Existing error messages in rust/src/api.rs (lines 107, 113, 151, 184, etc.), Rust std::error::Error trait patterns | Requirements: Requirement 2.1, 2.2, 2.6 | Success: All error enums compile, ErrorCode trait implemented with unique codes, Display trait shows user-friendly messages, errors can be propagated with ? operator. After completion: 1) Mark task 1.1 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (error types created, methods, integration points), 4) Mark task 1.1 as complete [x] in tasks.md_

### Task 1.2: Replace String Errors with Typed Errors

- [x] 1.2. Replace Result<T, String> with custom error types throughout Rust codebase
  - Files: rust/src/api.rs, rust/src/audio/engine.rs, rust/src/calibration/procedure.rs, rust/src/analysis/mod.rs (MODIFIED)
  - Replace all `Result<(), String>` with `Result<(), AudioError>` in api.rs
  - Replace all `Result<T, String>` with appropriate error types in engine.rs
  - Update CalibrationProcedure methods to return `Result<T, CalibrationError>`
  - Update error message creation to use `AudioError` variants instead of format!() strings
  - Update map_err() calls to convert to custom error types
  - _Leverage: New error types from rust/src/error.rs, existing error handling patterns_
  - _Requirements: Requirement 2 (Comprehensive Error Handling Infrastructure)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Refactoring Specialist with expertise in type system migration | Task: Replace all Result<T, String> returns with typed errors following Requirement 2, updating rust/src/api.rs (all FFI functions), rust/src/audio/engine.rs (AudioEngine methods), rust/src/calibration/procedure.rs (CalibrationProcedure methods). Convert string error messages to appropriate enum variants. | Restrictions: Maintain identical error semantics, do not change FFI function signatures visible to Dart, ensure no compilation errors | Leverage: Custom error types from rust/src/error.rs (task 1.1), existing error construction patterns in api.rs | Requirements: Requirement 2.1, 2.2 | Success: Zero Result<T, String> remaining in modified files, all errors use typed enums, code compiles without warnings, FFI bridge still works. After completion: 1) Mark task 1.2 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (files modified, error type migrations, affected functions), 4) Mark task 1.2 as complete [x] in tasks.md_

### Task 1.3: Eliminate Unwrap Calls with Safe Error Handling

- [x] 1.3. Replace all .unwrap() and .expect() calls with proper error handling
  - Files: rust/src/api.rs (lines 110, 124, 179, 187, 260, 369), rust/src/analysis/classifier.rs (line 75), rust/src/audio/buffer_pool.rs (MODIFIED)
  - Replace `lock().unwrap()` with `lock().map_err(|_| AudioError::LockPoisoned { component: "..." })?`
  - Replace `read().unwrap()` with `read().map_err(|_| CalibrationError::StatePoisoned)?`
  - Replace unwrap() on buffer pool operations with match or if-let patterns
  - Document safety invariants for any remaining expect() calls with clear comments
  - Add unit tests for lock poisoning recovery
  - _Leverage: Custom error types from rust/src/error.rs, lock error patterns_
  - _Requirements: Requirement 2 (Comprehensive Error Handling Infrastructure), Requirement 2.4 (Panic Safety)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Safety Engineer with expertise in panic-free code and error recovery | Task: Eliminate all .unwrap() and .expect() calls following Requirement 2.4, replacing with graceful error handling using custom error types. Focus on api.rs lock operations (lines 110, 124, 179, 187, 260, 369) and classifier.rs RwLock access (line 75). | Restrictions: Maintain zero-panic guarantee, do not add unwrap() elsewhere, ensure lock failures propagate as typed errors | Leverage: AudioError::LockPoisoned and CalibrationError::StatePoisoned from rust/src/error.rs | Requirements: Requirement 2.4, 2.5 | Success: Zero unwrap/expect calls in production code paths, all lock errors handled gracefully, panic tests verify error propagation. After completion: 1) Mark task 1.3 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (unwrap removals, error handling additions, safety improvements), 4) Mark task 1.3 as complete [x] in tasks.md_

### Task 1.4: Add Error Logging Infrastructure

- [x] 1.4. Add structured logging for errors with context
  - Files: rust/src/error.rs (MODIFIED), rust/src/api.rs (MODIFIED), Cargo.toml (MODIFIED)
  - Add log crate dependency to Cargo.toml
  - Implement log_error() helper that logs error code, message, and context
  - Add logging to all error return sites in api.rs
  - Use log::error! macro with structured fields (error_code, component, details)
  - Add logging configuration in lib.rs for Android target
  - _Leverage: Existing android_logger setup in rust/src/lib.rs, log crate_
  - _Requirements: Requirement 2 (Comprehensive Error Handling Infrastructure), Requirement 2.3 (Structured Logging)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps Engineer with expertise in structured logging and observability | Task: Add structured error logging following Requirement 2.3, integrating log crate with existing android_logger setup (rust/src/lib.rs). Create log_error() helper in error.rs that logs error code, component name, and contextual details. Add logging at all error return sites in api.rs. | Restrictions: Do not block on logging failures, ensure logging is zero-cost when disabled, maintain performance in audio path | Leverage: Existing android_logger configuration in rust/src/lib.rs, log crate macros | Requirements: Requirement 2.3, 2.6 | Success: All errors logged with structured context, logging doesn't impact performance, log output includes error codes and component names. After completion: 1) Mark task 1.4 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (logging functions, integration points, configuration changes), 4) Mark task 1.4 as complete [x] in tasks.md_

## Phase 2: Dependency Injection (P0 - Critical)

### Task 2.1: Create AppContext Container

- [x] 2.1. Create AppContext struct with dependency injection in rust/src/context.rs
  - Files: rust/src/context.rs (NEW)
  - Create AppContext struct with fields for all global state (audio_engine, calibration_procedure, calibration_state, classification_broadcast, calibration_broadcast)
  - Implement AppContext::new() constructor
  - Implement business logic methods: start_audio(), stop_audio(), set_bpm(), start_calibration(), finish_calibration()
  - Implement stream methods: classification_stream(), calibration_stream()
  - Add helper methods: lock_audio_engine(), lock_calibration_procedure(), read_calibration(), write_calibration()
  - _Leverage: Existing global static patterns from rust/src/api.rs (lines 25-43), Arc/Mutex patterns_
  - _Requirements: Requirement 1 (Eliminate Global State Testability Blockers), Requirement 3 (Enforce Dependency Injection Pattern)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Architect specializing in dependency injection and state management | Task: Create AppContext dependency injection container following Requirements 1 and 3, consolidating 5 global statics from rust/src/api.rs (lines 25-43) into a single injected context. Move all business logic from FFI functions into AppContext methods. Add safe lock helpers that return typed errors instead of using unwrap(). | Restrictions: Maintain thread-safety with Arc/Mutex, preserve audio callback performance, ensure no breaking changes to behavior | Leverage: Existing Arc/Mutex patterns from api.rs, AudioEngine from audio/engine.rs, CalibrationProcedure from calibration/procedure.rs | Requirements: Requirement 1.1-1.5, Requirement 3.1-3.5 | Success: AppContext compiles with all state management logic, methods properly handle lock errors, business logic is centralized and testable. After completion: 1) Mark task 2.1 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (struct definition, methods, lock helpers, moved business logic), 4) Mark task 2.1 as complete [x] in tasks.md_

### Task 2.2: Add Test Helpers for AppContext

- [x] 2.2. Add test configuration and mocking support to AppContext
  - Files: rust/src/context.rs (MODIFIED)
  - Add #[cfg(test)] section with test-specific methods
  - Implement AppContext::new_test() for isolated test instances
  - Add reset() method for cleaning up test state
  - Add with_mock_engine() for dependency injection in tests
  - Create test utilities for spawning isolated contexts
  - _Leverage: Rust #[cfg(test)] patterns, existing test modules_
  - _Requirements: Requirement 1 (Eliminate Global State Testability Blockers), Requirement 8 (Achieve Minimum Test Coverage)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Test Engineer with expertise in Rust testing and mocking frameworks | Task: Add comprehensive test support to AppContext following Requirement 1 and 8, creating isolated test instances and mock injection capabilities. Implement new_test() constructor that creates isolated context, reset() for cleanup, and with_mock_engine() for dependency injection. | Restrictions: Test code must not compile in release builds, maintain zero overhead in production, ensure test isolation | Leverage: Rust #[cfg(test)] conditional compilation, AppContext from task 2.1 | Requirements: Requirement 1.2, 1.4, Requirement 8.5, 8.6 | Success: Tests can create isolated contexts, mock dependencies injectable, parallel test execution safe, no production overhead. After completion: 1) Mark task 2.2 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (test helpers, mock support, configuration), 4) Mark task 2.2 as complete [x] in tasks.md_

### Task 2.3: Refactor FFI Bridge to Use AppContext

- [x] 2.3. Refactor rust/src/api.rs to delegate to AppContext
  - Files: rust/src/api.rs (MODIFIED)
  - Replace 5 global Lazy statics with single `static APP_CONTEXT: Lazy<AppContext>`
  - Update start_audio() to call APP_CONTEXT.start_audio()
  - Update stop_audio() to call APP_CONTEXT.stop_audio()
  - Update set_bpm() to call APP_CONTEXT.set_bpm()
  - Update start_calibration(), finish_calibration() to delegate to AppContext
  - Update classification_stream(), calibration_stream() to delegate to AppContext
  - Remove business logic from FFI functions (now in AppContext)
  - _Leverage: AppContext from rust/src/context.rs, flutter_rust_bridge annotations_
  - _Requirements: Requirement 1 (Eliminate Global State Testability Blockers), Requirement 3 (Enforce Dependency Injection Pattern)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: FFI Integration Specialist with expertise in Rust-Flutter bridge architecture | Task: Refactor rust/src/api.rs to delegate all business logic to AppContext following Requirements 1 and 3. Replace 5 global statics (lines 25-43) with single APP_CONTEXT. Each FFI function becomes thin wrapper calling AppContext method. | Restrictions: Maintain identical FFI API surface, preserve flutter_rust_bridge annotations, ensure no behavioral changes | Leverage: AppContext methods from rust/src/context.rs (task 2.1), existing FFI patterns | Requirements: Requirement 1.1, 1.3, Requirement 3.2, 3.4 | Success: FFI functions delegate to AppContext, only 1 global static remains, business logic removed from api.rs, FFI bridge compiles and works. After completion: 1) Mark task 2.3 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (FFI refactoring, delegation pattern, removed business logic), 4) Mark task 2.3 as complete [x] in tasks.md_

### Task 2.4: Add Unit Tests for AppContext

- [x] 2.4. Create comprehensive unit tests for AppContext in rust/src/context.rs
  - Files: rust/src/context.rs (MODIFIED - add #[cfg(test)] mod tests)
  - Test BPM validation (valid range, boundary values, invalid values)
  - Test double-start prevention (AlreadyRunning error)
  - Test stop when not running (graceful handling)
  - Test lock poisoning recovery (LockPoisoned error)
  - Test calibration state transitions
  - Test stream lifecycle (start, receive, stop)
  - _Leverage: Test helpers from task 2.2, Rust #[test] attribute_
  - _Requirements: Requirement 8 (Achieve Minimum Test Coverage)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: QA Engineer with expertise in Rust unit testing and async testing | Task: Create comprehensive unit tests for AppContext following Requirement 8, achieving 90% coverage for critical business logic. Test all error paths (BPM validation, AlreadyRunning, NotRunning, LockPoisoned), state transitions, and stream lifecycle. | Restrictions: Tests must run in parallel, no shared state between tests, use test helpers from task 2.2 | Leverage: AppContext test helpers (new_test, reset) from task 2.2, tokio::test for async tests | Requirements: Requirement 8.1, 8.2, 8.5 | Success: Tests cover all public methods, error paths tested, async streams tested, tests pass independently and in parallel. After completion: 1) Mark task 2.4 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (test cases, coverage areas, assertions), 4) Mark task 2.4 as complete [x] in tasks.md_

## Phase 3: Dart Service Layer (P1 - High)

### Task 3.1: Create Service Interfaces in Dart

- [x] 3.1. Create IAudioService and IPermissionService interfaces
  - Files: lib/services/audio/i_audio_service.dart (NEW), lib/services/permission/i_permission_service.dart (NEW)
  - Define IAudioService abstract class with methods: startAudio(), stopAudio(), setBpm(), getClassificationStream(), startCalibration(), finishCalibration(), getCalibrationStream()
  - Define IPermissionService abstract class with methods: checkMicrophonePermission(), requestMicrophonePermission(), openAppSettings()
  - Define PermissionStatus enum: granted, denied, permanentlyDenied
  - Add documentation for all interface methods
  - _Leverage: Existing model types (ClassificationResult, CalibrationProgress from lib/models/)_
  - _Requirements: Requirement 3 (Enforce Dependency Injection Pattern)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Software Architect specializing in Dart service architecture and dependency injection | Task: Define service interfaces following Requirement 3, creating abstract classes for audio and permission services to enable dependency injection and mocking. Use existing model types from lib/models/ for method signatures. | Restrictions: Interfaces must be pure (no implementation), maintain API consistency with existing FFI bridge, support Future and Stream return types | Leverage: ClassificationResult from lib/models/classification_result.dart, CalibrationProgress from lib/models/calibration_progress.dart | Requirements: Requirement 3.1, 3.2, 3.4 | Success: Interfaces compile, all methods properly typed, documentation complete, mockable for testing. After completion: 1) Mark task 3.1 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (interfaces created, methods defined, types used), 4) Mark task 3.1 as complete [x] in tasks.md_

### Task 3.2: Create ErrorHandler Utility

- [x] 3.2. Create ErrorHandler class for error translation
  - Files: lib/services/error_handler/error_handler.dart (NEW), lib/services/error_handler/exceptions.dart (NEW)
  - Create ErrorHandler class with methods: translateAudioError(), translateCalibrationError()
  - Implement pattern matching on Rust error strings to extract error codes
  - Create user-friendly message mappings for each error type
  - Define AudioServiceException and CalibrationServiceException classes
  - Add unit tests for error translation logic
  - _Leverage: Rust error messages from rust/src/error.rs (task 1.1)_
  - _Requirements: Requirement 2 (Comprehensive Error Handling Infrastructure), Requirement 2.3 (Error Translation)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Error Handling Specialist with expertise in cross-language error translation | Task: Create ErrorHandler utility following Requirement 2, translating technical Rust errors to user-friendly Dart messages. Pattern match on Rust error strings (e.g., "AudioError::BpmInvalid", "AudioError::AlreadyRunning") to provide contextual messages. | Restrictions: Never expose raw Rust errors to UI, handle all known error types, provide generic fallback for unknown errors | Leverage: Rust error message formats from rust/src/error.rs (task 1.1), existing error display patterns | Requirements: Requirement 2.3, 2.6 | Success: All Rust error types translatable, user-friendly messages clear and actionable, exception classes properly structured. After completion: 1) Mark task 3.2 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (translation logic, exception types, test cases), 4) Mark task 3.2 as complete [x] in tasks.md_

### Task 3.3: Implement AudioServiceImpl

- [ ] 3.3. Create concrete AudioServiceImpl implementation
  - Files: lib/services/audio/audio_service_impl.dart (NEW)
  - Implement IAudioService interface
  - Wrap FFI bridge calls (api.startAudio, api.stopAudio, api.setBpm, etc.)
  - Add error handling with ErrorHandler translation
  - Throw AudioServiceException on errors with translated messages
  - Validate inputs (e.g., BPM range 40-240) before FFI calls
  - _Leverage: FFI bridge from lib/bridge/api.dart, ErrorHandler from task 3.2, IAudioService interface from task 3.1_
  - _Requirements: Requirement 3 (Enforce Dependency Injection Pattern)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Dart Backend Developer with expertise in service implementation and error handling | Task: Implement concrete AudioServiceImpl following Requirement 3, wrapping FFI bridge calls with error translation and input validation. Each method calls corresponding FFI function, catches errors, translates via ErrorHandler, and throws typed exceptions. | Restrictions: Validate inputs before FFI calls, translate all errors, maintain async/Stream semantics from FFI bridge | Leverage: IAudioService interface (task 3.1), ErrorHandler (task 3.2), FFI bridge from lib/bridge/api.dart | Requirements: Requirement 3.2, 3.4, 3.5 | Success: Service implements all interface methods, error translation works, input validation prevents invalid FFI calls. After completion: 1) Mark task 3.3 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (service implementation, error handling, validation logic), 4) Mark task 3.3 as complete [x] in tasks.md_

### Task 3.4: Implement PermissionServiceImpl

- [ ] 3.4. Create concrete PermissionServiceImpl implementation
  - Files: lib/services/permission/permission_service_impl.dart (NEW)
  - Implement IPermissionService interface
  - Wrap permission_handler package calls
  - Convert permission_handler status types to PermissionStatus enum
  - Implement checkMicrophonePermission(), requestMicrophonePermission(), openAppSettings()
  - Add error handling for permission request failures
  - _Leverage: permission_handler package, IPermissionService interface from task 3.1_
  - _Requirements: Requirement 3 (Enforce Dependency Injection Pattern)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Developer with expertise in permission handling and platform integration | Task: Implement concrete PermissionServiceImpl following Requirement 3, wrapping permission_handler package. Convert package status types to custom PermissionStatus enum, handle all permission states (granted, denied, permanentlyDenied). | Restrictions: Handle all permission states, provide consistent error handling, ensure platform compatibility (Android) | Leverage: IPermissionService interface (task 3.1), permission_handler package, existing permission logic from lib/ui/screens/training_screen.dart (lines 112-154) | Requirements: Requirement 3.2, 3.5 | Success: Service implements all interface methods, status conversion correct, platform-specific handling works. After completion: 1) Mark task 3.4 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (service implementation, status mapping, platform integration), 4) Mark task 3.4 as complete [x] in tasks.md_

### Task 3.5: Add Service Unit Tests

- [ ] 3.5. Create unit tests for AudioServiceImpl and PermissionServiceImpl
  - Files: test/services/audio_service_test.dart (NEW), test/services/permission_service_test.dart (NEW), test/services/error_handler_test.dart (NEW)
  - Test AudioServiceImpl with mocked FFI bridge
  - Test error translation and exception throwing
  - Test input validation (BPM range, etc.)
  - Test PermissionServiceImpl with mocked permission_handler
  - Test ErrorHandler translation logic
  - Use mocktail for dependency mocking
  - _Leverage: mocktail package, flutter_test framework_
  - _Requirements: Requirement 8 (Achieve Minimum Test Coverage)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: QA Engineer with expertise in Dart unit testing and mocking | Task: Create comprehensive unit tests for service layer following Requirement 8, achieving 80% coverage. Use mocktail to mock FFI bridge and permission_handler dependencies. Test error handling, validation, and translation logic. | Restrictions: Tests must mock all external dependencies, test business logic in isolation, ensure deterministic results | Leverage: mocktail package for mocking, flutter_test framework, service implementations from tasks 3.3-3.4 | Requirements: Requirement 8.3, 8.4 | Success: All service methods tested with mocked dependencies, error scenarios covered, validation logic verified, tests pass reliably. After completion: 1) Mark task 3.5 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (test files, mock usage, coverage areas), 4) Mark task 3.5 as complete [x] in tasks.md_

## Phase 4: Shared UI Components (P1 - High)

### Task 4.1: Extract Shared Dialog Widgets

- [ ] 4.1. Create reusable dialog widgets
  - Files: lib/ui/widgets/error_dialog.dart (NEW), lib/ui/widgets/permission_dialogs.dart (NEW)
  - Extract ErrorDialog widget with configurable title, message, and retry callback
  - Create static show() method for easy invocation
  - Extract permission denial dialogs (PermissionDeniedDialog, PermissionSettingDialog)
  - Add unit widget tests for each dialog
  - _Leverage: Existing dialog patterns from lib/ui/screens/training_screen.dart (lines 157-201)_
  - _Requirements: Requirement 4 (Extract Reusable UI Components and Utilities)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter UI Developer with expertise in widget composition and reusability | Task: Extract shared dialog widgets following Requirement 4, creating ErrorDialog and permission-related dialogs from existing patterns in training_screen.dart (lines 157-201). Widgets must be stateless, configurable, and easily testable. | Restrictions: Maintain existing visual design, ensure accessibility, support Material Design 3 theming | Leverage: AlertDialog patterns from lib/ui/screens/training_screen.dart and calibration_screen.dart | Requirements: Requirement 4.1, 4.2, 4.5 | Success: Dialogs are reusable, properly typed, visually consistent, widget tests pass. After completion: 1) Mark task 4.1 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (widget components, props, reusability patterns), 4) Mark task 4.1 as complete [x] in tasks.md_

### Task 4.2: Extract Shared Loading and Status Widgets

- [ ] 4.2. Create LoadingOverlay and StatusCard widgets
  - Files: lib/ui/widgets/loading_overlay.dart (NEW), lib/ui/widgets/status_card.dart (NEW)
  - Extract LoadingOverlay widget with optional message parameter
  - Extract StatusCard widget with configurable colors, icon, title, and subtitle
  - Make widgets responsive and accessible
  - Add widget tests for different configurations
  - _Leverage: Existing loading patterns from lib/ui/screens/calibration_screen.dart (lines 189-201, 210-222), status patterns (lines 378-460)_
  - _Requirements: Requirement 4 (Extract Reusable UI Components and Utilities)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter UI Developer specializing in component design and Material Design | Task: Create LoadingOverlay and StatusCard reusable widgets following Requirement 4, extracting patterns from calibration_screen.dart. LoadingOverlay shows spinner with optional message. StatusCard shows colored container with icon, title, and subtitle. | Restrictions: Widgets must be stateless, support theming, maintain responsive design, follow Material Design guidelines | Leverage: CircularProgressIndicator patterns (calibration_screen.dart:193, 214), Container decoration patterns (lines 382-417, 424-456) | Requirements: Requirement 4.1, 4.2 | Success: Widgets are reusable and configurable, visual consistency maintained, responsive across screen sizes, widget tests pass. After completion: 1) Mark task 4.2 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (widget components, theming support, test coverage), 4) Mark task 4.2 as complete [x] in tasks.md_

### Task 4.3: Create Display Formatter Utilities

- [ ] 4.3. Extract display formatting utilities
  - Files: lib/ui/utils/display_formatters.dart (NEW)
  - Extract BPM formatting logic
  - Extract timing error formatting (existing in TimingFeedback.formattedError)
  - Create color mapping utilities for BeatboxHit types
  - Create icon utilities if needed
  - Add unit tests for formatting logic
  - _Leverage: Existing formatters from lib/models/timing_feedback.dart, color logic from lib/ui/screens/training_screen.dart (lines 365-396)_
  - _Requirements: Requirement 4 (Extract Reusable UI Components and Utilities)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Dart Developer with expertise in utility functions and separation of concerns | Task: Extract display formatting utilities following Requirement 4, creating reusable functions for BPM formatting, timing display, and color mappings. Consolidate formatting logic scattered across screens into centralized utility. | Restrictions: Keep utilities pure functions, no widget dependencies, ensure comprehensive test coverage | Leverage: TimingFeedback.formattedError from lib/models/timing_feedback.dart (lines 22-31), color mapping from training_screen.dart (lines 365-396) | Requirements: Requirement 4.2, 4.4 | Success: Utilities are pure functions, well-tested, reduce duplication, easy to use from widgets. After completion: 1) Mark task 4.3 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (utility functions, formatting logic, test cases), 4) Mark task 4.3 as complete [x] in tasks.md_

### Task 4.4: Update Screens to Use Shared Components

- [ ] 4.4. Refactor TrainingScreen and CalibrationScreen to use shared widgets
  - Files: lib/ui/screens/training_screen.dart (MODIFIED), lib/ui/screens/calibration_screen.dart (MODIFIED)
  - Replace inline error dialog code with ErrorDialog.show()
  - Replace loading indicators with LoadingOverlay widget
  - Replace status containers with StatusCard widget
  - Use display formatters from utilities
  - Inject services via constructor with default factory pattern
  - Remove duplicated code (target: reduce ~150 lines to ~50 lines)
  - _Leverage: Shared widgets from tasks 4.1-4.3, service interfaces from task 3.1_
  - _Requirements: Requirement 3 (Enforce Dependency Injection Pattern), Requirement 4 (Extract Reusable UI Components and Utilities)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Refactoring Specialist with expertise in component composition and dependency injection | Task: Refactor screens to use shared widgets and inject services following Requirements 3 and 4. Replace inline dialogs, loading indicators, and status containers with shared components from tasks 4.1-4.2. Add constructor injection for services with default factory pattern. | Restrictions: Maintain identical UI behavior and appearance, preserve state management logic, ensure no breaking changes | Leverage: ErrorDialog, LoadingOverlay, StatusCard from tasks 4.1-4.2, IAudioService/IPermissionService from task 3.1, service implementations from tasks 3.3-3.4 | Requirements: Requirement 3.1-3.5, Requirement 4.1-4.5 | Success: Code duplication reduced by ~100 lines, services injected, shared widgets used consistently, UI behavior unchanged. After completion: 1) Mark task 4.4 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (code removal, widget usage, service injection pattern), 4) Mark task 4.4 as complete [x] in tasks.md_

### Task 4.5: Add Widget Tests for Screens

- [ ] 4.5. Create widget tests for refactored screens with mocked services
  - Files: test/ui/screens/training_screen_test.dart (NEW), test/ui/screens/calibration_screen_test.dart (NEW)
  - Test TrainingScreen with mocked AudioService and PermissionService
  - Test error dialog display on audio start failure
  - Test permission request flow
  - Test loading states
  - Test CalibrationScreen with mocked services
  - Test progress display updates
  - Use mocktail for service mocking
  - _Leverage: mocktail package, flutter_test framework, shared widgets from tasks 4.1-4.2_
  - _Requirements: Requirement 8 (Achieve Minimum Test Coverage)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: QA Engineer specializing in Flutter widget testing and UI validation | Task: Create comprehensive widget tests for screens following Requirement 8, achieving 80% coverage for UI logic. Mock service dependencies with mocktail, test user interactions, state changes, and error handling. Verify shared widgets display correctly. | Restrictions: Tests must mock services, not test service implementation, focus on UI behavior and user flows | Leverage: mocktail for mocking IAudioService/IPermissionService, flutter_test testWidgets, shared widgets from tasks 4.1-4.2 | Requirements: Requirement 8.4 | Success: All user interactions tested, error scenarios covered, widget composition verified, tests reliable and fast. After completion: 1) Mark task 4.5 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (test scenarios, mock usage, UI validation), 4) Mark task 4.5 as complete [x] in tasks.md_

## Phase 5: File/Function Size Refactoring (P2 - Medium)

### Task 5.1: Split calibration/procedure.rs into Modules

- [ ] 5.1. Split calibration/procedure.rs (581 lines) into separate modules
  - Files: rust/src/calibration/procedure.rs (MODIFIED), rust/src/calibration/validation.rs (NEW), rust/src/calibration/progress.rs (NEW), rust/src/calibration/mod.rs (MODIFIED)
  - Extract SampleValidator struct and validate_sample() logic to validation.rs (~150 lines)
  - Extract CalibrationProgress struct and progress tracking to progress.rs (~150 lines)
  - Keep CalibrationProcedure in procedure.rs (~200 lines)
  - Update mod.rs to re-export all types
  - Maintain identical public API
  - _Leverage: Existing calibration logic in rust/src/calibration/procedure.rs_
  - _Requirements: Requirement 6 (Split Oversized Files)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer with expertise in module organization and code refactoring | Task: Split calibration/procedure.rs following Requirement 6, organizing into 3 focused modules: procedure.rs (CalibrationProcedure struct and orchestration), validation.rs (sample validation logic), progress.rs (progress tracking and reporting). Maintain public API compatibility. | Restrictions: No behavior changes, preserve all tests, maintain module visibility (pub/pub(crate)), ensure backward compatibility | Leverage: Existing calibration/procedure.rs structure (lines 1-581), Rust module system | Requirements: Requirement 6.1, 6.2, 6.4, 6.5 | Success: Files under 500 lines, clean module boundaries, all tests pass unchanged, public API identical. After completion: 1) Mark task 5.1 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (module split, file sizes, API preservation), 4) Mark task 5.1 as complete [x] in tasks.md_

### Task 5.2: Split analysis/features.rs into Modules

- [ ] 5.2. Split analysis/features.rs (576 lines) into feature extraction modules
  - Files: rust/src/analysis/features/mod.rs (NEW), rust/src/analysis/features/spectral.rs (NEW), rust/src/analysis/features/temporal.rs (NEW), rust/src/analysis/features/fft.rs (NEW), rust/src/analysis/features/types.rs (NEW), rust/src/analysis/mod.rs (MODIFIED)
  - Extract FFT computation logic to fft.rs (~100 lines)
  - Extract spectral features (centroid, rolloff, flatness) to spectral.rs (~150 lines)
  - Extract temporal features (ZCR, decay time) to temporal.rs (~120 lines)
  - Extract Features struct and builder to types.rs (~100 lines)
  - Keep FeatureExtractor coordinator in mod.rs (~100 lines)
  - Update analysis/mod.rs to use new module structure
  - _Leverage: Existing feature extraction logic in rust/src/analysis/features.rs_
  - _Requirements: Requirement 6 (Split Oversized Files)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DSP Engineer with expertise in Rust and signal processing architecture | Task: Split analysis/features.rs following Requirement 6, organizing into 5 domain-specific modules: fft.rs (FFT computation), spectral.rs (frequency domain features), temporal.rs (time domain features), types.rs (data structures), mod.rs (coordinator). Preserve DSP algorithm correctness. | Restrictions: No algorithm changes, maintain numerical accuracy, preserve all tests, ensure zero performance regression | Leverage: Existing analysis/features.rs structure (lines 1-576), rustfft usage patterns | Requirements: Requirement 6.1, 6.2, 6.4, 6.5 | Success: Files under 500 lines, clear domain separation, DSP tests pass unchanged, performance maintained. After completion: 1) Mark task 5.2 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (module organization, DSP logic split, test preservation), 4) Mark task 5.2 as complete [x] in tasks.md_

### Task 5.3: Break Down AudioEngine::start() Function

- [ ] 5.3. Refactor AudioEngine::start() (112 lines) into helper methods
  - Files: rust/src/audio/engine.rs (MODIFIED)
  - Extract create_input_stream() method (~20 lines)
  - Extract create_output_stream() method with callback (~40 lines)
  - Extract spawn_analysis_thread() method (~25 lines)
  - Keep start() as orchestrator (~25 lines)
  - Maintain identical behavior and audio callback performance
  - _Leverage: Existing AudioEngine implementation in rust/src/audio/engine.rs (lines 128-241)_
  - _Requirements: Requirement 5 (Refactor Oversized Functions)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Real-time Audio Engineer with expertise in Rust and low-latency systems | Task: Refactor AudioEngine::start() following Requirement 5, breaking 112-line method into focused helpers. Extract stream creation and thread spawning logic while preserving audio callback performance guarantees. | Restrictions: Zero performance regression in audio callback, maintain real-time safety (no allocations/locks), preserve exact behavior | Leverage: Existing AudioEngine::start() structure (audio/engine.rs:128-241), Oboe builder patterns | Requirements: Requirement 5.1, 5.2, 5.3, 5.5 | Success: Functions under 50 lines, audio latency unchanged, real-time safety maintained, tests pass. After completion: 1) Mark task 5.3 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (function extraction, orchestration pattern, performance validation), 4) Mark task 5.3 as complete [x] in tasks.md_

### Task 5.4: Break Down Widget Builder Methods in Dart

- [ ] 5.4. Refactor _buildProgressContent() (169 lines) and _buildClassificationDisplay() (90 lines) into sub-methods
  - Files: lib/ui/screens/calibration_screen.dart (MODIFIED), lib/ui/screens/training_screen.dart (MODIFIED)
  - Extract _buildOverallProgressHeader() from _buildProgressContent() (~30 lines)
  - Extract _buildCurrentSoundInstructions() (~50 lines)
  - Extract _buildProgressIndicator() (~30 lines)
  - Extract _buildStatusMessage() (~50 lines)
  - Keep _buildProgressContent() as compositor (~15 lines)
  - Extract _buildSoundTypeDisplay() from _buildClassificationDisplay() (~30 lines)
  - Extract _buildTimingFeedbackDisplay() (~30 lines)
  - Keep _buildClassificationDisplay() as compositor (~20 lines)
  - _Leverage: Existing widget tree patterns from screens_
  - _Requirements: Requirement 5 (Refactor Oversized Functions)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Developer with expertise in widget composition and code organization | Task: Refactor oversized widget builders following Requirement 5, breaking _buildProgressContent() (169 lines) and _buildClassificationDisplay() (90 lines) into focused sub-methods. Each method builds one UI section, compositor assembles them. | Restrictions: Maintain identical widget tree and styling, preserve UI behavior, ensure no performance regression | Leverage: Existing widget patterns from calibration_screen.dart (lines 293-463) and training_screen.dart (lines 362-451) | Requirements: Requirement 5.1, 5.2, 5.4, 5.5 | Success: Functions under 50 lines, widget tree unchanged, visual appearance identical, code more readable. After completion: 1) Mark task 5.4 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (method extraction, composition pattern, UI preservation), 4) Mark task 5.4 as complete [x] in tasks.md_

## Phase 6: Testing Infrastructure (P1 - High)

### Task 6.1: Create Pre-Commit Hook Script

- [ ] 6.1. Implement pre-commit hook with quality checks
  - Files: .git/hooks/pre-commit (NEW), scripts/pre-commit (NEW - version controlled)
  - Create bash script that runs: flutter analyze, dart format --set-exit-if-changed, cargo fmt -- --check, cargo clippy -- -D warnings, flutter test
  - Add file size checks (no files > 500 lines)
  - Add function size checks (no functions > 50 lines using grep patterns)
  - Make hook executable and add to git hooks
  - Create scripts/pre-commit as version-controlled template
  - Add installation instructions to README
  - _Leverage: Existing flutter and cargo tooling_
  - _Requirements: Requirement 7 (Establish Pre-Commit Quality Gates)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps Engineer with expertise in Git hooks and CI/CD automation | Task: Create comprehensive pre-commit hook following Requirement 7, implementing automated quality gates for linting, formatting, testing, and code metrics. Script must be fast, reliable, and provide clear error messages. | Restrictions: Hook must complete within 60 seconds, must be cross-platform compatible, provide actionable error messages | Leverage: flutter analyze, dart format, cargo fmt, cargo clippy, flutter test commands | Requirements: Requirement 7.1-7.6 | Success: Hook blocks commits with quality violations, runs quickly, clear error output, easy to install. After completion: 1) Mark task 6.1 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (hook script, checks implemented, installation process), 4) Mark task 6.1 as complete [x] in tasks.md_

### Task 6.2: Configure Test Coverage Reporting

- [ ] 6.2. Set up test coverage reporting for Rust and Dart
  - Files: Cargo.toml (MODIFIED), .github/workflows/test-coverage.yml (NEW if using CI), scripts/coverage.sh (NEW)
  - Configure cargo-tarpaulin or cargo-llvm-cov for Rust coverage
  - Configure flutter test --coverage for Dart coverage
  - Create coverage report generation script
  - Add coverage thresholds (80% overall, 90% critical paths)
  - Document coverage commands in README
  - _Leverage: cargo-tarpaulin or cargo-llvm-cov, flutter test --coverage_
  - _Requirements: Requirement 8 (Achieve Minimum Test Coverage)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: QA DevOps Engineer with expertise in test coverage tooling and reporting | Task: Configure test coverage reporting following Requirement 8, setting up tools for both Rust (cargo-tarpaulin/cargo-llvm-cov) and Dart (flutter test --coverage). Create unified coverage reports with threshold enforcement. | Restrictions: Coverage tools must not slow down test execution significantly, reports must be human-readable | Leverage: cargo-tarpaulin or cargo-llvm-cov for Rust, flutter test --coverage for Dart | Requirements: Requirement 8.1, 8.2 | Success: Coverage reports generated automatically, thresholds enforced, both Rust and Dart covered, easy to run. After completion: 1) Mark task 6.2 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (coverage configuration, report generation, threshold setup), 4) Mark task 6.2 as complete [x] in tasks.md_

### Task 6.3: Add Integration Tests

- [ ] 6.3. Create integration tests for FFI bridge and service layer
  - Files: rust/tests/integration_test.rs (NEW), test/integration/audio_integration_test.dart (NEW)
  - Create Rust integration test for full audio lifecycle (start → classify → stop)
  - Test stream behavior (subscribe, receive, close)
  - Create Dart integration test with real AudioServiceImpl (not mocked FFI)
  - Test error propagation across FFI boundary
  - Test service error translation
  - _Leverage: AppContext from rust/src/context.rs, AudioServiceImpl from lib/services/audio/audio_service_impl.dart_
  - _Requirements: Requirement 8 (Achieve Minimum Test Coverage)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Integration Test Engineer with expertise in cross-language testing and FFI validation | Task: Create integration tests following Requirement 8, testing full system flows across Rust-Dart boundary. Test audio lifecycle, stream behavior, and error propagation end-to-end. | Restrictions: Tests must be deterministic, handle async behavior correctly, clean up resources properly | Leverage: AppContext (rust/src/context.rs), AudioServiceImpl (lib/services/audio/audio_service_impl.dart), tokio::test for async Rust tests | Requirements: Requirement 8.1, 8.2, 8.6 | Success: Integration tests pass reliably, cover critical paths, validate FFI bridge, error translation verified. After completion: 1) Mark task 6.3 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (integration tests, cross-language validation, error propagation), 4) Mark task 6.3 as complete [x] in tasks.md_

### Task 6.4: Update Documentation

- [ ] 6.4. Update README and add architecture documentation
  - Files: README.md (MODIFIED), docs/ARCHITECTURE.md (NEW), docs/TESTING.md (NEW)
  - Update README with new service layer architecture
  - Document dependency injection pattern
  - Create ARCHITECTURE.md explaining AppContext, service layer, error handling
  - Create TESTING.md with test execution instructions and coverage requirements
  - Document pre-commit hook installation
  - Add code quality metrics and enforcement
  - _Leverage: Existing README.md, design document from this spec_
  - _Requirements: All (documentation completeness)_
  - _Prompt: Implement the task for spec code-quality-refactoring, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Technical Writer with expertise in software architecture documentation | Task: Create comprehensive documentation covering refactored architecture, testing strategy, and quality standards. Update README with new patterns, create ARCHITECTURE.md explaining design decisions, create TESTING.md with testing workflows. | Restrictions: Documentation must be accurate and up-to-date, examples must work, diagrams should clarify architecture | Leverage: Design document from .spec-workflow/specs/code-quality-refactoring/design.md, existing README.md structure | Requirements: All requirements (comprehensive documentation) | Success: Documentation is complete and accurate, examples work, architecture is clearly explained, testing guide is actionable. After completion: 1) Mark task 6.4 as in-progress [-] in tasks.md BEFORE starting, 2) Implement the code, 3) Use log-implementation tool with detailed artifacts (documentation files, diagrams, examples), 4) Mark task 6.4 as complete [x] in tasks.md_

## Summary

**Total Tasks**: 26
**Estimated Effort**: 15 developer days (as per design document)

**Task Distribution**:
- Phase 1 (Error Infrastructure): 4 tasks - 2 days
- Phase 2 (Dependency Injection): 4 tasks - 3 days
- Phase 3 (Dart Service Layer): 5 tasks - 2 days
- Phase 4 (Shared UI Components): 5 tasks - 1 day
- Phase 5 (File/Function Refactoring): 4 tasks - 3 days
- Phase 6 (Testing Infrastructure): 4 tasks - 4 days

**Implementation Order**: Follow phase sequence (P0 → P1 → P2), tasks within each phase can be parallelized where dependencies allow.

**Success Criteria** (from requirements):
- ✅ 0 global state variables in core business logic (currently 5)
- ✅ 0 unwrap/expect calls in production code (currently 11+)
- ✅ 80% test coverage overall, 90% critical paths (currently ~40%)
- ✅ < 50 duplicated lines (currently ~150)
- ✅ 100% of error paths return typed errors (currently 0%)
- ✅ 0 functions > 50 lines (currently 3)
- ✅ 0 source files > 500 lines excluding tests (currently 2)
- ✅ Audio latency remains < 20ms (no regression)
