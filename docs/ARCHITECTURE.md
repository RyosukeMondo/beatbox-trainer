# Architecture Documentation

## Overview

The Beatbox Trainer application is built with a layered, dependency-injected architecture designed for testability, maintainability, and real-time audio performance. This document explains the key architectural patterns, components, and design decisions.

## System Architecture

### Four-Layer Stack

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Dart/Flutter UI                                    │
│ - TrainingScreen, CalibrationScreen                         │
│ - Dependency Injection (services via constructor)           │
│ - Reactive state management                                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Service Abstractions                               │
│ - IAudioService, IPermissionService (interfaces)            │
│ - AudioServiceImpl, PermissionServiceImpl (concrete)        │
│ - ErrorHandler (Rust error → user-friendly messages)        │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Rust Audio Engine                                  │
│ - AppContext (dependency injection container)               │
│ - AudioEngine, CalibrationProcedure, CalibrationState       │
│ - Lock-free audio callback (zero allocations)               │
│ - Multi-threaded analysis pipeline                          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Oboe C++ Audio I/O                                 │
│ - Low-latency native audio streams                          │
│ - Platform-specific optimizations                           │
└─────────────────────────────────────────────────────────────┘
```

## Core Architectural Patterns

### 1. Dependency Injection

All components receive their dependencies via constructor injection, enabling:
- **Testability**: Mock dependencies in unit tests
- **Flexibility**: Swap implementations without code changes
- **Clarity**: Explicit dependencies visible in constructor

#### Example: Dart Service Injection

```dart
class TrainingScreen extends StatefulWidget {
  final IAudioService audioService;
  final IPermissionService permissionService;

  const TrainingScreen({
    IAudioService? audioService,
    IPermissionService? permissionService,
    super.key,
  }) : audioService = audioService ?? AudioServiceImpl(),
       permissionService = permissionService ?? PermissionServiceImpl();
}
```

#### Example: Rust AppContext

```rust
pub struct AppContext {
    audio_engine: Arc<Mutex<Option<AudioEngineState>>>,
    calibration_procedure: Arc<Mutex<Option<CalibrationProcedure>>>,
    calibration_state: Arc<RwLock<CalibrationState>>,
    // Broadcast channels for streams
}

impl AppContext {
    pub fn new() -> Self { /* ... */ }

    #[cfg(test)]
    pub fn new_test() -> Self { /* isolated test instance */ }
}
```

### 2. Typed Error Handling

Replaces stringly-typed errors with structured error types:

#### Rust Error Types

```rust
pub enum AudioError {
    BpmInvalid { value: u32, min: u32, max: u32 },
    AlreadyRunning,
    NotRunning,
    HardwareError(String),
    PermissionDenied,
    StreamOpenFailed { details: String },
    LockPoisoned { component: String },
}

pub enum CalibrationError {
    InsufficientSamples { collected: u8, needed: u8 },
    InvalidFeatures { reason: String },
    NotComplete,
    AlreadyInProgress,
    StatePoisoned,
}
```

#### Error Translation Layer

```rust
// Rust side: Return typed error
pub fn start_audio(bpm: u32) -> Result<(), AudioError> {
    if bpm < 40 || bpm > 240 {
        return Err(AudioError::BpmInvalid { value: bpm, min: 40, max: 240 });
    }
    // ...
}
```

```dart
// Dart side: Translate to user-friendly message
class ErrorHandler {
  String translateAudioError(String rustError) {
    if (rustError.contains('BPM') && rustError.contains('out of range')) {
      return 'Please choose a tempo between 40 and 240 BPM';
    }
    // ...
  }
}
```

### 3. Service Layer Abstraction

Separates business logic from presentation and data access:

```dart
abstract class IAudioService {
  Future<void> startAudio({required int bpm});
  Future<void> stopAudio();
  Stream<ClassificationResult> getClassificationStream();
}

class AudioServiceImpl implements IAudioService {
  final ErrorHandler _errorHandler;

  @override
  Future<void> startAudio({required int bpm}) async {
    try {
      await api.startAudio(bpm: bpm);
    } catch (e) {
      throw AudioServiceException(
        message: _errorHandler.translateAudioError(e.toString()),
      );
    }
  }
}
```

### 4. Lock-Free Audio Callback

Audio processing path maintains real-time guarantees:
- **Zero allocations**: All buffers pre-allocated
- **Lock-free**: Atomic operations only (AtomicU64, AtomicU32)
- **Zero-copy**: Lock-free SPSC queue for audio samples
- **<20ms latency**: Guaranteed by Oboe + lock-free design

```rust
// Audio callback (runs in real-time thread)
move |_, data: &mut [i16], _| {
    // Lock-free: atomic read only
    let bpm = audio_state.bpm.load(Ordering::Relaxed);
    let frame_counter = audio_state.frame_counter.fetch_add(1, Ordering::Relaxed);

    // Zero-allocation: pre-computed click samples
    if is_click_frame {
        data.copy_from_slice(&click_samples);
    }

    // Lock-free: SPSC queue push
    let _ = input_tx.try_send(audio_buffer);
}
```

## Key Components

### AppContext (Rust)

**Purpose**: Dependency injection container replacing global state

**File**: `rust/src/context.rs`

**Responsibilities**:
- Owns all shared state (AudioEngine, CalibrationProcedure, etc.)
- Provides business logic methods (start_audio, stop_audio, set_bpm)
- Manages stream lifecycle (classification_stream, calibration_stream)
- Safe lock helpers (eliminates unwrap() calls)

**Thread Safety**:
- `Arc<Mutex<T>>` for exclusive access
- `Arc<RwLock<T>>` for shared reads, exclusive writes
- Broadcast channels for multi-subscriber streams

**Testing Support**:
```rust
#[cfg(test)]
impl AppContext {
    pub fn new_test() -> Self { /* isolated instance */ }
    pub fn reset(&mut self) { /* cleanup for parallel tests */ }
}
```

### Service Layer (Dart)

**Purpose**: Abstract FFI bridge for testability and error translation

**Components**:

1. **IAudioService**: Interface defining audio operations
2. **AudioServiceImpl**: Wraps FFI bridge with error handling
3. **IPermissionService**: Interface for permission management
4. **PermissionServiceImpl**: Wraps permission_handler package
5. **ErrorHandler**: Translates technical errors to user messages

**Benefits**:
- FFI bridge mockable in tests
- Error messages user-friendly
- Business logic separated from UI
- Type-safe contracts (interfaces)

### Custom Error Types (Rust)

**Purpose**: Replace `Result<T, String>` with structured errors

**Files**:
- `rust/src/error.rs`: Error enum definitions
- `rust/src/api.rs`: FFI functions return typed errors
- `lib/services/error_handler/`: Dart translation layer

**Error Codes**:
```rust
impl ErrorCode for AudioError {
    fn code(&self) -> u32 {
        match self {
            AudioError::BpmInvalid { .. } => 1001,
            AudioError::AlreadyRunning => 1002,
            AudioError::NotRunning => 1003,
            AudioError::HardwareError(_) => 1004,
            AudioError::PermissionDenied => 1005,
            AudioError::StreamOpenFailed { .. } => 1006,
            AudioError::LockPoisoned { .. } => 1007,
        }
    }
}
```

### Shared UI Components

**Purpose**: Eliminate code duplication, ensure consistency

**Components**:
- `ErrorDialog`: Configurable error display with retry callback
- `LoadingOverlay`: Spinner with optional message
- `StatusCard`: Colored card with icon, title, subtitle
- `DisplayFormatters`: Utility functions (BPM, timing, colors)

**Benefits**:
- ~100 lines removed from screens
- Consistent UI across app
- Easily testable in isolation
- Single source of truth for styling

## Data Flow

### Audio Training Flow

```
User taps Start
    ↓
TrainingScreen._startTraining()
    ↓
permissionService.requestMicrophonePermission()
    ↓ (granted)
audioService.startAudio(bpm: 120)
    ↓
FFI Bridge: api.startAudio(bpm: 120)
    ↓
AppContext.start_audio(120)
    ↓
AudioEngine.start() → Spawns threads
    ↓
Audio Thread (lock-free callback)
    ├─→ Clicks playback
    └─→ Mic input → SPSC queue
             ↓
Analysis Thread
    ├─→ OnsetDetector
    ├─→ FeatureExtractor
    ├─→ Classifier
    └─→ Quantizer → MPSC channel
             ↓
Broadcast Channel → Multiple subscribers
    ↓
FFI Stream: classificationStream()
    ↓
audioService.getClassificationStream()
    ↓
TrainingScreen: StreamBuilder updates UI
```

### Error Propagation Flow

```
Rust Error (AudioError::StreamOpenFailed)
    ↓
FFI Bridge: Serialized to String
    ↓
Dart Exception: Caught in AudioServiceImpl
    ↓
ErrorHandler.translateAudioError()
    ↓
AudioServiceException with user message
    ↓
ErrorDialog.show(context, message, onRetry)
    ↓
User sees: "Unable to access audio hardware..."
```

## Module Organization

### Rust Module Structure

```
rust/src/
├── error.rs              # Custom error types (AudioError, CalibrationError)
├── context.rs            # AppContext DI container
├── api.rs                # FFI bridge (thin wrappers calling AppContext)
├── audio/
│   ├── mod.rs
│   ├── engine.rs         # AudioEngine (lock-free audio path)
│   └── buffer_pool.rs    # Lock-free SPSC queues
├── analysis/
│   ├── mod.rs            # Pipeline coordinator
│   ├── onset.rs          # OnsetDetector
│   ├── classifier.rs     # SoundClassifier
│   ├── quantizer.rs      # BeatQuantizer
│   └── features/         # Feature extraction (split into modules)
│       ├── mod.rs        # FeatureExtractor coordinator
│       ├── spectral.rs   # Spectral features (centroid, rolloff, flatness)
│       ├── temporal.rs   # Temporal features (ZCR, decay)
│       ├── fft.rs        # FFT computation
│       └── types.rs      # Features struct
└── calibration/
    ├── mod.rs
    ├── procedure.rs      # CalibrationProcedure orchestration
    ├── validation.rs     # Sample validation logic
    ├── progress.rs       # Progress tracking
    └── state.rs          # CalibrationState (thresholds storage)
```

### Dart Module Structure

```
lib/
├── main.dart
├── bridge/
│   └── api.dart          # FFI bridge (flutter_rust_bridge generated)
├── services/             # Service layer (NEW)
│   ├── audio/
│   │   ├── i_audio_service.dart          # Interface
│   │   └── audio_service_impl.dart       # FFI wrapper
│   ├── permission/
│   │   ├── i_permission_service.dart     # Interface
│   │   └── permission_service_impl.dart  # permission_handler wrapper
│   └── error_handler/
│       ├── error_handler.dart            # Error translation
│       └── exceptions.dart               # Dart exception types
├── models/               # Value objects (no changes)
│   ├── classification_result.dart
│   ├── timing_feedback.dart
│   └── calibration_progress.dart
└── ui/
    ├── screens/
    │   ├── training_screen.dart          # Injects services
    │   └── calibration_screen.dart       # Injects services
    ├── widgets/          # Shared components (NEW)
    │   ├── error_dialog.dart
    │   ├── loading_overlay.dart
    │   ├── status_card.dart
    │   └── permission_dialogs.dart
    └── utils/            # Display utilities (NEW)
        └── display_formatters.dart
```

## Design Decisions

### Why AppContext Instead of Trait-Based DI?

**Decision**: Single AppContext struct with all dependencies

**Rationale**:
- Simpler for FFI bridge (single static instead of generic injection)
- Sufficient for app size (not a microservices architecture)
- Easier to test (new_test() creates isolated instance)
- Maintains thread safety with Arc<Mutex<T>>

**Trade-off**: Less flexible than trait-based DI, but adequate for current needs

### Why Constructor Injection with Default Factory?

**Decision**: Optional parameters with default implementations

```dart
const TrainingScreen({
  IAudioService? audioService,
  super.key,
}) : audioService = audioService ?? AudioServiceImpl();
```

**Rationale**:
- Production code uses defaults (no boilerplate)
- Tests inject mocks easily
- No need for DI framework (GetIt, Provider, etc.)
- Clear dependency contracts

**Trade-off**: Slightly verbose constructors, but explicit dependencies

### Why Lock-Free Audio Path?

**Decision**: Atomic operations and SPSC queues in audio callback

**Rationale**:
- Oboe requires <20ms latency for glitch-free audio
- Mutexes/RwLocks can block (priority inversion risk)
- Atomics provide bounded worst-case latency
- SPSC queues are lock-free and cache-efficient

**Trade-off**: More complex than locks, but essential for real-time audio

### Why Manual Error Translation Instead of Code Generation?

**Decision**: Pattern matching on Rust error strings in Dart

**Rationale**:
- flutter_rust_bridge doesn't support custom error serialization
- Simple pattern matching sufficient for 10-15 error types
- User messages need context (not 1:1 mapping)
- Centralized in ErrorHandler for maintainability

**Trade-off**: Fragile to Rust error message changes, but acceptable

## Performance Considerations

### Audio Callback Optimization

- **Pre-allocation**: All buffers allocated at startup
- **Zero-copy**: Lock-free queues avoid memcpy
- **Atomic operations**: Relaxed ordering for counters (no cache invalidation)
- **Branch prediction**: Metronome click check optimized for common case

### Analysis Thread Optimization

- **Buffered processing**: 512-sample chunks (balance latency vs overhead)
- **FFT reuse**: Single FFT plan allocated once
- **Feature caching**: Spectral features computed once per onset
- **Async classification**: Non-blocking channel sends

### UI Performance

- **StreamBuilder**: Reactive updates without manual setState
- **Shared widgets**: Reduced widget rebuilds (const constructors)
- **Lazy loading**: Classification stream only active during training

## Testing Strategy

See [TESTING.md](TESTING.md) for comprehensive testing documentation.

**Key Testing Patterns**:

1. **Rust Unit Tests**: AppContext business logic with new_test()
2. **Dart Service Tests**: Mocked FFI bridge with mocktail
3. **Dart Widget Tests**: Mocked services with flutter_test
4. **Rust Integration Tests**: Full lifecycle with tokio::test
5. **Manual Device Tests**: Real audio hardware validation

## Migration Path (Completed)

The refactoring was completed in 6 phases:

1. **Phase 1: Error Infrastructure** - Custom error types, eliminate unwrap()
2. **Phase 2: Dependency Injection** - AppContext, replace global statics
3. **Phase 3: Dart Service Layer** - Service abstractions, error translation
4. **Phase 4: Shared UI Components** - Extract widgets, reduce duplication
5. **Phase 5: File/Function Refactoring** - Split large files, break down functions
6. **Phase 6: Testing Infrastructure** - Pre-commit hooks, coverage reporting

All phases complete. See `.spec-workflow/specs/code-quality-refactoring/` for detailed spec.

## References

- **Steering Documents**: `.spec-workflow/steering/tech.md`, `structure.md`
- **Design Document**: `.spec-workflow/specs/code-quality-refactoring/design.md`
- **Implementation Logs**: `.spec-workflow/specs/code-quality-refactoring/Implementation Logs/`
- **Test Documentation**: [TESTING.md](TESTING.md)
