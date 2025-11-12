# Requirements Document

## Introduction

The Beatbox Trainer Core implements the complete real-time rhythm training system for Android. This spec encompasses the entire application from low-latency audio I/O through DSP analysis to Flutter UI feedback. The feature delivers uncompromising real-time performance (< 20ms latency, 0 jitter metronome) using a native 4-layer stack (C++ Oboe → Rust → Java/JNI → Dart/Flutter) with heuristic DSP-based sound classification.

This specification addresses the fundamental limitations of existing rhythm training tools: high latency from managed runtimes, timing drift from software timers, and inflexibility of fixed-threshold classifiers. The solution provides sample-accurate metronome generation, lock-free audio processing, and user-calibratable heuristic models that adapt to individual voice characteristics.

## Alignment with Product Vision

This feature directly implements the core product purpose defined in product.md: providing "uncompromising low-latency audio performance" and "immediate feedback on timing accuracy against a sample-accurate metronome."

**Product Principles Alignment**:
- **Uncompromising Real-Time Performance**: 4-layer native stack with lock-free communication ensures deterministic execution
- **Transparency Over Black Boxes**: Heuristic DSP features (spectral centroid, ZCR) are interpretable vs. opaque ML models
- **Native-First Architecture**: Direct Oboe integration eliminates high-level bridging overhead
- **Progressive Complexity**: Level 1 (2 features) → Level 2 (5+ features) matches product roadmap
- **User Adaptation**: Calibration system addresses "individual voice characteristics and microphone response" requirement

**Success Metrics Coverage**:
- Latency: < 20ms target via Oboe double-buffering
- Timing Accuracy: 0 jitter via sample-accurate metronome generation
- Classification Accuracy: > 90% via user calibration
- App Size: < 50MB (no ML models)
- CPU Usage: < 15% via optimized Rust DSP

## Requirements

### Requirement 1: Low-Latency Full-Duplex Audio I/O

**User Story:** As a beatboxer, I want instantaneous audio feedback with no perceivable delay, so that I can accurately train my rhythm timing without the app interfering with my sense of timing.

#### Acceptance Criteria

1. WHEN the app starts audio engine THEN the system SHALL initialize Oboe audio streams with buffer size = 2 × burst size (double-buffering strategy)
2. WHEN audio streams are initialized THEN end-to-end audio latency SHALL be < 20ms (measured from microphone input to speaker output)
3. WHEN microphone input is captured THEN the system SHALL use full-duplex master-slave synchronization (output stream as master, input reads triggered from output callback)
4. WHEN the output callback executes THEN the system SHALL perform non-blocking read from input stream to prevent clock drift
5. IF device reports burst size > 512 frames THEN the system SHALL log warning and proceed with reported values (no hardcoded assumptions)

### Requirement 2: Sample-Accurate Metronome Generation

**User Story:** As a beatboxer practicing rhythm, I want a metronome with zero timing jitter, so that timing feedback is always accurate and the metronome never "speeds up" or "slows down" unpredictably.

#### Acceptance Criteria

1. WHEN BPM is set to N THEN the system SHALL compute samples_per_beat = (sample_rate × 60) / N
2. WHEN audio output callback executes THEN the system SHALL increment frame_counter by buffer_size
3. WHEN frame_counter % samples_per_beat == 0 THEN the system SHALL generate metronome click sound (20ms white noise burst or 1kHz sine wave)
4. WHEN metronome click is generated THEN the system SHALL mix click samples into output buffer (addition, not replacement)
5. WHEN metronome runs for 60 seconds at 120 BPM THEN measured jitter SHALL be 0 samples (sample-accurate timing)
6. IF BPM changes during session THEN the system SHALL require audio engine restart (no hot-swapping to maintain real-time safety)

### Requirement 3: Lock-Free Real-Time Audio Thread

**User Story:** As a developer maintaining real-time audio code, I want absolute guarantees that the audio thread never blocks, so that audio glitches ("xruns") never occur regardless of system load.

#### Acceptance Criteria

1. WHEN audio input callback (on_audio_ready) executes THEN the system SHALL NOT perform heap allocations (no Vec::push(), Box::new(), String::from())
2. WHEN audio callback executes THEN the system SHALL NOT acquire locks (no Mutex::lock(), RwLock::write(), Arc::clone() with atomic contention)
3. WHEN audio callback executes THEN the system SHALL NOT perform blocking I/O (no println!, file operations, network calls in release builds)
4. WHEN audio data needs processing THEN the system SHALL use SPSC (Single Producer Single Consumer) ring buffer (rtrb crate) for lock-free communication with analysis thread
5. WHEN audio buffer is full THEN the system SHALL retrieve pre-allocated buffer from POOL_QUEUE (object pool pattern)
6. WHEN audio data is copied THEN the system SHALL use copy_from_slice() (zero allocations)
7. WHEN filled buffer is ready THEN the system SHALL push to DATA_QUEUE via non-blocking push() (drop frames if queue is full - no blocking)
8. IF any allocation/lock violation is detected THEN code review SHALL reject the change (enforced via manual inspection)

### Requirement 4: JNI Initialization for Flutter + Oboe Integration

**User Story:** As an Android developer integrating Rust audio code with Flutter, I want the native library to initialize correctly on app launch, so that oboe-rs can access Android context without crashing.

#### Acceptance Criteria

1. WHEN Flutter app starts THEN MainActivity.kt init block SHALL call System.loadLibrary("beatbox_trainer")
2. WHEN System.loadLibrary() is called THEN Android OS SHALL invoke JNI_OnLoad function in Rust library
3. WHEN JNI_OnLoad executes THEN the system SHALL call ndk_context::initialize_android_context(vm_ptr, reserved_ptr)
4. WHEN ndk_context is initialized THEN oboe-rs SHALL successfully create audio streams without "android context was not initialized" panic
5. IF initialization fails THEN the system SHALL log error with JavaVM pointer address for debugging

### Requirement 5: Real-Time Onset Detection via Spectral Flux

**User Story:** As a beatboxer making percussive sounds, I want the app to detect exactly when each sound starts, so that timing measurements are precise and not "blurred" by long analysis windows.

#### Acceptance Criteria

1. WHEN analysis thread receives audio buffer from DATA_QUEUE THEN the system SHALL compute 256-sample FFT with 75% overlap (hop size = 64 samples)
2. WHEN FFT spectrum is computed THEN the system SHALL calculate spectral flux: SF(t) = Σ max(0, |FFT(t)| - |FFT(t-1)|)
3. WHEN spectral flux signal is generated THEN the system SHALL apply adaptive thresholding: threshold(t) = median(SF[t-N:t+N]) + offset
4. WHEN spectral flux exceeds adaptive threshold THEN the system SHALL detect onset at timestamp t_onset (in total sample count since engine start)
5. WHEN onset is detected THEN the system SHALL trigger classification pipeline (Requirement 6)
6. IF no onset detected for > 5 seconds THEN the system SHALL continue monitoring (no timeout, idle state is valid)

### Requirement 6: Heuristic Sound Classification (Level 1)

**User Story:** As a beatboxer practicing basic sounds, I want the app to correctly identify kick, snare, and hi-hat sounds after calibration, so that I get accurate feedback on what sound I produced.

#### Acceptance Criteria

1. WHEN onset is detected at t_onset THEN the system SHALL extract 1024-sample window starting at t_onset
2. WHEN classification window is extracted THEN the system SHALL compute 1024-point FFT (high frequency resolution)
3. WHEN FFT is computed THEN the system SHALL calculate spectral centroid: centroid = Σ(f_i × mag_i) / Σ(mag_i)
4. WHEN FFT is computed THEN the system SHALL calculate zero-crossing rate (ZCR): ZCR = count(sign(x[n]) ≠ sign(x[n-1])) / N
5. WHEN features are extracted THEN the system SHALL apply Level 1 heuristic rules:
   - IF centroid < T_KICK_CENTROID AND zcr < T_KICK_ZCR THEN classify as KICK
   - ELSE IF centroid < T_SNARE_CENTROID THEN classify as SNARE
   - ELSE IF centroid ≥ T_SNARE_CENTROID AND zcr > T_HIHAT_ZCR THEN classify as HI-HAT
   - ELSE classify as UNKNOWN
6. WHEN classification result is determined THEN the system SHALL send BeatboxHit enum (KICK/SNARE/HIHAT/UNKNOWN) to Dart UI via flutter_rust_bridge Stream
7. IF thresholds are not calibrated THEN the system SHALL use default values (1500 Hz for kick, 4000 Hz for snare, 0.1 for kick ZCR, 0.3 for hihat ZCR)

### Requirement 7: User Calibration System

**User Story:** As a beatboxer with a unique voice and microphone, I want to calibrate the app to my specific sound characteristics, so that classification accuracy exceeds 90% regardless of my equipment or technique.

#### Acceptance Criteria

1. WHEN user starts calibration flow THEN the system SHALL prompt "Make KICK sound 10 times"
2. WHEN user produces calibration sound THEN the system SHALL detect onset and extract features (centroid, ZCR) without classifying
3. WHEN 10 samples are collected for KICK THEN the system SHALL compute mean_centroid_kick and mean_zcr_kick
4. WHEN means are computed THEN the system SHALL set T_KICK_CENTROID = mean_centroid_kick × 1.2 (20% tolerance margin)
5. WHEN KICK calibration completes THEN the system SHALL repeat process for SNARE (10 samples)
6. WHEN SNARE calibration completes THEN the system SHALL repeat process for HI-HAT (10 samples)
7. WHEN all three sounds are calibrated THEN the system SHALL save thresholds to Rust state (CalibrationState struct)
8. WHEN calibration is complete THEN the system SHALL enable training mode with calibrated thresholds
9. IF user produces sound outside expected range (e.g., centroid > 20kHz) THEN the system SHALL reject sample and request retry

### Requirement 8: Timing Quantization and Feedback

**User Story:** As a beatboxer practicing with the metronome, I want to know if my sounds are on-beat, early, or late with millisecond precision, so that I can correct my timing errors.

#### Acceptance Criteria

1. WHEN onset is detected at t_onset THEN the system SHALL compute beat_error = t_onset % samples_per_beat
2. WHEN beat_error is computed THEN the system SHALL convert to milliseconds: error_ms = (beat_error / sample_rate) × 1000
3. WHEN error_ms is computed THEN the system SHALL apply timing classification:
   - IF error_ms < 50ms THEN timing = ON_TIME
   - ELSE IF error_ms > (beat_period_ms - 50ms) THEN timing = EARLY (too close to next beat)
   - ELSE timing = LATE
4. WHEN timing is classified THEN the system SHALL send TimingFeedback (ON_TIME/EARLY/LATE, error_ms) to Dart UI via Stream
5. WHEN UI receives timing feedback THEN the system SHALL display feedback within 100ms of onset (total pipeline latency)
6. IF metronome is not running THEN the system SHALL skip timing quantization (calibration mode)

### Requirement 9: Flutter UI Feedback Display

**User Story:** As a beatboxer using the app, I want to see real-time visual feedback showing the detected sound and timing accuracy, so that I can immediately adjust my technique.

#### Acceptance Criteria

1. WHEN app launches THEN UI SHALL display "Calibrate" button and "Start Training" button (disabled until calibrated)
2. WHEN user taps "Calibrate" THEN UI SHALL show calibration flow screen with instructions ("Make KICK sound 10 times")
3. WHEN Rust sends classification result via Stream THEN UI SHALL update sound indicator widget to show "KICK", "SNARE", or "HI-HAT" with color coding (red, blue, green)
4. WHEN Rust sends timing feedback via Stream THEN UI SHALL update timing indicator to show "ON-TIME" (green), "EARLY" (yellow), or "LATE" (yellow) with error value in milliseconds
5. WHEN user adjusts BPM slider THEN UI SHALL call rust_api.set_bpm(value) and display new BPM value
6. WHEN "Start Training" is tapped THEN UI SHALL call rust_api.start_audio() and display "Stop" button
7. WHEN "Stop" is tapped THEN UI SHALL call rust_api.stop_audio() and reset feedback indicators
8. IF audio engine fails to start THEN UI SHALL display error toast with message from Rust error Result

### Requirement 10: Progressive Difficulty - Level 2 (Future Extension)

**User Story:** As an advanced beatboxer, I want stricter sound classification that distinguishes between closed/open hi-hats and kick/K-snare, so that I can practice more complex beatbox patterns.

#### Acceptance Criteria

1. WHEN user enables Level 2 difficulty THEN the system SHALL add 3 additional features: spectral flatness, spectral rolloff, temporal envelope decay time
2. WHEN classifying hi-hat sounds THEN the system SHALL apply envelope analysis:
   - IF decay_time < 50ms THEN classify as CLOSED_HIHAT
   - ELSE IF decay_time > 150ms THEN classify as OPEN_HIHAT
3. WHEN classifying kick-like sounds THEN the system SHALL apply flatness check:
   - IF flatness < 0.1 (tonal) THEN classify as KICK
   - ELSE IF flatness > 0.3 (noisy) THEN classify as K_SNARE (kick+snare hybrid)
4. WHEN Level 2 is active THEN calibration SHALL require 10 samples per subcategory (total 50 samples: KICK, SNARE, CLOSED_HIHAT, OPEN_HIHAT, K_SNARE)
5. WHEN Level 2 classification completes THEN the system SHALL achieve > 85% accuracy (lower than Level 1 due to increased difficulty)

## Non-Functional Requirements

### Code Architecture and Modularity

- **Single Responsibility Principle**:
  - `audio/engine.rs`: Audio I/O only (no DSP logic)
  - `analysis/onset.rs`: Onset detection only (no classification)
  - `analysis/classifier.rs`: Classification only (no quantization)
  - `calibration/state.rs`: Threshold storage only (no measurement logic)

- **Modular Design**:
  - Rust audio engine is independent module (no Flutter dependencies)
  - DSP algorithms are pure functions (no side effects, fully testable)
  - flutter_rust_bridge provides clean layer boundary (no manual JNI in UI code)

- **Dependency Management**:
  - Audio layer → Analysis layer (one-way, analysis never calls audio)
  - Analysis layer → Calibration layer (one-way, calibration is read-only during training)
  - No circular dependencies between modules

- **Clear Interfaces**:
  - Public Rust API in `api.rs` (annotated with #[flutter_rust_bridge::frb])
  - All internal modules are `pub(crate)` or private
  - Dart models mirror Rust types (ClassificationResult, TimingFeedback)

### Performance

- **Audio Latency**: End-to-end latency < 20ms (target 10-15ms on modern devices)
- **CPU Usage**: < 15% sustained on mid-range SoC (Snapdragon 660-class) during active training
- **Memory Footprint**:
  - Total app memory < 100MB
  - Audio buffer pool: Pre-allocate 16 buffers × 2048 samples × 4 bytes = 128KB
  - FFT scratch buffers: < 20KB per analysis thread
- **Onset Detection Latency**: < 10ms from microphone input to onset timestamp
- **Classification Latency**: < 20ms from onset detection to UI feedback
- **Metronome Jitter**: 0 samples (sample-accurate generation, no drift over 60 seconds)
- **Startup Time**: Audio engine initialization < 500ms
- **Calibration Time**: Complete 3-sound calibration in < 2 minutes (30 samples at ~4 seconds per sound)

### Security

- **Permissions**:
  - Request RECORD_AUDIO permission at runtime (Android 6.0+ model)
  - No network permissions required (fully offline app)
  - No storage permissions (no data persistence in v1)
- **Data Privacy**:
  - No telemetry or analytics collection
  - No audio data leaves the device
  - Calibration thresholds stored in memory only (reset on app restart)
- **Memory Safety**: Rust ownership system prevents buffer overflows in DSP code
- **Input Validation**:
  - BPM clamped to range [40, 240]
  - Calibration samples rejected if centroid > 20kHz (invalid input)

### Reliability

- **Audio Thread Stability**:
  - No panics allowed in audio callbacks (use Result with graceful degradation)
  - IF DATA_QUEUE is full THEN drop frames (log warning, never block)
  - IF POOL_QUEUE is empty THEN drop frames (indicates processing bottleneck)
- **Error Recovery**:
  - IF Oboe stream disconnects THEN attempt reconnect (1 retry with 500ms delay)
  - IF FFT fails THEN skip analysis for current frame (log error, continue)
  - IF flutter_rust_bridge Stream breaks THEN restart Rust -> Dart communication
- **State Consistency**:
  - Calibration state is atomic (all thresholds updated together, no partial calibration)
  - Audio engine state machine prevents invalid transitions (e.g., cannot calibrate while training)
- **Device Compatibility**:
  - Support Android 7.0+ (API level 24+)
  - Degrade gracefully on low-end devices (warn if buffer size > 512 frames, but proceed)
  - Test on 3+ device tiers: flagship (< 5ms latency), mid-range (10-15ms), budget (15-20ms)

### Usability

- **Calibration UX**:
  - Clear visual instructions ("Make KICK sound 10 times")
  - Progress indicator showing N/10 samples collected
  - Audio playback of example sound (optional enhancement)
  - "Retry calibration" button if results are unsatisfactory
- **Real-Time Feedback**:
  - Sound classification displayed within 100ms of detection
  - Color-coded feedback (green = on-time, yellow = early/late, red = unknown sound)
  - Numeric timing error displayed in milliseconds (e.g., "+12ms LATE")
- **BPM Control**:
  - Slider range: 40-240 BPM (covers all practical training speeds)
  - BPM presets: 60, 80, 100, 120, 140, 160 (one-tap selection)
  - Current BPM always visible during training
- **Error Messages**:
  - User-friendly errors (no stack traces in UI)
  - "Microphone permission denied" → "Enable microphone access in Settings"
  - "Audio engine failed to start" → "Close other audio apps and try again"
  - "Device latency too high (45ms)" → "Your device may not support low-latency audio"
