# Code Quality Audit - Beatbox Trainer

## Executive Summary

**Audit Date**: 2025-11-13
**Project**: Beatbox Trainer (Flutter + Rust)
**Total Files Analyzed**: ~15 source files (Dart: 11, Rust: ~4,300 LOC)

### Critical Violations
1. **TESTABILITY BLOCKERS**: 5 global statics in Rust FFI layer (rust/src/api.rs)
2. **ERROR HANDLING**: No custom error types, 11+ unwrap() calls that can panic
3. **FILE SIZE VIOLATIONS**: 2 files exceed 500 lines (calibration_screen.dart: 464, training_screen.dart: 452)
4. **FUNCTION SIZE**: 1 function exceeds 50 lines (AudioEngine::start(): 112 lines)
5. **DEPENDENCY INJECTION**: Zero DI - all dependencies hard-coded or global

---

## 1. Testability Blockers (CRITICAL)

### Rust FFI Layer - Global State Anti-pattern
**Location**: rust/src/api.rs:25-43

```rust
static AUDIO_ENGINE: Lazy<Arc<Mutex<Option<AudioEngineState>>>> = ...
static CALIBRATION_PROCEDURE: Lazy<Arc<Mutex<Option<CalibrationProcedure>>>> = ...
static CALIBRATION_STATE: Lazy<Arc<RwLock<CalibrationState>>> = ...
static CLASSIFICATION_BROADCAST: Lazy<Arc<Mutex<Option<...>>>> = ...
static CALIBRATION_BROADCAST: Lazy<Arc<Mutex<Option<...>>>> = ...
```

**Issues**:
- Cannot unit test without affecting global state
- Cannot run tests in parallel
- Cannot mock dependencies
- Violates Dependency Injection principle
- Not thread-safe initialization (Lazy vs OnceCell)

**Impact**: Makes entire Rust backend **untestable** in isolation

---

## 2. Architectural Issues

### 2.1 SOLID Violations

#### Single Responsibility Principle (SRP)
**training_screen.dart**: Violates SRP
- Manages UI state
- Handles permission logic
- Manages audio lifecycle
- Formats display strings
- Direct API calls

**Recommendation**: Extract services:
- PermissionService
- AudioService wrapper
- DisplayFormatter utility

#### Dependency Inversion Principle (DIP)
**ALL Dart screens** depend on concrete implementation:
```dart
import '../../bridge/api.dart';  // Direct concrete dependency
await startAudio(bpm: _currentBpm);  // No abstraction layer
```

**Missing**: Repository pattern, service interfaces

---

### 2.2 Code Redundancy (DRY Violations)

#### Duplicated UI Patterns
**Both screens** have near-identical:
1. **Error dialogs** (3x in training_screen.dart, duplicated in calibration_screen.dart)
2. **Loading indicators** (4+ identical CircularProgressIndicator patterns)
3. **Container decorations** (BoxDecoration patterns repeated 5+ times)

**Estimated Duplication**: ~150 lines

#### Duplicated Error Handling
```dart
// Pattern repeated 6+ times across both screens:
if (mounted) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(...)
  );
}
```

**Recommendation**: Extract to shared widgets/utilities

---

## 3. File & Function Size KPIs

### Files Exceeding 500 Lines
| File | Lines | Limit | Status |
|------|-------|-------|--------|
| calibration_screen.dart | 464 | 500 | ⚠️ NEAR LIMIT |
| training_screen.dart | 452 | 500 | ⚠️ NEAR LIMIT |
| calibration/procedure.rs | 581 | 500 | ❌ **VIOLATION** |
| analysis/features.rs | 576 | 500 | ❌ **VIOLATION** |
| audio/engine.rs | 435 | 500 | ✅ PASS |
| analysis/classifier.rs | 457 | 500 | ✅ PASS |
| analysis/quantizer.rs | 453 | 500 | ✅ PASS |

**Violations**: 2 Rust files (primarily due to extensive tests)

### Functions Exceeding 50 Lines
| Function | Lines | File | Issue |
|----------|-------|------|-------|
| AudioEngine::start() | 112 | audio/engine.rs | Callback setup + stream init + thread spawn |
| _buildProgressContent() | 169 | calibration_screen.dart | Monolithic widget builder |
| _buildClassificationDisplay() | 90 | training_screen.dart | Complex UI logic |

**Violations**: 3 functions need refactoring

---

## 4. Error Handling Analysis

### 4.1 No Custom Error Types
**Current**: `Result<T, String>` everywhere
```rust
pub fn start_audio(_bpm: u32) -> Result<(), String> {
    return Err("Audio engine already running".to_string());
}
```

**Missing**:
```rust
pub enum AudioError {
    AlreadyRunning,
    PermissionDenied,
    DeviceBusy,
    InvalidBpm(u32),
}
```

### 4.2 Panic Risks
**11+ unwrap() calls in production code**:
- api.rs: `CLASSIFICATION_BROADCAST.lock().unwrap()` (lines 124, 187, 371)
- classifier.rs: `self.calibration.read().unwrap()` (line 75)
- buffer_pool.rs: Multiple unwrap() on lock-free queues
- onset.rs: Array indexing with potential panics

**Impact**: App can crash if lock is poisoned or array out of bounds

### 4.3 User-Facing Error Exposure
**Dart screens show raw Rust errors**:
```dart
_showErrorDialog(e.toString());  // Shows "AudioError::DeviceBusy" to users
```

**Needed**: Error translation layer

---

## 5. Missing Pre-commit Hooks

**No automated checks found**:
- ❌ No linting enforcement
- ❌ No formatting checks
- ❌ No test execution
- ❌ No code metrics validation

**Recommendation**: Add `.git/hooks/pre-commit`:
```bash
#!/bin/bash
flutter analyze || exit 1
cargo fmt -- --check || exit 1
cargo clippy -- -D warnings || exit 1
flutter test || exit 1
```

---

## 6. Test Coverage Gaps

### Missing Tests
- **Dart**: No unit tests for screens (0% coverage)
- **Dart**: No widget tests for custom UI components
- **Rust api.rs**: Global state cannot be unit tested
- **Integration**: No end-to-end Flutter↔Rust tests

### Existing Tests (Good)
✅ Rust DSP components have comprehensive unit tests
✅ Feature extraction well-covered
✅ Calibration logic tested

**Estimated Coverage**: ~40% (Rust backend only)
**Target**: 80% minimum

---

## Priority-Ordered Recommendations

### P0 - Critical (2-3 days)
1. **Remove all unwrap() calls** - Replace with proper error handling
2. **Create custom error enum** - Stop using String errors
3. **Add pre-commit hooks** - Enforce quality gates

### P1 - High (3-5 days)
4. **Refactor api.rs globals** - Introduce AppContext struct with DI
5. **Extract Dart services** - PermissionService, AudioService abstractions
6. **Break down long functions** - AudioEngine::start(), _buildProgressContent()

### P2 - Medium (5-7 days)
7. **Extract UI components** - Shared error dialogs, loading indicators
8. **Add unit tests for Dart** - Test business logic separately from UI
9. **Implement error translation** - User-friendly messages

### P3 - Low (Ongoing)
10. **Split large files** - calibration/procedure.rs, analysis/features.rs
11. **Add structured logging** - JSON format with context
12. **Document architecture** - Dependency graphs, design patterns

---

## Conclusion

**Overall Code Quality**: 5/10
- ✅ Strong DSP/algorithm implementation
- ✅ Good separation in analysis modules
- ❌ Critical testability issues
- ❌ No dependency injection
- ❌ Unsafe error handling (panics)
- ❌ Significant code duplication in UI

**Estimated Refactoring Effort**: 15-20 developer days

**Biggest Risk**: Global state + unwrap() calls can cause production crashes