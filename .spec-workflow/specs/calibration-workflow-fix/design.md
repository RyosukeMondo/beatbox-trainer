# Calibration Workflow Fix - Design Document

## 1. Executive Summary

This design document addresses the architectural gap in the calibration system: **onset detection events are not being forwarded to the calibration procedure's sample collection logic**.

### Current State

The system has all necessary components in place:
- ✓ Audio engine with Oboe full-duplex I/O
- ✓ Onset detection in analysis thread (`spawn_analysis_thread`)
- ✓ Feature extraction (spectral centroid, ZCR, flatness, rolloff, decay time)
- ✓ Calibration procedure with `add_sample()` method
- ✓ Progress broadcasting infrastructure
- ✗ **Missing**: Connection between onset detection and calibration sample collection

### Architectural Solution

**Core Insight**: The analysis thread (`rust/src/analysis/mod.rs:73-158`) currently only performs classification. We need to add **calibration mode** where the analysis thread forwards detected onsets to the calibration procedure instead of classifying them.

**Implementation Strategy**:
1. Add calibration procedure reference to analysis thread
2. Check calibration state on each onset
3. If calibration is active, forward features to `CalibrationProcedure::add_sample()`
4. Broadcast progress updates after each successful sample
5. If calibration is inactive, proceed with normal classification

## 2. System Architecture

### 2.1 Component Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                           UI Layer (Dart)                        │
├─────────────────────────────────────────────────────────────────┤
│  • CalibrationStream (receives CalibrationProgress)             │
│  • ClassificationStream (receives ClassificationResult)          │
└───────────────┬─────────────────────────────────┬───────────────┘
                │ FFI Bridge (flutter_rust_bridge) │
┌───────────────▼─────────────────────────────────▼───────────────┐
│                      API Layer (rust/src/api.rs)                │
├─────────────────────────────────────────────────────────────────┤
│  • calibration_stream() → StreamSink<CalibrationProgress>       │
│  • classification_stream() → StreamSink<ClassificationResult>   │
└───────────────┬─────────────────────────────────┬───────────────┘
                │                                 │
┌───────────────▼─────────────────────────────────▼───────────────┐
│              AppContext (rust/src/context.rs)                    │
├─────────────────────────────────────────────────────────────────┤
│  • AudioEngineManager    • CalibrationManager                   │
│  • BroadcastChannelManager                                      │
└──────┬────────────────────────────┬─────────────────────────────┘
       │                            │
       │                            │ Calibration Arc<Mutex<>>
       │                            │
┌──────▼────────────────────┐  ┌───▼──────────────────────────────┐
│   AudioEngine             │  │   CalibrationManager             │
│  (rust/src/audio/         │  │  (rust/src/managers/             │
│   engine.rs)              │  │   calibration_manager.rs)        │
├───────────────────────────┤  ├──────────────────────────────────┤
│  • OUTPUT stream (master) │  │  • procedure: Arc<Mutex<         │
│  • INPUT stream (slave)   │  │      Option<Calibration          │
│  • Metronome generation   │  │      Procedure>>>                │
│  • Frame counter          │  │  • state: Arc<RwLock<            │
│  • BPM atomic             │  │      CalibrationState>>          │
└──────┬────────────────────┘  └──────────────────────────────────┘
       │
       │ Lock-free buffer pool (rtrb queues)
       │
┌──────▼──────────────────────────────────────────────────────────┐
│           Analysis Thread (rust/src/analysis/mod.rs)            │
├─────────────────────────────────────────────────────────────────┤
│  Loop:                                                           │
│    1. Pop audio buffer from DATA_QUEUE                          │
│    2. OnsetDetector::process() → Vec<u64> onset timestamps      │
│    3. For each onset:                                           │
│       a. Extract 1024-sample window                             │
│       b. FeatureExtractor::extract() → Features                 │
│       c. [NEW] Check if calibration is active                   │
│          - IF calibration active:                               │
│              • procedure.add_sample(features)                   │
│              • Broadcast CalibrationProgress                    │
│          - ELSE:                                                │
│              • Classifier::classify_level1()                    │
│              • Quantizer::quantize()                            │
│              • Broadcast ClassificationResult                   │
│    4. Return buffer to POOL_QUEUE                               │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow Diagram

**Normal Classification Mode** (current, working):
```
Audio Callback → Buffer Pool → Analysis Thread → OnsetDetector → Features
                                                                      ↓
UI ← Broadcast ← ClassificationResult ← Quantizer ← Classifier ← Features
```

**Calibration Mode** (to be implemented):
```
Audio Callback → Buffer Pool → Analysis Thread → OnsetDetector → Features
                                                                      ↓
UI ← Broadcast ← CalibrationProgress ← CalibrationProcedure.add_sample()
```

**Key Decision Point**: Analysis thread checks calibration state to determine mode.

## 3. Detailed Design

### 3.1 Modified Analysis Thread Signature

**Current (rust/src/analysis/mod.rs:73-80)**:
```rust
pub fn spawn_analysis_thread(
    mut analysis_channels: AnalysisThreadChannels,
    calibration: Arc<RwLock<CalibrationState>>,  // Only state, not procedure!
    frame_counter: Arc<AtomicU64>,
    bpm: Arc<AtomicU32>,
    sample_rate: u32,
    result_sender: tokio::sync::broadcast::Sender<ClassificationResult>,
) -> JoinHandle<()>
```

**NEW Design**:
```rust
pub fn spawn_analysis_thread(
    mut analysis_channels: AnalysisThreadChannels,
    calibration_state: Arc<RwLock<CalibrationState>>,     // For classification
    calibration_procedure: Arc<Mutex<Option<CalibrationProcedure>>>, // NEW: For sample collection
    calibration_progress_tx: Option<broadcast::Sender<CalibrationProgress>>, // NEW: For progress
    frame_counter: Arc<AtomicU64>,
    bpm: Arc<AtomicU32>,
    sample_rate: u32,
    result_sender: tokio::sync::broadcast::Sender<ClassificationResult>,
) -> JoinHandle<()>
```

**Rationale**:
- `calibration_procedure`: Shared reference to active calibration procedure (None if not calibrating)
- `calibration_progress_tx`: Optional broadcast channel for calibration progress
- Keep existing `calibration_state` for classification mode
- Backward compatible: If `calibration_procedure` is None, behaves exactly as before

### 3.2 Analysis Thread Main Loop Logic

**NEW Processing Logic** (replaces lines 104-146 in `rust/src/analysis/mod.rs`):

```rust
// For each detected onset, run pipeline
for onset_timestamp in onsets {
    // Extract 1024-sample window starting at onset
    let onset_idx = (onset_timestamp % buffer.len() as u64) as usize;

    if onset_idx + 1024 <= buffer.len() {
        let onset_window = &buffer[onset_idx..onset_idx + 1024];

        // Extract DSP features (always needed for both modes)
        let features = feature_extractor.extract(onset_window);

        // NEW: Check if calibration is active
        let calibration_active = if let Ok(procedure_guard) = calibration_procedure.try_lock() {
            procedure_guard.is_some()
        } else {
            false // Lock failed, assume not calibrating
        };

        if calibration_active {
            // ====== CALIBRATION MODE ======
            // Forward features to calibration procedure
            if let Ok(mut procedure_guard) = calibration_procedure.lock() {
                if let Some(ref mut procedure) = *procedure_guard {
                    match procedure.add_sample(features) {
                        Ok(()) => {
                            // Sample accepted - broadcast progress
                            let progress = procedure.get_progress();

                            if let Some(ref tx) = calibration_progress_tx {
                                let _ = tx.send(progress);
                            }
                        }
                        Err(err) => {
                            // Sample rejected (validation error)
                            eprintln!("Calibration sample rejected: {:?}", err);
                            // Optionally broadcast error (future enhancement)
                        }
                    }
                }
            }
        } else {
            // ====== CLASSIFICATION MODE (existing logic) ======
            let (sound, confidence) = classifier.classify_level1(&features);

            let current_bpm = bpm.load(std::sync::atomic::Ordering::Relaxed);
            let timing = if current_bpm > 0 {
                quantizer.quantize(onset_timestamp)
            } else {
                TimingFeedback {
                    classification: quantizer::TimingClassification::OnTime,
                    error_ms: 0.0,
                }
            };

            let timestamp_ms = (onset_timestamp as f64 / sample_rate as f64 * 1000.0) as u64;

            let result = ClassificationResult {
                sound,
                timing,
                timestamp_ms,
                confidence,
            };

            let _ = result_sender.send(result);
        }
    }
}
```

**Key Design Decisions**:
1. **Non-blocking lock attempt**: Use `try_lock()` for calibration state check to avoid blocking audio analysis
2. **Graceful degradation**: If lock fails, assume not calibrating and proceed with classification
3. **Validation errors are logged**: Invalid samples don't crash the thread
4. **Progress broadcast after each sample**: Real-time UI feedback

### 3.3 AudioEngine Modifications

**Current start() method** (rust/src/audio/engine.rs:211-252):
```rust
pub fn start(
    &mut self,
    calibration: Arc<RwLock<CalibrationState>>,
    result_sender: broadcast::Sender<ClassificationResult>,
) -> Result<(), AudioError>
```

**NEW Design**:
```rust
pub fn start(
    &mut self,
    calibration_state: Arc<RwLock<CalibrationState>>,
    calibration_procedure: Arc<Mutex<Option<CalibrationProcedure>>>,  // NEW
    calibration_progress_tx: Option<broadcast::Sender<CalibrationProgress>>, // NEW
    result_sender: broadcast::Sender<ClassificationResult>,
) -> Result<(), AudioError>
```

**Modified spawn_analysis_thread_internal()** (lines 174-193):
```rust
fn spawn_analysis_thread_internal(
    &self,
    buffer_channels: BufferPoolChannels,
    calibration_state: Arc<RwLock<CalibrationState>>,
    calibration_procedure: Arc<Mutex<Option<CalibrationProcedure>>>,  // NEW
    calibration_progress_tx: Option<broadcast::Sender<CalibrationProgress>>, // NEW
    result_sender: broadcast::Sender<ClassificationResult>,
) {
    let (_, analysis_channels) = buffer_channels.split_for_threads();

    let frame_counter_clone = Arc::clone(&self.frame_counter);
    let bpm_clone = Arc::clone(&self.bpm);

    crate::analysis::spawn_analysis_thread(
        analysis_channels,
        calibration_state,
        calibration_procedure,          // NEW: Pass to analysis thread
        calibration_progress_tx,        // NEW: Pass to analysis thread
        frame_counter_clone,
        bpm_clone,
        self.sample_rate,
        result_sender,
    );
}
```

### 3.4 AppContext Integration

**Current start_calibration()** (rust/src/context.rs):
```rust
pub fn start_calibration(&self) -> Result<(), CalibrationError> {
    let broadcast_tx = self.broadcasts.init_calibration();
    self.calibration.start(broadcast_tx)?;

    #[cfg(target_os = "android")]
    {
        const DEFAULT_CALIBRATION_BPM: u32 = 120;
        self.start_audio(DEFAULT_CALIBRATION_BPM)
            .map_err(|audio_err| CalibrationError::AudioEngineError {
                details: format!("Failed to start audio engine: {:?}", audio_err),
            })?;
    }

    Ok(())
}
```

**Issues with current design**:
1. Audio engine is started AFTER calibration procedure is initialized
2. Analysis thread doesn't have access to calibration procedure
3. No way to pass procedure reference to already-running analysis thread

**NEW Design - Two Options**:

#### Option A: Restart Audio Engine (Simpler, Slight Latency)
```rust
pub fn start_calibration(&self) -> Result<(), CalibrationError> {
    // Initialize calibration procedure
    let broadcast_tx = self.broadcasts.init_calibration();
    self.calibration.start(broadcast_tx)?;

    #[cfg(target_os = "android")]
    {
        // Stop audio engine if running
        self.stop_audio()?;

        // Restart audio engine with calibration procedure
        const DEFAULT_CALIBRATION_BPM: u32 = 120;
        self.start_audio(DEFAULT_CALIBRATION_BPM)
            .map_err(|audio_err| CalibrationError::AudioEngineError {
                details: format!("Failed to start audio engine: {:?}", audio_err),
            })?;
    }

    Ok(())
}
```

**Pros**:
- Simpler implementation
- Clean separation of concerns
- Analysis thread gets fresh calibration procedure reference

**Cons**:
- Brief audio interruption (~100ms) during calibration start
- User hears metronome stop and restart

#### Option B: Pass Procedure at Audio Startup (Cleaner, More Complex)
```rust
// Modify AudioEngineManager to store calibration references
pub struct AudioEngineManager {
    engine: Option<AudioEngine>,
    calibration_state: Arc<RwLock<CalibrationState>>,
    calibration_procedure: Arc<Mutex<Option<CalibrationProcedure>>>,  // NEW: Stored reference
    // ...
}
```

**Pros**:
- No audio interruption
- Seamless calibration start

**Cons**:
- More complex state management
- AudioEngineManager now depends on calibration (coupling)
- Procedure reference must be shared between CalibrationManager and AudioEngineManager

**RECOMMENDED**: **Option A** for initial implementation (follows KISS principle)
- User impact is minimal (brief metronome restart)
- Simpler to test and maintain
- Can optimize to Option B later if needed

### 3.5 Calibration Manager Modifications

**Current CalibrationManager** (rust/src/managers/calibration_manager.rs):
- Stores `Arc<Mutex<Option<CalibrationProcedure>>>`
- Already has `start()` and `finish()` methods
- No modifications needed!

**Integration Points**:
1. AppContext calls `calibration.start(broadcast_tx)` to initialize procedure
2. AppContext gets procedure reference via `calibration.get_procedure_arc()` (NEW method)
3. Pass procedure reference to AudioEngine on start/restart

**NEW Method to Add**:
```rust
impl CalibrationManager {
    /// Get Arc reference to calibration procedure for sharing with audio engine
    ///
    /// # Returns
    /// `Arc<Mutex<Option<CalibrationProcedure>>>` - Thread-safe reference to procedure
    pub fn get_procedure_arc(&self) -> Arc<Mutex<Option<CalibrationProcedure>>> {
        Arc::clone(&self.procedure)
    }
}
```

## 4. Thread Safety Analysis

### 4.1 Lock Hierarchy

```
Audio Callback (highest priority, real-time thread)
    ↓ No locks, only atomics and lock-free queues
Analysis Thread (normal priority, async thread)
    ↓ Locks: Mutex<Option<CalibrationProcedure>>, RwLock<CalibrationState>
UI Thread (normal priority, Dart/Flutter)
    ↓ Receives via broadcast channels (no locks)
```

**Lock Acquisition Order** (prevents deadlocks):
1. Analysis thread: Try `calibration_procedure.try_lock()` for state check (non-blocking)
2. Analysis thread: `calibration_procedure.lock()` for sample add (blocking OK in analysis thread)
3. Never hold multiple locks simultaneously

### 4.2 Lock-Free Guarantees

**Audio Callback** (rust/src/audio/callback.rs):
- ✓ No locks (only `Arc<AtomicU64>`, `Arc<AtomicU32>`)
- ✓ No allocations
- ✓ Lock-free buffer pool (rtrb queues)
- ✓ Real-time safe

**Analysis Thread**:
- ✓ Can block (not real-time critical)
- ✓ Locks are acceptable
- ✓ Graceful fallback if lock fails (`try_lock()` for state check)

### 4.3 Race Condition Analysis

**Scenario 1**: User starts calibration while audio is playing
- AppContext stops audio → initializes procedure → restarts audio
- Audio callbacks stop during gap → analysis thread drains queue → new audio callbacks start
- **Safe**: No concurrent modification during transition

**Scenario 2**: User finishes calibration while onset is being processed
- Analysis thread locks procedure → adds sample → releases lock
- CalibrationManager locks procedure → calls finalize() → sets to None
- **Safe**: Sequential lock acquisition, no data race

**Scenario 3**: Calibration procedure is finalized between try_lock() and lock()
- Analysis thread: `try_lock()` → true (procedure exists)
- CalibrationManager: `lock()` → `finalize()` → procedure becomes None
- Analysis thread: `lock()` → procedure is now None → skip sample add
- **Safe**: Option<> handles None case gracefully

## 5. Error Handling Strategy

### 5.1 Error Scenarios and Responses

| Error Scenario | Detection Point | Response | User Impact |
|---|---|---|---|
| Invalid features (out of range) | `SampleValidator::validate()` | Log error, skip sample | None (silent rejection) |
| Lock poisoning on procedure | `calibration_procedure.lock()` | Log error, skip sample | None (continues processing) |
| Broadcast channel closed | `calibration_progress_tx.send()` | Ignore (no subscribers) | None (UI disconnected) |
| Insufficient samples on finalize | `CalibrationProcedure::finalize()` | Return `CalibrationError` | UI shows error message |
| Audio engine failure during start | `AudioEngine::start()` | Return `CalibrationError` | UI shows error message |

### 5.2 Error Propagation

```
Analysis Thread (onset processing)
    ↓ Invalid features → Log warning, continue
    ↓ Lock failure → Log warning, continue
    ↓ Broadcast failure → Silent ignore, continue

CalibrationManager::finish()
    ↓ Insufficient samples → Return CalibrationError
    ↓ Lock poisoning → Return CalibrationError

AppContext::start_calibration()
    ↓ Audio engine failure → Map to CalibrationError::AudioEngineError
    ↓ Propagate to Dart via FFI error code
```

**Design Principle**: Fail fast at API boundaries, fail gracefully in background threads.

### 5.3 Structured Error Logging

**Format** (from CLAUDE.md guidelines):
```json
{
  "timestamp": "2025-11-14T12:43:20.214Z",
  "level": "ERROR",
  "service": "calibration",
  "event": "sample_rejected",
  "context": {
    "reason": "Centroid 30.0 Hz out of range [50.0, 24000.0]",
    "current_sound": "KICK",
    "samples_collected": 5
  }
}
```

## 6. Performance Considerations

### 6.1 Latency Analysis

**Calibration Sample Processing**:
```
Onset detection:        ~20ms  (spectral flux analysis)
Feature extraction:     ~10ms  (FFT + feature computation)
Sample validation:      ~0.1ms (range checks)
Mutex lock acquisition: ~0.01ms (uncontended)
Progress broadcast:     ~0.01ms (channel send)
──────────────────────────────
Total:                  ~30ms  (well within 100ms requirement)
```

**Memory Allocation**:
- Features struct: 5 × f32 = 20 bytes (stack allocated)
- Progress struct: ~40 bytes (stack allocated, cloned for broadcast)
- No heap allocations in hot path ✓

### 6.2 Throughput

**Expected Onset Rate**:
- User performs beatbox sound every ~2 seconds
- Onset detection processes entire buffer (~10ms @ 48kHz, 480 samples)
- Typical onset rate: 0.5 onsets/second during calibration
- Analysis thread CPU usage: ~1-2% (plenty of headroom)

**Lock Contention**:
- Calibration procedure lock held for ~0.1ms per sample
- Single writer (analysis thread), no readers during calibration
- Lock contention: Negligible

### 6.3 Memory Footprint

**Per-Calibration Memory**:
- CalibrationProcedure: 3 × Vec<Features> × 10 samples = ~600 bytes
- Broadcast channel: 100 slot buffer × 40 bytes = 4KB
- Total: ~5KB (negligible for mobile device)

## 7. Testing Strategy

### 7.1 Unit Tests

**Test Coverage Requirements**: ≥ 90% (from requirements)

#### 7.1.1 Analysis Thread Tests

**File**: `rust/src/analysis/mod.rs` (new test module)

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calibration_mode_forwards_to_procedure() {
        // Setup: Initialize analysis thread with mock procedure
        // Action: Feed audio buffer with synthetic onset
        // Assert: procedure.add_sample() called with correct features
    }

    #[test]
    fn test_classification_mode_when_procedure_is_none() {
        // Setup: procedure = None
        // Action: Feed audio buffer with onset
        // Assert: ClassificationResult broadcast, no calibration call
    }

    #[test]
    fn test_invalid_features_rejected_gracefully() {
        // Setup: Mock validator to return error
        // Action: Feed buffer with invalid onset
        // Assert: Error logged, thread continues
    }

    #[test]
    fn test_progress_broadcast_after_each_sample() {
        // Setup: Mock broadcast channel
        // Action: Add 3 samples
        // Assert: 3 progress broadcasts sent
    }

    #[test]
    fn test_lock_failure_fallback_to_classification() {
        // Setup: Poison procedure lock
        // Action: Feed buffer with onset
        // Assert: Falls back to classification mode
    }
}
```

#### 7.1.2 CalibrationManager Tests

**File**: `rust/src/managers/calibration_manager.rs` (add to existing tests)

```rust
#[test]
fn test_get_procedure_arc() {
    let manager = CalibrationManager::new();
    let (broadcast_tx, _) = broadcast::channel(100);

    // Start calibration
    manager.start(broadcast_tx).unwrap();

    // Get procedure arc
    let procedure_arc = manager.get_procedure_arc();

    // Verify procedure is accessible via arc
    let procedure_guard = procedure_arc.lock().unwrap();
    assert!(procedure_guard.is_some());
}
```

### 7.2 Integration Tests

#### 7.2.1 End-to-End Calibration Workflow

**File**: `rust/tests/calibration_integration_test.rs`

```rust
#[test]
fn test_full_calibration_workflow() {
    // 1. Initialize AppContext
    // 2. Call start_calibration()
    // 3. Feed synthetic audio with 30 beatbox sounds (10 kick, 10 snare, 10 hihat)
    // 4. Verify 30 progress broadcasts received
    // 5. Call finish_calibration()
    // 6. Verify CalibrationState is persisted with correct thresholds
    // 7. Verify audio engine can restart in classification mode
}

#[test]
fn test_calibration_with_invalid_samples() {
    // 1. Start calibration
    // 2. Feed 8 valid samples + 2 invalid samples
    // 3. Verify only 8 samples accepted
    // 4. Verify progress shows 8/10
    // 5. Feed 2 more valid samples
    // 6. Verify progression to next sound
}

#[test]
fn test_calibration_restart_audio_interruption() {
    // 1. Start audio engine in classification mode
    // 2. Start calibration (triggers audio restart)
    // 3. Verify audio gap is < 200ms
    // 4. Verify metronome resumes correctly
}
```

### 7.3 Synthetic Audio Test Data

**Test Audio Generation**:
```rust
/// Generate synthetic beatbox sounds for testing
mod test_audio {
    /// Generate kick drum: Low centroid (500 Hz), high decay (100ms)
    pub fn generate_kick() -> Vec<f32> { /* ... */ }

    /// Generate snare: Mid centroid (3000 Hz), high ZCR (0.2)
    pub fn generate_snare() -> Vec<f32> { /* ... */ }

    /// Generate hi-hat: High centroid (8000 Hz), high flatness (0.7)
    pub fn generate_hihat() -> Vec<f32> { /* ... */ }

    /// Generate invalid sample: Out-of-range features
    pub fn generate_invalid() -> Vec<f32> { /* ... */ }
}
```

### 7.4 Mock Dependencies

**CalibrationProcedure Mock** (for testing analysis thread):
```rust
pub struct MockCalibrationProcedure {
    samples_received: Arc<Mutex<Vec<Features>>>,
    validation_result: Result<(), CalibrationError>,
}

impl MockCalibrationProcedure {
    pub fn new() -> Self { /* ... */ }

    pub fn add_sample(&mut self, features: Features) -> Result<(), CalibrationError> {
        self.samples_received.lock().unwrap().push(features);
        self.validation_result.clone()
    }

    pub fn get_samples_received(&self) -> Vec<Features> {
        self.samples_received.lock().unwrap().clone()
    }
}
```

## 8. Migration Path

### 8.1 Implementation Phases

**Phase 1: Analysis Thread Modifications** (2-3 hours)
- Modify `spawn_analysis_thread()` signature
- Add calibration mode logic to main loop
- Add unit tests for calibration mode

**Phase 2: AudioEngine Integration** (1-2 hours)
- Modify `AudioEngine::start()` signature
- Update `spawn_analysis_thread_internal()`
- Add unit tests for parameter passing

**Phase 3: AppContext Integration** (1-2 hours)
- Implement audio restart logic in `start_calibration()`
- Add `CalibrationManager::get_procedure_arc()`
- Wire up calibration procedure to audio engine

**Phase 4: Integration Testing** (2-3 hours)
- End-to-end calibration workflow test
- Invalid sample handling test
- Audio restart latency test

**Phase 5: Manual Testing** (1 hour)
- Deploy to Android device
- Perform calibration with real beatbox sounds
- Verify progress updates in UI
- Verify threshold computation

**Total Estimated Time**: 7-11 hours

### 8.2 Rollback Strategy

**If issues arise during implementation**:
1. Revert analysis thread changes (restore lines 104-146 in `rust/src/analysis/mod.rs`)
2. Revert `AudioEngine::start()` signature
3. Keep `CalibrationManager::get_procedure_arc()` (harmless addition)
4. System returns to previous state: audio works, calibration doesn't send progress

**Risk Mitigation**:
- All changes are additive (no removal of existing functionality)
- Backward compatible signatures (use Option<> for new parameters)
- Extensive unit tests before integration

## 9. API Changes Summary

### 9.1 Modified Functions

| Function | File | Change Type | Breaking? |
|---|---|---|---|
| `spawn_analysis_thread()` | `rust/src/analysis/mod.rs:73` | Add parameters | Yes* |
| `AudioEngine::start()` | `rust/src/audio/engine.rs:211` | Add parameters | Yes* |
| `spawn_analysis_thread_internal()` | `rust/src/audio/engine.rs:174` | Add parameters | No (private) |

*Breaking for internal calls only (not public API)

### 9.2 New Functions

| Function | File | Purpose |
|---|---|---|
| `CalibrationManager::get_procedure_arc()` | `rust/src/managers/calibration_manager.rs` | Get procedure reference for audio engine |

### 9.3 FFI/Public API

**No changes to FFI boundary** - All modifications are internal to Rust layer.

Dart API remains unchanged:
- `start_calibration()` - No signature change
- `calibration_stream()` - No signature change
- `finish_calibration()` - No signature change

## 10. Alternatives Considered

### 10.1 Alternative 1: Callback-Based Architecture

**Idea**: Pass callback function to analysis thread instead of procedure reference.

```rust
type CalibrationCallback = Box<dyn Fn(Features) -> Result<CalibrationProgress, CalibrationError> + Send>;

pub fn spawn_analysis_thread(
    // ...
    calibration_callback: Option<CalibrationCallback>,
) -> JoinHandle<()>
```

**Pros**:
- Decouples analysis thread from calibration types
- More flexible for future extensions

**Cons**:
- Heap allocation for boxed closure (not real-time safe for future optimizations)
- Harder to test (mocking closures is complex)
- Overkill for single use case

**Verdict**: **Rejected** - Adds complexity without clear benefit.

### 10.2 Alternative 2: Message-Passing Architecture

**Idea**: Analysis thread sends features to calibration thread via channel.

```rust
// Analysis thread
let _ = calibration_tx.send(features);

// Calibration thread
while let Ok(features) = calibration_rx.recv() {
    procedure.add_sample(features)?;
}
```

**Pros**:
- Complete decoupling of threads
- Easier to add more consumers of onset features

**Cons**:
- Extra thread overhead
- Extra latency (~1-2ms for channel send/receive)
- More complex error handling (what if channel is full?)
- Overkill for single consumer

**Verdict**: **Rejected** - Unnecessary complexity and latency for single consumer.

### 10.3 Alternative 3: Global Calibration State

**Idea**: Use global static for calibration procedure.

```rust
static CALIBRATION_PROCEDURE: Lazy<Arc<Mutex<Option<CalibrationProcedure>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));
```

**Pros**:
- No need to pass procedure through function signatures
- Simple access from any thread

**Cons**:
- Global mutable state (violates SOLID principles from CLAUDE.md)
- Hard to test (global state persists between tests)
- Hidden dependencies (makes call graph unclear)
- Not compatible with dependency injection

**Verdict**: **Rejected** - Violates project guidelines (DI mandatory, no globals).

### 10.4 Selected Approach: Direct Procedure Reference

**Rationale**:
- ✓ Explicit dependencies (follows DI principle)
- ✓ Easy to test (inject mock procedure)
- ✓ No extra latency
- ✓ Clear ownership (Arc<Mutex<>> for shared access)
- ✓ Minimal code changes

## 11. Future Enhancements

### 11.1 Automatic Calibration Quality Assessment

**Idea**: Analyze collected samples for quality metrics.

```rust
pub struct CalibrationQuality {
    pub kick_consistency: f32,    // 0.0-1.0 (low variance = high consistency)
    pub snare_consistency: f32,
    pub hihat_consistency: f32,
    pub separation_score: f32,    // How distinct the sounds are
}

impl CalibrationProcedure {
    pub fn assess_quality(&self) -> CalibrationQuality { /* ... */ }
}
```

**Benefit**: Warn user if calibration quality is low, suggest recalibration.

### 11.2 Real-Time Sample Feedback

**Idea**: Provide per-sample feedback (not just progress count).

```rust
pub enum SampleFeedback {
    Accepted { quality_score: f32 },
    Rejected { reason: String, suggestion: String },
    TooSimilarToPrevious,  // Encourage variety
}
```

**Benefit**: Help user understand which sounds are good/bad during calibration.

### 11.3 Adaptive Sample Count

**Idea**: Stop collecting samples early if consistency is high.

```rust
pub struct CalibrationProcedure {
    samples_needed: Range<u8>,  // e.g., 5-10 samples
    consistency_threshold: f32,  // e.g., 0.9
}
```

**Benefit**: Reduce calibration time from 2 minutes to <1 minute for consistent users.

### 11.4 Calibration Recovery

**Idea**: Save partial calibration state to disk, resume after app crash.

```rust
pub fn save_partial_calibration(&self) -> Result<(), std::io::Error> {
    let state = PartialCalibrationState {
        kick_samples: self.kick_samples.clone(),
        snare_samples: self.snare_samples.clone(),
        current_sound: self.current_sound,
    };
    // Serialize to JSON and save
}
```

**Benefit**: User doesn't have to restart calibration if app crashes mid-process.

## 12. Open Questions

### Q1: Should we stop metronome during calibration?

**Current**: Metronome plays at 120 BPM during calibration
**Alternative**: Silence metronome, only collect onset samples

**Pros of metronome**:
- Guides user timing (makes it easier to perform sounds)
- Consistent with normal usage (users practice with metronome)

**Pros of silence**:
- Reduces audio interference (metronome click might affect onset detection)
- Simpler audio processing

**Recommendation**: Keep metronome (user guidance is valuable)
**Fallback**: If interference is observed, add flag to disable metronome during calibration

### Q2: Should we provide visual feedback for each sample?

**Current**: Progress shows "3/10 samples" (count only)
**Alternative**: Show checkmark or X for each sample (visual history)

**Implementation**: Modify `CalibrationProgress` to include sample acceptance status
```rust
pub struct CalibrationProgress {
    pub current_sound: String,
    pub samples_collected: u8,
    pub total_samples_needed: u8,
    pub last_sample_status: Option<SampleFeedback>,  // NEW
}
```

**Recommendation**: Defer to future enhancement (Phase 2 feature)
**Rationale**: Keeps initial implementation simple, can add later based on user feedback

### Q3: Should we allow user to skip invalid samples?

**Current**: Invalid samples are silently rejected
**Alternative**: Pause calibration, show error, let user retry or skip

**Pros of skip**:
- User has control
- Avoids frustration if user can't produce valid sound

**Cons of skip**:
- More complex UI flow
- Risk of low-quality calibration (user skips all difficult samples)

**Recommendation**: Keep auto-rejection (simpler UX)
**Rationale**: Sample validation is lenient (wide ranges), invalid samples are rare

## 11. Adaptive Acceptance & Candidate Rescue (NEW)

### 11.1 Adaptive Backoff
- Track consecutive rejects per sound type in the analysis thread (lock-free counters; reset on success).
- After `N` rejects (default 3), relax gates in two dimensions:
  - Onset/RMS gate: `max(noise_floor * 1.2, current_gate * 0.85)`, floor at ×1.2 noise floor.
  - Feature ranges: widen centroid/ZCR bounds by 10% per step, capped at predefined safe min/max.
- Persist the current backoff step in `CalibrationProcedure` (mutable state guarded by existing mutex).
- Emit telemetry log per adjustment: sound type, step, gate values, reason (consecutive_misses).
- Reset step to 0 on first accepted sample or sound transition.

### 11.2 Candidate Buffer for Manual Accept
- Maintain per-sound “last candidate” in `CalibrationProcedure`:
  - Only store candidates that failed gating but passed structural validation (not malformed).
  - Overwrite on each rejected onset.
  - Clear on sound transition or successful accept.
- Expose FFI API: `manual_accept_last_candidate()`:
  - Checks active sound == candidate sound.
  - Pushes candidate through `add_sample` bypassing adaptive gates (still validates shape).
  - Emits `CalibrationProgress` like an auto-accept.
- Telemetry: log manual accept usage and whether a candidate existed.

### 11.3 Real-Time Safety
- Adaptive counters and gate math run in analysis thread but use stack-local copies; only the gate values written back under the existing `calibration_procedure` lock.
- No heap allocations in the hot path; candidate buffer uses fixed-capacity struct (Option<Features>).

## 12. UX Feedback & Observability (NEW)

### 12.1 Guidance Signals
- Extend progress/event stream with optional guidance payload:
  - `GuidanceState { sound: CalibrationSound, reason: Stagnation|TooQuiet|Clipped, level: f32, misses: u8 }`
  - Emitted at most once per 5s while condition persists; cleared on progress or quiet input.
- Dart controller maps guidance to banner copy and auto-clears on progress/quiet.

### 12.2 UI Hooks
- Show guidance banner beneath the level meter (already prototyped) using stream-driven messages instead of local heuristics.
- When `manual_accept_last_candidate` is available, enable a “Count last hit” button; disable otherwise.
- Snackbar/toast on manual accept success/failure.

### 12.3 Observability
- Add structured logs for: adaptive step changes, manual accepts, stagnation enter/exit.
- Include in QA doc a short checklist for verifying adaptive flow (stagnation -> hint -> auto-accept/manual-accept).

## 13. Success Criteria

The design will be considered successful if it meets the following criteria:

### 13.1 Functional Completeness
- ✓ Onset detection forwards features to calibration procedure during calibration mode
- ✓ Progress updates broadcast after each sample
- ✓ Classification mode resumes after calibration completes
- ✓ All 30 samples (10 × 3 sound types) can be collected successfully

### 13.2 Performance
- ✓ Progress broadcast latency < 100ms (measured from onset to UI update)
- ✓ No audio dropouts during calibration
- ✓ Analysis thread CPU usage < 5% average

### 13.3 Quality
- ✓ Unit test coverage ≥ 90% for modified code
- ✓ Integration tests pass for full calibration workflow
- ✓ No crashes observed over 100 calibration runs
- ✓ Code review passes (SOLID, < 500 lines/file, < 50 lines/function)

### 13.4 User Experience
- ✓ UI shows real-time progress during calibration
- ✓ Calibration completes in < 2 minutes (user-driven)
- ✓ Error messages are clear and actionable
- ✓ Saved calibration persists across app restarts

## 14. Appendix

### 14.1 Glossary

- **Onset**: Percussive transient in audio signal (beginning of a beatbox sound)
- **Feature Extraction**: Computing spectral characteristics (centroid, ZCR, etc.) from audio
- **Spectral Centroid**: Weighted mean frequency (Hz), indicates "brightness" of sound
- **Zero-Crossing Rate (ZCR)**: Ratio of sign changes in waveform, indicates noisiness
- **Spectral Flatness**: Measure of tone-like vs. noise-like quality (0.0-1.0)
- **Spectral Rolloff**: Frequency below which 85% of energy is concentrated
- **Decay Time**: Time for signal amplitude to decay to -20dB
- **Quantization**: Snapping onset timestamp to nearest metronome grid position
- **Lock-Free**: Algorithm that doesn't use mutexes or blocking operations
- **Real-Time Safety**: Guarantees bounded execution time (no allocations, locks, or blocking)

### 14.2 References

- **Oboe Documentation**: https://github.com/google/oboe/blob/main/docs/reference/
- **flutter_rust_bridge Guide**: https://cjycode.com/flutter_rust_bridge/
- **Tokio Broadcast Channels**: https://docs.rs/tokio/latest/tokio/sync/broadcast/
- **rtrb Lock-Free Queues**: https://docs.rs/rtrb/latest/rtrb/
- **Project Guidelines**: `.spec-workflow/steering/tech.md`, `~/.claude/CLAUDE.md`
