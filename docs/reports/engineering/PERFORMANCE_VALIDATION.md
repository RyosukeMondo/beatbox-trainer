# Performance Validation Guide

This document describes how to validate that the Beatbox Trainer application meets all performance requirements for UAT readiness.

## Performance Requirements

The application must meet these strict performance criteria:

| Metric | Requirement | Priority |
|--------|-------------|----------|
| Audio Processing Latency | < 20ms | Critical |
| Metronome Jitter | = 0ms (perfect timing) | Critical |
| CPU Usage | < 15% average | Critical |
| Stream Overhead | < 5ms | High |

## Prerequisites

### Required Tools

1. **Android Debug Bridge (adb)**
   ```bash
   # Check if adb is installed
   adb version

   # If not installed, install Android SDK Platform Tools
   # Ubuntu/Debian:
   sudo apt-get install android-tools-adb

   # macOS (using Homebrew):
   brew install android-platform-tools
   ```

2. **Python 3.8+**
   ```bash
   # Check Python version
   python3 --version

   # Should be 3.8 or higher
   ```

3. **Android Device**
   - Physical Android device (API level 26+) connected via USB
   - USB debugging enabled
   - Device authorized for debugging

### Application Setup

1. **Build Release Version**
   ```bash
   # Build Flutter app in release mode
   flutter build apk --release

   # Or build app bundle
   flutter build appbundle --release
   ```

2. **Install on Device**
   ```bash
   # Install APK
   flutter install

   # Or use adb directly
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

3. **Verify Device Connection**
   ```bash
   # List connected devices
   adb devices

   # Should show device in 'device' state
   # Example output:
   # List of devices attached
   # ABC123XYZ   device
   ```

## Running Performance Validation

### Basic Usage

```bash
# Run validation with default device
python3 tools/performance_validation.py

# Specify device ID if multiple devices connected
python3 tools/performance_validation.py --device ABC123XYZ

# Specify output file path
python3 tools/performance_validation.py --output reports/perf_validation_$(date +%Y%m%d).json
```

### What the Tool Does

The validation tool performs these measurements:

1. **Audio Processing Latency**
   - Captures latency metrics from audio engine logs
   - Measures time from onset detection to classification result
   - Collects samples over 10 seconds
   - Reports average latency

2. **Metronome Jitter**
   - Captures metronome timing events from logs
   - Measures deviation from perfect timing
   - Collects samples over 10 seconds
   - Reports maximum jitter (should be 0ms)

3. **CPU Usage**
   - Monitors CPU usage during active audio processing
   - Uses Android `top` command
   - Samples every second for 10 seconds
   - Reports average CPU percentage

4. **Stream Overhead**
   - Measures additional latency from stream implementation
   - Tracks time from Rust emission to Dart reception
   - Collects samples over 10 seconds
   - Reports average overhead

### Expected Output

```
======================================================================
BEATBOX TRAINER - PERFORMANCE VALIDATION (UAT Readiness)
======================================================================

Device: Pixel 6
Android Version: 13

Running performance measurements...
----------------------------------------------------------------------
  [1/4] Measuring audio processing latency...
     Collecting latency samples (10 seconds)...
     Captured 247 samples, average: 15.32ms
  [2/4] Measuring metronome jitter...
     Collecting metronome timing samples (10 seconds)...
     Captured 120 samples, max jitter: 0.0ms
  [3/4] Measuring CPU usage...
     Collecting CPU usage samples (10 seconds)...
     Captured 10 samples, average: 11.2%, max: 13.5%
  [4/4] Measuring stream overhead...
     Collecting stream timing samples (10 seconds)...
     Captured 245 samples, average: 2.15ms

======================================================================
PERFORMANCE VALIDATION RESULTS
======================================================================

Audio Processing Latency:
  Status: ✓ PASS
  Measured 15.32ms (threshold: < 20ms)

Metronome Jitter:
  Status: ✓ PASS
  Measured 0.00ms (threshold: = 0ms)

CPU Usage:
  Status: ✓ PASS
  Measured 11.2% (threshold: < 15%)

Stream Overhead:
  Status: ✓ PASS
  Measured 2.15ms (threshold: < 5ms)

----------------------------------------------------------------------
OVERALL: ✓ ALL PERFORMANCE REQUIREMENTS MET

The application is ready for UAT deployment.
======================================================================

Results saved to: performance_validation_report.json
```

### JSON Report Format

The tool generates a JSON report with detailed results:

```json
{
  "timestamp": "2025-11-14T10:30:45.123456",
  "device_info": {
    "model": "Pixel 6",
    "manufacturer": "Google",
    "android_version": "13"
  },
  "results": [
    {
      "metric_name": "Audio Processing Latency",
      "measured_value": 15.32,
      "threshold_value": 20.0,
      "unit": "ms",
      "passed": true,
      "message": "Measured 15.32ms (threshold: < 20ms)"
    },
    ...
  ],
  "all_passed": true
}
```

## Troubleshooting

### No Metrics Captured

If the tool reports "WARNING: No samples captured from logcat", this could mean:

1. **App not running in release mode**
   - Debug metrics may not be enabled in debug builds
   - Solution: Ensure you're testing the release build

2. **Debug logging disabled**
   - Check if the Rust audio engine has debug logging enabled
   - Solution: Verify `RUST_LOG=debug` or similar is set

3. **App not actively processing audio**
   - The app needs to be in training mode
   - Solution: Start a training session before running validation

### Device Not Found

```
ERROR: No Android device connected or device not authorized.
```

Solutions:
- Check USB cable connection
- Enable USB debugging in Developer Options
- Accept "Allow USB debugging" prompt on device
- Run `adb devices` and verify device listed

### Permission Denied

```
ERROR: adb: insufficient permissions for device
```

Solutions:
- On Linux: Add yourself to `plugdev` group
  ```bash
  sudo usermod -aG plugdev $USER
  # Log out and log back in
  ```
- Check udev rules for Android devices
- Try running with `sudo` (not recommended for security)

### Multiple Devices Connected

```
ERROR: more than one device/emulator
```

Solution:
```bash
# List devices
adb devices

# Run validation with specific device
python3 tools/performance_validation.py --device DEVICE_ID
```

## Manual Validation

If the automated tool cannot be used, perform manual validation:

### 1. Latency Measurement

```bash
# Enable verbose logging
adb logcat -c
adb logcat -s AudioEngine:V RustAudio:V | grep -i latency

# Start training session on device
# Observe latency values in logcat output
# Calculate average manually
```

### 2. Jitter Measurement

```bash
# Monitor metronome timing
adb logcat -c
adb logcat -s Metronome:V BeatScheduler:V | grep -i jitter

# Start training session with metronome enabled
# Verify all jitter values are 0.0ms
```

### 3. CPU Usage Measurement

```bash
# Monitor CPU usage in real-time
adb shell top | grep beatboxtrainer

# Or use Android Profiler in Android Studio
# Target: < 15% CPU average
```

### 4. Stream Overhead Measurement

```bash
# Monitor stream timing
adb logcat -c
adb logcat -s StreamMetrics:V ClassificationStream:V | grep -i overhead

# Start training session
# Observe overhead values
# Calculate average manually
```

## Performance Optimization Tips

If validation fails, consider these optimizations:

### High Latency (> 20ms)

- Check audio buffer size configuration
- Verify DSP pipeline is lock-free
- Profile classification algorithm
- Reduce unnecessary allocations in hot path

### Metronome Jitter (> 0ms)

- Verify high-precision timer implementation
- Check for blocking operations in metronome callback
- Ensure metronome runs on dedicated thread

### High CPU Usage (> 15%)

- Profile with Android Profiler
- Optimize DSP feature extraction
- Reduce UI update frequency
- Check for unnecessary background work

### High Stream Overhead (> 5ms)

- Minimize data copying between Rust and Dart
- Optimize FFI bridge code
- Check StreamController configuration
- Reduce broadcast channel buffer size if needed

## Continuous Performance Monitoring

For ongoing performance validation:

1. **Add to CI/CD Pipeline**
   ```bash
   # In GitHub Actions or similar
   - name: Performance Validation
     run: |
       python3 tools/performance_validation.py --device $DEVICE_ID
       # Upload results as artifact
   ```

2. **Regular Testing Schedule**
   - Run validation before each release
   - Test on multiple device models
   - Test on minimum and recommended hardware

3. **Performance Regression Testing**
   - Compare results against baseline
   - Alert on performance degradation
   - Track metrics over time

## References

- [Requirements Document](../.spec-workflow/specs/remaining-uat-readiness/requirements.md) - Performance requirements
- [Design Document](../.spec-workflow/specs/remaining-uat-readiness/design.md) - Architecture and performance considerations
- [UAT Test Guide](../../guides/qa/UAT_TEST_GUIDE.md) - User acceptance testing procedures
