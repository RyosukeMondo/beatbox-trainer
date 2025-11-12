# Product Overview

## Product Purpose
Beatbox Trainer is a real-time, precision rhythm training application for Android that provides uncompromising low-latency audio performance for beatboxing practice. The app analyzes beatbox sounds (kick, snare, hi-hat) in real-time using heuristic DSP algorithms and provides immediate feedback on timing accuracy against a sample-accurate metronome. This tool solves the fundamental problem of rhythm training where existing solutions suffer from latency, jitter, and imprecise timing feedback that makes accurate practice impossible.

## Target Users
**Primary Users**: Beatboxers and vocal percussionists at all skill levels who need precise rhythm training

**User Needs**:
- Real-time audio feedback with minimal latency (< 20ms)
- Accurate timing measurement against a stable metronome
- Sound classification without requiring machine learning models or large app sizes
- Progressive difficulty scaling as skills improve
- Transparent, calibratable system that adapts to individual voice characteristics

**Pain Points Addressed**:
- High-level audio frameworks introduce unacceptable latency and jitter
- Generic metronome apps have timing drift and instability
- ML-based approaches require large models, high CPU usage, and lack interpretability
- Fixed thresholds fail to adapt to different users' voice characteristics and microphones

## Key Features

1. **Sample-Accurate Metronome**: Oboe-generated metronome clicks with zero jitter, ensuring stable BPM grid for precise timing measurement
2. **Real-Time Sound Classification**: Heuristic DSP-based detection distinguishes between kick, snare, and hi-hat sounds using spectral features (centroid, ZCR, flatness, rolloff)
3. **Timing Quantization**: Measures user input against metronome grid with millisecond precision, providing "on-time", "early", or "late" feedback
4. **User Calibration System**: Initial calibration phase adapts classification thresholds to individual voice characteristics and microphone response
5. **Progressive Difficulty Levels**:
   - Level 1: Broad categories (kick, snare, hi-hat) using simple features
   - Level 2: Strict subcategories (closed vs open hi-hat, kick vs K-snare) using advanced features and temporal envelope analysis

## Business Objectives
- Provide the most accurate and responsive beatbox training tool on Android
- Demonstrate the viability of heuristic DSP approaches over ML for real-time rhythm applications
- Build a lightweight, interpretable system that runs efficiently on mid-range devices
- Establish a foundation for rhythm training that can be extended to other vocal percussion styles

## Success Metrics
- **Latency**: End-to-end audio latency < 20ms (target: ~10-15ms with Oboe double-buffering)
- **Timing Accuracy**: Metronome jitter = 0 samples (sample-accurate generation)
- **Classification Accuracy**: > 90% correct classification after user calibration (Level 1), > 85% for Level 2 subcategories
- **App Size**: < 50MB (no ML models, pure DSP)
- **CPU Usage**: < 15% on mid-range devices during active analysis
- **User Calibration**: < 2 minutes to complete initial setup (10 samples per sound category)

## Product Principles

1. **Uncompromising Real-Time Performance**: Every architectural decision prioritizes deterministic, low-latency execution. No garbage collection, no locks, no blocking operations in the audio path. Performance is never sacrificed for convenience.

2. **Transparency Over Black Boxes**: Heuristic DSP models are interpretable, debuggable, and user-calibratable. Users understand what features are being measured (brightness, noisiness, attack/decay) rather than trusting opaque ML predictions.

3. **Native-First Architecture**: The 4-layer stack (C++ Oboe → Rust → Java/JNI → Dart/Flutter) is intentional. High-level Dart audio plugins are explicitly avoided to maintain control over the real-time audio thread and eliminate bridging overhead.

4. **Progressive Complexity**: Start simple (broad categories with 2 features) and add complexity only when users request it (subcategories with 5+ features). This keeps the initial experience fast and reliable while supporting advanced users.

5. **User Adaptation, Not Universal Models**: Fixed thresholds fail. The calibration phase makes the system robust to individual differences in voice, technique, and hardware without requiring dataset collection or model retraining.

## Monitoring & Visibility

- **Dashboard Type**: Mobile UI (Flutter) with real-time visual feedback
- **Real-time Updates**: Rust → Dart stream via flutter_rust_bridge for immediate classification results
- **Key Metrics Displayed**:
  - Current sound detected (KICK, SNARE, HI-HAT)
  - Timing feedback (ON-TIME, EARLY, LATE) with millisecond error value
  - Current BPM setting
  - Calibration status per sound category
- **Sharing Capabilities**: Future enhancement - session statistics export (JSON/CSV)

## Future Vision

### Potential Enhancements

- **Remote Access**: WebSocket-based dashboard for desktop monitoring and practice session review
- **Analytics**:
  - Historical accuracy trends over practice sessions
  - Weak spot identification (e.g., "snare detection at 140+ BPM drops to 78%")
  - Timing drift visualization
  - Progress tracking toward accuracy targets
- **Collaboration**:
  - Practice session recording and playback
  - Share calibration profiles between devices
  - Community-submitted heuristic rule improvements
- **Extended Sound Library**:
  - Additional beatbox sounds (rim shot, cymbal, tom variations)
  - User-defined custom sound categories
  - Advanced techniques (lip rolls, scratches, throat bass)
- **Adaptive Training**:
  - AI-driven practice routines based on detected weaknesses
  - Gradually increasing BPM challenges
  - Pattern complexity progression
