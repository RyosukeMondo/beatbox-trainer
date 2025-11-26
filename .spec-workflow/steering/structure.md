# Project Structure

## Directory Organization

```
beatbox-trainer/
├── lib/                        # Dart/Flutter UI source code
│   ├── main.dart              # Application entry point
│   ├── di/                    # Dependency injection
│   │   └── service_locator.dart    # GetIt service locator setup
│   ├── services/              # Service layer (interfaces + implementations)
│   │   ├── audio/            # Audio service
│   │   │   ├── i_audio_service.dart      # Audio service interface
│   │   │   ├── audio_service_impl.dart   # Production implementation
│   │   │   ├── audio_controller.dart     # Audio lifecycle controller
│   │   │   ├── telemetry_stream.dart     # Telemetry event streaming
│   │   │   └── test_harness/            # Test harness components
│   │   │       ├── harness_audio_source.dart
│   │   │       └── diagnostics_controller.dart
│   │   ├── permission/       # Permission service
│   │   │   ├── i_permission_service.dart
│   │   │   └── permission_service_impl.dart
│   │   ├── navigation/       # Navigation service
│   │   │   ├── i_navigation_service.dart
│   │   │   └── go_router_navigation_service.dart
│   │   ├── storage/          # Local storage service
│   │   │   ├── i_storage_service.dart
│   │   │   └── storage_service_impl.dart
│   │   ├── settings/         # App settings service
│   │   │   ├── i_settings_service.dart
│   │   │   └── settings_service_impl.dart
│   │   ├── error_handler/    # Error handling utilities
│   │   │   ├── error_handler.dart
│   │   │   └── exceptions.dart
│   │   └── debug/            # Debug and diagnostics services
│   │       ├── i_debug_service.dart
│   │       ├── debug_service_impl.dart
│   │       ├── debug_sse_client.dart
│   │       ├── i_log_exporter.dart
│   │       ├── log_exporter_impl.dart
│   │       ├── fixture_metadata_service.dart
│   │       ├── i_debug_capabilities.dart
│   │       ├── i_onset_event_provider.dart
│   │       └── i_audio_metrics_provider.dart
│   ├── controllers/          # Business logic controllers
│   │   ├── training/
│   │   │   └── training_controller.dart
│   │   ├── calibration/
│   │   │   └── calibration_controller.dart
│   │   └── debug/
│   │       ├── debug_lab_controller.dart
│   │       └── fixture_validation_tracker.dart
│   ├── ui/                    # UI components and screens
│   │   ├── screens/          # Main app screens
│   │   │   ├── splash_screen.dart
│   │   │   ├── onboarding_screen.dart
│   │   │   ├── training_screen.dart
│   │   │   ├── calibration_screen.dart
│   │   │   ├── settings_screen.dart
│   │   │   └── debug_lab_screen.dart
│   │   ├── widgets/          # Reusable UI widgets
│   │   │   ├── classification_indicator.dart
│   │   │   ├── timing_feedback_widget.dart
│   │   │   ├── bpm_control.dart
│   │   │   ├── status_card.dart
│   │   │   ├── loading_overlay.dart
│   │   │   ├── error_dialog.dart
│   │   │   ├── permission_dialogs.dart
│   │   │   ├── debug_overlay.dart
│   │   │   ├── training_classification_section.dart
│   │   │   └── debug/        # Debug-specific widgets
│   │   │       ├── telemetry_chart.dart
│   │   │       ├── debug_log_list.dart
│   │   │       ├── param_slider_card.dart
│   │   │       ├── anomaly_banner.dart
│   │   │       └── debug_server_panel.dart
│   │   └── utils/            # UI utilities
│   │       └── display_formatters.dart
│   ├── models/               # Dart data models
│   │   ├── classification_result.dart
│   │   ├── timing_feedback.dart
│   │   ├── calibration_state.dart
│   │   ├── calibration_progress.dart
│   │   ├── telemetry_event.dart
│   │   ├── debug_log_entry.dart
│   │   └── debug/
│   │       └── fixture_anomaly_notice.dart
│   └── bridge/               # flutter_rust_bridge generated bindings
│       ├── api.dart/         # Auto-generated Dart API
│       │   ├── api.dart
│       │   ├── frb_generated.dart
│       │   ├── frb_generated.io.dart
│       │   ├── frb_generated.web.dart
│       │   ├── api/
│       │   │   ├── types.dart
│       │   │   ├── streams.dart
│       │   │   └── diagnostics.dart
│       │   ├── analysis/
│       │   │   ├── classifier.dart
│       │   │   └── quantizer.dart
│       │   ├── engine/
│       │   │   └── core.dart
│       │   ├── calibration/
│       │   │   └── progress.dart
│       │   ├── telemetry/
│       │   │   └── events.dart
│       │   ├── testing/
│       │   │   ├── fixtures.dart
│       │   │   └── fixture_manifest.dart
│       │   └── error/
│       │       ├── audio.dart
│       │       └── calibration.dart
│       └── extensions/       # Dart extensions for bridge types
│           ├── beatbox_hit_extensions.dart
│           └── error_code_extensions.dart
│
├── rust/                      # Rust audio engine (core DSP)
│   ├── src/
│   │   ├── lib.rs            # Library entry point
│   │   ├── api.rs            # Public API exposed to Dart via flutter_rust_bridge
│   │   ├── context.rs        # AppContext for dependency injection
│   │   ├── config.rs         # Configuration constants
│   │   ├── bridge_generated.rs # Auto-generated bridge code
│   │   ├── api/              # API sub-modules
│   │   │   ├── streams.rs    # Stream-returning functions
│   │   │   ├── types.rs      # Shared API types
│   │   │   ├── diagnostics.rs # Diagnostic API functions
│   │   │   └── tests.rs      # API unit tests
│   │   ├── managers/         # State managers (DI-friendly)
│   │   │   ├── mod.rs
│   │   │   ├── audio_engine_manager.rs
│   │   │   ├── calibration_manager.rs
│   │   │   └── broadcast_manager.rs
│   │   ├── engine/           # Audio engine abstraction
│   │   │   ├── mod.rs
│   │   │   ├── core.rs       # Core engine logic
│   │   │   ├── core/
│   │   │   │   └── tests.rs
│   │   │   └── backend/      # Platform-specific backends
│   │   │       ├── mod.rs
│   │   │       ├── oboe.rs         # Android Oboe backend
│   │   │       └── desktop_stub.rs  # Desktop stub for development
│   │   ├── audio/            # Low-level audio I/O
│   │   │   ├── mod.rs
│   │   │   ├── engine.rs     # AudioEngine struct, callbacks
│   │   │   ├── engine/
│   │   │   │   └── tests.rs
│   │   │   ├── callback.rs   # Audio callback implementation
│   │   │   ├── metronome.rs  # Sample-accurate metronome generation
│   │   │   ├── buffer_pool.rs # SPSC queue + object pool pattern
│   │   │   └── stubs.rs      # Test stubs
│   │   ├── analysis/         # DSP processing layer
│   │   │   ├── mod.rs
│   │   │   ├── onset.rs      # Onset detection (spectral flux)
│   │   │   ├── classifier.rs # Heuristic rule-based classifier
│   │   │   ├── quantizer.rs  # Timing quantization to metronome grid
│   │   │   ├── tests.rs      # Analysis unit tests
│   │   │   └── features/     # Feature extraction
│   │   │       ├── mod.rs
│   │   │       ├── types.rs
│   │   │       ├── spectral.rs   # Spectral features (centroid, flatness, rolloff)
│   │   │       ├── temporal.rs   # Temporal features (ZCR, envelope)
│   │   │       └── fft.rs        # FFT utilities
│   │   ├── calibration/      # User calibration system
│   │   │   ├── mod.rs
│   │   │   ├── state.rs      # Calibration thresholds storage
│   │   │   ├── procedure.rs  # Calibration workflow logic
│   │   │   ├── progress.rs   # Progress tracking
│   │   │   └── validation.rs # Input validation
│   │   ├── telemetry/        # Telemetry and metrics
│   │   │   ├── mod.rs
│   │   │   └── events.rs     # Telemetry event types
│   │   ├── debug/            # Debug HTTP server
│   │   │   ├── mod.rs
│   │   │   ├── http.rs       # HTTP server setup
│   │   │   └── routes/       # REST API routes
│   │   │       ├── mod.rs
│   │   │       ├── handlers.rs
│   │   │       ├── metrics.rs
│   │   │       ├── state.rs
│   │   │       └── tests.rs
│   │   ├── testing/          # Test fixtures and harness
│   │   │   ├── mod.rs
│   │   │   ├── fixtures.rs   # Test fixture definitions
│   │   │   ├── fixtures/
│   │   │   │   └── tests.rs
│   │   │   ├── fixture_manifest.rs # Manifest parsing
│   │   │   ├── fixture_manifest/
│   │   │   │   └── tests.rs
│   │   │   ├── fixture_engine.rs   # Fixture playback engine
│   │   │   └── fixture_validation.rs # Validation utilities
│   │   ├── error/            # Custom error types
│   │   │   ├── mod.rs
│   │   │   ├── audio.rs      # Audio-related errors
│   │   │   └── calibration.rs # Calibration errors
│   │   └── fixtures/         # Static fixture data
│   │       └── mod.rs
│   ├── Cargo.toml            # Rust dependencies
│   └── src/bin/              # CLI tools
│       ├── beatbox_cli.rs    # Main CLI entry point
│       └── bbt_diag/         # Diagnostics CLI tool
│           ├── mod.rs
│           ├── telemetry.rs
│           └── validation.rs
│
├── android/                   # Android-specific configuration
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── kotlin/com/ryosukemondo/beatbox_trainer/
│   │   │   │   └── MainActivity.kt    # System.loadLibrary() init block
│   │   │   ├── AndroidManifest.xml   # Microphone permissions
│   │   │   └── res/                  # Android resources
│   │   └── build.gradle.kts          # App-level build config
│   ├── gradle/                       # Gradle wrapper
│   ├── build.gradle.kts              # Project-level build config
│   └── settings.gradle.kts           # Gradle settings
│
├── test/                      # Dart widget and integration tests
│   ├── mocks.dart            # Shared mock definitions
│   ├── services/             # Service layer tests
│   │   ├── audio/
│   │   │   ├── audio_service_impl_test.dart
│   │   │   ├── telemetry_stream_test.dart
│   │   │   └── test_harness/
│   │   │       ├── diagnostics_controller_test.dart
│   │   │       ├── harness_audio_source_test.dart
│   │   │       ├── audio_controller_test.dart
│   │   │       └── diagnostics_controller_widget_test.dart
│   │   ├── permission_service_test.dart
│   │   ├── storage_service_test.dart
│   │   ├── settings_service_test.dart
│   │   ├── error_handler_test.dart
│   │   ├── calibration_data_test.dart
│   │   ├── audio_service_test.dart
│   │   └── debug/
│   │       └── log_exporter_impl_test.dart
│   ├── di/                   # Dependency injection tests
│   │   └── service_locator_test.dart
│   ├── controllers/          # Controller tests
│   │   ├── training/
│   │   │   └── training_controller_test.dart
│   │   └── debug/
│   │       └── debug_lab_controller_test.dart
│   ├── integration/          # Integration tests
│   │   ├── calibration_navigation_test.dart
│   │   ├── calibration_flow_test.dart
│   │   ├── audio_integration_test.dart
│   │   ├── refactored_workflows_test.dart
│   │   └── stream_workflows_test.dart
│   └── ui/                   # UI tests
│       ├── app_router_test.dart
│       ├── debug/
│       │   └── debug_lab_screen_test.dart
│       ├── utils/
│       │   └── display_formatters_test.dart
│       ├── screens/
│       │   ├── training_screen_test.dart
│       │   ├── calibration_screen_basic_test.dart
│       │   ├── calibration_screen_progress_test.dart
│       │   ├── calibration_screen_completion_test.dart
│       │   ├── calibration_screen_test_helper.dart
│       │   ├── settings_screen_test.dart
│       │   ├── onboarding_screen_test.dart
│       │   ├── splash_screen_test.dart
│       │   └── screen_factory_di_test.dart
│       └── widgets/
│           ├── classification_indicator_test.dart
│           ├── timing_feedback_test.dart
│           ├── bpm_control_test.dart
│           ├── status_card_test.dart
│           ├── loading_overlay_test.dart
│           ├── error_dialog_test.dart
│           └── permission_dialogs_test.dart
│
├── .spec-workflow/            # Spec-workflow MCP server artifacts
│   ├── steering/             # Steering documents
│   │   ├── product.md
│   │   ├── tech.md
│   │   └── structure.md
│   ├── specs/                # Feature specifications
│   └── templates/            # Document templates
│
├── pubspec.yaml              # Flutter dependencies
├── analysis_options.yaml     # Dart static analysis config
├── .gitignore
└── README.md
```

## Naming Conventions

### Files

**Dart/Flutter Layer**:
- **Screens**: `snake_case_screen.dart` (e.g., `training_screen.dart`, `calibration_screen.dart`)
- **Widgets**: `snake_case.dart` (e.g., `classification_indicator.dart`, `bpm_control.dart`)
- **Services**: `i_[service_name].dart` for interface, `[service_name]_impl.dart` for implementation
- **Controllers**: `[name]_controller.dart` (e.g., `training_controller.dart`)
- **Models**: `snake_case.dart` (e.g., `classification_result.dart`, `timing_feedback.dart`)
- **Tests**: `[filename]_test.dart` (e.g., `classification_result_test.dart`)

**Rust Layer**:
- **Modules**: `snake_case.rs` (e.g., `audio_engine.rs`, `onset_detector.rs`)
- **Tests**: Inline unit tests using `#[cfg(test)]` modules within each `.rs` file
- **Integration tests**: `tests/` directory at crate root or `[module]/tests.rs`

**Kotlin/Java Layer**:
- **Activities**: `PascalCase.kt` (e.g., `MainActivity.kt`)
- **Package structure**: Follows reverse domain notation (`com.ryosukemondo.beatbox_trainer`)

### Code

**Dart**:
- **Classes**: `PascalCase` (e.g., `TrainingScreen`, `AudioServiceImpl`)
- **Interfaces**: `I` prefix (e.g., `IAudioService`, `IPermissionService`)
- **Functions/Methods**: `camelCase` (e.g., `startTraining()`, `updateBpm()`)
- **Constants**: `lowerCamelCase` with `const` keyword (e.g., `defaultBpm = 120`)
- **Private members**: Prefix with `_` (e.g., `_audioService`, `_initializeState()`)

**Rust**:
- **Structs/Enums**: `PascalCase` (e.g., `AudioEngine`, `BeatboxHit`)
- **Functions/Methods**: `snake_case` (e.g., `start_audio()`, `detect_onset()`)
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `DEFAULT_SAMPLE_RATE`, `MIN_ONSET_THRESHOLD`)
- **Module-private items**: `pub(crate)` visibility for internal APIs

**Kotlin/Java**:
- **Classes**: `PascalCase` (e.g., `MainActivity`)
- **Methods**: `camelCase` (e.g., `onCreate()`, `loadLibrary()`)
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `LIBRARY_NAME`)

## Import Patterns

### Dart Import Order
1. **Dart SDK imports**: `dart:*` packages
2. **Flutter framework imports**: `package:flutter/*`
3. **External package imports**: `package:[other]/*`
4. **Internal imports**: Relative paths within `lib/`
5. **Generated bridge imports**: `package:beatbox_trainer/bridge/*`

**Example**:
```dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get_it/get_it.dart';

import '../services/audio/i_audio_service.dart';
import '../models/classification_result.dart';
```

### Rust Import Order
1. **Standard library imports**: `use std::*`
2. **External crate imports**: Alphabetically sorted
3. **Internal crate imports**: `use crate::*`
4. **Module-level imports**: `use super::*` (sparingly)

**Example**:
```rust
use std::sync::Arc;

use oboe::{AudioInputCallback, AudioOutputStream};
use rtrb::RingBuffer;

use crate::analysis::OnsetDetector;
use crate::audio::BufferPool;
use crate::context::AppContext;
```

### Module Organization

**Rust Crate Structure**:
- **Public API** (`api.rs`): Only types and functions exposed to Dart (annotated with `#[flutter_rust_bridge::frb]`)
- **Context** (`context.rs`): `AppContext` struct for dependency injection
- **Managers** (`managers/`): State managers for audio engine, calibration, broadcasts
- **Internal modules**: All implementation details are `pub(crate)` or private
- **No circular dependencies**: Audio layer → Analysis layer → Calibration layer (one-way dependency flow)

## Code Structure Patterns

### Dart Service Layer Pattern
```dart
// 1. Interface definition (i_audio_service.dart)
abstract class IAudioService {
  Future<void> startAudio({required int bpm});
  Future<void> stopAudio();
  Stream<ClassificationResult> get classificationStream;
}

// 2. Implementation (audio_service_impl.dart)
class AudioServiceImpl implements IAudioService {
  @override
  Future<void> startAudio({required int bpm}) async {
    // Input validation
    if (bpm <= 0) throw ArgumentError('BPM must be positive');
    // Delegate to Rust FFI
    await startAudioRust(bpm: bpm);
  }
}

// 3. Registration (service_locator.dart)
final getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerLazySingleton<IAudioService>(() => AudioServiceImpl());
  getIt.registerLazySingleton<IPermissionService>(() => PermissionServiceImpl());
}
```

### Dart Screen Pattern (with DI)
```dart
class TrainingScreen extends StatefulWidget {
  final IAudioService? audioService;
  final IPermissionService? permissionService;

  const TrainingScreen({
    super.key,
    this.audioService,
    this.permissionService,
  });

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late final IAudioService _audioService;
  late final IPermissionService _permissionService;

  @override
  void initState() {
    super.initState();
    _audioService = widget.audioService ?? getIt<IAudioService>();
    _permissionService = widget.permissionService ?? getIt<IPermissionService>();
  }
  // ...
}
```

### Rust AppContext Pattern
```rust
// context.rs - Centralized dependency injection
pub struct AppContext {
    audio_engine_manager: AudioEngineManager,
    calibration_manager: CalibrationManager,
    broadcast_manager: BroadcastManager,
}

impl AppContext {
    pub fn new() -> Self {
        Self {
            audio_engine_manager: AudioEngineManager::new(),
            calibration_manager: CalibrationManager::new(),
            broadcast_manager: BroadcastManager::new(),
        }
    }

    pub fn audio_engine(&self) -> &AudioEngineManager { &self.audio_engine_manager }
    pub fn calibration(&self) -> &CalibrationManager { &self.calibration_manager }
    pub fn broadcasts(&self) -> &BroadcastManager { &self.broadcast_manager }
}

// Single global instance (api.rs)
static APP_CONTEXT: Lazy<AppContext> = Lazy::new(AppContext::new);
```

### Rust File Organization
```rust
// 1. Module documentation
//! Onset detection using spectral flux algorithm.

// 2. Imports
use std::collections::VecDeque;
use rustfft::FftPlanner;

// 3. Constants
const FFT_SIZE: usize = 256;
const THRESHOLD_OFFSET: f32 = 0.1;

// 4. Type definitions
pub struct OnsetDetector {
    fft_planner: FftPlanner<f32>,
    prev_spectrum: Vec<f32>,
    onset_signal: VecDeque<f32>,
}

// 5. Public API implementation
impl OnsetDetector {
    /// Creates a new onset detector with the specified sample rate.
    pub fn new(sample_rate: u32) -> Self { /* ... */ }

    /// Processes audio buffer and returns onset timestamps.
    pub fn process(&mut self, audio: &[f32]) -> Vec<usize> { /* ... */ }
}

// 6. Private helper methods
impl OnsetDetector {
    fn compute_spectral_flux(&self, spectrum: &[f32]) -> f32 { /* ... */ }
    fn adaptive_threshold(&self) -> f32 { /* ... */ }
}

// 7. Unit tests
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_onset_detection() { /* ... */ }
}
```

## Code Organization Principles

1. **Single Responsibility**:
   - Each Rust module handles one aspect (audio I/O, onset detection, feature extraction, classification)
   - Each Dart service handles one domain (audio, permissions, storage, settings)
   - Each Dart screen manages one user workflow (training, calibration, settings)

2. **Dependency Injection**:
   - Dart: Services injected via GetIt service locator
   - Dart: Screens accept optional service parameters for testing
   - Rust: Single `AppContext` struct contains all managers
   - No direct FFI calls from screens - always through service layer

3. **Modularity**:
   - Rust audio engine is completely independent of Flutter UI
   - flutter_rust_bridge provides clean abstraction boundary
   - DSP algorithms are pure functions (no side effects, fully testable)
   - Service interfaces enable mocking for tests

4. **Testability**:
   - Rust: Unit tests alongside implementation (`#[cfg(test)]`)
   - Dart: Widget tests in `test/` directory mirror `lib/` structure
   - Integration tests for cross-layer workflows
   - Mock audio data for integration tests (pre-recorded beatbox samples)

5. **Consistency**:
   - Follow Dart style guide (enforced by `dart format`)
   - Follow Rust API guidelines (enforced by `clippy`)
   - Real-time safety rules apply universally to all audio callback code

## Module Boundaries

### Layer Boundaries (Strict Separation)

**UI Layer (Dart) ← Services → Bridge → Engine Layer (Rust)**:
- **Direction**: UI uses Services, Services call Bridge, Bridge calls Rust
- **Contract**: UI never calls FFI directly; all Rust operations go through service layer
- **Rationale**: Enables mocking, testing, error translation

**Service Layer (Dart) ← Bridge → Managers (Rust)**:
- **Direction**: Services call flutter_rust_bridge, which calls Rust managers via AppContext
- **Contract**: Services handle validation and error translation
- **Rationale**: Clean separation of concerns, testable services

**Engine Layer (Rust) → Audio Hardware (C++ Oboe)**:
- **Direction**: Rust wraps Oboe via `oboe-rs` bindings
- **Contract**: Only Rust audio thread touches Oboe callbacks; no direct C++ FFI from Dart
- **Rationale**: Type safety, memory safety, eliminates manual JNI code

**Audio Thread ← Lock-Free Queue → Analysis Thread**:
- **Direction**: Audio thread produces buffers, Analysis thread consumes
- **Contract**: Zero blocking operations in audio thread; all allocations happen in Analysis thread
- **Rationale**: Real-time safety - prevents xruns and audio glitches

### Feature Boundaries (Soft Separation)

**Core Training vs Calibration**:
- **Core Training**: Assumes calibration is complete, uses fixed thresholds
- **Calibration**: Modifies threshold state, isolated to calibration workflow
- **Shared**: Calibration state struct is shared (read-only during training, read-write during calibration)

**Level 1 (Broad Categories) vs Level 2 (Strict Subcategories)**:
- **Level 1**: Uses 2 features (centroid, ZCR) with simple rules
- **Level 2**: Adds 3+ features (flatness, rolloff, envelope) with complex rules
- **Implementation**: Single `Classifier` struct with difficulty level parameter

### Platform Boundaries

**Android-Specific vs Cross-Platform**:
- **Android-Specific**: `MainActivity.kt` (JNI initialization), `AndroidManifest.xml` (permissions), `oboe.rs` backend
- **Desktop Development**: `desktop_stub.rs` backend for development without Android device
- **Cross-Platform**: Entire Rust codebase (except backend/), majority of Dart UI code
- **Isolation**: Platform-specific code limited to `android/` directory and `rust/src/engine/backend/`

## Code Size Guidelines

### File Size Limits (Excluding Comments/Blank Lines)
- **Maximum lines per file**: 500 lines
- **Target file size**: 200-300 lines
- **Action if exceeded**: Split into sub-modules (e.g., `classifier.rs` → `classifier/mod.rs`, `classifier/level1.rs`, `classifier/level2.rs`)

### Function/Method Size
- **Maximum lines per function**: 50 lines
- **Target function size**: 10-20 lines
- **Single Level of Abstraction Principle (SLAP)**: Each function should operate at one level of abstraction
- **Action if exceeded**: Extract helper functions

### Class/Module Complexity
- **Maximum methods per struct**: 15 public methods
- **Cyclomatic complexity**: ≤ 10 per function (enforced via `clippy::cognitive_complexity`)
- **Nesting depth**: Maximum 4 levels of indentation

### Real-Time Code Constraints (Rust Audio Thread)
- **Audio callback functions**: ≤ 30 lines (including buffer copy operations)
- **No heap allocations**: Enforced via code review (no `Vec::push()`, `Box::new()`, etc.)
- **No locks**: Enforced via code review (no `Mutex`, `RwLock`, `Arc::clone()` in callbacks)
- **Execution time**: Must complete within `buffer_size / sample_rate` duration (e.g., < 10ms for 512 samples @ 48kHz)

## Documentation Standards

### Rust Documentation (rustdoc)
- **Public API**: All `pub` items must have `///` doc comments
- **Complex algorithms**: Include mathematical formulas in doc comments (e.g., spectral centroid formula)
- **Examples**: Public functions should include `# Examples` section with code snippet
- **Safety**: Functions with `unsafe` blocks must document invariants

### Dart Documentation (dartdoc)
- **Public widgets**: Document purpose and usage with `///` comments
- **Service interfaces**: Document contract and expected behavior
- **State management**: Explain lifecycle and state transitions
- **Stream contracts**: Document what events the Stream emits and when

### Inline Comments
- **Complex DSP logic**: Explain "why" not "what" (code is self-documenting for "what")
- **Real-time constraints**: Flag critical sections with comments like `// REAL-TIME SAFE: No allocations`
- **Magic numbers**: Always explain hardcoded thresholds (e.g., `// 1500 Hz centroid threshold separates kick from snare`)

## Project-Specific Patterns

### Error Handling

**Rust**:
- Use custom error types in `error/` module (`AudioError`, `CalibrationError`)
- All FFI functions return `Result<T, Error>` with proper error types
- Audio thread: Log errors but never panic (graceful degradation)
- Analysis thread: Can return errors, handled by caller
- **Zero unwrap() calls in production code** - all unwraps confined to `#[cfg(test)]` blocks

**Dart**:
- Services catch FFI errors and translate to user-friendly messages
- Use custom exceptions from `exceptions.dart`
- Error handler service provides centralized error handling
- Show user-friendly error messages in UI (never expose stack traces)

### Real-Time Safety Checklist

Every audio callback function must pass this checklist:
- [ ] No heap allocations (`Vec::push()`, `Box::new()`, `String::from()`)
- [ ] No locking primitives (`Mutex`, `RwLock`, `Arc::clone()` with atomic operations)
- [ ] No blocking I/O (`println!`, file operations, network)
- [ ] No unbounded loops (all loops must have compile-time known upper bounds)
- [ ] Execution time is deterministic and < buffer duration

### Flutter-Rust Bridge Patterns

**Async operations**:
```dart
// Dart: All Rust calls are async, go through service layer
final audioService = getIt<IAudioService>();
await audioService.startAudio(bpm: 120);
```

**Streaming events**:
```rust
// Rust: Return Stream for continuous updates
#[flutter_rust_bridge::frb(stream)]
pub async fn classification_stream() -> impl Stream<Item = ClassificationResult> {
    // Implementation using async channels
}
```

**Ownership transfer**:
```rust
// Rust: Use managers within AppContext for shared state
pub struct AppContext {
    audio_engine_manager: AudioEngineManager,
    // Managers handle their own synchronization
}
```

This structure ensures the codebase remains maintainable, testable, and adheres to the strict real-time constraints required for low-latency audio processing.
