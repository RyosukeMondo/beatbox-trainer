# Project Structure

## Directory Organization

```
beatbox-trainer/
├── lib/                        # Dart/Flutter UI source code
│   ├── main.dart              # Application entry point
│   ├── ui/                    # UI components and screens
│   │   ├── screens/          # Main app screens
│   │   ├── widgets/          # Reusable UI widgets
│   │   └── theme/            # App theming and styles
│   ├── bridge/               # flutter_rust_bridge generated bindings
│   │   └── api.dart          # Auto-generated Dart API for Rust calls
│   └── models/               # Dart data models
│       ├── classification.dart    # Sound classification results
│       ├── timing.dart           # Timing feedback models
│       └── calibration.dart      # Calibration state
│
├── rust/                      # Rust audio engine (core DSP)
│   ├── src/
│   │   ├── lib.rs            # Library entry point, JNI_OnLoad definition
│   │   ├── api.rs            # Public API exposed to Dart via flutter_rust_bridge
│   │   ├── audio/            # Audio I/O layer
│   │   │   ├── engine.rs     # AudioEngine struct, Oboe callbacks
│   │   │   ├── metronome.rs  # Sample-accurate metronome generation
│   │   │   └── buffer_pool.rs # SPSC queue + object pool pattern
│   │   ├── analysis/         # DSP processing layer
│   │   │   ├── onset.rs      # Onset detection (spectral flux)
│   │   │   ├── features.rs   # Feature extraction (centroid, ZCR, etc.)
│   │   │   ├── classifier.rs # Heuristic rule-based classifier
│   │   │   └── quantizer.rs  # Timing quantization to metronome grid
│   │   └── calibration/      # User calibration system
│   │       ├── state.rs      # Calibration thresholds storage
│   │       └── procedure.rs  # Calibration workflow logic
│   └── Cargo.toml            # Rust dependencies
│
├── android/                   # Android-specific configuration
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── kotlin/com/ryosukemondo/beatbox_trainer/
│   │   │   │   └── MainActivity.kt    # System.loadLibrary() init block
│   │   │   ├── java/io/flutter/plugins/
│   │   │   │   └── GeneratedPluginRegistrant.java
│   │   │   ├── AndroidManifest.xml   # Microphone permissions
│   │   │   └── res/                  # Android resources
│   │   └── build.gradle.kts          # App-level build config
│   ├── gradle/                       # Gradle wrapper
│   ├── build.gradle.kts              # Project-level build config
│   └── settings.gradle.kts           # Gradle settings
│
├── ios/                       # iOS-specific configuration (future)
├── macos/                     # macOS-specific configuration (future)
├── windows/                   # Windows-specific configuration (future)
├── linux/                     # Linux-specific configuration (future)
│
├── test/                      # Dart widget and integration tests
│   ├── widget_test.dart      # Example widget tests
│   ├── ui/                   # UI component tests
│   └── bridge/               # Rust bridge integration tests
│
├── docs/                      # Technical documentation
│   └── search.md             # Architecture blueprint (Japanese)
│
├── .spec-workflow/            # Spec-workflow MCP server artifacts
│   ├── steering/             # Steering documents (this file)
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
- **Screens**: `snake_case.dart` (e.g., `training_screen.dart`, `calibration_screen.dart`)
- **Widgets**: `snake_case.dart` (e.g., `sound_indicator.dart`, `metronome_controls.dart`)
- **Models**: `snake_case.dart` (e.g., `classification_result.dart`, `timing_feedback.dart`)
- **Tests**: `[filename]_test.dart` (e.g., `classification_result_test.dart`)

**Rust Layer**:
- **Modules**: `snake_case.rs` (e.g., `audio_engine.rs`, `onset_detector.rs`)
- **Tests**: Inline unit tests using `#[cfg(test)]` modules within each `.rs` file
- **Integration tests**: `tests/` directory at crate root

**Kotlin/Java Layer**:
- **Activities**: `PascalCase.kt` (e.g., `MainActivity.kt`)
- **Package structure**: Follows reverse domain notation (`com.ryosukemondo.beatbox_trainer`)

### Code

**Dart**:
- **Classes**: `PascalCase` (e.g., `TrainingScreen`, `SoundClassifier`)
- **Functions/Methods**: `camelCase` (e.g., `startTraining()`, `updateBpm()`)
- **Constants**: `lowerCamelCase` with `const` keyword (e.g., `defaultBpm = 120`)
- **Private members**: Prefix with `_` (e.g., `_audioEngine`, `_initializeState()`)

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

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

import '../models/classification_result.dart';
import '../bridge/api.dart';
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
```

### Module Organization

**Rust Crate Structure**:
- **Public API** (`api.rs`): Only types and functions exposed to Dart (annotated with `#[flutter_rust_bridge::frb]`)
- **Internal modules**: All implementation details are `pub(crate)` or private
- **No circular dependencies**: Audio layer → Analysis layer → Calibration layer (one-way dependency flow)

## Code Structure Patterns

### Dart File Organization
```dart
// 1. Imports (sorted by category)
import 'dart:async';
import 'package:flutter/material.dart';

// 2. Class definition with documentation
/// Widget for displaying real-time classification feedback.
class ClassificationWidget extends StatefulWidget {
  // 3. Public constants
  static const double defaultSize = 200.0;

  // 4. Constructor and fields
  const ClassificationWidget({Key? key, required this.stream}) : super(key: key);

  final Stream<ClassificationResult> stream;

  // 5. State creation
  @override
  State<ClassificationWidget> createState() => _ClassificationWidgetState();
}

// 6. State implementation
class _ClassificationWidgetState extends State<ClassificationWidget> {
  // Private fields
  ClassificationResult? _latestResult;

  // Lifecycle methods
  @override
  void initState() { /* ... */ }

  @override
  void dispose() { /* ... */ }

  // Build method
  @override
  Widget build(BuildContext context) { /* ... */ }

  // Private helper methods
  void _handleResult(ClassificationResult result) { /* ... */ }
}
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

### Function/Method Organization
```rust
// Input validation first
pub fn classify_sound(features: &Features, thresholds: &Thresholds) -> Result<BeatboxHit, Error> {
    // 1. Validate inputs
    if features.centroid <= 0.0 {
        return Err(Error::InvalidFeatures("Centroid must be positive"));
    }

    // 2. Core classification logic
    let hit = if features.centroid < thresholds.kick_centroid {
        if features.zcr < thresholds.kick_zcr {
            BeatboxHit::Kick
        } else {
            BeatboxHit::Unknown
        }
    } else if features.centroid < thresholds.snare_centroid {
        BeatboxHit::Snare
    } else {
        BeatboxHit::HiHat
    };

    // 3. Clear return point
    Ok(hit)
}
```

## Code Organization Principles

1. **Single Responsibility**:
   - Each Rust module handles one aspect (audio I/O, onset detection, feature extraction, classification)
   - Each Dart screen manages one user workflow (training, calibration, settings)

2. **Modularity**:
   - Rust audio engine is completely independent of Flutter UI
   - flutter_rust_bridge provides clean abstraction boundary
   - DSP algorithms are pure functions (no side effects, fully testable)

3. **Testability**:
   - Rust: Unit tests alongside implementation (`#[cfg(test)]`)
   - Dart: Widget tests in `test/` directory mirror `lib/` structure
   - Mock audio data for integration tests (pre-recorded beatbox samples)

4. **Consistency**:
   - Follow Dart style guide (enforced by `dart format`)
   - Follow Rust API guidelines (enforced by `clippy`)
   - Real-time safety rules apply universally to all audio callback code

## Module Boundaries

### Layer Boundaries (Strict Separation)

**UI Layer (Dart) ← Bridge → Engine Layer (Rust)**:
- **Direction**: UI calls Engine via `flutter_rust_bridge`, Engine sends events to UI via `Stream`
- **Contract**: UI never accesses audio hardware directly; all audio operations go through Rust API
- **Rationale**: Maintains real-time guarantees, prevents GC pauses in audio thread

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
- **Android-Specific**: `MainActivity.kt` (JNI initialization), `AndroidManifest.xml` (permissions)
- **Cross-Platform**: Entire Rust codebase, majority of Dart UI code
- **Isolation**: Android-specific code limited to `android/` directory; no platform checks in `lib/` or `rust/src/`

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

**Example**:
```rust
/// Computes spectral centroid (brightness) of the input spectrum.
///
/// # Formula
/// centroid = Σ(f_i * mag_i) / Σ(mag_i)
///
/// # Examples
/// ```
/// let centroid = compute_centroid(&spectrum, 48000);
/// assert!(centroid > 0.0 && centroid < 24000.0);
/// ```
pub fn compute_centroid(spectrum: &[f32], sample_rate: u32) -> f32 { /* ... */ }
```

### Dart Documentation (dartdoc)
- **Public widgets**: Document purpose and usage with `///` comments
- **State management**: Explain lifecycle and state transitions
- **Stream contracts**: Document what events the Stream emits and when

**Example**:
```dart
/// Displays real-time sound classification and timing feedback.
///
/// Listens to [classificationStream] and updates UI whenever a new
/// beatbox sound is detected. Shows sound type (KICK, SNARE, HI-HAT)
/// and timing accuracy (ON-TIME, EARLY, LATE).
class ClassificationWidget extends StatefulWidget { /* ... */ }
```

### Inline Comments
- **Complex DSP logic**: Explain "why" not "what" (code is self-documenting for "what")
- **Real-time constraints**: Flag critical sections with comments like `// REAL-TIME SAFE: No allocations`
- **Magic numbers**: Always explain hardcoded thresholds (e.g., `// 1500 Hz centroid threshold separates kick from snare`)

### Module-Level Documentation
- **Purpose**: Each Rust module (`mod.rs` or top of `.rs` file) should have `//!` module doc
- **Architecture diagrams**: Complex modules (e.g., `audio/`) should reference external docs
- **Thread safety**: Document which types are `Send`/`Sync` and why

## Project-Specific Patterns

### Error Handling

**Rust**:
- Use `Result<T, Error>` for fallible operations
- Audio thread: Log errors but never panic (use `Result` with graceful degradation)
- Analysis thread: Can panic on unrecoverable errors (will restart thread)

**Dart**:
- Use `try-catch` for async operations
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
// Dart: All Rust calls are async
final result = await rustApi.startAudio(bpm: 120);
```

**Streaming events**:
```rust
// Rust: Return Stream for continuous updates
#[flutter_rust_bridge::frb]
pub fn classification_stream() -> impl Stream<Item = ClassificationResult> {
    // Implementation using async channels
}
```

**Ownership transfer**:
```rust
// Rust: Use Arc for shared state across threads
pub struct AudioEngine {
    state: Arc<Mutex<State>>,  // Only non-audio thread locks this
}
```

This structure ensures the codebase remains maintainable, testable, and adheres to the strict real-time constraints required for low-latency audio processing.
