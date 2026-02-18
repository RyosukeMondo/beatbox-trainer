use std::convert::Infallible;
use std::net::SocketAddr;
use std::pin::Pin;
use std::time::Duration;

use anyhow::Context;
use axum::body::Body;
use axum::extract::{Query, State};
use axum::http::header::{HeaderName, AUTHORIZATION, CONTENT_TYPE};
use axum::http::{HeaderMap, HeaderValue, StatusCode};
use axum::response::sse::{Event, KeepAlive, Sse};
use axum::response::{IntoResponse, Json, Response};
use axum::routing::get;
use axum::Router;
use futures::{Stream, StreamExt};
use serde::{Deserialize, Serialize};
use tokio::sync::oneshot;
use tokio_stream::wrappers::BroadcastStream;

use crate::api::diagnostics;
use crate::calibration::CalibrationState;
use crate::engine::core::{EngineHandle, ParamPatch};
use crate::telemetry::{self, MetricEvent};

use super::metrics::render_prometheus_metrics;
use super::state::{spawn_watchdog_task, DebugHttpState, DebugWatchdog};

pub type TraceStream = SseStream;
pub type ClassificationStream = SseStream;
type SseStream = Sse<Pin<Box<dyn Stream<Item = Result<Event, Infallible>> + Send>>>;

pub fn build_router(state: DebugHttpState) -> Router {
    Router::new()
        .route("/health", get(healthz))
        .route("/healthz", get(healthz))
        .route("/metrics", get(metrics))
        .route("/trace", get(trace_stream_handler))
        .route("/classification-stream", get(classification_stream_handler))
        .route("/params", get(list_params).post(apply_params))
        .route("/control/start", axum::routing::post(control_start))
        .route("/control/stop", axum::routing::post(control_stop))
        .with_state(state)
}

pub async fn run_http_server(
    state: DebugHttpState,
    addr: SocketAddr,
    shutdown: oneshot::Receiver<()>,
) -> anyhow::Result<()> {
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .context("binding debug HTTP listener")?;
    let router = build_router(state.clone());
    let watchdog_task = spawn_watchdog_task(state.watchdog());
    axum::serve(listener, router)
        .with_graceful_shutdown(async move {
            let _ = shutdown.await;
        })
        .await
        .context("serving debug HTTP router")?;
    watchdog_task.abort();
    Ok(())
}

#[derive(Debug, Default, Deserialize)]
pub struct AuthQuery {
    pub token: Option<String>,
}

#[derive(Debug)]
pub enum HttpServerError {
    Unauthorized,
    BadRequest(&'static str),
    Backpressure,
    ServiceUnavailable(&'static str),
    Internal(String),
}

impl IntoResponse for HttpServerError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            Self::Unauthorized => (StatusCode::UNAUTHORIZED, "missing or invalid token".into()),
            Self::BadRequest(msg) => (StatusCode::BAD_REQUEST, msg.to_string()),
            Self::Backpressure => (
                StatusCode::TOO_MANY_REQUESTS,
                "command queue saturated".into(),
            ),
            Self::ServiceUnavailable(msg) => (StatusCode::SERVICE_UNAVAILABLE, msg.into()),
            Self::Internal(msg) => (StatusCode::INTERNAL_SERVER_ERROR, msg),
        };

        (status, Json(serde_json::json!({ "error": message }))).into_response()
    }
}

#[derive(Debug, Serialize)]
pub struct HealthResponse {
    pub status: &'static str,
    pub engine_running: bool,
    pub fixture_active: bool,
    pub uptime_ms: u64,
    pub watchdog_ms: u64,
    pub watchdog_healthy: bool,
    pub telemetry_events: u64,
    pub dropped_events: u64,
    pub last_error: Option<String>,
    pub last_jni_phase: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ParamDescriptor {
    pub supported: &'static [&'static str],
    pub calibration_state: Option<CalibrationState>,
}

#[derive(Debug, Serialize)]
pub struct ParamAck {
    pub accepted: bool,
}

pub async fn healthz(
    State(state): State<DebugHttpState>,
    Query(query): Query<AuthQuery>,
    headers: HeaderMap,
) -> Result<Json<HealthResponse>, HttpServerError> {
    authorize(&state, &headers, query.token.as_deref())?;

    let snapshot = telemetry::hub().snapshot();
    let watchdog = state.watchdog();
    let last_error = snapshot.recent.iter().rev().find_map(|event| match event {
        MetricEvent::Error { code, context } => Some(format!("{:?}:{}", code, context)),
        _ => None,
    });
    let last_jni_phase = snapshot.recent.iter().rev().find_map(|event| match event {
        MetricEvent::JniLifecycle { phase, .. } => Some(format!("{:?}", phase)),
        _ => None,
    });

    let status = if watchdog.is_healthy() && last_error.is_none() {
        "ok"
    } else {
        "degraded"
    };

    Ok(Json(HealthResponse {
        status,
        engine_running: state.handle.is_audio_running(),
        fixture_active: diagnostics::fixture_session_is_running(),
        uptime_ms: state.uptime_ms(),
        watchdog_ms: watchdog.elapsed_ms(),
        watchdog_healthy: watchdog.is_healthy(),
        telemetry_events: snapshot.total_events,
        dropped_events: snapshot.dropped_events,
        last_error,
        last_jni_phase,
    }))
}

pub async fn metrics(
    State(state): State<DebugHttpState>,
    Query(query): Query<AuthQuery>,
    headers: HeaderMap,
) -> Result<Response<Body>, HttpServerError> {
    authorize(&state, &headers, query.token.as_deref())?;
    let snapshot = telemetry::hub().snapshot();
    let body = render_prometheus_metrics(&state, &snapshot);
    Response::builder()
        .status(StatusCode::OK)
        .header(
            CONTENT_TYPE,
            HeaderValue::from_static("text/plain; version=0.0.4; charset=utf-8"),
        )
        .body(Body::from(body))
        .map_err(|err| HttpServerError::Internal(err.to_string()))
}

pub async fn trace_stream_handler(
    State(state): State<DebugHttpState>,
    Query(query): Query<AuthQuery>,
    headers: HeaderMap,
) -> Result<TraceStream, HttpServerError> {
    authorize(&state, &headers, query.token.as_deref())?;
    build_trace_stream(state.watchdog())
}

pub async fn classification_stream_handler(
    State(state): State<DebugHttpState>,
    Query(query): Query<AuthQuery>,
    headers: HeaderMap,
) -> Result<ClassificationStream, HttpServerError> {
    authorize(&state, &headers, query.token.as_deref())?;
    build_classification_stream(state.handle)
}

pub async fn list_params(
    State(state): State<DebugHttpState>,
    Query(query): Query<AuthQuery>,
    headers: HeaderMap,
) -> Result<Json<ParamDescriptor>, HttpServerError> {
    authorize(&state, &headers, query.token.as_deref())?;

    let calibration_state = state.handle.get_calibration_state().ok();

    Ok(Json(ParamDescriptor {
        supported: &["bpm", "centroid_threshold", "zcr_threshold"],
        calibration_state,
    }))
}

pub async fn apply_params(
    State(state): State<DebugHttpState>,
    Query(query): Query<AuthQuery>,
    headers: HeaderMap,
    Json(patch): Json<ParamPatch>,
) -> Result<Json<ParamAck>, HttpServerError> {
    authorize(&state, &headers, query.token.as_deref())?;

    if patch.bpm.is_none() && patch.centroid_threshold.is_none() && patch.zcr_threshold.is_none() {
        return Err(HttpServerError::BadRequest(
            "at least one parameter must be provided",
        ));
    }

    let sender = state.handle.command_sender();
    sender.try_send(patch.clone()).map_err(map_try_send_error)?;

    Ok(Json(ParamAck { accepted: true }))
}

fn authorize(
    state: &DebugHttpState,
    headers: &HeaderMap,
    query_token: Option<&str>,
) -> Result<(), HttpServerError> {
    let provided = extract_token(headers, query_token);
    match provided {
        Some(value) if value == state.token() => Ok(()),
        _ => Err(HttpServerError::Unauthorized),
    }
}

fn build_trace_stream(watchdog: DebugWatchdog) -> Result<TraceStream, HttpServerError> {
    let receiver = telemetry::hub().collector().subscribe();
    let stream = BroadcastStream::new(receiver).filter_map(move |result| {
        let watchdog = watchdog.clone();
        async move {
            match result {
                Ok(event) => match serde_json::to_string(&event) {
                    Ok(payload) => {
                        watchdog.beat();
                        Some(Ok(Event::default().event("trace").data(payload)))
                    }
                    Err(_) => None,
                },
                Err(_) => None,
            }
        }
    });

    Ok(Sse::new(Box::pin(stream) as Pin<Box<_>>).keep_alive(
        KeepAlive::new()
            .interval(Duration::from_secs(5))
            .text("debug-trace-keepalive"),
    ))
}

fn build_classification_stream(
    handle: &'static EngineHandle,
) -> Result<ClassificationStream, HttpServerError> {
    let receiver =
        handle
            .broadcasts
            .subscribe_classification()
            .ok_or(HttpServerError::ServiceUnavailable(
                "classification channel not initialized",
            ))?;

    let stream = BroadcastStream::new(receiver).filter_map(|result| async move {
        match result {
            Ok(result) => match serde_json::to_string(&result) {
                Ok(payload) => Some(Ok(Event::default().event("classification").data(payload))),
                Err(_) => None,
            },
            Err(_) => None,
        }
    });

    Ok(Sse::new(Box::pin(stream) as Pin<Box<_>>).keep_alive(
        KeepAlive::new()
            .interval(Duration::from_secs(5))
            .text("debug-classification-keepalive"),
    ))
}

fn map_try_send_error(err: tokio::sync::mpsc::error::TrySendError<ParamPatch>) -> HttpServerError {
    match err {
        tokio::sync::mpsc::error::TrySendError::Full(_) => HttpServerError::Backpressure,
        tokio::sync::mpsc::error::TrySendError::Closed(_) => {
            HttpServerError::ServiceUnavailable("param command channel closed")
        }
    }
}

pub fn extract_token(headers: &HeaderMap, query_token: Option<&str>) -> Option<String> {
    if let Some(token) = query_token {
        return Some(token.to_string());
    }

    static X_DEBUG_TOKEN: HeaderName = HeaderName::from_static("x-debug-token");

    headers
        .get(&X_DEBUG_TOKEN)
        .and_then(|value| value.to_str().ok())
        .map(|value| value.to_string())
        .or_else(|| {
            headers
                .get(AUTHORIZATION)
                .and_then(|value| value.to_str().ok())
                .and_then(|raw| raw.strip_prefix("Bearer ").map(|v| v.to_string()))
        })
}

#[derive(Debug, Deserialize)]
pub struct StartParams {
    #[serde(default = "default_bpm")]
    pub bpm: u32,
}

fn default_bpm() -> u32 {
    120
}

#[derive(Debug, Serialize)]
pub struct ControlResponse {
    pub success: bool,
    pub engine_running: bool,
    pub message: String,
}

/// POST /control/start - Start the audio engine
pub async fn control_start(
    State(state): State<DebugHttpState>,
    Query(query): Query<AuthQuery>,
    headers: HeaderMap,
    params: Option<Json<StartParams>>,
) -> Result<Json<ControlResponse>, HttpServerError> {
    authorize(&state, &headers, query.token.as_deref())?;

    let bpm = params.map(|p| p.bpm).unwrap_or(120);

    match state.handle.start_audio(bpm) {
        Ok(()) => Ok(Json(ControlResponse {
            success: true,
            engine_running: state.handle.is_audio_running(),
            message: format!("Audio engine started at {} BPM", bpm),
        })),
        Err(e) => Ok(Json(ControlResponse {
            success: false,
            engine_running: state.handle.is_audio_running(),
            message: format!("Failed to start: {:?}", e),
        })),
    }
}

/// POST /control/stop - Stop the audio engine
pub async fn control_stop(
    State(state): State<DebugHttpState>,
    Query(query): Query<AuthQuery>,
    headers: HeaderMap,
) -> Result<Json<ControlResponse>, HttpServerError> {
    authorize(&state, &headers, query.token.as_deref())?;

    match state.handle.stop_audio() {
        Ok(()) => Ok(Json(ControlResponse {
            success: true,
            engine_running: state.handle.is_audio_running(),
            message: "Audio engine stopped".to_string(),
        })),
        Err(e) => Ok(Json(ControlResponse {
            success: false,
            engine_running: state.handle.is_audio_running(),
            message: format!("Failed to stop: {:?}", e),
        })),
    }
}
