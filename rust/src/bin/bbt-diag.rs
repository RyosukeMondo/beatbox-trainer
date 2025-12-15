#[cfg(feature = "diagnostics_fixtures")]
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::ExitCode;

#[cfg(feature = "diagnostics_fixtures")]
use std::time::{Duration, Instant};

#[cfg(feature = "diagnostics_fixtures")]
use anyhow::{anyhow, Context};
use anyhow::{bail, Result};
#[cfg(feature = "diagnostics_fixtures")]
use beatbox_trainer::telemetry;

use clap::{Args, Parser, Subcommand, ValueEnum};
#[cfg(feature = "diagnostics_fixtures")]
use tokio::sync::mpsc::error::TryRecvError;

#[cfg(feature = "diagnostics_fixtures")]
#[path = "bbt_diag/telemetry.rs"]
mod telemetry_utils;
#[cfg(feature = "diagnostics_fixtures")]
use telemetry_utils::{drain_metrics, RecordPayload, TelemetryAggregator};

#[cfg(feature = "diagnostics_fixtures")]
#[path = "bbt_diag/validation.rs"]
mod validation;
#[cfg(feature = "diagnostics_fixtures")]
use validation::{drain_classification_events, enforce_fixture_metadata};

fn main() -> ExitCode {
    let cli = Cli::parse();
    match cli.execute() {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("bbt-diag error: {err:?}");
            ExitCode::from(1)
        }
    }
}

#[derive(Parser, Debug)]
#[command(name = "bbt-diag", about = "Diagnostics + telemetry harness CLI")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

impl Cli {
    fn execute(self) -> Result<()> {
        match self.command {
            Command::Run(args) => run_command(args),
            Command::Serve(args) => serve_command(args),
            Command::Record(args) => record_command(args),
        }
    }
}

#[derive(Subcommand, Debug)]
enum Command {
    /// Run a fixture session and print telemetry summary.
    Run(RunArgs),
    /// Start the debug HTTP server (requires debug_http feature).
    Serve(ServeArgs),
    /// Capture classification events to a JSON file.
    Record(RecordArgs),
}

#[derive(Args, Debug, Clone)]
struct RunArgs {
    #[command(flatten)]
    fixture: FixtureArgs,
    /// How long to stream telemetry before stopping the fixture (milliseconds).
    #[arg(long, default_value_t = 2_000)]
    watch_ms: u64,
    /// Output format for telemetry summary.
    #[arg(long, value_enum, default_value_t = TelemetryFormat::Table)]
    telemetry_format: TelemetryFormat,
    /// Destination file for telemetry output (JSON only).
    #[arg(long)]
    telemetry_out: Option<PathBuf>,
}

#[derive(Args, Debug, Clone)]
struct RecordArgs {
    #[command(flatten)]
    fixture: FixtureArgs,
    /// Destination file for the captured classification events.
    #[arg(long)]
    output: PathBuf,
    /// Maximum number of events to capture before stopping.
    #[arg(long, default_value_t = 1024)]
    max_events: usize,
    /// How long to wait for fixture events (milliseconds).
    #[arg(long, default_value_t = 2_000)]
    watch_ms: u64,
}

#[derive(Args, Debug, Clone)]
struct ServeArgs {
    /// Host interface for the HTTP diagnostics server.
    #[arg(long, default_value = "127.0.0.1")]
    host: String,
    /// Port to expose HTTP metrics on.
    #[arg(long, default_value_t = 8_787)]
    metrics_port: u16,
    /// Token required by HTTP consumers.
    #[arg(long, default_value = "beatbox-debug")]
    token: String,
}

#[derive(Args, Debug, Clone)]
struct FixtureArgs {
    /// Path to a WAV file fixture to stream.
    #[arg(long)]
    fixture: Option<PathBuf>,
    /// Deterministic synthetic pattern to generate.
    #[arg(long, value_enum)]
    synthetic: Option<SyntheticPatternArg>,
    /// Use microphone passthrough stub instead of a fixture file.
    #[arg(long, default_value_t = false)]
    loopback: bool,
    /// Override fixture identifier used in reports.
    #[arg(long)]
    id: Option<String>,
    /// Override duration per loop (milliseconds).
    #[arg(long)]
    duration_ms: Option<u32>,
    /// Override sample rate for synthetic/loopback sources.
    #[arg(long, default_value_t = 48_000)]
    sample_rate: u32,
    /// Number of times to loop fixture data.
    #[arg(long, default_value_t = 1)]
    loop_count: u16,
    /// Attach metadata entries formatted as KEY=VALUE.
    #[arg(long = "metadata", value_name = "KEY=VALUE")]
    metadata: Vec<String>,
}

#[cfg(feature = "diagnostics_fixtures")]
impl FixtureArgs {
    fn resolved_id(&self) -> String {
        if let Some(id) = &self.id {
            return id.clone();
        }

        if let Some(path) = &self.fixture {
            if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                return stem.to_string();
            }
        }

        if let Some(pattern) = self.synthetic {
            return format!("synthetic-{pattern}");
        }

        if self.loopback {
            return "loopback".into();
        }

        "diagnostics-fixture".into()
    }

    fn validate(&self) -> Result<()> {
        let selected =
            self.fixture.is_some() as u8 + self.synthetic.is_some() as u8 + u8::from(self.loopback);
        if selected != 1 {
            bail!("Provide exactly one source via --fixture, --synthetic, or --loopback");
        }
        if let Some(path) = &self.fixture {
            if !path.exists() {
                bail!("fixture file {} does not exist", path.display());
            }
        }
        if self.sample_rate == 0 {
            bail!("Sample rate must be greater than zero");
        }
        if self.loop_count == 0 {
            bail!("Loop count must be at least 1");
        }
        Ok(())
    }

    fn metadata_map(&self) -> Result<HashMap<String, String>> {
        let mut map = HashMap::new();
        for entry in &self.metadata {
            let (key, value) = entry
                .split_once('=')
                .ok_or_else(|| anyhow!("metadata must use KEY=VALUE format: {entry}"))?;
            if key.is_empty() {
                bail!("metadata key cannot be empty");
            }
            map.insert(key.to_string(), value.to_string());
        }
        Ok(map)
    }
}

#[derive(Debug, Copy, Clone, ValueEnum)]
enum SyntheticPatternArg {
    Sine,
    Square,
    WhiteNoise,
    ImpulseTrain,
}

impl std::fmt::Display for SyntheticPatternArg {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

#[derive(Debug, Copy, Clone, Eq, PartialEq, ValueEnum)]
enum TelemetryFormat {
    Json,
    Table,
}

fn run_command(args: RunArgs) -> Result<()> {
    #[cfg(feature = "diagnostics_fixtures")]
    {
        return run_impl(args);
    }

    #[cfg(not(feature = "diagnostics_fixtures"))]
    {
        let _ = args;
        bail!("bbt-diag run requires the diagnostics_fixtures feature");
    }
}

fn record_command(args: RecordArgs) -> Result<()> {
    #[cfg(feature = "diagnostics_fixtures")]
    {
        return record_impl(args);
    }

    #[cfg(not(feature = "diagnostics_fixtures"))]
    {
        let _ = args;
        bail!("bbt-diag record requires the diagnostics_fixtures feature");
    }
}

fn serve_command(args: ServeArgs) -> Result<()> {
    #[cfg(all(feature = "debug_http", debug_assertions))]
    {
        return serve_impl(args);
    }

    #[cfg(not(all(feature = "debug_http", debug_assertions)))]
    {
        let _ = args;
        bail!("bbt-diag serve requires debug_http feature and debug build");
    }
}

#[cfg(feature = "diagnostics_fixtures")]
fn run_impl(args: RunArgs) -> Result<()> {
    use beatbox_trainer::analysis::ClassificationResult;
    use beatbox_trainer::testing::fixture_engine;
    use std::thread;

    args.fixture.validate()?;
    let spec = build_fixture_spec(&args.fixture)?;
    let fixture_id = spec.id.clone();
    let mut classification_rx = engine_handle().subscribe_classification();
    let mut observed_events: Vec<ClassificationResult> = Vec::new();
    let mut handle = fixture_engine::start_fixture_session_internal(engine_handle(), spec)
        .context("starting fixture session")?;
    let mut telemetry_rx = telemetry::hub().collector().subscribe();
    let mut aggregator = TelemetryAggregator::default();
    let deadline = Instant::now() + Duration::from_millis(args.watch_ms.max(100));

    while handle.is_running() && Instant::now() < deadline {
        drain_metrics(&mut telemetry_rx, &mut aggregator);
        drain_classification_events(&mut classification_rx, &mut observed_events);
        thread::sleep(Duration::from_millis(25));
    }
    drain_metrics(&mut telemetry_rx, &mut aggregator);
    drain_classification_events(&mut classification_rx, &mut observed_events);
    handle.stop().context("stopping fixture session")?;

    let snapshot = telemetry::hub().snapshot();
    let report = aggregator.into_report(snapshot.total_events, snapshot.dropped_events);

    if let Some(path) = args.telemetry_out {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).context("creating telemetry output directory")?;
        }
        let json = serde_json::to_string_pretty(&report).context("serializing telemetry report")?;
        std::fs::write(&path, json)
            .with_context(|| format!("writing telemetry to {}", path.display()))?;
    } else {
        match args.telemetry_format {
            TelemetryFormat::Json => report.print_json()?,
            TelemetryFormat::Table => report.print_table(),
        }
    }

    enforce_fixture_metadata(&fixture_id, &observed_events, "bbt-diag run")?;

    Ok(())
}

#[cfg(feature = "diagnostics_fixtures")]
fn record_impl(args: RecordArgs) -> Result<()> {
    use beatbox_trainer::testing::fixture_engine;
    use std::thread;

    args.fixture.validate()?;
    let spec = build_fixture_spec(&args.fixture)?;
    let fixture_id = spec.id.clone();
    let sample_rate = spec.sample_rate;

    let mut classification_rx = engine_handle().subscribe_classification();
    let mut handle = fixture_engine::start_fixture_session_internal(engine_handle(), spec)
        .context("starting fixture session")?;

    let mut captured = Vec::new();
    let deadline = Instant::now() + Duration::from_millis(args.watch_ms.max(100));

    while Instant::now() < deadline && captured.len() < args.max_events && handle.is_running() {
        match classification_rx.try_recv() {
            Ok(event) => captured.push(event),
            Err(TryRecvError::Empty) => thread::sleep(Duration::from_millis(15)),
            Err(TryRecvError::Disconnected) => break,
        }
    }

    handle.stop().context("stopping fixture session")?;
    drain_classification_events(&mut classification_rx, &mut captured);

    let payload = RecordPayload {
        fixture_id,
        sample_rate,
        event_count: captured.len(),
        events: captured,
    };
    let json =
        serde_json::to_string_pretty(&payload).context("serializing classification payload")?;

    if let Some(parent) = args.output.parent() {
        std::fs::create_dir_all(parent).context("creating record output directory")?;
    }

    std::fs::write(&args.output, json)
        .with_context(|| format!("writing classification log to {}", args.output.display()))?;
    enforce_fixture_metadata(&payload.fixture_id, &payload.events, "bbt-diag record")?;
    println!(
        "Captured {} events to {}",
        payload.event_count,
        args.output.display()
    );
    Ok(())
}

#[cfg(all(feature = "debug_http", debug_assertions))]
fn serve_impl(args: ServeArgs) -> Result<()> {
    use beatbox_trainer::debug::http;

    let addr = format!("{}:{}", args.host, args.metrics_port);
    std::env::set_var("BEATBOX_DEBUG_HTTP_ADDR", addr);
    std::env::set_var("BEATBOX_DEBUG_TOKEN", &args.token);
    http::spawn_if_enabled(engine_handle());
    println!(
        "Debug HTTP server running on {} (token prefix {}***)",
        std::env::var("BEATBOX_DEBUG_HTTP_ADDR").unwrap(),
        &args.token.chars().take(4).collect::<String>()
    );
    println!("Press Ctrl+C to stop.");
    loop {
        std::thread::sleep(std::time::Duration::from_secs(60));
    }
}

#[cfg(feature = "diagnostics_fixtures")]
fn build_fixture_spec(
    args: &FixtureArgs,
) -> Result<beatbox_trainer::testing::fixtures::FixtureSpec> {
    use beatbox_trainer::testing::fixtures::FixtureSpec;

    let metadata = args.metadata_map()?;
    let spec = FixtureSpec {
        id: args.resolved_id(),
        source: determine_source(args)?,
        sample_rate: args.sample_rate,
        channels: 1,
        duration_ms: args.duration_ms.unwrap_or(1_000),
        loop_count: args.loop_count,
        metadata,
    };
    spec.validate()?;
    Ok(spec)
}

#[cfg(feature = "diagnostics_fixtures")]
fn determine_source(
    args: &FixtureArgs,
) -> Result<beatbox_trainer::testing::fixtures::FixtureSource> {
    use beatbox_trainer::testing::fixtures::{FixtureSource, SyntheticSpec};

    if let Some(path) = &args.fixture {
        return Ok(FixtureSource::WavFile { path: path.clone() });
    }

    if let Some(pattern) = args.synthetic {
        let spec = SyntheticSpec {
            pattern: synthetic_pattern(pattern),
            frequency_hz: 220.0,
            amplitude: 0.8,
        };
        return Ok(FixtureSource::Synthetic(spec));
    }

    if args.loopback {
        return Ok(FixtureSource::MicrophonePassthrough);
    }

    bail!("No fixture source provided")
}

#[cfg(feature = "diagnostics_fixtures")]
fn synthetic_pattern(
    pattern: SyntheticPatternArg,
) -> beatbox_trainer::testing::fixtures::SyntheticPattern {
    use beatbox_trainer::testing::fixtures::SyntheticPattern;
    match pattern {
        SyntheticPatternArg::Sine => SyntheticPattern::Sine,
        SyntheticPatternArg::Square => SyntheticPattern::Square,
        SyntheticPatternArg::WhiteNoise => SyntheticPattern::WhiteNoise,
        SyntheticPatternArg::ImpulseTrain => SyntheticPattern::ImpulseTrain,
    }
}

#[cfg(any(
    feature = "diagnostics_fixtures",
    all(feature = "debug_http", debug_assertions)
))]
fn engine_handle() -> &'static beatbox_trainer::engine::EngineHandle {
    use beatbox_trainer::engine::EngineHandle;
    use once_cell::sync::Lazy;

    static ENGINE: Lazy<&'static EngineHandle> =
        Lazy::new(|| Box::leak(Box::new(EngineHandle::new())));
    *ENGINE
}
