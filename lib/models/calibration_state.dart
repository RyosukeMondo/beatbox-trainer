/// Calibration state model mirroring the Rust `CalibrationState` struct.
///
/// Provides helpers for converting between the flattened JSON representation
/// used by flutter_rust_bridge and the Dart storage layer.
class CalibrationState {
  final int level;
  final double tKickCentroid;
  final double tKickZcr;
  final double tSnareCentroid;
  final double tHihatZcr;
  final bool isCalibrated;
  final double noiseFloorRms;

  const CalibrationState({
    required this.level,
    required this.tKickCentroid,
    required this.tKickZcr,
    required this.tSnareCentroid,
    required this.tHihatZcr,
    required this.isCalibrated,
    this.noiseFloorRms = 0.01,
  });

  factory CalibrationState.fromJson(Map<String, dynamic> json) {
    return CalibrationState(
      level: json['level'] as int? ?? 1,
      tKickCentroid: (json['t_kick_centroid'] as num? ?? 1500).toDouble(),
      tKickZcr: (json['t_kick_zcr'] as num? ?? 0.1).toDouble(),
      tSnareCentroid: (json['t_snare_centroid'] as num? ?? 4000).toDouble(),
      tHihatZcr: (json['t_hihat_zcr'] as num? ?? 0.3).toDouble(),
      isCalibrated: json['is_calibrated'] as bool? ?? false,
      noiseFloorRms: (json['noise_floor_rms'] as num? ?? 0.01).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      't_kick_centroid': tKickCentroid,
      't_kick_zcr': tKickZcr,
      't_snare_centroid': tSnareCentroid,
      't_hihat_zcr': tHihatZcr,
      'is_calibrated': isCalibrated,
      'noise_floor_rms': noiseFloorRms,
    };
  }

  /// Convenience helper for persisting thresholds independently from flags.
  Map<String, double> toThresholdMap() {
    return {
      't_kick_centroid': tKickCentroid,
      't_kick_zcr': tKickZcr,
      't_snare_centroid': tSnareCentroid,
      't_hihat_zcr': tHihatZcr,
      'noise_floor_rms': noiseFloorRms,
    };
  }
}
