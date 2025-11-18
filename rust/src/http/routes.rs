use std::net::SocketAddr;
use std::sync::Arc;

use anyhow::Context;
use axum::extract::{Query, State};
use axum::http::header::{HeaderName, AUTHORIZATION};
use axum::http::{HeaderMap, StatusCode};
use axum::response::{IntoResponse, Json, Response};
use axum::routing::get;
use axum::Router;
use serde::{Deserialize, Serialize};
use tokio::sync::broadcast;
use tokio::sync::broadcast::error::TryRecvError;
use tokio::sync::mpsc::error::TrySendError;

use crate::api::AudioMetrics;
use crate::calibration::CalibrationState;
use crate::engine::core::{EngineHandle, ParamPatch, TelemetryEvent};
use crate::telemetry::{self, TelemetrySnapshot};

use super::sse;

/// Shared application state for HTTP handlers.
#[derive(Clone)]
pub struct DebugHttpState {
    pub handle: &'static EngineHandle,
    token: Arc<String>,
}

impl DebugHttpState {
    pub fn new(handle: &'static EngineHandle, token: String) -> Self {
        Self {
            handle,
            token: Arc::new(token),
        }
    }

    fn authorize(
        &self,
        headers: &HeaderMap,
        query_token: Option<&str>,
    ) -> Result<(), HttpServerError> {
        let provided = extract_token(headers, query_token);
        match provided {
            Some(value) if value == *self.token => Ok(()),
            _ => Err(HttpServerError::Unauthorized),
        }
    }
}

/// Query payload for extracting token from URL.
#[derive(Debug, Default, Deserialize)]
pub struct AuthQuery {
    pub token: Option<String>,
}

/// HTTP error variants mapped to JSON responses.
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

/// Health endpoint response payload.
#[derive(Debug, Serialize)]
pub struct HealthResponse {
    pub status: &'static str,
    pub engine_running: bool,
    pub uptime_ms: u64,
    pub calibrated: bool,
}

/// Metrics endpoint response payload.
#[derive(Debug, Serialize)]
pub struct MetricsResponse {
    pub latest_audio_metrics: Option<AudioMetrics>,
    pub latest_telemetry: Option<TelemetryEvent>,
    pub diagnostics: TelemetrySnapshot,
}

/// Parameter description payload.
#[derive(Debug, Serialize)]
pub struct ParamDescriptor {
    pub supported: &'static [&'static str],
    pub calibration_state: Option<CalibrationState>,
}

/// Command acknowledgement payload.
#[derive(Debug, Serialize)]
pub struct ParamAck {
    pub accepted: bool,
}

/// Build the Axum router with all handlers.
pub fn build_router(state: DebugHttpState) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/metrics", get(metrics))
        .route("/classification-stream", get(classification_stream_handler))
        .route("/params", get(list_params).post(apply_params))
        .with_state(state)
}

/// Run the HTTP server loop.
pub async fn run_http_server(state: DebugHttpState, addr: SocketAddr) -> anyhow::Result<()> {
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .context("binding debug HTTP listener")?;
    let router = build_router(state);
    axum::serve(listener, router)
        .await
        .context("serving debug HTTP router")?;
    Ok(())
}

pub async fn health(
    State(state): State<DebugHttpState>,
    Query(query): Query<AuthQuery>,
    headers: HeaderMap,
) -> Result<Json<HealthResponse>, HttpServerError> {
    state.authorize(&headers, query.token.as_deref())?;

    let calibrated = state
        .handle
        .get_calibration_state()
        .map(|cal| cal.is_calibrated)
        .unwrap_or(false);

    Ok(Json(HealthResponse {
        status: "ok",
        engine_running: state.handle.is_audio_running(),
        uptime_ms: state.handle.uptime_ms(),
        calibrated,
    }))
}

pub async fn metrics(
    State(state): State<DebugHttpState>,
    Query(query): Query<AuthQuery>,
    headers: HeaderMap,
) -> Result<Json<MetricsResponse>, HttpServerError> {
    state.authorize(&headers, query.token.as_deref())?;

    let latest_audio_metrics = state
        .handle
        .broadcasts
        .subscribe_audio_metrics()
        .and_then(|mut rx| drain_broadcast(&mut rx));

    let latest_telemetry = {
        let mut telemetry_rx = state.handle.telemetry_receiver();
        drain_broadcast(&mut telemetry_rx)
    };
    let diagnostics = telemetry::hub().snapshot();

    Ok(Json(MetricsResponse {
        latest_audio_metrics,
        latest_telemetry,
        diagnostics,
    }))
}

pub async fn classification_stream_handler(
    State(state): State<DebugHttpState>,
    Query(query): Query<AuthQuery>,
    headers: HeaderMap,
) -> Result<sse::ClassificationStream, HttpServerError> {
    state.authorize(&headers, query.token.as_deref())?;
    sse::classification(state.handle)
}

pub async fn list_params(
    State(state): State<DebugHttpState>,
    Query(query): Query<AuthQuery>,
    headers: HeaderMap,
) -> Result<Json<ParamDescriptor>, HttpServerError> {
    state.authorize(&headers, query.token.as_deref())?;

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
    state.authorize(&headers, query.token.as_deref())?;

    if patch.bpm.is_none() && patch.centroid_threshold.is_none() && patch.zcr_threshold.is_none() {
        return Err(HttpServerError::BadRequest(
            "at least one parameter must be provided",
        ));
    }

    let sender = state.handle.command_sender();
    sender
        .try_send(patch.clone())
        .map_err(|err| map_try_send_error(err))?;

    Ok(Json(ParamAck { accepted: true }))
}

fn map_try_send_error(err: TrySendError<ParamPatch>) -> HttpServerError {
    match err {
        TrySendError::Full(_) => HttpServerError::Backpressure,
        TrySendError::Closed(_) => {
            HttpServerError::ServiceUnavailable("param command channel closed")
        }
    }
}

fn extract_token(headers: &HeaderMap, query_token: Option<&str>) -> Option<String> {
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

fn drain_broadcast<T: Clone>(rx: &mut broadcast::Receiver<T>) -> Option<T> {
    let mut latest = None;
    loop {
        match rx.try_recv() {
            Ok(value) => latest = Some(value),
            Err(TryRecvError::Lagged(_)) => continue,
            Err(TryRecvError::Empty) => break,
            Err(TryRecvError::Closed) => return None,
        }
    }
    latest
}

#[cfg(all(test, feature = "debug_http"))]
mod tests {
    use super::*;
    use axum::body::{to_bytes, Body};
    use axum::http::{Request, StatusCode};
    use axum::response::Response;
    use futures::StreamExt;
    use once_cell::sync::Lazy;
    use serde_json::Value;
    use tower::ServiceExt;

    static TEST_HANDLE: Lazy<EngineHandle> = Lazy::new(EngineHandle::new);
    const TOKEN: &str = "smoke-token";

    fn make_router() -> Router {
        let state = DebugHttpState::new(&TEST_HANDLE, TOKEN.to_string());
        build_router(state)
    }

    async fn response_json(response: Response) -> (StatusCode, Value) {
        let status = response.status();
        let bytes = to_bytes(response.into_body(), usize::MAX)
            .await
            .expect("response body bytes");
        let json = serde_json::from_slice::<Value>(&bytes).expect("JSON body");
        (status, json)
    }

    #[tokio::test]
    async fn health_requires_token() {
        let (status, json) = response_json(
            make_router()
                .oneshot(
                    Request::builder()
                        .uri("/health")
                        .body(Body::empty())
                        .expect("health request"),
                )
                .await
                .expect("health call"),
        )
        .await;

        println!("[HTTP Smoke] /health (no token) => {json}");
        assert_eq!(status, StatusCode::UNAUTHORIZED);
        assert_eq!(json["error"], "missing or invalid token");
    }

    #[tokio::test]
    async fn health_succeeds_with_token() {
        let (status, json) = response_json(
            make_router()
                .oneshot(
                    Request::builder()
                        .uri(format!("/health?token={TOKEN}"))
                        .body(Body::empty())
                        .expect("health request"),
                )
                .await
                .expect("health call"),
        )
        .await;

        println!("[HTTP Smoke] /health => {json}");
        assert_eq!(status, StatusCode::OK);
        assert_eq!(json["status"], "ok");
    }

    #[tokio::test]
    async fn metrics_succeeds_with_token() {
        let (status, json) = response_json(
            make_router()
                .oneshot(
                    Request::builder()
                        .uri(format!("/metrics?token={TOKEN}"))
                        .body(Body::empty())
                        .expect("metrics request"),
                )
                .await
                .expect("metrics call"),
        )
        .await;

        println!("[HTTP Smoke] /metrics => {json}");
        assert_eq!(status, StatusCode::OK);
        assert!(json["latest_audio_metrics"].is_null() || json["latest_audio_metrics"].is_object());
        assert!(json["diagnostics"].is_object());
    }

    #[tokio::test]
    async fn params_support_listing() {
        let (status, json) = response_json(
            make_router()
                .oneshot(
                    Request::builder()
                        .uri(format!("/params?token={TOKEN}"))
                        .body(Body::empty())
                        .expect("params request"),
                )
                .await
                .expect("params call"),
        )
        .await;

        println!("[HTTP Smoke] /params => {json}");
        assert_eq!(status, StatusCode::OK);
        assert!(json["supported"].is_array());
    }
}
