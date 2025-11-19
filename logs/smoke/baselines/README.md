# Diagnostics Baseline Snapshots

Keynote-grade testing stores telemetry baselines under this directory so drift
is caught automatically by:

* `dart run tools/cli/diagnostics/lib/baseline_diff.dart`
* `tools/cli/diagnostics/watch.sh` (wraps the Dart CLI in watch mode)
* `scripts/pre-commit` (runs the diff whenever DSP-critical files change)

Each scenario gets its own JSON snapshot:

```json
{
  "schemaVersion": 1,
  "scenario": "default-smoke",
  "logRoot": "logs/diagnostics",
  "metricsArtifact": "metrics/default-smoke.json",
  "capturedAt": "2025-11-19T16:55:00Z",
  "sourceArtifact": "logs/diagnostics/default-smoke/2025-11-19T16-54-58Z/metrics/default-smoke.json",
  "metrics": [
    {
      "id": "latency-avg",
      "label": "Latency avg (ms)",
      "path": "latency.avg_ms",
      "expected": 21.8,
      "tolerance": { "absolute": 2.0 }
    }
  ]
}
```

* `metricsArtifact` – file (relative to the scenario log folder) the diff engine
  searches after running the playbook.
* `metrics[].path` – dot-notation selector into the telemetry JSON. Only numeric
  fields are supported today.
* `tolerance.absolute` – fixed window where the diff still passes.
* `tolerance.percent` – optional percentage window (relative to the expected
  value) that also has to pass.
* `warnOnly` – mark metrics that should log warnings without failing the diff.

## Updating baselines

1. Run the scenario once (either manually or through `watch.sh`):
   ```bash
   ./tools/cli/diagnostics/run.sh --scenario default-smoke
   ```
2. Locate the most recent telemetry artifact (listed in the playbook artifacts
   section).
3. Regenerate the snapshot:
   ```bash
   dart run tools/cli/diagnostics/lib/baseline_diff.dart \
     --scenario default-smoke \
     --metrics logs/diagnostics/default-smoke/<timestamp>/metrics/default-smoke.json \
     --regenerate
   ```

The CLI stamps `capturedAt` and `sourceArtifact` automatically so the audit
trail remains intact. Commit the updated JSON alongside any code changes that
affect DSP or telemetry behavior.
