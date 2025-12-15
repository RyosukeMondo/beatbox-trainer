use std::time::Duration;

#[derive(Debug)]
pub enum LevelCrossingEvent {
    Crossing,
    ForcedCapture,
}

#[derive(Debug)]
pub struct LevelCrossingDetector {
    prev_rms: f64,
    last_capture_sample: u64,
    debounce_samples: u64,
    captured_in_gate: bool,
}

impl LevelCrossingDetector {
    pub fn new(sample_rate: u32, debounce_ms: u64) -> Self {
        let debounce_samples = (debounce_ms * sample_rate as u64) / 1000;
        Self {
            prev_rms: 0.0,
            last_capture_sample: 0,
            debounce_samples,
            captured_in_gate: false,
        }
    }

    /// Reset internal state (e.g. when switching modes)
    pub fn reset(&mut self) {
        self.prev_rms = 0.0;
        self.last_capture_sample = 0;
        self.captured_in_gate = false;
    }

    pub fn last_capture_sample(&self) -> u64 {
        self.last_capture_sample
    }

    pub fn is_captured_in_gate(&self) -> bool {
        self.captured_in_gate
    }

    /// Process a new RMS window for classification mode (simple crossing with debounce)
    pub fn process_classification(
        &mut self,
        rms: f64,
        threshold: f64,
        current_sample_count: u64,
    ) -> Option<LevelCrossingEvent> {
        // Check debounce
        if current_sample_count.saturating_sub(self.last_capture_sample) < self.debounce_samples {
            self.prev_rms = rms;
            return None;
        }

        let crossed = self.prev_rms < threshold && rms >= threshold;
        self.prev_rms = rms;

        if crossed {
            self.last_capture_sample = current_sample_count;
            Some(LevelCrossingEvent::Crossing)
        } else {
            None
        }
    }

    /// Process a new RMS window for calibration mode (with hysteresis and forced capture)
    pub fn process_calibration(
        &mut self,
        rms: f64,
        detection_threshold: f64,
        current_sample_count: u64,
    ) -> Option<LevelCrossingEvent> {
        let reset_threshold = detection_threshold * 0.6; // Hysteresis

        // Reset gate state if we drop below hysteresis threshold
        if rms <= reset_threshold {
            self.captured_in_gate = false;
        }

        // Check debounce
        if current_sample_count.saturating_sub(self.last_capture_sample) < self.debounce_samples {
            self.prev_rms = rms;
            return None;
        }

        let mut event = None;

        // Forced capture: if we are high enough but haven't captured in this gate yet
        if !self.captured_in_gate && rms >= detection_threshold {
            event = Some(LevelCrossingEvent::ForcedCapture);
            self.captured_in_gate = true;
            self.last_capture_sample = current_sample_count;
        }

        // Standard crossing detection
        // Note: Logic in original code allowed crossing to trigger even if forced capture didn't,
        // but they effectively do the same thing (trigger a capture).
        // Here we prioritize the ForcedCapture check above.
        // If we didn't force capture, check crossing:
        if event.is_none() {
             let crossed = self.prev_rms < detection_threshold && rms >= detection_threshold;
             if crossed && !self.captured_in_gate {
                 event = Some(LevelCrossingEvent::Crossing);
                 self.captured_in_gate = true;
                 self.last_capture_sample = current_sample_count;
             }
        }
        
        self.prev_rms = rms;
        event
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_classification_crossing() {
        let mut detector = LevelCrossingDetector::new(48000, 100);
        let threshold = 0.5;
        let start_sample = 5000; // Start after potential debounce window if last_capture was 0

        // Below threshold
        assert!(detector.process_classification(0.1, threshold, start_sample).is_none());
        
        // Crossing
        assert!(matches!(
            detector.process_classification(0.6, threshold, start_sample + 100),
            Some(LevelCrossingEvent::Crossing)
        ));

        // Debounce active - crossing ignored
        // We are at sample start_sample + 100 (captured here). Debounce is 4800 samples.
        // Next sample: start_sample + 200. Diff is 100 < 4800.
        // We simulate dropping low then going high again while in debounce
        assert!(detector.process_classification(0.1, threshold, start_sample + 200).is_none());
        assert!(detector.process_classification(0.6, threshold, start_sample + 300).is_none()); 

        // Debounce expired
        let debounce_samples = (100 * 48000) / 1000; // 4800
        let next_safe_sample = start_sample + 100 + debounce_samples + 100;
        
        // Reset low first to enable crossing
        assert!(detector.process_classification(0.1, threshold, next_safe_sample - 1).is_none());

        assert!(matches!(
            detector.process_classification(0.6, threshold, next_safe_sample),
            Some(LevelCrossingEvent::Crossing)
        ));
    }

    #[test]
    fn test_calibration_hysteresis() {
        let mut detector = LevelCrossingDetector::new(48000, 100);
        let threshold = 0.5;
        let start_sample = 5000;

        // Crossing
        assert!(matches!(
            detector.process_calibration(0.6, threshold, start_sample),
            Some(LevelCrossingEvent::ForcedCapture)
        ));
        assert!(detector.captured_in_gate);

        // Still above, no new capture
        assert!(detector.process_calibration(0.7, threshold, start_sample + 100).is_none());

        // Drop but not below reset (0.3)
        assert!(detector.process_calibration(0.4, threshold, start_sample + 200).is_none());
        assert!(detector.captured_in_gate);

        // Drop below reset
        assert!(detector.process_calibration(0.2, threshold, start_sample + 300).is_none());
        assert!(!detector.captured_in_gate);

        // Wait for debounce
        let debounce_samples = (100 * 48000) / 1000;
        let next_safe_sample = start_sample + debounce_samples + 1000;

        // Rise again -> Capture
        assert!(matches!(
            detector.process_calibration(0.6, threshold, next_safe_sample),
            Some(LevelCrossingEvent::ForcedCapture)
        ));
    }
}
