// Pipeline Tracer - Diagnostic logging for the audio analysis pipeline
//
// Provides structured trace points throughout the DSP pipeline to help debug
// signal flow issues. Each stage of processing logs its state when tracing
// is enabled, making it easy to identify where signals are lost or transformed.
//
// Usage:
//   - Enable with BEATBOX_TRACE=1 environment variable
//   - Traces appear in logs with [TRACE] prefix
//   - Each trace includes stage name, timestamp, and relevant metrics

use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::time::Instant;

/// Global flag to enable/disable pipeline tracing
static TRACING_ENABLED: AtomicBool = AtomicBool::new(false);

/// Counter for trace events (helps correlate related traces)
static TRACE_COUNTER: AtomicU64 = AtomicU64::new(0);

/// Initialize pipeline tracing based on environment variable
pub fn init() {
    let enabled = std::env::var("BEATBOX_TRACE")
        .map(|v| v == "1" || v.to_lowercase() == "true")
        .unwrap_or(false);
    TRACING_ENABLED.store(enabled, Ordering::SeqCst);
    if enabled {
        log::info!("[TRACE] Pipeline tracing ENABLED - set BEATBOX_TRACE=0 to disable");
    }
}

/// Check if tracing is enabled
#[inline]
pub fn is_enabled() -> bool {
    TRACING_ENABLED.load(Ordering::Relaxed)
}

/// Enable tracing at runtime
pub fn enable() {
    TRACING_ENABLED.store(true, Ordering::SeqCst);
    log::info!("[TRACE] Pipeline tracing enabled at runtime");
}

/// Disable tracing at runtime
pub fn disable() {
    TRACING_ENABLED.store(false, Ordering::SeqCst);
    log::info!("[TRACE] Pipeline tracing disabled at runtime");
}

/// Pipeline stages for structured logging
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PipelineStage {
    /// Audio callback receives raw samples
    AudioCallback,
    /// Buffer queued to analysis thread
    BufferQueued,
    /// Analysis thread receives buffer
    AnalysisReceive,
    /// RMS level computed
    RmsComputed,
    /// Gate decision (above/below threshold)
    GateDecision,
    /// Onset detected by spectral flux
    OnsetDetected,
    /// Level crossing detected
    LevelCrossing,
    /// Features extracted from audio window
    FeaturesExtracted,
    /// Classification decision made
    Classification,
    /// Result sent to Dart
    ResultSent,
    /// Calibration sample collected
    CalibrationSample,
}

impl PipelineStage {
    pub fn as_str(&self) -> &'static str {
        match self {
            PipelineStage::AudioCallback => "AUDIO_CB",
            PipelineStage::BufferQueued => "BUF_QUEUE",
            PipelineStage::AnalysisReceive => "ANALYSIS_RX",
            PipelineStage::RmsComputed => "RMS",
            PipelineStage::GateDecision => "GATE",
            PipelineStage::OnsetDetected => "ONSET",
            PipelineStage::LevelCrossing => "LEVEL_X",
            PipelineStage::FeaturesExtracted => "FEATURES",
            PipelineStage::Classification => "CLASSIFY",
            PipelineStage::ResultSent => "RESULT_TX",
            PipelineStage::CalibrationSample => "CAL_SAMPLE",
        }
    }
}

/// Trace event data for a single pipeline stage
#[derive(Debug, Clone)]
pub struct TraceEvent {
    pub id: u64,
    pub stage: PipelineStage,
    pub timestamp_us: u64,
    pub message: String,
}

/// Global start time for relative timestamps
static START_TIME: std::sync::OnceLock<Instant> = std::sync::OnceLock::new();

fn get_timestamp_us() -> u64 {
    let start = START_TIME.get_or_init(Instant::now);
    start.elapsed().as_micros() as u64
}

/// Log a trace event at a pipeline stage
///
/// Only logs if BEATBOX_TRACE=1 is set.
///
/// # Arguments
/// * `stage` - The pipeline stage
/// * `message` - Descriptive message with metrics
#[inline]
pub fn trace(stage: PipelineStage, message: &str) {
    if !is_enabled() {
        return;
    }

    let id = TRACE_COUNTER.fetch_add(1, Ordering::Relaxed);
    let ts = get_timestamp_us();

    log::info!(
        "[TRACE] {:>12} #{:06} @{:>10}us | {}",
        stage.as_str(),
        id,
        ts,
        message
    );
}

/// Log a trace event with formatted arguments
#[macro_export]
macro_rules! trace_pipeline {
    ($stage:expr, $($arg:tt)*) => {
        if $crate::debug::pipeline_tracer::is_enabled() {
            $crate::debug::pipeline_tracer::trace($stage, &format!($($arg)*));
        }
    };
}

/// Trace audio callback with buffer info
pub fn trace_audio_callback(samples: usize, rms: f64) {
    trace(
        PipelineStage::AudioCallback,
        &format!("samples={} rms={:.4}", samples, rms),
    );
}

/// Trace buffer queued to analysis
pub fn trace_buffer_queued(samples: usize, queue_len: usize) {
    trace(
        PipelineStage::BufferQueued,
        &format!("samples={} queue_len={}", samples, queue_len),
    );
}

/// Trace analysis thread receiving buffer
pub fn trace_analysis_receive(samples: usize, accumulated: usize) {
    trace(
        PipelineStage::AnalysisReceive,
        &format!("samples={} accumulated={}", samples, accumulated),
    );
}

/// Trace RMS computation
pub fn trace_rms(rms: f64, gate_threshold: f64) {
    trace(
        PipelineStage::RmsComputed,
        &format!("rms={:.4} threshold={:.4}", rms, gate_threshold),
    );
}

/// Trace gate decision
pub fn trace_gate(rms: f64, threshold: f64, passed: bool) {
    trace(
        PipelineStage::GateDecision,
        &format!(
            "rms={:.4} threshold={:.4} {}",
            rms,
            threshold,
            if passed { "PASSED" } else { "BLOCKED" }
        ),
    );
}

/// Trace onset detection
pub fn trace_onset(sample_position: u64, flux: f32) {
    trace(
        PipelineStage::OnsetDetected,
        &format!("pos={} flux={:.2}", sample_position, flux),
    );
}

/// Trace level crossing detection
pub fn trace_level_crossing(prev_rms: f64, curr_rms: f64, threshold: f64) {
    trace(
        PipelineStage::LevelCrossing,
        &format!(
            "prev={:.4} curr={:.4} threshold={:.4} TRIGGERED",
            prev_rms, curr_rms, threshold
        ),
    );
}

/// Trace feature extraction
pub fn trace_features(centroid: f32, zcr: f32, rms: f32) {
    trace(
        PipelineStage::FeaturesExtracted,
        &format!("centroid={:.1}Hz zcr={:.3} rms={:.4}", centroid, zcr, rms),
    );
}

/// Trace classification result
pub fn trace_classification(sound: &str, confidence: f32, timing_ms: f32) {
    trace(
        PipelineStage::Classification,
        &format!(
            "sound={} confidence={:.2} timing={:+.1}ms",
            sound, confidence, timing_ms
        ),
    );
}

/// Trace result sent to Dart
pub fn trace_result_sent(sound: &str, timestamp_ms: u64) {
    trace(
        PipelineStage::ResultSent,
        &format!("sound={} timestamp={}ms", sound, timestamp_ms),
    );
}

/// Trace calibration sample collection
pub fn trace_calibration_sample(sound: &str, sample_num: u32, total: u32) {
    trace(
        PipelineStage::CalibrationSample,
        &format!("sound={} sample={}/{}", sound, sample_num, total),
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_trace_disabled_by_default() {
        assert!(!is_enabled());
    }

    #[test]
    fn test_enable_disable() {
        enable();
        assert!(is_enabled());
        disable();
        assert!(!is_enabled());
    }

    #[test]
    fn test_stage_names() {
        assert_eq!(PipelineStage::AudioCallback.as_str(), "AUDIO_CB");
        assert_eq!(PipelineStage::Classification.as_str(), "CLASSIFY");
    }
}
