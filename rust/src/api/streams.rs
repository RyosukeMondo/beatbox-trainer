use futures::Stream;

use crate::bridge_generated::StreamSink;
use crate::engine::core::TelemetryEvent;
use crate::error::AudioError;
use crate::telemetry::{self, MetricEvent};

use super::{AudioMetrics, OnsetEvent, ENGINE_HANDLE};

/// Stream of audio metrics for debug visualization
///
/// Returns a stream that yields AudioMetrics with real-time DSP metrics
/// from the audio processing pipeline. Useful for debugging and development.
#[flutter_rust_bridge::frb(ignore)]
pub async fn audio_metrics_stream() -> impl Stream<Item = AudioMetrics> {
    ENGINE_HANDLE.audio_metrics_stream().await
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
/// Returns a stream that yields OnsetEvent whenever an onset is detected.
#[flutter_rust_bridge::frb(ignore)]
pub async fn onset_events_stream() -> impl Stream<Item = OnsetEvent> {
    ENGINE_HANDLE.onset_events_stream().await
}
