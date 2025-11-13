# Requirements: UAT Readiness for Beatbox Trainer

## Overview
Make the Beatbox Trainer app ready for User Acceptance Testing (UAT) by implementing critical missing features, fixing identified issues, adding comprehensive debug capabilities, and establishing a complete testing framework.

## Background
**Current Status:**
- ✅ Audio engine working (Oboe with stereo output, mono input)
- ✅ FFI bridge functional (after regeneration)
- ✅ Core classification logic implemented
- ❌ No calibration UI (classifier cannot work without calibration)
- ❌ No visual feedback during training (users see "Listening..." but no responses)
- ❌ Missing debug logging for troubleshooting
- ❌ No test coverage metrics
- ❌ No UAT test scenarios documented

**Root Cause Analysis:**
The classification system requires calibration to establish thresholds for KICK, SNARE, and HI-HAT detection. Without calibration data, the classifier cannot identify sounds, resulting in zero feedback to users.

## Goals
1. **Enable End-to-End User Flow**: Users can calibrate, train, and see real-time feedback
2. **Debug Visibility**: Comprehensive logging at all system levels (Rust, Dart, UI)
3. **Test Coverage**: Establish testing infrastructure with >80% coverage
4. **UAT Documentation**: Clear test scenarios and acceptance criteria
5. **Production Readiness**: Fix all high-priority issues from audit

## User Stories

### US-1: Calibration Onboarding Flow
**As a** new user
**When** I launch the app for the first time
**Then** I am guided through calibration before accessing training mode

**Acceptance Criteria:**
- Welcome screen explains calibration purpose
- Step-by-step instructions for KICK → SNARE → HI-HAT
- Visual progress indicator (e.g., "KICK: 7/10 samples")
- Audio feedback confirms sample collection
- Calibration data persists across app restarts
- Option to recalibrate from settings

**EARS Criteria:**
- **WHILE** app detects no calibration data exists
- **WHEN** user launches the app
- **THEN** the app **SHALL** display calibration onboarding screen
- **AND** prevent access to training mode until calibration completes

### US-2: Real-Time Classification Feedback
**As a** user practicing beatbox
**When** I make a sound into the microphone
**Then** I see immediate visual feedback showing what sound was detected and timing accuracy

**Acceptance Criteria:**
- Sound type displayed prominently (KICK/SNARE/HIHAT/UNKNOWN)
- Color-coded timing feedback (GREEN=on-time, YELLOW=early/late, RED=very off)
- Timing error shown in milliseconds with +/- indicator
- Feedback persists for 500ms minimum for readability
- Smooth transitions between classifications
- No lag or stuttering in UI updates

**EARS Criteria:**
- **WHILE** training mode is active and calibration exists
- **WHEN** onset detector identifies a sound above threshold
- **THEN** the app **SHALL** classify the sound within 100ms
- **AND** update the UI with classification result and timing feedback
- **AND** the feedback **SHALL** remain visible for at least 500ms

### US-3: Debug Mode for Troubleshooting
**As a** developer or power user
**When** I enable debug mode
**Then** I see detailed real-time metrics about audio processing and classification

**Acceptance Criteria:**
- Toggle for debug mode in settings
- Real-time audio level meter (RMS visualization)
- Onset detection events logged with timestamps
- Feature values displayed (RMS, spectral centroid, flux)
- Classification confidence scores shown
- Frame timing and latency metrics
- Export debug logs to file for analysis

**EARS Criteria:**
- **WHILE** debug mode is enabled
- **WHEN** audio engine is running
- **THEN** the app **SHALL** display:
  - Current audio input level (RMS)
  - Onset detection events with timestamps
  - Extracted feature values for each onset
  - Classification results with confidence scores
  - Audio callback timing metrics
- **AND** log all events to persistent storage

### US-4: Classifier Level Selection
**As a** user
**When** I complete basic training
**Then** I can enable advanced mode (Level 2) for more detailed sound categories

**Acceptance Criteria:**
- Settings toggle for "Beginner/Advanced" mode
- Beginner: 3 categories (KICK, SNARE, HIHAT)
- Advanced: 6 categories (Kick, Snare, ClosedHiHat, OpenHiHat, KSnare, Silence)
- Recalibration required when switching levels
- UI adapts to show appropriate categories
- Level preference persists across sessions

**EARS Criteria:**
- **WHILE** user is in settings screen
- **WHEN** user toggles difficulty level
- **THEN** the app **SHALL** update CalibrationState with new level
- **AND** prompt for recalibration if switching from Level 1 to Level 2
- **AND** persist level preference to local storage

### US-5: Automated Test Suite
**As a** developer
**When** I run the test suite
**Then** all unit tests, integration tests, and widget tests pass with >80% coverage

**Acceptance Criteria:**
- Unit tests for all services (AudioService, PermissionService, ErrorHandler)
- Widget tests for all screens (TrainingScreen, CalibrationScreen, SettingsScreen)
- Integration tests for audio engine lifecycle
- Mock implementations for dependencies
- Coverage reports generated automatically
- CI/CD pipeline runs tests on every commit
- All tests complete in <3 minutes

**EARS Criteria:**
- **WHEN** developer runs `flutter test`
- **THEN** the test suite **SHALL** execute all test cases
- **AND** achieve minimum 80% code coverage
- **AND** complete within 180 seconds
- **AND** generate HTML coverage report

### US-6: UAT Test Scenarios Documentation
**As a** QA tester
**When** I receive the app for UAT
**Then** I have clear test scenarios covering all critical user paths

**Acceptance Criteria:**
- Test scenarios document with step-by-step instructions
- Expected results for each scenario
- Edge cases and error scenarios included
- Acceptance criteria for pass/fail
- Test data and prerequisites specified
- Known limitations documented
- Sign-off checklist for UAT completion

**EARS Criteria:**
- **WHEN** UAT phase begins
- **THEN** documentation **SHALL** exist containing:
  - Minimum 15 test scenarios covering all user stories
  - Clear pass/fail criteria for each scenario
  - Instructions for reproducing issues
  - Performance benchmarks (latency, CPU, memory)
  - Device compatibility matrix

## Non-Functional Requirements

### NFR-1: Performance
- Audio callback latency: <10ms (P99)
- UI classification updates: <100ms from onset detection
- Calibration completion time: <2 minutes for 30 samples
- App launch time: <3 seconds on mid-range devices
- Memory usage: <150MB during active training
- CPU usage: <40% sustained during training

### NFR-2: Reliability
- No crashes during 30-minute continuous training session
- Graceful handling of all audio permission states
- Automatic recovery from audio stream interruptions (calls, notifications)
- Data persistence survives app crashes
- Error messages are user-friendly and actionable

### NFR-3: Usability
- Onboarding flow completable in <3 minutes
- All buttons and controls have clear labels
- Feedback is visual and unambiguous
- Settings are discoverable and intuitive
- No jargon in user-facing text

### NFR-4: Maintainability
- Code coverage: >80% (>90% for critical paths)
- All public APIs documented
- Architecture diagrams included in docs
- Dependency injection used throughout
- No global state beyond necessary singletons
- Maximum 500 lines per file
- Maximum 50 lines per function

### NFR-5: Testability
- All services mockable via interfaces
- UI components accept dependency-injected services
- No direct references to FFI or platform channels in UI
- Test data builders for complex objects
- Integration test harness for audio engine

## Dependencies
- **Existing**: oboe-rs, flutter_rust_bridge, permission_handler, tokio
- **New**: shared_preferences (for calibration persistence), fl_chart (for debug visualizations)

## Constraints
- Android only (iOS support future work)
- Minimum Android API 21 (Lollipop)
- Requires microphone hardware
- Real-time audio processing (no offline mode)
- Must work without internet connection

## Success Metrics
1. **Feature Complete**: All 6 user stories implemented and tested
2. **Zero Critical Bugs**: No crashes, hangs, or data loss
3. **Test Coverage**: >80% overall, >90% on critical paths
4. **UAT Sign-Off**: All test scenarios pass on 3 different Android devices
5. **Performance**: All NFRs met on Pixel 9a test device

## Out of Scope
- iOS support
- Multi-user accounts
- Cloud sync
- Social features (sharing, leaderboards)
- Advanced audio effects (reverb, EQ)
- Batch calibration import/export
- Machine learning model customization

## Risks
1. **Audio Hardware Variability**: Different Android devices may have different mic characteristics
   - Mitigation: Test on min 3 devices with different chipsets
2. **Real-Time Performance**: Low-end devices may not meet latency requirements
   - Mitigation: Establish minimum device specs, graceful degradation
3. **Calibration UX Complexity**: Users may not understand calibration importance
   - Mitigation: Clear onboarding with video/animation tutorials
4. **Test Coverage Gaps**: Hard-to-test real-time audio code
   - Mitigation: Use mock audio streams, integration test harness

## Glossary
- **UAT**: User Acceptance Testing - final validation before production release
- **Onset**: The beginning of a sound event, detected by energy increase
- **Calibration**: Process of collecting samples to establish classification thresholds
- **RMS**: Root Mean Square - measure of audio signal amplitude
- **Spectral Centroid**: "Center of mass" of audio spectrum, indicates brightness
- **Spectral Flux**: Measure of how quickly the audio spectrum changes
- **FFI**: Foreign Function Interface - Dart-to-Rust communication layer
