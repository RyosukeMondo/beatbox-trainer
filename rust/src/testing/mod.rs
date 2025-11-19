//! Diagnostics + testability harness utilities.
//!
//! Modules in this namespace are only compiled for unit tests or when the
//! `diagnostics_fixtures` Cargo feature is enabled, ensuring the production
//! build stays lean while still allowing richly instrumented harnesses during
//! development.

pub mod fixture_engine;
pub mod fixture_manifest;
pub mod fixture_validation;
pub mod fixtures;
