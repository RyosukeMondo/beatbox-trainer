use std::convert::Infallible;
use std::pin::Pin;
use std::time::Duration;

use axum::response::sse::{Event, KeepAlive, Sse};
use futures::{Stream, StreamExt};
use tokio_stream::wrappers::BroadcastStream;

use crate::engine::core::EngineHandle;

use super::routes::HttpServerError;

pub type ClassificationStream = Sse<Pin<Box<dyn Stream<Item = Result<Event, Infallible>> + Send>>>;

/// Build a Server-Sent Events stream for live classification results.
pub fn classification(
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
            .text("debug-keepalive"),
    ))
}
