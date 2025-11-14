# Test Coverage Report
Generated: 2025-11-14

## Executive Summary

| Metric | Dart | Rust | Overall |
|--------|------|------|---------|
| Lines Hit | 955 | 2,513 | 3,468 |
| Lines Total | 1,824 | 3,690 | 5,514 |
| **Coverage** | **52.4%** | **68.1%** | **62.9%** |

## Requirements Analysis

### Minimum Coverage Requirements
- **Overall Target**: 80% minimum
- **Critical Paths Target**: 90% minimum

### Status
- ❌ Overall coverage **BELOW** 80% requirement (62.9% < 80%)
- ❌ Dart coverage **BELOW** 80% requirement (52.4% < 80%)
- ❌ Rust coverage **BELOW** 80% requirement (68.1% < 80%)

## Critical Path Coverage (90% Requirement)

### Dart Critical Paths

| File | Coverage | Status |
|------|----------|--------|
| lib/services/debug/i_debug_service.dart | 0.0% | ❌ FAIL |
| lib/services/debug/debug_service_impl.dart | 17.2% | ❌ FAIL |
| lib/services/permission/permission_service_impl.dart | 41.7% | ❌ FAIL |
| lib/services/audio/audio_service_impl.dart | 44.3% | ❌ FAIL |
| lib/services/navigation/go_router_navigation_service.dart | 77.8% | ❌ FAIL |
| lib/services/settings/settings_service_impl.dart | 83.7% | ❌ FAIL |
| lib/services/storage/storage_service_impl.dart | 85.0% | ❌ FAIL |
| lib/di/service_locator.dart | 100.0% | ✅ PASS |
| lib/controllers/training/training_controller.dart | 100.0% | ✅ PASS |

### Rust Critical Paths

| File | Coverage | Status |
|------|----------|--------|
| context.rs | 41.0% | ❌ FAIL |
| managers/audio_engine_manager.rs | 48.2% | ❌ FAIL |
| audio/metronome.rs | 81.2% | ❌ FAIL |
| managers/calibration_manager.rs | 86.2% | ❌ FAIL |
| audio/buffer_pool.rs | 87.2% | ❌ FAIL |
| error.rs | 94.2% | ✅ PASS |
| audio/engine.rs | 97.6% | ✅ PASS |
| audio/stubs.rs | 100.0% | ✅ PASS |
| managers/broadcast_manager.rs | 100.0% | ✅ PASS |

## Coverage Gaps

### Critical Paths Below 90%

**Dart:**
- lib/services/debug/i_debug_service.dart: 0.0% (gap: 90.0%)
- lib/services/debug/debug_service_impl.dart: 17.2% (gap: 72.8%)
- lib/services/permission/permission_service_impl.dart: 41.7% (gap: 48.3%)
- lib/services/audio/audio_service_impl.dart: 44.3% (gap: 45.7%)
- lib/services/navigation/go_router_navigation_service.dart: 77.8% (gap: 12.2%)
- lib/services/settings/settings_service_impl.dart: 83.7% (gap: 6.3%)
- lib/services/storage/storage_service_impl.dart: 85.0% (gap: 5.0%)

**Rust:**
- context.rs: 41.0% (gap: 49.0%)
- managers/audio_engine_manager.rs: 48.2% (gap: 41.8%)
- audio/metronome.rs: 81.2% (gap: 8.8%)
- managers/calibration_manager.rs: 86.2% (gap: 3.8%)
- audio/buffer_pool.rs: 87.2% (gap: 2.8%)

## Recommendations

1. **Increase Overall Coverage**: Current 62.9% is significantly below 80% target

2. **Improve Dart Coverage**: Focus on:
   - FFI bridge layer (currently 0-40%)
   - Debug services (currently 0-17%)
   - Permission services (currently 42%)
   - Audio services (currently 44%)
   - Navigation services (currently 78%)

3. **Improve Rust Coverage**: Focus on:
   - AppContext facade (currently 41%)
   - AudioEngineManager (currently 48%)
   - Metronome (currently 81%)

4. **Address Critical Path Gaps**: Priority items (by coverage percentage):
   - [Dart] lib/services/debug/i_debug_service.dart (0.0%)
   - [Dart] lib/services/debug/debug_service_impl.dart (17.2%)
   - [Rust] context.rs (41.0%)
   - [Dart] lib/services/permission/permission_service_impl.dart (41.7%)
   - [Dart] lib/services/audio/audio_service_impl.dart (44.3%)

5. **Fix Failing Tests**: Currently 13 tests are failing in the Dart test suite. These need to be fixed before accurate coverage can be measured and improved.

## Test Status

### Dart Tests
- **Status**: 412 passed, 13 failed
- **Issues**:
  - TrainingController tests have failures related to test setup
  - CalibrationScreen tests have rendering overflow errors
  - Some tests are looking up deactivated widgets

### Rust Tests
- **Status**: All 154 tests passed ✅
  - 146 unit tests passed
  - 8 integration tests passed

## Next Steps

1. **Fix failing Dart tests** (priority: CRITICAL)
   - Investigate and fix the 13 failing tests
   - Ensure all tests pass before measuring final coverage

2. **Add missing test coverage** for low-coverage areas:
   - Write integration tests for FFI bridge layer
   - Add unit tests for debug services
   - Increase test coverage for permission and audio services

3. **Verify critical path coverage** once tests are fixed:
   - Ensure all critical paths reach 90%+ coverage
   - Focus on business logic and error handling paths

## Files Generated

- Rust coverage: coverage/rust/lcov.info
- Dart coverage: Not generated due to test failures
- This report: coverage/COVERAGE_REPORT.md

## Notes

- Dart coverage data is based on the last successful partial run
- Full coverage report requires fixing the 13 failing tests first
- Rust coverage is complete and accurate (all tests passing)
