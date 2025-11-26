use std::sync::atomic::Ordering;
use std::sync::{Arc, RwLock};

use futures::Stream;
use tokio::runtime::Builder;
use tokio::sync::{broadcast, mpsc};
use tokio_stream::wrappers::UnboundedReceiverStream;

use super::TelemetryEvent;
use crate::analysis::ClassificationResult;
use crate::api::{AudioMetrics, OnsetEvent};
#[cfg(any(test, feature = "diagnostics_fixtures"))]
use crate::calibration::CalibrationProcedure;
use crate::calibration::{CalibrationProgress, CalibrationState};
use crate::config::AppConfig;

use super::{EngineHandle, ParamPatch};

impl EngineHandle {
    // ========================================================================
    // STREAM SUBSCRIPTIONS
    // ========================================================================

    pub fn subscribe_classification(&self) -> mpsc::UnboundedReceiver<ClassificationResult> {
        let (tx, rx) = mpsc::unbounded_channel();

        if let Some(mut broadcast_rx) = self.broadcasts.subscribe_classification() {
            std::thread::spawn(move || {
                let rt = Builder::new_current_thread()
                    .enable_all()
                    .build()
                    .expect("Failed to create Tokio runtime");
                rt.block_on(async move {
                    while let Ok(result) = broadcast_rx.recv().await {
                        if tx.send(result).is_err() {
                            break;
                        }
                    }
                });
            });
        }

        rx
    }

    pub fn subscribe_calibration(&self) -> mpsc::UnboundedReceiver<CalibrationProgress> {
        let (tx, rx) = mpsc::unbounded_channel();

        if let Some(mut broadcast_rx) = self.broadcasts.subscribe_calibration() {
            std::thread::spawn(move || {
                let rt = Builder::new_current_thread()
                    .enable_all()
                    .build()
                    .expect("Failed to create Tokio runtime");
                rt.block_on(async move {
                    while let Ok(progress) = broadcast_rx.recv().await {
                        if tx.send(progress).is_err() {
                            break;
                        }
                    }
                });
            });
        }

        rx
    }

    pub fn subscribe_audio_metrics(&self) -> mpsc::UnboundedReceiver<AudioMetrics> {
        let (tx, rx) = mpsc::unbounded_channel();

        if let Some(mut broadcast_rx) = self.broadcasts.subscribe_audio_metrics() {
            std::thread::spawn(move || {
                let rt = Builder::new_current_thread()
                    .enable_all()
                    .build()
                    .expect("Failed to create Tokio runtime");
                rt.block_on(async move {
                    while let Ok(metrics) = broadcast_rx.recv().await {
                        if tx.send(metrics).is_err() {
                            break;
                        }
                    }
                });
            });
        }

        rx
    }

    pub fn subscribe_onset_events(&self) -> mpsc::UnboundedReceiver<OnsetEvent> {
        let (tx, rx) = mpsc::unbounded_channel();

        if let Some(mut broadcast_rx) = self.broadcasts.subscribe_onset_events() {
            std::thread::spawn(move || {
                let rt = Builder::new_current_thread()
                    .enable_all()
                    .build()
                    .expect("Failed to create Tokio runtime");
                rt.block_on(async move {
                    while let Ok(event) = broadcast_rx.recv().await {
                        if tx.send(event).is_err() {
                            break;
                        }
                    }
                });
            });
        }

        rx
    }

    pub fn subscribe_telemetry(&self) -> mpsc::UnboundedReceiver<TelemetryEvent> {
        let (tx, rx) = mpsc::unbounded_channel();
        let mut broadcast_rx = self.telemetry_tx.subscribe();

        std::thread::spawn(move || {
            let rt = Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("Failed to create Tokio runtime");
            rt.block_on(async move {
                while let Ok(event) = broadcast_rx.recv().await {
                    if tx.send(event).is_err() {
                        break;
                    }
                }
            });
        });

        rx
    }

    pub fn telemetry_receiver(&self) -> broadcast::Receiver<TelemetryEvent> {
        self.telemetry_tx.subscribe()
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

    /// Check whether audio backend is running (best effort).
    pub fn is_audio_running(&self) -> bool {
        self.engine_running.load(Ordering::SeqCst)
    }

    /// Milliseconds elapsed since the handle was created (used for telemetry).
    pub fn uptime_ms(&self) -> u64 {
        self.time_source
            .now()
            .saturating_duration_since(self.start_instant)
            .as_millis() as u64
    }

    /// Snapshot the current app configuration (tooling helper).
    pub fn config_snapshot(&self) -> AppConfig {
        self.config
            .read()
            .map(|cfg| cfg.clone())
            .unwrap_or_else(|err| err.into_inner().clone())
    }

    /// Expose calibration state handle for fixture processors.
    pub fn calibration_state_handle(&self) -> Arc<RwLock<CalibrationState>> {
        self.calibration.get_state_arc()
    }

    /// Expose calibration procedure handle when diagnostics fixtures need it.
    #[cfg(any(test, feature = "diagnostics_fixtures"))]
    pub fn calibration_procedure_handle(
        &self,
    ) -> Arc<std::sync::Mutex<Option<CalibrationProcedure>>> {
        self.calibration.get_procedure_arc()
    }
}
