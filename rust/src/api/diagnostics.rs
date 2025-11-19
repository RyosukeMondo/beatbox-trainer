#[cfg(any(test, feature = "diagnostics_fixtures"))]
use super::ENGINE_HANDLE;
use crate::error::AudioError;
#[cfg(any(test, feature = "diagnostics_fixtures"))]
use crate::testing::fixture_engine::{self, FixtureHandle};
use crate::testing::fixture_manifest::{FixtureManifestCatalog, FixtureManifestEntry};
use crate::testing::fixtures::FixtureSpec;
use flutter_rust_bridge::frb;
#[cfg(any(test, feature = "diagnostics_fixtures"))]
use once_cell::sync::Lazy;
#[cfg(any(test, feature = "diagnostics_fixtures"))]
use std::sync::Mutex;

#[cfg(any(test, feature = "diagnostics_fixtures"))]
static FIXTURE_SESSION: Lazy<Mutex<Option<FixtureHandle>>> = Lazy::new(|| Mutex::new(None));

/// Start a diagnostics fixture session feeding PCM data into the DSP pipeline.
#[frb]
pub fn start_fixture_session(spec: FixtureSpec) -> Result<(), AudioError> {
    #[cfg(any(test, feature = "diagnostics_fixtures"))]
    {
        let mut guard = FIXTURE_SESSION
            .lock()
            .map_err(|_| AudioError::LockPoisoned {
                component: "fixture_session".to_string(),
            })?;
        if guard.is_some() {
            return Err(AudioError::AlreadyRunning);
        }

        let handle = fixture_engine::start_fixture_session_internal(&ENGINE_HANDLE, spec)?;
        *guard = Some(handle);
        Ok(())
    }

    #[cfg(not(any(test, feature = "diagnostics_fixtures")))]
    {
        let _ = spec;
        Err(AudioError::StreamFailure {
            reason: "diagnostics fixtures disabled in this build".to_string(),
        })
    }
}

/// Stop the currently running diagnostics fixture session, if any.
#[frb(sync)]
pub fn stop_fixture_session() -> Result<(), AudioError> {
    #[cfg(any(test, feature = "diagnostics_fixtures"))]
    {
        let mut guard = FIXTURE_SESSION
            .lock()
            .map_err(|_| AudioError::LockPoisoned {
                component: "fixture_session".to_string(),
            })?;

        if let Some(mut handle) = guard.take() {
            handle.stop()
        } else {
            Err(AudioError::NotRunning)
        }
    }

    #[cfg(not(any(test, feature = "diagnostics_fixtures")))]
    {
        Err(AudioError::StreamFailure {
            reason: "diagnostics fixtures disabled in this build".to_string(),
        })
    }
}

/// Return the full fixture metadata catalog for diagnostics consumers.
#[frb(sync)]
pub fn load_fixture_catalog() -> Result<Vec<FixtureManifestEntry>, AudioError> {
    let catalog = FixtureManifestCatalog::load_from_default()?;
    Ok(catalog.fixtures)
}

/// Return a single fixture metadata entry by id when present.
#[frb(sync)]
pub fn fixture_metadata_for_id(id: String) -> Result<Option<FixtureManifestEntry>, AudioError> {
    let catalog = FixtureManifestCatalog::load_from_default()?;
    Ok(catalog.find(&id).cloned())
}

pub(crate) fn fixture_session_is_running() -> bool {
    #[cfg(any(test, feature = "diagnostics_fixtures"))]
    {
        FIXTURE_SESSION
            .lock()
            .map(|guard| {
                guard
                    .as_ref()
                    .map(|handle| handle.is_running())
                    .unwrap_or(false)
            })
            .unwrap_or(false)
    }

    #[cfg(not(any(test, feature = "diagnostics_fixtures")))]
    {
        false
    }
}
