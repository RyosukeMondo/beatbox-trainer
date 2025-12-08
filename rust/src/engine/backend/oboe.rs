use crate::config::{AudioConfig, OnsetDetectionConfig};
use crate::error::AudioError;
use crate::managers::AudioEngineManager;

use super::{AudioBackend, EngineStartContext};

/// Android backend that drives the Oboe-powered audio engine.
pub struct OboeBackend {
    manager: AudioEngineManager,
}

impl OboeBackend {
    pub fn new(
        audio_config: AudioConfig,
        onset_config: OnsetDetectionConfig,
        log_every_n_buffers: u64,
    ) -> Self {
        Self {
            manager: AudioEngineManager::new(audio_config, onset_config, log_every_n_buffers),
        }
    }
}

impl AudioBackend for OboeBackend {
    fn start(&self, ctx: EngineStartContext) -> Result<(), AudioError> {
        self.manager.start(
            ctx.bpm,
            ctx.calibration_state,
            ctx.calibration_procedure,
            ctx.calibration_progress_tx,
            ctx.classification_tx,
            ctx.metronome_enabled,
        )
    }

    fn stop(&self) -> Result<(), AudioError> {
        self.manager.stop()
    }

    fn set_bpm(&self, bpm: u32) -> Result<(), AudioError> {
        self.manager.set_bpm(bpm)
    }
}
