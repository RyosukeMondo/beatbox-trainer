//! EngineHandle: reusable audio/DSP orchestration layer.
//!
//! This struct supersedes the old `AppContext`, exposing trait-based backends,
//! telemetry channels, and a `ParamPatch` command pipeline shared across CLI,
//! HTTP, and FRB entry points.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, RwLock};
use std::time::Instant;

use serde::{Deserialize, Serialize};
use tokio::sync::{broadcast, mpsc, Mutex};

use crate::calibration::{CalibrationProgress, CalibrationState};
use crate::config::AppConfig;
use crate::engine::backend::{AudioBackend, EngineStartContext, TimeSource};
#[cfg(not(target_os = "android"))]
use crate::engine::backend::{CpalBackend, StubTimeSource};
#[cfg(target_os = "android")]
use crate::engine::backend::{OboeBackend, SystemTimeSource};
use crate::error::{AudioError, CalibrationError};
use crate::managers::{BroadcastChannelManager, CalibrationManager};

#[path = "core_subscriptions.rs"]
mod core_subscriptions;

/// Patch describing parameter updates to apply to the running engine.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ParamPatch {
    #[serde(default)]
    pub bpm: Option<u32>,
    #[serde(default)]
    pub centroid_threshold: Option<f32>,
    #[serde(default)]
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
    engine_running: AtomicBool,
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
            engine_running: AtomicBool::new(false),
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
    fn create_backend(config: &AppConfig) -> Arc<dyn AudioBackend> {
        Arc::new(CpalBackend::new(
            config.audio.clone(),
            config.onset_detection.clone(),
            config.calibration.log_every_n_buffers,
        ))
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

        // Spawn a dedicated thread with its own Tokio runtime
        // This is necessary because the Flutter Rust Bridge may not have a Tokio runtime
        // available on desktop platforms when this is called
        std::thread::spawn(move || {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("Failed to create Tokio runtime for command worker");

            rt.block_on(async move {
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

        // Initialize audio metrics channel for live level meter
        let audio_metrics_tx = Some(self.broadcasts.init_audio_metrics());

        let ctx = EngineStartContext {
            bpm,
            calibration_state,
            calibration_procedure,
            calibration_progress_tx,
            classification_tx: broadcast_tx,
            audio_metrics_tx,
        };

        self.backend.start(ctx)?;
        self.engine_running.store(true, Ordering::SeqCst);
        self.emit_event(TelemetryEventKind::EngineStarted { bpm }, None);
        self.init_command_worker();
        Ok(())
    }

    /// Stop the audio engine.
    pub fn stop_audio(&self) -> Result<(), AudioError> {
        if !self.engine_running.load(Ordering::SeqCst) {
            return Err(AudioError::NotRunning);
        }

        self.backend.stop()?;
        self.engine_running.store(false, Ordering::SeqCst);
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

        // Stop any existing audio and restart for calibration on all platforms
        if let Err(err) = self.stop_audio() {
            eprintln!(
                "Warning: Failed to stop audio engine during calibration start: {:?}",
                err
            );
        }

        const DEFAULT_CALIBRATION_BPM: u32 = 120;
        self.start_audio(DEFAULT_CALIBRATION_BPM)
            .map_err(|audio_err| CalibrationError::Timeout {
                reason: format!(
                    "Failed to start audio engine for calibration: {:?}",
                    audio_err
                ),
            })?;

        // Emit initial calibration progress so UI can show the calibration interface
        if let Some(tx) = self.broadcasts.get_calibration_sender() {
            if let Ok(procedure_guard) = self.calibration.get_procedure_arc().lock() {
                if let Some(ref procedure) = *procedure_guard {
                    let initial_progress = procedure.get_progress();
                    log::info!(
                        "[EngineHandle] Emitting initial calibration progress: {:?}",
                        initial_progress
                    );
                    let _ = tx.send(initial_progress);
                }
            }
        }

        Ok(())
    }

    pub fn finish_calibration(&self) -> Result<(), CalibrationError> {
        self.calibration.finish()
    }

    /// User confirms current calibration step and advances to next sound
    ///
    /// Called when user clicks "OK" after reviewing current sound samples.
    /// Emits updated progress via calibration stream.
    ///
    /// # Returns
    /// * `Ok(true)` - Advanced to next sound
    /// * `Ok(false)` - Calibration complete
    pub fn confirm_calibration_step(&self) -> Result<bool, CalibrationError> {
        let result = self.calibration.confirm_step()?;

        // Emit progress update after confirmation
        if let Some(tx) = self.broadcasts.get_calibration_sender() {
            if let Ok(procedure_guard) = self.calibration.get_procedure_arc().lock() {
                if let Some(ref procedure) = *procedure_guard {
                    let progress = procedure.get_progress();
                    log::info!(
                        "[EngineHandle] Emitting calibration progress after confirm: {:?}",
                        progress
                    );
                    let _ = tx.send(progress);
                }
            }
        }

        Ok(result)
    }

    /// User wants to retry the current calibration step
    ///
    /// Called when user clicks "Retry" to redo current sound samples.
    /// Emits updated progress via calibration stream.
    pub fn retry_calibration_step(&self) -> Result<(), CalibrationError> {
        self.calibration.retry_step()?;

        // Emit progress update after retry
        if let Some(tx) = self.broadcasts.get_calibration_sender() {
            if let Ok(procedure_guard) = self.calibration.get_procedure_arc().lock() {
                if let Some(ref procedure) = *procedure_guard {
                    let progress = procedure.get_progress();
                    log::info!(
                        "[EngineHandle] Emitting calibration progress after retry: {:?}",
                        progress
                    );
                    let _ = tx.send(progress);
                }
            }
        }

        Ok(())
    }

    /// Manually accept the last rejected candidate for the active calibration sound.
    ///
    /// Useful when adaptive gates are too strict; emits updated progress on success.
    pub fn manual_accept_last_candidate(&self) -> Result<CalibrationProgress, CalibrationError> {
        let progress = self.calibration.manual_accept_last_candidate()?;

        if let Some(tx) = self.broadcasts.get_calibration_sender() {
            let _ = tx.send(progress.clone());
        }

        Ok(progress)
    }
}

// ========================================================================
// TEST HELPERS
// ========================================================================

#[cfg(test)]
mod tests;

impl Default for EngineHandle {
    fn default() -> Self {
        Self::new()
    }
}
