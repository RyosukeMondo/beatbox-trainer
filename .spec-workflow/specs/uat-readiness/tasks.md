# Tasks: UAT Readiness Implementation

## Overview
This document breaks down the UAT Readiness design into atomic, implementable tasks. Each task is estimated for effort, has clear success criteria, and includes an implementation prompt for execution.

**Total Estimated Effort**: ~4-5 weeks (1 developer)

## Task Status Legend
- `[ ]` - Pending
- `[-]` - In Progress
- `[x]` - Completed

---

## Phase 1: Foundation & Dependencies (3 days)

- [x] 1.1. Add Project Dependencies
  - File: pubspec.yaml
  - Estimate: 30 minutes | Priority: Critical
  - Add new Flutter dependencies for navigation, storage, and testing enhancements
  - _Requirements: US-1, US-3, US-4, US-5_
  - _Leverage: Existing pubspec.yaml at /home/rmondo/repos/beatbox-trainer/pubspec.yaml_
  - _Prompt: Role: DevOps/Build Engineer | Task: Add the following dependencies to pubspec.yaml: go_router: ^14.6.2, shared_preferences: ^2.3.4. Already present (verify versions): mocktail: ^1.0.4, flutter_test (SDK), integration_test (SDK) | Restrictions: Do NOT upgrade existing dependencies unnecessarily, Verify pubspec.yaml syntax after changes, Run `flutter pub get` to validate | Leverage: Existing pubspec.yaml at /home/rmondo/repos/beatbox-trainer/pubspec.yaml | Requirements: US-1 (navigation for onboarding), US-3 (settings storage), US-5 (testing) | Success: pubspec.yaml contains all new dependencies, `flutter pub get` succeeds without errors, No version conflicts reported_

- [x] 1.2. Regenerate Flutter Rust Bridge
  - File: rust/src/api.rs, Dart generated files
  - Estimate: 15 minutes | Priority: Critical
  - Ensure FFI bridge is up-to-date before adding new API methods
  - _Requirements: All_
  - _Leverage: Existing FFI setup in rust/src/api.rs, Design document FFI examples (design.md lines 78-112)_
  - _Prompt: Role: Rust/FFI Integration Engineer | Task: Regenerate Flutter Rust Bridge bindings to ensure clean slate. Steps: 1. Run `flutter_rust_bridge_codegen generate` 2. Verify no compilation errors in Rust 3. Verify no errors in Dart bindings 4. Commit generated files | Restrictions: Do NOT modify rust/src/api.rs manually before regenerating, Verify bridge_generated.rs and frb_generated.dart compile | Leverage: Existing FFI setup in rust/src/api.rs, Design document FFI examples (design.md lines 78-112) | Requirements: Foundation for all features | Success: `flutter_rust_bridge_codegen generate` completes successfully, Rust compiles: `cargo build --release`, Dart analyzes: `flutter analyze` shows no new errors, Generated files committed_

---

## Phase 2: Storage Infrastructure (1 week)

- [x] 2.1. Implement Storage Service Interface
  - File: lib/services/storage/i_storage_service.dart
  - Estimate: 2 hours | Priority: Critical
  - Create interface for calibration and settings persistence
  - _Requirements: US-1, US-4_
  - _Leverage: lib/services/audio/i_audio_service.dart (interface pattern), Design document section 1.1 (design.md lines 117-141)_
  - _Prompt: Role: Flutter Service Layer Developer | Task: Create IStorageService interface following existing patterns. Interface methods: abstract class IStorageService { Future<void> init(); Future<bool> hasCalibration(); Future<void> saveCalibration(CalibrationData data); Future<CalibrationData?> loadCalibration(); Future<void> clearCalibration(); } class CalibrationData { final int level; final DateTime timestamp; final Map<String, double> thresholds; CalibrationData({required this.level, required this.timestamp, required this.thresholds}); factory CalibrationData.fromJson(Map<String, dynamic> json); Map<String, dynamic> toJson(); } | Restrictions: Follow existing service interface patterns (see IAudioService), Use abstract class not mixin, Document all methods with /// comments | Leverage: lib/services/audio/i_audio_service.dart (interface pattern), Design document section 1.1 (design.md lines 117-141) | Requirements: US-1 (calibration persistence), US-4 (level storage) | Success: File created at lib/services/storage/i_storage_service.dart, Interface defines all 5 methods, CalibrationData class includes fromJson/toJson, No syntax errors: `dart analyze lib/services/storage/`_

- [x] 2.2. Implement Storage Service
  - File: lib/services/storage/storage_service_impl.dart
  - Estimate: 4 hours | Priority: Critical
  - Implement storage service using shared_preferences
  - _Requirements: US-1, US-4_
  - _Leverage: lib/services/audio/audio_service_impl.dart (implementation pattern), Task 2.1 interface definition, Design document section 1.1 (design.md lines 142-152)_
  - _Prompt: Role: Flutter Service Implementation Developer | Task: Implement StorageServiceImpl with shared_preferences. Implementation requirements: Initialize SharedPreferences in init(), Store calibration as JSON string with key 'calibration_data', Handle serialization/deserialization errors gracefully, Use proper error types (StorageException). Storage keys: 'calibration_data': JSON string of CalibrationData, 'has_calibration': bool flag | Restrictions: Must call init() before using (async initialization pattern), Handle null cases (no data saved), Use try-catch for JSON parsing, Follow existing service implementation patterns | Leverage: lib/services/audio/audio_service_impl.dart (implementation pattern), Task 2.1 interface definition, Design document section 1.1 (design.md lines 142-152) | Requirements: US-1 (calibration persistence), US-4 (settings storage) | Success: File created at lib/services/storage/storage_service_impl.dart, Implements IStorageService, All methods work with SharedPreferences, Error handling for JSON parsing, No analyzer errors_

- [x] 2.3. Add Storage Service Tests
  - File: test/services/storage_service_test.dart
  - Estimate: 3 hours | Priority: High
  - Unit tests for storage service with mock SharedPreferences
  - _Requirements: US-5_
  - _Leverage: test/services/audio_service_test.dart (test pattern), Design document section 6.3 (design.md lines 568-606), Task 2.2 implementation_
  - _Prompt: Role: Test Engineer | Task: Write comprehensive unit tests for StorageServiceImpl. Test cases: 1. hasCalibration returns false when no data 2. saveCalibration and loadCalibration round-trip 3. clearCalibration removes data 4. JSON parsing error handling 5. Null handling for missing data. Use SharedPreferences.setMockInitialValues({}) for testing | Restrictions: Do NOT use real file system, Use MockInitialValues pattern for SharedPreferences, Follow existing test patterns (mocktail), Aim for 100% code coverage of storage service | Leverage: test/services/audio_service_test.dart (test pattern), Design document section 6.3 (design.md lines 568-606), Task 2.2 implementation | Requirements: US-5 (80%+ test coverage) | Success: File created at test/services/storage_service_test.dart, All 5+ test cases pass, Coverage of storage_service_impl.dart is 100%, Tests run in <3 seconds_

- [x] 2.4. Add Rust Calibration Persistence API
  - File: rust/src/api.rs, rust/src/context.rs
  - Estimate: 3 hours | Priority: Critical
  - Add FFI methods to load/save calibration state from JSON
  - _Requirements: US-1, US-4_
  - _Leverage: rust/src/api.rs existing patterns, rust/src/calibration/state.rs, Design document section 1.1 (design.md lines 153-169)_
  - _Prompt: Role: Rust FFI/Backend Developer | Task: Add FFI methods for calibration persistence. New FFI methods to add to rust/src/api.rs: #[flutter_rust_bridge::frb] pub fn load_calibration_state(json: String) -> Result<(), CalibrationError> { let data: CalibrationData = serde_json::from_str(&json)?; APP_CONTEXT.load_calibration(data)?; Ok(()) } #[flutter_rust_bridge::frb] pub fn get_calibration_state() -> Result<String, CalibrationError> { let data = APP_CONTEXT.get_calibration_state()?; Ok(serde_json::to_string(&data)?) }. Also update CalibrationState struct to include `level` field | Restrictions: Use serde_json for serialization, Return proper CalibrationError types, Do NOT use unwrap() or expect(), Add serde Serialize/Deserialize derives | Leverage: rust/src/api.rs existing patterns, rust/src/calibration/state.rs, Design document section 1.1 (design.md lines 153-169) | Requirements: US-1 (load calibration on app start), US-4 (level persistence) | Success: Two new FFI methods in api.rs, CalibrationState has `level: u8` field, Rust compiles without errors, FFI bridge regenerates successfully_

---

## Phase 3: Navigation & Onboarding (1 week)

- [x] 3.1. Configure go_router Navigation
  - File: lib/main.dart
  - Estimate: 2 hours | Priority: Critical
  - Replace MaterialApp with MaterialApp.router and define routes
  - _Requirements: US-1_
  - _Leverage: lib/main.dart current structure, Design document section 1.2 (design.md lines 172-202)_
  - _Prompt: Role: Flutter Navigation Developer | Task: Configure go_router for app navigation. Routes to define: `/` → SplashScreen (checks calibration), `/onboarding` → OnboardingScreen, `/calibration` → CalibrationScreen, `/training` → TrainingScreen, `/settings` → SettingsScreen. Replace existing MaterialApp with MaterialApp.router | Restrictions: Keep existing theme configuration, Do NOT break existing TrainingScreen, Use context.go() for navigation (not Navigator.push) | Leverage: lib/main.dart current structure, Design document section 1.2 (design.md lines 172-202) | Requirements: US-1 (onboarding flow navigation) | Success: main.dart uses MaterialApp.router, All 5 routes defined, App compiles and launches, No navigation errors in logs_

- [x] 3.2. Implement Splash Screen
  - File: lib/ui/screens/splash_screen.dart
  - Estimate: 3 hours | Priority: Critical
  - Create splash screen that checks calibration and routes accordingly
  - _Requirements: US-1_
  - _Leverage: lib/ui/screens/training_screen.dart (StatefulWidget pattern), Task 2.2 StorageService implementation, Design document section 1.2 (design.md lines 204-232)_
  - _Prompt: Role: Flutter UI Developer | Task: Create SplashScreen with calibration check logic. Flow: 1. Show app logo/loading indicator 2. Initialize StorageService 3. Check hasCalibration() 4. If true: load calibration into Rust, navigate to /training 5. If false: navigate to /onboarding | Restrictions: Use StatefulWidget with initState for checks, Handle errors gracefully (show error dialog), Inject IStorageService for testability, Show loading indicator while checking | Leverage: lib/ui/screens/training_screen.dart (StatefulWidget pattern), Task 2.2 StorageService implementation, Design document section 1.2 (design.md lines 204-232) | Requirements: US-1 (first-time user detection) | Success: File created at lib/ui/screens/splash_screen.dart, Checks calibration on mount, Routes to correct screen based on state, Shows loading indicator, Handles errors with ErrorDialog_

- [x] 3.3. Implement Onboarding Screen
  - File: lib/ui/screens/onboarding_screen.dart
  - Estimate: 4 hours | Priority: High
  - Create friendly onboarding screen explaining calibration
  - _Requirements: US-1_
  - _Leverage: lib/ui/screens/training_screen.dart (UI patterns), Design document section 1.2 (design.md lines 234-291)_
  - _Prompt: Role: Flutter UI/UX Developer | Task: Create OnboardingScreen with welcoming design. UI elements: App logo/icon (large), Welcome message, Explanation of calibration purpose, 3-step visual guide (KICK → SNARE → HI-HAT), "Start Calibration" button | Restrictions: Use Material Design 3 components, Follow existing color scheme (deepPurple), Make text readable and friendly, Button navigates to /calibration | Leverage: lib/ui/screens/training_screen.dart (UI patterns), Design document section 1.2 (design.md lines 234-291) | Requirements: US-1 (onboarding experience) | Success: File created at lib/ui/screens/onboarding_screen.dart, Clear explanation of calibration, Visual step indicators, Button navigates to calibration, Matches design mockup_

- [x] 3.4. Enhance Calibration Screen with Persistence
  - File: lib/ui/screens/calibration_screen.dart
  - Estimate: 3 hours | Priority: Critical
  - Modify existing calibration screen to save data on completion
  - _Requirements: US-1_
  - _Leverage: lib/ui/screens/calibration_screen.dart (existing implementation), Task 2.2 StorageService, Task 2.4 Rust API methods, Design document section 1.3 (design.md lines 293-339)_
  - _Prompt: Role: Flutter Integration Developer | Task: Enhance CalibrationScreen to persist calibration data. Changes needed: 1. Inject IStorageService 2. After finish_calibration() succeeds: Call api.getCalibrationState(), Deserialize JSON to CalibrationData, Call storageService.saveCalibration(data) 3. Show success dialog 4. Navigate to /training | Restrictions: Do NOT break existing calibration logic, Handle save errors gracefully, Keep existing UI/UX, Use existing error handling patterns | Leverage: lib/ui/screens/calibration_screen.dart (existing implementation), Task 2.2 StorageService, Task 2.4 Rust API methods, Design document section 1.3 (design.md lines 293-339) | Requirements: US-1 (calibration persistence) | Success: CalibrationScreen saves data on completion, Success dialog shows before navigation, Data persists across app restarts, No errors in logs_

---

## Phase 4: Settings & Configuration (1 week)

- [x] 4.1. Implement Settings Service Interface
  - File: lib/services/settings/i_settings_service.dart
  - Estimate: 1 hour | Priority: High
  - Create interface for app settings (BPM, debug mode, classifier level)
  - _Requirements: US-3, US-4_
  - _Leverage: Task 2.1 IStorageService (interface pattern), Design document section 4 (design.md lines 504-528)_
  - _Prompt: Role: Flutter Service Layer Developer | Task: Create ISettingsService interface. Methods to define: abstract class ISettingsService { Future<void> init(); Future<int> getBpm(); Future<void> setBpm(int bpm); Future<bool> getDebugMode(); Future<void> setDebugMode(bool enabled); Future<int> getClassifierLevel(); Future<void> setClassifierLevel(int level); } | Restrictions: Follow existing interface patterns, Document all methods, Use abstract class | Leverage: Task 2.1 IStorageService (interface pattern), Design document section 4 (design.md lines 504-528) | Requirements: US-3 (debug mode), US-4 (level selection) | Success: File created at lib/services/settings/i_settings_service.dart, Interface defines all 7 methods, No syntax errors_

- [x] 4.2. Implement Settings Service
  - File: lib/services/settings/settings_service_impl.dart
  - Estimate: 2 hours | Priority: High
  - Implement settings service with shared_preferences
  - _Requirements: US-3, US-4_
  - _Leverage: Task 2.2 StorageServiceImpl (implementation pattern), Task 4.1 ISettingsService interface, Design document section 4 (design.md lines 529-548)_
  - _Prompt: Role: Flutter Service Implementation Developer | Task: Implement SettingsServiceImpl. Storage keys and defaults: 'default_bpm': 120, 'debug_mode': false, 'classifier_level': 1. Use SharedPreferences, similar to StorageServiceImpl pattern | Restrictions: Must call init() before use, Provide sensible defaults, Validate input (BPM 40-240, level 1-2) | Leverage: Task 2.2 StorageServiceImpl (implementation pattern), Task 4.1 ISettingsService interface, Design document section 4 (design.md lines 529-548) | Requirements: US-3 (debug mode persistence), US-4 (level persistence) | Success: File created at lib/services/settings/settings_service_impl.dart, Implements ISettingsService, All methods use SharedPreferences correctly, Input validation present, No analyzer errors_

- [x] 4.3. Create Settings Screen UI
  - File: lib/ui/screens/settings_screen.dart
  - Estimate: 6 hours | Priority: High
  - Build settings screen with all configuration options
  - _Requirements: US-3, US-4_
  - _Leverage: lib/ui/screens/training_screen.dart (UI patterns), Task 4.2 SettingsServiceImpl, Task 2.2 StorageServiceImpl (for clearing calibration), Design document section 4 (design.md lines 549-650)_
  - _Prompt: Role: Flutter UI Developer | Task: Create SettingsScreen with all settings. UI sections: 1. Default BPM slider (40-240) 2. Debug Mode switch 3. Classifier Level switch (Beginner/Advanced) - Show recalibration warning dialog on change 4. Recalibrate button | Restrictions: Use ListView for scrollable settings, Follow Material Design patterns, Inject ISettingsService and IStorageService, Handle recalibration flow (clear data, navigate) | Leverage: lib/ui/screens/training_screen.dart (UI patterns), Task 4.2 SettingsServiceImpl, Task 2.2 StorageServiceImpl (for clearing calibration), Design document section 4 (design.md lines 549-650) | Requirements: US-3 (debug toggle), US-4 (level selection, recalibrate) | Success: File created at lib/ui/screens/settings_screen.dart, All 4 settings functional, Recalibration warning dialog shows, Settings persist across restarts, Navigates to /calibration when recalibrating_

- [x] 4.4. Add Settings Navigation
  - File: lib/ui/screens/training_screen.dart
  - Estimate: 1 hour | Priority: Medium
  - Add settings button to TrainingScreen AppBar
  - _Requirements: US-3, US-4_
  - _Leverage: lib/ui/screens/training_screen.dart (existing AppBar), Task 4.3 SettingsScreen, Design document navigation examples_
  - _Prompt: Role: Flutter UI Integration Developer | Task: Add settings button to TrainingScreen. Changes: Add IconButton to AppBar actions, Icon: Icons.settings, OnPressed: context.go('/settings') | Restrictions: Do NOT modify existing AppBar title/style, Keep minimal changes | Leverage: lib/ui/screens/training_screen.dart (existing AppBar), Task 4.3 SettingsScreen, Design document navigation examples | Requirements: US-3, US-4 (access settings) | Success: Settings icon in AppBar, Tapping navigates to /settings, Can navigate back to training, No UI regressions_

---

## Phase 5: Debug Mode System (1 week)

- [x] 5.1. Add Rust Debug Streams API
  - File: rust/src/api.rs, rust/src/audio/mod.rs
  - Estimate: 4 hours | Priority: High
  - Add FFI streams for audio metrics and onset events
  - _Requirements: US-3_
  - _Leverage: rust/src/api.rs existing stream patterns (classification_stream), rust/src/context.rs (AppContext broadcast channels), Design document section 3.1 (design.md lines 362-413)_
  - _Prompt: Role: Rust FFI/Backend Developer | Task: Add debug data streams to FFI API. New structs and streams: #[derive(Clone, serde::Serialize, serde::Deserialize)] pub struct AudioMetrics { pub rms: f64; pub spectral_centroid: f64; pub spectral_flux: f64; pub frame_number: u64; pub timestamp: u64; } #[derive(Clone, serde::Serialize, serde::Deserialize)] pub struct OnsetEvent { pub timestamp: u64; pub energy: f64; pub features: AudioFeatures; pub classification: Option<ClassificationResult>; } #[flutter_rust_bridge::frb] pub fn audio_metrics_stream(sink: StreamSink<AudioMetrics>) { TOKIO_RUNTIME.spawn(async move { let stream = APP_CONTEXT.audio_metrics_stream().await; tokio::pin!(stream); while let Some(metrics) = stream.next().await { sink.add(metrics); } }); } #[flutter_rust_bridge::frb] pub fn onset_events_stream(sink: StreamSink<OnsetEvent>) { // Similar pattern }. Also update AppContext to provide these streams | Restrictions: Use same pattern as classification_stream, Do NOT block audio thread, Use broadcast channels for multiple subscribers, Add derives for serde | Leverage: rust/src/api.rs existing stream patterns (classification_stream), rust/src/context.rs (AppContext broadcast channels), Design document section 3.1 (design.md lines 362-413) | Requirements: US-3 (debug data streams) | Success: Two new FFI stream methods in api.rs, AudioMetrics and OnsetEvent structs defined, Streams forward data from audio engine, FFI bridge regenerates successfully, Rust compiles_

- [x] 5.2. Implement Debug Service Interface
  - File: lib/services/debug/i_debug_service.dart
  - Estimate: 1 hour | Priority: High
  - Create interface for debug data access
  - _Requirements: US-3_
  - _Leverage: Task 2.1 IStorageService (interface pattern), Task 5.1 Rust structs, Design document section 3.1 (design.md lines 345-375)_
  - _Prompt: Role: Flutter Service Layer Developer | Task: Create IDebugService interface. Methods: abstract class IDebugService { Stream<AudioMetrics> getAudioMetricsStream(); Stream<OnsetEvent> getOnsetEventsStream(); Future<String> exportLogs(); }. Also define Dart classes matching Rust structs (AudioMetrics, OnsetEvent) | Restrictions: Follow existing interface patterns, Match Rust struct fields exactly, Document all methods | Leverage: Task 2.1 IStorageService (interface pattern), Task 5.1 Rust structs, Design document section 3.1 (design.md lines 345-375) | Requirements: US-3 (debug data access) | Success: File created at lib/services/debug/i_debug_service.dart, Interface defines 3 methods, Dart classes match Rust structs, No syntax errors_

- [x] 5.3. Implement Debug Service
  - File: lib/services/debug/debug_service_impl.dart
  - Estimate: 2 hours | Priority: High
  - Implement debug service wrapping FFI debug streams
  - _Requirements: US-3_
  - _Leverage: Task 5.1 Rust FFI methods, Task 5.2 IDebugService interface, lib/services/audio/audio_service_impl.dart (FFI call pattern), Design document section 3.1_
  - _Prompt: Role: Flutter Service Implementation Developer | Task: Implement DebugServiceImpl. Implementation: getAudioMetricsStream(): call api.audioMetricsStream(), getOnsetEventsStream(): call api.onsetEventsStream(), exportLogs(): serialize recent events to JSON file | Restrictions: Follow existing service patterns, Handle stream errors gracefully, Limit log buffer size (last 1000 events) | Leverage: Task 5.1 Rust FFI methods, Task 5.2 IDebugService interface, lib/services/audio/audio_service_impl.dart (FFI call pattern), Design document section 3.1 | Requirements: US-3 (debug functionality) | Success: File created at lib/services/debug/debug_service_impl.dart, Implements IDebugService, Streams forward FFI data, exportLogs creates JSON file, No errors_

- [x] 5.4. Create Debug Overlay Widget
  - File: lib/ui/widgets/debug_overlay.dart
  - Estimate: 6 hours | Priority: High
  - Build debug overlay UI with real-time metrics
  - _Requirements: US-3_
  - _Leverage: lib/ui/widgets/loading_overlay.dart (overlay pattern), Task 5.3 DebugServiceImpl, Design document section 3.2 (design.md lines 415-497)_
  - _Prompt: Role: Flutter UI Developer | Task: Create DebugOverlay widget with real-time debug UI. UI components: 1. Header with "Debug Metrics" and close button 2. Audio metrics section: RMS level (numerical + bar meter), Spectral centroid, Spectral flux, Frame number 3. Onset events log (scrollable list, last 10 events). Use Stack widget to overlay on top of main content | Restrictions: Use semi-transparent black background (0.85 opacity), Do NOT block touches to underlying UI (use Positioned correctly), StreamBuilder for reactive updates, Inject IDebugService | Leverage: lib/ui/widgets/loading_overlay.dart (overlay pattern), Task 5.3 DebugServiceImpl, Design document section 3.2 (design.md lines 415-497) | Requirements: US-3 (debug visualization) | Success: File created at lib/ui/widgets/debug_overlay.dart, Displays all metrics in real-time, RMS level meter animates, Onset events log scrolls, Close button dismisses overlay, No performance impact on audio_

- [x] 5.5. Integrate Debug Overlay into TrainingScreen
  - File: lib/ui/screens/training_screen.dart
  - Estimate: 2 hours | Priority: High
  - Add debug overlay toggle to training screen
  - _Requirements: US-3_
  - _Leverage: Task 5.4 DebugOverlay widget, Task 4.2 SettingsServiceImpl, lib/ui/screens/training_screen.dart, Design document section 3.3 (design.md lines 499-535)_
  - _Prompt: Role: Flutter Integration Developer | Task: Integrate DebugOverlay into TrainingScreen. Changes: 1. Load debug mode setting from ISettingsService on init 2. If debug mode enabled, wrap build output with DebugOverlay 3. Add toggle in AppBar (debug icon) 4. Pass IDebugService to overlay | Restrictions: Do NOT always show overlay (only when enabled), Inject ISettingsService and IDebugService, Keep existing training UI unchanged | Leverage: Task 5.4 DebugOverlay widget, Task 4.2 SettingsServiceImpl, lib/ui/screens/training_screen.dart, Design document section 3.3 (design.md lines 499-535) | Requirements: US-3 (debug mode integration) | Success: Debug overlay appears when enabled in settings, Toggle button in AppBar, Overlay shows real-time data, No impact when disabled, Settings persistence works_

---

## Phase 6: Real-Time Feedback Enhancements (3 days)

- [x] 6.1. Add Confidence Score to Rust Classifier
  - File: rust/src/analysis/classifier.rs, rust/src/analysis/mod.rs
  - Estimate: 3 hours | Priority: Medium
  - Calculate and return confidence scores with classifications
  - _Requirements: US-2_
  - _Leverage: rust/src/analysis/classifier.rs (existing classification), rust/src/analysis/mod.rs (ClassificationResult struct), Design document section 2.2 (design.md lines 440-474)_
  - _Prompt: Role: Rust Audio/ML Developer | Task: Add confidence score calculation to Classifier. Changes: 1. Add `confidence: f32` field to ClassificationResult struct 2. In classify_level1(), compute confidence as: max_score / (sum of all scores), Clamp to 0.0-1.0 3. Similarly for classify_level2() | Restrictions: Do NOT change classification logic, Confidence must be normalized 0.0-1.0, Handle edge cases (all zeros = 0.0 confidence) | Leverage: rust/src/analysis/classifier.rs (existing classification), rust/src/analysis/mod.rs (ClassificationResult struct), Design document section 2.2 (design.md lines 440-474) | Requirements: US-2 (confidence display) | Success: ClassificationResult has confidence field, Confidence calculated in both level 1 and 2, Values between 0.0 and 1.0, Rust compiles, FFI regenerates, Existing tests still pass_

- [x] 6.2. Enhance Classification Display with Confidence
  - File: lib/ui/screens/training_screen.dart
  - Estimate: 3 hours | Priority: Medium
  - Add confidence meter and fade animation to classification feedback
  - _Requirements: US-2_
  - _Leverage: lib/ui/screens/training_screen.dart (existing display), Task 6.1 confidence field in ClassificationResult, Design document section 2.1 (design.md lines 341-423)_
  - _Prompt: Role: Flutter UI/Animation Developer | Task: Enhance classification display with confidence and animations. Additions: 1. AnimationController for fade-out effect (500ms) 2. Confidence meter below timing feedback: Progress bar (0-100%), Color-coded: green >80%, orange 50-80%, red <50%, Percentage label 3. Restart animation on each new result | Restrictions: Use SingleTickerProviderStateMixin for animation, Do NOT break existing sound/timing display, Dispose animation controller properly, Keep animations smooth (60fps) | Leverage: lib/ui/screens/training_screen.dart (existing display), Task 6.1 confidence field in ClassificationResult, Design document section 2.1 (design.md lines 341-423) | Requirements: US-2 (enhanced feedback with confidence) | Success: Classification display includes confidence meter, Feedback fades out over 500ms, Confidence bar animates smoothly, Color coding works correctly, No jank or dropped frames_

---

## Phase 7: Classifier Level Selection (3 days)

- [x] 7.1. Add Level Field to Rust CalibrationState
  - File: rust/src/calibration/state.rs, rust/src/analysis/classifier.rs
  - Estimate: 2 hours | Priority: Medium
  - Add level field and implement level 2 classification logic
  - _Requirements: US-4_
  - _Leverage: rust/src/calibration/state.rs, rust/src/analysis/classifier.rs (classify_level1 pattern), Design document section 5 (design.md lines 653-686)_
  - _Prompt: Role: Rust Audio/Classification Developer | Task: Add classifier level support to Rust backend. Changes: 1. Add `level: u8` to CalibrationState struct 2. Add level 2 thresholds (closed_hihat, open_hihat, ksnare) 3. Implement classify_level2() method: 6 categories: Kick, Snare, ClosedHiHat, OpenHiHat, KSnare, Silence, Use additional spectral features for subcategories 4. Update classify() to dispatch based on level | Restrictions: Do NOT break existing level 1 logic, Level defaults to 1 if not specified, Add proper serde derives, Level 2 logic can be simplified for UAT (refinement later) | Leverage: rust/src/calibration/state.rs, rust/src/analysis/classifier.rs (classify_level1 pattern), Design document section 5 (design.md lines 653-686) | Requirements: US-4 (advanced mode) | Success: CalibrationState has level field, classify() dispatches based on level, classify_level2() implemented (even if simple), Rust compiles, tests pass, FFI bridge regenerates_

- [x] 7.2. Update Settings Screen with Level Selection
  - File: lib/ui/screens/settings_screen.dart
  - Estimate: 2 hours | Priority: Medium
  - Add classifier level toggle with recalibration warning
  - _Requirements: US-4_
  - _Leverage: Task 4.3 existing SettingsScreen, Task 2.2 StorageService (clearCalibration), Task 4.2 SettingsService (setClassifierLevel), Design document section 4 (design.md lines 583-646)_
  - _Prompt: Role: Flutter UI/UX Developer | Task: Add classifier level selection to SettingsScreen. UI changes: Add SwitchListTile for "Advanced Mode", Title: "Advanced Mode", Subtitle: Current level description (Level 1: "Beginner (3 categories: KICK, SNARE, HIHAT)", Level 2: "Advanced (6 categories with subcategories)"), On change: show confirmation dialog warning about recalibration, If confirmed: save level, clear calibration, navigate to /calibration | Restrictions: Confirmation dialog is REQUIRED, Explain that switching requires recalibration, Do NOT allow switching without clearing calibration | Leverage: Task 4.3 existing SettingsScreen, Task 2.2 StorageService (clearCalibration), Task 4.2 SettingsService (setClassifierLevel), Design document section 4 (design.md lines 583-646) | Requirements: US-4 (level selection, recalibration) | Success: Level toggle appears in settings, Confirmation dialog shows on change, Switching clears calibration and navigates, Level persists across restarts, UI shows correct level description_

---

## Phase 8: Test Infrastructure (1 week)

- [x] 8.1. Create Test Mocks
  - File: test/mocks.dart
  - Estimate: 2 hours | Priority: High
  - Define all mock classes for testing
  - _Requirements: US-5_
  - _Leverage: test/services/audio_service_test.dart (existing mock pattern), All service interfaces (Tasks 2.1, 4.1, 5.2), Design document section 6.2 (design.md lines 540-554)_
  - _Prompt: Role: Test Infrastructure Engineer | Task: Create centralized mocks file. Mocks needed: class MockAudioService extends Mock implements IAudioService {}, class MockStorageService extends Mock implements IStorageService {}, class MockSettingsService extends Mock implements ISettingsService {}, class MockDebugService extends Mock implements IDebugService {}, class MockPermissionService extends Mock implements IPermissionService {} | Restrictions: Use mocktail library, One mock per service interface, Follow existing mock patterns | Leverage: test/services/audio_service_test.dart (existing mock pattern), All service interfaces (Tasks 2.1, 4.1, 5.2), Design document section 6.2 (design.md lines 540-554) | Requirements: US-5 (test infrastructure) | Success: File created at test/mocks.dart, All 5 mocks defined, Mocks compile without errors, Can be imported in test files_

- [x] 8.2. Write Settings Service Tests
  - File: test/services/settings_service_test.dart
  - Estimate: 2 hours | Priority: High
  - Unit tests for SettingsServiceImpl
  - _Requirements: US-5_
  - _Leverage: Task 2.3 storage service tests (test pattern), Task 4.2 SettingsServiceImpl, Design document test examples_
  - _Prompt: Role: Test Engineer | Task: Write comprehensive tests for SettingsServiceImpl. Test cases: 1. Default values returned when no data 2. getBpm/setBpm persistence 3. getDebugMode/setDebugMode persistence 4. getClassifierLevel/setClassifierLevel persistence 5. BPM validation (reject <40 or >240) 6. Level validation (reject <1 or >2) | Restrictions: Use SharedPreferences.setMockInitialValues, Follow existing test patterns, Aim for 100% coverage of settings service | Leverage: Task 2.3 storage service tests (test pattern), Task 4.2 SettingsServiceImpl, Design document test examples | Requirements: US-5 (test coverage) | Success: File created at test/services/settings_service_test.dart, All 6+ test cases pass, Coverage of settings_service_impl.dart is 100%, Tests run in <3 seconds_

- [x] 8.3. Write Widget Tests for New Screens
  - File: Multiple test files
  - Estimate: 6 hours | Priority: High
  - Widget tests for splash, onboarding, and settings screens
  - _Requirements: US-5_
  - _Leverage: test/ui/screens/training_screen_test.dart (widget test patterns), Task 8.1 mocks, Design document section 6 (test patterns)_
  - _Prompt: Role: Flutter Widget Test Engineer | Task: Write widget tests for all new screens. Test files to create: 1. test/ui/screens/splash_screen_test.dart (Test navigation when calibration exists, Test navigation when no calibration, Test error handling) 2. test/ui/screens/onboarding_screen_test.dart (Test UI renders correctly, Test "Start Calibration" navigation) 3. test/ui/screens/settings_screen_test.dart (Test all settings load correctly, Test BPM change persists, Test debug toggle persists, Test level change shows dialog, Test recalibrate button) | Restrictions: Use testWidgets for each case, Mock all services (use Task 8.1 mocks), Use MaterialApp wrapper for navigation context, Verify with tester.pump() and tester.pumpAndSettle() | Leverage: test/ui/screens/training_screen_test.dart (widget test patterns), Task 8.1 mocks, Design document section 6 (test patterns) | Requirements: US-5 (widget test coverage) | Success: 3 test files created, 10+ test cases total, All tests pass, Coverage increases by 15-20%_

- [x] 8.4. Integration Test: Calibration Flow
  - File: test/integration/calibration_flow_test.dart
  - Estimate: 4 hours | Priority: Medium
  - End-to-end integration test for calibration flow
  - _Requirements: US-5_
  - _Leverage: Integration test documentation, All screens (Tasks 3.2, 3.3, 3.4), Design document integration test notes_
  - _Prompt: Role: Integration Test Engineer | Task: Write integration test for full calibration flow. Test flow: 1. Launch app (no calibration) 2. Verify onboarding screen appears 3. Tap "Start Calibration" 4. Complete calibration (mock FFI) 5. Verify data saved to storage 6. Restart app 7. Verify training screen appears (calibration loaded) | Restrictions: Use integration_test package, May need to mock FFI calls (Rust not available in tests), Use real SharedPreferences (not mocked), Clean up storage after test | Leverage: Integration test documentation, All screens (Tasks 3.2, 3.3, 3.4), Design document integration test notes | Requirements: US-5 (integration test coverage) | Success: File created at test/integration/calibration_flow_test.dart, Test completes entire flow, Test passes consistently, Storage cleanup works_

- [x] 8.5. Update Coverage Script and Verify 80% Threshold
  - File: scripts/coverage.sh
  - Estimate: 2 hours | Priority: High
  - Update coverage script to enforce 80% threshold
  - _Requirements: US-5_
  - _Leverage: Existing scripts/coverage.sh (if present), Design document section 6.4 (design.md lines 608-626)_
  - _Prompt: Role: DevOps/CI Engineer | Task: Update coverage script with 80% threshold check. Script requirements: 1. Run `flutter test --coverage` 2. Filter out generated files (frb_generated, bridge_generated) 3. Generate HTML report 4. Extract coverage percentage 5. Exit with error if <80% | Restrictions: Use lcov for filtering and reporting, Exclude generated Dart files, Exclude Rust generated files, Print clear pass/fail message | Leverage: Existing scripts/coverage.sh (if present), Design document section 6.4 (design.md lines 608-626) | Requirements: US-5 (80% coverage requirement) | Success: scripts/coverage.sh updated, Script exits 0 if ≥80% exits 1 if <80%, HTML report generated in coverage/html, Clear output messages, Script is executable_

---

## Phase 9: UAT Documentation & Execution (3 days)

- [x] 9.1. Create UAT Test Scenarios Document
  - File: .spec-workflow/specs/uat-readiness/UAT_TEST_SCENARIOS.md
  - Estimate: 4 hours | Priority: Critical
  - Document all UAT test scenarios with step-by-step instructions
  - _Requirements: US-6_
  - _Leverage: requirements.md user stories, Design document UAT section (design.md lines 687-735)_
  - _Prompt: Role: QA Documentation Specialist | Task: Create comprehensive UAT test scenarios document. Document structure: 1. Test environment (devices, Android versions) 2. 15+ test scenarios covering: First-time user onboarding, Calibration flow, Real-time classification feedback, Debug mode, Settings (BPM, debug, level, recalibrate), Persistence (calibration, settings), Error handling, Performance benchmarks 3. Each scenario has: Prerequisite, Steps (numbered), Expected result, Pass/Fail checkbox 4. Performance benchmark table 5. Sign-off section | Restrictions: Clear step-by-step instructions, Testable by non-developers, Specific measurable expectations, Include edge cases | Leverage: requirements.md user stories, Design document UAT section (design.md lines 687-735) | Requirements: US-6 (UAT documentation) | Success: File created with 15+ scenarios, Each scenario is complete and testable, Performance benchmarks defined, Sign-off checklist present, Formatted in Markdown_

- [-] 9.2. Execute UAT Scenarios on Connected Devices
  - File: UAT_TEST_SCENARIOS.md (updated with results)
  - Estimate: 8 hours (spread over 2 days) | Priority: Critical
  - Run all UAT scenarios on the currently connected Android device(s) (minimum one) and document results
  - _Requirements: US-6_
  - _Leverage: Task 9.1 UAT scenarios document, Build APK: `flutter build apk --debug`, Install: `adb install build/app/outputs/flutter-apk/app-debug.apk`_
  - _Prompt: Role: QA Tester | Task: Execute all UAT scenarios on whichever Android devices are currently connected via ADB (document the model + Android version for each). At least one physical device must be exercised; additional devices are optional but recommended when available. For each scenario: 1. Follow steps exactly 2. Record actual results 3. Mark Pass/Fail 4. Document any issues found 5. Measure performance metrics | Restrictions: Test on clean installs (uninstall/reinstall), Test with airplane mode for offline validation, Record any crashes or errors, Take screenshots of failures | Leverage: Task 9.1 UAT scenarios document, Build APK: `flutter build apk --debug`, Install: `adb install build/app/outputs/flutter-apk/app-debug.apk` | Requirements: US-6 (UAT execution) | Success: All scenarios executed on each connected device (minimum one), Results documented in UAT_TEST_SCENARIOS.md, Performance benchmarks measured, Issues documented with repro steps, Sign-off complete if all pass_

  - _Status Update (2025-11-17)_: Command attempts from the Codex CLI fail before execution. `flutter build apk --debug` cannot update `/home/rmondo/flutter/bin/cache/engine.stamp` (permission denied) and `adb devices` cannot start the daemon (`Operation not permitted`). Manual, on-device execution is still required on a workstation with physical access to the hardware.

- [x] 9.3. Fix Critical UAT Issues (if any)
  - File: Various (depends on issues)
  - Estimate: Variable (1-3 days) | Priority: Critical
  - Fix any critical bugs discovered during UAT
  - _Requirements: All_
  - _Leverage: Task 9.2 issue reports, All existing code and tests, Design document troubleshooting guidance_
  - _Prompt: Role: Full-Stack Developer | Task: Fix critical issues found during UAT execution. Process: 1. Review issues from Task 9.2 2. Prioritize: Critical > High > Medium > Low 3. Fix critical issues first 4. Re-test affected scenarios 5. Update UAT document with retest results | Restrictions: Only fix critical issues (crashes, data loss, blocking bugs), Do NOT add new features, Maintain backward compatibility, Run existing tests after fixes | Leverage: Task 9.2 issue reports, All existing code and tests, Design document troubleshooting guidance | Requirements: All (bug fixes) | Success: All critical issues resolved, No regressions introduced, Tests still pass, UAT scenarios now pass_

- [x] 9.4. Create UAT Sign-Off Report
  - File: .spec-workflow/specs/uat-readiness/UAT_SIGN_OFF_REPORT.md
  - Estimate: 2 hours | Priority: High
  - Summarize UAT results and provide sign-off recommendation
  - _Requirements: US-6_
  - _Leverage: Task 9.2 UAT results, Task 9.3 issue resolutions, requirements.md success criteria_
  - _Prompt: Role: QA Lead | Task: Create UAT sign-off report. Report contents: 1. Executive Summary (Overall pass/fail status, Devices tested, Test duration) 2. Test Results Summary (Scenarios passed/failed, Coverage of requirements) 3. Performance Benchmark Results (Measured vs target for each metric) 4. Known Issues (Remaining bugs if any, Workarounds) 5. Recommendations (Production readiness assessment, Blockers if any) 6. Sign-Off (QA approval, Stakeholder approval section) | Restrictions: Be objective and data-driven, Clearly state any blockers, Provide evidence (test results), Professional formatting | Leverage: Task 9.2 UAT results, Task 9.3 issue resolutions, requirements.md success criteria | Requirements: US-6 (UAT completion) | Success: Report created with all sections, Clear pass/fail recommendation, Data-driven assessment, Sign-off section present, Professional quality_

---

## Summary

**Total Tasks**: 31
**Estimated Duration**: 4-5 weeks (1 developer)

**Critical Path**:
1. Foundation (Tasks 1.x) - 1 day
2. Storage (Tasks 2.x) - 1 week
3. Navigation & Onboarding (Tasks 3.x) - 1 week
4. Settings (Tasks 4.x) - 1 week
5. Debug Mode (Tasks 5.x) - 1 week
6. Enhancements (Tasks 6.x, 7.x) - 1 week
7. Testing (Tasks 8.x) - 1 week
8. UAT (Tasks 9.x) - 3 days

**Success Metrics**:
- All 31 tasks completed
- All tests passing (>80% coverage)
- All UAT scenarios pass on 3 devices
- Performance benchmarks met
- Zero critical bugs

**Next Steps**:
Once this tasks document is approved, you can begin implementation by:
1. Reading each task's _Prompt section
2. Marking task as in-progress (change [ ] to [-])
3. Following the prompt instructions
4. Using log-implementation tool after completion
5. Marking task as complete (change [-] to [x])
