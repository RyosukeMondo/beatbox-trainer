# Tasks Document

## Phase 1: Project Setup and Infrastructure

- [x] 1.1. Initialize Rust audio library with Cargo configuration
  - Files: `rust/Cargo.toml`, `rust/src/lib.rs`
  - Create Rust library crate with Android NDK targets (aarch64-linux-android, armv7-linux-androideabi)
  - Add dependencies: oboe-rs, rtrb, rustfft, jni, ndk-context
  - Configure crate-type as cdylib for JNI integration
  - _Leverage: Cargo.toml best practices for Android NDK compilation_
  - _Requirements: Req 1 (Audio I/O), Req 4 (JNI Integration)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust developer specializing in Android NDK integration | Task: Initialize Rust audio library crate with proper Android NDK configuration in rust/Cargo.toml and rust/src/lib.rs, adding all required dependencies (oboe-rs v0.6+, rtrb v0.3+, rustfft v6+, jni v0.21+, ndk-context v0.1+) following requirements 1 and 4 from requirements.md and design patterns from design.md | Restrictions: Must configure crate-type = ["cdylib"] for JNI, do not add unnecessary dependencies, ensure Android NDK targets are properly specified (aarch64-linux-android, armv7-linux-androideabi) | Leverage: Standard Cargo.toml patterns for Android libraries, oboe-rs documentation for audio dependencies | Success: Cargo.toml compiles for Android targets, all dependencies resolve correctly, lib.rs contains basic crate structure with proper module declarations, crate builds successfully with cargo build --target aarch64-linux-android | Instructions: After completing this task, mark task 1.1 as in progress [-] in tasks.md before starting, then use log-implementation tool to record implementation details with artifacts (list all crates added with versions, file structure created), then mark as complete [x] in tasks.md_

- [x] 1.2. Implement JNI_OnLoad initialization function
  - Files: `rust/src/lib.rs`
  - Implement JNI_OnLoad function that initializes ndk_context for Oboe integration
  - Use #[cfg(target_os = "android")] conditional compilation
  - Call ndk_context::initialize_android_context() with JavaVM pointer
  - _Leverage: ndk-context crate API, JNI initialization patterns_
  - _Requirements: Req 4 (JNI Initialization)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Android native developer with Rust/JNI expertise | Task: Implement JNI_OnLoad function in rust/src/lib.rs following requirement 4, using jni and ndk-context crates to properly initialize Android context for oboe-rs as specified in design.md Component 1 (AudioEngine) | Restrictions: Must use #[cfg(target_os = "android")] guard, must return JNI_VERSION_1_6, do not perform blocking operations in JNI_OnLoad, ensure unsafe code is properly documented | Leverage: JNI_OnLoad signature from jni crate docs, ndk_context::initialize_android_context API | Success: JNI_OnLoad function compiles without errors, unsafe blocks are properly justified, function returns correct JNI version, initialization prevents "android context was not initialized" panic | Instructions: Mark task 1.2 as in progress [-] before starting, use log-implementation tool with artifacts (functions created with signatures, safety invariants documented), mark as complete [x]_

- [x] 1.3. Configure MainActivity.kt with System.loadLibrary() call
  - Files: `android/app/src/main/kotlin/com/ryosukemondo/beatbox_trainer/MainActivity.kt`
  - Add init block to MainActivity that calls System.loadLibrary("beatbox_trainer")
  - Ensure library name matches Cargo.toml crate name
  - _Leverage: Android Kotlin Activity lifecycle, System class API_
  - _Requirements: Req 4 (JNI Initialization)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Android Kotlin developer | Task: Modify MainActivity.kt to add System.loadLibrary() init block following requirement 4 design from design.md, ensuring native library loads before Flutter initialization | Restrictions: init block must execute before any Rust function calls, library name must exactly match Cargo.toml [package] name, do not modify existing Flutter integration code | Leverage: Kotlin init block syntax, FlutterActivity base class patterns | Success: MainActivity compiles, init block calls System.loadLibrary("beatbox_trainer") correctly, app launches without "UnsatisfiedLinkError" | Instructions: Mark task 1.3 as in progress [-], use log-implementation tool with artifacts (Kotlin code added to MainActivity with line numbers), mark as complete [x]_

- [x] 1.4. Setup flutter_rust_bridge code generation
  - Files: `lib/bridge/api.dart`, `rust/src/api.rs`, `build.rs` (create), `pubspec.yaml`
  - Install flutter_rust_bridge_codegen as dev dependency
  - Create api.rs with #[flutter_rust_bridge::frb] annotated functions
  - Configure build.rs to run codegen automatically
  - Add flutter_rust_bridge package to pubspec.yaml
  - _Leverage: flutter_rust_bridge documentation, code generation workflows_
  - _Requirements: Req 9 (Flutter UI), Layer 3 (Bridge)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter/Rust integration specialist | Task: Setup flutter_rust_bridge code generation following Layer 3 design from design.md and requirement 9, creating api.rs with stub functions and configuring automated codegen in build.rs | Restrictions: Must use flutter_rust_bridge v2+, do not manually write FFI bindings, ensure codegen runs before each build, API functions must return Result types for error handling | Leverage: flutter_rust_bridge getting started guide, example build.rs configurations | Success: Running flutter_rust_bridge_codegen generates lib/bridge/api.dart and Rust FFI glue code, Flutter app can import and call stub Rust functions, codegen integrates with flutter build process | Instructions: Mark task 1.4 as in progress [-], use log-implementation tool with artifacts (build system configuration, codegen commands, example API function signatures), mark as complete [x]_

## Phase 2: Core Audio Engine (Rust)

- [x] 2.1. Implement BufferPool with dual SPSC queues
  - Files: `rust/src/audio/mod.rs`, `rust/src/audio/buffer_pool.rs`
  - Create BufferPool struct using rtrb::RingBuffer for DATA_QUEUE and POOL_QUEUE
  - Implement split() method that returns producers/consumers for both queues
  - Pre-allocate 16 buffers of 2048 f32 samples
  - _Leverage: rtrb crate API, object pool pattern_
  - _Requirements: Req 3 (Lock-Free Audio Thread)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Real-time audio systems engineer with Rust expertise | Task: Implement BufferPool struct in rust/src/audio/buffer_pool.rs following design.md Component 2 and requirement 3, using rtrb::RingBuffer to create lock-free dual-queue object pool pattern with pre-allocated f32 Vec buffers | Restrictions: All allocations must happen in new(), no heap allocations in push/pop operations, buffer count and size must be configurable constants, split() must transfer ownership cleanly | Leverage: rtrb::RingBuffer::new() API, Rust ownership rules for Send + Sync types | Success: BufferPool::new(16, 2048) creates and pre-fills pool with 16 buffers, split() returns (data_prod, data_cons), (pool_prod, pool_cons) with correct types, all operations are Send + Sync, compiles without unsafe code | Instructions: Mark task 2.1 as in progress [-], use log-implementation tool with artifacts (struct definition, method signatures, buffer allocation strategy, thread safety guarantees), mark as complete [x]_

- [x] 2.2. Implement Metronome click generation logic
  - Files: `rust/src/audio/metronome.rs`
  - Create function generate_click_sample() that returns 20ms white noise burst or 1kHz sine wave
  - Implement BPM-to-samples_per_beat conversion: (sample_rate × 60) / BPM
  - Add function to check if current frame is on beat: frame_counter % samples_per_beat == 0
  - _Leverage: DSP basics for sine wave generation and white noise_
  - _Requirements: Req 2 (Sample-Accurate Metronome)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Audio DSP engineer | Task: Implement metronome click generation in rust/src/audio/metronome.rs following design.md Component 1 and requirement 2, creating deterministic click samples and BPM timing functions | Restrictions: All functions must be pure (no side effects), click generation must be deterministic (same seed = same noise), no allocations in timing check functions, use f32 for audio samples | Leverage: Standard sine wave formula: sin(2π * frequency * sample_index / sample_rate), white noise from rand crate with fixed seed | Success: generate_click_sample(sample_rate) returns Vec<f32> of exactly 20ms duration, is_on_beat(frame_counter, bpm, sample_rate) returns true at exact beat boundaries with 0 sample error, samples_per_beat calculation matches design formula | Instructions: Mark task 2.2 as in progress [-], use log-implementation tool with artifacts (function signatures, DSP formulas implemented, click sample properties), mark as complete [x]_

- [x] 2.3. Implement AudioEngine struct with Oboe integration
  - Files: `rust/src/audio/engine.rs`
  - Create AudioEngine struct with oboe-rs AudioStreamAsync<Output> and AudioStreamAsync<Input>
  - Implement AudioOutputCallback trait with on_audio_ready method
  - Use FullDuplexStream master-slave pattern: output callback triggers non-blocking input reads
  - Store frame_counter (AtomicU64) and bpm (AtomicU32) for metronome timing
  - Integrate BufferPool for lock-free data transfer
  - _Leverage: oboe-rs examples, FullDuplexStream documentation_
  - _Requirements: Req 1 (Audio I/O), Req 2 (Metronome), Req 3 (Lock-Free)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Senior Rust audio developer with real-time systems expertise | Task: Implement AudioEngine struct in rust/src/audio/engine.rs following design.md Component 1 and requirements 1-3, integrating oboe-rs for full-duplex audio with metronome generation and lock-free buffer pool | Restrictions: on_audio_ready callback must have no heap allocations (only atomic loads, modulo arithmetic, pool_consumer.pop(), data_producer.push(), copy_from_slice()), no mutex locks, no blocking I/O, must return DataCallbackResult::Continue | Leverage: oboe::AudioStreamBuilder API, oboe::PerformanceMode::LowLatency, BufferPool from task 2.1, metronome functions from task 2.2 | Success: AudioEngine::new() initializes with specified BPM and buffer size = 2 * burst_size (double-buffering), start() successfully opens full-duplex streams, on_audio_ready generates metronome clicks with frame_counter % samples_per_beat timing and performs non-blocking input reads to buffer pool, real-time safety checklist passes (no alloc/lock/blocking), compiles with #[cfg(test)] unit tests | Instructions: Mark task 2.3 as in progress [-], use log-implementation tool with artifacts (AudioEngine struct fields, on_audio_ready implementation details, real-time safety verification checklist results), mark as complete [x]_

## Phase 3: DSP Analysis Pipeline (Rust)

- [x] 3.1. Implement OnsetDetector with spectral flux algorithm
  - Files: `rust/src/analysis/mod.rs`, `rust/src/analysis/onset.rs`
  - Create OnsetDetector struct with FftPlanner (256-sample window, 75% overlap)
  - Implement spectral flux calculation: SF(t) = Σ max(0, |FFT(t)| - |FFT(t-1)|)
  - Add adaptive thresholding: threshold(t) = median(flux[t-N:t+N]) + offset
  - Implement peak picking to detect onset timestamps
  - _Leverage: rustfft or microfft crate, standard spectral flux algorithm_
  - _Requirements: Req 5 (Onset Detection)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Music Information Retrieval (MIR) engineer with Rust DSP expertise | Task: Implement OnsetDetector in rust/src/analysis/onset.rs following design.md Component 3 and requirement 5, using rustfft for 256-sample FFT with spectral flux onset detection and adaptive thresholding | Restrictions: FFT window size must be exactly 256 samples with hop size = 64 (75% overlap), spectral flux must use only positive differences (max(0, ...)), median calculation for adaptive threshold must be efficient (use running median or approximation), process() must return Vec<u64> of onset timestamps in sample count | Leverage: rustfft::FftPlanner API, VecDeque for circular flux signal buffer, median calculation algorithms | Success: OnsetDetector::new(sample_rate) initializes with 256-point FFT planner, process(audio_buffer) detects percussive onsets with adaptive threshold, onset timestamps are accurate to within hop size (64 samples), false positive rate < 10% on test audio | Instructions: Mark task 3.1 as in progress [-], use log-implementation tool with artifacts (OnsetDetector struct, spectral flux formula, adaptive threshold logic, peak picking algorithm, unit test results), mark as complete [x]_

- [x] 3.2. Implement FeatureExtractor for DSP features
  - Files: `rust/src/analysis/features.rs`
  - Create Features struct with fields: centroid, zcr, flatness, rolloff, decay_time_ms
  - Implement FeatureExtractor with 1024-sample FFT for high frequency resolution
  - Add feature calculation functions: compute_centroid(), compute_zcr(), compute_flatness(), compute_rolloff(), compute_decay_time()
  - _Leverage: aus or estratto crate (optional), rustfft, standard MIR feature formulas_
  - _Requirements: Req 6 (Classification), Req 10 (Level 2)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Audio DSP engineer specializing in feature extraction | Task: Implement FeatureExtractor in rust/src/analysis/features.rs following design.md Component 4 and requirements 6, 10, calculating spectral centroid, ZCR, flatness, rolloff, and temporal envelope features using 1024-sample FFT for classification | Restrictions: All feature functions must be pure (no side effects), centroid must use weighted mean formula Σ(f_i × |X[i]|) / Σ|X[i]|, ZCR formula (1/N) Σ |sign(x[n]) - sign(x[n-1])|, flatness uses geometric/arithmetic mean ratio, rolloff finds 85% energy threshold frequency | Leverage: rustfft for 1024-point FFT, standard MIR textbook formulas, aus/estratto crates if available | Success: FeatureExtractor::new(sample_rate) initializes, extract(audio_window) returns Features struct with all 5 fields calculated, centroid values are in Hz range 50-20000, ZCR in range 0-1, features match expected ranges for test signals (pure tone = low ZCR, noise = high ZCR), unit tests verify formulas | Instructions: Mark task 3.2 as in progress [-], use log-implementation tool with artifacts (Features struct definition, all 5 feature calculation formulas with citations, FFT window size and rationale, unit test validation results), mark as complete [x]_

- [x] 3.3. Implement Classifier with heuristic rules
  - Files: `rust/src/analysis/classifier.rs`
  - Create BeatboxHit enum: Kick, Snare, HiHat, Unknown (+ Level 2: ClosedHiHat, OpenHiHat, KSnare)
  - Implement Classifier struct that reads CalibrationState thresholds
  - Add classify_level1() method using centroid and ZCR rules from requirements
  - Add classify_level2() method using additional features for subcategories
  - _Leverage: CalibrationState struct (task 3.5), decision tree patterns_
  - _Requirements: Req 6 (Classification), Req 10 (Level 2)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Machine learning engineer specializing in heuristic rule-based systems | Task: Implement Classifier in rust/src/analysis/classifier.rs following design.md Component 5 and requirements 6, 10, using heuristic decision rules based on calibrated thresholds for Level 1 (kick/snare/hi-hat) and Level 2 (subcategories) classification | Restrictions: classify_level1 must use only centroid and ZCR features, decision tree must follow exact logic from requirement 6 acceptance criteria, Level 2 must add flatness and decay_time checks, must use Arc<RwLock<CalibrationState>> for thread-safe threshold access (read-only), no ML models or training | Leverage: CalibrationState from task 3.5, Features from task 3.2, decision tree pattern from design.md Component 5 | Success: Classifier::new(calibration) initializes with calibration state reference, classify(features) returns BeatboxHit enum, Level 1 rules correctly classify test signals (pure low-freq tone → Kick, mid-freq → Snare, high-freq noise → HiHat), Level 2 adds subcategory distinction, classification takes < 1ms | Instructions: Mark task 3.3 as in progress [-], use log-implementation tool with artifacts (BeatboxHit enum variants, classify_level1 decision tree logic, classify_level2 enhancements, calibration threshold usage), mark as complete [x]_

- [x] 3.4. Implement Quantizer for timing feedback
  - Files: `rust/src/analysis/quantizer.rs`
  - Create TimingClassification enum: OnTime, Early, Late
  - Create TimingFeedback struct with classification and error_ms fields
  - Implement Quantizer that uses shared frame_counter and bpm from AudioEngine
  - Add quantize() method that computes beat_error and classifies timing
  - _Leverage: Atomic references from AudioEngine, timing quantization algorithms_
  - _Requirements: Req 8 (Timing Quantization)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Audio engineer specializing in rhythm quantization | Task: Implement Quantizer in rust/src/analysis/quantizer.rs following design.md Component 6 and requirement 8, calculating timing error between onset timestamps and metronome grid using shared atomic frame_counter and BPM | Restrictions: Must use Arc<AtomicU64> for frame_counter and Arc<AtomicU32> for BPM (shared with AudioEngine), beat_error calculation: onset_timestamp % samples_per_beat, tolerance_ms = 50ms for ON_TIME classification, error_ms must be signed float for display purposes | Leverage: Atomic::load(Ordering::Relaxed), samples_per_beat formula from metronome.rs, modulo arithmetic for phase calculation | Success: Quantizer::new(frame_counter, bpm, sample_rate) initializes with atomic references, quantize(onset_timestamp) returns TimingFeedback with correct classification, onset exactly on beat (error = 0) → OnTime, onset within 50ms of beat → OnTime, onset 100ms after beat → Late, onset 50ms before next beat → Early, unit tests verify all boundary conditions | Instructions: Mark task 3.4 as in progress [-], use log-implementation tool with artifacts (TimingClassification enum, TimingFeedback struct, quantize algorithm with formulas, boundary condition handling), mark as complete [x]_

- [x] 3.5. Implement CalibrationState and calibration logic
  - Files: `rust/src/calibration/mod.rs`, `rust/src/calibration/state.rs`, `rust/src/calibration/procedure.rs`
  - Create CalibrationState struct with threshold fields: t_kick_centroid, t_kick_zcr, t_snare_centroid, t_hihat_zcr, is_calibrated
  - Implement new_default() with hardcoded default thresholds
  - Implement from_samples() that computes mean + 20% margin from calibration samples
  - Create CalibrationProcedure to manage sample collection workflow
  - _Leverage: Standard statistics (mean calculation), state machine pattern_
  - _Requirements: Req 7 (Calibration System)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Software engineer with statistics and state machine expertise | Task: Implement CalibrationState and CalibrationProcedure in rust/src/calibration/ following design.md Component 7 and requirement 7, creating threshold storage and sample collection workflow for user calibration | Restrictions: Default thresholds must match design.md (t_kick_centroid = 1500Hz, t_kick_zcr = 0.1, t_snare_centroid = 4000Hz, t_hihat_zcr = 0.3), from_samples must require exactly 10 samples per sound type, threshold calculation: mean * 1.2 (20% margin), CalibrationProcedure must validate samples (reject if centroid > 20kHz or < 50Hz) | Leverage: Features struct from task 3.2, Vec::iter().sum() / len() for mean calculation, Result types for validation errors | Success: CalibrationState::new_default() returns default thresholds with is_calibrated = false, from_samples([kick], [snare], [hihat]) computes means and returns calibrated state with is_calibrated = true, CalibrationProcedure manages 3-sound workflow (30 total samples), sample validation rejects out-of-range inputs, unit tests verify mean + 20% calculation | Instructions: Mark task 3.5 as in progress [-], use log-implementation tool with artifacts (CalibrationState struct with default values, from_samples algorithm, CalibrationProcedure state machine, validation logic), mark as complete [x]_

- [x] 3.6. Implement AnalysisThread main loop
  - Files: `rust/src/analysis/mod.rs`, `rust/src/audio/engine.rs` (spawn thread)
  - Create analysis thread that consumes from DATA_QUEUE and returns buffers to POOL_QUEUE
  - Integrate OnsetDetector, FeatureExtractor, Classifier, Quantizer in processing pipeline
  - Send ClassificationResult to Dart UI via tokio channel (for flutter_rust_bridge Stream)
  - _Leverage: All analysis components from tasks 3.1-3.5, std::thread::spawn_
  - _Requirements: Req 5-8 (DSP Pipeline)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Concurrent systems engineer with Rust threading expertise | Task: Implement AnalysisThread main loop in rust/src/analysis/mod.rs following design.md thread architecture and requirements 5-8, orchestrating DSP pipeline (onset → features → classification → quantization) with lock-free queue communication | Restrictions: Thread must be spawned by AudioEngine::start(), loop must use blocking data_consumer.pop() (not audio thread), must return buffers to pool_producer after processing, panic in analysis thread must not crash audio thread, use tokio::sync::mpsc for ClassificationResult stream to Dart | Leverage: OnsetDetector from 3.1, FeatureExtractor from 3.2, Classifier from 3.3, Quantizer from 3.4, CalibrationState from 3.5, BufferPool queues from 2.1 | Success: spawn_analysis_thread(data_cons, pool_prod, calibration, frame_counter, bpm) creates analysis thread, thread continuously processes buffers from DATA_QUEUE through full pipeline, ClassificationResult (sound + timing) sent to Dart stream on each onset, buffers returned to POOL_QUEUE, thread handles errors gracefully without panicking, integration test verifies onset → classification → UI latency < 100ms | Instructions: Mark task 3.6 as in progress [-], use log-implementation tool with artifacts (thread spawn code, main loop structure, pipeline integration, error handling, channel setup for Dart stream), mark as complete [x]_

## Phase 4: Rust Public API (flutter_rust_bridge)

- [x] 4.1. Implement public API functions in api.rs
  - Files: `rust/src/api.rs`
  - Add #[flutter_rust_bridge::frb] annotated functions: start_audio(bpm), stop_audio(), set_bpm(bpm), classification_stream()
  - Implement start_calibration(sound), finish_calibration(), calibration_stream()
  - Store AudioEngine instance in static Arc<Mutex<Option<AudioEngine>>> for lifecycle management
  - _Leverage: flutter_rust_bridge attribute macros, Rust static variables, Arc/Mutex patterns_
  - _Requirements: Req 9 (Flutter UI), All functional requirements_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: API design engineer with Flutter/Rust integration expertise | Task: Implement public API in rust/src/api.rs following design.md Layer 3 and requirement 9, exposing AudioEngine and calibration functions to Dart with flutter_rust_bridge annotations and proper lifecycle management | Restrictions: All public functions must use #[flutter_rust_bridge::frb] attribute, must return Result<T, String> for error handling (String is FFI-safe), AudioEngine must be stored in static AUDIO_ENGINE: Lazy<Arc<Mutex<Option<AudioEngine>>>> for global access, classification_stream must return impl Stream<Item = ClassificationResult>, streams must use tokio channels internally | Leverage: flutter_rust_bridge v2 docs, once_cell::sync::Lazy for static initialization, tokio::sync::mpsc for Stream implementation, Arc<Mutex> for thread-safe AudioEngine access | Success: start_audio(bpm) initializes and starts AudioEngine, returns Ok() or Err(error_message), stop_audio() safely stops and drops engine, set_bpm(bpm) updates atomic BPM value, classification_stream() returns Stream that yields ClassificationResult on each onset, calibration functions manage CalibrationProcedure workflow, flutter_rust_bridge codegen produces valid Dart bindings in lib/bridge/api.dart | Instructions: Mark task 4.1 as in progress [-], use log-implementation tool with artifacts (all API function signatures with frb annotations, AudioEngine lifecycle management code, Stream setup, error handling patterns), mark as complete [x]_

- [x] 4.2. Define Dart data models matching Rust types
  - Files: `lib/models/classification_result.dart`, `lib/models/timing_feedback.dart`, `lib/models/calibration_progress.dart`
  - Create Dart classes matching Rust structs: ClassificationResult, BeatboxHit, TimingFeedback, TimingClassification
  - Add calibration models: CalibrationProgress, CalibrationSound enum
  - Ensure models match flutter_rust_bridge auto-generated types
  - _Leverage: flutter_rust_bridge type mapping, Dart class syntax_
  - _Requirements: Req 9 (Flutter UI), Data Models from design.md_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter developer with type system expertise | Task: Define Dart data models in lib/models/ following design.md data models section, creating classes that match Rust types for ClassificationResult, TimingFeedback, and CalibrationProgress | Restrictions: Models must match flutter_rust_bridge generated types exactly (check lib/bridge/api.dart after codegen), use immutable classes (final fields), add const constructors where possible, enum names must match Rust naming (camelCase in Dart vs PascalCase in Rust handled by codegen) | Leverage: flutter_rust_bridge type mappings (Result → throws Exception, Stream → Stream<T>, enums auto-convert), Dart immutable class patterns | Success: ClassificationResult has fields: BeatboxHit sound, TimingFeedback timing, int timestampMs; BeatboxHit enum has variants: kick, snare, hiHat, unknown; TimingFeedback has: TimingClassification classification, double errorMs; CalibrationProgress matches Rust struct, all models compile and match generated types | Instructions: Mark task 4.2 as in progress [-], use log-implementation tool with artifacts (all Dart class definitions, enum variants, field types, immutability patterns), mark as complete [x]_

## Phase 5: Flutter UI Implementation

- [x] 5.1. Create TrainingScreen with StreamBuilder
  - Files: `lib/ui/screens/training_screen.dart`
  - Implement StatefulWidget with start/stop training buttons
  - Add StreamBuilder listening to classification_stream() from Rust API
  - Display current BPM with Slider control
  - Show Start/Stop FloatingActionButton
  - _Leverage: Flutter Material Design widgets, StreamBuilder for reactive UI_
  - _Requirements: Req 9 (Flutter UI)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter UI developer | Task: Create TrainingScreen in lib/ui/screens/training_screen.dart following design.md Component 8 and requirement 9, building reactive UI with StreamBuilder connected to Rust classification stream | Restrictions: Use StatefulWidget for local state management, must handle stream subscription lifecycle (dispose properly), Stream must be from api.classificationStream(), BPM slider range 40-240, must show loading state before stream data arrives, handle errors from Rust API gracefully | Leverage: Flutter Scaffold, AppBar, Column layout, StreamBuilder widget, FloatingActionButton, Slider widget, Material Design patterns | Success: TrainingScreen renders with BPM slider (40-240), Start button calls api.startAudio(bpm) and switches to Stop button, StreamBuilder<ClassificationResult> updates UI on each classification event, Stop button calls api.stopAudio() and resets UI, error dialog appears if start_audio fails, screen properly disposes stream subscription | Instructions: Mark task 5.1 as in progress [-], use log-implementation tool with artifacts (StatefulWidget structure, StreamBuilder setup, button callbacks, stream lifecycle management), mark as complete [x]_

- [x] 5.2. Create ClassificationIndicator widget
  - Files: `lib/ui/widgets/classification_indicator.dart`
  - Create StatelessWidget that displays BeatboxHit enum as colored text
  - Color scheme: KICK (red), SNARE (blue), HI-HAT (green), UNKNOWN (gray)
  - Add idle state display when no stream data
  - _Leverage: Flutter Container, Text widgets, color theming_
  - _Requirements: Req 9 (Flutter UI)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter UI component developer | Task: Create ClassificationIndicator widget in lib/ui/widgets/classification_indicator.dart following design.md Component 8 and requirement 9, displaying sound classification with color-coded visual feedback | Restrictions: Must be StatelessWidget (no local state), take ClassificationResult? as parameter (nullable for idle state), use Container with BoxDecoration for colored background, text should be large and readable (style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)), color mapping must match requirements (KICK → Colors.red, SNARE → Colors.blue, HI-HAT → Colors.green, UNKNOWN → Colors.grey) | Leverage: Flutter Container, BoxDecoration, Text widget, Colors class, Theme.of(context) for text style | Success: ClassificationIndicator(result: null) displays "---" in gray (idle), ClassificationIndicator(result: kick) displays "KICK" in red container, indicator updates instantly when result changes, widget is reusable across different screens | Instructions: Mark task 5.2 as in progress [-], use log-implementation tool with artifacts (StatelessWidget structure, color mapping logic, idle state handling, text styling), mark as complete [x]_

- [x] 5.3. Create TimingFeedback widget
  - Files: `lib/ui/widgets/timing_feedback.dart`
  - Create StatelessWidget displaying TimingClassification and error_ms
  - Color scheme: ON_TIME (green), EARLY (yellow), LATE (yellow)
  - Show error value in milliseconds: "+12ms LATE", "-5ms EARLY", "0ms ON-TIME"
  - _Leverage: Flutter Text, Row widgets, string formatting_
  - _Requirements: Req 9 (Flutter UI), Req 8 (Timing Feedback)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter UI developer with UX focus | Task: Create TimingFeedback widget in lib/ui/widgets/timing_feedback.dart following design.md Component 8 and requirements 8, 9, displaying timing accuracy with millisecond precision and color-coded feedback | Restrictions: Must be StatelessWidget, take ClassificationResult? parameter (nullable), extract timing field, display error_ms with sign (+ for late, - for early, no sign for on-time), color mapping: ON_TIME → Colors.green, EARLY/LATE → Colors.amber, text format: "${error}ms ${classification}" e.g. "+12ms LATE" | Leverage: Flutter Text widget, string interpolation, Colors class, conditional color selection | Success: TimingFeedback(result: null) displays "---" (idle), TimingFeedback(result: on-time) displays "0ms ON-TIME" in green, TimingFeedback(result: late +12ms) displays "+12ms LATE" in yellow, error value rounded to 1 decimal place, widget updates immediately | Instructions: Mark task 5.3 as in progress [-], use log-implementation tool with artifacts (StatelessWidget structure, error_ms formatting logic, color mapping, null handling), mark as complete [x]_

- [x] 5.4. Create BPMControl widget
  - Files: `lib/ui/widgets/bpm_control.dart`
  - Create StatefulWidget with Slider (40-240 range) and BPM preset buttons (60, 80, 100, 120, 140, 160)
  - Call onChanged(int bpm) callback when BPM changes
  - Display current BPM value prominently
  - _Leverage: Flutter Slider, ElevatedButton, Row/Column layouts_
  - _Requirements: Req 9 (Flutter UI), Req 2 (BPM Control)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter UI developer | Task: Create BPMControl widget in lib/ui/widgets/bpm_control.dart following design.md Component 8 and requirements 2, 9, providing intuitive BPM selection with slider and preset buttons | Restrictions: Must take int currentBpm and ValueChanged<int> onChanged as parameters, Slider range: min 40, max 240, divisions: 200 (1 BPM increments), preset buttons: [60, 80, 100, 120, 140, 160], tapping preset should call onChanged, display current BPM as large text above controls | Leverage: Flutter Slider widget, ElevatedButton, Row for preset buttons, Column layout, onChanged callback pattern | Success: BPMControl displays current BPM (e.g. "120 BPM") prominently, Slider allows smooth adjustment 40-240, preset buttons set exact BPM values, onChanged callback fires immediately, widget integrates cleanly with TrainingScreen | Instructions: Mark task 5.4 as in progress [-], use log-implementation tool with artifacts (StatefulWidget structure, Slider configuration, preset button array, callback implementation), mark as complete [x]_

- [x] 5.5. Create CalibrationScreen with sample collection UI
  - Files: `lib/ui/screens/calibration_screen.dart`
  - Implement StatefulWidget managing calibration workflow (KICK → SNARE → HI-HAT)
  - Display instructions: "Make KICK sound 10 times"
  - Show progress indicator: "Sample 5/10"
  - Listen to calibration_stream() for sample collection feedback
  - Navigate back to TrainingScreen when calibration completes
  - _Leverage: Flutter Stepper or custom progress UI, api.startCalibration/finishCalibration_
  - _Requirements: Req 7 (Calibration), Req 9 (Flutter UI)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter developer with state machine expertise | Task: Create CalibrationScreen in lib/ui/screens/calibration_screen.dart following design.md Component 9 and requirements 7, 9, implementing 3-step calibration workflow with clear instructions and progress tracking | Restrictions: Must use enum CalibrationSound { kick, snare, hihat } for state, display instructions matching current sound ("Make KICK sound 10 times"), show progress N/10, call api.startCalibration(sound) on screen load, listen to api.calibrationStream() for sample acceptance, call api.finishCalibration() and Navigator.pop() when complete, handle sample rejection errors (show "Invalid sample, try again") | Leverage: StatefulWidget with CalibrationSound enum state, StreamBuilder for calibration progress, Column layout for instructions + progress, LinearProgressIndicator, ElevatedButton for restart | Success: CalibrationScreen starts with KICK instructions, progress updates 0→10 as samples collected, auto-advances to SNARE then HI-HAT, shows error message for rejected samples, calls finishCalibration and returns to TrainingScreen on completion, calibration takes < 2 minutes for 30 samples | Instructions: Mark task 5.5 as in progress [-], use log-implementation tool with artifacts (StatefulWidget with calibration state machine, instructions text, progress UI, stream handling, navigation logic), mark as complete [x]_

- [x] 5.6. Add microphone permission handling
  - Files: `lib/main.dart`, `pubspec.yaml`
  - Add permission_handler package to pubspec.yaml
  - Request RECORD_AUDIO permission before starting training
  - Show permission rationale dialog if denied
  - Open app settings if permission permanently denied
  - _Leverage: permission_handler Flutter package, Android permission system_
  - _Requirements: Req 9 (Flutter UI), NFR Security (Permissions)_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter mobile developer with Android permissions expertise | Task: Add microphone permission handling in lib/main.dart following design.md error handling section and NFR security requirements, using permission_handler package for runtime permission flow | Restrictions: Must add permission_handler to pubspec.yaml dependencies, request Permission.microphone.request() before calling api.startAudio(), handle 3 states: granted (proceed), denied (show dialog), permanentlyDenied (openAppSettings()), show clear rationale: "Microphone access needed to detect beatbox sounds", do not proceed with audio if permission denied | Leverage: permission_handler package API (Permission.microphone.request(), openAppSettings()), Flutter AlertDialog, async/await for permission result | Success: First app launch requests microphone permission with system dialog, tapping "Start Training" rechecks permission before audio start, denied permission shows custom dialog with "This app needs microphone access to detect your beatbox sounds", permanently denied opens Android settings, granted permission allows training to start normally | Instructions: Mark task 5.6 as in progress [-], use log-implementation tool with artifacts (permission_handler integration, request flow, dialog UI, settings navigation), mark as complete [x]_

## Phase 6: Integration and Testing

- [x] 6.1. Write Rust unit tests for DSP components
  - Files: `rust/src/analysis/onset.rs`, `rust/src/analysis/features.rs`, `rust/src/analysis/classifier.rs`, `rust/src/analysis/quantizer.rs`
  - Add #[cfg(test)] modules with unit tests for each DSP component
  - Test OnsetDetector with synthetic percussive signals
  - Test FeatureExtractor with pure tones (low/high freq) and noise
  - Test Classifier with known feature vectors
  - Test Quantizer with exact beat timestamps and off-beat timestamps
  - _Leverage: Rust #[test] attribute, assert! macros, synthetic audio generation_
  - _Requirements: All functional requirements, Testing Strategy from design.md_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Audio test engineer with Rust expertise | Task: Write comprehensive unit tests for DSP components in rust/src/analysis/ following design.md testing strategy, creating synthetic test signals to verify algorithm correctness | Restrictions: Tests must use #[cfg(test)] modules, generate synthetic audio (sine waves, noise, impulses) programmatically (no external files), use assert! and assert_eq! with clear failure messages, test both happy path and edge cases, each component tested in isolation (mock dependencies if needed) | Leverage: Rust test framework, f32 sine wave generation: (2π * freq * t / sr).sin(), rand crate for noise, vector operations for signal synthesis | Success: cargo test passes all tests, OnsetDetector test detects impulse with < 64 sample error, FeatureExtractor test: 100Hz sine → centroid < 500Hz, white noise → ZCR > 0.3, Classifier test: low centroid + low ZCR → Kick, Quantizer test: onset at beat boundary → OnTime (error < 1ms), test coverage > 80% for analysis module | Instructions: Mark task 6.1 as in progress [-], use log-implementation tool with artifacts (test module structure, synthetic signal generation code, all test function signatures with descriptions, test results and coverage), mark as complete [x]_

- [ ] 6.2. Write Flutter widget tests
  - Files: `test/ui/widgets/classification_indicator_test.dart`, `test/ui/widgets/timing_feedback_test.dart`, `test/ui/widgets/bpm_control_test.dart`
  - Add flutter_test tests for each widget
  - Verify widgets render correctly with test data
  - Test color mappings and text formatting
  - Test user interactions (button taps, slider changes)
  - _Leverage: flutter_test package, testWidgets function, WidgetTester_
  - _Requirements: All UI requirements, Testing Strategy from design.md_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter test engineer | Task: Write widget tests for UI components in test/ui/widgets/ following design.md testing strategy, verifying correct rendering, color mapping, and user interactions | Restrictions: Must use testWidgets() function, wrap widgets in MaterialApp for Material theming, use tester.pumpWidget(), verify with expect(find.text(...), findsOneWidget), test color with tester.widget<Container>(find.byType(Container)).decoration, test slider with tester.drag() and verify callback, do not test implementation details (only public interface) | Leverage: flutter_test package (testWidgets, expect, find, tester.pumpWidget), WidgetTester API (tap, drag, pump, pumpAndSettle) | Success: flutter test passes all tests, ClassificationIndicator test verifies KICK shows red container with "KICK" text, TimingFeedback test verifies "+12ms LATE" formatting, BPMControl test verifies slider drag updates value and calls callback, preset button test verifies tapping 120 button calls onChanged(120), null/idle state tests pass | Instructions: Mark task 6.2 as in progress [-], use log-implementation tool with artifacts (all test file names, test function descriptions, widget setup code, assertions used, test results), mark as complete [x]_

- [ ] 6.3. Manual integration testing with real device
  - Equipment: Android device with API 24+, audio loopback cable (3.5mm), DAW software (Audacity/Ableton)
  - Test 1: Audio loopback latency measurement (connect headphone to mic, measure metronome click detection)
  - Test 2: Metronome jitter measurement (record 60s @ 120 BPM, analyze inter-click intervals)
  - Test 3: Calibration accuracy test (5 testers × 100 test sounds each)
  - Test 4: Training session E2E (calibrate → train 3 mins → verify feedback accuracy)
  - Document results in test report
  - _Leverage: Real Android device, audio analysis tools, manual testing procedures_
  - _Requirements: All functional and non-functional requirements_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: QA engineer with audio testing expertise | Task: Perform manual integration tests following design.md testing strategy, measuring latency, jitter, and classification accuracy on real Android hardware with documented procedures and results | Restrictions: Must use real Android device (not emulator), must use audio loopback cable for latency test, must record metronome to WAV for jitter analysis, must recruit 5+ testers for calibration accuracy, document all test procedures and results in markdown report, include screenshots and audio recordings as evidence | Leverage: Audio loopback cable, DAW software for waveform analysis, Android audio latency test apps, statistical analysis for calibration accuracy | Success: Test report documents: (1) Measured end-to-end latency < 20ms, (2) Metronome jitter = 0 samples verified, (3) Mean calibration accuracy > 90% across testers, (4) E2E training session completes without crashes, all acceptance criteria from requirements verified, test procedures are reproducible | Instructions: Mark task 6.3 as in progress [-], use log-implementation tool with artifacts (test report markdown file with results, latency measurements, jitter analysis data, accuracy statistics, test device specifications), mark as complete [x]_

- [ ] 6.4. Build release APK and verify functionality
  - Files: `android/app/build.gradle.kts`, release configuration
  - Configure release build with ProGuard/R8 optimizations
  - Build Rust library for ARM64 and ARMv7 targets
  - Build Flutter release APK
  - Install on test device and verify all features work in release mode
  - Measure APK size (must be < 50MB)
  - _Leverage: Flutter build tools, Gradle release configuration, cargo build --release_
  - _Requirements: NFR Performance (App Size), All functional requirements_
  - _Prompt: Implement the task for spec beatbox-trainer-core, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Android release engineer | Task: Configure and build release APK following NFR performance requirements (< 50MB app size), building Rust libraries for production and optimizing Flutter release build | Restrictions: Must build Rust with cargo build --release --target aarch64-linux-android and armv7-linux-androideabi, copy .so files to android/app/src/main/jniLibs/[abi]/, configure android/app/build.gradle.kts with release signing, enable shrinkResources and minifyEnabled, test APK on real device (not emulator), verify audio latency is same as debug build | Leverage: cargo build --release for optimized Rust, flutter build apk --release, Gradle release build type, ProGuard rules for flutter_rust_bridge, Android Studio for APK analysis | Success: Release APK builds successfully, APK size < 50MB verified (analyze with flutter build apk --analyze-size), installs on test device without errors, all features work identically to debug build (calibration, training, metronome, classification, timing), audio latency remains < 20ms, no ProGuard obfuscation issues with FFI | Instructions: Mark task 6.4 as in progress [-], use log-implementation tool with artifacts (build commands used, Gradle configuration changes, APK size report, release testing results, .so files included in APK), mark as complete [x]_

## Notes

- Task order is optimized for dependency flow: infrastructure → audio → DSP → API → UI → testing
- Each task includes detailed _Prompt field for future implementation guidance
- _Leverage fields reference prior work and existing components
- _Requirements map back to requirements.md section numbers
- Atomic task scope: each task touches 1-3 files and takes 1-3 hours
- Real-time safety critical for audio tasks (2.1-2.3, 3.6)
- Integration testing (6.3) requires physical Android device and audio equipment
