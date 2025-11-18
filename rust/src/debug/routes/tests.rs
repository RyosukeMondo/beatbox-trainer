use super::handlers::*;
use super::state::DebugHttpState;
use crate::engine::core::EngineHandle;
use crate::telemetry;
use axum::body::to_bytes;
use axum::http::header::CONTENT_TYPE;
use axum::http::{Request, StatusCode};
use axum::response::Response;
use axum::Router;
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
                    .uri("/healthz")
                    .body(axum::body::Body::empty())
                    .expect("health request"),
            )
            .await
            .expect("health call"),
    )
    .await;

    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(json["error"], "missing or invalid token");
}

#[tokio::test]
async fn health_succeeds_with_token() {
    let (status, json) = response_json(
        make_router()
            .oneshot(
                Request::builder()
                    .uri(format!("/healthz?token={TOKEN}"))
                    .body(axum::body::Body::empty())
                    .expect("health request"),
            )
            .await
            .expect("health call"),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(json["status"], "ok");
}

#[tokio::test]
async fn metrics_return_prometheus_payload() {
    let router = make_router();
    telemetry::hub().record_buffer_occupancy("test", 42.0);
    let response = router
        .oneshot(
            Request::builder()
                .uri(format!("/metrics?token={TOKEN}"))
                .body(axum::body::Body::empty())
                .expect("metrics request"),
        )
        .await
        .expect("metrics call");

    assert_eq!(response.status(), StatusCode::OK);
    let content_type = response
        .headers()
        .get(CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .unwrap_or_default();
    assert!(content_type.contains("text/plain"));
    let bytes = to_bytes(response.into_body(), usize::MAX)
        .await
        .expect("metrics bytes");
    let body = String::from_utf8(bytes.to_vec()).expect("metrics body");
    assert!(body.contains("beatbox_events_total"));
}

#[tokio::test]
async fn trace_requires_token() {
    let response = make_router()
        .oneshot(
            Request::builder()
                .uri("/trace")
                .body(axum::body::Body::empty())
                .expect("trace request"),
        )
        .await
        .expect("trace call");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn trace_succeeds_with_token() {
    let response = make_router()
        .oneshot(
            Request::builder()
                .uri(format!("/trace?token={TOKEN}"))
                .body(axum::body::Body::empty())
                .expect("trace request"),
        )
        .await
        .expect("trace call");
    assert_eq!(response.status(), StatusCode::OK);
    let header = response
        .headers()
        .get(CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .unwrap_or_default();
    assert!(header.contains("text/event-stream"));
}

#[tokio::test]
async fn params_support_listing() {
    let (status, json) = response_json(
        make_router()
            .oneshot(
                Request::builder()
                    .uri(format!("/params?token={TOKEN}"))
                    .body(axum::body::Body::empty())
                    .expect("params request"),
            )
            .await
            .expect("params call"),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert!(json["supported"].is_array());
}
