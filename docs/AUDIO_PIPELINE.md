# Audio Analysis Pipeline

This document describes the signal flow through the beatbox trainer's audio analysis pipeline.

## Pipeline Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AUDIO PIPELINE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                   │
│  │  Microphone  │───▶│ CPAL Backend │───▶│  Audio       │                   │
│  │  (Hardware)  │    │  (Callback)  │    │  Buffer Pool │                   │
│  └──────────────┘    └──────────────┘    └──────┬───────┘                   │
│                                                  │                           │
│                                                  ▼                           │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                      ANALYSIS THREAD                                  │   │
│  ├──────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  ┌─────────┐   ┌─────────┐   ┌─────────────┐   ┌──────────────┐      │   │
│  │  │ Buffer  │──▶│   RMS   │──▶│  Noise Gate │──▶│ Onset/Level  │      │   │
│  │  │ Accum.  │   │  Calc   │   │  (2x noise) │   │  Detection   │      │   │
│  │  └─────────┘   └─────────┘   └─────────────┘   └──────┬───────┘      │   │
│  │                                                        │              │   │
│  │                                          ┌─────────────┴──────────┐   │   │
│  │                                          ▼                        ▼   │   │
│  │                              ┌──────────────────┐    ┌─────────────┐  │   │
│  │                              │ Spectral Flux    │    │ Level Cross │  │   │
│  │                              │ Onset Detection  │    │ Detection   │  │   │
│  │                              └────────┬─────────┘    └──────┬──────┘  │   │
│  │                                       │                      │        │   │
│  │                                       └──────────┬───────────┘        │   │
│  │                                                  ▼                    │   │
│  │                              ┌──────────────────────────────────┐     │   │
│  │                              │      Feature Extraction          │     │   │
│  │                              │  • Spectral Centroid             │     │   │
│  │                              │  • Zero Crossing Rate            │     │   │
│  │                              │  • RMS Energy                    │     │   │
│  │                              └────────────────┬─────────────────┘     │   │
│  │                                               │                       │   │
│  │                                               ▼                       │   │
│  │                              ┌──────────────────────────────────┐     │   │
│  │                              │        Classifier                 │     │   │
│  │                              │  • Kick:  low centroid, low ZCR  │     │   │
│  │                              │  • Snare: mid centroid           │     │   │
│  │                              │  • Hi-hat: high ZCR              │     │   │
│  │                              └────────────────┬─────────────────┘     │   │
│  │                                               │                       │   │
│  │                                               ▼                       │   │
│  │                              ┌──────────────────────────────────┐     │   │
│  │                              │         Quantizer                │     │   │
│  │                              │  • Timing to metronome grid      │     │   │
│  │                              │  • OnTime/Early/Late/Miss        │     │   │
│  │                              └────────────────┬─────────────────┘     │   │
│  │                                               │                       │   │
│  └───────────────────────────────────────────────┼───────────────────────┘   │
│                                                  │                           │
│                                                  ▼                           │
│                              ┌──────────────────────────────────┐            │
│                              │   Tokio Broadcast Channel        │            │
│                              │   ClassificationResult           │            │
│                              └────────────────┬─────────────────┘            │
│                                               │                              │
└───────────────────────────────────────────────┼──────────────────────────────┘
                                                │
                                                ▼
                              ┌──────────────────────────────────┐
                              │   Flutter UI (Dart)              │
                              │   • Training feedback            │
                              │   • Level meter                  │
                              │   • Debug overlay                │
                              └──────────────────────────────────┘
```

## Pipeline Stages

### 1. Audio Callback (AUDIO_CB)
- **Location**: `rust/src/engine/backend/cpal.rs`
- **Purpose**: Receive raw audio samples from hardware
- **Data**: PCM samples at 48kHz

### 2. Buffer Queue (BUF_QUEUE)
- **Location**: `rust/src/audio/buffer_pool.rs`
- **Purpose**: Lock-free transfer between audio and analysis threads
- **Data**: 256-sample buffers via rtrb ring buffer

### 3. Analysis Receive (ANALYSIS_RX)
- **Location**: `rust/src/analysis/mod.rs:186`
- **Purpose**: Pop buffers and accumulate to minimum size
- **Data**: Accumulated to 1024+ samples

### 4. RMS Computation (RMS)
- **Location**: `rust/src/analysis/mod.rs:220-223`
- **Formula**: `sqrt(sum(x²) / N)`
- **Output**: Audio level for gate decision

### 5. Gate Decision (GATE)
- **Location**: `rust/src/analysis/mod.rs`
- **Threshold**: `noise_floor_rms * 2.0`
- **Purpose**: Block silence/background noise

### 6. Detection (ONSET / LEVEL_X)
Two parallel detection methods:

#### Onset Detection (Spectral Flux)
- **Location**: `rust/src/analysis/onset.rs`
- **Algorithm**:
  1. 256-point FFT with 75% overlap
  2. Compute magnitude spectrum
  3. Sum positive differences from previous frame
  4. Adaptive threshold (median + offset)
  5. Peak picking

#### Level Crossing Detection
- **Location**: `rust/src/analysis/mod.rs`
- **Trigger**: RMS crosses from below to above threshold
- **Debounce**: 150ms minimum between triggers

### 7. Feature Extraction (FEATURES)
- **Location**: `rust/src/analysis/features.rs`
- **Features**:
  - **Spectral Centroid**: Brightness of sound (Hz)
  - **Zero Crossing Rate**: Noisiness (0-1)
  - **RMS**: Energy level

### 8. Classification (CLASSIFY)
- **Location**: `rust/src/analysis/classifier.rs`
- **Method**: Threshold-based decision tree
- **Classes**:
  - **Kick**: centroid < threshold, zcr < threshold
  - **Hi-hat**: zcr > threshold
  - **Snare**: centroid > threshold
  - **Unknown**: none of the above

### 9. Result Sent (RESULT_TX)
- **Location**: `rust/src/analysis/mod.rs`
- **Channel**: Tokio broadcast
- **Data**: `ClassificationResult { sound, timing, confidence, timestamp }`

## Debugging

### Enable Pipeline Tracing

Set environment variable before running:
```bash
BEATBOX_TRACE=1 flutter run -d linux
```

Or enable at runtime via FFI:
```dart
import 'package:beatbox_trainer/bridge/api.dart' as api;
api.setPipelineTracing(enabled: true);
```

### Trace Output Format
```
[TRACE]     AUDIO_CB #000001 @    123456us | samples=256 rms=0.0123
[TRACE]    BUF_QUEUE #000002 @    123500us | samples=256 queue_len=1
[TRACE]  ANALYSIS_RX #000003 @    124000us | samples=256 accumulated=512
[TRACE]          RMS #000004 @    124100us | rms=0.0456 threshold=0.0200
[TRACE]         GATE #000005 @    124150us | rms=0.0456 threshold=0.0200 PASSED
[TRACE]      LEVEL_X #000006 @    124200us | prev=0.0100 curr=0.0456 threshold=0.0200 TRIGGERED
[TRACE]     FEATURES #000007 @    124500us | centroid=1234.5Hz zcr=0.123 rms=0.0456
[TRACE]     CLASSIFY #000008 @    124600us | sound=Kick confidence=0.85 timing=+5.2ms
[TRACE]    RESULT_TX #000009 @    124700us | sound=Kick timestamp=1234ms
```

## Common Issues

### No Classification Despite Level Indicator Moving
- Check: Gate threshold vs actual RMS
- Check: Onset detection sensitivity
- Solution: Level-crossing detection bypasses onset detection

### False Positives on Background Noise
- Check: Noise floor calibration
- Check: Gate threshold (should be 2x noise floor RMS)
- Solution: Re-run noise floor calibration

### Wrong Classification
- Check: Spectral centroid and ZCR values in debug overlay
- Check: Calibration thresholds match your sounds
- Solution: Adjust thresholds via CalibrationDebugPanel
