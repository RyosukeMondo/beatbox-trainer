use std::collections::BTreeMap;

use anyhow::{Context, Result};
use beatbox_trainer::analysis::ClassificationResult;
use beatbox_trainer::telemetry::MetricEvent;
use serde::Serialize;
use tokio::sync::broadcast::{error::TryRecvError, Receiver};

#[derive(Default)]
pub struct TelemetryAggregator {
    total_events: usize,
    lagged_events: usize,
    last_latency: Option<LatencySummary>,
    buffers: BTreeMap<String, f32>,
    classification_count: usize,
    last_classification: Option<ClassificationMetric>,
    lifecycle: Vec<LifecycleEntry>,
    errors: Vec<String>,
}

impl TelemetryAggregator {
    pub fn record(&mut self, event: MetricEvent) {
        self.total_events += 1;
        match event {
            MetricEvent::Latency {
                avg_ms,
                max_ms,
                sample_count,
            } => {
                self.last_latency = Some(LatencySummary {
                    avg_ms,
                    max_ms,
                    sample_count,
                });
            }
            MetricEvent::BufferOccupancy { channel, percent } => {
                self.buffers.insert(channel, percent);
            }
            MetricEvent::Classification {
                sound,
                confidence,
                timing_error_ms,
            } => {
                self.classification_count += 1;
                self.last_classification = Some(ClassificationMetric {
                    sound: format!("{sound:?}"),
                    confidence,
                    timing_error_ms,
                });
            }
            MetricEvent::JniLifecycle {
                phase,
                timestamp_ms,
            } => self.lifecycle.push(LifecycleEntry {
                phase: format!("{phase:?}"),
                timestamp_ms,
            }),
            MetricEvent::Error { code, context } => {
                self.errors.push(format!("{code:?}: {context}"))
            }
        }
    }

    pub fn lagged(&mut self, skipped: usize) {
        self.lagged_events += skipped;
    }

    pub fn into_report(self, collector_total: u64, collector_dropped: u64) -> TelemetryReport {
        TelemetryReport {
            observed_events: self.total_events,
            collector_total,
            collector_dropped,
            lagged_events: self.lagged_events,
            latency: self.last_latency,
            buffer_levels: self.buffers,
            classification_count: self.classification_count,
            last_classification: self.last_classification,
            lifecycle_events: self.lifecycle,
            error_messages: self.errors,
        }
    }
}

pub fn drain_metrics(rx: &mut Receiver<MetricEvent>, aggregator: &mut TelemetryAggregator) {
    loop {
        match rx.try_recv() {
            Ok(event) => aggregator.record(event),
            Err(TryRecvError::Lagged(skipped)) => aggregator.lagged(skipped as usize),
            Err(TryRecvError::Empty) | Err(TryRecvError::Closed) => break,
        }
    }
}

#[derive(Debug, Serialize)]
pub struct TelemetryReport {
    pub observed_events: usize,
    pub collector_total: u64,
    pub collector_dropped: u64,
    pub lagged_events: usize,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub latency: Option<LatencySummary>,
    #[serde(skip_serializing_if = "BTreeMap::is_empty")]
    pub buffer_levels: BTreeMap<String, f32>,
    pub classification_count: usize,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_classification: Option<ClassificationMetric>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub lifecycle_events: Vec<LifecycleEntry>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub error_messages: Vec<String>,
}

impl TelemetryReport {
    pub fn print_json(&self) -> Result<()> {
        let json = serde_json::to_string_pretty(self).context("serializing telemetry report")?;
        println!("{json}");
        Ok(())
    }

    pub fn print_table(&self) {
        println!("Telemetry Events Observed : {}", self.observed_events);
        println!(
            "Collector totals         : {} (dropped {}, lagged {})",
            self.collector_total, self.collector_dropped, self.lagged_events
        );

        if let Some(latency) = &self.latency {
            println!(
                "Latency avg/max (ms)     : {:.2} / {:.2} over {} samples",
                latency.avg_ms, latency.max_ms, latency.sample_count
            );
        } else {
            println!("Latency avg/max (ms)     : n/a");
        }

        println!("Classification events    : {}", self.classification_count);
        if let Some(last) = &self.last_classification {
            println!(
                "Last classification      : {} (confidence {:.2}, timing {:.2} ms)",
                last.sound, last.confidence, last.timing_error_ms
            );
        }

        if self.buffer_levels.is_empty() {
            println!("Buffer occupancy         : n/a");
        } else {
            println!("Buffer occupancy         :");
            for (channel, percent) in &self.buffer_levels {
                println!("  - {channel}: {:.1}%", percent);
            }
        }

        if !self.lifecycle_events.is_empty() {
            println!("Lifecycle events         :");
            for entry in &self.lifecycle_events {
                println!("  - {} @ {} ms", entry.phase, entry.timestamp_ms);
            }
        }

        if !self.error_messages.is_empty() {
            println!("Errors                   :");
            for msg in &self.error_messages {
                println!("  - {msg}");
            }
        }
    }
}

#[derive(Debug, Serialize)]
pub struct LatencySummary {
    pub avg_ms: f32,
    pub max_ms: f32,
    pub sample_count: usize,
}

#[derive(Debug, Serialize)]
pub struct ClassificationMetric {
    pub sound: String,
    pub confidence: f32,
    pub timing_error_ms: f32,
}

#[derive(Debug, Serialize)]
pub struct LifecycleEntry {
    pub phase: String,
    pub timestamp_ms: u64,
}

#[derive(Debug, Serialize)]
pub struct RecordPayload {
    pub fixture_id: String,
    pub sample_rate: u32,
    pub event_count: usize,
    pub events: Vec<ClassificationResult>,
}
