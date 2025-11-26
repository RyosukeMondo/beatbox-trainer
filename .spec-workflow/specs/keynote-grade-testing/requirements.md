# Requirements Document

## Introduction

Keynote-grade testing focuses on surfacing high-impact audio bugs under demo
conditions rather than simply raising coverage numbers. This effort will
formalize how fixture engines, diagnostics CLIs, HTTP telemetry, and Debug Lab
visuals combine to expose timing drift, misclassification, and calibration
regressions in minutes. The spec defines the test experiences, data capture,
and guardrails needed so QA can iterate at keynote speed while keeping evidence
shareable with engineering and product stakeholders.

## Alignment with Product Vision

Beatbox Trainer differentiates itself through uncompromising real-time
performance and transparent, user-calibrated DSP. Keynote-grade testing
reinforces that vision by turning every diagnostics surface (fixture engine,
bbt-diag, beatbox_cli, Debug Lab) into actionable bug-hunting workflows that
prove the DSP still meets the low-latency, accuracy, and interpretability bars
described in the steering docs. Instead of manual spot checks, QA gains
repeatable, data-backed demonstrations that the metronome remains jitter-free,
classification thresholds stay personalized, and calibration flows never
regress ahead of investor or demo milestones.

## Requirements

### Requirement 1 — Diagnostics-first smoke playbooks

**User Story:** As a diagnostics engineer, I want curated CLI + HTTP smoke
playbooks so that I can reproduce keynote-critical scenarios and detect timing
or classification regressions within five minutes.

#### Acceptance Criteria

1. WHEN QA runs `tools/cli/diagnostics/run.sh` with the default smoke preset
   THEN the workflow SHALL stream synthetic (impulse + sine) fixtures, capture
   telemetry in both table and JSON formats, and summarize anomalies with
   explicit PASS/FAIL markers.
2. IF QA selects a named playbook (e.g., `--scenario keynote-latency`) THEN the
   CLI SHALL stitch together beatbox_cli classify/stream runs plus bbt-diag
   record/serve calls, persisting logs under `logs/diagnostics/<scenario>/`.
3. WHEN a smoke playbook finishes AND any CLI exit code is non-zero THEN the
   harness SHALL bundle stdout/stderr, HTTP metrics snapshots, and FRB stream
   samples into a single artifact directory referenced in console output.

### Requirement 2 — Fixture-driven bug discovery catalog

**User Story:** As a QA lead, I want a maintained fixture catalog with metadata
covering stress, calibration, and edge-case beats so that regression tests
surface musically relevant bugs instead of synthetic-only coverage.

#### Acceptance Criteria

1. WHEN a new fixture is added THEN its spec SHALL declare source type (WAV,
   synthetic generator, loopback), expected BPM window, classification labels,
   and anomaly tags (e.g., “late kicks”, “noisy hats”) in a machine-readable
   manifest under `rust/fixtures/catalog.json`.
2. IF diagnostics_fixtures are enabled AND QA requests `bbt-diag run
   --fixture <id>` THEN the engine SHALL load metadata, enforce BPM constraints,
   and fail fast with actionable messaging when expectations are violated.
3. WHEN fixtures run through Debug Lab synthetic toggles AND telemetry deviates
   from manifest expectations beyond configured tolerances THEN the UI SHALL
   highlight the card in warning state and write a structured entry to
   `logs/smoke/debug_lab_anomalies.log`.

### Requirement 3 — Evidence-grade watch + diff loops

**User Story:** As a release coordinator, I want watchable test loops that
continuously diff diagnostics output against last-known-good baselines so that
we catch keynote regressions before demo rehearsals.

#### Acceptance Criteria

1. WHEN developers run `scripts/pre-commit --watch` or equivalent THEN the hook
   SHALL re-trigger CLI + HTTP smokes whenever files under `rust/src/analysis`,
   `lib/services/audio/`, or `lib/ui/screens/debug_lab_screen.dart` change and
   surface deltas inline (✓/✗) without waiting for manual commits.
2. IF a diff loop detects deviations in JSON telemetry (classification counts,
   latency percentiles, param patches) beyond defined thresholds THEN the tool
   SHALL emit a human-readable diff plus the command required to regenerate the
   baseline, storing both in `logs/smoke/baseline_diffs/`.
3. WHEN QA exports Debug Lab sessions for keynote rehearsals THEN the export
   SHALL package FRB stream samples, HTTP `/metrics` snapshots, fixture IDs,
   and any applied ParamPatch commands into a single zipped artifact ready for
   handoff to stakeholders.

## Non-Functional Requirements

### Code Architecture and Modularity
- Automation scripts SHALL isolate scenario definitions (YAML/JSON) from runner
  logic so QA can add new playbooks without editing shell code.
- Test harnesses SHALL expose typed interfaces (e.g., Dart services or Rust
  structs) for anomaly reporting to keep UI, CLI, and HTTP consumers in sync.

### Performance
- Diagnostics smoke runs SHALL complete within five minutes on a mid-range
  laptop, including both CLI and HTTP flows.
- Watch-mode reruns SHALL debounce changes to avoid reprocessing more than once
  per five seconds while edits are in flight.

### Security
- Debug artifacts SHALL continue to redact tokens (BEATBOX_DEBUG_TOKEN) and
  avoid logging microphone transcripts outside fixture assets.

### Reliability
- Playbooks SHALL retry transient cargo/flutter invocations up to two times and
  clearly separate infrastructure failures from DSP regressions.
- Baseline diffing SHALL store previous artifacts so results remain reproducible
  even if subsequent runs fail midstream.

### Usability
- CLI outputs SHALL link to log directories using relative paths and ANSI
  highlighting so engineers can jump to evidence quickly.
- Debug Lab alerts SHALL include actionable text (e.g., “Expected hi-hat hits:
  16, observed: 13”) instead of generic warnings to aid demo prep.
