use crate::analysis::features::Features;
use crate::calibration::progress::CalibrationSound;

const RMS_GATE_START_MULTIPLIER: f64 = 1.6;
const RMS_GATE_FLOOR_MULTIPLIER: f64 = 1.2;
pub(super) const BACKOFF_TRIGGER: u8 = 3;
pub(super) const MAX_BACKOFF_STEPS: u8 = 3;
const FEATURE_BACKOFF_PCT: f32 = 0.12;

/// Sound-indexed centroid gates (min, max) before backoff
const BASE_CENTROID_GATES: [(f32, f32); 3] = [
    (60.0, 2000.0),    // Kick
    (500.0, 7000.0),   // Snare
    (3500.0, 14000.0), // Hi-hat
];

/// Sound-indexed ZCR gates (min, max) before backoff
const BASE_ZCR_GATES: [(f32, f32); 3] = [
    (0.0, 0.3),  // Kick
    (0.02, 0.6), // Snare
    (0.18, 1.0), // Hi-hat
];

#[derive(Clone, Copy, Debug)]
pub(super) struct AdaptiveGateState {
    pub(super) rejects: u8,
    pub(super) step: u8,
    pub(super) rms_gate: f64,
    pub(super) centroid_min: f32,
    pub(super) centroid_max: f32,
    pub(super) zcr_min: f32,
    pub(super) zcr_max: f32,
}

pub(super) struct AdaptiveBackoff {
    pub(super) gates: [AdaptiveGateState; 3],
    noise_floor_threshold: Option<f64>,
}

impl AdaptiveBackoff {
    pub(super) fn new(noise_floor_threshold: Option<f64>) -> Self {
        Self {
            gates: Self::init_gates(noise_floor_threshold),
            noise_floor_threshold,
        }
    }

    pub(super) fn update_noise_floor(&mut self, noise_floor_threshold: Option<f64>) {
        self.noise_floor_threshold = noise_floor_threshold;
        self.gates = Self::init_gates(noise_floor_threshold);
    }

    pub(super) fn reset_for_sound(&mut self, sound: CalibrationSound) {
        if let Some(idx) = Self::gate_index(sound) {
            self.gates[idx] = Self::gate_state_for_index(idx, self.noise_floor_threshold);
        }
    }

    pub(super) fn record_reject(&mut self, sound: CalibrationSound, reason: &str) {
        if let Some(idx) = Self::gate_index(sound) {
            let state = &mut self.gates[idx];
            state.rejects = state.rejects.saturating_add(1);
            self.apply_backoff(sound, reason);
        }
    }

    pub(super) fn record_success(&mut self, sound: CalibrationSound) {
        self.reset_for_sound(sound);
    }

    pub(super) fn passes_feature_gates(
        &self,
        sound: CalibrationSound,
        features: &Features,
    ) -> bool {
        if let Some(idx) = Self::gate_index(sound) {
            let gates = &self.gates[idx];
            return features.centroid >= gates.centroid_min
                && features.centroid <= gates.centroid_max
                && features.zcr >= gates.zcr_min
                && features.zcr <= gates.zcr_max;
        }
        true
    }

    pub(super) fn rms_gate(&self, sound: CalibrationSound) -> Option<f64> {
        Self::gate_index(sound).map(|idx| self.gates[idx].rms_gate)
    }

    #[cfg(test)]
    pub(super) fn gate_floor(&self) -> f64 {
        Self::gate_floor_value(self.noise_floor_threshold)
    }

    #[cfg(test)]
    pub(super) fn gate_state(&self, sound: CalibrationSound) -> Option<&AdaptiveGateState> {
        Self::gate_index(sound).map(|idx| &self.gates[idx])
    }

    fn gate_index(sound: CalibrationSound) -> Option<usize> {
        match sound {
            CalibrationSound::Kick => Some(0),
            CalibrationSound::Snare => Some(1),
            CalibrationSound::HiHat => Some(2),
            CalibrationSound::NoiseFloor => None,
        }
    }

    fn gate_floor_value(noise_floor_threshold: Option<f64>) -> f64 {
        noise_floor_threshold.unwrap_or(super::MIN_RMS_THRESHOLD) * RMS_GATE_FLOOR_MULTIPLIER
    }

    fn starting_rms_gate(noise_floor_threshold: Option<f64>) -> f64 {
        noise_floor_threshold.unwrap_or(super::MIN_RMS_THRESHOLD) * RMS_GATE_START_MULTIPLIER
    }

    fn gate_state_for_index(idx: usize, noise_floor_threshold: Option<f64>) -> AdaptiveGateState {
        AdaptiveGateState {
            rejects: 0,
            step: 0,
            rms_gate: Self::starting_rms_gate(noise_floor_threshold),
            centroid_min: BASE_CENTROID_GATES[idx].0,
            centroid_max: BASE_CENTROID_GATES[idx].1,
            zcr_min: BASE_ZCR_GATES[idx].0,
            zcr_max: BASE_ZCR_GATES[idx].1,
        }
    }

    fn init_gates(noise_floor_threshold: Option<f64>) -> [AdaptiveGateState; 3] {
        [
            Self::gate_state_for_index(0, noise_floor_threshold),
            Self::gate_state_for_index(1, noise_floor_threshold),
            Self::gate_state_for_index(2, noise_floor_threshold),
        ]
    }

    #[allow(clippy::manual_is_multiple_of)]
    fn apply_backoff(&mut self, sound: CalibrationSound, reason: &str) {
        if let Some(idx) = Self::gate_index(sound) {
            let floor = Self::gate_floor_value(self.noise_floor_threshold);
            let state = &mut self.gates[idx];
            if state.rejects % BACKOFF_TRIGGER == 0 && state.step < MAX_BACKOFF_STEPS {
                state.step += 1;
                state.rms_gate = (state.rms_gate * 0.85).max(floor);
                state.centroid_min = (state.centroid_min * (1.0 - FEATURE_BACKOFF_PCT)).max(50.0);
                state.centroid_max =
                    (state.centroid_max * (1.0 + FEATURE_BACKOFF_PCT)).min(20_000.0);
                state.zcr_min = (state.zcr_min * (1.0 - FEATURE_BACKOFF_PCT)).max(0.0);
                state.zcr_max = (state.zcr_max * (1.0 + FEATURE_BACKOFF_PCT)).min(1.0);

                log::info!(
                    "[CalibrationProcedure] Backoff step {} for {:?} after {} rejects (reason: {}). RMS gate: {:.4}, centroid: {:.1}-{:.1}, zcr: {:.3}-{:.3}",
                    state.step,
                    sound,
                    state.rejects,
                    reason,
                    state.rms_gate,
                    state.centroid_min,
                    state.centroid_max,
                    state.zcr_min,
                    state.zcr_max
                );
            }
        }
    }
}
