//! Backend abstractions for the reusable engine core.

use std::sync::{Arc, Mutex, RwLock};
use std::time::Instant;

use tokio::sync::broadcast;

use crate::analysis::ClassificationResult;
use crate::api::AudioMetrics;
use crate::calibration::{CalibrationProcedure, CalibrationProgress, CalibrationState};
use crate::error::AudioError;

/// Context provided to audio backends when starting the engine.
///
/// This bundles the mutable state and channels required by the backend
/// to wire the DSP pipeline without coupling it to higher-level code.
pub struct EngineStartContext {
    pub bpm: u32,
    pub calibration_state: Arc<RwLock<CalibrationState>>,
    pub calibration_procedure: Arc<Mutex<Option<CalibrationProcedure>>>,
    pub calibration_progress_tx: Option<broadcast::Sender<CalibrationProgress>>,
    pub classification_tx: broadcast::Sender<ClassificationResult>,
    pub audio_metrics_tx: Option<broadcast::Sender<AudioMetrics>>,
    pub metronome_enabled: bool,
}

/// Trait implemented by platform-specific audio backends.
///
/// Each backend is responsible for connecting the lock-free audio engine
/// to the shared channels provided via [EngineStartContext].
pub trait AudioBackend: Send + Sync {
    fn start(&self, ctx: EngineStartContext) -> Result<(), AudioError>;
    fn stop(&self) -> Result<(), AudioError>;
    fn set_bpm(&self, bpm: u32) -> Result<(), AudioError>;
}

/// Trait representing a monotonic time source used for telemetry timestamps.
pub trait TimeSource: Send + Sync {
    fn now(&self) -> Instant;
}

/// Default time source backed by `Instant::now`.
#[derive(Default)]
pub struct SystemTimeSource {
    _unit: (),
}

impl TimeSource for SystemTimeSource {
    fn now(&self) -> Instant {
        Instant::now()
    }
}

#[cfg(target_os = "android")]
mod oboe;
#[cfg(target_os = "android")]
pub use oboe::OboeBackend;

#[cfg(not(target_os = "android"))]
mod cpal;
#[cfg(not(target_os = "android"))]
pub use cpal::CpalBackend;

mod desktop_stub;
pub use desktop_stub::{DesktopStubBackend, StubTimeSource};
