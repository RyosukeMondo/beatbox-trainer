# Design Document

## Overview

Keynote-grade testing formalizes three complementary systems:

1. **Diagnostics Playbooks** – declarative scenarios that orchestrate
   `bbt-diag`, `beatbox_cli`, HTTP smoke tests, and Debug Lab exports. Playbooks
   live as YAML/JSON manifests and are executed by new runners under
   `tools/cli/diagnostics/`.
2. **Fixture Discovery Catalog** – machine-readable metadata for each WAV or
   synthetic fixture so CLIs, Debug Lab, and telemetry diffing know the expected
   BPM ranges, class counts, and anomaly tags.
3. **Evidence-grade Watch/Diff Loop** – reusable watchers (shell + Dart) that
   rerun playbooks whenever critical files change and diff telemetry against
   baselines stored under `logs/smoke/baselines/`.

Together they turn diagnostics utilities into fast, repeatable bug-hunting
workflows aimed at keynote rehearsals.

## Steering Document Alignment

### Technical Standards (tech.md)
- Reuses the native-first tooling stack (`bbt-diag`, `beatbox_cli`, FRB APIs).
- Keeps lock-free DSP untouched; new code lives in runners, manifests, logging,
  and Debug Lab UI overlays.
- Automation scripts rely on standard tooling (`cargo`, `flutter`, shell),
  observing no-network, no-secrets policies.

### Project Structure (structure.md)
- CLI tooling remains under `tools/cli/diagnostics/` with additional modules
  for playbook parsing and artifact bundling.
- Fixture metadata resides under `rust/fixtures/` alongside WAV assets.
- Debug Lab changes stay confined to `lib/ui/screens/debug_lab_screen.dart` plus
  reusable widgets/services under `lib/services/debug/`.
- Logs continue under `logs/diagnostics/` and `logs/smoke/`.

## Code Reuse Analysis

### Existing Components to Leverage
- **`tools/cli/diagnostics/run.sh`**: Extend to read scenario manifests and
  spawn multiple commands with shared env overrides.
- **`scripts/pre-commit`**: Hook into existing CLI/HTTP smoke runners to add
  watch-mode triggers and baseline diff steps.
- **`DebugLabController` + telemetry widgets**: Add anomaly highlighting and log
  export bundling without rewriting UI.
- **`rust/src/testing/fixture_engine.rs`**: Continue powering fixture playback;
  new metadata files feed into the same APIs.

### Integration Points
- **Rust + Dart services**: Use FRB calls (`startFixtureSession`,
  `stopFixtureSession`, param patches) as execution primitives for Debug Lab.
- **Logging pipeline**: All runners write to `logs/diagnostics/` and
  `logs/smoke/` directories with timestamped folders referenced in CLI output.

## Architecture

```
playbooks/*.yaml --(Parser)--> DiagnosticsScenario
       |                             |
       v                             v
tools/cli/diagnostics/playbook_runner.dart  <--->  ArtifactBundler
       |                                  ^
       v                                  |
 CLI commands (bbt-diag, beatbox_cli, cargo test) --- logs/smoke/*

rust/fixtures/catalog.json --(Rust + Dart loaders)--> FixtureMetadataRegistry
                                            |
DebugLab (Flutter) <---- anomaly stream ----+
```

### Modular Design Principles
- **Single File Responsibility**: Separate parser, runner, artifact bundler, and
  diff logic.
- **Component Isolation**: UI receives summarized anomaly models instead of raw
  diagnostics logs.
- **Service Layer Separation**: CLI orchestrators remain pure shell/Dart;
  fixture metadata loading is pure Rust/Dart code accessible via FRB.
- **Utility Modularity**: Baseline comparator implemented as shared Rust helper
  for telemetry JSON plus a Dart counterpart for Debug Lab exports.

## Components and Interfaces

### DiagnosticsPlaybookParser
- **Purpose:** Load YAML/JSON playbooks describing ordered steps, env vars,
  timeout policies, and artifact destinations.
- **Interfaces:** `DiagnosticsPlaybook parse(File input)`
- **Dependencies:** Dart `yaml` package (invoked via `dart run` inside tools).
- **Reuses:** Existing run.sh to execute parsed commands.

### PlaybookRunner (shell/Dart hybrid)
- **Purpose:** Execute parsed steps, enforce timeouts, collect logs, and emit
  PASS/FAIL summaries with relative paths.
- **Interfaces:** `run_playbook(playbook, {dryRun, profile})`
- **Dependencies:** `bbt-diag`, `beatbox_cli`, `cargo`, `curl`.
- **Reuses:** `tools/cli/diagnostics/run.sh` logging infrastructure.

### FixtureMetadataRegistry (Rust + Dart)
- **Purpose:** Provide typed access to fixture manifest data (expected BPM,
  class counts, anomaly tags) for CLI and Debug Lab.
- **Interfaces:** `FixtureMetadata load_catalog()`, `FixtureExpectation validate(StreamStats stats)`
- **Dependencies:** `serde_json` (Rust), generated FRB bindings.
- **Reuses:** `rust/src/testing/fixtures.rs`.

### BaselineDiffEngine
- **Purpose:** Compare latest telemetry JSON against baselines, highlight
  deltas, and store diff artifacts.
- **Interfaces:** `DiffResult compare(currentPath, baselinePath, tolerances)`
- **Dependencies:** `jq`/`dart:convert`.
- **Reuses:** Existing log locations in `logs/smoke/`.

### DebugLabAnomalyOverlay
- **Purpose:** Visual highlight card when metrics deviate from fixture metadata.
- **Interfaces:** `void showAnomaly(FixtureAnomaly anomaly)`
- **Dependencies:** `DebugLabController` and ValueNotifiers.
- **Reuses:** `TelemetryChart`, `DebugLogList`.

## Data Models

### DiagnosticsPlaybook (YAML/JSON)
```
id: string
description: string
steps:
  - name: "classify basic_hits"
    command: ["cargo", "run", "--bin", "beatbox_cli", "--", "classify", ...]
    env:
      CARGO_FEATURES: "diagnostics_fixtures"
    artifacts:
      - logs/smoke/classify_basic_hits.json
    retry: 2
```

### FixtureManifestEntry
```
id: string
source: { kind: "wav_file"|"synthetic"|"loopback", path?: string }
expectedBpm: { min: int, max: int }
expectedCounts:
  kick: int
  snare: int
  hihat: int
anomalyTags: ["late-kick", "noisy-hat"]
tolerances:
  latencyMs: { max: float }
  classificationDropPct: { max: float }
```

### TelemetryBaseline
```
scenarioId: string
timestamp: string
metrics:
  latencyMsP95: float
  classificationCounts: { kick: int, snare: int, hihat: int }
  paramPatchesApplied: int
```

## Error Handling

### Scenario 1: Playbook command failure
- **Handling:** Runner retries up to configured count, tags step as FAILED with
  exit code, and keeps subsequent steps from executing. Artifacts zipped even on
  failure for inspection.
- **User Impact:** CLI prints red ✗ with path to log bundle.

### Scenario 2: Fixture metadata mismatch
- **Handling:** Validation emits structured anomaly with expected vs actual
  values; Debug Lab overlay shows warning, CLI writes entry to
  `logs/smoke/baseline_diffs/`.
- **User Impact:** QA immediately sees which metric drifted and instructions to
  regenerate baseline.

## Testing Strategy

### Unit Testing
- Rust unit tests for `FixtureMetadataRegistry` (parsing, validation).
- Dart unit tests for `DiagnosticsPlaybookParser`, `BaselineDiffEngine`.

### Integration Testing
- CLI integration tests under `scripts/pre-commit` watch mode to assert playbook
  orchestration and artifact bundling.
- Debug Lab widget tests verifying anomaly overlay states.

### End-to-End Testing
- Full smoke scenario triggered in CI: run keynote playbook, diff telemetry
  against baselines, export Debug Lab artifact, ensure zipped evidence exists.
