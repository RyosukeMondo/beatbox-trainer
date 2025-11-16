//! Debug HTTP server surfaced only in debug feature builds.
//!
//! This module spawns a lightweight Axum server that exposes health, metrics,
//! SSE classification streams, and parameter patch endpoints for diagnostics.

#[cfg(all(feature = "debug_http", debug_assertions))]
mod routes;
#[cfg(all(feature = "debug_http", debug_assertions))]
mod sse;

use crate::engine::core::EngineHandle;

#[cfg(all(feature = "debug_http", debug_assertions))]
use routes::{run_http_server, DebugHttpState};

#[cfg(all(feature = "debug_http", debug_assertions))]
use log::{error, info, warn};
#[cfg(all(feature = "debug_http", debug_assertions))]
use std::net::SocketAddr;
#[cfg(all(feature = "debug_http", debug_assertions))]
use std::sync::atomic::{AtomicBool, Ordering};
#[cfg(all(feature = "debug_http", debug_assertions))]
use std::thread;

#[cfg(all(feature = "debug_http", debug_assertions))]
static SERVER_STARTED: AtomicBool = AtomicBool::new(false);

/// Spawn the debug HTTP server only when the feature flag and debug builds are enabled.
pub fn spawn_if_enabled(handle: &'static EngineHandle) {
    #[cfg(all(feature = "debug_http", debug_assertions))]
    {
        if SERVER_STARTED
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .is_err()
        {
            warn!("Debug HTTP server already running");
            return;
        }

        let addr: SocketAddr = std::env::var("BEATBOX_DEBUG_HTTP_ADDR")
            .unwrap_or_else(|_| "127.0.0.1:8787".to_string())
            .parse()
            .unwrap_or_else(|_| SocketAddr::from(([127, 0, 0, 1], 8787)));

        let token =
            std::env::var("BEATBOX_DEBUG_TOKEN").unwrap_or_else(|_| "beatbox-debug".to_string());
        let preview = token.chars().take(4).collect::<String>();

        thread::spawn(move || {
            let runtime = tokio::runtime::Builder::new_multi_thread()
                .worker_threads(2)
                .enable_all()
                .build()
                .expect("Failed to build tokio runtime for debug HTTP server");

            info!(
                "Debug HTTP server binding {} (token prefix {}***)",
                addr, preview
            );

            runtime.block_on(async move {
                let state = DebugHttpState::new(handle, token);
                if let Err(err) = run_http_server(state, addr).await {
                    error!("Debug HTTP server stopped: {}", err);
                }
            });
        });
    }
}

#[cfg(not(all(feature = "debug_http", debug_assertions)))]
#[allow(unused_variables)]
pub fn spawn_if_enabled(_handle: &'static EngineHandle) {
    // Debug HTTP server disabled in this build.
}
