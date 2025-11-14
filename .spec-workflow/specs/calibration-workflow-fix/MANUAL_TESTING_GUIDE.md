# Manual Testing Guide: Calibration Workflow Fix

**Spec:** calibration-workflow-fix
**Task:** 5.2 - Manual testing on Android device
**Date:** 2025-11-14
**Requirements:** Design Section 7.4, NFR-1 (Performance), NFR-2 (Real-Time Latency)

---

## Prerequisites

### Hardware Requirements
- Physical Android device (API level 21+)
- USB cable for device connection
- Quiet testing environment (<40dB ambient noise)
- Headphones/speakers for metronome audio

### Software Requirements
- Android Studio with ADB tools installed
- Flutter SDK (configured and working)
- Device with USB debugging enabled
- App built and deployed to device

### Deployment Steps
```bash
# 1. Connect Android device via USB
adb devices

# 2. Build and deploy Flutter app
cd /home/rmondo/repos/beatbox-trainer
flutter run --release

# 3. Open logcat for monitoring
adb logcat -s beatbox:* RustAudio:* CalibrationManager:* AudioEngine:*
```

---

## Test Cases

### Test Case 1: Complete Calibration Workflow ✓
**Objective:** Verify complete 30-sample calibration completes successfully

**Preconditions:**
- App launched and no prior calibration exists
- Audio permissions granted
- Device in quiet environment

**Test Steps:**
1. Navigate to calibration screen
2. Tap "Start Calibration" button
3. Wait for metronome to start (should restart audio engine)
4. Perform 10 KICK sounds (low frequency "B" or "Boom")
   - Wait ~2 seconds between each sound
   - Verify UI shows "KICK: X/10" progress
5. When KICK complete, verify UI transitions to "SNARE: 0/10"
6. Perform 10 SNARE sounds (mid frequency "P" or "Psh")
   - Verify progress updates in real-time
7. When SNARE complete, verify UI transitions to "HIHAT: 0/10"
8. Perform 10 HIHAT sounds (high frequency "T" or "Ts")
   - Verify progress updates in real-time
9. After 30th sample, verify UI shows completion state
10. Tap "Finish Calibration" button
11. Verify calibration state saved (check preferences or storage)

**Expected Results:**
- ✓ Audio engine restarts within 200ms (NFR-1)
- ✓ Progress updates appear within 100ms of each sound (NFR-2)
- ✓ All 30 samples accepted (10 kick, 10 snare, 10 hihat)
- ✓ UI transitions smoothly between sound types
- ✓ Calibration state persists after completion
- ✓ No crashes or errors in logcat

**Actual Results:**
- [ ] Pass / [ ] Fail
- Audio restart latency: _____ ms
- Progress update latency: _____ ms (average)
- Total completion time: _____ seconds
- Notes: _____________________

**Logcat Verification:**
```bash
# Look for these log patterns:
# [CalibrationManager] Starting calibration
# [AudioEngine] Stopping audio engine
# [AudioEngine] Starting audio engine with calibration procedure
# [AnalysisThread] Onset detected, forwarding to calibration
# [CalibrationProcedure] Sample added: KICK (1/10)
# [BroadcastManager] Progress broadcast: KICK 1/10
# ... (repeat for all 30 samples)
# [CalibrationManager] Calibration complete
```

---

### Test Case 2: Invalid Sample Rejection ✓
**Objective:** Verify system rejects invalid/quiet samples gracefully

**Preconditions:**
- App running with calibration in progress
- Currently collecting KICK samples (any point in workflow)

**Test Steps:**
1. Perform 3 valid KICK sounds → Verify count increases to 3/10
2. **Invalid Test A:** Whisper "test" (non-beatbox sound)
   - Verify count stays at 3/10
   - Check logcat for rejection message
3. **Invalid Test B:** Make very quiet "b" sound (<40dB)
   - Verify count stays at 3/10
   - Check logcat for rejection or no onset detected
4. **Invalid Test C:** Tap finger on microphone (non-valid transient)
   - Verify count may or may not increase (depends on features)
   - If increases, verify features are still within valid range
5. Continue with 7 more valid KICK sounds → Verify reaches 10/10
6. Verify system transitions to SNARE

**Expected Results:**
- ✓ Invalid samples rejected or not detected
- ✓ Progress count only increases for valid beatbox sounds
- ✓ No crashes on invalid input
- ✓ Logcat shows error messages for rejected samples
- ✓ System continues normally after rejections

**Actual Results:**
- [ ] Pass / [ ] Fail
- Invalid samples rejected: _____ / 3
- Notes: _____________________

**Logcat Verification:**
```bash
# Look for these patterns:
# [AnalysisThread] No onset detected (for quiet sounds)
# [CalibrationProcedure] Sample validation failed: features out of range
# [CalibrationProcedure] Rejected sample: centroid=X, zcr=Y
```

---

### Test Case 3: Audio Restart Latency Measurement ✓
**Objective:** Verify audio restart during calibration start is <200ms (NFR-1)

**Preconditions:**
- App running in classification mode with audio engine active
- Metronome playing at some BPM

**Test Steps:**
1. Start audio engine in classification mode
2. Let metronome play for a few beats to establish baseline
3. **Precision Timer:** Use stopwatch or logcat timestamps
4. Tap "Start Calibration" button → Start timer
5. Listen for metronome audio gap
6. Note when metronome resumes → Stop timer
7. Repeat test 3 times for consistency
8. Calculate average latency

**Expected Results:**
- ✓ Audio gap (silence) < 200ms
- ✓ Gap is "barely noticeable" to user
- ✓ Metronome resumes at 120 BPM
- ✓ No audio glitches or pops during restart

**Actual Results:**
- [ ] Pass / [ ] Fail
- Test 1 latency: _____ ms
- Test 2 latency: _____ ms
- Test 3 latency: _____ ms
- Average latency: _____ ms
- Subjective perception: [ ] Barely noticeable [ ] Noticeable [ ] Disruptive
- Notes: _____________________

**Logcat Timing Verification:**
```bash
# Extract timestamps from logcat:
adb logcat -v time | grep -E "stop_audio|start_audio|calibration"

# Look for pattern:
# 14:23:45.123 [AppContext] stop_audio() called
# 14:23:45.289 [AudioEngine] Audio engine stopped
# 14:23:45.301 [AppContext] start_audio(120) called
# 14:23:45.315 [AudioEngine] Audio engine started

# Calculate: start_time - stop_time = restart latency
```

---

### Test Case 4: Calibration Cancellation ✓
**Objective:** Verify incomplete calibration does not save corrupted state

**Preconditions:**
- App running with no prior calibration

**Test Steps:**
1. Start calibration → Begin collecting KICK samples
2. Perform 5 KICK sounds (50% complete)
3. Verify progress shows "KICK: 5/10"
4. **Cancel Action A:** Press back button / navigate away
5. Verify calibration state is "InProgress" or "NotStarted"
6. **Cancel Action B:** Force close app (swipe away from recent apps)
7. Restart app
8. Navigate to calibration screen
9. Verify previous incomplete calibration is NOT loaded
10. Verify UI shows "Start Calibration" (not "Resume")

**Expected Results:**
- ✓ Incomplete calibration not persisted
- ✓ App restarts cleanly without corrupted state
- ✓ User can start fresh calibration after cancel
- ✓ No crashes during cancellation

**Actual Results:**
- [ ] Pass / [ ] Fail
- Behavior after back button: _____________________
- Behavior after force close: _____________________
- Notes: _____________________

---

### Test Case 5: Error Handling ✓
**Objective:** Verify error cases handled gracefully without crashes

**Preconditions:**
- App installed on device

**Test Steps:**

**5A: No Microphone Permission**
1. Revoke microphone permission: `adb shell pm revoke com.beatboxtrainer android.permission.RECORD_AUDIO`
2. Launch app
3. Tap "Start Calibration"
4. Verify error message displayed: "Microphone permission required"
5. Verify app does not crash
6. Grant permission via settings
7. Retry calibration → Verify works normally

**5B: Calibration Already In Progress**
1. Start calibration (collect 2-3 samples)
2. Without completing, tap "Start Calibration" again
3. Verify error message: "Calibration already in progress"
4. Verify first calibration session continues normally
5. Complete or cancel first session
6. Verify can start new session

**5C: Audio Engine Failure (Simulated)**
- Note: This test requires code modification or device state manipulation
- Simulate by disabling audio device or forcing AudioEngine error
- Verify `CalibrationError::AudioEngineError` returned
- Verify error message shown to user
- Verify app does not crash

**Expected Results:**
- ✓ All error cases handled gracefully
- ✓ Clear error messages shown to user
- ✓ No crashes or app freezes
- ✓ App state remains consistent after errors
- ✓ User can retry after resolving error condition

**Actual Results:**
- [ ] Pass / [ ] Fail
- 5A (No Permission): _____________________
- 5B (Already In Progress): _____________________
- 5C (Audio Failure): _____________________
- Notes: _____________________

**Logcat Error Verification:**
```bash
# Look for error patterns:
# [CalibrationManager] Error: PermissionDenied
# [CalibrationManager] Error: AlreadyInProgress
# [AppContext] CalibrationError: AudioEngineError(...)
```

---

## Device Log Monitoring

### Key Log Tags to Monitor
```bash
# Real-time filtered logs
adb logcat -s \
  beatbox:* \
  RustAudio:* \
  CalibrationManager:* \
  AudioEngine:* \
  AnalysisThread:* \
  CalibrationProcedure:* \
  BroadcastManager:*
```

### Expected Log Sequence (Happy Path)
```
[CalibrationManager] start() called
[AudioEngine] stop_audio() called
[AudioEngine] Audio engine stopped
[AudioEngine] start_audio(120) called with calibration_procedure
[AudioEngine] spawn_analysis_thread_internal() with calibration params
[AnalysisThread] Started with calibration mode enabled
[Metronome] Playing at 120 BPM

# User performs KICK sound
[AnalysisThread] Onset detected at frame 48523
[AnalysisThread] Features extracted: centroid=523Hz, zcr=0.12, flatness=0.34
[AnalysisThread] Calibration mode active, forwarding to procedure
[CalibrationProcedure] add_sample() called
[CalibrationProcedure] Sample validated successfully
[CalibrationProcedure] KICK sample 1/10 added
[BroadcastManager] Progress broadcast: KICK 1/10
[DartBridge] CalibrationProgress received, updating UI

# ... (repeat for 30 samples)

[CalibrationProcedure] All samples collected
[CalibrationManager] finish_calibration() called
[CalibrationState] Thresholds computed successfully
[CalibrationState] State persisted to storage
[AudioEngine] Restarting in classification mode
```

### Log Patterns for Rejection/Errors
```
# Onset not detected (too quiet)
[AnalysisThread] No onset detected in buffer

# Invalid features
[CalibrationProcedure] Validation failed: centroid out of range (12000 Hz > 8000 Hz max)
[CalibrationProcedure] Sample rejected

# Lock failure (should be rare)
[AnalysisThread] Failed to acquire calibration procedure lock, falling back to classification
```

---

## Success Criteria Summary

**All test cases must pass:**
- ✓ Test Case 1: Complete calibration succeeds (30 samples)
- ✓ Test Case 2: Invalid samples rejected silently
- ✓ Test Case 3: Audio restart latency < 200ms (NFR-1)
- ✓ Test Case 4: Incomplete calibration not saved
- ✓ Test Case 5: Error handling graceful (no crashes)

**Performance Metrics:**
- ✓ Progress updates visible in UI within 100ms (NFR-2)
- ✓ Total calibration time < 2 minutes (NFR-1)
- ✓ Audio restart gap "barely noticeable" (<200ms)

**Reliability:**
- ✓ No crashes observed during any test case
- ✓ Calibration state persists after completion
- ✓ App restarts cleanly without corrupted state

**Logging:**
- ✓ Onset detection events logged
- ✓ Sample acceptance/rejection logged
- ✓ Progress broadcasts logged
- ✓ Error cases logged with clear messages

---

## Test Execution Checklist

**Before Testing:**
- [ ] Build app in release mode: `flutter run --release`
- [ ] Deploy to physical Android device
- [ ] Connect device to ADB
- [ ] Open logcat monitoring in terminal
- [ ] Ensure quiet environment (<40dB ambient)
- [ ] Charge device to >50% battery

**During Testing:**
- [ ] Execute Test Case 1: Complete Calibration
- [ ] Execute Test Case 2: Invalid Sample Rejection
- [ ] Execute Test Case 3: Audio Restart Latency
- [ ] Execute Test Case 4: Calibration Cancellation
- [ ] Execute Test Case 5: Error Handling
- [ ] Capture logcat output for each test
- [ ] Record timing measurements
- [ ] Note any unexpected behavior

**After Testing:**
- [ ] Review logcat logs for errors/warnings
- [ ] Verify all success criteria met
- [ ] Document any issues found
- [ ] Update task status in tasks.md: `[x]`
- [ ] Use spec-workflow log-implementation tool
- [ ] Commit test results and findings

---

## Issues and Findings Template

**Issue ID:** [Generated or manual ID]
**Test Case:** [Which test case revealed the issue]
**Severity:** [Critical / Major / Minor / Cosmetic]
**Description:** [Clear description of the issue]
**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected Behavior:** [What should happen]
**Actual Behavior:** [What actually happened]
**Logcat Output:** [Relevant log snippets]
**Screenshots/Video:** [If applicable]
**Suggested Fix:** [If known]

---

## Appendix: Beatbox Sound Reference

### KICK Sounds (Low Frequency)
- Classic: "B" or "Boom" (lips vibrate)
- Expected features: centroid ~300-800 Hz, high decay time (80-120ms)

### SNARE Sounds (Mid Frequency)
- Classic: "P" or "Psh" (plosive + breath)
- Expected features: centroid ~2000-4000 Hz, high ZCR (0.2-0.4)

### HIHAT Sounds (High Frequency)
- Classic: "T" or "Ts" (tongue click + breath)
- Expected features: centroid ~6000-10000 Hz, high flatness (0.6-0.8)

---

## Contact and Support

**For issues or questions:**
- Review design document: `.spec-workflow/specs/calibration-workflow-fix/design.md`
- Check requirements: `.spec-workflow/specs/calibration-workflow-fix/requirements.md`
- Review implementation logs: `.spec-workflow/specs/calibration-workflow-fix/Implementation Logs/`
- Consult task list: `.spec-workflow/specs/calibration-workflow-fix/tasks.md`

**Test execution date:** _____________________
**Tested by:** _____________________
**Device model:** _____________________
**Android version:** _____________________
**App version:** _____________________
