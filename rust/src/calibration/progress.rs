// Progress tracking for calibration workflow
//
// This module provides types and utilities for tracking progress through
// the calibration sample collection workflow.

/// Sound type being calibrated
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CalibrationSound {
    Kick,
    Snare,
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
            CalibrationSound::Kick => Some(CalibrationSound::Snare),
            CalibrationSound::Snare => Some(CalibrationSound::HiHat),
            CalibrationSound::HiHat => None,
        }
    }

    /// Get human-readable name for display
    pub fn display_name(&self) -> &'static str {
        match self {
            CalibrationSound::Kick => "KICK",
            CalibrationSound::Snare => "SNARE",
            CalibrationSound::HiHat => "HI-HAT",
        }
    }
}

/// Progress information for the current calibration step
#[derive(Debug, Clone)]
pub struct CalibrationProgress {
    /// Current sound being calibrated
    pub current_sound: CalibrationSound,
    /// Number of samples collected for current sound (0-10)
    pub samples_collected: u8,
    /// Total samples needed per sound
    pub samples_needed: u8,
}

impl CalibrationProgress {
    /// Create a new progress instance
    ///
    /// # Arguments
    /// * `current_sound` - Sound currently being calibrated
    /// * `samples_collected` - Number of samples collected so far
    /// * `samples_needed` - Total samples needed for this sound
    pub fn new(current_sound: CalibrationSound, samples_collected: u8, samples_needed: u8) -> Self {
        Self {
            current_sound,
            samples_collected,
            samples_needed,
        }
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
        assert_eq!(CalibrationSound::Kick.next(), Some(CalibrationSound::Snare));
        assert_eq!(
            CalibrationSound::Snare.next(),
            Some(CalibrationSound::HiHat)
        );
        assert_eq!(CalibrationSound::HiHat.next(), None);
    }

    #[test]
    fn test_calibration_sound_display_name() {
        assert_eq!(CalibrationSound::Kick.display_name(), "KICK");
        assert_eq!(CalibrationSound::Snare.display_name(), "SNARE");
        assert_eq!(CalibrationSound::HiHat.display_name(), "HI-HAT");
    }

    #[test]
    fn test_calibration_progress_new() {
        let progress = CalibrationProgress::new(CalibrationSound::Kick, 5, 10);
        assert_eq!(progress.current_sound, CalibrationSound::Kick);
        assert_eq!(progress.samples_collected, 5);
        assert_eq!(progress.samples_needed, 10);
    }

    #[test]
    fn test_calibration_progress_is_sound_complete() {
        let progress = CalibrationProgress::new(CalibrationSound::Kick, 10, 10);
        assert!(progress.is_sound_complete());

        let progress = CalibrationProgress::new(CalibrationSound::Kick, 5, 10);
        assert!(!progress.is_sound_complete());
    }

    #[test]
    fn test_calibration_progress_is_calibration_complete() {
        let progress = CalibrationProgress::new(CalibrationSound::HiHat, 10, 10);
        assert!(progress.is_calibration_complete());

        let progress = CalibrationProgress::new(CalibrationSound::Snare, 10, 10);
        assert!(!progress.is_calibration_complete());

        let progress = CalibrationProgress::new(CalibrationSound::HiHat, 5, 10);
        assert!(!progress.is_calibration_complete());
    }

    #[test]
    fn test_calibration_progress_percentage() {
        let progress = CalibrationProgress::new(CalibrationSound::Kick, 0, 10);
        assert_eq!(progress.percentage(), 0);

        let progress = CalibrationProgress::new(CalibrationSound::Kick, 5, 10);
        assert_eq!(progress.percentage(), 50);

        let progress = CalibrationProgress::new(CalibrationSound::Kick, 10, 10);
        assert_eq!(progress.percentage(), 100);

        let progress = CalibrationProgress::new(CalibrationSound::Kick, 7, 10);
        assert_eq!(progress.percentage(), 70);
    }

    #[test]
    fn test_calibration_progress_percentage_zero_needed() {
        let progress = CalibrationProgress::new(CalibrationSound::Kick, 0, 0);
        assert_eq!(progress.percentage(), 0);
    }
}
