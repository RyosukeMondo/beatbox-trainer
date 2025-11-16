//! EngineHandle: reusable audio/DSP orchestration layer.
//!
//! This struct supersedes the old `AppContext`, exposing trait-based backends,
//! telemetry channels, and a `ParamPatch` command pipeline shared across CLI,
//! HTTP, and FRB entry points.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, RwLock};
use std::time::Instant;

use futures::Stream;
use serde::{Deserialize, Serialize};
use tokio::sync::{broadcast, mpsc, Mutex};
use tokio_stream::wrappers::UnboundedReceiverStream;

use crate::analysis::ClassificationResult;
use crate::api::{AudioMetrics, OnsetEvent};
use crate::calibration::{CalibrationProgress, CalibrationState};
use crate::config::AppConfig;
use crate::engine::backend::{AudioBackend, EngineStartContext, TimeSource};
#[cfg(not(target_os = "android"))]
use crate::engine::backend::{DesktopStubBackend, StubTimeSource};
#[cfg(target_os = "android")]
use crate::engine::backend::{OboeBackend, SystemTimeSource};
use crate::error::{AudioError, CalibrationError};
use crate::managers::{BroadcastChannelManager, CalibrationManager};

/// Patch describing parameter updates to apply to the running engine.
#[derive(Debug, Clone, Default)]
pub struct ParamPatch {
    pub bpm: Option<u32>,
    pub centroid_threshold: Option<f32>,
    pub zcr_threshold: Option<f32>,
}

/// Telemetry event emitted by the engine core.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TelemetryEvent {
    pub timestamp_ms: u64,
    pub kind: TelemetryEventKind,
    pub detail: Option<String>,
}

/// Types of telemetry events supported by the core.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TelemetryEventKind {
    EngineStarted { bpm: u32 },
    EngineStopped,
    BpmChanged { bpm: u32 },
    Warning,
}

/// EngineHandle orchestrates the DSP pipeline and shared channels.
pub struct EngineHandle {
    #[allow(dead_code)]
    config: Arc<RwLock<AppConfig>>,
    backend: Arc<dyn AudioBackend>,
    calibration: CalibrationManager,
    pub(crate) broadcasts: BroadcastChannelManager,
    telemetry_tx: broadcast::Sender<TelemetryEvent>,
    command_tx: mpsc::Sender<ParamPatch>,
    command_rx: Arc<Mutex<mpsc::Receiver<ParamPatch>>>,
    command_worker_started: AtomicBool,
    time_source: Arc<dyn TimeSource>,
    start_instant: Instant,
}

impl EngineHandle {
    /// Create a new EngineHandle with platform defaults.
    pub fn new() -> Self {
        let initial_config = Self::load_platform_config();
        Self::from_config(initial_config)
    }

    fn from_config(initial_config: AppConfig) -> Self {
        let config = Arc::new(RwLock::new(initial_config.clone()));

        let backend = Self::create_backend(&initial_config);
        let calibration = CalibrationManager::new(initial_config.calibration.clone());
        let broadcasts = BroadcastChannelManager::new();
        let (telemetry_tx, _) = broadcast::channel(128);
        let (command_tx, command_rx) = mpsc::channel(64);
        let time_source = Self::create_time_source();

        Self {
            config,
            backend,
            calibration,
            broadcasts,
            telemetry_tx,
            command_tx,
            command_rx: Arc::new(Mutex::new(command_rx)),
            command_worker_started: AtomicBool::new(false),
            time_source,
            start_instant: Instant::now(),
        }
    }

    fn load_platform_config() -> AppConfig {
        #[cfg(target_os = "android")]
        {
            AppConfig::load_android()
        }

        #[cfg(not(target_os = "android"))]
        {
            AppConfig::load()
        }
    }

    #[cfg(target_os = "android")]
    fn create_backend(config: &AppConfig) -> Arc<dyn AudioBackend> {
        Arc::new(OboeBackend::new(
            config.audio.clone(),
            config.onset_detection.clone(),
            config.calibration.log_every_n_buffers,
        ))
    }

    #[cfg(not(target_os = "android"))]
    fn create_backend(_config: &AppConfig) -> Arc<dyn AudioBackend> {
        Arc::new(DesktopStubBackend::new())
    }

    #[cfg(target_os = "android")]
    fn create_time_source() -> Arc<dyn TimeSource> {
        Arc::new(SystemTimeSource::default())
    }

    #[cfg(not(target_os = "android"))]
    fn create_time_source() -> Arc<dyn TimeSource> {
        Arc::new(StubTimeSource::default())
    }

    fn init_command_worker(&self) {
        if self
            .command_worker_started
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .is_err()
        {
            return;
        }

        let backend = Arc::clone(&self.backend);
        let telemetry_tx = self.telemetry_tx.clone();
        let time_source = Arc::clone(&self.time_source);
        let command_rx = Arc::clone(&self.command_rx);
        let start_instant = self.start_instant;

        tokio::spawn(async move {
            loop {
                let patch = {
                    let mut guard = command_rx.lock().await;
                    guard.recv().await
                };

                match patch {
                    Some(patch) => {
                        if let Some(bpm) = patch.bpm {
                            let result = backend.set_bpm(bpm);
                            let (kind, detail) = match result {
                                Ok(_) => (TelemetryEventKind::BpmChanged { bpm }, None),
                                Err(err) => (
                                    TelemetryEventKind::Warning,
                                    Some(format!("Failed to apply BPM patch: {}", err)),
                                ),
                            };
                            Self::publish_event(
                                &telemetry_tx,
                                &time_source,
                                start_instant,
                                kind,
                                detail,
                            );
                        }
                    }
                    None => break,
                }
            }
        });
    }

    fn publish_event(
        tx: &broadcast::Sender<TelemetryEvent>,
        time_source: &Arc<dyn TimeSource>,
        start_instant: Instant,
        kind: TelemetryEventKind,
        detail: Option<String>,
    ) {
        let timestamp_ms = time_source
            .now()
            .saturating_duration_since(start_instant)
            .as_millis() as u64;
        let _ = tx.send(TelemetryEvent {
            timestamp_ms,
            kind,
            detail,
        });
    }

    fn emit_event(&self, kind: TelemetryEventKind, detail: Option<String>) {
        Self::publish_event(
            &self.telemetry_tx,
            &self.time_source,
            self.start_instant,
            kind,
            detail,
        );
    }

    // ========================================================================
    // AUDIO ENGINE METHODS
    // ========================================================================

    /// Start the audio engine with specified BPM.
    pub fn start_audio(&self, bpm: u32) -> Result<(), AudioError> {
        let broadcast_tx = self.broadcasts.init_classification();
        let calibration_state = self.calibration.get_state_arc();
        let calibration_procedure = self.calibration.get_procedure_arc();
        let calibration_progress_tx = self.broadcasts.get_calibration_sender();

        let ctx = EngineStartContext {
            bpm,
            calibration_state,
            calibration_procedure,
            calibration_progress_tx,
            classification_tx: broadcast_tx,
        };

        self.backend.start(ctx)?;
        self.emit_event(TelemetryEventKind::EngineStarted { bpm }, None);
        self.init_command_worker();
        Ok(())
    }

    /// Stop the audio engine.
    pub fn stop_audio(&self) -> Result<(), AudioError> {
        self.backend.stop()?;
        self.emit_event(TelemetryEventKind::EngineStopped, None);
        Ok(())
    }

    /// Update BPM dynamically.
    pub fn set_bpm(&self, bpm: u32) -> Result<(), AudioError> {
        self.backend.set_bpm(bpm)?;
        self.emit_event(TelemetryEventKind::BpmChanged { bpm }, None);
        Ok(())
    }

    // ========================================================================
    // CALIBRATION METHODS
    // ========================================================================

    pub fn load_calibration(&self, state: CalibrationState) -> Result<(), CalibrationError> {
        self.calibration.load_state(state)
    }

    pub fn get_calibration_state(&self) -> Result<CalibrationState, CalibrationError> {
        self.calibration.get_state()
    }

    pub fn start_calibration(&self) -> Result<(), CalibrationError> {
        let broadcast_tx = self.broadcasts.init_calibration();
        self.calibration.start(broadcast_tx)?;

        #[cfg(target_os = "android")]
        {
            if let Err(err) = self.stop_audio() {
                eprintln!(
                    "Warning: Failed to stop audio engine during calibration start: {:?}",
                    err
                );
            }

            const DEFAULT_CALIBRATION_BPM: u32 = 120;
            self.start_audio(DEFAULT_CALIBRATION_BPM)
                .map_err(|audio_err| CalibrationError::AudioEngineError {
                    details: format!(
                        "Failed to start audio engine for calibration: {:?}",
                        audio_err
                    ),
                })?;
        }

        Ok(())
    }

    pub fn finish_calibration(&self) -> Result<(), CalibrationError> {
        self.calibration.finish()
    }

    // ========================================================================
    // STREAM SUBSCRIPTIONS
    // ========================================================================

    pub fn subscribe_classification(&self) -> mpsc::UnboundedReceiver<ClassificationResult> {
        let (tx, rx) = mpsc::unbounded_channel();

        if let Some(mut broadcast_rx) = self.broadcasts.subscribe_classification() {
            tokio::spawn(async move {
                while let Ok(result) = broadcast_rx.recv().await {
                    if tx.send(result).is_err() {
                        break;
                    }
                }
            });
        }

        rx
    }

    pub fn subscribe_calibration(&self) -> mpsc::UnboundedReceiver<CalibrationProgress> {
        let (tx, rx) = mpsc::unbounded_channel();

        if let Some(mut broadcast_rx) = self.broadcasts.subscribe_calibration() {
            tokio::spawn(async move {
                while let Ok(progress) = broadcast_rx.recv().await {
                    if tx.send(progress).is_err() {
                        break;
                    }
                }
            });
        }

        rx
    }

    pub fn subscribe_audio_metrics(&self) -> mpsc::UnboundedReceiver<AudioMetrics> {
        let (tx, rx) = mpsc::unbounded_channel();

        if let Some(mut broadcast_rx) = self.broadcasts.subscribe_audio_metrics() {
            tokio::spawn(async move {
                while let Ok(metrics) = broadcast_rx.recv().await {
                    if tx.send(metrics).is_err() {
                        break;
                    }
                }
            });
        }

        rx
    }

    pub fn subscribe_onset_events(&self) -> mpsc::UnboundedReceiver<OnsetEvent> {
        let (tx, rx) = mpsc::unbounded_channel();

        if let Some(mut broadcast_rx) = self.broadcasts.subscribe_onset_events() {
            tokio::spawn(async move {
                while let Ok(event) = broadcast_rx.recv().await {
                    if tx.send(event).is_err() {
                        break;
                    }
                }
            });
        }

        rx
    }

    pub fn subscribe_telemetry(&self) -> mpsc::UnboundedReceiver<TelemetryEvent> {
        let (tx, rx) = mpsc::unbounded_channel();
        let mut broadcast_rx = self.telemetry_tx.subscribe();

        tokio::spawn(async move {
            while let Ok(event) = broadcast_rx.recv().await {
                if tx.send(event).is_err() {
                    break;
                }
            }
        });

        rx
    }

    // ========================================================================
    // ASYNC STREAM ADAPTERS
    // ========================================================================

    pub async fn classification_stream(&self) -> impl Stream<Item = ClassificationResult> + Unpin {
        UnboundedReceiverStream::new(self.subscribe_classification())
    }

    pub async fn calibration_stream(&self) -> impl Stream<Item = CalibrationProgress> + Unpin {
        UnboundedReceiverStream::new(self.subscribe_calibration())
    }

    pub async fn audio_metrics_stream(&self) -> impl Stream<Item = AudioMetrics> + Unpin {
        UnboundedReceiverStream::new(self.subscribe_audio_metrics())
    }

    pub async fn onset_events_stream(&self) -> impl Stream<Item = OnsetEvent> + Unpin {
        UnboundedReceiverStream::new(self.subscribe_onset_events())
    }

    pub async fn telemetry_stream(&self) -> impl Stream<Item = TelemetryEvent> + Unpin {
        UnboundedReceiverStream::new(self.subscribe_telemetry())
    }

    // ========================================================================
    // PARAM PATCH COMMANDS
    // ========================================================================

    /// Get a clone of the sender for ParamPatch commands.
    pub fn command_sender(&self) -> mpsc::Sender<ParamPatch> {
        self.command_tx.clone()
    }

    /// Snapshot the current app configuration (desktop tooling helper).
    #[cfg(not(target_os = "android"))]
    pub fn config_snapshot(&self) -> AppConfig {
        self.config
            .read()
            .map(|cfg| cfg.clone())
            .unwrap_or_else(|err| err.into_inner().clone())
    }

    /// Expose calibration state handle for fixture processors.
    #[cfg(not(target_os = "android"))]
    pub fn calibration_state_handle(&self) -> Arc<RwLock<CalibrationState>> {
        self.calibration.get_state_arc()
    }
}

// ========================================================================
// TEST HELPERS
// ========================================================================

#[cfg(test)]
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

impl Default for EngineHandle {
    fn default() -> Self {
        Self::new()
    }
}
