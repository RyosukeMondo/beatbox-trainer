# Manager Pattern in Rust

## Overview

The Manager Pattern refactors a monolithic "god object" (`AppContext`) into focused, composable manager classes that each handle a single responsibility. This architectural pattern improves testability, reduces complexity, and makes the codebase more maintainable.

## Motivation

Prior to refactoring, `AppContext` was a **1495-line god object** violating the Single Responsibility Principle:

```rust
// ❌ BEFORE: God object with too many responsibilities
pub struct AppContext {
    audio_engine: Arc<Mutex<Option<AudioEngineState>>>,
    calibration_procedure: Arc<Mutex<Option<CalibrationProcedure>>>,
    calibration_state: Arc<RwLock<CalibrationState>>,
    classification_tx: Arc<Mutex<Option<broadcast::Sender<ClassificationResult>>>>,
    // ... 15+ more fields
}

impl AppContext {
    // 86-line method managing audio engine lifecycle
    pub fn start_audio(&self, bpm: u32) -> Result<(), AudioError> { /* ... */ }

    // 73-line method managing calibration workflow
    pub fn finish_calibration(&self) -> Result<CalibrationData, CalibrationError> { /* ... */ }

    // 45-line method setting up broadcast channels
    fn init_classification_broadcast(&self) { /* ... */ }

    // ... 20+ more methods
}
```

**Problems**:
- **Hard to test**: Tests required full AppContext with all dependencies
- **Hard to understand**: Mixed concerns (audio, calibration, streaming)
- **Hard to modify**: Changes to one feature risked breaking others
- **Violates SRP**: Single class responsible for everything
- **High complexity**: Functions exceeded 50-line limit, file exceeded 500 lines

## Core Concepts

### Single Responsibility Principle (SRP)

Each manager class handles **one and only one** concern:

| Manager | Responsibility |
|---------|---------------|
| `AudioEngineManager` | Audio engine lifecycle (start/stop/setBpm) |
| `CalibrationManager` | Calibration workflow and state persistence |
| `BroadcastChannelManager` | Tokio broadcast channel setup and subscription |

### Facade Pattern

After refactoring, `AppContext` becomes a **thin facade** that composes managers and delegates method calls:

```rust
// ✅ AFTER: Facade composing focused managers
pub struct AppContext {
    audio: AudioEngineManager,
    calibration: CalibrationManager,
    broadcasts: BroadcastChannelManager,
}

impl AppContext {
    pub fn new() -> Self {
        Self {
            audio: AudioEngineManager::new(),
            calibration: CalibrationManager::new(),
            broadcasts: BroadcastChannelManager::new(),
        }
    }

    pub fn start_audio(&self, bpm: u32) -> Result<(), AudioError> {
        let broadcast_tx = self.broadcasts.init_classification();
        let calibration_state = self.calibration.get_state_arc();

        // Delegate to AudioEngineManager
        self.audio.start(bpm, calibration_state, broadcast_tx)
    }
}
```

**Benefits**:
- **Reduced complexity**: AppContext reduced from 1495 lines to < 200 lines
- **Clear separation**: Each manager is independently testable
- **Backward compatible**: Public API unchanged; existing FFI calls work as-is

## Manager Implementations

### AudioEngineManager

**Responsibility**: Audio engine lifecycle and BPM management

**File**: `rust/src/managers/audio_engine_manager.rs`

**Key Methods**:

```rust
pub struct AudioEngineManager {
    engine: Arc<Mutex<Option<AudioEngineState>>>,
}

impl AudioEngineManager {
    /// Create a new manager with no audio engine running
    pub fn new() -> Self;

    /// Start audio engine with specified BPM
    ///
    /// Validates BPM, creates buffer pool, starts audio streams.
    /// Reduced from 86-line method to focused orchestration.
    pub fn start(
        &self,
        bpm: u32,
        calibration: Arc<RwLock<CalibrationState>>,
        broadcast_tx: broadcast::Sender<ClassificationResult>,
    ) -> Result<(), AudioError>;

    /// Stop audio engine and release resources
    pub fn stop(&self) -> Result<(), AudioError>;

    /// Update BPM on running audio engine
    pub fn set_bpm(&self, bpm: u32) -> Result<(), AudioError>;
}
```

**Design Highlights**:

1. **Helper Method Extraction**: Large methods broken into focused helpers:
   ```rust
   // High-level orchestration (< 20 lines)
   pub fn start(&self, ...) -> Result<(), AudioError> {
       self.validate_bpm(bpm)?;
       let mut guard = self.lock_engine()?;
       self.check_not_running(&guard)?;

       let buffer_pool = self.create_buffer_pool();
       let mut engine = self.create_engine(bpm, buffer_pool)?;

       self.setup_classification(
           &mut engine,
           calibration,
           broadcast_tx,
       )?;

       self.start_streams(&mut engine)?;
       *guard = Some(engine);
       Ok(())
   }

   // Focused helpers (each < 15 lines)
   fn validate_bpm(&self, bpm: u32) -> Result<(), AudioError> { /* ... */ }
   fn lock_engine(&self) -> Result<MutexGuard<...>, AudioError> { /* ... */ }
   fn check_not_running(&self, guard: &...) -> Result<(), AudioError> { /* ... */ }
   fn create_buffer_pool(&self) -> Arc<BufferPool> { /* ... */ }
   fn create_engine(&self, bpm: u32, pool: Arc<BufferPool>) -> Result<...> { /* ... */ }
   fn setup_classification(&self, ...) -> Result<(), AudioError> { /* ... */ }
   fn start_streams(&self, engine: &mut AudioEngineState) -> Result<(), AudioError> { /* ... */ }
   ```

2. **Single Level of Abstraction Principle (SLAP)**: Each method operates at one abstraction level
3. **Platform Abstraction**: Conditional compilation for Android vs desktop testing:
   ```rust
   #[cfg(target_os = "android")]
   use crate::audio::engine::AudioEngine;

   #[cfg(not(target_os = "android"))]
   // Stub implementation for desktop testing
   ```

**Testability**: Can be tested in isolation with stub audio engine on desktop

### CalibrationManager

**Responsibility**: Calibration workflow and state management

**File**: `rust/src/managers/calibration_manager.rs`

**Key Methods**:

```rust
pub struct CalibrationManager {
    procedure: Arc<Mutex<Option<CalibrationProcedure>>>,
    state: Arc<RwLock<CalibrationState>>,
}

impl CalibrationManager {
    /// Create a new manager with default calibration state
    pub fn new() -> Self;

    /// Start calibration procedure
    ///
    /// Begins collecting samples for KICK, SNARE, HI-HAT sequence
    pub fn start(
        &self,
        broadcast_tx: broadcast::Sender<CalibrationProgress>,
    ) -> Result<(), CalibrationError>;

    /// Finish calibration and compute thresholds
    pub fn finish(&self) -> Result<CalibrationData, CalibrationError>;

    /// Get current calibration state
    pub fn get_state(&self) -> Result<CalibrationState, CalibrationError>;

    /// Load saved calibration state (for persistence)
    pub fn load_state(&self, state: CalibrationState) -> Result<(), CalibrationError>;

    /// Get calibration state as Arc for sharing with audio engine
    pub fn get_state_arc(&self) -> Arc<RwLock<CalibrationState>>;
}
```

**Design Highlights**:

1. **State Encapsulation**: Owns calibration procedure and state with proper locking
2. **Error Handling**: Returns typed `CalibrationError` instead of panicking
3. **Helper Method Extraction**:
   ```rust
   pub fn finish(&self) -> Result<CalibrationData, CalibrationError> {
       let mut procedure_guard = self.lock_procedure()?;
       self.check_in_progress(&procedure_guard)?;

       let data = self.extract_data(&mut procedure_guard)?;
       self.update_state(&data)?;

       Ok(data)
   }

   fn lock_procedure(&self) -> Result<MutexGuard<...>, CalibrationError> { /* ... */ }
   fn check_in_progress(&self, guard: &...) -> Result<(), CalibrationError> { /* ... */ }
   fn extract_data(&self, guard: &mut ...) -> Result<CalibrationData, CalibrationError> { /* ... */ }
   fn update_state(&self, data: &CalibrationData) -> Result<(), CalibrationError> { /* ... */ }
   ```

**Thread Safety**: Uses `Arc<Mutex<T>>` for exclusive access, `Arc<RwLock<T>>` for concurrent reads

### BroadcastChannelManager

**Responsibility**: Tokio broadcast channel setup and subscription management

**File**: `rust/src/managers/broadcast_manager.rs`

**Key Methods**:

```rust
pub struct BroadcastChannelManager {
    classification_tx: Arc<Mutex<Option<broadcast::Sender<ClassificationResult>>>>,
    calibration_tx: Arc<Mutex<Option<broadcast::Sender<CalibrationProgress>>>>,
}

impl BroadcastChannelManager {
    /// Create a new manager with no active channels
    pub fn new() -> Self;

    /// Initialize classification broadcast channel
    ///
    /// Returns a broadcast sender that audio engine uses to emit results.
    /// Multiple subscribers can receive the same stream.
    pub fn init_classification(&self) -> broadcast::Sender<ClassificationResult>;

    /// Subscribe to classification stream
    ///
    /// Returns an UnboundedReceiverStream for Dart FFI consumption.
    pub fn subscribe_classification(
        &self,
    ) -> Result<UnboundedReceiverStream<ClassificationResult>, AudioError>;

    /// Initialize calibration broadcast channel
    pub fn init_calibration(&self) -> broadcast::Sender<CalibrationProgress>;

    /// Subscribe to calibration stream
    pub fn subscribe_calibration(
        &self,
    ) -> Result<UnboundedReceiverStream<CalibrationProgress>, CalibrationError>;
}
```

**Design Highlights**:

1. **Fan-out Pattern**: Single broadcast sender → multiple receivers
2. **Lazy Initialization**: Channels created only when first needed
3. **Stream Simplification**: Eliminates unnecessary mpsc → broadcast forwarding
   ```rust
   // ❌ OLD: Double forwarding (mpsc → broadcast → FFI)
   let (tx, rx) = mpsc::unbounded_channel();
   tokio::spawn(async move {
       while let Some(result) = rx.recv().await {
           let _ = broadcast_tx.send(result);
       }
   });

   // ✅ NEW: Direct broadcast (audio engine → broadcast → FFI)
   let broadcast_tx = self.init_classification();
   audio_engine.set_classification_callback(move |result| {
       let _ = broadcast_tx.send(result);
   });
   ```

4. **FFI Integration**: Converts `broadcast::Receiver` → `mpsc::UnboundedReceiver` → `UnboundedReceiverStream` for Flutter consumption

**Benefits**: Simpler code, fewer allocations, lower latency

## Integration Pattern

### AppContext as Facade

The refactored `AppContext` is a thin facade delegating to managers:

**File**: `rust/src/context.rs`

```rust
use crate::managers::{AudioEngineManager, CalibrationManager, BroadcastChannelManager};

pub struct AppContext {
    audio: AudioEngineManager,
    calibration: CalibrationManager,
    broadcasts: BroadcastChannelManager,
}

impl AppContext {
    pub fn new() -> Self {
        Self {
            audio: AudioEngineManager::new(),
            calibration: CalibrationManager::new(),
            broadcasts: BroadcastChannelManager::new(),
        }
    }

    // ========================================================================
    // AUDIO METHODS (delegate to AudioEngineManager)
    // ========================================================================

    pub fn start_audio(&self, bpm: u32) -> Result<(), AudioError> {
        let broadcast_tx = self.broadcasts.init_classification();
        let calibration_state = self.calibration.get_state_arc();
        self.audio.start(bpm, calibration_state, broadcast_tx)
    }

    pub fn stop_audio(&self) -> Result<(), AudioError> {
        self.audio.stop()
    }

    pub fn set_bpm(&self, bpm: u32) -> Result<(), AudioError> {
        self.audio.set_bpm(bpm)
    }

    // ========================================================================
    // CALIBRATION METHODS (delegate to CalibrationManager)
    // ========================================================================

    pub fn start_calibration(&self) -> Result<(), CalibrationError> {
        let broadcast_tx = self.broadcasts.init_calibration();
        self.calibration.start(broadcast_tx)
    }

    pub fn finish_calibration(&self) -> Result<CalibrationData, CalibrationError> {
        self.calibration.finish()
    }

    pub fn get_calibration_state(&self) -> Result<CalibrationState, CalibrationError> {
        self.calibration.get_state()
    }

    pub fn load_calibration_state(
        &self,
        state: CalibrationState,
    ) -> Result<(), CalibrationError> {
        self.calibration.load_state(state)
    }

    // ========================================================================
    // STREAM METHODS (delegate to BroadcastChannelManager)
    // ========================================================================

    pub fn subscribe_classification(
        &self,
    ) -> Result<UnboundedReceiverStream<ClassificationResult>, AudioError> {
        self.broadcasts.subscribe_classification()
    }

    pub fn subscribe_calibration(
        &self,
    ) -> Result<UnboundedReceiverStream<CalibrationProgress>, CalibrationError> {
        self.broadcasts.subscribe_calibration()
    }
}
```

**Backward Compatibility**: All existing FFI calls continue to work:
```rust
// FFI layer unchanged
#[flutter_rust_bridge::frb(sync)]
pub fn start_audio(bpm: u32) -> Result<(), AudioError> {
    APP_CONTEXT.start_audio(bpm)
}
```

## Testing Patterns

### Unit Testing Managers

Each manager can be tested in isolation:

**Example**: Testing `AudioEngineManager` on desktop without Android emulator

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_audio_engine_manager_validation() {
        let manager = AudioEngineManager::new();

        // Test BPM validation without real audio engine
        let result = manager.validate_bpm(0);
        assert!(result.is_err());

        let result = manager.validate_bpm(120);
        assert!(result.is_ok());
    }

    #[test]
    fn test_audio_engine_lifecycle() {
        let manager = AudioEngineManager::new();

        // On desktop, start() returns error (no Android audio hardware)
        let result = manager.start(120, calibration_state, broadcast_tx);
        assert!(matches!(result, Err(AudioError::HardwareError { .. })));
    }
}
```

**Benefits**:
- **Fast tests**: No need for Android emulator
- **Focused tests**: Test one manager at a time
- **Platform abstraction**: Conditional compilation for desktop vs Android

### Integration Testing AppContext

Integration tests verify managers work together correctly:

```rust
#[tokio::test]
async fn test_appcontext_audio_lifecycle() {
    let ctx = AppContext::new();

    // Start audio (initializes classification broadcast)
    let result = ctx.start_audio(120);
    assert!(result.is_ok());

    // Subscribe to classification stream
    let stream = ctx.subscribe_classification();
    assert!(stream.is_ok());

    // Stop audio
    let result = ctx.stop_audio();
    assert!(result.is_ok());
}
```

## Best Practices

### ✅ DO

- **Extract helpers**: Keep public methods < 50 lines, helpers < 20 lines
- **Apply SLAP**: Each method operates at one abstraction level
- **Use focused managers**: One manager per responsibility
- **Return typed errors**: `Result<T, ManagerError>` instead of panicking
- **Document responsibilities**: Clear rustdoc explaining what each manager does
- **Test in isolation**: Write unit tests for each manager independently

### ❌ DON'T

- **Don't create "util managers"**: Avoid catch-all "HelperManager" or "UtilityManager"
- **Don't share state directly**: Use `Arc<Mutex<T>>` or `Arc<RwLock<T>>` for thread safety
- **Don't skip validation**: Always validate inputs in manager methods
- **Don't use unwrap()**: Return `Result` and let caller handle errors
- **Don't mix concerns**: If a manager handles > 1 responsibility, split it further

## Code Metrics After Refactoring

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| AppContext lines | 1495 | < 200 | **-87% reduction** |
| Longest method | 86 lines | < 30 lines | **-65% reduction** |
| Total functions > 50 lines | 8 | 0 | **100% compliance** |
| Files > 500 lines | 1 | 0 | **100% compliance** |
| Manager test coverage | 0% | 90%+ | **Testable** |

## Migration Guide

When extracting a manager from a god object:

### Step 1: Identify Responsibility

Group related methods by responsibility:
- Audio lifecycle: `start_audio`, `stop_audio`, `set_bpm`
- Calibration: `start_calibration`, `finish_calibration`, `get_state`
- Streaming: `init_classification`, `subscribe_classification`

### Step 2: Create Manager Struct

```rust
pub struct AudioEngineManager {
    engine: Arc<Mutex<Option<AudioEngineState>>>,
}

impl AudioEngineManager {
    pub fn new() -> Self {
        Self {
            engine: Arc::new(Mutex::new(None)),
        }
    }
}
```

### Step 3: Move Methods

Cut methods from god object, paste into manager, update signatures:

```rust
// Before (in AppContext)
pub fn start_audio(&self, bpm: u32) -> Result<(), AudioError> {
    let mut guard = self.audio_engine.lock().unwrap();
    // ... 86 lines ...
}

// After (in AudioEngineManager)
pub fn start(&self, bpm: u32, ...) -> Result<(), AudioError> {
    let mut guard = self.engine.lock().unwrap();
    // ... refactored into helpers ...
}
```

### Step 4: Extract Helpers

Break large methods into focused helpers following SLAP:

```rust
pub fn start(&self, ...) -> Result<(), AudioError> {
    self.validate_bpm(bpm)?;
    let mut guard = self.lock_engine()?;
    self.check_not_running(&guard)?;
    // ... orchestration only
}

fn validate_bpm(&self, bpm: u32) -> Result<(), AudioError> { /* ... */ }
fn lock_engine(&self) -> Result<MutexGuard<...>, AudioError> { /* ... */ }
```

### Step 5: Update Facade

Compose managers in god object facade:

```rust
pub struct AppContext {
    audio: AudioEngineManager,
    // ... other managers
}

impl AppContext {
    pub fn start_audio(&self, bpm: u32) -> Result<(), AudioError> {
        self.audio.start(bpm, ...) // Delegate
    }
}
```

### Step 6: Write Tests

Test manager in isolation:

```rust
#[test]
fn test_audio_engine_manager_start() {
    let manager = AudioEngineManager::new();
    let result = manager.start(120, ...);
    assert!(result.is_ok());
}
```

## Related Documentation

- [Dependency Injection Pattern](./dependency_injection.md) - DI in Dart/Flutter
- [Controller Pattern](./controllers.md) - Business logic separation in Dart
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID) - Design principles applied
