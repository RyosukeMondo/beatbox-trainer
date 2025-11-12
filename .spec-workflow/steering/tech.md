# Technology Stack

## Project Type
Real-time Android mobile application with native audio processing capabilities and cross-platform UI framework.

## Core Technologies

### Primary Language(s)
- **Dart 3.x**: Flutter UI layer
- **Rust**: Real-time audio analysis engine (DSP processing, feature extraction, classification)
- **C++**: Low-latency audio I/O via Oboe library
- **Java/Kotlin**: Android integration layer (JNI bridge, MainActivity)

**Language-specific tools**:
- `cargo`: Rust package manager and build tool
- `flutter`: Dart SDK and Flutter framework tooling
- `gradle`: Android build system
- `rustc`: Rust compiler with Android NDK target support

### Key Dependencies/Libraries

**Audio I/O & Real-time Processing**:
- **oboe-rs** (v0.6+): Rust bindings for Google's C++ Oboe library - provides low-latency, full-duplex audio streams with sample-accurate timing
- **rtrb** (v0.3+): Lock-free, wait-free SPSC (Single Producer Single Consumer) ring buffer for zero-allocation audio thread communication

**DSP & Signal Processing**:
- **rustfft** (v6+): High-performance FFT implementation for spectral analysis
- **microfft** (v0.5+): Optimized real-valued FFT for onset detection (alternative to rustfft for smaller window sizes)
- **aus** or **estratto**: Spectral feature extraction (centroid, flatness, rolloff, ZCR)
- **microdsp** or **aubio-rs**: Spectral flux onset detection algorithms

**Cross-Language Bridge**:
- **flutter_rust_bridge** (v2+): Automated FFI/JNI code generation for Dart ↔ Rust communication with async Stream support
- **jni** (v0.21+): JNI bindings for Rust
- **ndk-context** (v0.1+): Android context initialization for native libraries in Flutter apps

**Android Integration**:
- **Flutter SDK** (v3.19+): Cross-platform UI framework
- **Android NDK**: Native development kit for compiling Rust/C++ to ARM/ARM64 targets

### Application Architecture

**4-Layer Native-First Stack**:

```
┌─────────────────────────────────────┐
│  Layer 4: Dart/Flutter UI           │  ← User interaction, visualization
├─────────────────────────────────────┤
│  Layer 3: flutter_rust_bridge       │  ← Type-safe FFI/JNI bridge
├─────────────────────────────────────┤
│  Layer 2: Rust Audio Engine         │  ← DSP analysis, classification, state
├─────────────────────────────────────┤
│  Layer 1: C++ Oboe (via oboe-rs)    │  ← Low-latency audio I/O
└─────────────────────────────────────┘
```

**Architectural Pattern**: Event-driven, lock-free multi-threaded pipeline

**Core Threads**:
1. **AudioThread (Real-time)**: Oboe output callback (master), drives audio I/O at hardware clock rate, generates metronome clicks, performs non-blocking microphone reads
2. **AnalysisThread (Non-real-time)**: Consumes audio data from lock-free queue, executes DSP algorithms (FFT, onset detection, feature extraction, classification)
3. **UI Thread (Flutter)**: Receives classification results via flutter_rust_bridge Stream, updates visual feedback

**Critical Design Principles**:
- **Zero allocation in audio path**: Pre-allocated buffer pool pattern with dual SPSC queues (DATA_QUEUE + POOL_QUEUE)
- **Lock-free communication**: `rtrb` ring buffers eliminate mutex contention
- **Full-duplex synchronization**: Output stream (metronome) is master, input stream (microphone) is slave to prevent drift
- **Sample-accurate timing**: Metronome generated in audio callback at frame granularity (0 jitter)

### Data Storage
- **Primary storage**: In-memory state (no persistent database in v1)
- **Caching**: Calibration thresholds stored in Rust state (per-user thresholds for centroid, ZCR, etc.)
- **Data formats**:
  - Audio: Raw f32 PCM samples (32-bit floating point)
  - Configuration: Rust structs serialized via flutter_rust_bridge
  - Calibration profiles: Future enhancement - JSON export/import

### External Integrations
- **APIs**: None (fully offline application)
- **Protocols**: JNI for Java ↔ Rust communication, FFI for Dart ↔ Rust communication
- **Authentication**: N/A (local-only app)

### Monitoring & Dashboard Technologies
- **Dashboard Framework**: Flutter (Dart) - Material Design widgets
- **Real-time Communication**: `flutter_rust_bridge` Stream from Rust → Dart (push-based, async)
- **Visualization Libraries**: Flutter CustomPainter for waveform rendering (future enhancement)
- **State Management**: StreamBuilder pattern for reactive UI updates

## Development Environment

### Build & Development Tools
- **Build System**:
  - Flutter build system (wraps Gradle for Android)
  - Cargo for Rust library compilation
  - Android NDK integration via `cargo-ndk` or manual cross-compilation
- **Package Management**:
  - `pub` (Dart/Flutter dependencies)
  - `cargo` (Rust crates)
  - `gradle` (Android dependencies)
- **Development workflow**:
  - Flutter hot reload for UI iteration
  - Rust: `cargo watch` for native library recompilation
  - `flutter_rust_bridge_codegen` for regenerating FFI bindings on API changes

### Code Quality Tools
- **Static Analysis**:
  - `dart analyze` (Dart linter)
  - `clippy` (Rust linter with strict warnings)
- **Formatting**:
  - `dart format` (automatic Dart formatting)
  - `rustfmt` (automatic Rust formatting per project style guide)
- **Testing Framework**:
  - Dart: `flutter_test` for widget and integration tests
  - Rust: `cargo test` for unit tests (DSP algorithm correctness, calibration logic)
  - Manual: Real-device audio latency profiling with audio loopback cable
- **Documentation**:
  - `dartdoc` for Dart API documentation
  - `cargo doc` for Rust module documentation

### Version Control & Collaboration
- **VCS**: Git
- **Branching Strategy**: GitHub Flow (feature branches → main)
- **Code Review Process**: Pull requests required for main branch, focus on:
  - Real-time safety (no allocations/locks in audio callbacks)
  - Numeric correctness of DSP algorithms
  - JNI initialization integrity

## Deployment & Distribution
- **Target Platform(s)**: Android 7.0+ (API level 24+), ARM64-v8a and armeabi-v7a architectures
- **Distribution Method**:
  - Google Play Store (release builds)
  - APK direct download for testing (debug/profile builds)
- **Installation Requirements**:
  - Microphone and speaker/headphone access
  - Minimum 2GB RAM (for FFT processing)
  - Android device with low-latency audio support (check via `AudioManager.getProperty(PROPERTY_OUTPUT_FRAMES_PER_BUFFER)`)
- **Update Mechanism**: Standard Google Play Store auto-update flow

## Technical Requirements & Constraints

### Performance Requirements
- **End-to-end audio latency**: < 20ms target (10-15ms achievable with Oboe double-buffering on modern devices)
- **Metronome jitter**: 0 samples (sample-accurate generation eliminates timing drift)
- **Classification latency**: < 100ms from onset detection to UI feedback
- **CPU usage**: < 15% sustained on mid-range device (Snapdragon 660-class SoC)
- **Memory footprint**: < 100MB total, < 5MB for audio buffers
- **App size**: < 50MB (no ML models, pure DSP)

**Benchmarks**:
- FFT computation (1024-point): < 2ms on ARM Cortex-A73
- Feature extraction (5 features): < 1ms
- Onset detection (256-sample window, spectral flux): < 0.5ms

### Compatibility Requirements
- **Platform Support**: Android 7.0+ (API 24+)
- **Architectures**: ARM64-v8a (primary), armeabi-v7a (fallback)
- **Dependency Versions**:
  - Flutter SDK: 3.19+
  - Rust toolchain: 1.75+ with `aarch64-linux-android` and `armv7-linux-androideabi` targets
  - Android NDK: r25c or later
- **Standards Compliance**:
  - Android Audio API best practices (Oboe recommended guidelines)
  - No reliance on deprecated AudioTrack/AudioRecord APIs

### Security & Compliance
- **Security Requirements**:
  - Microphone permission requested at runtime (Android 6.0+ permission model)
  - No network access required or requested
  - No data collection or telemetry
- **Compliance Standards**: N/A (single-user, offline, non-commercial training tool)
- **Threat Model**:
  - Low-risk surface (no network, no persistent storage, no user data)
  - Memory safety via Rust (prevents buffer overflows in DSP code)

### Scalability & Reliability
- **Expected Load**: Single user per device, no concurrent sessions
- **Availability Requirements**: Offline-first (100% availability with no network dependency)
- **Growth Projections**:
  - Phase 1: Support 3 sound categories (kick, snare, hi-hat)
  - Phase 2: Extend to 8+ categories (rim shot, cymbal, throat bass, etc.)
  - Phase 3: User-defined custom sounds via template matching

## Technical Decisions & Rationale

### Decision Log

1. **Native-First Stack (C++ Oboe → Rust → Java → Dart) over High-Level Plugins**:
   - **Rationale**: High-level Dart audio plugins (e.g., `flutter_sound`, `just_audio`) introduce unacceptable latency (50-200ms) and jitter due to:
     - Garbage collection pauses in Dart VM
     - Channel bridging overhead (platform channels add 10-30ms latency)
     - Inability to control buffer sizes and audio thread priority
   - **Trade-offs**: Increased complexity (4-layer stack, manual JNI/FFI setup) in exchange for deterministic real-time performance
   - **Validation**: Oboe documentation confirms < 20ms latency achievable only via native APIs

2. **Heuristic DSP over Machine Learning for Sound Classification**:
   - **Rationale**:
     - **Interpretability**: Users understand "brightness" (spectral centroid) and "noisiness" (ZCR) as tangible concepts vs. black-box ML predictions
     - **Calibration**: Threshold-based rules adapt to individual users via simple 2-minute calibration (10 samples per category)
     - **Resource efficiency**: No model loading, no inference overhead, < 5MB code footprint
     - **Progressive difficulty**: Rule complexity scales programmatically (Level 1: 2 features, Level 2: 5+ features) without retraining
   - **Trade-offs**: Lower initial accuracy for uncalibrated users, manual feature engineering required
   - **Alternatives considered**: TensorFlow Lite (rejected due to 20-50MB model size, 20ms inference latency, lack of interpretability)

3. **Lock-Free SPSC Queues (rtrb) over Mutexes**:
   - **Rationale**: Audio callbacks execute in high-priority real-time thread - any blocking (mutex contention) causes audible glitches ("xruns")
   - **Implementation**: Dual-queue "object pool" pattern with pre-allocated buffers eliminates heap allocations in audio path
   - **Trade-offs**: More complex buffer lifecycle management vs. guaranteed deterministic execution time
   - **Validation**: Real-time audio literature universally mandates lock-free communication for audio threads

4. **Full-Duplex Master-Slave Synchronization over Independent Streams**:
   - **Rationale**: Independent input/output streams drift apart due to different hardware clocks, making timing quantization impossible
   - **Implementation**: Output stream (metronome) is master, input stream (microphone) reads are triggered from output callback
   - **Trade-offs**: Slightly more complex initialization logic vs. eliminating unbounded clock drift
   - **Source**: Oboe team's FullDuplexStream pattern (recommended best practice)

5. **Multi-Resolution STFT Strategy over Single FFT Window Size**:
   - **Rationale**: Time-frequency uncertainty principle - optimal onset detection requires small windows (256 samples), optimal classification requires large windows (1024 samples)
   - **Implementation**:
     - Pipeline 1 (continuous): 256-sample FFT for spectral flux onset detection
     - Pipeline 2 (event-triggered): 1024-sample FFT for feature extraction at detected onsets
   - **Trade-offs**: Dual FFT computation increases CPU usage by ~30% vs. achieving both accurate timing and accurate classification
   - **Alternatives rejected**: Single 512-sample compromise window results in "blurred" onsets and "blurred" spectral features

6. **Sample-Accurate Metronome over Dart Timer.periodic**:
   - **Rationale**: Dart/Flutter timers exhibit 50-100ms jitter (documented in `Timer` API and `audioPlayers` plugin issues), making rhythm training impossible
   - **Implementation**: Metronome clicks synthesized directly in Oboe output callback using modulo arithmetic on frame counter
   - **Trade-offs**: Zero jitter vs. slightly more complex audio generation logic
   - **Validation**: Sample-accurate generation eliminates all timing measurement ambiguity

7. **Manual JNI_OnLoad Implementation over Automatic Initialization**:
   - **Rationale**: Flutter apps load native libraries via Dart FFI, not via Java `System.loadLibrary()`, causing `ndk_context` to remain uninitialized
   - **Implementation**: Manual `System.loadLibrary()` in Kotlin `MainActivity.init` block + explicit `JNI_OnLoad` function in Rust
   - **Trade-offs**: 30 lines of boilerplate code vs. preventing "android context was not initialized" crash on app launch
   - **Source**: Critical undocumented requirement for using oboe-rs within Flutter (discovered via community forums)

## Known Limitations

- **Single-user calibration**: Calibration profiles are not shareable between users - each user must complete 2-minute initial setup
  - **Impact**: Onboarding friction for new users
  - **Future solution**: Community-contributed "voice profile presets" (e.g., "deep male voice", "high female voice")

- **Device audio latency variability**: Some low-end Android devices report 40-60ms latency even with Oboe optimizations
  - **Impact**: Training effectiveness reduced on budget hardware (< $150 devices)
  - **Workaround**: Display device latency estimate in settings, recommend users test with audio loopback

- **No background operation**: Android audio focus and power management prevent training during screen-off
  - **Impact**: Users cannot practice with screen off to save battery
  - **When addressed**: Phase 2 with wake lock and audio focus management

- **Fixed BPM during session**: Changing BPM requires stopping and restarting the audio engine
  - **Impact**: Cannot practice tempo ramping (gradual BPM increase)
  - **Why it exists**: Rust audio state is immutable during active callback loop for real-time safety
  - **Future solution**: Lock-free command queue for control messages (BPM updates, start/stop)

- **FFT bin resolution constraints**: 1024-sample FFT at 48kHz = ~47Hz per bin, insufficient for distinguishing sub-bass nuances (40Hz kick vs. 60Hz kick)
  - **Impact**: Very low-frequency sounds may be misclassified
  - **Mitigation**: Calibration step accounts for individual "kick" frequency range
  - **Future enhancement**: Zero-padding or chirp-Z transform for higher frequency resolution in bass region

- **No session history persistence**: Practice statistics (accuracy over time, weak spots) reset on app restart
  - **Impact**: Users cannot track long-term progress
  - **When addressed**: Phase 3 with local SQLite database and analytics dashboard
