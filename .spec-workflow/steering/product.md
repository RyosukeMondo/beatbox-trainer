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

### Core Training Features ✅ IMPLEMENTED
1. **Sample-Accurate Metronome**: Oboe-generated metronome clicks with zero jitter, ensuring stable BPM grid for precise timing measurement
2. **Real-Time Sound Classification**: Heuristic DSP-based detection distinguishes between kick, snare, and hi-hat sounds using spectral features (centroid, ZCR, flatness, rolloff)
3. **Timing Quantization**: Measures user input against metronome grid with millisecond precision, providing "on-time", "early", or "late" feedback
4. **User Calibration System**: Initial calibration phase adapts classification thresholds to individual voice characteristics and microphone response
5. **Progressive Difficulty Levels**:
   - Level 1: Broad categories (kick, snare, hi-hat) using simple features
   - Level 2: Strict subcategories (closed vs open hi-hat, kick vs K-snare) using advanced features and temporal envelope analysis

### User Experience Features ✅ IMPLEMENTED
6. **Onboarding Flow**: Guided first-launch experience introducing app features and calibration process
7. **Settings Management**: Persistent user preferences via settings service with import/export capability
8. **Error Handling**: User-friendly error messages with graceful degradation
9. **BPM Control**: Adjustable tempo with real-time feedback

### Developer & Diagnostic Features ✅ IMPLEMENTED
10. **Debug Lab**: Comprehensive diagnostic screen for development and troubleshooting
    - Real-time telemetry charts showing audio metrics
    - Parameter slider controls for threshold adjustment
    - Debug log viewer with filtering
    - Anomaly detection and alerts
11. **Test Fixture System**: Reproducible audio test scenarios for development
    - Fixture manifest parsing
    - Fixture playback engine
    - Validation utilities
12. **HTTP Debug Server**: REST API for diagnostics (debug builds only)
    - Metrics endpoints
    - State inspection
    - Remote debugging support
13. **CLI Diagnostics Tools**: Command-line utilities for testing
    - `beatbox_cli`: Main CLI interface
    - `bbt_diag`: Telemetry and validation tools
14. **Telemetry System**: Structured metrics collection for performance analysis

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
- **Test Coverage**: Target 80% for both Dart and Rust code

## Product Principles

1. **Uncompromising Real-Time Performance**: Every architectural decision prioritizes deterministic, low-latency execution. No garbage collection, no locks, no blocking operations in the audio path. Performance is never sacrificed for convenience.

2. **Transparency Over Black Boxes**: Heuristic DSP models are interpretable, debuggable, and user-calibratable. Users understand what features are being measured (brightness, noisiness, attack/decay) rather than trusting opaque ML predictions.

3. **Native-First Architecture**: The 5-layer stack (C++ Oboe → Rust → flutter_rust_bridge → Dart Services → Dart UI) is intentional. High-level Dart audio plugins are explicitly avoided to maintain control over the real-time audio thread and eliminate bridging overhead.

4. **Progressive Complexity**: Start simple (broad categories with 2 features) and add complexity only when users request it (subcategories with 5+ features). This keeps the initial experience fast and reliable while supporting advanced users.

5. **User Adaptation, Not Universal Models**: Fixed thresholds fail. The calibration phase makes the system robust to individual differences in voice, technique, and hardware without requiring dataset collection or model retraining.

6. **Testability First**: Every component is designed for testability. Service interfaces enable mocking, dependency injection enables isolation, and comprehensive test fixtures ensure reliability.

## App Screens

### Production Screens
| Screen | Purpose | Status |
|--------|---------|--------|
| **Splash Screen** | App initialization and loading | ✅ Implemented |
| **Onboarding Screen** | First-launch user guidance | ✅ Implemented |
| **Training Screen** | Main training interface with classification and timing feedback | ✅ Implemented |
| **Calibration Screen** | User calibration workflow for threshold tuning | ✅ Implemented |
| **Settings Screen** | User preferences and app configuration | ✅ Implemented |

### Developer Screens
| Screen | Purpose | Status |
|--------|---------|--------|
| **Debug Lab Screen** | Comprehensive diagnostic dashboard | ✅ Implemented |

## Monitoring & Visibility

- **Dashboard Type**: Mobile UI (Flutter) with real-time visual feedback
- **Real-time Updates**: Rust → Dart stream via flutter_rust_bridge for immediate classification results
- **Key Metrics Displayed**:
  - Current sound detected (KICK, SNARE, HI-HAT)
  - Timing feedback (ON-TIME, EARLY, LATE) with millisecond error value
  - Current BPM setting
  - Calibration status per sound category
- **Debug Lab Metrics** (developer mode):
  - Audio buffer levels
  - Onset detection events
  - Feature extraction values
  - Classification confidence
  - Telemetry charts
  - Anomaly alerts
- **Sharing Capabilities**: Log export for diagnostics, calibration profile export/import

## Developer Experience

### Testing Infrastructure
- **Unit Tests**: 40+ Dart test files, Rust tests alongside implementation
- **Integration Tests**: Cross-layer workflow validation
- **Test Fixtures**: Pre-recorded audio scenarios for reproducible testing
- **Mock Services**: Full service interface mocking for isolated testing
- **Widget Tests**: Comprehensive UI component testing

### Debugging Tools
- **Debug Lab**: Visual diagnostics with charts and controls
- **HTTP Debug Server**: REST API for remote inspection
- **CLI Tools**: Command-line diagnostics and validation
- **Telemetry Streams**: Real-time metrics streaming
- **Log Export**: Structured log export for analysis

### Development Workflow
- **Desktop Stub**: UI development without Android device
- **Hot Reload**: Rapid UI iteration
- **Pre-commit Hooks**: Automated quality checks
- **Service Layer**: Clean separation for testing

## Future Vision

### Phase 2 Enhancements (Planned)
- **Background Operation**: Wake lock and audio focus management for screen-off practice
- **Extended Sound Library**: Additional beatbox sounds (rim shot, cymbal, tom variations)
- **Tempo Ramping**: Lock-free command queue for dynamic BPM changes
- **Analytics Dashboard**: Historical accuracy trends and progress tracking

### Phase 3 Enhancements (Future)
- **Remote Access**: WebSocket-based dashboard for desktop monitoring and practice session review
- **User-Defined Sounds**: Custom sound categories via template matching
- **Community Features**:
  - Share calibration profiles between devices
  - Community-submitted heuristic rule improvements
  - Voice profile presets (e.g., "deep male voice", "high female voice")
- **Advanced Analytics**:
  - Weak spot identification (e.g., "snare detection at 140+ BPM drops to 78%")
  - Timing drift visualization
  - Progress tracking toward accuracy targets
- **Practice Session Recording**: Playback and review of training sessions
- **Adaptive Training**: AI-driven practice routines based on detected weaknesses

### Technical Debt & Improvements
- **Coverage Target**: Achieve 80% test coverage across all modules
- **Documentation**: Generate comprehensive API documentation
- **Performance Profiling**: Systematic latency optimization
- **FFT Resolution**: Zero-padding or chirp-Z transform for better bass frequency resolution

## Architecture Quality Achievements

### Resolved Issues
| Issue | Previous State | Current State |
|-------|---------------|---------------|
| Global Statics | 5 Lazy statics blocking tests | Single AppContext |
| Testability | Zero DI, untestable | Full service layer + DI |
| Error Handling | String errors, 11+ unwraps | Custom error types, zero production unwraps |
| Code Duplication | ~150 lines repeated | Extracted shared widgets |

### Quality Metrics
- **Architecture**: SOLID principles, dependency injection throughout
- **Error Handling**: Custom exceptions, user-friendly messages
- **Test Suite**: Comprehensive coverage with mocks and fixtures
- **Code Organization**: Clear layer boundaries, single responsibility
