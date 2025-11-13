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
    /// * `calibration` - Arc<RwLock<CalibrationState>> for thread-safe threshold access
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
                // Lock poisoned - log error and return Unknown with zero confidence
                log::error!("Calibration state lock poisoned in classify_level2");
                return (BeatboxHit::Unknown, 0.0);
            }
        };

        // Calculate scores for all Level 2 classes
        let kick_score = self.calculate_kick_score_level2(features, &cal);
        let ksnare_score = self.calculate_ksnare_score_level2(features, &cal);
        let snare_score = self.calculate_snare_score_level1(features, &cal); // Same as Level 1
        let closed_hihat_score = self.calculate_closed_hihat_score_level2(features, &cal);
        let open_hihat_score = self.calculate_open_hihat_score_level2(features, &cal);
        let hihat_score = self.calculate_hihat_score_level1(features, &cal); // Generic hi-hat

        // Find max score and sum
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

        // Calculate confidence
        let confidence = if sum_scores > 0.0 {
            (max_score / sum_scores).clamp(0.0, 1.0)
        } else {
            0.0
        };

        // Apply decision rules (same logic as before)
        let classification =
            if features.centroid < cal.t_kick_centroid && features.zcr < cal.t_kick_zcr {
                // Level 2 enhancement: flatness check for kick subcategories
                if features.flatness < 0.1 {
                    BeatboxHit::Kick
                } else if features.flatness > 0.3 {
                    BeatboxHit::KSnare
                } else {
                    BeatboxHit::Kick
                }
            } else if features.centroid < cal.t_snare_centroid {
                BeatboxHit::Snare
            } else if features.centroid >= cal.t_snare_centroid && features.zcr > cal.t_hihat_zcr {
                // Level 2 enhancement: decay time check for hi-hat subcategories
                if features.decay_time_ms < 50.0 {
                    BeatboxHit::ClosedHiHat
                } else if features.decay_time_ms > 150.0 {
                    BeatboxHit::OpenHiHat
                } else {
                    BeatboxHit::HiHat
                }
            } else {
                BeatboxHit::Unknown
            };

        (classification, confidence)
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
    /// For now, defaults to Level 1. Future: add level selection to CalibrationState.
    ///
    /// # Arguments
    /// * `features` - Extracted DSP features
    ///
    /// # Returns
    /// Tuple of (BeatboxHit classification result, confidence score 0.0-1.0)
    pub fn classify(&self, features: &Features) -> (BeatboxHit, f32) {
        // Default to Level 1 for now
        // TODO: Add level selection to CalibrationState in future
        self.classify_level1(features)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Helper to create Features struct for testing
    fn create_features(centroid: f32, zcr: f32, flatness: f32, decay_time_ms: f32) -> Features {
        Features {
            centroid,
            zcr,
            flatness,
            rolloff: 0.0, // Not used in current classification
            decay_time_ms,
        }
    }

    /// Helper to create Classifier with default calibration
    fn create_classifier() -> Classifier {
        let cal = Arc::new(RwLock::new(CalibrationState::new_default()));
        Classifier::new(cal)
    }

    #[test]
    fn test_classify_level1_kick() {
        let classifier = create_classifier();

        // Low centroid (< 1500 Hz) AND low ZCR (< 0.1) = KICK
        let features = create_features(1000.0, 0.05, 0.0, 0.0);
        let (result, confidence) = classifier.classify_level1(&features);

        assert_eq!(
            result,
            BeatboxHit::Kick,
            "Expected Kick for low centroid ({} Hz) and low ZCR ({})",
            features.centroid,
            features.zcr
        );
        assert!(
            (0.0..=1.0).contains(&confidence),
            "Confidence should be between 0.0 and 1.0, got {}",
            confidence
        );
    }

    #[test]
    fn test_classify_level1_snare() {
        let classifier = create_classifier();

        // Mid centroid (< 4000 Hz but >= 1500 Hz OR high ZCR) = SNARE
        let features = create_features(2500.0, 0.2, 0.0, 0.0);
        let (result, confidence) = classifier.classify_level1(&features);

        assert_eq!(
            result,
            BeatboxHit::Snare,
            "Expected Snare for mid centroid ({} Hz)",
            features.centroid
        );
        assert!((0.0..=1.0).contains(&confidence));
    }

    #[test]
    fn test_classify_level1_hihat() {
        let classifier = create_classifier();

        // High centroid (>= 4000 Hz) AND high ZCR (> 0.3) = HI-HAT
        let features = create_features(6000.0, 0.4, 0.0, 0.0);
        let (result, confidence) = classifier.classify_level1(&features);

        assert_eq!(
            result,
            BeatboxHit::HiHat,
            "Expected HiHat for high centroid ({} Hz) and high ZCR ({})",
            features.centroid,
            features.zcr
        );
        assert!((0.0..=1.0).contains(&confidence));
    }

    #[test]
    fn test_classify_level1_unknown() {
        let classifier = create_classifier();

        // High centroid but low ZCR (doesn't match hi-hat pattern) = UNKNOWN
        let features = create_features(6000.0, 0.1, 0.0, 0.0);
        let (result, confidence) = classifier.classify_level1(&features);

        assert_eq!(
            result,
            BeatboxHit::Unknown,
            "Expected Unknown for high centroid ({} Hz) but low ZCR ({})",
            features.centroid,
            features.zcr
        );
        assert!((0.0..=1.0).contains(&confidence));
    }

    #[test]
    fn test_classify_level1_boundary_cases() {
        let classifier = create_classifier();

        // Test exact threshold boundaries
        // Centroid exactly at kick threshold with low ZCR = SNARE (not < threshold)
        let features1 = create_features(1500.0, 0.05, 0.0, 0.0);
        let (result1, _) = classifier.classify_level1(&features1);
        assert_eq!(
            result1,
            BeatboxHit::Snare,
            "Centroid at exact threshold should not be Kick"
        );

        // Centroid just below kick threshold with low ZCR = KICK
        let features2 = create_features(1499.0, 0.05, 0.0, 0.0);
        let (result2, _) = classifier.classify_level1(&features2);
        assert_eq!(
            result2,
            BeatboxHit::Kick,
            "Centroid just below threshold should be Kick"
        );

        // ZCR exactly at hihat threshold with high centroid = HI-HAT (not > threshold)
        let features3 = create_features(5000.0, 0.3, 0.0, 0.0);
        let (result3, _) = classifier.classify_level1(&features3);
        assert_eq!(
            result3,
            BeatboxHit::Unknown,
            "ZCR at exact threshold should not be HiHat (needs > not >=)"
        );

        // ZCR just above hihat threshold with high centroid = HI-HAT
        let features4 = create_features(5000.0, 0.31, 0.0, 0.0);
        let (result4, _) = classifier.classify_level1(&features4);
        assert_eq!(
            result4,
            BeatboxHit::HiHat,
            "ZCR just above threshold should be HiHat"
        );
    }

    #[test]
    fn test_classify_level2_kick_vs_ksnare() {
        let classifier = create_classifier();

        // Low centroid + low ZCR + low flatness (tonal) = KICK
        let kick_features = create_features(1000.0, 0.05, 0.05, 30.0);
        let (kick_result, kick_conf) = classifier.classify_level2(&kick_features);
        assert_eq!(
            kick_result,
            BeatboxHit::Kick,
            "Expected Kick for tonal low-frequency sound (flatness {})",
            kick_features.flatness
        );
        assert!((0.0..=1.0).contains(&kick_conf));

        // Low centroid + low ZCR + high flatness (noisy) = K-SNARE
        let ksnare_features = create_features(1000.0, 0.05, 0.4, 30.0);
        let (ksnare_result, ksnare_conf) = classifier.classify_level2(&ksnare_features);
        assert_eq!(
            ksnare_result,
            BeatboxHit::KSnare,
            "Expected KSnare for noisy low-frequency sound (flatness {})",
            ksnare_features.flatness
        );
        assert!((0.0..=1.0).contains(&ksnare_conf));

        // Low centroid + low ZCR + intermediate flatness = KICK (default)
        let intermediate_features = create_features(1000.0, 0.05, 0.2, 30.0);
        let (intermediate_result, intermediate_conf) =
            classifier.classify_level2(&intermediate_features);
        assert_eq!(
            intermediate_result,
            BeatboxHit::Kick,
            "Expected Kick for intermediate flatness ({})",
            intermediate_features.flatness
        );
        assert!((0.0..=1.0).contains(&intermediate_conf));
    }

    #[test]
    fn test_classify_level2_closed_vs_open_hihat() {
        let classifier = create_classifier();

        // High centroid + high ZCR + short decay (< 50ms) = CLOSED HI-HAT
        let closed_features = create_features(6000.0, 0.4, 0.6, 30.0);
        let (closed_result, closed_conf) = classifier.classify_level2(&closed_features);
        assert_eq!(
            closed_result,
            BeatboxHit::ClosedHiHat,
            "Expected ClosedHiHat for short decay ({} ms)",
            closed_features.decay_time_ms
        );
        assert!((0.0..=1.0).contains(&closed_conf));

        // High centroid + high ZCR + long decay (> 150ms) = OPEN HI-HAT
        let open_features = create_features(6000.0, 0.4, 0.6, 200.0);
        let (open_result, open_conf) = classifier.classify_level2(&open_features);
        assert_eq!(
            open_result,
            BeatboxHit::OpenHiHat,
            "Expected OpenHiHat for long decay ({} ms)",
            open_features.decay_time_ms
        );
        assert!((0.0..=1.0).contains(&open_conf));

        // High centroid + high ZCR + intermediate decay = HI-HAT (generic)
        let generic_features = create_features(6000.0, 0.4, 0.6, 100.0);
        let (generic_result, generic_conf) = classifier.classify_level2(&generic_features);
        assert_eq!(
            generic_result,
            BeatboxHit::HiHat,
            "Expected generic HiHat for intermediate decay ({} ms)",
            generic_features.decay_time_ms
        );
        assert!((0.0..=1.0).contains(&generic_conf));
    }

    #[test]
    fn test_classify_level2_snare_unchanged() {
        let classifier = create_classifier();

        // Snare classification should be same in Level 2 (no subcategories)
        let features = create_features(2500.0, 0.2, 0.5, 100.0);
        let (level1_result, _) = classifier.classify_level1(&features);
        let (level2_result, _) = classifier.classify_level2(&features);

        assert_eq!(level1_result, BeatboxHit::Snare);
        assert_eq!(level2_result, BeatboxHit::Snare);
        assert_eq!(
            level1_result, level2_result,
            "Snare should have same classification in Level 1 and Level 2"
        );
    }

    #[test]
    fn test_classify_uses_level1() {
        let classifier = create_classifier();

        // Test that classify() defaults to Level 1
        let features = create_features(1000.0, 0.05, 0.0, 0.0);
        let classify_result = classifier.classify(&features);
        let level1_result = classifier.classify_level1(&features);

        assert_eq!(
            classify_result, level1_result,
            "classify() should default to Level 1"
        );
    }

    #[test]
    fn test_thread_safe_calibration_access() {
        // Test that multiple classifiers can share calibration state
        let cal = Arc::new(RwLock::new(CalibrationState::new_default()));
        let classifier1 = Classifier::new(Arc::clone(&cal));
        let classifier2 = Classifier::new(Arc::clone(&cal));

        let features = create_features(1000.0, 0.05, 0.0, 0.0);

        // Both classifiers should produce same result with shared state
        assert_eq!(
            classifier1.classify(&features),
            classifier2.classify(&features),
            "Classifiers with shared calibration should produce same results"
        );
    }

    #[test]
    fn test_classifier_with_custom_calibration() {
        // Create custom calibration with different thresholds
        let mut custom_cal = CalibrationState::new_default();
        custom_cal.t_kick_centroid = 2000.0; // Higher kick threshold
        custom_cal.t_snare_centroid = 5000.0; // Higher snare threshold

        let cal = Arc::new(RwLock::new(custom_cal));
        let classifier = Classifier::new(cal);

        // Test that classifier uses custom thresholds
        let features = create_features(1800.0, 0.05, 0.0, 0.0);

        // With default thresholds (1500 Hz): would be SNARE
        // With custom thresholds (2000 Hz): should be KICK
        let (result, _) = classifier.classify(&features);
        assert_eq!(
            result,
            BeatboxHit::Kick,
            "Classifier should use custom calibration thresholds"
        );
    }

    #[test]
    fn test_all_enum_variants_reachable() {
        let classifier = create_classifier();

        // Ensure all enum variants can be reached
        let (kick, _) = classifier.classify_level1(&create_features(1000.0, 0.05, 0.0, 0.0));
        let (snare, _) = classifier.classify_level1(&create_features(2500.0, 0.2, 0.0, 0.0));
        let (hihat, _) = classifier.classify_level1(&create_features(6000.0, 0.4, 0.0, 0.0));
        let (unknown, _) = classifier.classify_level1(&create_features(6000.0, 0.1, 0.0, 0.0));

        let (closed_hihat, _) =
            classifier.classify_level2(&create_features(6000.0, 0.4, 0.6, 30.0));
        let (open_hihat, _) = classifier.classify_level2(&create_features(6000.0, 0.4, 0.6, 200.0));
        let (ksnare, _) = classifier.classify_level2(&create_features(1000.0, 0.05, 0.4, 30.0));

        assert_eq!(kick, BeatboxHit::Kick);
        assert_eq!(snare, BeatboxHit::Snare);
        assert_eq!(hihat, BeatboxHit::HiHat);
        assert_eq!(unknown, BeatboxHit::Unknown);
        assert_eq!(closed_hihat, BeatboxHit::ClosedHiHat);
        assert_eq!(open_hihat, BeatboxHit::OpenHiHat);
        assert_eq!(ksnare, BeatboxHit::KSnare);
    }
}
