// Progress tracking for calibration workflow
//
// This module provides types and utilities for tracking progress through
// the calibration sample collection workflow.

/// Calibration phase - includes noise floor measurement before sound collection
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum CalibrationSound {
    /// Step 1: Measuring ambient noise level (user should stay quiet)
    NoiseFloor,
    /// Step 2: Collecting kick drum samples
    Kick,
    /// Step 3: Collecting snare drum samples
    Snare,
    /// Step 4: Collecting hi-hat samples
    HiHat,
}

impl CalibrationSound {
    /// Get the next sound in the calibration sequence
    ///
    /// # Returns
    /// * `Some(CalibrationSound)` - Next sound to calibrate
    /// * `None` - Calibration sequence complete
    pub fn next(&self) -> Option<CalibrationSound> {
        match self {
            CalibrationSound::NoiseFloor => Some(CalibrationSound::Kick),
            CalibrationSound::Kick => Some(CalibrationSound::Snare),
            CalibrationSound::Snare => Some(CalibrationSound::HiHat),
            CalibrationSound::HiHat => None,
        }
    }

    /// Get human-readable name for display
    pub fn display_name(&self) -> &'static str {
        match self {
            CalibrationSound::NoiseFloor => "NOISE FLOOR",
            CalibrationSound::Kick => "KICK",
            CalibrationSound::Snare => "SNARE",
            CalibrationSound::HiHat => "HI-HAT",
        }
    }

    /// Check if this is a sound collection phase (not noise floor)
    pub fn is_sound_phase(&self) -> bool {
        !matches!(self, CalibrationSound::NoiseFloor)
    }
}

/// Reasons for providing calibration guidance to the UI
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum CalibrationGuidanceReason {
    /// We hear sustained audio but no samples are being accepted
    Stagnation,
    /// Audio level is too low to pass the RMS gate
    TooQuiet,
    /// Audio appears clipped or overly loud
    Clipped,
}

/// Guidance payload accompanying calibration progress updates
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct CalibrationGuidance {
    /// Sound currently being calibrated
    pub sound: CalibrationSound,
    /// Guidance reason
    pub reason: CalibrationGuidanceReason,
    /// RMS/level observed when guidance was generated
    pub level: f32,
    /// Number of consecutive misses triggering guidance
    pub misses: u8,
}

/// Progress information for the current calibration step
///
/// This struct is sent to the Dart UI via flutter_rust_bridge Stream
/// for real-time display of calibration progress.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct CalibrationProgress {
    /// Current sound being calibrated
    pub current_sound: CalibrationSound,
    /// Number of samples collected for current sound (0-10)
    pub samples_collected: u8,
    /// Total samples needed per sound
    pub samples_needed: u8,
    /// Whether waiting for user confirmation to proceed to next phase
    pub waiting_for_confirmation: bool,
    /// Optional guidance hint for the UI
    pub guidance: Option<CalibrationGuidance>,
    /// Whether a manual accept candidate is available for promotion
    pub manual_accept_available: bool,
}

impl CalibrationProgress {
    /// Create a new progress instance
    ///
    /// # Arguments
    /// * `current_sound` - Sound currently being calibrated
    /// * `samples_collected` - Number of samples collected so far
    /// * `samples_needed` - Total samples needed for this sound
    /// * `waiting_for_confirmation` - Whether waiting for user to confirm/retry
    pub fn new(
        current_sound: CalibrationSound,
        samples_collected: u8,
        samples_needed: u8,
        waiting_for_confirmation: bool,
    ) -> Self {
        Self {
            current_sound,
            samples_collected,
            samples_needed,
            waiting_for_confirmation,
            guidance: None,
            manual_accept_available: false,
        }
    }

    /// Attach guidance payload to this progress instance
    pub fn with_guidance(mut self, guidance: Option<CalibrationGuidance>) -> Self {
        self.guidance = guidance;
        self
    }

    /// Update manual accept availability flag
    pub fn with_manual_accept(mut self, available: bool) -> Self {
        self.manual_accept_available = available;
        self
    }

    /// Check if current sound is complete
    pub fn is_sound_complete(&self) -> bool {
        self.samples_collected >= self.samples_needed
    }

    /// Check if entire calibration is complete
    pub fn is_calibration_complete(&self) -> bool {
        self.is_sound_complete() && self.current_sound == CalibrationSound::HiHat
    }

    /// Get progress percentage (0-100)
    pub fn percentage(&self) -> u8 {
        if self.samples_needed == 0 {
            return 0;
        }
        ((self.samples_collected as f32 / self.samples_needed as f32) * 100.0) as u8
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calibration_sound_next() {
        assert_eq!(
            CalibrationSound::NoiseFloor.next(),
            Some(CalibrationSound::Kick)
        );
        assert_eq!(CalibrationSound::Kick.next(), Some(CalibrationSound::Snare));
        assert_eq!(
            CalibrationSound::Snare.next(),
            Some(CalibrationSound::HiHat)
        );
        assert_eq!(CalibrationSound::HiHat.next(), None);
    }

    #[test]
    fn test_calibration_sound_display_name() {
        assert_eq!(CalibrationSound::NoiseFloor.display_name(), "NOISE FLOOR");
        assert_eq!(CalibrationSound::Kick.display_name(), "KICK");
        assert_eq!(CalibrationSound::Snare.display_name(), "SNARE");
        assert_eq!(CalibrationSound::HiHat.display_name(), "HI-HAT");
    }

    #[test]
    fn test_calibration_sound_is_sound_phase() {
        assert!(!CalibrationSound::NoiseFloor.is_sound_phase());
        assert!(CalibrationSound::Kick.is_sound_phase());
        assert!(CalibrationSound::Snare.is_sound_phase());
        assert!(CalibrationSound::HiHat.is_sound_phase());
    }

    #[test]
    fn test_calibration_progress_new() {
        let progress = CalibrationProgress::new(CalibrationSound::Kick, 5, 10, false);
        assert_eq!(progress.current_sound, CalibrationSound::Kick);
        assert_eq!(progress.samples_collected, 5);
        assert_eq!(progress.samples_needed, 10);
        assert!(!progress.waiting_for_confirmation);
        assert!(progress.guidance.is_none());
        assert!(!progress.manual_accept_available);
    }

    #[test]
    fn test_calibration_progress_is_sound_complete() {
        let progress = CalibrationProgress::new(CalibrationSound::Kick, 10, 10, false);
        assert!(progress.is_sound_complete());

        let progress = CalibrationProgress::new(CalibrationSound::Kick, 5, 10, false);
        assert!(!progress.is_sound_complete());
    }

    #[test]
    fn test_calibration_progress_is_calibration_complete() {
        let progress = CalibrationProgress::new(CalibrationSound::HiHat, 10, 10, false);
        assert!(progress.is_calibration_complete());

        let progress = CalibrationProgress::new(CalibrationSound::Snare, 10, 10, false);
        assert!(!progress.is_calibration_complete());

        let progress = CalibrationProgress::new(CalibrationSound::HiHat, 5, 10, false);
        assert!(!progress.is_calibration_complete());
    }

    #[test]
    fn test_calibration_progress_percentage() {
        let progress = CalibrationProgress::new(CalibrationSound::Kick, 0, 10, false);
        assert_eq!(progress.percentage(), 0);

        let progress = CalibrationProgress::new(CalibrationSound::Kick, 5, 10, false);
        assert_eq!(progress.percentage(), 50);

        let progress = CalibrationProgress::new(CalibrationSound::Kick, 10, 10, false);
        assert_eq!(progress.percentage(), 100);

        let progress = CalibrationProgress::new(CalibrationSound::Kick, 7, 10, false);
        assert_eq!(progress.percentage(), 70);
    }

    #[test]
    fn test_calibration_progress_percentage_zero_needed() {
        let progress = CalibrationProgress::new(CalibrationSound::Kick, 0, 0, false);
        assert_eq!(progress.percentage(), 0);
    }

    #[test]
    fn test_calibration_progress_waiting_for_confirmation() {
        let progress = CalibrationProgress::new(CalibrationSound::Kick, 10, 10, true);
        assert!(progress.waiting_for_confirmation);
        assert!(progress.is_sound_complete());
    }
}
