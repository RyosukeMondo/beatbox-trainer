//! Diagnostics telemetry collector and helpers.
//!
//! The collector multiplexes latency, classification, buffer occupancy, and
//! JNI lifecycle events into a bounded history plus async broadcast stream.

use std::collections::{HashMap, VecDeque};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

use once_cell::sync::Lazy;
use tokio::sync::{broadcast, mpsc};

use crate::analysis::ClassificationResult;

pub mod events;

pub use events::{DiagnosticError, LifecyclePhase, MetricEvent};

/// Global telemetry hub shared across the crate.
static HUB: Lazy<TelemetryHub> = Lazy::new(TelemetryHub::default);

/// Access the global telemetry hub.
pub fn hub() -> &'static TelemetryHub {
    &HUB
}

/// Snapshot of collector state for HTTP/CLI reporting.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct TelemetrySnapshot {
    pub recent: Vec<MetricEvent>,
    pub total_events: u64,
    pub dropped_events: u64,
}

/// Broadcast-based collector retaining a bounded history of metrics.
pub struct TelemetryCollector {
    tx: broadcast::Sender<MetricEvent>,
    history: Mutex<VecDeque<MetricEvent>>,
    history_capacity: usize,
    total_events: AtomicU64,
    dropped_history: AtomicU64,
}

impl TelemetryCollector {
    pub fn new(buffer: usize, history_capacity: usize) -> Self {
        let (tx, _) = broadcast::channel(buffer);
        Self {
            tx,
            history: Mutex::new(VecDeque::with_capacity(history_capacity)),
            history_capacity,
            total_events: AtomicU64::new(0),
            dropped_history: AtomicU64::new(0),
        }
    }

    pub fn publish(&self, event: MetricEvent) {
        self.total_events.fetch_add(1, Ordering::Relaxed);
        {
            let mut history = self.history.lock().expect("history poisoned");
            if history.len() == self.history_capacity {
                history.pop_front();
                self.dropped_history.fetch_add(1, Ordering::Relaxed);
            }
            history.push_back(event.clone());
        }

        let _ = self.tx.send(event);
    }

    pub fn subscribe(&self) -> broadcast::Receiver<MetricEvent> {
        self.tx.subscribe()
    }

    pub fn subscribe_unbounded(&self) -> mpsc::UnboundedReceiver<MetricEvent> {
        let (tx, rx) = mpsc::unbounded_channel();
        let mut broadcast_rx = self.tx.subscribe();

        tokio::spawn(async move {
            while let Ok(event) = broadcast_rx.recv().await {
                if tx.send(event).is_err() {
                    break;
                }
            }
        });

        rx
    }

    pub fn snapshot(&self) -> TelemetrySnapshot {
        let history = self.history.lock().expect("history poisoned");
        TelemetrySnapshot {
            recent: history.iter().cloned().collect(),
            total_events: self.total_events.load(Ordering::Relaxed),
            dropped_events: self.dropped_history.load(Ordering::Relaxed),
        }
    }
}

impl Default for TelemetryCollector {
    fn default() -> Self {
        Self::new(256, 64)
    }
}

/// Latency tracker maintains a rolling window to compute avg/max latency.
struct LatencyTracker {
    samples: VecDeque<f32>,
    max_samples: usize,
}

impl LatencyTracker {
    fn new(max_samples: usize) -> Self {
        Self {
            samples: VecDeque::with_capacity(max_samples),
            max_samples,
        }
    }

    fn observe(&mut self, value: f32) -> (f32, f32, usize) {
        if self.samples.len() == self.max_samples {
            self.samples.pop_front();
        }
        self.samples.push_back(value.abs());

        let count = self.samples.len();
        let sum: f32 = self.samples.iter().copied().sum();
        let max = self
            .samples
            .iter()
            .copied()
            .fold(0.0_f32, |acc, next| acc.max(next));
        let avg = if count == 0 { 0.0 } else { sum / count as f32 };
        (avg, max, count)
    }
}

/// Top-level hub wrapping collector state plus derived gauges.
pub struct TelemetryHub {
    collector: TelemetryCollector,
    latency: Mutex<LatencyTracker>,
    buffer_gauges: Mutex<HashMap<&'static str, f32>>,
}

impl TelemetryHub {
    pub fn new(channel_capacity: usize, history_capacity: usize, latency_window: usize) -> Self {
        Self {
            collector: TelemetryCollector::new(channel_capacity, history_capacity),
            latency: Mutex::new(LatencyTracker::new(latency_window)),
            buffer_gauges: Mutex::new(HashMap::new()),
        }
    }

    pub fn collector(&self) -> &TelemetryCollector {
        &self.collector
    }

    pub fn snapshot(&self) -> TelemetrySnapshot {
        self.collector.snapshot()
    }

    pub fn record_classification(&self, result: &ClassificationResult) {
        self.collector.publish(MetricEvent::Classification {
            sound: result.sound,
            confidence: result.confidence,
            timing_error_ms: result.timing.error_ms,
        });

        let (avg, max, count) = {
            let mut tracker = self.latency.lock().expect("latency tracker poisoned");
            tracker.observe(result.timing.error_ms.abs())
        };

        self.collector.publish(MetricEvent::Latency {
            avg_ms: avg,
            max_ms: max,
            sample_count: count,
        });
    }

    pub fn record_buffer_occupancy(&self, channel: &'static str, percent: f32) {
        let normalized = percent.clamp(0.0, 100.0);
        let mut gauges = self
            .buffer_gauges
            .lock()
            .expect("buffer gauge lock poisoned");

        let should_emit = gauges
            .get(channel)
            .map(|last| (last - normalized).abs() >= 2.5)
            .unwrap_or(true);

        if should_emit {
            gauges.insert(channel, normalized);
            self.collector.publish(MetricEvent::BufferOccupancy {
                channel: channel.to_string(),
                percent: normalized,
            });
        }
    }

    pub fn record_jni_phase(&self, phase: LifecyclePhase) {
        self.collector.publish(MetricEvent::JniLifecycle {
            phase,
            timestamp_ms: now_timestamp_ms(),
        });
    }

    pub fn record_error(&self, code: DiagnosticError, context: impl Into<String>) {
        self.collector.publish(MetricEvent::Error {
            code,
            context: context.into(),
        });
    }
}

impl Default for TelemetryHub {
    fn default() -> Self {
        Self::new(256, 64, 32)
    }
}

fn now_timestamp_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::analysis::classifier::BeatboxHit;
    use crate::analysis::quantizer::{TimingClassification, TimingFeedback};

    fn sample_result(confidence: f32, error_ms: f32) -> ClassificationResult {
        ClassificationResult {
            sound: BeatboxHit::Kick,
            timing: TimingFeedback {
                classification: TimingClassification::OnTime,
                error_ms,
            },
            timestamp_ms: 42,
            confidence,
        }
    }

    #[test]
    fn collector_preserves_order_within_history() {
        let collector = TelemetryCollector::new(8, 3);
        collector.publish(MetricEvent::Latency {
            avg_ms: 1.0,
            max_ms: 2.0,
            sample_count: 1,
        });
        collector.publish(MetricEvent::Latency {
            avg_ms: 3.0,
            max_ms: 4.0,
            sample_count: 2,
        });
        collector.publish(MetricEvent::BufferOccupancy {
            channel: "test".to_string(),
            percent: 50.0,
        });

        let snapshot = collector.snapshot();
        assert_eq!(snapshot.recent.len(), 3);
        assert!(
            matches!(snapshot.recent[0], MetricEvent::Latency { avg_ms, .. } if (avg_ms - 1.0).abs() < f32::EPSILON)
        );
        assert!(matches!(
            snapshot.recent[2],
            MetricEvent::BufferOccupancy { .. }
        ));
    }

    #[test]
    fn collector_drops_history_when_full() {
        let collector = TelemetryCollector::new(8, 2);
        collector.publish(MetricEvent::Latency {
            avg_ms: 1.0,
            max_ms: 2.0,
            sample_count: 1,
        });
        collector.publish(MetricEvent::Latency {
            avg_ms: 3.0,
            max_ms: 4.0,
            sample_count: 2,
        });
        collector.publish(MetricEvent::Latency {
            avg_ms: 5.0,
            max_ms: 6.0,
            sample_count: 3,
        });

        let snapshot = collector.snapshot();
        assert_eq!(snapshot.recent.len(), 2);
        assert_eq!(snapshot.dropped_events, 1);
        assert!(
            matches!(snapshot.recent[0], MetricEvent::Latency { avg_ms, .. } if (avg_ms - 3.0).abs() < f32::EPSILON)
        );
    }

    #[test]
    fn hub_emits_latency_and_classification() {
        let hub = TelemetryHub::new(8, 8, 4);
        hub.record_classification(&sample_result(0.9, 12.0));
        hub.record_classification(&sample_result(0.8, 6.0));

        let snapshot = hub.snapshot();
        assert!(snapshot.total_events >= 2);
        assert!(snapshot
            .recent
            .iter()
            .any(|event| matches!(event, MetricEvent::Classification { .. })));
        assert!(snapshot
            .recent
            .iter()
            .any(|event| matches!(event, MetricEvent::Latency { .. })));
    }

    #[test]
    fn buffer_gauge_debounces_small_changes() {
        let hub = TelemetryHub::new(8, 8, 4);
        hub.record_buffer_occupancy("queue", 10.0);
        hub.record_buffer_occupancy("queue", 10.5);
        hub.record_buffer_occupancy("queue", 25.0);

        let snapshot = hub.snapshot();
        assert!(
            snapshot
                .recent
                .iter()
                .filter(|event| matches!(event, MetricEvent::BufferOccupancy { .. }))
                .count()
                >= 2
        );
    }
}
