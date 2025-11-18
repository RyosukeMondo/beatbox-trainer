use std::collections::BTreeMap;
use std::fmt::Write;

use crate::analysis::classifier::BeatboxHit;
use crate::api::diagnostics;
use crate::telemetry::{DiagnosticError, LifecyclePhase, MetricEvent, TelemetrySnapshot};

use super::state::DebugHttpState;

pub fn render_prometheus_metrics(state: &DebugHttpState, snapshot: &TelemetrySnapshot) -> String {
    PrometheusWriter::new(state, snapshot).render()
}

struct PrometheusWriter<'a> {
    state: &'a DebugHttpState,
    snapshot: &'a TelemetrySnapshot,
    output: String,
    classification_counts: BTreeMap<&'static str, u64>,
    buffer_levels: BTreeMap<String, f32>,
    lifecycle_phases: BTreeMap<&'static str, u64>,
    latest_latency: Option<(f32, f32, usize)>,
    last_error_code: Option<&'static str>,
}

impl<'a> PrometheusWriter<'a> {
    fn new(state: &'a DebugHttpState, snapshot: &'a TelemetrySnapshot) -> Self {
        let mut classification_counts = BTreeMap::new();
        let mut buffer_levels = BTreeMap::new();
        let mut lifecycle_phases = BTreeMap::new();
        let mut latest_latency = None;
        let mut last_error_code = None;

        for event in &snapshot.recent {
            match event {
                MetricEvent::Classification { sound, .. } => {
                    *classification_counts
                        .entry(sound_label(*sound))
                        .or_insert(0) += 1;
                }
                MetricEvent::BufferOccupancy { channel, percent } => {
                    buffer_levels.insert(channel.clone(), *percent);
                }
                MetricEvent::Latency {
                    avg_ms,
                    max_ms,
                    sample_count,
                } => latest_latency = Some((*avg_ms, *max_ms, *sample_count)),
                MetricEvent::JniLifecycle {
                    phase,
                    timestamp_ms,
                } => {
                    lifecycle_phases.insert(lifecycle_label(*phase), *timestamp_ms);
                }
                MetricEvent::Error { code, .. } => last_error_code = Some(error_label(*code)),
            }
        }

        Self {
            state,
            snapshot,
            output: String::new(),
            classification_counts,
            buffer_levels,
            lifecycle_phases,
            latest_latency,
            last_error_code,
        }
    }

    fn render(mut self) -> String {
        self.write_event_counters();
        self.write_engine_flags();
        self.write_latency_section();
        self.write_classifications();
        self.write_buffer_levels();
        self.write_lifecycle();
        self.write_error_flag();
        self.output
    }

    fn write_event_counters(&mut self) {
        writeln!(
            &mut self.output,
            "# HELP beatbox_events_total Total telemetry events emitted"
        )
        .unwrap();
        writeln!(&mut self.output, "# TYPE beatbox_events_total counter").unwrap();
        writeln!(
            &mut self.output,
            "beatbox_events_total {}",
            self.snapshot.total_events
        )
        .unwrap();

        writeln!(
            &mut self.output,
            "# HELP beatbox_events_dropped_total Telemetry events dropped"
        )
        .unwrap();
        writeln!(
            &mut self.output,
            "# TYPE beatbox_events_dropped_total counter"
        )
        .unwrap();
        writeln!(
            &mut self.output,
            "beatbox_events_dropped_total {}",
            self.snapshot.dropped_events
        )
        .unwrap();
    }

    fn write_engine_flags(&mut self) {
        self.write_engine_status();
        self.write_fixture_flag();
        self.write_watchdog_metrics();
        self.write_uptime();
    }

    fn write_engine_status(&mut self) {
        writeln!(
            &mut self.output,
            "# HELP beatbox_engine_running Audio engine running flag"
        )
        .unwrap();
        writeln!(&mut self.output, "# TYPE beatbox_engine_running gauge").unwrap();
        writeln!(
            &mut self.output,
            "beatbox_engine_running {}",
            bool_to_int(self.state.handle.is_audio_running())
        )
        .unwrap();
    }

    fn write_fixture_flag(&mut self) {
        writeln!(
            &mut self.output,
            "# HELP beatbox_fixture_active Fixture session active flag"
        )
        .unwrap();
        writeln!(&mut self.output, "# TYPE beatbox_fixture_active gauge").unwrap();
        writeln!(
            &mut self.output,
            "beatbox_fixture_active {}",
            bool_to_int(diagnostics::fixture_session_is_running())
        )
        .unwrap();
    }

    fn write_watchdog_metrics(&mut self) {
        let watchdog = self.state.watchdog();
        writeln!(
            &mut self.output,
            "# HELP beatbox_watchdog_seconds Watchdog idle duration"
        )
        .unwrap();
        writeln!(&mut self.output, "# TYPE beatbox_watchdog_seconds gauge").unwrap();
        writeln!(
            &mut self.output,
            "beatbox_watchdog_seconds {:.3}",
            watchdog.elapsed_ms() as f64 / 1000.0
        )
        .unwrap();

        writeln!(
            &mut self.output,
            "# HELP beatbox_watchdog_state Watchdog health (1 healthy)"
        )
        .unwrap();
        writeln!(&mut self.output, "# TYPE beatbox_watchdog_state gauge").unwrap();
        writeln!(
            &mut self.output,
            "beatbox_watchdog_state {}",
            bool_to_int(watchdog.is_healthy())
        )
        .unwrap();
    }

    fn write_uptime(&mut self) {
        writeln!(
            &mut self.output,
            "# HELP beatbox_uptime_ms HTTP server uptime"
        )
        .unwrap();
        writeln!(&mut self.output, "# TYPE beatbox_uptime_ms counter").unwrap();
        writeln!(
            &mut self.output,
            "beatbox_uptime_ms {}",
            self.state.uptime_ms()
        )
        .unwrap();
    }

    fn write_latency_section(&mut self) {
        if let Some((avg, max, samples)) = self.latest_latency {
            writeln!(
                &mut self.output,
                "# HELP beatbox_latency_avg_ms Average latency"
            )
            .unwrap();
            writeln!(&mut self.output, "# TYPE beatbox_latency_avg_ms gauge").unwrap();
            writeln!(&mut self.output, "beatbox_latency_avg_ms {:.4}", avg).unwrap();

            writeln!(
                &mut self.output,
                "# HELP beatbox_latency_max_ms Max latency"
            )
            .unwrap();
            writeln!(&mut self.output, "# TYPE beatbox_latency_max_ms gauge").unwrap();
            writeln!(&mut self.output, "beatbox_latency_max_ms {:.4}", max).unwrap();

            writeln!(
                &mut self.output,
                "# HELP beatbox_latency_samples Latency sample count"
            )
            .unwrap();
            writeln!(&mut self.output, "# TYPE beatbox_latency_samples gauge").unwrap();
            writeln!(&mut self.output, "beatbox_latency_samples {}", samples).unwrap();
        }
    }

    fn write_classifications(&mut self) {
        for (sound, count) in &self.classification_counts {
            writeln!(
                &mut self.output,
                "beatbox_classifications_total{{sound=\"{}\"}} {}",
                sound, count
            )
            .unwrap();
        }
    }

    fn write_buffer_levels(&mut self) {
        for (channel, percent) in &self.buffer_levels {
            writeln!(
                &mut self.output,
                "beatbox_buffer_percent{{channel=\"{}\"}} {:.3}",
                channel, percent
            )
            .unwrap();
        }
    }

    fn write_lifecycle(&mut self) {
        for (phase, timestamp) in &self.lifecycle_phases {
            writeln!(
                &mut self.output,
                "beatbox_jni_phase_timestamp_ms{{phase=\"{}\"}} {}",
                phase, timestamp
            )
            .unwrap();
        }
    }

    fn write_error_flag(&mut self) {
        match self.last_error_code {
            Some(code) => {
                writeln!(
                    &mut self.output,
                    "beatbox_last_error{{code=\"{}\"}} 1",
                    code
                )
                .unwrap();
            }
            None => {
                writeln!(&mut self.output, "beatbox_last_error{{code=\"none\"}} 0").unwrap();
            }
        }
    }
}

fn sound_label(hit: BeatboxHit) -> &'static str {
    match hit {
        BeatboxHit::Kick => "kick",
        BeatboxHit::Snare => "snare",
        BeatboxHit::HiHat => "hihat",
        BeatboxHit::ClosedHiHat => "closed_hihat",
        BeatboxHit::OpenHiHat => "open_hihat",
        BeatboxHit::KSnare => "k_snare",
        BeatboxHit::Unknown => "unknown",
    }
}

fn lifecycle_label(phase: LifecyclePhase) -> &'static str {
    match phase {
        LifecyclePhase::LibraryLoaded => "library_loaded",
        LifecyclePhase::ContextInitialized => "context_initialized",
        LifecyclePhase::PermissionsGranted => "permissions_granted",
        LifecyclePhase::PermissionsDenied => "permissions_denied",
        LifecyclePhase::LibraryUnloaded => "library_unloaded",
    }
}

fn error_label(code: DiagnosticError) -> &'static str {
    match code {
        DiagnosticError::FixtureLoad => "fixture_load",
        DiagnosticError::BufferDrain => "buffer_drain",
        DiagnosticError::StreamBackpressure => "stream_backpressure",
        DiagnosticError::Unknown => "unknown",
    }
}

fn bool_to_int(value: bool) -> u8 {
    if value {
        1
    } else {
        0
    }
}
