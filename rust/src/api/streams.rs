use crate::bridge_generated::StreamSink;
use crate::engine::core::TelemetryEvent;
use crate::error::AudioError;
use crate::telemetry::{self, MetricEvent};

use super::{AudioMetrics, OnsetEvent, ENGINE_HANDLE};

/// Stream of audio metrics for debug visualization
///
/// Emits AudioMetrics with real-time DSP metrics from the audio processing pipeline.
/// Useful for debugging and development.
#[allow(unused_must_use)]
#[flutter_rust_bridge::frb]
pub fn audio_metrics_stream(sink: StreamSink<AudioMetrics>) {
    let mut metrics_rx = ENGINE_HANDLE.subscribe_audio_metrics();

    std::thread::spawn(move || {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("Failed to create Tokio runtime for audio metrics stream");

        rt.block_on(async move {
            loop {
                match metrics_rx.recv().await {
                    Some(metrics) => {
                        if sink.add(metrics).is_err() {
                            break;
                        }
                    }
                    None => {
                        let _ = sink.add_error(AudioError::StreamFailure {
                            reason: "audio metrics channel closed".to_string(),
                        });
                        break;
                    }
                }
            }
        });
    });
}

/// Stream of telemetry events for debug instrumentation
///
/// Emits engine lifecycle events (start/stop, BPM changes) and warnings.
#[allow(unused_must_use)]
#[flutter_rust_bridge::frb]
pub fn telemetry_stream(sink: StreamSink<TelemetryEvent>) {
    let mut telemetry_rx = ENGINE_HANDLE.subscribe_telemetry();

    std::thread::spawn(move || {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("Failed to create Tokio runtime for telemetry stream");

        rt.block_on(async move {
            loop {
                match telemetry_rx.recv().await {
                    Some(event) => {
                        if sink.add(event).is_err() {
                            break;
                        }
                    }
                    None => {
                        let _ = sink.add_error(AudioError::StreamFailure {
                            reason: "telemetry channel closed".to_string(),
                        });
                        break;
                    }
                }
            }
        });
    });
}

/// Stream of diagnostic metrics aggregated from telemetry hub.
#[allow(unused_must_use)]
#[flutter_rust_bridge::frb]
pub fn diagnostic_metrics_stream(sink: StreamSink<MetricEvent>) {
    let mut metrics_rx = telemetry::hub().collector().subscribe_unbounded();

    std::thread::spawn(move || {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("Failed to create Tokio runtime for diagnostic metrics stream");

        rt.block_on(async move {
            loop {
                match metrics_rx.recv().await {
                    Some(event) => {
                        if sink.add(event).is_err() {
                            break;
                        }
                    }
                    None => {
                        let _ = sink.add_error(AudioError::StreamFailure {
                            reason: "diagnostic metrics channel closed".to_string(),
                        });
                        break;
                    }
                }
            }
        });
    });
}

/// Stream of onset events for debug visualization
///
/// Emits OnsetEvent whenever an onset is detected.
#[allow(unused_must_use)]
#[flutter_rust_bridge::frb]
pub fn onset_events_stream(sink: StreamSink<OnsetEvent>) {
    let mut onset_rx = ENGINE_HANDLE.subscribe_onset_events();

    std::thread::spawn(move || {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("Failed to create Tokio runtime for onset events stream");

        rt.block_on(async move {
            loop {
                match onset_rx.recv().await {
                    Some(event) => {
                        if sink.add(event).is_err() {
                            break;
                        }
                    }
                    None => {
                        let _ = sink.add_error(AudioError::StreamFailure {
                            reason: "onset events channel closed".to_string(),
                        });
                        break;
                    }
                }
            }
        });
    });
}
