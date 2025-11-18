# Integration Test Report - Beatbox Trainer Core

**Spec Name:** beatbox-trainer-core
**Task:** 6.3 - Manual integration testing with real device
**Test Date:** _[TO BE FILLED BY TESTER]_
**Tester Name:** _[TO BE FILLED BY TESTER]_
**Build Version:** _[TO BE FILLED BY TESTER]_

---

## Test Environment

### Required Equipment
- [ ] Android device with API 24+ (Android 7.0+)
- [ ] Audio loopback cable (3.5mm male-to-male)
- [ ] DAW software (Audacity, Ableton Live, or similar)
- [ ] Computer with audio interface
- [ ] Quiet testing environment (< 40dB ambient noise)

### Test Device Information
| Field | Value |
|-------|-------|
| **Device Model** | _[e.g., Samsung Galaxy S21]_ |
| **Android Version** | _[e.g., Android 12]_ |
| **API Level** | _[e.g., API 31]_ |
| **Chipset** | _[e.g., Snapdragon 888]_ |
| **RAM** | _[e.g., 8GB]_ |

---

## Test Summary

| Test ID | Test Name | Status | Notes |
|---------|-----------|--------|-------|
| T1 | Audio Loopback Latency | ⬜ PENDING / ✅ PASS / ❌ FAIL | |
| T2 | Metronome Jitter Measurement | ⬜ PENDING / ✅ PASS / ❌ FAIL | |
| T3 | Calibration Accuracy | ⬜ PENDING / ✅ PASS / ❌ FAIL | |
| T4 | E2E Training Session | ⬜ PENDING / ✅ PASS / ❌ FAIL | |

**Overall Result:** ⬜ PENDING / ✅ ALL TESTS PASSED / ❌ TESTS FAILED

---

## Test 1: Audio Loopback Latency Measurement

### Objective
Verify that end-to-end audio latency from microphone input to speaker output is < 20ms as specified in Requirement 1.

### Requirements Tested
- **Req 1.2:** End-to-end audio latency SHALL be < 20ms

### Test Setup
1. **Hardware Connection:**
   - Connect 3.5mm audio loopback cable from device headphone jack to microphone jack
   - If device uses USB-C audio, use appropriate USB-C to 3.5mm adapter

2. **App Configuration:**
   - Build and install debug APK on test device
   - Launch app and grant microphone permission
   - Complete calibration flow (all 3 sounds)
   - Set BPM to 120
   - Start training session

3. **Measurement Procedure:**
   - In the app, start audio engine (metronome should play)
   - Metronome click will go from speaker → loopback cable → microphone
   - App should detect the click as an onset
   - Record the timestamp displayed in timing feedback
   - Calculate latency = time from metronome beat to onset detection

### Pass Criteria
- ✅ Measured latency < 20ms
- ✅ Latency is consistent across 10 consecutive beats (standard deviation < 2ms)
- ✅ No audio glitches or dropouts during test

### Test Results

| Measurement | Beat # | Metronome Timestamp (ms) | Onset Detection Timestamp (ms) | Latency (ms) |
|-------------|--------|--------------------------|--------------------------------|--------------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| 6 | | | | |
| 7 | | | | |
| 8 | | | | |
| 9 | | | | |
| 10 | | | | |

**Mean Latency:** _[Calculate average]_ ms
**Standard Deviation:** _[Calculate std dev]_ ms
**Min Latency:** _[Min value]_ ms
**Max Latency:** _[Max value]_ ms

**Test Status:** ⬜ PASS / ⬜ FAIL
**Notes:** _[Any observations, issues, or anomalies]_

---

## Test 2: Metronome Jitter Measurement

### Objective
Verify that metronome generation has 0 sample jitter (sample-accurate timing) over 60 seconds as specified in Requirement 2.

### Requirements Tested
- **Req 2.2:** System SHALL increment frame_counter by buffer_size
- **Req 2.3:** System SHALL generate metronome click when frame_counter % samples_per_beat == 0
- **Req 2.5:** Measured jitter SHALL be 0 samples (sample-accurate timing)

### Test Setup
1. **Recording Configuration:**
   - Connect device to computer audio interface using 3.5mm cable
   - Open DAW software (Audacity recommended)
   - Set recording sample rate to 48000 Hz (match device)
   - Create new stereo recording track

2. **App Configuration:**
   - Launch app on device
   - Set BPM to 120 (exactly 2 beats per second at 48kHz = 24000 samples per beat)
   - Start training session

3. **Recording Procedure:**
   - Start recording in DAW
   - Let metronome run for exactly 60 seconds
   - Stop recording
   - Export recording as WAV file: `metronome_jitter_test_120bpm_60s.wav`

4. **Analysis Procedure:**
   - In DAW, zoom into waveform
   - Measure time between each consecutive click using sample-accurate cursors
   - At 120 BPM: expected interval = 24000 samples (500ms at 48kHz)
   - Record actual interval for all beats
   - Calculate jitter = |actual_interval - expected_interval|

### Pass Criteria
- ✅ Jitter = 0 samples for all beat intervals
- ✅ No drift over 60 seconds (total time = exactly 120 beats)
- ✅ All clicks have consistent amplitude and duration

### Test Results

**Recording Details:**
- **Recording File:** _[filename]_
- **Sample Rate:** _[e.g., 48000 Hz]_
- **Duration:** _[e.g., 60.000s]_
- **Total Beats Recorded:** _[Expected: 120 at 120 BPM]_
- **Expected Interval:** _[e.g., 24000 samples]_

**Jitter Measurements (Sample First 20 beats):**

| Beat Interval | Measured Samples | Expected Samples | Jitter (samples) |
|---------------|------------------|------------------|------------------|
| Beat 1→2 | | 24000 | |
| Beat 2→3 | | 24000 | |
| Beat 3→4 | | 24000 | |
| Beat 4→5 | | 24000 | |
| Beat 5→6 | | 24000 | |
| Beat 6→7 | | 24000 | |
| Beat 7→8 | | 24000 | |
| Beat 8→9 | | 24000 | |
| Beat 9→10 | | 24000 | |
| Beat 10→11 | | 24000 | |
| Beat 11→12 | | 24000 | |
| Beat 12→13 | | 24000 | |
| Beat 13→14 | | 24000 | |
| Beat 14→15 | | 24000 | |
| Beat 15→16 | | 24000 | |
| Beat 16→17 | | 24000 | |
| Beat 17→18 | | 24000 | |
| Beat 18→19 | | 24000 | |
| Beat 19→20 | | 24000 | |
| Beat 20→21 | | 24000 | |

**Jitter Statistics:**
- **Mean Jitter:** _[Calculate]_ samples
- **Max Jitter:** _[Max value]_ samples
- **Jitter-Free Intervals (0 samples):** _[Count]_ / 119
- **60s Total Duration Error:** _[Total samples - (119 × 24000)]_ samples

**Test Status:** ⬜ PASS / ⬜ FAIL
**Notes:** _[Attach waveform screenshot showing sample-accurate measurement]_

---

## Test 3: Calibration Accuracy Test

### Objective
Verify that classification accuracy exceeds 90% after user calibration across multiple testers as specified in Requirement 6 and 7.

### Requirements Tested
- **Req 7:** User calibration system with 10 samples per sound type
- **Req 6.6:** System SHALL send correct BeatboxHit enum to UI
- **Acceptance Criteria:** Mean calibration accuracy > 90% across testers

### Test Setup
1. **Tester Recruitment:**
   - Recruit 5 testers with varying beatbox experience:
     - 1 experienced beatboxer
     - 2 intermediate users (some beatbox knowledge)
     - 2 beginners (no beatbox experience)

2. **Test Protocol (Per Tester):**
   - Install app on test device
   - Complete calibration flow (10 samples × 3 sounds = 30 total)
   - Perform 100 test sounds (evenly distributed):
     - 34 KICK sounds
     - 33 SNARE sounds
     - 33 HI-HAT sounds
   - Record app's classification result for each sound
   - Tester also manually labels each sound (ground truth)

3. **Data Collection:**
   - Use screen recording to capture all classifications
   - Create CSV file per tester: `tester_N_results.csv`
   - Columns: `sound_number`, `ground_truth`, `app_classification`, `correct`

### Pass Criteria
- ✅ Mean accuracy across all 5 testers > 90%
- ✅ Per-sound accuracy (KICK/SNARE/HIHAT) > 85% for each
- ✅ No tester has accuracy < 80%

### Test Results

#### Tester 1: [Experience Level]
| Metric | Value |
|--------|-------|
| **Overall Accuracy** | _[N correct / 100]_ % |
| **KICK Accuracy** | _[N correct / 34]_ % |
| **SNARE Accuracy** | _[N correct / 33]_ % |
| **HI-HAT Accuracy** | _[N correct / 33]_ % |
| **Calibration Time** | _[minutes]_ |

**Confusion Matrix:**
|  | Predicted KICK | Predicted SNARE | Predicted HIHAT | Predicted UNKNOWN |
|--|----------------|-----------------|-----------------|-------------------|
| **Actual KICK** | | | | |
| **Actual SNARE** | | | | |
| **Actual HIHAT** | | | | |

#### Tester 2: [Experience Level]
| Metric | Value |
|--------|-------|
| **Overall Accuracy** | _[N correct / 100]_ % |
| **KICK Accuracy** | _[N correct / 34]_ % |
| **SNARE Accuracy** | _[N correct / 33]_ % |
| **HI-HAT Accuracy** | _[N correct / 33]_ % |
| **Calibration Time** | _[minutes]_ |

**Confusion Matrix:**
|  | Predicted KICK | Predicted SNARE | Predicted HIHAT | Predicted UNKNOWN |
|--|----------------|-----------------|-----------------|-------------------|
| **Actual KICK** | | | | |
| **Actual SNARE** | | | | |
| **Actual HIHAT** | | | | |

#### Tester 3: [Experience Level]
| Metric | Value |
|--------|-------|
| **Overall Accuracy** | _[N correct / 100]_ % |
| **KICK Accuracy** | _[N correct / 34]_ % |
| **SNARE Accuracy** | _[N correct / 33]_ % |
| **HI-HAT Accuracy** | _[N correct / 33]_ % |
| **Calibration Time** | _[minutes]_ |

**Confusion Matrix:**
|  | Predicted KICK | Predicted SNARE | Predicted HIHAT | Predicted UNKNOWN |
|--|----------------|-----------------|-----------------|-------------------|
| **Actual KICK** | | | | |
| **Actual SNARE** | | | | |
| **Actual HIHAT** | | | | |

#### Tester 4: [Experience Level]
| Metric | Value |
|--------|-------|
| **Overall Accuracy** | _[N correct / 100]_ % |
| **KICK Accuracy** | _[N correct / 34]_ % |
| **SNARE Accuracy** | _[N correct / 33]_ % |
| **HI-HAT Accuracy** | _[N correct / 33]_ % |
| **Calibration Time** | _[minutes]_ |

**Confusion Matrix:**
|  | Predicted KICK | Predicted SNARE | Predicted HIHAT | Predicted UNKNOWN |
|--|----------------|-----------------|-----------------|-------------------|
| **Actual KICK** | | | | |
| **Actual SNARE** | | | | |
| **Actual HIHAT** | | | | |

#### Tester 5: [Experience Level]
| Metric | Value |
|--------|-------|
| **Overall Accuracy** | _[N correct / 100]_ % |
| **KICK Accuracy** | _[N correct / 34]_ % |
| **SNARE Accuracy** | _[N correct / 33]_ % |
| **HI-HAT Accuracy** | _[N correct / 33]_ % |
| **Calibration Time** | _[minutes]_ |

**Confusion Matrix:**
|  | Predicted KICK | Predicted SNARE | Predicted HIHAT | Predicted UNKNOWN |
|--|----------------|-----------------|-----------------|-------------------|
| **Actual KICK** | | | | |
| **Actual SNARE** | | | | |
| **Actual HIHAT** | | | | |

#### Aggregated Results
| Metric | Value |
|--------|-------|
| **Mean Accuracy (All Testers)** | _[Calculate average]_ % |
| **Standard Deviation** | _[Calculate std dev]_ % |
| **Min Accuracy (Worst Tester)** | _[Min value]_ % |
| **Max Accuracy (Best Tester)** | _[Max value]_ % |
| **Mean KICK Accuracy** | _[Average across testers]_ % |
| **Mean SNARE Accuracy** | _[Average across testers]_ % |
| **Mean HIHAT Accuracy** | _[Average across testers]_ % |
| **Mean Calibration Time** | _[Average]_ minutes |

**Test Status:** ⬜ PASS / ⬜ FAIL
**Notes:** _[Observations about misclassifications, calibration quality, tester feedback]_

---

## Test 4: End-to-End Training Session

### Objective
Verify that complete training workflow executes without crashes and provides accurate real-time feedback as specified in Requirements 1-9.

### Requirements Tested
- **Req 1-9:** Complete system integration
- **Req 9:** Flutter UI feedback display
- **Req 8:** Timing quantization and feedback
- **NFR:** System reliability and stability

### Test Setup
1. **App Installation:**
   - Build and install APK on test device
   - Clear app data to simulate fresh install
   - Launch app

2. **Test Workflow:**
   - Grant microphone permission
   - Complete calibration (3 sounds × 10 samples)
   - Start training session at 60 BPM
   - Practice for 1 minute (verify feedback appears)
   - Increase BPM to 120
   - Practice for 1 minute
   - Increase BPM to 180
   - Practice for 1 minute
   - Stop training session
   - Restart training at 120 BPM
   - Practice for 30 seconds
   - Stop and exit app

### Pass Criteria
- ✅ No crashes or ANR (Application Not Responding) during entire session
- ✅ Classification results appear within 100ms of sound production
- ✅ Timing feedback displays correct classification (ON_TIME/EARLY/LATE)
- ✅ Metronome plays continuously with no audio glitches
- ✅ BPM changes take effect immediately on restart
- ✅ All UI elements render correctly

### Test Results

#### Functional Verification Checklist

| Feature | Status | Notes |
|---------|--------|-------|
| **App Launch** | ⬜ PASS / ⬜ FAIL | Time to launch: _[seconds]_ |
| **Microphone Permission** | ⬜ PASS / ⬜ FAIL | Permission dialog shown correctly |
| **Calibration - KICK** | ⬜ PASS / ⬜ FAIL | 10 samples collected |
| **Calibration - SNARE** | ⬜ PASS / ⬜ FAIL | 10 samples collected |
| **Calibration - HIHAT** | ⬜ PASS / ⬜ FAIL | 10 samples collected |
| **Calibration Complete** | ⬜ PASS / ⬜ FAIL | Success message shown |
| **Start Training** | ⬜ PASS / ⬜ FAIL | Audio engine started |
| **Metronome Audible** | ⬜ PASS / ⬜ FAIL | Click sound clear and consistent |
| **Classification Display** | ⬜ PASS / ⬜ FAIL | KICK/SNARE/HIHAT shown correctly |
| **Timing Feedback** | ⬜ PASS / ⬜ FAIL | ON_TIME/EARLY/LATE shown with ms value |
| **BPM Slider** | ⬜ PASS / ⬜ FAIL | Slider adjusts value smoothly |
| **BPM Change (60→120)** | ⬜ PASS / ⬜ FAIL | Metronome speed increased |
| **BPM Change (120→180)** | ⬜ PASS / ⬜ FAIL | Metronome speed increased |
| **Stop Training** | ⬜ PASS / ⬜ FAIL | Audio stopped, UI reset |
| **Restart Training** | ⬜ PASS / ⬜ FAIL | Resumed without issues |

#### Performance Metrics

| Metric | Measurement | Target | Result |
|--------|-------------|--------|--------|
| **Feedback Latency** | _[Average ms from sound to display]_ | < 100ms | ⬜ PASS / ⬜ FAIL |
| **CPU Usage** | _[Average % during training]_ | < 15% | ⬜ PASS / ⬜ FAIL |
| **Memory Usage** | _[MB during training]_ | < 100MB | ⬜ PASS / ⬜ FAIL |
| **Audio Glitches** | _[Count during 3min session]_ | 0 | ⬜ PASS / ⬜ FAIL |

#### Stability Metrics

| Metric | Value |
|--------|-------|
| **Crashes** | _[Count]_ |
| **ANR Events** | _[Count]_ |
| **Total Session Duration** | _[minutes]_ |
| **Audio Stream Disconnects** | _[Count]_ |
| **UI Freezes** | _[Count]_ |

**Test Status:** ⬜ PASS / ⬜ FAIL
**Notes:** _[Any issues, user experience observations, unexpected behavior]_

---

## Additional Observations

### Usability Findings
_[Tester feedback on UI clarity, workflow smoothness, error messages, etc.]_

### Performance Issues
_[Any lag, stuttering, thermal throttling, battery drain observations]_

### Device-Specific Behavior
_[Any issues specific to test device model or Android version]_

### Recommendations
_[Suggested improvements based on testing results]_

---

## Test Evidence

### Required Attachments
- [ ] Screenshot: App home screen
- [ ] Screenshot: Calibration flow
- [ ] Screenshot: Training session with classification feedback
- [ ] Screenshot: Timing feedback display
- [ ] Audio Recording: `metronome_jitter_test_120bpm_60s.wav`
- [ ] Waveform Screenshot: Jitter analysis in DAW
- [ ] Screen Recording: E2E training session (video)
- [ ] CSV Files: Calibration accuracy data (`tester_N_results.csv` for N=1..5)

---

## Sign-Off

**Tester Signature:** _________________________
**Date:** _________________________

**Reviewer Signature:** _________________________
**Date:** _________________________

---

## Appendix A: Known Issues and Workarounds

_[Document any known issues encountered and their workarounds]_

---

## Appendix B: Test Data Files

All test data files should be stored in: `docs/test_results/integration_test_[DATE]/`

File structure:
```
docs/test_results/integration_test_2024-XX-XX/
├── integration_test_report.md (this file, filled out)
├── screenshots/
│   ├── home_screen.png
│   ├── calibration_kick.png
│   ├── calibration_snare.png
│   ├── calibration_hihat.png
│   ├── training_session.png
│   └── timing_feedback.png
├── audio_recordings/
│   ├── metronome_jitter_test_120bpm_60s.wav
│   └── jitter_analysis_screenshot.png
├── video/
│   └── e2e_training_session.mp4
└── calibration_data/
    ├── tester_1_results.csv
    ├── tester_2_results.csv
    ├── tester_3_results.csv
    ├── tester_4_results.csv
    └── tester_5_results.csv
```

---

**End of Integration Test Report**
