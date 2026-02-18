use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use tokio::task::JoinHandle;

use crate::telemetry::{self, MetricEvent};

pub const DEFAULT_WATCHDOG_TIMEOUT_MS: u64 = 5_000;

#[derive(Clone)]
pub struct DebugHttpState {
    pub handle: &'static crate::engine::core::EngineHandle,
    token: Arc<String>,
    started_at: Instant,
    watchdog: DebugWatchdog,
}

impl DebugHttpState {
    pub fn new(handle: &'static crate::engine::core::EngineHandle, token: String) -> Self {
        Self::with_watchdog(
            handle,
            token,
            DebugWatchdog::new(Duration::from_millis(DEFAULT_WATCHDOG_TIMEOUT_MS)),
        )
    }

    pub fn with_watchdog(
        handle: &'static crate::engine::core::EngineHandle,
        token: String,
        watchdog: DebugWatchdog,
    ) -> Self {
        Self {
            handle,
            token: Arc::new(token),
            started_at: Instant::now(),
            watchdog,
        }
    }

    pub fn uptime_ms(&self) -> u64 {
        self.started_at.elapsed().as_millis() as u64
    }

    pub fn watchdog(&self) -> DebugWatchdog {
        self.watchdog.clone()
    }

    pub fn token(&self) -> &str {
        &self.token
    }
}

#[derive(Clone)]
pub struct DebugWatchdog {
    last_beat_ms: Arc<AtomicU64>,
    timeout_ms: u64,
}

impl DebugWatchdog {
    pub fn new(timeout: Duration) -> Self {
        Self {
            last_beat_ms: Arc::new(AtomicU64::new(now_timestamp_ms())),
            timeout_ms: timeout.as_millis() as u64,
        }
    }

    pub fn beat(&self) {
        self.last_beat_ms
            .store(now_timestamp_ms(), Ordering::Relaxed);
    }

    pub fn elapsed_ms(&self) -> u64 {
        now_timestamp_ms().saturating_sub(self.last_beat_ms.load(Ordering::Relaxed))
    }

    pub fn status(&self) -> WatchdogStatus {
        if self.elapsed_ms() > self.timeout_ms {
            WatchdogStatus::Degraded
        } else {
            WatchdogStatus::Healthy
        }
    }

    pub fn is_healthy(&self) -> bool {
        matches!(self.status(), WatchdogStatus::Healthy)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WatchdogStatus {
    Healthy,
    Degraded,
}

pub fn spawn_watchdog_task(watchdog: DebugWatchdog) -> JoinHandle<()> {
    tokio::spawn(async move {
        let mut receiver = telemetry::hub().collector().subscribe();
        while let Ok(event) = receiver.recv().await {
            // Beat the watchdog on every event regardless of type
            let _ = event; // acknowledge event
            watchdog.beat();
        }
    })
}

pub fn now_timestamp_ms() -> u64 {
    use std::time::{SystemTime, UNIX_EPOCH};

    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}
