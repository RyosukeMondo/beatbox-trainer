// Classifier - heuristic rule-based beatbox sound classification
//
// This module implements a decision-tree classifier for distinguishing between
// different beatbox sounds using DSP features. It supports two difficulty levels:
//
// Level 1: Basic classification (Kick, Snare, HiHat)
// Level 2: Advanced classification with subcategories (ClosedHiHat, OpenHiHat, KSnare)
//
// Classification uses calibrated thresholds from CalibrationState and features
// extracted by FeatureExtractor (centroid, ZCR, flatness, decay_time).
//
// References:
// - Requirement 6: Heuristic Sound Classification
// - Requirement 10: Progressive Difficulty - Level 2

use crate::analysis::features::Features;
use crate::calibration::state::CalibrationState;
use std::sync::{Arc, RwLock};

/// BeatboxHit represents classified beatbox sounds
///
/// Level 1 sounds: Kick, Snare, HiHat
/// Level 2 adds subcategories: ClosedHiHat, OpenHiHat, KSnare
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum BeatboxHit {
    /// Kick drum (low frequency, low ZCR)
    Kick,
    /// Snare drum (mid frequency)
    Snare,
    /// Hi-hat (high frequency, high ZCR) - Level 1 generic
    HiHat,
    /// Closed hi-hat (short decay) - Level 2
    ClosedHiHat,
    /// Open hi-hat (long decay) - Level 2
    OpenHiHat,
    /// K-snare (kick+snare hybrid, noisy kick) - Level 2
    KSnare,
    /// Unknown sound (doesn't match any pattern)
    Unknown,
}

/// Classifier applies heuristic rules to classify beatbox sounds
///
/// Uses calibrated thresholds from CalibrationState (thread-safe via RwLock)
/// and DSP features from FeatureExtractor to classify sounds into BeatboxHit categories.
pub struct Classifier {
    /// Calibration state with thresholds (thread-safe, read-only during classification)
    calibration: Arc<RwLock<CalibrationState>>,
}

impl Classifier {
    /// Create a new Classifier with calibration state reference
    ///
    /// # Arguments
    /// * `calibration` - `Arc<RwLock<CalibrationState>>` for thread-safe threshold access
    pub fn new(calibration: Arc<RwLock<CalibrationState>>) -> Self {
        Self { calibration }
    }

    /// Classify a sound using Level 1 rules (basic classification)
    ///
    /// Decision tree (from Requirement 6):
    /// 1. IF centroid < T_KICK_CENTROID AND zcr < T_KICK_ZCR THEN Kick
    /// 2. ELSE IF centroid < T_SNARE_CENTROID THEN Snare
    /// 3. ELSE IF centroid >= T_SNARE_CENTROID AND zcr > T_HIHAT_ZCR THEN HiHat
    /// 4. ELSE Unknown
    ///
    /// # Arguments
    /// * `features` - Extracted DSP features (centroid, ZCR, etc.)
    ///
    /// # Returns
    /// Tuple of (BeatboxHit classification, confidence score 0.0-1.0)
    pub fn classify_level1(&self, features: &Features) -> (BeatboxHit, f32) {
        // Read calibration thresholds (thread-safe)
        let cal = match self.calibration.read() {
            Ok(guard) => guard,
            Err(_) => {
                // Lock poisoned - log error and return Unknown with zero confidence
                log::error!("Calibration state lock poisoned in classify_level1");
                return (BeatboxHit::Unknown, 0.0);
            }
        };

        // Calculate scores for each class (simple distance-based scoring)
        // Lower distance from ideal = higher score
        let kick_score = self.calculate_kick_score_level1(features, &cal);
        let snare_score = self.calculate_snare_score_level1(features, &cal);
        let hihat_score = self.calculate_hihat_score_level1(features, &cal);

        // Find the maximum score
        let max_score = kick_score.max(snare_score).max(hihat_score);
        let sum_scores = kick_score + snare_score + hihat_score;

        // Calculate confidence as max_score / sum_of_scores
        // Handle edge case where all scores are zero
        let confidence = if sum_scores > 0.0 {
            (max_score / sum_scores).clamp(0.0, 1.0)
        } else {
            0.0
        };

        // Apply decision rules (same as before)
        let classification =
            if features.centroid < cal.t_kick_centroid && features.zcr < cal.t_kick_zcr {
                BeatboxHit::Kick
            } else if features.centroid < cal.t_snare_centroid {
                BeatboxHit::Snare
            } else if features.centroid >= cal.t_snare_centroid && features.zcr > cal.t_hihat_zcr {
                BeatboxHit::HiHat
            } else {
                BeatboxHit::Unknown
            };

        (classification, confidence)
    }

    /// Calculate kick score for Level 1 classification
    /// Score is higher when features match kick characteristics
    fn calculate_kick_score_level1(&self, features: &Features, cal: &CalibrationState) -> f32 {
        // Ideal kick: low centroid, low ZCR
        // Distance from thresholds (normalized)
        let centroid_dist = (features.centroid / cal.t_kick_centroid).min(2.0);
        let zcr_dist = (features.zcr / cal.t_kick_zcr).min(2.0);

        // Score decreases with distance from ideal
        let score = (2.0 - centroid_dist) * (2.0 - zcr_dist);
        score.max(0.0)
    }

    /// Calculate snare score for Level 1 classification
    fn calculate_snare_score_level1(&self, features: &Features, cal: &CalibrationState) -> f32 {
        // Ideal snare: mid centroid (between kick and hihat thresholds)
        let mid_point = (cal.t_kick_centroid + cal.t_snare_centroid) / 2.0;
        let centroid_dist = (features.centroid - mid_point).abs() / cal.t_snare_centroid;

        // Score is higher when centroid is in the middle range
        let score = 1.0 - centroid_dist.min(1.0);
        score.max(0.0)
    }

    /// Calculate hi-hat score for Level 1 classification
    fn calculate_hihat_score_level1(&self, features: &Features, cal: &CalibrationState) -> f32 {
        // Ideal hi-hat: high centroid, high ZCR
        let centroid_factor = (features.centroid / cal.t_snare_centroid).min(2.0);
        let zcr_factor = (features.zcr / cal.t_hihat_zcr).min(2.0);

        // Score increases with higher values
        let score = (centroid_factor + zcr_factor) / 2.0;
        score.max(0.0)
    }

    /// Classify a sound using Level 2 rules (advanced with subcategories)
    ///
    /// Level 2 enhancements (from Requirement 10):
    /// - Hi-hat subcategories: decay_time distinguishes closed (< 50ms) vs open (> 150ms)
    /// - Kick subcategories: flatness distinguishes kick (< 0.1 tonal) vs K-snare (> 0.3 noisy)
    ///
    /// # Arguments
    /// * `features` - Extracted DSP features (all 5: centroid, ZCR, flatness, rolloff, decay_time)
    ///
    /// # Returns
    /// Tuple of (BeatboxHit classification with subcategories, confidence score 0.0-1.0)
    pub fn classify_level2(&self, features: &Features) -> (BeatboxHit, f32) {
        // Read calibration thresholds
        let cal = match self.calibration.read() {
            Ok(guard) => guard,
            Err(_) => {
                log::error!("Calibration state lock poisoned in classify_level2");
                return (BeatboxHit::Unknown, 0.0);
            }
        };

        // Calculate scores and confidence
        let confidence = self.calculate_level2_confidence(features, &cal);

        // Apply decision rules
        let classification = self.apply_level2_decision_rules(features, &cal);

        (classification, confidence)
    }

    /// Calculate confidence score for Level 2 classification
    fn calculate_level2_confidence(&self, features: &Features, cal: &CalibrationState) -> f32 {
        let kick_score = self.calculate_kick_score_level2(features, cal);
        let ksnare_score = self.calculate_ksnare_score_level2(features, cal);
        let snare_score = self.calculate_snare_score_level1(features, cal);
        let closed_hihat_score = self.calculate_closed_hihat_score_level2(features, cal);
        let open_hihat_score = self.calculate_open_hihat_score_level2(features, cal);
        let hihat_score = self.calculate_hihat_score_level1(features, cal);

        let max_score = kick_score
            .max(ksnare_score)
            .max(snare_score)
            .max(closed_hihat_score)
            .max(open_hihat_score)
            .max(hihat_score);
        let sum_scores = kick_score
            + ksnare_score
            + snare_score
            + closed_hihat_score
            + open_hihat_score
            + hihat_score;

        if sum_scores > 0.0 {
            (max_score / sum_scores).clamp(0.0, 1.0)
        } else {
            0.0
        }
    }

    /// Apply decision tree rules for Level 2 classification
    fn apply_level2_decision_rules(
        &self,
        features: &Features,
        cal: &CalibrationState,
    ) -> BeatboxHit {
        if features.centroid < cal.t_kick_centroid && features.zcr < cal.t_kick_zcr {
            // Level 2 enhancement: flatness check for kick subcategories
            self.classify_kick_subcategory(features.flatness)
        } else if features.centroid < cal.t_snare_centroid {
            BeatboxHit::Snare
        } else if features.centroid >= cal.t_snare_centroid && features.zcr > cal.t_hihat_zcr {
            // Level 2 enhancement: decay time check for hi-hat subcategories
            self.classify_hihat_subcategory(features.decay_time_ms)
        } else {
            BeatboxHit::Unknown
        }
    }

    /// Classify kick subcategory based on flatness
    fn classify_kick_subcategory(&self, flatness: f32) -> BeatboxHit {
        if flatness < 0.1 {
            BeatboxHit::Kick
        } else if flatness > 0.3 {
            BeatboxHit::KSnare
        } else {
            BeatboxHit::Kick
        }
    }

    /// Classify hi-hat subcategory based on decay time
    fn classify_hihat_subcategory(&self, decay_time_ms: f32) -> BeatboxHit {
        if decay_time_ms < 50.0 {
            BeatboxHit::ClosedHiHat
        } else if decay_time_ms > 150.0 {
            BeatboxHit::OpenHiHat
        } else {
            BeatboxHit::HiHat
        }
    }

    /// Calculate kick score for Level 2 (tonal kick)
    fn calculate_kick_score_level2(&self, features: &Features, cal: &CalibrationState) -> f32 {
        let base_score = self.calculate_kick_score_level1(features, cal);
        // Bonus for low flatness (tonal)
        let flatness_bonus = if features.flatness < 0.1 { 1.5 } else { 0.5 };
        (base_score * flatness_bonus).max(0.0)
    }

    /// Calculate K-snare score for Level 2 (noisy kick)
    fn calculate_ksnare_score_level2(&self, features: &Features, cal: &CalibrationState) -> f32 {
        let base_score = self.calculate_kick_score_level1(features, cal);
        // Bonus for high flatness (noisy)
        let flatness_bonus = if features.flatness > 0.3 { 1.5 } else { 0.5 };
        (base_score * flatness_bonus).max(0.0)
    }

    /// Calculate closed hi-hat score for Level 2
    fn calculate_closed_hihat_score_level2(
        &self,
        features: &Features,
        cal: &CalibrationState,
    ) -> f32 {
        let base_score = self.calculate_hihat_score_level1(features, cal);
        // Bonus for short decay time
        let decay_bonus = if features.decay_time_ms < 50.0 {
            1.5
        } else {
            0.5
        };
        (base_score * decay_bonus).max(0.0)
    }

    /// Calculate open hi-hat score for Level 2
    fn calculate_open_hihat_score_level2(
        &self,
        features: &Features,
        cal: &CalibrationState,
    ) -> f32 {
        let base_score = self.calculate_hihat_score_level1(features, cal);
        // Bonus for long decay time
        let decay_bonus = if features.decay_time_ms > 150.0 {
            1.5
        } else {
            0.5
        };
        (base_score * decay_bonus).max(0.0)
    }

    /// Classify a sound (convenience method that chooses level based on configuration)
    ///
    /// Dispatches to classify_level1() or classify_level2() based on the level field
    /// in CalibrationState. Defaults to Level 1 if lock is poisoned.
    ///
    /// # Arguments
    /// * `features` - Extracted DSP features
    ///
    /// # Returns
    /// Tuple of (BeatboxHit classification result, confidence score 0.0-1.0)
    pub fn classify(&self, features: &Features) -> (BeatboxHit, f32) {
        // Read calibration level (thread-safe)
        let level = match self.calibration.read() {
            Ok(guard) => guard.level,
            Err(_) => {
                // Lock poisoned - log error and default to Level 1
                log::error!("Calibration state lock poisoned in classify, defaulting to Level 1");
                1
            }
        };

        // Dispatch based on level
        match level {
            2 => self.classify_level2(features),
            _ => self.classify_level1(features), // Default to Level 1 for any other value
        }
    }
}

#[cfg(test)]
#[path = "classifier_tests.rs"]
mod tests;
