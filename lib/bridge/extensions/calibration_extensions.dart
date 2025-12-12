import '../api.dart/calibration/state.dart';

extension CalibrationStateJson on CalibrationState {
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
}
