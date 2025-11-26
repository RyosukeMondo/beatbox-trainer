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
fn test_classify_dispatches_by_level() {
    // Test Level 1 dispatch (default)
    let classifier_l1 = create_classifier();
    let features = create_features(1000.0, 0.05, 0.0, 0.0);
    let classify_result = classifier_l1.classify(&features);
    let level1_result = classifier_l1.classify_level1(&features);

    assert_eq!(
        classify_result, level1_result,
        "classify() should use Level 1 when level=1"
    );

    // Test Level 2 dispatch
    let mut cal_l2 = CalibrationState::new_default();
    cal_l2.level = 2;
    let classifier_l2 = Classifier::new(Arc::new(RwLock::new(cal_l2)));

    let classify_result_l2 = classifier_l2.classify(&features);
    let level2_result = classifier_l2.classify_level2(&features);

    assert_eq!(
        classify_result_l2, level2_result,
        "classify() should use Level 2 when level=2"
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

    let (closed_hihat, _) = classifier.classify_level2(&create_features(6000.0, 0.4, 0.6, 30.0));
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
