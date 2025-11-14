# UAT Testing Guide - Beatbox Trainer

**Purpose:** Manual end-to-end testing guide for User Acceptance Testing (UAT)
**Spec:** remaining-uat-readiness
**Task:** 15.1 - Perform end-to-end manual testing
**Date Created:** 2025-11-14

---

## Overview

This guide provides comprehensive instructions for performing manual end-to-end testing of the Beatbox Trainer application. Testing should be performed on a **real Android device** to verify all user workflows function correctly before production release.

---

## Prerequisites

### Required Equipment
- Android device with API 24+ (Android 7.0+)
- Quiet testing environment (< 40dB ambient noise recommended)
- Headphones or earbuds (recommended for metronome audio)

### Test Device Requirements
- Microphone permission available
- At least 100MB free storage
- No other audio apps running during testing

---

## Test Scope

This UAT covers the following user workflows:

1. **First Launch & Permissions** - App initialization and permission handling
2. **Calibration Flow** - User calibration of three sounds (KICK, SNARE, HI-HAT)
3. **Training Session** - Real-time beatbox training with feedback
4. **Settings & Configuration** - BPM adjustment and app settings
5. **Error Handling** - Graceful error handling and recovery
6. **Navigation** - Screen transitions and back navigation

---

## Test Environment Setup

### 1. Install Application

```bash
# Build release APK
flutter build apk --release

# Install on device
flutter install -d <device-id>

# Or install manually:
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 2. Clear Previous Data (if retesting)

```bash
# Clear app data for fresh test
adb shell pm clear com.example.beatbox_trainer
```

### 3. Record Device Information

| Field | Value |
|-------|-------|
| **Device Model** | _________________ |
| **Android Version** | _________________ |
| **API Level** | _________________ |
| **RAM** | _________________ |
| **Build Version** | _________________ |

---

## Test Case 1: First Launch & Permissions

### Objective
Verify application launches successfully and requests necessary permissions.

### Test Steps

1. **Launch Application**
   - Tap app icon from launcher
   - **Expected:** App launches within 3 seconds
   - **Expected:** No crashes or ANR errors
   - **Result:** ☐ PASS ☐ FAIL

2. **Microphone Permission Request**
   - **Expected:** System permission dialog appears
   - **Expected:** Dialog explains why microphone is needed
   - Tap "Allow"
   - **Expected:** Permission granted successfully
   - **Result:** ☐ PASS ☐ FAIL

3. **Initial Screen Display**
   - **Expected:** App shows home/calibration screen
   - **Expected:** UI elements render correctly (no overlapping, proper fonts)
   - **Expected:** Instructions are clear and readable
   - **Result:** ☐ PASS ☐ FAIL

**Test Case 1 Status:** ☐ PASS ☐ FAIL
**Notes:** _________________________________________________

---

## Test Case 2: Calibration Flow

### Objective
Verify user can complete calibration for all three sound types.

### Test Steps

1. **Start Calibration**
   - Navigate to calibration screen
   - **Expected:** Instructions explain calibration process
   - **Expected:** Calibration starts with KICK sound
   - **Result:** ☐ PASS ☐ FAIL

2. **Calibrate KICK Sound (10 samples)**
   - Perform KICK sound into microphone 10 times
   - Observe progress indicator after each sample
   - **Expected:** Progress shows N/10 after each sample
   - **Expected:** Audio feedback confirms sample recorded
   - **Expected:** All 10 samples collected successfully
   - **Result:** ☐ PASS ☐ FAIL

3. **Calibrate SNARE Sound (10 samples)**
   - **Expected:** Screen automatically advances to SNARE
   - Perform SNARE sound into microphone 10 times
   - **Expected:** Progress shows N/10 after each sample
   - **Expected:** All 10 samples collected successfully
   - **Result:** ☐ PASS ☐ FAIL

4. **Calibrate HI-HAT Sound (10 samples)**
   - **Expected:** Screen automatically advances to HI-HAT
   - Perform HI-HAT sound into microphone 10 times
   - **Expected:** Progress shows N/10 after each sample
   - **Expected:** All 10 samples collected successfully
   - **Result:** ☐ PASS ☐ FAIL

5. **Calibration Completion**
   - **Expected:** Success message displays
   - **Expected:** Navigation to training screen occurs
   - **Expected:** Calibration data persists (not lost on restart)
   - **Result:** ☐ PASS ☐ FAIL

6. **Calibration Error Handling**
   - (Optional) Test with very quiet sounds
   - **Expected:** Clear error message if sound not detected
   - **Expected:** Option to retry sample
   - **Result:** ☐ PASS ☐ FAIL ☐ N/A

**Test Case 2 Status:** ☐ PASS ☐ FAIL
**Notes:** _________________________________________________

---

## Test Case 3: Training Session

### Objective
Verify real-time training session with classification and timing feedback.

### Test Steps

1. **Start Training Session**
   - Navigate to training screen
   - Set BPM to 60 (slow tempo for testing)
   - Tap "Start" button
   - **Expected:** Metronome starts playing immediately
   - **Expected:** Metronome click is clear and audible
   - **Expected:** No audio glitches or dropouts
   - **Result:** ☐ PASS ☐ FAIL

2. **Classification Feedback - KICK**
   - Perform KICK sound in sync with metronome
   - **Expected:** "KICK" classification displays within 100ms
   - **Expected:** Classification is correct
   - Repeat 5 times
   - **Expected:** Consistent correct classification
   - **Accuracy:** ___/5 correct
   - **Result:** ☐ PASS ☐ FAIL

3. **Classification Feedback - SNARE**
   - Perform SNARE sound in sync with metronome
   - **Expected:** "SNARE" classification displays within 100ms
   - **Expected:** Classification is correct
   - Repeat 5 times
   - **Expected:** Consistent correct classification
   - **Accuracy:** ___/5 correct
   - **Result:** ☐ PASS ☐ FAIL

4. **Classification Feedback - HI-HAT**
   - Perform HI-HAT sound in sync with metronome
   - **Expected:** "HI-HAT" classification displays within 100ms
   - **Expected:** Classification is correct
   - Repeat 5 times
   - **Expected:** Consistent correct classification
   - **Accuracy:** ___/5 correct
   - **Result:** ☐ PASS ☐ FAIL

5. **Timing Feedback**
   - Perform sounds intentionally early (before click)
   - **Expected:** "EARLY" feedback with negative ms value
   - Perform sounds on time (with click)
   - **Expected:** "ON_TIME" feedback with ms value ≈ 0
   - Perform sounds intentionally late (after click)
   - **Expected:** "LATE" feedback with positive ms value
   - **Result:** ☐ PASS ☐ FAIL

6. **BPM Change During Session**
   - Stop training
   - Change BPM to 120 (double speed)
   - Restart training
   - **Expected:** Metronome tempo increases noticeably
   - **Expected:** New BPM takes effect immediately
   - Practice for 30 seconds
   - **Expected:** No audio glitches during practice
   - **Result:** ☐ PASS ☐ FAIL

7. **Extended Session Stability**
   - Continue training for 2 minutes at 120 BPM
   - **Expected:** No crashes or freezes
   - **Expected:** Metronome remains consistent
   - **Expected:** Classification continues working
   - **Expected:** UI remains responsive
   - **Result:** ☐ PASS ☐ FAIL

8. **Stop Training**
   - Tap "Stop" button
   - **Expected:** Metronome stops immediately
   - **Expected:** Audio engine releases resources
   - **Expected:** UI resets to idle state
   - **Result:** ☐ PASS ☐ FAIL

**Test Case 3 Status:** ☐ PASS ☐ FAIL
**Overall Classification Accuracy:** ___/15 (target > 90% = 14/15)
**Notes:** _________________________________________________

---

## Test Case 4: Settings & Configuration

### Objective
Verify settings screen functionality and BPM validation.

### Test Steps

1. **Navigate to Settings**
   - Tap settings icon/button
   - **Expected:** Settings screen displays
   - **Expected:** All settings options visible
   - **Result:** ☐ PASS ☐ FAIL

2. **BPM Slider Adjustment**
   - Drag BPM slider to minimum (40 BPM)
   - **Expected:** Value updates to 40
   - Drag slider to maximum (200 BPM)
   - **Expected:** Value updates to 200
   - Drag slider to middle (120 BPM)
   - **Expected:** Smooth slider movement
   - **Expected:** Value updates in real-time
   - **Result:** ☐ PASS ☐ FAIL

3. **BPM Validation**
   - (If manual input exists) Try entering BPM < 40
   - **Expected:** Error message or value clamped to 40
   - Try entering BPM > 200
   - **Expected:** Error message or value clamped to 200
   - **Result:** ☐ PASS ☐ FAIL ☐ N/A

4. **Settings Persistence**
   - Set BPM to 150
   - Navigate away and return to settings
   - **Expected:** BPM still shows 150
   - Close app completely
   - Reopen app and check settings
   - **Expected:** BPM persists across app restarts
   - **Result:** ☐ PASS ☐ FAIL

**Test Case 4 Status:** ☐ PASS ☐ FAIL
**Notes:** _________________________________________________

---

## Test Case 5: Error Handling & Edge Cases

### Objective
Verify application handles errors gracefully.

### Test Steps

1. **Deny Microphone Permission**
   - Uninstall app
   - Reinstall app
   - Launch app
   - Tap "Deny" on microphone permission
   - **Expected:** Clear error message explaining microphone needed
   - **Expected:** App doesn't crash
   - **Expected:** Option to request permission again
   - **Result:** ☐ PASS ☐ FAIL

2. **Background/Foreground Transitions**
   - Start training session
   - Press home button (app goes to background)
   - Wait 10 seconds
   - Return to app
   - **Expected:** App resumes correctly
   - **Expected:** Audio engine state maintained or gracefully reset
   - **Result:** ☐ PASS ☐ FAIL

3. **Low Battery Scenario** (Optional)
   - Test with device battery < 20%
   - Start training session
   - **Expected:** App continues functioning
   - **Expected:** No unexpected shutdowns
   - **Result:** ☐ PASS ☐ FAIL ☐ N/A

4. **Airplane Mode / No Network** (if applicable)
   - Enable airplane mode
   - Launch app
   - **Expected:** App works offline (no network required)
   - Complete calibration and training
   - **Expected:** Full functionality maintained
   - **Result:** ☐ PASS ☐ FAIL ☐ N/A

**Test Case 5 Status:** ☐ PASS ☐ FAIL
**Notes:** _________________________________________________

---

## Test Case 6: Navigation & User Experience

### Objective
Verify screen navigation works correctly and UX is smooth.

### Test Steps

1. **Back Button Navigation**
   - From training screen, press Android back button
   - **Expected:** Confirmation dialog or proper back action
   - From calibration screen, press back button
   - **Expected:** Appropriate navigation (return or cancel calibration)
   - **Expected:** No app crash on back navigation
   - **Result:** ☐ PASS ☐ FAIL

2. **Screen Transitions**
   - Navigate through all screens (home → calibration → training → settings)
   - **Expected:** Smooth transitions with no lag
   - **Expected:** No screen flicker or visual glitches
   - **Expected:** All screens render correctly
   - **Result:** ☐ PASS ☐ FAIL

3. **UI Responsiveness**
   - Tap all interactive elements (buttons, sliders, etc.)
   - **Expected:** Immediate visual feedback (<100ms)
   - **Expected:** No frozen UI or delayed responses
   - **Result:** ☐ PASS ☐ FAIL

**Test Case 6 Status:** ☐ PASS ☐ FAIL
**Notes:** _________________________________________________

---

## Performance Metrics (Optional but Recommended)

### Latency Measurement
- **Feedback Latency:** Estimate time from sound to classification display
  - **Measured:** ______ ms (target: < 100ms)
  - **Result:** ☐ PASS ☐ FAIL

### Resource Usage
- **CPU Usage:** Monitor with Android Studio Profiler during training
  - **Measured:** ______ % (target: < 15%)
  - **Result:** ☐ PASS ☐ FAIL

- **Memory Usage:** Check memory consumption
  - **Measured:** ______ MB (target: < 100MB)
  - **Result:** ☐ PASS ☐ FAIL

### Stability Metrics
- **Crashes:** Count during entire UAT session
  - **Count:** ______ (target: 0)

- **ANR Events:** Application Not Responding errors
  - **Count:** ______ (target: 0)

- **Audio Glitches:** Click dropouts or distortion
  - **Count:** ______ (target: 0)

---

## Overall UAT Results

### Summary

| Test Case | Status | Critical? |
|-----------|--------|-----------|
| 1. First Launch & Permissions | ☐ PASS ☐ FAIL | YES |
| 2. Calibration Flow | ☐ PASS ☐ FAIL | YES |
| 3. Training Session | ☐ PASS ☐ FAIL | YES |
| 4. Settings & Configuration | ☐ PASS ☐ FAIL | NO |
| 5. Error Handling | ☐ PASS ☐ FAIL | YES |
| 6. Navigation & UX | ☐ PASS ☐ FAIL | NO |

**Overall UAT Status:** ☐ ALL CRITICAL TESTS PASSED ☐ FAILURES DETECTED

### Pass/Fail Criteria

**UAT PASSES if:**
- ✅ All critical test cases (1, 2, 3, 5) PASS
- ✅ Overall classification accuracy > 90% (14/15 or better)
- ✅ Zero crashes during complete test session
- ✅ No critical errors preventing core functionality

**UAT FAILS if:**
- ❌ Any critical test case FAILS
- ❌ Classification accuracy < 90%
- ❌ App crashes during testing
- ❌ Core workflows blocked by errors

---

## Issues Found

### Critical Issues (Block Release)
1. _____________________________________________________________
2. _____________________________________________________________

### High Priority Issues (Should Fix)
1. _____________________________________________________________
2. _____________________________________________________________

### Medium/Low Priority Issues (Nice to Have)
1. _____________________________________________________________
2. _____________________________________________________________

---

## User Experience Observations

### Positive Findings
- _____________________________________________________________
- _____________________________________________________________

### Areas for Improvement
- _____________________________________________________________
- _____________________________________________________________

### Tester Feedback
_________________________________________________________________
_________________________________________________________________

---

## Recommendations

### Immediate Actions Required
- [ ] _____________________________________________________________
- [ ] _____________________________________________________________

### Future Enhancements
- [ ] _____________________________________________________________
- [ ] _____________________________________________________________

---

## Sign-Off

**Tester Name:** _________________________
**Test Date:** _________________________
**Test Duration:** _________ minutes
**Signature:** _________________________

**Reviewer Name:** _________________________
**Review Date:** _________________________
**Approval:** ☐ APPROVED FOR UAT ☐ REQUIRES FIXES
**Signature:** _________________________

---

## Appendix A: Test Evidence

### Screenshots to Capture
- [ ] App launch screen
- [ ] Microphone permission dialog
- [ ] Calibration screen (KICK/SNARE/HIHAT)
- [ ] Training session with classification feedback
- [ ] Timing feedback display (EARLY/ON_TIME/LATE)
- [ ] Settings screen
- [ ] Any error messages encountered

### Screen Recording (Optional)
- [ ] Complete E2E session: calibration → training → settings
- File: `uat_session_<date>.mp4`

---

## Appendix B: Known Limitations

Document any known limitations or platform-specific behaviors:
- _____________________________________________________________
- _____________________________________________________________

---

**End of UAT Testing Guide**
