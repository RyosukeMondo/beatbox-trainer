//! Core telemetry event types describing diagnostics data exposed to
//! CLI/HTTP surfaces and flutter_rust_bridge streams.

use serde::{Deserialize, Serialize};

use crate::analysis::classifier::BeatboxHit;

/// High-level lifecycle stages reported by JNI/engine instrumentation.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum LifecyclePhase {
    LibraryLoaded,
    ContextInitialized,
    PermissionsGranted,
    PermissionsDenied,
    LibraryUnloaded,
}

/// Diagnostic error codes surfaced via telemetry metrics.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum DiagnosticError {
    FixtureLoad,
    BufferDrain,
    StreamBackpressure,
    Unknown,
}

/// Rich metric events covering latency, buffer occupancy, and lifecycle details.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "type", content = "payload", rename_all = "snake_case")]
pub enum MetricEvent {
    Latency {
        avg_ms: f32,
        max_ms: f32,
        sample_count: usize,
    },
    BufferOccupancy {
        channel: String,
        percent: f32,
    },
    Classification {
        sound: BeatboxHit,
        confidence: f32,
        timing_error_ms: f32,
    },
    JniLifecycle {
        phase: LifecyclePhase,
        timestamp_ms: u64,
    },
    Error {
        code: DiagnosticError,
        context: String,
    },
}
