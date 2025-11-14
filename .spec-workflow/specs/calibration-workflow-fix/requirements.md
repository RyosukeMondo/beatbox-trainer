# Calibration Workflow Fix - Requirements

## 1. Introduction

The calibration system is a critical component of the Beatbox Trainer app that adapts sound classification to individual voice characteristics. Currently, the calibration workflow has an architectural gap: the audio engine detects onsets and extracts spectral features, but these features are never fed to the calibration procedure's sample collection logic.

This specification addresses the complete end-to-end calibration workflow to enable:
- Onset detection during calibration sessions
- Feature extraction and validation
- Sample collection (10 samples per sound type: KICK, SNARE, HI-HAT)
- Real-time progress feedback to the UI
- Threshold computation and state persistence

## 2. Alignment with Product Vision

**From product.md:**
> Calibration time < 2 minutes (10 samples × 3 sound types = 30 samples total)

**From tech.md:**
> Real-time audio processing with lock-free communication, sample-accurate metronome, < 20ms latency

This specification ensures the calibration workflow supports these goals by:
1. Providing real-time progress updates (< 100ms latency)
2. Enabling efficient sample collection through clear UI guidance
3. Maintaining real-time safety with lock-free architecture
4. Delivering reliable threshold computation for accurate classification

## 3. User Stories

### Story 1: Voice Calibration for Accurate Classification
**As a** beatboxer
**I want to** calibrate the app to my voice
**So that** sound classification recognizes my unique technique and vocal characteristics

**EARS Criteria:**
- **WHEN** I start calibration
- **WHILE** the audio engine is running
- **IF** I perform a beatbox sound (KICK, SNARE, or HI-HAT)
- **THEN** the system shall detect the onset within 50ms
- **AND** extract spectral features (centroid, ZCR, flatness, rolloff, decay time)
- **AND** validate features are within acceptable ranges
- **AND** add the sample to the calibration procedure

**Acceptance Criteria:**
- ✓ Onset detection triggers within 50ms of transient
- ✓ Features extracted match DSP specifications
- ✓ Invalid samples (out of range) are rejected with clear error
- ✓ Each sound type collects exactly 10 valid samples

---

### Story 2: Real-Time Progress Feedback
**As a** user
**I want to** see real-time progress during calibration
**So that** I know the system is working and how many samples remain

**EARS Criteria:**
- **WHEN** a valid sample is collected
- **THEN** the system shall broadcast a progress update within 100ms
- **AND** the UI shall display:
  - Current sound type being calibrated (KICK/SNARE/HI-HAT)
  - Sample count (e.g., "3/10 samples collected")
  - Visual/audio feedback confirming sample acceptance

**Acceptance Criteria:**
- ✓ Progress broadcast latency < 100ms
- ✓ UI updates reflect sample count accurately
- ✓ Progress stream continues until calibration completion or error
- ✓ Stream ends gracefully when calibration finishes

---

### Story 3: Clear Calibration Instructions
**As a** user
**I want to** receive clear instructions for each sound type
**So that** I know what beatbox sound to perform

**EARS Criteria:**
- **WHEN** calibration starts or progresses to the next sound type
- **THEN** the system shall indicate the current sound type to perform
- **AND** provide visual guidance (e.g., "Perform KICK sound: 3/10 samples")

**Acceptance Criteria:**
- ✓ Calibration sequence follows: KICK → SNARE → HI-HAT
- ✓ UI displays current sound type prominently
- ✓ Transition to next sound type occurs automatically after 10 samples
- ✓ Completion message shown after all 30 samples collected

---

### Story 4: Testable Calibration Architecture
**As a** developer
**I want** unit-testable calibration logic
**So that** the system is maintainable and regression-free

**EARS Criteria:**
- **WHEN** calibration logic is implemented
- **THEN** each component shall be independently testable:
  - Onset detection can be tested with synthetic audio
  - Feature extraction can be tested with known spectral content
  - Sample validation can be tested with boundary cases
  - Threshold computation can be tested with mock sample sets
  - Progress broadcasting can be tested with mock channels

**Acceptance Criteria:**
- ✓ Unit test coverage ≥ 90% for calibration modules
- ✓ Integration tests verify onset → sample → progress flow
- ✓ Mock dependencies injectable for testing
- ✓ Edge cases tested: insufficient samples, invalid features, duplicate onsets

## 4. Functional Requirements

### FR-1: Onset Detection During Calibration
**Requirement:** The audio engine shall detect percussive transients during calibration sessions.

**Details:**
- Use spectral flux analysis for onset detection
- Threshold-based trigger to distinguish onset from noise
- Sample-accurate timestamp using frame counter

**Rationale:** Calibration requires detecting when the user performs a beatbox sound.

---

### FR-2: Feature Extraction
**Requirement:** For each detected onset, the system shall extract the following spectral features:

1. **Spectral Centroid** (Hz): Weighted mean frequency
2. **Zero-Crossing Rate (ZCR)**: Ratio of sign changes (0.0 to 1.0)
3. **Spectral Flatness**: Measure of noise-like vs. tone-like (0.0 to 1.0)
4. **Spectral Rolloff** (Hz): Frequency below which 85% of energy is concentrated
5. **Decay Time** (ms): Time for signal to decay to -20dB

**Rationale:** These features distinguish KICK (low centroid, high decay) from SNARE (mid centroid, high ZCR) from HI-HAT (high centroid, high flatness).

---

### FR-3: Sample Validation
**Requirement:** The calibration procedure shall validate features before adding samples.

**Validation Rules:**
- Centroid: 0 Hz < centroid < Nyquist frequency (sample_rate / 2)
- ZCR: 0.0 ≤ zcr ≤ 1.0
- Flatness: 0.0 ≤ flatness ≤ 1.0
- Rolloff: 0 Hz < rolloff < Nyquist frequency
- Decay time: > 0 ms

**Error Handling:**
- Invalid samples rejected with error code and reason
- Error logged for debugging
- UI shows rejection feedback (optional)

**Rationale:** Prevents corrupted data from affecting threshold computation.

---

### FR-4: Sample Collection Workflow
**Requirement:** The calibration procedure shall collect 10 samples per sound type in sequence: KICK → SNARE → HI-HAT.

**State Transitions:**
1. **NotStarted** → **CollectingKick** (when `start_calibration()` called)
2. **CollectingKick** → **CollectingSnare** (after 10 KICK samples)
3. **CollectingSnare** → **CollectingHiHat** (after 10 SNARE samples)
4. **CollectingHiHat** → **Complete** (after 10 HI-HAT samples)

**Rationale:** Sequential collection provides clear user guidance and simplifies UI logic.

---

### FR-5: Progress Broadcasting
**Requirement:** The calibration procedure shall broadcast progress updates via Tokio broadcast channel.

**Progress Event Structure:**
```rust
pub struct CalibrationProgress {
    pub current_sound: String,      // "KICK" | "SNARE" | "HIHAT"
    pub samples_collected: u8,      // 0-10
    pub total_samples_needed: u8,   // Always 10
}
```

**Broadcasting Rules:**
- Broadcast after each valid sample added
- Broadcast on state transition (e.g., KICK → SNARE)
- Broadcast on error (optional)

**Rationale:** Real-time UI updates improve user experience.

---

### FR-6: Threshold Computation
**Requirement:** Upon completion, the system shall compute classification thresholds from collected samples.

**Algorithm:**
1. Calculate mean and standard deviation for each feature per sound type
2. Compute decision boundaries using statistical thresholds
3. Store thresholds in `CalibrationState`
4. Serialize state to JSON for persistence

**Rationale:** Thresholds enable accurate classification of future sounds.

---

### FR-7: Audio Engine Integration
**Requirement:** The audio engine's analysis thread shall forward detected onsets to the calibration procedure during calibration mode.

**Integration Points:**
- Analysis thread checks if calibration is in progress
- If active, calls `CalibrationProcedure::add_sample(features)`
- If inactive, proceeds with normal classification

**Rationale:** Connects onset detection to sample collection without duplicating DSP logic.

## 5. Non-Functional Requirements

### NFR-1: Performance
**Requirement:** Calibration shall complete in < 2 minutes under normal usage.

**Assumptions:**
- User performs sounds at ~2 second intervals
- 30 samples × 2 seconds = 60 seconds active time
- + UI guidance + threshold computation < 60 seconds overhead
- Total: ~120 seconds

**Measurement:** End-to-end timer from `start_calibration()` to `finish_calibration()`

---

### NFR-2: Real-Time Latency
**Requirement:** Progress updates shall reach the UI within 100ms of sample collection.

**Components:**
- Onset detection: < 50ms
- Feature extraction: < 20ms
- Progress broadcast: < 10ms
- Dart stream processing: < 20ms

**Measurement:** Timestamp comparison between onset detection and UI update logs

---

### NFR-3: Reliability
**Requirement:** The calibration workflow shall handle errors gracefully without crashing.

**Error Scenarios:**
- Invalid features → Reject sample, log error, continue
- Audio engine failure → Return `CalibrationError::AudioEngineError`
- Broadcast channel failure → Log warning, continue (degraded mode)
- Lock poisoning → Return `CalibrationError::StatePoisoned`

**Rationale:** Production apps must not crash on edge cases.

---

### NFR-4: Testability
**Requirement:** All calibration logic shall be unit testable with ≥ 90% coverage.

**Architecture Requirements:**
- Dependency injection for audio engine, broadcast channels
- Mock calibration procedure for testing UI integration
- Synthetic audio samples for testing onset detection
- Deterministic feature vectors for testing validation logic

**Rationale:** High test coverage prevents regressions and enables confident refactoring.

---

### NFR-5: Code Quality
**Requirement:** Implementation shall follow SOLID principles and project guidelines.

**Guidelines (from CLAUDE.md):**
- Max 500 lines/file
- Max 50 lines/function
- Single Responsibility Principle
- Dependency Injection
- Structured error handling with error codes

**Rationale:** Maintainable code reduces long-term costs.

## 6. Out of Scope

The following are explicitly **NOT** included in this specification:

1. **Advanced UI Features:**
   - Visual waveform display during calibration
   - Audio playback of collected samples
   - Calibration history/analytics

2. **Adaptive Calibration:**
   - Automatic recalibration based on drift detection
   - Continuous learning from user corrections

3. **Multi-User Calibration:**
   - Saving multiple calibration profiles per device
   - Cloud sync of calibration data

4. **Advanced DSP:**
   - Machine learning-based classification (current spec uses rule-based thresholds)
   - Spectral harmonics analysis

**Rationale:** These features can be added in future specs after core calibration is stable.

## 7. Assumptions and Constraints

### Assumptions:
1. User has granted microphone permissions before starting calibration
2. Audio environment is reasonably quiet (< 40dB ambient noise)
3. User understands basic beatbox sounds (KICK, SNARE, HI-HAT)
4. Device supports low-latency audio via Oboe (Android 4.1+)

### Constraints:
1. **Platform:** Android-only (Oboe library constraint)
2. **Sample Rate:** 48000 Hz (Oboe default)
3. **Buffer Size:** Variable (Oboe auto-tuning)
4. **Real-Time Safety:** No allocations, locks, or blocking in audio callback
5. **Memory:** Limited by Android device (typically 2-4 GB available to app)

## 8. Success Metrics

The calibration workflow implementation shall be considered successful if:

1. **Functional Completeness:**
   - ✓ All user stories pass acceptance criteria
   - ✓ All functional requirements implemented
   - ✓ End-to-end calibration completes without errors

2. **Performance:**
   - ✓ Calibration time < 2 minutes (measured via device logs)
   - ✓ Progress latency < 100ms (measured via timestamps)
   - ✓ No audio dropouts or glitches during calibration

3. **Quality:**
   - ✓ Unit test coverage ≥ 90%
   - ✓ Integration tests pass for onset → progress flow
   - ✓ Zero crashes in calibration workflow (tested over 100 runs)
   - ✓ Code review passes (SOLID principles, < 500 lines/file)

4. **User Experience:**
   - ✓ Clear progress feedback visible in UI
   - ✓ Smooth transition between sound types
   - ✓ Completion message confirms successful calibration
   - ✓ Saved calibration persists across app restarts

## 9. Dependencies

### Internal Dependencies:
- `rust/src/audio/engine.rs` - Oboe audio streams, onset detection
- `rust/src/analysis/mod.rs` - Spectral feature extraction
- `rust/src/calibration/procedure.rs` - Sample collection logic
- `rust/src/calibration/manager.rs` - Calibration lifecycle management
- `rust/src/context.rs` - Dependency injection container
- `rust/src/managers/broadcast.rs` - Progress broadcasting

### External Dependencies:
- `oboe-rs 0.6.1` - Audio I/O
- `tokio 1.42.0` - Async runtime, broadcast channels
- `flutter_rust_bridge 2.11.1` - FFI bridge
- `serde_json` - Calibration state serialization

### Test Dependencies:
- `mockall` or manual mocks - Dependency injection for tests
- Synthetic audio samples - Testing onset detection
- Known feature vectors - Testing validation logic

## 10. References

- **Product Vision:** `.spec-workflow/steering/product.md`
- **Technical Architecture:** `.spec-workflow/steering/tech.md`
- **Codebase Structure:** `.spec-workflow/steering/structure.md`
- **Existing Calibration Code:** `rust/src/calibration/`
- **Audio Engine:** `rust/src/audio/engine.rs`
- **FFI API:** `rust/src/api.rs`
