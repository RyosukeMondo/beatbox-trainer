use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::time::{Duration, Instant};

use crate::error::AudioError;

use super::{AudioBackend, EngineStartContext, TimeSource};

/// Desktop stub backend used for deterministic testing and CLI tooling.
///
/// For now it simply simulates engine lifecycle without real audio I/O.
pub struct DesktopStubBackend {
    running: AtomicBool,
}

impl DesktopStubBackend {
    pub fn new() -> Self {
        Self {
            running: AtomicBool::new(false),
        }
    }
}

impl Default for DesktopStubBackend {
    fn default() -> Self {
        Self::new()
    }
}

impl AudioBackend for DesktopStubBackend {
    fn start(&self, ctx: EngineStartContext) -> Result<(), AudioError> {
        if ctx.bpm == 0 {
            return Err(AudioError::BpmInvalid { bpm: ctx.bpm });
        }

        if self.running.swap(true, Ordering::SeqCst) {
            return Err(AudioError::AlreadyRunning);
        }

        // Desktop harness will inject synthetic data in later tasks; for now we
        // simply accept the wiring to ensure CLI/HTTP code can build.
        let _ = ctx;

        Ok(())
    }

    fn stop(&self) -> Result<(), AudioError> {
        if !self.running.swap(false, Ordering::SeqCst) {
            return Err(AudioError::NotRunning);
        }
        Ok(())
    }

    fn set_bpm(&self, bpm: u32) -> Result<(), AudioError> {
        if bpm == 0 {
            return Err(AudioError::BpmInvalid { bpm });
        }
        if !self.running.load(Ordering::SeqCst) {
            return Err(AudioError::NotRunning);
        }
        Ok(())
    }
}

/// Deterministic time source for desktop runs.
///
/// Each call to `now()` advances by a fixed 10ms to guarantee monotonic
/// timestamps even when no real audio stream is active.
pub struct StubTimeSource {
    start: Instant,
    offset_ms: AtomicU64,
}

impl StubTimeSource {
    pub fn new() -> Self {
        Self {
            start: Instant::now(),
            offset_ms: AtomicU64::new(0),
        }
    }
}

impl Default for StubTimeSource {
    fn default() -> Self {
        Self::new()
    }
}

impl TimeSource for StubTimeSource {
    fn now(&self) -> Instant {
        let ms = self.offset_ms.fetch_add(10, Ordering::SeqCst);
        self.start + Duration::from_millis(ms)
    }
}
