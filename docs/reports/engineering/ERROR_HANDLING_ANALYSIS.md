# Error Handling Analysis Report
## Beatbox Trainer Project

### Executive Summary
The project demonstrates **inconsistent error handling patterns** across Rust and Dart layers. While Rust uses `Result<T, String>` for explicit error handling, error details are often generic string messages lacking structured logging. Dart screens handle errors reactively but without comprehensive validation.

---

## 1. RUST ERROR HANDLING ANALYSIS

### A. Custom Error Types vs String Errors

**FINDING: Using `anyhow::Result<T>` and `Result<T, String>` - NOT custom error types**

```rust
// rust/src/api.rs - Lines 6, 62, 74, 95, 171, 212, 297, 325
use anyhow::Result;

#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> Result<String> {
    Ok(format!("Hello, {}! Flutter Rust Bridge is working.", name))
}

pub fn start_audio(_bpm: u32) -> Result<(), String> {
    // Uses String for error type, not custom enum
    return Err("BPM must be greater than 0".to_string());
}

pub fn stop_audio() -> Result<(), String> {
    // String error types throughout
    let mut engine_guard = AUDIO_ENGINE.lock().map_err(|e| e.to_string())?;
}
```

**Status**: ✅ Explicit error handling, ❌ No custom error types with error codes

### B. Error Handling Pattern Analysis

#### Pattern 1: Lock Guard Errors
```rust
// rust/src/api.rs:110, 124, 179, 187, 227, 260, 298, 326, 334
let mut engine_guard = AUDIO_ENGINE.lock().map_err(|e| e.to_string())?;
//                                         ^^^^^^^^^^^^^^^^^^^ Generic string conversion
```
**Issue**: Mutex lock errors converted to generic strings - loses error context

#### Pattern 2: Validation Errors (Good)
```rust
// rust/src/api.rs:106-108
if bpm == 0 {
    return Err("BPM must be greater than 0".to_string());
}
```
**Status**: ✅ Clear validation message, ❌ No error code

#### Pattern 3: Chained Error Formatting
```rust
// rust/src/api.rs:144, 151
engine.start(calibration, classification_tx)
    .map_err(|e| format!("Failed to start audio: {}", e))?;
//        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Context added
```
**Status**: ✅ Context provided, ❌ Error codes missing

### C. Error Handling Consistency in Modules

#### Audio Engine (rust/src/audio/engine.rs)
```rust
// Lines 96-150: Result<Self, String>
pub fn new(
    bpm: u32,
    sample_rate: u32,
    buffer_channels: BufferPoolChannels,
) -> Result<Self, String> {
    // No error handling for construction - returns Ok(()) immediately
    // Actual I/O errors deferred to start() method
}

pub fn start(...) -> Result<(), String> {
    let input_stream = AudioStreamBuilder::default()
        .set_performance_mode(PerformanceMode::LowLatency)
        .set_sharing_mode(SharingMode::Exclusive)
        .set_direction::<Input>()
        .set_sample_rate(sample_rate as i32)
        .set_channel_count(1)
        .set_format::<f32>()
        .open_stream()
        .map_err(|e| format!("Failed to open input stream: {:?}", e))?;
        //                                           ^^^^^^ Includes debug output
}
```

#### Calibration State (rust/src/calibration/state.rs)
```rust
// Lines 63-110: Detailed error messages with context
pub fn from_samples(
    kick_samples: &[Features],
    snare_samples: &[Features],
    hihat_samples: &[Features],
) -> Result<Self, String> {
    if kick_samples.len() != 10 {
        return Err(format!(
            "Expected exactly 10 kick samples, got {}",
            kick_samples.len()
        ));
    }
    
    Self::validate_samples(kick_samples, "kick")?;
}

fn validate_samples(samples: &[Features], sound_name: &str) -> Result<(), String> {
    for (i, features) in samples.iter().enumerate() {
        if features.centroid < 50.0 || features.centroid > 20000.0 {
            return Err(format!(
                "{} sample {}: centroid {} Hz out of valid range [50, 20000]",
                sound_name, i, features.centroid
            ));
        }
    }
    Ok(())
}
```
**Status**: ✅ Detailed error messages with context, ✅ Index numbers included

#### Calibration Procedure (rust/src/calibration/procedure.rs)
```rust
// Lines 114-176: Similar pattern with user-friendly messages
pub fn add_sample(&mut self, features: Features) -> Result<(), String> {
    Self::validate_sample(&features)?;
    
    match self.current_sound {
        CalibrationSound::Kick => {
            if self.kick_samples.len() >= self.samples_needed as usize {
                return Err("Kick samples already complete".to_string());
            }
        }
    }
    Ok(())
}

fn validate_sample(features: &Features) -> Result<(), String> {
    if features.centroid < 50.0 || features.centroid > 20000.0 {
        return Err(format!(
            "Invalid sample: centroid {} Hz out of range [50, 20000]. Try again.",
            features.centroid
        ));
    }
    Ok(())
}
```
**Status**: ✅ User-friendly messages, ✅ Actionable guidance ("Try again")

### D. Logging Pattern in Rust

**FINDING: Minimal structured logging, mix of log/println/eprintln**

```rust
// rust/src/lib.rs - Lines 27-34
fn init_logging() {
    use log::info;
    android_logger::init_once(
        android_logger::Config::default()
            .with_max_level(log::LevelFilter::Debug)
            .with_tag("BeatboxTrainer"),
    );
    info!("Android logger initialized");
}

// rust/src/audio/engine.rs
log::warn!("AudioEngine::start() called on non-Android platform - no-op");
log::warn!("AudioEngine::stop() called on non-Android platform - no-op");

// rust/src/analysis/onset.rs, features.rs, mod.rs
println!("Detected onsets at samples: {:?}", onsets);
eprintln!("Warning: POOL_QUEUE full, dropping buffer");
// ❌ Mix of println, eprintln, and structured log
```

**Status**: ✅ log crate configured, ❌ Inconsistent usage across modules, ❌ No JSON structured logging

### E. Unwrap Usage (Panic Risk)

```rust
// rust/src/audio/buffer_pool.rs:256, 258, 269, 271, 305
let mut buffer = channels.pool_consumer.pop().unwrap();
let buffer = channels.data_consumer.pop().unwrap();
// ❌ Potential panics in real-time code

// rust/src/analysis/onset.rs:151, 207
let mut planner = self.fft_planner.lock().unwrap();
window.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
// ⚠️ Lock unwrap in analysis thread

// rust/src/api.rs:260, 369
let sender_guard = CLASSIFICATION_BROADCAST.lock().unwrap();
let procedure_guard = CALIBRATION_PROCEDURE.lock().unwrap();
// ⚠️ Unwraps in public API functions (async context)

// rust/src/calibration/procedure.rs:336-351
procedure.add_sample(kick_features).unwrap();
procedure.add_sample(snare_features).unwrap();
procedure.add_sample(hihat_features).unwrap();
// ⚠️ Test code only, but pattern problematic
```

**Finding**: 11+ unwrap() calls in production code paths. Lock unwraps could panic if poisoned.

---

## 2. DART ERROR HANDLING ANALYSIS

### A. Dart API Layer (lib/bridge/api.dart)

```dart
// lib/bridge/api.dart - Lines 16-62
// ❌ STUB FILE - No actual error handling
Future<void> startAudio({required int bpm}) async {
  throw UnimplementedError(
    'This is a stub. Run flutter_rust_bridge_codegen generate to create the actual implementation.',
  );
}

Stream<ClassificationResult> classificationStream() {
  throw UnimplementedError(
    'This is a stub. Run flutter_rust_bridge_codegen generate to create the actual implementation.',
  );
}
```

**Status**: ⚠️ Stub file - actual error handling generated by codegen (not analyzed)

### B. Training Screen (lib/ui/screens/training_screen.dart)

#### Error Handling Pattern
```dart
// Lines 46-72: _startTraining()
Future<void> _startTraining() async {
    try {
        await startAudio(bpm: _currentBpm);
        final stream = classificationStream();
        setState(() {
            _isTraining = true;
            _classificationStream = stream;
        });
    } catch (e) {
        if (mounted) {
            _showErrorDialog(e.toString());
            // ❌ Generic e.toString() - loses type information
        }
    }
}

// Lines 74-91: _stopTraining()
Future<void> _stopTraining() async {
    try {
        await stopAudio();
        setState(() { ... });
    } catch (e) {
        if (mounted) {
            _showErrorDialog('Failed to stop audio: $e');
            // ⚠️ String interpolation, no error type checking
        }
    }
}

// Lines 93-110: _updateBpm()
Future<void> _updateBpm(int newBpm) async {
    setState(() { _currentBpm = newBpm; });
    
    if (_isTraining) {
        try {
            await setBpm(bpm: newBpm);
        } catch (e) {
            if (mounted) {
                _showErrorDialog('Failed to update BPM: $e');
                // ⚠️ Still updating local state even if setBpm fails
            }
        }
    }
}
```

**Issues**:
- ❌ No error type discrimination (all caught as generic Exception)
- ⚠️ No validation before API calls
- ⚠️ BPM update optimistically applies state change before confirming success
- ❌ Error messages expose raw Rust error strings to users

#### Error Display
```dart
// Lines 204-218: _showErrorDialog()
void _showErrorDialog(String message) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),  // Raw error message from Rust
            actions: [...],
        ),
    );
}
```

**Issue**: ❌ Displays raw technical error messages directly to user

#### Stream Error Handling
```dart
// Lines 263-299: StreamBuilder
StreamBuilder<ClassificationResult>(
    stream: _classificationStream,
    builder: (context, snapshot) {
        if (snapshot.hasError) {
            return Center(
                child: Column(
                    children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        Text('Stream error: ${snapshot.error}'),
                        // ❌ Raw stream error message displayed
                    ],
                ),
            );
        }
        
        if (snapshot.hasData) {
            _currentResult = snapshot.data;
            return _buildClassificationDisplay(_currentResult!);
        }
    },
)
```

**Status**: ✅ Handles ConnectionState, ✅ Displays error state, ❌ No recovery mechanism

### C. Calibration Screen (lib/ui/screens/calibration_screen.dart)

#### Error Handling Pattern
```dart
// Lines 57-78: _startCalibration()
Future<void> _startCalibration() async {
    try {
        await startCalibration();
        final stream = calibrationStream();
        setState(() {
            _isCalibrating = true;
            _calibrationStream = stream;
            _currentProgress = null;
            _errorMessage = null;
        });
    } catch (e) {
        setState(() {
            _errorMessage = 'Failed to start calibration: $e';
            _isCalibrating = false;
            // ✅ Stores error for display, ✅ Resets state
        });
    }
}

// Lines 80-96: _finishCalibration()
Future<void> _finishCalibration() async {
    try {
        await finishCalibration();
        if (mounted) {
            Navigator.of(context).pop();
        }
    } catch (e) {
        setState(() {
            _errorMessage = 'Calibration failed: $e';
            _isCalibrating = false;
        });
    }
}

// Lines 98-107: _restartCalibration()
Future<void> _restartCalibration() async {
    setState(() {
        _currentProgress = null;
        _errorMessage = null;
        _isCalibrating = false;
    });
    await _startCalibration();
    // ✅ Provides recovery mechanism
}
```

**Status**: 
- ✅ Stores errors in state variable
- ✅ Provides recovery mechanism (_restartCalibration)
- ❌ Still exposes raw error messages to user
- ⚠️ No error classification/discrimination

#### Error Display
```dart
// Lines 152-185: _buildErrorDisplay()
Widget _buildErrorDisplay() {
    return Center(
        child: Column(
            children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                Text(
                    _errorMessage!,  // ⚠️ Raw error message
                    style: const TextStyle(fontSize: 18, color: Colors.red),
                ),
                ElevatedButton(
                    onPressed: _restartCalibration,  // ✅ Retry option
                    child: const Text('Retry'),
                ),
            ],
        ),
    );
}

// Lines 206-252: Stream error handling in StreamBuilder
StreamBuilder<CalibrationProgress>(
    stream: _calibrationStream,
    builder: (context, snapshot) {
        if (snapshot.hasError) {
            return Center(
                child: Column(
                    children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        Text('Stream error: ${snapshot.error}'),
                        // ❌ No recovery from stream errors
                    ],
                ),
            );
        }
    },
)
```

**Status**: ⚠️ Missing recovery for stream errors (only UI errors have retry)

---

## 3. CROSS-LAYER ERROR FLOW

```
Rust API (Result<T, String>)
        ↓
        └→ Error message string
           │
           ├─ Example: "BPM must be greater than 0"
           ├─ Example: "Failed to open input stream: AudioError"
           └─ Example: "Invalid sample: centroid 15000 Hz out of range"
                ↓
Dart catch (e) { e.toString() }
        ↓
        └→ Platform Exception (from flutter_rust_bridge)
           │
           └─ Message: "BPM must be greater than 0"
                ↓
_showErrorDialog(e.toString())
        ↓
        └→ User sees raw technical message
           ├─ ❌ Not user-friendly
           ├─ ❌ No actionable guidance
           └─ ❌ Exposes implementation details
```

---

## 4. VALIDATION & INPUT CHECKING

### Rust Validation (Good)

```rust
// rust/src/api.rs:106-108
if bpm == 0 {
    return Err("BPM must be greater than 0".to_string());
}
// ✅ Validates BPM before processing

// rust/src/calibration/procedure.rs:158-176
fn validate_sample(features: &Features) -> Result<(), String> {
    if features.centroid < 50.0 || features.centroid > 20000.0 {
        return Err(format!(
            "Invalid sample: centroid {} Hz out of range [50, 20000]. Try again.",
            features.centroid
        ));
    }
    // ✅ Range validation with guidance
}
```

### Dart Validation (Missing)

```dart
// lib/ui/screens/training_screen.dart:94-110
Future<void> _updateBpm(int newBpm) async {
    setState(() { _currentBpm = newBpm; });
    // ❌ No validation of newBpm range (40-240)
    
    if (_isTraining) {
        try {
            await setBpm(bpm: newBpm);  // Assumes valid
        } catch (e) {
            // Error handled here, but optimistic state update already done
        }
    }
}

// lib/ui/screens/calibration_screen.dart - No validation layer
// ❌ No pre-flight checks before API calls
```

---

## 5. MISSING ERROR HANDLING

### In Rust (Production Code)

1. **Buffer Pool Errors** (rust/src/audio/buffer_pool.rs:256, 305)
   ```rust
   let mut buffer = channels.pool_consumer.pop().unwrap();
   // ❌ Panics if queue empty (should use map_err)
   ```

2. **FFT Planner Lock** (rust/src/analysis/onset.rs:151)
   ```rust
   let mut planner = self.fft_planner.lock().unwrap();
   // ❌ Panics if lock poisoned
   ```

3. **Broadcast Channel Send** (rust/src/api.rs:133)
   ```rust
   let _ = broadcast_tx_clone.send(result);
   // ⚠️ Silently ignores send errors (acceptable for broadcast)
   ```

### In Dart (UI Layer)

1. **No Input Validation Before API Calls**
   - BPM range [40-240] not validated before setBpm()
   - Permission checks done, but no other pre-flight validation

2. **No Error Classification**
   ```dart
   catch (e) {
       _showErrorDialog(e.toString());  // No way to handle permission vs audio errors differently
   }
   ```

3. **No Retry Logic for Transient Errors**
   - Stream errors have no recovery mechanism
   - Only manual "Retry" button in CalibrationScreen

4. **No Error Context Object**
   ```dart
   // Currently:
   _errorMessage = 'Calibration failed: $e';
   
   // Should be:
   // _errorMessage = AppError(
   //   code: 'CALIBRATION_FAILED',
   //   userMessage: 'Could not complete calibration',
   //   technicalMessage: e.toString(),
   // );
   ```

---

## SUMMARY TABLE

| Aspect | Rust | Dart | Score |
|--------|------|------|-------|
| **Custom Error Types** | String errors only | None | 1/10 |
| **Error Codes** | Missing | Missing | 0/10 |
| **Logging** | Partial (log + println mix) | None | 2/10 |
| **Structured Logging** | None (no JSON) | None | 0/10 |
| **User-Friendly Messages** | Partial (calibration good) | None (raw strings) | 2/10 |
| **Input Validation** | Good (Rust layer) | Missing (Dart layer) | 4/10 |
| **Error Recovery** | None (panics via unwrap) | Partial (retry buttons) | 3/10 |
| **Context Preservation** | Good (error chains) | Limited (toString only) | 4/10 |
| **Consistency** | Moderate (varies by module) | Low (ad-hoc) | 3/10 |

---

## RECOMMENDATIONS

### High Priority

1. **Create Custom Error Type in Rust**
   ```rust
   #[derive(Debug)]
   pub enum AudioError {
       StreamInitFailed { reason: String },
       BpmInvalid { bpm: u32 },
       CalibrationIncomplete { missing: String },
       LockPoisoned,
   }
   
   impl std::fmt::Display for AudioError { ... }
   impl std::error::Error for AudioError { ... }
   ```

2. **Replace Unwrap with Proper Error Handling**
   - buffer_pool.rs: Use Option handling or Result
   - onset.rs: Handle lock poisoning
   - api.rs: Propagate lock errors instead of unwrapping

3. **Implement Error Code System**
   ```rust
   pub enum ErrorCode {
       AUDIO_INIT = 1001,
       BPM_INVALID = 1002,
       CALIBRATION_INCOMPLETE = 1003,
       STREAM_ERROR = 1004,
   }
   ```

### Medium Priority

4. **Structured Logging in Rust**
   ```rust
   // Use slog or tracing crate for JSON structured logs
   slog::info!(logger, "Audio started"; 
       "bpm" => bpm, 
       "sample_rate" => sample_rate,
   );
   ```

5. **Error Translation Layer in Dart**
   ```dart
   class AppError {
       final String code;
       final String userMessage;
       final String technicalDetails;
       
       factory AppError.fromPlatformException(PlatformException e) {
           // Map Rust error messages to user-friendly messages
       }
   }
   ```

6. **Input Validation in Dart**
   ```dart
   void _updateBpm(int newBpm) {
       if (!_isValidBpm(newBpm)) {
           _showErrorDialog('BPM must be between 40 and 240');
           return;
       }
       // ... proceed
   }
   ```

### Lower Priority

7. **Implement Retry Logic with Backoff**
   ```dart
   Future<void> _retryWithBackoff(Future Function() operation) async {
       for (int attempt = 0; attempt < 3; attempt++) {
           try {
               await operation();
               return;
           } catch (e) {
               if (attempt < 2) await Future.delayed(Duration(seconds: 1 << attempt));
           }
       }
   }
   ```

---

## CONCLUSION

**Current State**: Minimal error handling - relies on generic string errors and basic try-catch blocks.

**Risk Level**: 🔴 HIGH
- Unwrap() calls can panic in audio thread
- No user-friendly error messages
- Missing input validation in UI layer
- Stream errors lack recovery mechanism

**Effort to Fix**: Medium (2-3 days)
- Error type definition: 2 hours
- Replace unwraps: 4 hours
- Add validation: 3 hours
- Error translation: 2 hours
- Testing: 4 hours
