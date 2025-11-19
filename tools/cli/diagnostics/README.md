# Diagnostics Playbook Manifests

The keynote-grade testing spec standardizes diagnostics coverage around **declarative playbooks**.  Each
playbook scenario describes the ordered steps, environment overrides, retries, and artifact outputs that the
upcoming `DiagnosticsPlaybookParser` + runner will execute without requiring custom shell logic.

Current manifests live in [`tools/cli/diagnostics/playbooks/`](playbooks/) with the canonical keynote bundle
at [`playbooks/keynote.yaml`](playbooks/keynote.yaml).

## Running playbooks

The playbook parser + runner now power the same CLI wrapper. To execute a
scenario, pass `--scenario <id>` (defaults to `default-smoke`):

```bash
# Run the default smoke suite
./tools/cli/diagnostics/run.sh --scenario

# Keynote latency rehearsal
./tools/cli/diagnostics/run.sh --scenario keynote-latency

# Preview a scenario without executing commands
./tools/cli/diagnostics/run.sh --scenario calibration-stress --dry-run
```

Under the hood the Dart runner:
1. Loads `playbooks/keynote.yaml`.
2. Resolves `defaults` plus scenario/step overrides.
3. Executes each ordered step with retries, timeouts, and env merging.
4. Streams stdout/stderr to `logs/diagnostics/<scenario>/<timestamp>/`
   and prints a PASS/FAIL summary with resolved artifact paths.

## Schema overview

| Field | Description |
| --- | --- |
| `schemaVersion` | Versioned so the parser can reject unknown layouts (currently `1`). |
| `metadata` | Human context (`name`, `description`, `owner`, and timestamp). |
| `defaults` | Shared values such as `logRoot`, baseline environment variables, retry policy, timeout, and path templates. |
| `schema` | Defines the required/optional keys for scenarios and steps to keep manifests lintable. |
| `scenarios` | Map of scenario id → scenario definition (summary, tags, env, steps, artifacts, optional guards). |

### Steps

Each step entry inside `steps:` must provide:
- `id`: unique slug for ordering + log naming.
- `run`: executable relative to repo (typically `./tools/cli/diagnostics/run.sh`).
- Optional `args`, `env`, `timeoutSeconds`, and `retries` to override defaults.
- `artifacts`: zero or more records describing the files created by this step. The runner interpolates
  `{{logRoot}}`, `{{scenario}}`, `{{timestamp}}`, and `{{stepId}}` into the templates defined under `defaults.artifactTemplates`.

### Scenario-level artifacts

Scenarios may define top-level `artifacts` for outputs produced across multiple steps. These use the same
template helpers as step artifacts so runners can emit PASS/FAIL summaries with structured paths.

## Artifact + log layout

Every run writes under the configured `logRoot` (`logs/diagnostics`). The manifest templates expand to:

```
logs/diagnostics/<scenario>/<timestamp>/
  warmup.log              # defaults.artifactTemplates.stepLog
  metrics/
    default-smoke.json
    keynote-latency.json
  artifacts/
    default-smoke-recording.json
```

QA can attach `artifacts/*` to tickets, link `metrics/*.json` in reports, and forward
`warmup.log`/`latency-log` for engineering follow-up.  Additional structured files should reuse the same
directories to stay compatible with automation.

## Baseline diffs

Telemetry drift checks live under `logs/smoke/baselines/`.  Compare the latest run
against the committed snapshot with:

```bash
dart run tools/cli/diagnostics/lib/baseline_diff.dart \
  --scenario default-smoke \
  --run-playbook
```

Use `--metrics <file>` and `--regenerate` to stamp a new baseline after reviewing
the diff output. The CLI prints PASS/FAIL summaries plus the regeneration command
needed to update the JSON snapshot.

## Watch loops

`tools/cli/diagnostics/watch.sh` wraps the baseline diff CLI in watch mode. The
script monitors DSP-critical paths (Rust DSP, diagnostics tooling, Debug Lab
controllers, and scripts) via the Dart `Directory.watch` API and reruns the
scenario after a 5-second debounce. Example:

```bash
./tools/cli/diagnostics/watch.sh --scenario default-smoke
```

Add `--watch-path <dir>` entries to monitor additional folders (e.g.,
`lib/services/audio`). The playbook output streams inline, followed by the
baseline diff verdict so regressions are highlighted immediately.

## Sample scenarios

| Scenario | Purpose | Highlights |
| --- | --- | --- |
| `default-smoke` | Fast CI-friendly validation | Two quick `run` steps plus a reference recording for regression diffing. |
| `keynote-latency` | End-to-end keynote rehearsal | Hardware guardrails + JSON latency capture and waveform export. |
| `calibration-stress` | Long-running thermal/BPM soak | Baseline telemetry, multi-hour stress loop, and final summary capture. |

## Extending the manifest

1. Duplicate the structure used in `keynote.yaml` and choose a new scenario id.
2. Keep commands declarative—reference repo scripts/binaries only (e.g., `./tools/cli/diagnostics/run.sh`).
3. Define `steps` in the exact execution order and list every artifact path the QA team needs later.
4. Use scenario-level `env` to override `defaults.scenarioEnv` rather than mutating shell scripts.
5. Document each addition inside this README so others understand how to run and interpret the results.

Following this format keeps QA self-sufficient today and lets the upcoming parser/runner load the same manifests
without further code changes.
