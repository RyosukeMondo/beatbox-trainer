use std::fs;
use std::path::PathBuf;
use std::process::ExitCode;

use anyhow::{Context, Result};
use beatbox_trainer::analysis::ClassificationResult;
use beatbox_trainer::engine::EngineHandle;
use beatbox_trainer::fixtures::{ExpectationDiff, FixtureCatalog, FixtureProcessor};
use clap::{Parser, Subcommand};
use serde::Serialize;

#[derive(Parser, Debug)]
#[command(
    name = "beatbox_cli",
    about = "Deterministic DSP fixture harness for Beatbox Trainer"
)]
struct Cli {
    /// Override directory containing fixture assets (defaults to rust/fixtures)
    #[arg(long)]
    fixtures_dir: Option<PathBuf>,
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Run a fixture classification and optionally compare against expectations
    Classify {
        #[arg(long)]
        fixture: String,
        #[arg(long)]
        expect: Option<PathBuf>,
        #[arg(long)]
        output: Option<PathBuf>,
        #[arg(long, default_value_t = 120)]
        bpm: u32,
    },
    /// Stream classification events for a fixture to stdout
    Stream {
        #[arg(long)]
        fixture: String,
        #[arg(long, default_value_t = 120)]
        bpm: u32,
    },
    /// List available fixtures on disk
    DumpFixtures,
}

fn main() -> ExitCode {
    match run() {
        Ok(code) => code,
        Err(err) => {
            eprintln!("Error: {err:?}");
            ExitCode::from(1)
        }
    }
}

fn run() -> Result<ExitCode> {
    let cli = Cli::parse();
    let catalog = cli
        .fixtures_dir
        .map(FixtureCatalog::new)
        .unwrap_or_else(FixtureCatalog::default);

    match cli.command {
        Commands::Classify {
            fixture,
            expect,
            output,
            bpm,
        } => run_classify(&catalog, &fixture, expect, output, bpm),
        Commands::Stream { fixture, bpm } => run_stream(&catalog, &fixture, bpm),
        Commands::DumpFixtures => run_dump(&catalog),
    }
}

fn run_classify(
    catalog: &FixtureCatalog,
    fixture: &str,
    override_expect: Option<PathBuf>,
    output_path: Option<PathBuf>,
    bpm: u32,
) -> Result<ExitCode> {
    let engine = EngineHandle::new();
    let config = engine.config_snapshot();
    let calibration = engine.calibration_state_handle();
    let processor = FixtureProcessor::new(config, calibration).with_bpm(bpm);
    let data = catalog.load(fixture, override_expect)?;
    let actual = processor
        .run(&data)
        .with_context(|| format!("processing fixture {}", fixture))?;

    emit_report(&data.metadata.name, data.sample_rate, &actual, output_path)?;

    if let Some(expectations) = data.expectations {
        match expectations.verify(&actual) {
            Ok(()) => Ok(ExitCode::from(0)),
            Err(diff) => {
                emit_diff(&diff)?;
                Ok(ExitCode::from(2))
            }
        }
    } else {
        Ok(ExitCode::from(0))
    }
}

fn run_stream(catalog: &FixtureCatalog, fixture: &str, bpm: u32) -> Result<ExitCode> {
    let engine = EngineHandle::new();
    let config = engine.config_snapshot();
    let calibration = engine.calibration_state_handle();
    let processor = FixtureProcessor::new(config, calibration).with_bpm(bpm);
    let data = catalog.load(fixture, None)?;
    let actual = processor
        .run(&data)
        .with_context(|| format!("processing fixture {}", fixture))?;

    for event in actual {
        println!("{}", serde_json::to_string(&event)?);
    }

    Ok(ExitCode::from(0))
}

fn run_dump(catalog: &FixtureCatalog) -> Result<ExitCode> {
    let fixtures = catalog.discover()?;
    if fixtures.is_empty() {
        println!("No fixtures found under {}", catalog.root().display());
        return Ok(ExitCode::from(0));
    }

    for metadata in fixtures {
        if let Some(expect) = metadata.expect_path {
            println!("{} -> {}", metadata.name, expect.display());
        } else {
            println!("{}", metadata.name);
        }
    }
    Ok(ExitCode::from(0))
}

fn emit_report(
    fixture: &str,
    sample_rate: u32,
    events: &[ClassificationResult],
    output_path: Option<PathBuf>,
) -> Result<()> {
    let report = FixtureReportPayload {
        fixture,
        sample_rate,
        event_count: events.len(),
        events,
    };
    let json = serde_json::to_string_pretty(&report)?;

    if let Some(path) = output_path {
        fs::write(&path, json).with_context(|| format!("writing {}", path.display()))?;
    } else {
        println!("{json}");
    }

    Ok(())
}

fn emit_diff(diff: &ExpectationDiff) -> Result<()> {
    let json = serde_json::to_string_pretty(&diff.to_json())?;
    eprintln!("{json}");
    Ok(())
}

#[derive(Serialize)]
struct FixtureReportPayload<'a> {
    fixture: &'a str,
    sample_rate: u32,
    event_count: usize,
    #[serde(skip_serializing_if = "slice_empty")]
    events: &'a [ClassificationResult],
}

fn slice_empty(events: &&[ClassificationResult]) -> bool {
    events.is_empty()
}
