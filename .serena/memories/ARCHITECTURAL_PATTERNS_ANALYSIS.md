# Beatbox Trainer - Architectural Patterns Analysis
**Analysis Date**: 2025-11-13

---

## 1. STATE MANAGEMENT IN RUST AUDIO ENGINE

### Pattern: Atomic-based Shared State with Lock-Free Primitives

**Location**: `rust/src/audio/engine.rs:59-76`, `rust/src/api.rs:25-43`

#### AudioEngine State Pattern
```rust
pub struct AudioEngine {
    output_stream: Option<AudioStreamAsync<Output>>,      // Real-time audio callback
    input_stream: Option<AudioStreamAsync<Input>>,        // Input stream
    frame_counter: Arc<AtomicU64>,                        // Lock-free timing state
    bpm: Arc<AtomicU32>,                                  // Lock-free tempo state
    sample_rate: u32,                                     // Immutable config
    click_samples: Arc<Vec<f32>>,                         // Immutable pre-generated data
    buffer_channels: BufferPoolChannels,                  // Lock-free producer/consumer
    click_position: Arc<AtomicU64>,                       // Lock-free callback state
}
```

**Key Characteristics**:
- **Atomics for RT Safety** (engine.rs:25, 65-68): Uses `AtomicU64` and `AtomicU32` for frame counter and BPM instead of mutexes
- **Arc Sharing Pattern**: All shared state wrapped in `Arc` for thread-safe cloning
- **Immutable Config**: `sample_rate` and `click_samples` stored directly as immutable fields
- **Callback State**: `click_position` is atomic to track click sample playback position in audio callback

**Thread Safety Guarantees** (engine.rs:15-18):
- Frame counter: `AtomicU64` for sample-accurate timing across threads
- BPM updates: `AtomicU32` allows dynamic changes without blocking audio callback
- Click samples: Immutable Arc, safe to read from callback
- Real-time callback: NO allocations, NO locks, only atomic reads/writes

#### Global FFI State Pattern
```rust
static AUDIO_ENGINE: Lazy<Arc<Mutex<Option<AudioEngineState>>>> = ...     // api.rs:25-26
static CALIBRATION_PROCEDURE: Lazy<Arc<Mutex<Option<...>>>> = ...         // api.rs:29-30
static CALIBRATION_STATE: Lazy<Arc<RwLock<CalibrationState>>> = ...       // api.rs:33-34
static CLASSIFICATION_BROADCAST: Lazy<Arc<Mutex<...>>> = ...              // api.rs:38-39
static CALIBRATION_BROADCAST: Lazy<Arc<Mutex<...>>> = ...                 // api.rs:42-43
```

**Issue**: These globals create testability blockers (as per audit)
- `Lazy` initialization requires `.lock().unwrap()` calls (api.rs:110, 124, 179, 187, 260, 298, etc.)
- Unwrap panics if lock is poisoned
- Cannot be mocked or isolated in tests
- Global state persists across test runs

**PATTERN TO PRESERVE**: The concept of Arc<Atomic> for lock-free shared state is excellent
**PATTERN TO REFACTOR**: The global `Lazy` statics should be moved to an injected AppContext

---

## 2. ERROR PROPAGATION: RUST TO DART

### Pattern: Result<T, String> with Tokio Broadcast Channels

**Location**: `rust/src/api.rs` (functions return `Result<T, String>`)

#### Current Error Handling Pattern
```rust
// FFI function signatures (api.rs:95, 171, 212, 297, 325)
pub fn start_audio(_bpm: u32) -> Result<(), String> {
    if bpm == 0 {
        return Err("BPM must be greater than 0".to_string());  // api.rs:107
    }
    
    // Lock access with error propagation
    let mut engine_guard = AUDIO_ENGINE.lock().map_err(|e| e.to_string())?;  // api.rs:110
    
    if engine_guard.is_some() {
        return Err("Audio engine already running. Call stop_audio() first.".to_string());  // api.rs:113
    }
    // ... initialization
}
```

**Error Types Used**:
1. **String errors**: All FFI functions use `Result<T, String>`
2. **Lock poisoning errors**: `map_err(|e| e.to_string())?` converts PoisonError to String
3. **Hardware errors**: `map_err(|e| format!("Failed to create AudioEngine: {}", e))?` (api.rs:144)

#### Stream-based Progress Reporting
```rust
// Classification stream (api.rs:254-281)
pub async fn classification_stream() -> impl futures::Stream<Item = ClassificationResult> {
    let receiver = {
        let sender_guard = CLASSIFICATION_BROADCAST.lock().unwrap();  // Panic point!
        if let Some(broadcast_sender) = sender_guard.as_ref() {
            Some(broadcast_sender.subscribe())
        } else {
            None
        }
    };
    
    if let Some(rx) = receiver {
        // Create stream from broadcast receiver
        futures::stream::unfold(rx, |mut rx| async move {
            match rx.recv().await {
                Ok(result) => Some((result, rx)),
                Err(_) => None,  // Channel closed or lagged
            }
        })
        .boxed()
    } else {
        futures::stream::empty().boxed()
    }
}
```

**Pattern Details**:
- **Broadcast channels**: Used for multiple subscribers to same stream
- **MPSC for analysis**: `tokio::sync::mpsc` sends results from analysis thread (engine.rs:131)
- **Forwarder pattern**: Spawned task bridges mpsc → broadcast (api.rs:128-135)
- **Graceful closure**: Broadcast sender set to None on stop (api.rs:187-188)

#### Dart Side Error Handling
```dart
// training_screen.dart:54-71
try {
    await startAudio(bpm: _currentBpm);
    final stream = classificationStream();
    setState(() {
        _isTraining = true;
        _classificationStream = stream;
    });
} catch (e) {
    if (mounted) {
        _showErrorDialog(e.toString());  // Shows raw Rust error!
    }
}
```

**Issues**:
- Raw error strings shown to users (e.g., "Audio engine already running")
- No structured error types for programmatic handling
- Lock poisoning can still cause crashes

**PATTERNS TO PRESERVE**:
- Broadcast channels for multi-subscriber streams
- MPSC for analysis thread communication
- Result-based error propagation

**PATTERNS TO ENHANCE**:
- Custom error types (not String)
- Error translation layer for user-facing messages
- Remove unwrap() calls to prevent panics

---

## 3. RUST STRUCTS EXPOSURE VIA FFI

### Pattern: Serializable Data Structures with Generate Markers

**Location**: `rust/src/api.rs` (FFI functions), `rust/src/analysis/mod.rs` (data types)

#### Main Data Types Exposed
```rust
// ClassificationResult (analysis/mod.rs:34-42)
#[derive(Debug, Clone)]
pub struct ClassificationResult {
    pub sound: BeatboxHit,                    // Enum
    pub timing: TimingFeedback,               // Struct
    pub timestamp_ms: u64,                    // Scalar
}

// TimingFeedback (analysis/quantizer.rs, generated in Dart)
pub struct TimingFeedback {
    pub classification: TimingClassification,  // Enum
    pub error_ms: f64,                        // Scalar
}

// BeatboxHit enum (analysis/classifier.rs:24-40)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BeatboxHit {
    Kick, Snare, HiHat, ClosedHiHat, OpenHiHat, KSnare, Unknown,
}
```

#### flutter_rust_bridge Annotations
```rust
// Functions marked with #[flutter_rust_bridge::frb] (api.rs:61, 74, 94, 171, 212, 297, 325)
#[flutter_rust_bridge::frb(sync)]         // Synchronous FFI call
pub fn greet(name: String) -> Result<String> { ... }

#[flutter_rust_bridge::frb]               // Async FFI call
pub fn start_audio(_bpm: u32) -> Result<(), String> { ... }

#[flutter_rust_bridge::frb(stream)]       // Stream-returning FFI call
pub async fn classification_stream() -> impl futures::Stream<Item = ClassificationResult> { ... }
```

#### Dart Generated Types
```dart
// ClassificationResult (lib/models/classification_result.dart:10-29)
class ClassificationResult {
  final BeatboxHit sound;
  final TimingFeedback timing;
  final int timestampMs;
  
  const ClassificationResult({
    required this.sound,
    required this.timing,
    required this.timestampMs,
  });
}

// BeatboxHit enum with displayName getter (classification_result.dart:37-78)
enum BeatboxHit {
  kick, snare, hiHat, closedHiHat, openHiHat, kSnare, unknown;
  
  String get displayName { ... }  // User-friendly labels
}

// TimingFeedback (lib/models/timing_feedback.dart:7-36)
class TimingFeedback {
  final TimingClassification classification;
  final double errorMs;
  
  String get formattedError {  // Formatted display: "+12.5ms"
    if (errorMs == 0.0) return '0.0ms';
    else if (errorMs > 0) return '+${errorMs.toStringAsFixed(1)}ms';
    else return '${errorMs.toStringAsFixed(1)}ms';
  }
}
```

**Pattern Characteristics**:
- **Type Derivation**: `#[derive(Debug, Clone, Copy, PartialEq, Eq)]` for serialization
- **Enum Representation**: Enums serialize to integers by default
- **Result Wrapping**: All FFI functions return `Result<T, String>` for error handling
- **Async Bridge**: `async fn` becomes `Future` in Dart
- **Stream Bridge**: `impl futures::Stream` becomes `Stream<T>` in Dart

**Codegen Process** (lib/bridge/api.dart:1-8):
```dart
// AUTO-GENERATED FILE - DO NOT EDIT
// Generated by flutter_rust_bridge_codegen
// Command: flutter_rust_bridge_codegen generate
```

The stub file (api.dart:1-56) shows that actual implementation is auto-generated.

**PATTERNS TO PRESERVE**:
- Derive markers for serialization
- Result type wrapping for errors
- Simple scalar + enum composition
- Stream-based progress reporting

---

## 4. LIFECYCLE MANAGEMENT: AUDIO STREAMS

### Pattern: Builder Pattern with Callback Ownership

**Location**: `rust/src/audio/engine.rs:112-240`

#### AudioEngine Lifecycle States
```rust
// State 1: Created (new)
let engine = AudioEngine::new(120, 48000, buffer_channels)?;
// Streams are None, atomics initialized

// State 2: Started (start called)
engine.start(calibration, result_sender)?;
// Streams opened, callbacks registered, analysis thread spawned

// State 3: Running (callback executing)
// Audio callback fires in Oboe thread, analysis thread processes buffers

// State 4: Stopped (stop called)
engine.stop()?;
// Streams closed, analysis thread exits on next sender drop
```

#### Stream Initialization Pattern (engine.rs:140-195)
```rust
// Input stream (slave)
let input_stream = AudioStreamBuilder::default()
    .set_performance_mode(PerformanceMode::LowLatency)
    .set_sharing_mode(SharingMode::Exclusive)
    .set_direction::<Input>()
    .set_sample_rate(sample_rate as i32)
    .set_channel_count(1)
    .set_format::<f32>()
    .open_stream()
    .map_err(|e| format!("Failed to open input stream: {:?}", e))?;

// Output stream (master) with callback closure
let output_stream = AudioStreamBuilder::default()
    .set_performance_mode(PerformanceMode::LowLatency)
    .set_sharing_mode(SharingMode::Exclusive)
    .set_direction::<Output>()
    .set_sample_rate(sample_rate as i32)
    .set_channel_count(1)
    .set_format::<f32>()
    .set_callback(move |_, output: &mut [f32], _| {
        // Real-time audio callback - NO ALLOCATIONS, LOCKS, OR BLOCKING!
        // Load current state (atomic operations only)
        // ... process output
        DataCallbackResult::Continue
    })
    .open_stream()
    .map_err(|e| format!("Failed to open output stream: {:?}", e))?;

// Start in order: input first (slave), then output (master)
input_stream.start()?;
output_stream.start()?;

self.input_stream = Some(input_stream);
self.output_stream = Some(output_stream);
```

#### Callback Real-Time Safety (engine.rs:159-192)
```rust
.set_callback(move |_, output: &mut [f32], _| {
    // Load current state (atomic operations are lock-free)
    let current_frame = frame_counter.load(Ordering::Relaxed);
    let current_bpm = bpm.load(Ordering::Relaxed);
    let mut click_pos = click_position.load(Ordering::Relaxed) as usize;

    // Process each output frame
    for (i, sample) in output.iter_mut().enumerate() {
        let frame = current_frame + i as u64;
        
        if is_on_beat(frame, current_bpm, sample_rate) {
            click_pos = 0;
        }

        if click_pos < click_samples.len() {
            *sample = click_samples[click_pos];
            click_pos += 1;
        } else {
            *sample = 0.0;
        }
    }

    // Update positions for next callback
    click_position.store(click_pos as u64, Ordering::Relaxed);
    frame_counter.fetch_add(output.len() as u64, Ordering::Relaxed);
    
    DataCallbackResult::Continue
})
```

**Key Patterns**:
1. **Exclusive Sharing**: `SharingMode::Exclusive` for dedicated audio access
2. **Low Latency Mode**: `PerformanceMode::LowLatency`
3. **Callback Closure Capture**: Captures Arcs and atomics via move
4. **Lock-Free Operations**: Only atomic loads/stores in callback
5. **No Allocations**: Pre-generated click samples, no new buffers
6. **Ordered Startup**: Input before output (slave-master relationship)

#### Buffer Pool Lifecycle (buffer_pool.rs:21-64)
```rust
// Pre-allocated with 16 buffers of 2048 samples each
let buffer_pool = BufferPool::new(16, 2048);

// Split for thread ownership
let (audio_channels, analysis_channels) = buffer_channels.split_for_threads();

// Audio thread uses:
pub struct AudioThreadChannels {
    pub data_producer: Producer<AudioBuffer>,    // Send filled buffers
    pub pool_consumer: Consumer<AudioBuffer>,    // Retrieve empty buffers
}

// Analysis thread uses:
pub struct AnalysisThreadChannels {
    pub data_consumer: Consumer<AudioBuffer>,    // Receive filled buffers
    pub pool_producer: Producer<AudioBuffer>,    // Return empty buffers
}
```

#### Analysis Thread Lifecycle (analysis/mod.rs:79-101)
```rust
pub fn spawn_analysis_thread(...) -> JoinHandle<()> {
    thread::spawn(move || {
        // Initialize DSP components (all allocations happen here)
        let mut onset_detector = OnsetDetector::new(sample_rate);
        let feature_extractor = FeatureExtractor::new(sample_rate);
        let classifier = Classifier::new(Arc::clone(&calibration));
        let quantizer = Quantizer::new(...);

        // Main loop - runs until sender is dropped
        loop {
            let buffer = match analysis_channels.data_consumer.pop() {
                Ok(buf) => buf,
                Err(_) => {
                    std::thread::sleep(std::time::Duration::from_millis(1));
                    continue;
                }
            };

            // Process buffer through DSP pipeline
            let onsets = onset_detector.process(&buffer);
            for onset_timestamp in onsets {
                let features = feature_extractor.extract(onset_window);
                let sound = classifier.classify_level1(&features);
                let timing = quantizer.quantize(onset_timestamp);
                
                let _ = result_sender.send(ClassificationResult { ... });
            }
            
            // Return buffer to pool
            let _ = analysis_channels.pool_producer.push(buffer);
        }
    })
}
```

#### FFI Lifecycle Wrapper (api.rs:78-160)
```rust
pub fn start_audio(_bpm: u32) -> Result<(), String> {
    // 1. Validate parameters
    if bpm == 0 { return Err(...); }
    
    // 2. Acquire global engine lock
    let mut engine_guard = AUDIO_ENGINE.lock().map_err(|e| e.to_string())?;
    
    // 3. Check preconditions
    if engine_guard.is_some() { return Err(...); }
    
    // 4. Create channels for classification stream
    let (classification_tx, mut classification_rx) = mpsc::unbounded_channel();
    let (broadcast_tx, _broadcast_rx) = tokio::sync::broadcast::channel(100);
    
    // 5. Store broadcast sender globally
    {
        let mut sender_guard = CLASSIFICATION_BROADCAST.lock().map_err(|e| e.to_string())?;
        *sender_guard = Some(broadcast_tx.clone());
    }
    
    // 6. Spawn mpsc→broadcast forwarder
    let broadcast_tx_clone = broadcast_tx.clone();
    tokio::spawn(async move {
        while let Some(result) = classification_rx.recv().await {
            let _ = broadcast_tx_clone.send(result);
        }
    });
    
    // 7. Create AudioEngine and start it
    let mut engine = AudioEngine::new(bpm, sample_rate, buffer_channels)?;
    engine.start(calibration, classification_tx)?;
    
    // 8. Store engine in global state
    *engine_guard = Some(AudioEngineState { engine });
    
    Ok(())
}
```

**Closure Control Flow** (api.rs:38-39):
- Broadcast sender stored in `CLASSIFICATION_BROADCAST` global
- Multiple subscribers can call `classification_stream()` to get receivers
- When `stop_audio()` is called, sender is set to None, streams close gracefully

**PATTERNS TO PRESERVE**:
- Builder pattern for stream configuration
- Lock-free atomic operations in real-time callback
- Pre-allocation of buffers before callback starts
- Master-slave stream ordering
- Graceful shutdown via sender cleanup

---

## 5. SERVICE ABSTRACTIONS & UTILITIES IN DART

### Current State: Minimal Abstraction

**Location**: `lib/ui/screens/*.dart`, `lib/models/`, `lib/bridge/api.dart`

#### Direct FFI Dependency Pattern
```dart
// training_screen.dart:1-5
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../bridge/api.dart';  // Direct concrete dependency
import '../../models/classification_result.dart';
import '../../models/timing_feedback.dart';
```

#### Monolithic Screen Pattern (training_screen.dart:24-100)
```dart
class _TrainingScreenState extends State<TrainingScreen> {
    int _currentBpm = 120;
    bool _isTraining = false;
    Stream<ClassificationResult>? _classificationStream;
    ClassificationResult? _currentResult;
    
    Future<void> _startTraining() async {
        // 1. Permission check
        final hasPermission = await _requestMicrophonePermission();
        if (!hasPermission) return;
        
        try {
            // 2. Direct API call
            await startAudio(bpm: _currentBpm);
            
            // 3. Subscribe to stream
            final stream = classificationStream();
            
            // 4. Update state
            setState(() {
                _isTraining = true;
                _classificationStream = stream;
                _currentResult = null;
            });
        } catch (e) {
            // 5. Error handling
            if (mounted) {
                _showErrorDialog(e.toString());
            }
        }
    }
}
```

**Issues Identified**:
- **No service abstraction**: Permission logic embedded in screen
- **No error translation**: Raw Rust errors shown to users
- **No dependency injection**: Hard-coded API calls
- **Mixed concerns**: Lifecycle management + UI rendering
- **Code duplication**: Similar patterns in calibration_screen.dart

#### Model-only Structure
```dart
// lib/models/classification_result.dart - Value object
class ClassificationResult { ... }
enum BeatboxHit { ... }

// lib/models/timing_feedback.dart - Value object
class TimingFeedback { ... }
enum TimingClassification { ... }

// lib/models/calibration_progress.dart - Value object
class CalibrationProgress { ... }
```

**Good Practice**: These are pure value objects with display formatters
```dart
// Enum display formatter (classification_result.dart:59-77)
enum BeatboxHit {
    kick, snare, hiHat, closedHiHat, openHiHat, kSnare, unknown;
    
    String get displayName {
        switch (this) {
            case BeatboxHit.kick: return 'KICK';
            case BeatboxHit.snare: return 'SNARE';
            case BeatboxHit.hiHat: return 'HI-HAT';
            // ...
        }
    }
}

// TimingFeedback formatter (timing_feedback.dart:22-31)
String get formattedError {
    if (errorMs == 0.0) {
        return '0.0ms';
    } else if (errorMs > 0) {
        return '+${errorMs.toStringAsFixed(1)}ms';
    } else {
        return '${errorMs.toStringAsFixed(1)}ms';
    }
}
```

#### Missing Service Abstractions
**NO EXISTS**: Permission Service, Audio Service, Error Handler, Logger

**These should be created**:
```dart
// Proposed: lib/services/permission_service.dart
abstract class PermissionService {
    Future<bool> requestMicrophonePermission();
}

// Proposed: lib/services/audio_service.dart
abstract class AudioService {
    Future<void> startAudio({required int bpm});
    Future<void> stopAudio();
    Future<void> setBpm(int bpm);
    Stream<ClassificationResult> getClassificationStream();
}

// Proposed: lib/services/error_handler.dart
abstract class ErrorHandler {
    String translateRustError(String error);
    String getUserFriendlyMessage(String error);
}
```

#### Shared UI Patterns (NOT extracted)
**Duplicated across training_screen.dart and calibration_screen.dart**:

1. **Error Dialog Pattern** (repeated 3+ times):
```dart
if (mounted) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(_errorMessage ?? e.toString()),
            actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                ),
            ],
        ),
    );
}
```

2. **Loading Indicator Pattern** (repeated 4+ times):
```dart
if (_isLoading)
    const CircularProgressIndicator()
else
    // content
```

3. **Container Decoration Pattern** (repeated 5+ times):
```dart
Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
    ),
    child: // content
)
```

**Audit Finding**: ~150 lines of duplication could be extracted to:
- `lib/ui/widgets/error_dialog.dart`
- `lib/ui/widgets/loading_overlay.dart`
- `lib/ui/styles/container_styles.dart`

---

## SUMMARY OF PATTERNS

### Strengths (PRESERVE)
✅ **Rust Architecture**:
- Atomic-based lock-free state management
- Builder pattern for stream configuration
- Real-time callback safety (no allocations/locks)
- Pre-allocation strategy for buffer management
- Stream-based progress reporting with broadcast channels
- Analysis thread spawn pattern with owned channels

✅ **Dart/Flutter**:
- Value object models with display formatters
- Enum-based type safety
- Stream subscription pattern
- Proper lifecycle management (dispose cleanup)

✅ **FFI Bridge**:
- Type-safe serialization with #[derive]
- Result wrapping for errors
- Stream-returning async functions
- Codegen-based development

### Weaknesses (REFACTOR)
❌ **Global State Antipattern** (api.rs:25-43):
- 5 Lazy statics block testing
- Unwrap() calls can panic
- No dependency injection
- Hard to mock

❌ **String Error Types** (api.rs throughout):
- No structured error classification
- Raw errors shown to users
- Cannot pattern match on error types
- Lock poisoning panics

❌ **No Dart Service Layer**:
- Screens directly call FFI
- Permission logic embedded in UI
- No error translation
- ~150 lines code duplication

### Refactoring Strategy
1. **P0**: Create custom error types in Rust
2. **P1**: Refactor api.rs to use injected AppContext
3. **P2**: Extract Dart service abstractions
4. **P3**: Extract shared UI widgets
