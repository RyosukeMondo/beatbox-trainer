#[cfg(any(test, feature = "diagnostics_fixtures"))]
use super::ENGINE_HANDLE;
use crate::error::AudioError;
#[cfg(any(test, feature = "diagnostics_fixtures"))]
use crate::testing::fixture_engine::{self, FixtureHandle};
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
