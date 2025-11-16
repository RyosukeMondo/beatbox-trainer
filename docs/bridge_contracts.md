# Bridge Contracts

This document captures the canonical contract between the Rust engine,
flutter_rust_bridge (FRB) bindings, the HTTP debug API, and the Flutter UI.
All interfaces consume the same payloads so QA, support, and tooling can swap
between them without rewriting parsers.

## API Surface Summary

| Channel | Type | Purpose | Notes |
| --- | --- | --- | --- |
| `start_audio(bpm)` / `stop_audio()` / `set_bpm()` | RPC | Engine lifecycle control | Errors map to `AudioErrorCodes` (see below) |
| `classification_stream` | Stream | Emits `ClassificationResult` on every onset | Mirrors `/classification-stream` SSE |
| `calibration_stream` | Stream | Pushes `CalibrationProgress` updates | Used by onboarding & CLI transcript |
| `telemetry_stream` | Stream | Emits `TelemetryEvent` entries (engine + BPM) | Also fed into Debug Lab charts |
| `apply_params(ParamPatch)` | RPC | Runtime parameter updates (BPM, centroid, ZCR) | Same payload accepted by HTTP `/params` |

## Shared Payloads

### ClassificationResult

```json
{
  "sound": "KICK",
  "timing": {
    "status": "ON_TIME",
    "delta_ms": 12
  },
  "timestamp_ms": 8345,
  "confidence": 0.93
}
```

- `sound`: Uppercase `BeatboxHit` label (Kick/Snare/Hi-Hat/...)
- `timing.status`: `ON_TIME`, `EARLY`, or `LATE`
- `timing.delta_ms`: Signed millisecond delta relative to the metronome grid
- `confidence`: 0.0–1.0 float (same normalization used by CLI + Debug Lab)

### CalibrationProgress

```json
{
  "phase": "snare",
  "collected": 7,
  "required": 10,
  "thresholds": {
    "t_kick_centroid": 1420.0,
    "t_kick_zcr": 0.08,
    "t_snare_centroid": 3840.0,
    "t_hihat_zcr": 0.31
  }
}
```

`phase` switches between `kick`, `snare`, `hihat`, and `complete`. When the
phase becomes `complete`, FRB forwards the snapshot to
`CalibrationState.fromJson` and the Debug Lab toggles its "Calibrated" badge.

### TelemetryEvent

```json
{
  "timestamp_ms": 9100,
  "type": "bpmChanged",
  "bpm": 112,
  "detail": "ParamPatch(bpm=112)"
}
```

- `type`: `engineStarted`, `engineStopped`, `bpmChanged`, or `warning`
- `detail`: Optional human-readable message surfaced in Debug Lab log feed

### ParamPatch

```json
{
  "bpm": 110,
  "centroid_threshold": 3600.0,
  "zcr_threshold": 0.28
}
```

Every field is optional; at least one must be provided. Both `apply_params`
and HTTP `/params` reuse this shape. If the bounded lock-free queue is full,
the engine returns `AudioError.StreamFailure` with reason
`"parameter command queue is full"`.

## Error Codes

| Code | Description | Typical Resolution |
| --- | --- | --- |
| `audio_already_running` | Duplicate `start_audio` | Call `stop_audio()` or use Debug Lab toggle before restarting |
| `audio_stream_failure` | Device I/O failure or closed channel | Confirm microphone permission, restart `beatbox_cli`/app |
| `calibration_insufficient_samples` | Less than required samples per phase | Re-run calibration or feed CLI fixture with `--repeat` |
| `token_rejected` | HTTP token mismatch | Export `BEATBOX_DEBUG_TOKEN` or update Debug Lab token field |

All FRB errors convert into `AudioStreamFailure`/`CalibrationTimeout` models in
Dart; see `lib/services/audio/audio_service_impl.dart` for mapping logic.

## Channel Parity

1. **CLI ➜ HTTP:** `beatbox_cli stream --fixture kick_fast` emits the same
   `ClassificationResult` payloads that `/classification-stream` pushes over
   SSE. Capture CLI JSON as ground truth when debugging SSE clients.
2. **HTTP ➜ Flutter:** Debug Lab's telemetry panels subscribe to the FRB
   streams and optionally to the HTTP SSE if "Remote Session" is toggled.
   Payloads are identical, so you can diff them with `jq --compact-output` to
   ensure no serialization drift.
3. **Flutter ➜ Engine:** Parameter sliders translate directly into
   `ParamPatch` structs; the confirmation toast prints the HTTP echo body
   when the debug server is enabled.

## Operational Checklist

- Run `./scripts/pre-commit` to refresh CLI + HTTP smoke artifacts under
  `logs/smoke/`. Upload those logs with UAT reports.
- When updating FRB structs, regenerate bindings via
  `flutter_rust_bridge_codegen --rust-output rust/src/bridge_generated.rs --dart-output lib/bridge/`.
- Keep this file in sync with `rust/src/api.rs` and the Dart models:
  `lib/models/classification_result.dart`, `lib/models/calibration_state.dart`,
  `lib/models/telemetry_event.dart`.

Following these guidelines ensures QA/support engineers can switch between the
CLI, HTTP tooling, and Flutter screens without contract surprises.
