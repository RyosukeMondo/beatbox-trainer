//! Backwards-compatible re-export of the new engine core.

pub use crate::engine::core::{EngineHandle, ParamPatch, TelemetryEvent, TelemetryEventKind};

/// Historical alias retained for existing code/tests.
pub type AppContext = EngineHandle;
