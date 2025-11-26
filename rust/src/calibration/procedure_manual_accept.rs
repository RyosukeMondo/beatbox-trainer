use std::time::Instant;

use crate::analysis::features::Features;
use crate::calibration::progress::CalibrationSound;
use crate::calibration::CalibrationProgress;
use crate::error::CalibrationError;

use super::CalibrationProcedure;

#[derive(Default)]
pub(super) struct CandidateBuffer {
    pub(super) kick: Option<Features>,
    pub(super) snare: Option<Features>,
    pub(super) hihat: Option<Features>,
}

impl CandidateBuffer {
    pub(super) fn store(&mut self, sound: CalibrationSound, features: Features) {
        match sound {
            CalibrationSound::Kick => self.kick = Some(features),
            CalibrationSound::Snare => self.snare = Some(features),
            CalibrationSound::HiHat => self.hihat = Some(features),
            CalibrationSound::NoiseFloor => {}
        }
    }

    pub(super) fn take(&mut self, sound: CalibrationSound) -> Option<Features> {
        match sound {
            CalibrationSound::Kick => self.kick.take(),
            CalibrationSound::Snare => self.snare.take(),
            CalibrationSound::HiHat => self.hihat.take(),
            CalibrationSound::NoiseFloor => None,
        }
    }

    pub(super) fn clear_sound(&mut self, sound: CalibrationSound) {
        let _ = self.take(sound);
    }

    pub(super) fn clear_all(&mut self) {
        self.kick = None;
        self.snare = None;
        self.hihat = None;
    }
}

impl CalibrationProcedure {
    /// Manually accept the last rejected-but-valid candidate for the current sound
    ///
    /// # Returns
    /// * `Ok(CalibrationProgress)` - Updated progress after manual acceptance
    /// * `Err(CalibrationError)` - No candidate available or sound already complete
    pub fn manual_accept_last_candidate(
        &mut self,
    ) -> Result<CalibrationProgress, CalibrationError> {
        if self.current_sound == CalibrationSound::NoiseFloor {
            return Err(CalibrationError::InvalidFeatures {
                reason: "Manual accept is only available during sound collection phases."
                    .to_string(),
            });
        }

        if self.waiting_for_confirmation {
            return Err(CalibrationError::InvalidFeatures {
                reason: "Current sound already complete. Confirm or retry before manual accept."
                    .to_string(),
            });
        }

        let sound = self.current_sound;
        let candidate =
            self.last_candidates
                .take(sound)
                .ok_or_else(|| CalibrationError::InvalidFeatures {
                    reason: format!("No candidate available for manual accept on {:?}", sound),
                })?;

        let samples_needed = self.samples_needed;
        let collection = self.collection_for_sound(sound);
        Self::add_to_collection(collection, candidate, samples_needed)?;
        self.backoff.record_success(sound);
        self.last_sample_time = Some(Instant::now());

        if self.is_current_sound_complete() {
            self.waiting_for_confirmation = true;
            log::info!(
                "[CalibrationProcedure] Manual accept completed {:?} collection",
                sound
            );
        }

        let progress = self.get_progress();
        log::info!(
            "[CalibrationProcedure] Manual accept used for {:?}. Progress: {:?}",
            sound,
            progress
        );
        Ok(progress)
    }

    pub(super) fn store_candidate(&mut self, sound: CalibrationSound, features: Features) {
        if sound.is_sound_phase() {
            self.last_candidates.store(sound, features);
        }
    }

    pub(super) fn clear_candidate_for_sound(&mut self, sound: CalibrationSound) {
        if sound.is_sound_phase() {
            self.last_candidates.clear_sound(sound);
        }
    }

    pub(super) fn clear_all_candidates(&mut self) {
        self.last_candidates.clear_all();
    }

    fn collection_for_sound(&mut self, sound: CalibrationSound) -> &mut Vec<Features> {
        match sound {
            CalibrationSound::Kick => &mut self.kick_samples,
            CalibrationSound::Snare => &mut self.snare_samples,
            CalibrationSound::HiHat => &mut self.hihat_samples,
            CalibrationSound::NoiseFloor => unreachable!("Noise floor has no feature collection"),
        }
    }
}
