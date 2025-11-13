# UAT Test Scenarios for Beatbox Trainer

## Document Information
- **Version**: 1.0
- **Date Created**: 2025-11-14
- **Purpose**: User Acceptance Testing scenarios for UAT Readiness release
- **Scope**: All features from user stories US-1 through US-6

---

## Test Environment

### Required Devices
Test on a minimum of 3 Android devices with different manufacturers and chipsets:

1. **Primary Test Device**: Pixel 9a (Android 14+)
2. **Secondary Device**: Samsung Galaxy (e.g., S21, S22, or similar - Android 11-13)
3. **Tertiary Device**: Different manufacturer (OnePlus, Xiaomi, Motorola, etc. - Android 11-13)

### Build Information
- **Build Type**: Debug APK
- **Build Command**: `flutter build apk --debug`
- **APK Location**: `build/app/outputs/flutter-apk/app-debug.apk`
- **Installation**: `adb install build/app/outputs/flutter-apk/app-debug.apk`

### Prerequisites
- All test devices have Android API 21 (Lollipop) or higher
- Microphone hardware functional and accessible
- No other apps actively using microphone during tests
- Quiet testing environment for audio calibration/classification accuracy
- ADB installed for APK installation and log collection

### Test Data Cleanup
Before each test scenario requiring "fresh install":
```bash
adb uninstall com.beatbox.trainer  # Adjust package name as needed
adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

## Test Scenarios

### Scenario 1: First-Time User Onboarding Flow

**User Story**: US-1 (Calibration Onboarding Flow)
**Priority**: Critical
**Estimated Duration**: 5-7 minutes

**Prerequisite**:
- Fresh app install (no existing calibration data)
- Microphone permission not yet granted

**Test Steps**:
1. Launch the Beatbox Trainer app
2. Observe the splash screen appears
3. Verify splash screen checks for calibration data
4. Confirm navigation to onboarding screen (no calibration exists)
5. Read onboarding welcome message and calibration explanation
6. Verify 3-step visual guide shows: KICK → SNARE → HI-HAT
7. Tap "Start Calibration" button
8. Grant microphone permission when prompted
9. Verify navigation to calibration screen

**Expected Results**:
- Splash screen displays app logo/loading indicator for <3 seconds
- Onboarding screen appears with clear, friendly messaging
- Visual guide clearly shows 3 calibration steps
- "Start Calibration" button is prominent and clickable
- Microphone permission dialog appears (if not previously granted)
- Smooth navigation to calibration screen after permission grant
- No crashes or error dialogs

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to document any issues, screenshots, or observations]
```

---

### Scenario 2: Complete Calibration Process

**User Story**: US-1 (Calibration Onboarding Flow)
**Priority**: Critical
**Estimated Duration**: 3-5 minutes

**Prerequisite**:
- App launched and navigated to calibration screen
- Microphone permission granted

**Test Steps**:
1. Observe calibration instructions for KICK sound
2. Make KICK sound into microphone 10 times
3. Verify progress indicator shows "KICK: X/10 samples"
4. Verify audio feedback confirms sample collection (visual or auditory)
5. Complete all 10 KICK samples
6. Observe transition to SNARE calibration
7. Make SNARE sound into microphone 10 times
8. Verify progress updates to "SNARE: X/10 samples"
9. Complete all 10 SNARE samples
10. Observe transition to HI-HAT calibration
11. Make HI-HAT sound into microphone 10 times
12. Verify progress updates to "HIHAT: X/10 samples"
13. Complete all 10 HI-HAT samples
14. Verify success message/dialog appears
15. Verify automatic navigation to training screen

**Expected Results**:
- Clear instructions for each sound type (KICK, SNARE, HI-HAT)
- Progress indicator updates in real-time (within 200ms of each sample)
- Audio feedback confirms each sample collected
- Smooth transitions between calibration phases
- Total calibration time <2 minutes for 30 samples
- Success message clearly indicates completion
- Calibration data persists (verified in subsequent scenarios)
- Navigation to training screen is automatic
- No crashes, hangs, or error dialogs

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to document any issues, total calibration time, sample recognition accuracy]
```

---

### Scenario 3: Calibration Persistence Across App Restarts

**User Story**: US-1 (Calibration Onboarding Flow)
**Priority**: Critical
**Estimated Duration**: 2 minutes

**Prerequisite**:
- Calibration completed in Scenario 2
- App currently showing training screen

**Test Steps**:
1. Force-close the app (swipe away from recent apps)
2. Wait 5 seconds
3. Relaunch the app
4. Observe splash screen
5. Verify navigation directly to training screen (skip onboarding)
6. Verify no calibration prompts appear

**Expected Results**:
- Splash screen appears briefly (<3 seconds)
- Calibration data is detected automatically
- App navigates directly to training screen
- No onboarding or calibration screens shown
- Previous calibration still functional (test in Scenario 4)

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to document any issues]
```

---

### Scenario 4: Real-Time Classification with Timing Feedback

**User Story**: US-2 (Real-Time Classification Feedback)
**Priority**: Critical
**Estimated Duration**: 5 minutes

**Prerequisite**:
- Calibration complete
- Training screen visible

**Test Steps**:
1. Tap "Start" button on training screen
2. Verify metronome/beat indicator starts
3. Make KICK sound on beat
4. Observe classification result appears within 100ms
5. Verify sound type displayed (KICK) with color coding
6. Verify timing feedback shows milliseconds (e.g., "+15ms" or "-10ms")
7. Verify color-coded timing: GREEN (on-time), YELLOW (early/late), RED (very off)
8. Verify confidence meter shows percentage bar below feedback
9. Verify confidence bar is color-coded: green >80%, orange 50-80%, red <50%
10. Verify feedback persists for at least 500ms
11. Verify feedback fades out smoothly over 500ms
12. Make SNARE sound on beat
13. Verify classification updates immediately to SNARE
14. Make HI-HAT sound on beat
15. Verify classification updates immediately to HIHAT
16. Make sounds OFF beat (early/late)
17. Verify timing feedback shows correct deviation (+/- ms)
18. Tap "Stop" button
19. Verify metronome stops and feedback clears

**Expected Results**:
- Classification latency <100ms from sound to display update
- Sound type (KICK/SNARE/HIHAT) displayed prominently
- Timing accuracy shown in milliseconds with +/- indicator
- Color coding matches timing accuracy (green/yellow/red)
- Confidence meter displays percentage (0-100%)
- Confidence bar color-coded correctly based on value
- Feedback persists minimum 500ms for readability
- Smooth fade-out animation (no abrupt disappearance)
- UI updates are smooth with no jank or stuttering
- No dropped frames during continuous classification
- Stop button halts classification immediately

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to measure latency, note any misclassifications, UI jank]
```

---

### Scenario 5: Debug Mode Activation and Real-Time Metrics

**User Story**: US-3 (Debug Mode for Troubleshooting)
**Priority**: High
**Estimated Duration**: 5 minutes

**Prerequisite**:
- App running on training screen
- Training session active (metronome running)

**Test Steps**:
1. Tap settings icon in AppBar
2. Navigate to settings screen
3. Locate "Debug Mode" toggle switch
4. Enable debug mode
5. Navigate back to training screen
6. Verify debug overlay appears on screen
7. Verify debug overlay shows header "Debug Metrics"
8. Verify close button (X) is visible
9. Observe audio metrics section displays:
   - RMS level (numerical value)
   - RMS level meter (visual bar)
   - Spectral centroid value
   - Spectral flux value
   - Frame number counter
10. Make sounds (KICK, SNARE, HIHAT)
11. Verify onset events log section displays:
    - Last 10 onset events in scrollable list
    - Each event shows: timestamp, energy, classification
12. Verify RMS meter animates in real-time
13. Verify frame number increments continuously
14. Tap close button (X) on debug overlay
15. Verify overlay dismisses
16. Tap debug icon in AppBar to re-show overlay

**Expected Results**:
- Settings screen has "Debug Mode" toggle clearly labeled
- Debug overlay appears as semi-transparent overlay (0.85 opacity)
- Overlay does NOT block touches to underlying UI
- All audio metrics display with real-time updates:
  - RMS level updates at least 10 times per second
  - RMS meter bar animates smoothly
  - Spectral centroid and flux update on onset events
- Frame number increments continuously (proves real-time stream)
- Onset events log shows last 10 events:
  - Timestamps are monotonically increasing
  - Energy values are reasonable (>0)
  - Classifications match actual sounds made
- Onset events log is scrollable
- Close button dismisses overlay immediately
- Debug icon in AppBar toggles overlay visibility
- No performance impact on audio processing or classification
- No audio stuttering or dropped frames when debug mode active

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to note performance issues, metric accuracy, UI responsiveness]
```

---

### Scenario 6: Debug Log Export

**User Story**: US-3 (Debug Mode for Troubleshooting)
**Priority**: Medium
**Estimated Duration**: 3 minutes

**Prerequisite**:
- Debug mode enabled
- Several onset events logged (from previous scenario)

**Test Steps**:
1. Navigate to settings screen
2. Locate "Export Debug Logs" button/option
3. Tap export button
4. Verify file picker or share dialog appears
5. Save exported logs to device storage or share via method (e.g., email)
6. Open exported log file
7. Verify file format is JSON
8. Verify log contains:
   - Onset events with timestamps
   - Audio metrics samples
   - Classification results
9. Verify log is limited to reasonable size (last 1000 events)

**Expected Results**:
- Export button is discoverable in settings or debug overlay
- Export completes within 2 seconds
- Exported file is valid JSON format
- Log file contains structured data:
  - Timestamps (ISO 8601 or Unix time)
  - Audio metrics (RMS, centroid, flux)
  - Onset events with classifications
  - Confidence scores
- Log buffer is limited to prevent huge files (last 1000 events)
- No sensitive data (PII) in logs
- File can be opened in text editor or JSON viewer

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to attach sample log file or note formatting issues]
```

---

### Scenario 7: Settings - Default BPM Configuration

**User Story**: US-3, US-4 (Settings & Configuration)
**Priority**: High
**Estimated Duration**: 3 minutes

**Prerequisite**:
- App running on training screen

**Test Steps**:
1. Tap settings icon in AppBar
2. Navigate to settings screen
3. Locate "Default BPM" slider
4. Verify current BPM value is displayed (default: 120)
5. Drag slider to minimum value (40 BPM)
6. Verify displayed value updates to 40
7. Drag slider to maximum value (240 BPM)
8. Verify displayed value updates to 240
9. Set slider to 90 BPM
10. Navigate back to training screen
11. Tap "Start" button
12. Verify metronome tempo matches ~90 BPM (use stopwatch: 1 beat every 666ms)
13. Stop training and navigate to settings
14. Verify BPM slider still shows 90 (persistence check)
15. Force-close app and relaunch
16. Navigate to settings
17. Verify BPM slider still shows 90 (persistence across restarts)

**Expected Results**:
- BPM slider is clearly labeled in settings
- Slider range is 40-240 BPM
- Current value is displayed numerically
- Slider updates value immediately on drag
- Slider rejects values outside range (40-240)
- BPM setting persists across screen navigation
- BPM setting persists across app restarts
- Metronome tempo in training screen matches selected BPM
- No lag or delay when adjusting slider

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to note slider responsiveness, BPM accuracy]
```

---

### Scenario 8: Settings - Classifier Level Selection (Beginner to Advanced)

**User Story**: US-4 (Classifier Level Selection)
**Priority**: High
**Estimated Duration**: 5 minutes

**Prerequisite**:
- Calibration complete at Level 1 (Beginner mode)
- App on settings screen

**Test Steps**:
1. Locate "Advanced Mode" switch in settings
2. Verify switch is currently OFF
3. Verify subtitle shows "Beginner (3 categories: KICK, SNARE, HIHAT)"
4. Tap switch to enable Advanced Mode
5. Verify confirmation dialog appears with title "Recalibration Required"
6. Verify dialog message explains:
   - Switching requires recalibration
   - Current calibration will be cleared
7. Verify dialog has "Cancel" and "Recalibrate" buttons
8. Tap "Cancel" button
9. Verify dialog dismisses and switch remains OFF
10. Tap switch again to enable Advanced Mode
11. Tap "Recalibrate" button in dialog
12. Verify navigation to calibration screen
13. Complete calibration for Level 2 (6 categories)
14. Verify training screen loads after calibration
15. Navigate back to settings
16. Verify "Advanced Mode" switch is now ON
17. Verify subtitle shows "Advanced (6 categories with subcategories)"
18. Force-close app and relaunch
19. Navigate to settings
20. Verify "Advanced Mode" switch is still ON (persistence)

**Expected Results**:
- "Advanced Mode" switch clearly labeled in settings
- Subtitle accurately describes current level:
  - Level 1: "Beginner (3 categories: KICK, SNARE, HIHAT)"
  - Level 2: "Advanced (6 categories with subcategories)"
- Confirmation dialog is REQUIRED when switching levels
- Dialog clearly warns about recalibration and data clearing
- "Cancel" button dismisses dialog without changes
- "Recalibrate" button clears calibration and navigates to calibration screen
- Level preference persists across app restarts
- UI adapts to show appropriate categories in training (Level 2 shows subcategories)
- No crashes or data corruption when switching levels

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to note level switching behavior, recalibration completion]
```

---

### Scenario 9: Settings - Recalibrate Button

**User Story**: US-1, US-4 (Calibration & Settings)
**Priority**: High
**Estimated Duration**: 4 minutes

**Prerequisite**:
- Existing calibration data present (any level)
- App on settings screen

**Test Steps**:
1. Locate "Recalibrate" button in settings
2. Verify button shows subtitle "Clear calibration and start over"
3. Tap "Recalibrate" button
4. Verify confirmation dialog appears with title "Confirm Recalibration"
5. Verify dialog message explains "This will clear your current calibration"
6. Verify dialog has "Cancel" and "Confirm" buttons
7. Tap "Cancel" button
8. Verify dialog dismisses and no action taken
9. Tap "Recalibrate" button again
10. Tap "Confirm" button in dialog
11. Verify navigation to calibration screen
12. Verify calibration screen shows fresh state (0/10 samples)
13. Complete recalibration
14. Verify training screen loads with new calibration data

**Expected Results**:
- "Recalibrate" button is discoverable in settings
- Button has clear icon (e.g., refresh/reset icon)
- Confirmation dialog is REQUIRED to prevent accidental recalibration
- Dialog clearly explains action (clearing calibration)
- "Cancel" button dismisses dialog without changes
- "Confirm" button clears existing calibration
- Navigation to calibration screen after confirmation
- Calibration screen starts fresh (no residual data)
- New calibration data replaces old data
- No data corruption or persistence issues

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to note recalibration flow, data clearing]
```

---

### Scenario 10: Navigation - Settings Access from Training Screen

**User Story**: US-3, US-4 (Settings Navigation)
**Priority**: Medium
**Estimated Duration**: 2 minutes

**Prerequisite**:
- App on training screen

**Test Steps**:
1. Locate settings icon in AppBar (top-right)
2. Verify icon is a standard settings icon (gear/cog)
3. Tap settings icon
4. Verify navigation to settings screen
5. Verify AppBar shows "Back" button or arrow
6. Modify any setting (e.g., BPM)
7. Tap "Back" button
8. Verify navigation back to training screen
9. Verify training screen state is preserved (if training was active, it continues)

**Expected Results**:
- Settings icon is discoverable in AppBar (top-right corner)
- Icon is standard Material Design settings icon
- Tapping navigates to settings screen smoothly
- Settings screen has back navigation (AppBar back button)
- Back navigation returns to training screen
- Training screen state is preserved (no interruption to active session)
- No animation jank or lag during navigation

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to note navigation smoothness, state preservation]
```

---

### Scenario 11: Error Handling - Microphone Permission Denied

**User Story**: US-1, NFR-2 (Reliability)
**Priority**: Critical
**Estimated Duration**: 3 minutes

**Prerequisite**:
- Fresh app install (no calibration)
- Microphone permission NOT granted

**Test Steps**:
1. Launch app and navigate to calibration screen
2. When microphone permission dialog appears, tap "Deny"
3. Verify error dialog appears explaining permission is required
4. Verify error dialog has actionable message (e.g., "Open Settings")
5. Tap "Open Settings" button
6. Verify Android settings app opens to app permissions
7. Grant microphone permission
8. Return to Beatbox Trainer app
9. Verify app detects permission and allows calibration to proceed

**Expected Results**:
- Permission denial is detected immediately
- Error dialog appears with clear, user-friendly message
- Message explains WHY permission is needed (not just "permission denied")
- Dialog provides actionable solution (e.g., "Open Settings" button)
- Tapping button opens Android settings to correct location
- App detects permission grant without requiring restart
- No crashes or infinite permission request loops
- Error message is non-technical and friendly

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to note error message clarity, recovery flow]
```

---

### Scenario 12: Error Handling - Audio Stream Interruption

**User Story**: NFR-2 (Reliability)
**Priority**: High
**Estimated Duration**: 5 minutes

**Prerequisite**:
- App running in training mode with active session
- Another phone available to call test device

**Test Steps**:
1. Start training session (tap "Start" button)
2. Verify metronome and classification are working
3. Receive an incoming phone call on test device
4. Verify app pauses or handles interruption gracefully
5. Decline or end the phone call
6. Return to Beatbox Trainer app
7. Verify app automatically resumes audio stream
8. Verify classification functionality restored
9. Make test sounds (KICK, SNARE, HIHAT)
10. Verify classification works correctly post-interruption
11. Repeat test with notification sound (text message, alarm, etc.)
12. Verify app handles notification interruption gracefully

**Expected Results**:
- Incoming call does not crash app
- App detects audio interruption (phone call)
- Training session pauses automatically during call
- No error dialogs during interruption
- App automatically resumes audio stream after interruption ends
- Classification functionality restored immediately (<3 seconds)
- No need to manually restart training session
- Notification sounds also handled gracefully
- No audio stream corruption or persistent errors
- User can continue training without app restart

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to note recovery time, any persistent issues]
```

---

### Scenario 13: Edge Case - Rapid Sound Classification

**User Story**: US-2, NFR-1 (Performance)
**Priority**: Medium
**Estimated Duration**: 3 minutes

**Prerequisite**:
- Calibration complete
- Training screen with active session

**Test Steps**:
1. Start training session
2. Make rapid sounds in quick succession (KICK-SNARE-KICK-HIHAT as fast as possible)
3. Observe classification updates
4. Verify each sound is classified (no dropped detections)
5. Verify UI updates smoothly without jank
6. Verify no UI freezing or lag
7. Continue rapid sounds for 30 seconds
8. Verify app performance remains stable (no crashes, no slowdown)

**Expected Results**:
- Rapid sounds (>5 per second) are detected
- Each sound is classified individually (no merging)
- UI updates for each classification without lag
- No dropped frames or UI stuttering
- Confidence scores and timing feedback update correctly
- No memory leaks or performance degradation over time
- CPU usage remains <40% (check in Android Developer Options)
- No crashes or hangs during stress test

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to note maximum sounds per second detected, performance issues]
```

---

### Scenario 14: Edge Case - Background and Foreground Transitions

**User Story**: NFR-2 (Reliability)
**Priority**: Medium
**Estimated Duration**: 4 minutes

**Prerequisite**:
- App running in training mode with active session

**Test Steps**:
1. Start training session (tap "Start" button)
2. Verify audio and classification working
3. Press Home button (send app to background)
4. Wait 10 seconds
5. Reopen app from recent apps
6. Verify app returns to training screen
7. Verify training session state preserved (still running)
8. Make test sound (KICK)
9. Verify classification still works
10. Repeat: send to background, wait 1 minute, return to foreground
11. Verify app still functional after longer background duration

**Expected Results**:
- App handles background transition gracefully
- Training session state preserved during short background duration (<1 minute)
- Audio stream resumes automatically when returning to foreground
- Classification functionality restored immediately
- No crashes or data loss during background/foreground transitions
- Long background duration (>1 minute) may stop session (acceptable) but app remains stable
- User can restart session if stopped during long background

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to note state preservation, audio stream behavior]
```

---

### Scenario 15: Edge Case - Settings Persistence and Validation

**User Story**: US-3, US-4 (Settings Validation)
**Priority**: Medium
**Estimated Duration**: 5 minutes

**Prerequisite**:
- App on settings screen

**Test Steps**:
1. Attempt to set BPM to extreme values:
   - Drag slider below 40 (verify slider stops at 40)
   - Drag slider above 240 (verify slider stops at 240)
2. Set BPM to valid value (e.g., 150)
3. Enable Debug Mode
4. Enable Advanced Mode (complete recalibration if prompted)
5. Force-close app (swipe away from recent apps)
6. Relaunch app
7. Navigate to settings
8. Verify all settings persisted correctly:
   - BPM: 150
   - Debug Mode: ON
   - Advanced Mode: ON
9. Uninstall app completely
10. Reinstall app
11. Navigate to settings
12. Verify settings reset to defaults:
    - BPM: 120
    - Debug Mode: OFF
    - Advanced Mode: OFF (Level 1)

**Expected Results**:
- BPM slider enforces range validation (40-240)
- Slider cannot be set to invalid values
- All settings persist across app restarts:
  - Default BPM
  - Debug mode state
  - Classifier level
- Settings stored in SharedPreferences
- App uninstall clears all settings and calibration data
- Fresh install starts with default settings
- No settings corruption or invalid state persistence

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes/Issues**:
```
[Space for tester to note validation behavior, persistence correctness]
```

---

### Scenario 16: Accessibility - Screen Reader Support (Optional)

**User Story**: Accessibility (NFR-3)
**Priority**: Low
**Estimated Duration**: 5 minutes

**Prerequisite**:
- TalkBack (Android screen reader) enabled in device settings
- App on training screen

**Test Steps**:
1. Navigate through training screen using TalkBack swipe gestures
2. Verify all buttons have semantic labels:
   - Start/Stop button
   - Settings icon
3. Tap buttons using TalkBack double-tap
4. Verify buttons are activated correctly
5. Navigate to settings screen
6. Verify all settings controls have labels:
   - BPM slider
   - Debug Mode switch
   - Advanced Mode switch
   - Recalibrate button
7. Verify classification feedback is announced (if possible)

**Expected Results**:
- All interactive elements have meaningful semantic labels
- TalkBack announces button labels correctly
- All controls are activatable via TalkBack double-tap
- Settings controls announce current values
- UI elements have proper focus order
- No unlabeled buttons or controls

**Pass/Fail**: ☐ Pass ☐ Fail (or ☐ Not Tested if accessibility testing not required)

**Notes/Issues**:
```
[Space for tester to note accessibility issues, missing labels]
```

---

## Performance Benchmarks

Measure the following performance metrics on each test device during active training sessions. Use Android Developer Options and profiling tools as needed.

| Metric | Target | Pixel 9a | Device 2 | Device 3 | Pass/Fail |
|--------|--------|----------|----------|----------|-----------|
| **Audio Callback Latency (P99)** | <10ms | ____ms | ____ms | ____ms | ☐ Pass ☐ Fail |
| **UI Classification Update Latency** | <100ms | ____ms | ____ms | ____ms | ☐ Pass ☐ Fail |
| **App Launch Time (Cold Start)** | <3 seconds | ____s | ____s | ____s | ☐ Pass ☐ Fail |
| **Memory Usage (Active Training)** | <150MB | ____MB | ____MB | ____MB | ☐ Pass ☐ Fail |
| **CPU Usage (Sustained Training)** | <40% | ____% | ____% | ____% | ☐ Pass ☐ Fail |
| **Calibration Completion Time** | <2 minutes | ____s | ____s | ____s | ☐ Pass ☐ Fail |

**Measurement Notes**:
- **Audio Callback Latency**: Use Android Studio Profiler or debug logs (if available)
- **UI Update Latency**: Use stopwatch to measure sound to display update (user perception)
- **App Launch Time**: Measure from tap to training screen visible (with existing calibration)
- **Memory Usage**: Check in Android Developer Options → Memory or use Android Studio Profiler
- **CPU Usage**: Check in Android Developer Options → Running Services or use Android Studio Profiler
- **Calibration Time**: Use stopwatch from first sample to completion (30 samples total)

---

## Known Limitations

Document any known limitations discovered during testing that do not constitute bugs:

1. **Background Audio Handling**: Training session may stop after >1 minute in background (expected behavior to conserve resources)
2. **Device Variability**: Microphone sensitivity varies by device; calibration may require different sound volumes
3. **Debug Mode Performance**: Debug overlay may slightly increase CPU usage (acceptable tradeoff)
4. **Level 2 Classification**: Advanced mode (Level 2) may have lower accuracy initially (calibration quality dependent)

---

## Critical Bugs Log

Use this section to document any critical bugs found during testing that block UAT sign-off:

| Bug ID | Scenario | Description | Severity | Steps to Reproduce | Status |
|--------|----------|-------------|----------|-------------------|--------|
| BUG-001 | [Scenario #] | [Brief description] | Critical/High/Medium | [Steps] | Open/Fixed |

**Example**:
| Bug ID | Scenario | Description | Severity | Steps to Reproduce | Status |
|--------|----------|-------------|----------|-------------------|--------|
| BUG-001 | Scenario 4 | Classification latency >500ms on Samsung Galaxy S21 | High | 1. Start training session 2. Make KICK sound 3. Observe >500ms delay | Open |

---

## Test Execution Summary

### Device Test Matrix

| Scenario | Pixel 9a | Device 2 | Device 3 | Overall |
|----------|----------|----------|----------|---------|
| 1. First-Time Onboarding | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 2. Complete Calibration | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 3. Calibration Persistence | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 4. Real-Time Classification | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 5. Debug Mode Activation | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 6. Debug Log Export | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 7. Settings - BPM | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 8. Settings - Level Selection | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 9. Settings - Recalibrate | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 10. Settings Navigation | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 11. Error - Permission Denied | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 12. Error - Audio Interruption | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 13. Edge - Rapid Classification | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 14. Edge - Background Transitions | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 15. Edge - Settings Validation | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |
| 16. Accessibility (Optional) | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F | ☐ P ☐ F |

**Legend**: P = Pass, F = Fail

---

## UAT Sign-Off Checklist

UAT is considered complete when ALL of the following criteria are met:

- [ ] All 15 mandatory test scenarios (1-15) passed on Pixel 9a
- [ ] All 15 mandatory test scenarios (1-15) passed on Device 2 (Samsung or equivalent)
- [ ] All 15 mandatory test scenarios (1-15) passed on Device 3 (different manufacturer)
- [ ] All performance benchmarks met on at least 2 of 3 devices
- [ ] Zero critical bugs identified (crashes, data loss, blocking issues)
- [ ] All high-severity bugs documented with reproduction steps
- [ ] Known limitations documented and accepted by stakeholders
- [ ] Test execution summary completed for all devices
- [ ] Debug logs collected for any failures

---

## Sign-Off

### QA Engineer Approval

**Name**: _______________________________
**Signature**: _______________________________
**Date**: _______________________________

**Overall Assessment**: ☐ **APPROVED** - Ready for production
                       ☐ **CONDITIONAL APPROVAL** - Minor issues acceptable, see notes
                       ☐ **REJECTED** - Critical issues must be fixed before release

**Notes**:
```
[QA engineer notes and recommendations]
```

---

### Stakeholder Approval

**Name**: _______________________________
**Signature**: _______________________________
**Date**: _______________________________

**Decision**: ☐ **APPROVED** for production release
             ☐ **REQUIRES CHANGES** - see notes

**Notes**:
```
[Stakeholder notes and business acceptance]
```

---

## Appendix

### Test Data

**Test Sounds**: For consistent calibration testing, use:
- **KICK**: Vocal bass drum sound (low frequency, short burst)
- **SNARE**: Vocal snare sound (mid-high frequency, sharp attack)
- **HI-HAT**: Vocal cymbal sound (high frequency, short duration)

### Useful ADB Commands

```bash
# Install APK
adb install build/app/outputs/flutter-apk/app-debug.apk

# Uninstall app (clear all data)
adb uninstall com.beatbox.trainer

# Collect logcat logs
adb logcat -d > beatbox_logcat.txt

# Check app memory usage
adb shell dumpsys meminfo com.beatbox.trainer

# Grant microphone permission manually
adb shell pm grant com.beatbox.trainer android.permission.RECORD_AUDIO

# Revoke microphone permission
adb shell pm revoke com.beatbox.trainer android.permission.RECORD_AUDIO

# Check app CPU usage
adb shell top -n 1 | grep com.beatbox.trainer
```

### Contact Information

**For UAT Issues or Questions**:
- Developer: [Name/Email]
- QA Lead: [Name/Email]
- Project Manager: [Name/Email]

---

**Document Version History**:
- v1.0 (2025-11-14): Initial UAT test scenarios document created
