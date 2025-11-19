//! Engine module housing the reusable audio core.
//!
//! This module exposes trait-based backends (`backend`) and the `EngineHandle`
//! orchestration layer (`core`). Future tasks will extend this area with CLI,
//! HTTP, and telemetry adapters.

pub mod backend;
pub mod core;

#[cfg(target_os = "android")]
pub use backend::OboeBackend;
pub use backend::{AudioBackend, DesktopStubBackend, StubTimeSource, SystemTimeSource, TimeSource};
pub use core::{EngineHandle, ParamPatch, TelemetryEvent, TelemetryEventKind};
