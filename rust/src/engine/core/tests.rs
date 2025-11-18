use super::*;

impl EngineHandle {
    pub fn new_test() -> Self {
        Self::new()
    }

    pub fn reset(&self) {
        let _ = self.stop_audio();
        let _ = self.load_calibration(CalibrationState::new_default());
    }

    pub fn with_mock_calibration(state: CalibrationState) -> Self {
        let ctx = Self::new();
        let _ = ctx.load_calibration(state);
        ctx
    }

    pub fn get_calibration_state_for_test(&self) -> Option<CalibrationState> {
        self.get_calibration_state().ok()
    }

    pub fn is_audio_running_for_test(&self) -> Option<bool> {
        match self.start_audio(0) {
            Err(AudioError::AlreadyRunning) => Some(true),
            Err(AudioError::BpmInvalid { .. }) => Some(false),
            _ => None,
        }
    }

    pub fn is_calibration_active_for_test(&self) -> Option<bool> {
        match self.start_calibration() {
            Err(CalibrationError::AlreadyInProgress) => Some(true),
            Ok(()) => {
                let _ = self.finish_calibration();
                Some(false)
            }
            _ => None,
        }
    }

    pub fn new_test_with_channels() -> Self {
        let ctx = Self::new();
        let _ = ctx.broadcasts.init_classification();
        let _ = ctx.broadcasts.init_calibration();
        ctx
    }
}
