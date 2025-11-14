# Tasks Document: Calibration Workflow Fix

## Phase 1: CalibrationManager Enhancement

- [x] 1.1. Add get_procedure_arc() method to CalibrationManager
  - File: `rust/src/managers/calibration_manager.rs`
  - Add public method to expose calibration procedure reference for audio engine
  - Add unit tests: test_get_procedure_arc() and test_get_procedure_arc_when_not_started()
  - _Leverage: Existing CalibrationManager structure and get_state_arc() pattern_
  - _Requirements: Design Section 3.5_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust developer with expertise in concurrency and Arc/Mutex patterns | Task: Add get_procedure_arc() method to CalibrationManager in rust/src/managers/calibration_manager.rs that returns Arc<Mutex<Option<CalibrationProcedure>>>. Follow the existing pattern from get_state_arc() method. Add two unit tests: one verifying Arc is Some when calibration started, one verifying None when not started. Reference design document Section 3.5. | Restrictions: Must follow existing patterns, must return cloned Arc (not move), must include comprehensive doc comments | _Leverage: Existing get_state_arc() method at line 138 as template_ | Success: Method compiles and returns correct Arc reference, Arc can be cloned and shared across threads, unit tests pass with 100% coverage | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (method signature, location, test cases). Then mark as completed [x] in tasks.md_

## Phase 2: Analysis Thread Modifications

- [x] 2.1. Update spawn_analysis_thread() signature
  - File: `rust/src/analysis/mod.rs`
  - Add calibration_procedure and calibration_progress_tx parameters to function signature
  - Rename calibration parameter to calibration_state for clarity
  - Update function documentation with new parameters
  - _Leverage: Existing spawn_analysis_thread() at line 73_
  - _Requirements: Design Section 3.1_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust systems programmer with async/threading expertise | Task: Modify spawn_analysis_thread() signature in rust/src/analysis/mod.rs (line 73) to add two new parameters: calibration_procedure: Arc<Mutex<Option<CalibrationProcedure>>> and calibration_progress_tx: Option<broadcast::Sender<CalibrationProgress>>. Rename existing calibration parameter to calibration_state. Update doc comments to describe new parameters. Reference design document Section 3.1. | Restrictions: Must maintain backward compatibility for existing calls (will be updated in next tasks), must compile successfully even if parameters not used yet, must include comprehensive parameter documentation | _Leverage: Existing parameter patterns with Arc and broadcast channels_ | Success: Function signature updated correctly, compiles with new parameters, documentation is clear and complete, no functional changes yet | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (function signature, parameter types, doc updates). Then mark as completed [x] in tasks.md_

- [x] 2.2. Implement calibration mode logic in analysis thread
  - File: `rust/src/analysis/mod.rs`
  - Replace onset processing loop (lines 104-146) with calibration mode check
  - Add non-blocking try_lock() for calibration state check
  - Forward features to procedure.add_sample() during calibration mode
  - Broadcast progress after successful sample addition
  - Keep existing classification mode as fallback
  - _Leverage: Existing onset detection and feature extraction at lines 101-114_
  - _Requirements: Design Section 3.2_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust audio systems programmer with real-time programming expertise | Task: Implement calibration mode logic in spawn_analysis_thread() main loop in rust/src/analysis/mod.rs (replace lines 104-146). Add code to check if calibration is active using try_lock() on calibration_procedure. If active, forward extracted features to procedure.add_sample() and broadcast CalibrationProgress. If inactive or lock fails, fall back to existing classification pipeline. Ensure non-blocking lock check for real-time safety. Reference design document Section 3.2 for complete implementation. | Restrictions: Must use try_lock() for state check to avoid blocking, must handle lock failures gracefully, must preserve existing classification logic, must log errors without panicking, must maintain real-time safety (no allocations in hot path) | _Leverage: Existing classifier and quantizer at lines 116-141_ | Success: Calibration mode correctly forwards features to procedure, progress broadcasts after each sample, classification mode works when calibration inactive, no blocking operations in analysis loop, error handling is robust | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (code sections modified, logic flow, error handling). Then mark as completed [x] in tasks.md_

- [x] 2.3. Add unit tests for analysis thread calibration mode
  - File: `rust/src/analysis/mod.rs`
  - Create test module with 5 comprehensive test cases
  - Test 1: Calibration mode forwards features to procedure
  - Test 2: Classification mode when procedure is None
  - Test 3: Invalid features rejected gracefully
  - Test 4: Progress broadcast after each sample
  - Test 5: Lock failure fallback to classification
  - Add test helper: create_test_buffer_with_onset()
  - _Leverage: Existing OnsetDetector and FeatureExtractor for test setup_
  - _Requirements: Design Section 7.1.1_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust test engineer with audio DSP testing expertise | Task: Create comprehensive test module in rust/src/analysis/mod.rs with 5 test cases covering calibration mode logic. Tests should use synthetic audio buffers with mock CalibrationProcedure and verify correct mode switching, feature forwarding, progress broadcasting, error handling, and lock failure fallback. Reference design document Section 7.1.1 for detailed test specifications and expected behavior. | Restrictions: Must achieve ≥90% coverage for modified code, must use mock/synthetic data (no real audio files), tests must run in <1 second total, must not require Android target, must be deterministic | _Leverage: OnsetDetector and FeatureExtractor for realistic test data_ | Success: All 5 test cases pass, coverage ≥90%, tests are fast (<1s), tests use synthetic data, all edge cases covered (lock failure, invalid samples, mode switching) | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (test functions created, coverage metrics, assertions verified). Then mark as completed [x] in tasks.md_

## Phase 3: AudioEngine Integration

- [x] 3.1. Update AudioEngine::start() signature
  - File: `rust/src/audio/engine.rs`
  - Modify start() method signature (line 211) to add calibration parameters
  - Rename calibration parameter to calibration_state
  - Add calibration_procedure and calibration_progress_tx parameters
  - Update function documentation
  - _Leverage: Existing start() method structure_
  - _Requirements: Design Section 3.3_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust audio engine developer | Task: Update AudioEngine::start() method signature in rust/src/audio/engine.rs (line 211) to accept calibration_procedure: Arc<Mutex<Option<CalibrationProcedure>>> and calibration_progress_tx: Option<broadcast::Sender<CalibrationProgress>>. Rename existing calibration parameter to calibration_state. Update doc comments to describe new parameters and their purpose. Reference design document Section 3.3. | Restrictions: Must maintain existing functionality, must compile successfully, must update all internal calls to spawn_analysis_thread_internal, must include comprehensive documentation | _Leverage: Existing parameter patterns from spawn_analysis_thread_ | Success: Signature updated with new parameters, compiles successfully, documentation is clear, internal method calls updated | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (method signature, parameter types, call sites updated). Then mark as completed [x] in tasks.md_

- [x] 3.2. Update spawn_analysis_thread_internal()
  - File: `rust/src/audio/engine.rs`
  - Modify spawn_analysis_thread_internal() (line 174) to accept new parameters
  - Pass calibration_procedure and calibration_progress_tx to spawn_analysis_thread()
  - Update start() method body to pass new parameters through
  - _Leverage: Existing thread spawning pattern_
  - _Requirements: Design Section 3.3_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust concurrency specialist | Task: Update spawn_analysis_thread_internal() in rust/src/audio/engine.rs (line 174) to accept and forward calibration_procedure and calibration_progress_tx parameters to spawn_analysis_thread(). Update the start() method body to pass these parameters through the call chain. Ensure all Arc references are properly cloned. Reference design document Section 3.3. | Restrictions: Must preserve existing thread spawning logic, must properly clone Arc references, must not introduce memory leaks, must maintain real-time safety guarantees | _Leverage: Existing Arc cloning patterns for frame_counter and bpm_ | Success: Parameters passed correctly through to analysis thread, no compilation errors, Arc cloning is correct, no functional changes to behavior | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (function modifications, parameter passing chain). Then mark as completed [x] in tasks.md_

- [ ] 3.3. Add unit tests for AudioEngine parameter passing
  - File: `rust/src/audio/engine.rs`
  - Add test_audio_engine_start_with_calibration_parameters() to existing test module
  - Verify AudioEngine accepts calibration parameters without error
  - Test on both Android (real) and desktop (stub) platforms
  - _Leverage: Existing AudioEngine test module at line 342_
  - _Requirements: Design Section 7.1.2_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust test engineer | Task: Add test_audio_engine_start_with_calibration_parameters() to the test module in rust/src/audio/engine.rs (after line 342). Test should create AudioEngine with calibration_procedure and calibration_progress_tx parameters, call start(), and verify it succeeds (on Android) or handles gracefully (on desktop stub). Reference design document Section 7.1.2. | Restrictions: Must work on both Android and desktop (using cfg! macros), must use mock CalibrationProcedure and broadcast channels, must not require actual audio hardware, test must be deterministic | _Leverage: Existing test patterns in test module (lines 342-411)_ | Success: Test compiles on all platforms, passes on Android and desktop, correctly uses stub on non-Android, no platform-specific test failures | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (test function created, platform handling, assertions). Then mark as completed [x] in tasks.md_

## Phase 4: AppContext Integration

- [ ] 4.1. Add BroadcastChannelManager::get_calibration_sender()
  - File: `rust/src/managers/broadcast_manager.rs`
  - Add get_calibration_sender() method returning Option<broadcast::Sender<CalibrationProgress>>
  - Add unit test: test_get_calibration_sender()
  - _Leverage: Existing BroadcastChannelManager structure_
  - _Requirements: Design Section 3.4, Task 4.4_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust API developer | Task: Add get_calibration_sender() method to BroadcastChannelManager in rust/src/managers/broadcast_manager.rs that returns Option<broadcast::Sender<CalibrationProgress>>. Method should acquire read lock on calibration channel and clone sender if available, return None otherwise. Add unit test verifying returns None before init and Some after init_calibration(). Reference design document Task 4.4. | Restrictions: Must use read lock (not write), must handle lock failure gracefully, must return cloned sender (not move), must include comprehensive documentation | _Leverage: Existing broadcast manager patterns and init_calibration() method_ | Success: Method returns correct Option type, handles uninitialized state correctly, unit test passes, documentation is clear | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (method implementation, test case, error handling). Then mark as completed [x] in tasks.md_

- [ ] 4.2. Modify AudioEngineManager to accept calibration parameters
  - File: `rust/src/managers/audio_engine_manager.rs`
  - Update AudioEngineManager::start() to accept calibration_procedure and calibration_progress_tx
  - Pass parameters through to AudioEngine::start()
  - Update method documentation
  - _Leverage: Existing AudioEngineManager::start() method_
  - _Requirements: Design Section 3.4, Task 4.1_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust manager pattern specialist | Task: Update AudioEngineManager::start() in rust/src/managers/audio_engine_manager.rs to accept calibration_procedure and calibration_progress_tx parameters and forward them to AudioEngine::start(). Update documentation to describe new parameters. Reference design document Task 4.1. | Restrictions: Must maintain existing error handling, must preserve NotInitialized error case, must pass parameters correctly through to engine, must update doc comments | _Leverage: Existing start() method structure and error handling_ | Success: Parameters accepted and forwarded correctly, compiles successfully, documentation updated, error handling preserved | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (signature changes, parameter forwarding). Then mark as completed [x] in tasks.md_

- [ ] 4.3. Update AppContext::start_audio() to pass calibration parameters
  - File: `rust/src/context.rs`
  - Modify start_audio() to retrieve calibration procedure via get_procedure_arc()
  - Retrieve optional calibration progress sender via get_calibration_sender()
  - Pass both parameters to audio engine start()
  - _Leverage: Existing start_audio() implementation and calibration/broadcasts managers_
  - _Requirements: Design Section 3.4, Task 4.2_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust application architect | Task: Update AppContext::start_audio() in rust/src/context.rs to retrieve calibration_procedure via self.calibration.get_procedure_arc() and calibration_progress_tx via self.broadcasts.get_calibration_sender(), then pass both to self.audio.start(). Reference design document Task 4.2 for complete implementation pattern. | Restrictions: Must handle conditional compilation for Android, must retrieve calibration references before audio start, must pass all parameters correctly, must maintain existing error propagation | _Leverage: Existing calibration and broadcast manager access patterns_ | Success: Calibration parameters retrieved and passed correctly, compiles for Android and desktop, error handling preserved, no functional regression | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (code modifications, parameter retrieval, method calls). Then mark as completed [x] in tasks.md_

- [ ] 4.4. Implement audio restart logic in start_calibration()
  - File: `rust/src/context.rs`
  - Modify start_calibration() to call stop_audio() before starting calibration
  - Log stop errors as warnings but continue
  - Call start_audio(120) to restart with calibration procedure active
  - Map audio errors to CalibrationError::AudioEngineError
  - _Leverage: Existing start_calibration() and stop_audio() methods_
  - _Requirements: Design Section 3.4, Task 4.3_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust error handling specialist | Task: Modify AppContext::start_calibration() in rust/src/context.rs to stop audio engine before initializing calibration (using stop_audio()), then restart with start_audio(120). Log stop errors as warnings using eprintln! but don't fail. Map start_audio errors to CalibrationError::AudioEngineError. Reference design document Task 4.3 for complete implementation including error handling strategy. | Restrictions: Must use conditional compilation for Android, must not fail on stop errors (log only), must propagate start errors as CalibrationError, must restart at 120 BPM, must maintain existing calibration initialization logic | _Leverage: Existing stop_audio() and start_audio() methods_ | Success: Audio restarts cleanly during calibration start, stop errors logged but don't block, start errors propagate correctly, metronome plays at 120 BPM, calibration procedure is active in analysis thread | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (modifications to start_calibration, error handling, logging). Then mark as completed [x] in tasks.md_

## Phase 5: Integration Testing

- [ ] 5.1. Create end-to-end calibration workflow test
  - File: `rust/tests/calibration_integration_test.rs`
  - Create test_full_calibration_workflow() with AppContext initialization
  - Test calibration start, procedure initialization, audio engine state
  - Add test_calibration_restart_audio() measuring restart latency
  - Add placeholders for future synthetic audio injection tests
  - _Leverage: AppContext public API and calibration manager methods_
  - _Requirements: Design Section 7.2.1_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust integration test engineer | Task: Create rust/tests/calibration_integration_test.rs with end-to-end tests for calibration workflow. Implement test_full_calibration_workflow() verifying procedure initialization and audio engine start. Implement test_calibration_restart_audio() measuring audio restart latency (<200ms requirement). Add conditional compilation for Android-only tests. Reference design document Section 7.2.1 for complete test specifications. | Restrictions: Must use conditional compilation for Android tests, must not require physical device for desktop tests, must verify state transitions not actual audio processing (requires manual testing), must measure timing accurately, must clean up resources after tests | _Leverage: AppContext::new(), start_calibration(), CalibrationManager::get_procedure_arc()_ | Success: Tests compile on all platforms, Android tests verify correct initialization, restart latency test passes (<200ms), tests clean up properly, no resource leaks | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (test file created, test cases implemented, timing measurements). Then mark as completed [x] in tasks.md_

- [ ] 5.2. Manual testing on Android device
  - Deploy to Android device and test complete calibration workflow
  - Test Case 1: Complete calibration (30 samples: 10 kick, 10 snare, 10 hihat)
  - Test Case 2: Invalid sample rejection (quiet sounds, non-beatbox sounds)
  - Test Case 3: Audio restart latency (<200ms, barely noticeable)
  - Test Case 4: Calibration cancellation (incomplete state not saved)
  - Test Case 5: Error handling (no permission, already in progress)
  - Check device logs for onset detection, sample acceptance/rejection, progress broadcasts
  - _Leverage: Complete calibration system from all previous tasks_
  - _Requirements: Design Section 7.4, NFR-1, NFR-2_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Mobile QA engineer with Android testing expertise | Task: Deploy app to Android device and execute comprehensive manual test plan covering 5 test cases: (1) Complete calibration workflow with 30 samples, (2) Invalid sample rejection, (3) Audio restart latency measurement, (4) Calibration cancellation, (5) Error handling. Monitor device logs for onset detection events, sample acceptance/rejection, progress broadcasts. Verify all acceptance criteria from design document Section 7.4. Document findings including any issues, timing measurements, and log snippets. | Restrictions: Must test on physical Android device (not emulator), must perform real beatbox sounds, must verify UI updates in real-time, must capture logcat output, must test in quiet environment (<40dB ambient), must verify calibration persistence across app restarts | _Leverage: Complete calibration system, device logcat for debugging_ | Success: Complete calibration succeeds with 30 samples, progress updates visible in UI in real-time (<100ms latency), invalid samples rejected silently, audio restart <200ms, calibration state persists after completion, no crashes observed, all 5 test cases pass | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (test results for each case, logcat snippets, timing measurements, issues found). Then mark as completed [x] in tasks.md_

## Phase 6: Documentation and Cleanup

- [ ] 6.1. Update API documentation
  - Files: `rust/src/analysis/mod.rs`, `rust/src/audio/engine.rs`, `rust/src/context.rs`, `rust/src/managers/*.rs`
  - Add/update function-level doc comments with `///`
  - Document all parameters with `# Arguments`
  - Document return values with `# Returns`
  - Document error cases with `# Errors`
  - Add thread safety notes with `# Thread Safety`
  - Verify `cargo doc` builds without warnings
  - _Leverage: Existing documentation patterns in codebase_
  - _Requirements: Design Section 9, Task 6.1_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Technical documentation specialist with Rust expertise | Task: Update inline documentation for all modified functions in rust/src/analysis/mod.rs, rust/src/audio/engine.rs, rust/src/context.rs, and rust/src/managers/ using Rust doc comment conventions. Include function descriptions, parameter descriptions (# Arguments), return values (# Returns), error cases (# Errors), and thread safety notes (# Thread Safety) where applicable. Verify documentation builds correctly with cargo doc. Reference design document Section 9 for API changes requiring documentation. | Restrictions: Must use standard Rust doc comment format (///), must document all public functions, must include examples for complex functions, must verify cargo doc succeeds with no warnings, must follow existing documentation style | _Leverage: Existing doc comment patterns in codebase_ | Success: All modified public functions documented, cargo doc builds without warnings, documentation is clear and comprehensive, parameters and returns fully described, thread safety notes included | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (functions documented, cargo doc output, documentation coverage). Then mark as completed [x] in tasks.md_

- [ ] 6.2. Update CHANGELOG.md
  - File: `CHANGELOG.md` (create if doesn't exist)
  - Add [Unreleased] section with Added/Changed/Fixed subsections
  - Document user-facing changes (calibration progress updates work)
  - Document technical changes (analysis thread calibration mode, signatures)
  - Include version and date when released
  - _Leverage: Project semantic versioning conventions_
  - _Requirements: Design Section 11, Task 6.2_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Technical writer with software release documentation expertise | Task: Update or create CHANGELOG.md following semantic versioning conventions. Add [Unreleased] section with Added/Changed/Fixed categories documenting the calibration workflow fix. Include both user-facing changes (progress updates now work) and technical details (analysis thread modifications, signature changes). Reference design document Task 6.2 for complete changelog entry format. | Restrictions: Must follow semantic versioning format, must separate user-facing and technical changes, must be concise but complete, must use proper markdown formatting, must include breaking changes if any | _Leverage: Existing CHANGELOG.md if present, semantic versioning conventions_ | Success: CHANGELOG.md updated with clear entries, user-facing changes documented, technical changes documented, follows semantic versioning format, no spelling or grammar errors | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (changelog entries added, categories used). Then mark as completed [x] in tasks.md_

- [ ] 6.3. Code review and quality audit
  - Perform self-review against project quality standards (CLAUDE.md)
  - Verify all files <500 lines, all functions <50 lines
  - Verify SOLID principles, dependency injection, no globals
  - Verify unit test coverage ≥90% for modified code
  - Verify no performance regressions (<5% CPU, <10KB memory)
  - Run cargo clippy and address all warnings
  - Run cargo fmt to ensure consistent formatting
  - _Leverage: Project quality guidelines from CLAUDE.md_
  - _Requirements: Design Section 13, Task 6.3_
  - _Prompt: Implement the task for spec calibration-workflow-fix, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Senior Rust code reviewer | Task: Perform comprehensive quality audit of all modified code against project standards from CLAUDE.md. Check: files <500 lines, functions <50 lines, SOLID principles, dependency injection used, no globals, no testability blockers, unit test coverage ≥90%, lock-free audio callback, real-time safety. Run cargo clippy and fix all warnings. Run cargo fmt. Measure CPU and memory impact. Document findings and address any issues. Reference design document Section 13 for complete checklist. | Restrictions: Must address all clippy warnings, must format with cargo fmt, must verify coverage with cargo tarpaulin or similar, must profile CPU/memory impact, must not introduce new quality issues, must document any exceptions | _Leverage: cargo clippy, cargo fmt, coverage tools, project quality guidelines_ | Success: All quality checks pass, no clippy warnings, code properly formatted, coverage ≥90%, no performance regressions, SOLID principles followed, all issues documented and resolved | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (quality metrics, clippy results, coverage report, performance measurements). Then mark as completed [x] in tasks.md_
