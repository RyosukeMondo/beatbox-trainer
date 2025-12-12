import 'package:beatbox_trainer/services/storage/i_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalibrationData.toRustState', () {
    test(
      'marks persisted calibration as calibrated and flattens thresholds',
      () {
        final data = CalibrationData(
          level: 2,
          timestamp: DateTime.parse('2025-11-15T12:34:56.000Z'),
          thresholds: {
            't_kick_centroid': 2100.0,
            't_kick_zcr': 0.12,
            't_snare_centroid': 5200.0,
            't_hihat_zcr': 0.28,
          },
        );

        final rustState = data.toRustState();

        expect(rustState.level, equals(2));
        expect(rustState.tKickCentroid, equals(2100.0));
        expect(rustState.tKickZcr, equals(0.12));
        expect(rustState.tSnareCentroid, equals(5200.0));
        expect(rustState.tHihatZcr, equals(0.28));
        expect(rustState.isCalibrated, isTrue);
      },
    );

    test('falls back to default thresholds when missing from map', () {
      final data = CalibrationData(
        level: 1,
        timestamp: DateTime.parse('2025-11-15T00:00:00.000Z'),
        thresholds: const <String, double>{},
      );

      final rustState = data.toRustState();

      expect(rustState.tKickCentroid, equals(1500.0));
      expect(rustState.tKickZcr, equals(0.1));
      expect(rustState.tSnareCentroid, equals(4000.0));
      expect(rustState.tHihatZcr, equals(0.3));
      expect(rustState.isCalibrated, isTrue);
    });
  });
}
