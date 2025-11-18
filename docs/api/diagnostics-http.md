# Diagnostics HTTP API

The diagnostics HTTP server exposes observability and control hooks for the
fixture-driven audio pipelines. It only starts when the crate is built with the
`debug_http` feature and runs in debug/profile builds. The implementation lives
in `rust/src/debug/http.rs` and `rust/src/debug/routes.rs`.

- **Bind address:** `BEATBOX_DEBUG_HTTP_ADDR` (defaults to `127.0.0.1:8787`).
- **Token:** All endpoints require the token from `BEATBOX_DEBUG_TOKEN`
  (default `beatbox-debug`). Provide the token via the `token` query parameter,
  the `Authorization: Bearer` header, or `X-Debug-Token`.
- **Graceful shutdown:** The server mirrors the fixture engine's handle pattern.
  A `DebugWatchdog` monitors telemetry beats to detect stalls; shutting the
  runtime down triggers a clean `tokio::sync::oneshot` path so CLI smoke tests
  can tear it down deterministically.

## Endpoints

### `GET /healthz`

Returns JSON describing the current engine state, fixture handle activity, and
watchdog timers. `/health` aliases the same handler.

Fields:

| Field | Type | Description |
| --- | --- | --- |
| `status` | string | `ok` when the watchdog is healthy and no errors were observed; `degraded` otherwise. |
| `engine_running` | bool | Whether the audio engine thread graph is live. |
| `fixture_active` | bool | Mirrors the Rust `FixtureHandle::is_running()` status for deterministic teardown. |
| `uptime_ms` | number | Milliseconds since the HTTP server started. |
| `watchdog_ms` | number | Milliseconds since the last telemetry heartbeat. |
| `watchdog_healthy` | bool | Convenience flag mirroring the watchdog status. |
| `telemetry_events` | number | Total events emitted by the telemetry collector. |
| `dropped_events` | number | Events dropped because the bounded history filled up. |
| `last_error` | string? | Latest `DiagnosticError` + context if any were reported. |
| `last_jni_phase` | string? | Most recent JNI lifecycle phase emitted via telemetry. |

Example:

```json
{
  "status": "ok",
  "engine_running": false,
  "fixture_active": false,
  "uptime_ms": 9123,
  "watchdog_ms": 84,
  "watchdog_healthy": true,
  "telemetry_events": 64,
  "dropped_events": 0,
  "last_error": null,
  "last_jni_phase": "permissions_granted"
}
```

### `GET /metrics`

Produces Prometheus text containing latency gauges, classification counters,
buffer occupancy percentages, watchdog timers, and lifecycle timestamps. The
endpoint always responds with `Content-Type: text/plain; version=0.0.4` so it
can be scraped directly by Prometheus-compatible collectors.

Example snippet:

```
# HELP beatbox_events_total Total telemetry events emitted
# TYPE beatbox_events_total counter
beatbox_events_total 64
# HELP beatbox_watchdog_seconds Watchdog idle duration
# TYPE beatbox_watchdog_seconds gauge
beatbox_watchdog_seconds 0.084
beatbox_classifications_total{sound="kick"} 5
beatbox_buffer_percent{channel="analysis_queue"} 32.500
```

### `GET /trace`

Streams `MetricEvent` payloads over SSE so dashboards can react immediately to
latency spikes or JNI regressions. Each message includes the serialized telemetry
event and uses the `trace` event name.

```
curl -N -H "X-Debug-Token: beatbox-debug" http://127.0.0.1:8787/trace
```

### `GET /classification-stream`

Legacy SSE endpoint that continues to emit `ClassificationResult` payloads for
Debug Lab and widget tests. The new `/trace` endpoint should be preferred for
telemetry-oriented tooling, but both can run simultaneously.

### `/params`

- `GET /params` – Lists supported parameters (`bpm`, `centroid_threshold`,
  `zcr_threshold`) and includes the cached calibration state when available.
- `POST /params` – Applies a `ParamPatch` JSON payload. Partial patches are
  allowed; the server enforces that at least one field is present and surfaces
  backpressure/errors via HTTP statuses.

## Watchdog & Error Signaling

- The `DebugWatchdog` records the timestamp of every telemetry event. If no
  events arrive for five seconds the watchdog flips to `degraded`, which
  surfaces in `/healthz` and `/metrics`.
- Publishing a `MetricEvent::Error` or dropping telemetry history does not
  crash the server—those scenarios are exposed through the `/healthz`
  `last_error` field and the Prometheus `beatbox_last_error` metric so CI can
  fail quickly.
- Because the fixture engine exposes its own `FixtureHandle`, `/healthz`
  reports `fixture_active` even when no audio threads are running. This keeps CI
  from tearing the server down while a deterministic fixture run is still in
  flight.
