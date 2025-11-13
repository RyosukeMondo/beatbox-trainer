# Tasks Document: Android Build Integration

## Phase 1: Rust Code Fixes (Critical - Compilation Blockers)

- [x] 1.1. Fix Oboe audio callback trait implementation
  - File: `rust/src/audio/engine.rs`
  - Extract closure into named struct implementing `AudioOutputCallback` trait
  - Update `create_output_stream()` to use struct instead of closure
  - Verify compilation for android targets: `cargo check --target aarch64-linux-android`
  - _Leverage: Existing metronome logic in `rust/src/audio/metronome.rs`_
  - _Requirements: Requirement 1_
  - _Prompt: Implement the task for spec android-build-integration, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust systems programmer with expertise in audio programming and trait bounds | Task: Refactor the oboe audio callback in rust/src/audio/engine.rs from a closure to a named struct implementing the AudioOutputCallback trait (lines 146-192). The struct must satisfy oboe-rs v0.6.x trait bounds with FrameType = (f32, oboe::Mono). Preserve all existing metronome generation logic, atomic operations, and real-time safety guarantees (no allocations, no locks). Reference design document Component 2. | Restrictions: Must not change audio callback logic, must maintain zero-allocation guarantee, must preserve frame counter and BPM atomic operations, do not introduce any locks or blocking operations | _Leverage: rust/src/audio/metronome.rs for click generation patterns_ | Success: Compiles successfully for aarch64-linux-android target without trait bound errors, audio callback struct satisfies AudioOutputCallback trait, all existing tests pass | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (structs created, methods implemented, file locations). Then mark as completed [x] in tasks.md_

- [x] 1.2. Fix ndk-context initialization with both required parameters
  - File: `rust/src/lib.rs`
  - Modify `JNI_OnLoad` function to obtain application context from JavaVM
  - Call `ndk_context::initialize_android_context(vm_ptr, context_ptr)` with both parameters
  - Add error handling and logging for initialization failures
  - _Leverage: Existing `JNI_OnLoad` skeleton in `rust/src/lib.rs`_
  - _Requirements: Requirement 2_
  - _Prompt: Implement the task for spec android-build-integration, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Android NDK developer with expertise in JNI and context initialization | Task: Fix the ndk_context::initialize_android_context() call in rust/src/lib.rs JNI_OnLoad function to provide both required parameters (JavaVM pointer and Context jobject). Use JNI to retrieve the application context from the JavaVM environment before calling initialize. Add proper error handling and logging. Reference design document Component 3. | Restrictions: Must use conditional compilation #[cfg(target_os = "android")], must handle JNI errors gracefully without panicking, must return JNI_VERSION_1_6 even on initialization failure | _Leverage: Existing JNI_OnLoad structure in rust/src/lib.rs_ | Success: Compiles for Android targets, ndk_context initializes without errors, no "android context was not initialized" crash occurs, proper error logging to logcat | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (functions modified, JNI calls added, error handling). Then mark as completed [x] in tasks.md_

- [x] 1.3. Add Android-specific error variants to error.rs
  - File: `rust/src/error.rs`
  - Add `JniInitFailed { reason: String }` (code 1008) to AudioError enum
  - Add `ContextNotInitialized` (code 1009) to AudioError enum
  - Implement `ErrorCode` trait methods for new variants
  - Add unit tests for new error codes
  - _Leverage: Existing `AudioError` enum and `ErrorCode` trait in `rust/src/error.rs`_
  - _Requirements: Requirement 2, Requirement 5_
  - _Prompt: Implement the task for spec android-build-integration, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust developer with expertise in error handling and type systems | Task: Extend the AudioError enum in rust/src/error.rs with Android-specific error variants: JniInitFailed (code 1008) and ContextNotInitialized (code 1009). Implement message() method returning clear user-facing error messages. Add comprehensive unit tests covering the new variants. Reference design document Component 5. | Restrictions: Must follow existing error code pattern (1001-1007), must implement ErrorCode trait for new variants, must include user-friendly error messages, must add Display trait formatting | _Leverage: Existing error.rs structure and test patterns_ | Success: New error variants compile and integrate seamlessly, error codes are unique (1008, 1009), unit tests pass, error messages are clear and actionable | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (enum variants added, error codes, test cases). Then mark as completed [x] in tasks.md_

## Phase 2: Android Build System Integration

- [ ] 2.1. Create Gradle task for cargo-ndk invocation
  - File: `android/app/build.gradle.kts`
  - Add custom Gradle task `buildRustAndroid` that runs cargo-ndk for each architecture
  - Configure task to execute before `preBuild` task
  - Add environment checks for cargo-ndk availability
  - _Leverage: Existing `android/app/build.gradle.kts` structure and defaultConfig_
  - _Requirements: Requirement 3_
  - _Prompt: Implement the task for spec android-build-integration, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Android build engineer with expertise in Gradle and native library integration | Task: Create a custom Gradle task "buildRustAndroid" in android/app/build.gradle.kts that executes cargo ndk for arm64-v8a, armeabi-v7a, and x86_64 architectures. The task should verify cargo-ndk is installed, execute cross-compilation, and copy resulting .so files to android/app/src/main/jniLibs/{arch}/. Hook the task into the build dependency chain before preBuild. Reference design document Component 1 and Architecture diagram. | Restrictions: Must check for cargo-ndk installation before running, must handle compilation failures gracefully, must not break existing Flutter build process, must support incremental builds | _Leverage: android.defaultConfig for architecture list_ | Success: Task executes during flutter build apk, cargo-ndk compiles Rust library for all 3 architectures, .so files are copied to correct jniLibs locations, task fails with clear error if cargo-ndk missing | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (Gradle task created, shell commands executed, file paths). Then mark as completed [x] in tasks.md_

- [ ] 2.2. Configure jniLibs source directory in Gradle
  - File: `android/app/build.gradle.kts`
  - Add `android.sourceSets` configuration pointing to `jniLibs` directory
  - Verify APK packaging includes .so files from jniLibs
  - Add architecture filters to defaultConfig.ndk
  - _Leverage: Existing `android` block in `build.gradle.kts`_
  - _Requirements: Requirement 4_
  - _Prompt: Implement the task for spec android-build-integration, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Android build configuration specialist | Task: Configure jniLibs source directory in android/app/build.gradle.kts to ensure the APK packaging system includes native libraries from android/app/src/main/jniLibs/. Add android.sourceSets configuration and ndk.abiFilters for arm64-v8a, armeabi-v7a, x86_64. Verify configuration by building APK and checking contents with unzip. Reference design document Data Models section. | Restrictions: Must not break existing resource packaging, must preserve Flutter's default jniLibs handling, must support multiple architectures correctly | _Leverage: Existing android block structure_ | Success: APK contains libbeatbox_trainer.so for all 3 architectures, files are in correct lib/{arch}/ paths, APK size increases by < 15MB | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (Gradle configurations added, APK verification results). Then mark as completed [x] in tasks.md_

- [ ] 2.3. Update MainActivity.kt to load native library
  - File: `android/app/src/main/kotlin/com/ryosukemondo/beatbox_trainer/MainActivity.kt`
  - Add `companion object` with `init` block calling `System.loadLibrary("beatbox_trainer")`
  - Add try-catch for `UnsatisfiedLinkError` with user-friendly error logging
  - Verify library name matches Cargo.toml `[lib] name`
  - _Leverage: Existing `MainActivity.kt` FlutterActivity structure_
  - _Requirements: Requirement 5_
  - _Prompt: Implement the task for spec android-build-integration, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Android developer with expertise in JNI and native library loading | Task: Modify MainActivity.kt to load the beatbox_trainer native library using System.loadLibrary() in a companion object init block. Add comprehensive error handling for UnsatisfiedLinkError with logging that helps diagnose missing libraries. Verify the library name matches rust/Cargo.toml [lib] name = "beatbox_trainer". Reference design document Component 4 and Runtime Initialization Flow diagram. | Restrictions: Must not break existing FlutterActivity functionality, must handle loading errors gracefully without crashing, must provide clear error messages for debugging | _Leverage: Existing MainActivity extends FlutterActivity_ | Success: System.loadLibrary() executes successfully on app launch, no UnsatisfiedLinkError occurs, JNI_OnLoad in Rust is called, error messages are clear if library missing | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (Kotlin code added, error handling implemented). Then mark as completed [x] in tasks.md_

## Phase 3: Build Verification and Testing

- [ ] 3.1. Verify full APK build with native libraries
  - Run `flutter clean && flutter build apk` from project root
  - Verify build completes without errors in < 5 minutes
  - Check APK contents with `unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep libbeatbox_trainer.so`
  - Confirm .so files present for arm64-v8a, armeabi-v7a, x86_64
  - _Leverage: Gradle tasks from Phase 2_
  - _Requirements: Requirement 3, Requirement 4_
  - _Prompt: Implement the task for spec android-build-integration, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps engineer with Android build expertise | Task: Execute full clean build workflow (flutter clean && flutter build apk) and verify native library integration. Check that cargo-ndk task executes, Rust compiles for all architectures, .so files are packaged in APK at correct paths. Measure build time and verify < 5 minute target. Document any build warnings or issues discovered. Reference design document Testing Strategy - Build Reproducibility Test. | Restrictions: Must test clean build from scratch, must verify all 3 architectures present, must not modify code during verification | _Leverage: Gradle buildRustAndroid task, APK packaging configuration_ | Success: Clean build completes in < 5 minutes, APK contains libbeatbox_trainer.so for all architectures in lib/{arch}/ paths, no compilation errors occur, build is reproducible | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (build commands executed, verification results, timing measurements). Then mark as completed [x] in tasks.md_

- [ ] 3.2. Test incremental Rust rebuild
  - Modify `rust/src/api.rs` (add comment)
  - Run `flutter build apk` and verify Rust recompilation triggers
  - Measure incremental build time (target < 30 seconds)
  - Verify APK is updated with new .so files
  - _Leverage: Gradle task dependency chain from Phase 2_
  - _Requirements: Requirement 3_
  - _Prompt: Implement the task for spec android-build-integration, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Build optimization specialist | Task: Test incremental build performance by modifying rust/src/api.rs and running flutter build apk. Verify that Gradle detects Rust source changes and triggers cargo-ndk recompilation only for modified code. Measure build time and ensure < 30 second target is met. Verify APK receives updated .so files. Reference design document Testing Strategy - Build Time Benchmark. | Restrictions: Must test with minimal code change (comment only), must verify actual recompilation occurs, must not affect runtime functionality | _Leverage: Gradle buildRustAndroid task incremental detection_ | Success: Incremental build completes in < 30 seconds, Rust recompilation triggered correctly, APK updated with new .so, no unnecessary full rebuilds | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (timing measurements, build output analysis). Then mark as completed [x] in tasks.md_

- [ ] 3.3. Deploy and test on physical device (Pixel 9a)
  - Connect Pixel 9a via USB (device ID: 4C041JEBF15065)
  - Run `flutter run -d 4C041JEBF15065` and verify app launches
  - Check logcat for JNI_OnLoad execution and ndk_context initialization
  - Tap "Start" button and verify audio engine starts without errors
  - _Leverage: MainActivity native library loading, Rust audio engine_
  - _Requirements: Requirement 6_
  - _Prompt: Implement the task for spec android-build-integration, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Mobile QA engineer with Android testing expertise | Task: Deploy app to Pixel 9a (device ID: 4C041JEBF15065) using flutter run and perform end-to-end verification. Monitor logcat for JNI_OnLoad, ndk_context initialization, and any errors. Test app launch, UI load, and audio engine start sequence. Verify no UnsatisfiedLinkError or ContextNotInitialized errors occur. Reference design document Testing Strategy - Physical Device Test. | Restrictions: Must test on actual hardware (not emulator), must verify full initialization chain, must test audio engine start flow, must capture logcat output | _Leverage: All components from Phases 1-2_ | Success: App installs and launches successfully on Pixel 9a, no library loading errors, JNI_OnLoad executes, ndk_context initializes, audio engine starts when user taps button, no crashes | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (test results, logcat snippets, verification checklist). Then mark as completed [x] in tasks.md_

## Phase 4: Documentation and Cleanup

- [ ] 4.1. Document build setup in README
  - File: `README.md` (or create `docs/ANDROID_BUILD.md`)
  - Document cargo-ndk installation requirements
  - Add troubleshooting section for common build errors
  - Document required Android NDK version (r25c+)
  - _Leverage: Design document error handling scenarios_
  - _Requirements: All requirements (documentation)_
  - _Prompt: Implement the task for spec android-build-integration, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Technical writer with Android development knowledge | Task: Create comprehensive build setup documentation covering cargo-ndk installation, required tools (Android NDK r25c+, Rust targets), build commands, and troubleshooting guide for common errors (cargo-ndk not found, library missing from APK, JNI initialization failures). Reference design document Error Handling section for error scenarios. | Restrictions: Must provide clear step-by-step instructions, must include troubleshooting for all documented error scenarios, must be accessible to developers unfamiliar with Rust/Android NDK | _Leverage: Design document Error Handling scenarios_ | Success: Documentation is complete and accurate, covers all setup steps and prerequisites, includes troubleshooting section with solutions, developers can follow instructions successfully | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (documentation files created, sections added). Then mark as completed [x] in tasks.md_

- [ ] 4.2. Add CI/CD build verification (optional enhancement)
  - File: `.github/workflows/android-build.yml` (create if desired)
  - Configure GitHub Actions workflow to build APK
  - Add cargo-ndk installation step
  - Verify APK artifact contains native libraries
  - _Leverage: Gradle build tasks from Phase 2_
  - _Requirements: Non-Functional Requirements (CI/CD Integration)_
  - _Prompt: Implement the task for spec android-build-integration, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps engineer with CI/CD and GitHub Actions expertise | Task: Create GitHub Actions workflow (.github/workflows/android-build.yml) that installs required tools (cargo-ndk, Android NDK, Rust targets), runs flutter build apk, and verifies APK contains libbeatbox_trainer.so for all architectures. Configure artifact upload for APK. Reference design document Non-Functional Requirements - CI/CD Integration. | Restrictions: Must install all dependencies in CI environment, must cache Rust and Gradle artifacts for performance, must fail if APK verification fails, must work on standard GitHub Actions runners | _Leverage: Gradle buildRustAndroid task, Phase 3 verification commands_ | Success: Workflow executes successfully on push/PR, APK builds in CI environment, native libraries present in artifact, workflow caches dependencies for faster runs | Instructions: Mark this task as in-progress in tasks.md before starting. After completion, use log-implementation tool with detailed artifacts (workflow file created, CI steps configured). Then mark as completed [x] in tasks.md_

## Estimated Timeline

- **Phase 1** (Rust Code Fixes): 2-3 hours (critical path)
- **Phase 2** (Build System): 2-3 hours
- **Phase 3** (Testing): 1-2 hours
- **Phase 4** (Documentation): 1 hour
- **Total**: 6-9 hours (1-2 days)

## Success Criteria

All tasks completed when:
- ✅ Rust compiles for Android targets without errors
- ✅ APK contains libbeatbox_trainer.so for all architectures
- ✅ App launches successfully on Pixel 9a
- ✅ Audio engine starts without library loading errors
- ✅ Build completes in < 5 minutes (clean), < 30 seconds (incremental)
- ✅ Documentation covers setup and troubleshooting
