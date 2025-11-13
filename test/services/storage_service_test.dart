import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beatbox_trainer/services/storage/storage_service_impl.dart';
import 'package:beatbox_trainer/services/storage/i_storage_service.dart';

void main() {
  group('StorageServiceImpl', () {
    late StorageServiceImpl storageService;

    setUp(() {
      // Reset SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      storageService = StorageServiceImpl();
    });

    group('initialization', () {
      test('init() completes successfully with empty storage', () async {
        await storageService.init();
        // No exception means success
      });

      test('init() can be called multiple times without error', () async {
        await storageService.init();
        await storageService.init();
        // Should not throw
      });

      test('throws StorageException if methods called before init()', () async {
        // Don't call init()
        expect(
          () => storageService.hasCalibration(),
          throwsA(
            isA<StorageException>().having(
              (e) => e.message,
              'message',
              contains('not initialized'),
            ),
          ),
        );
      });

      test('saveCalibration throws if not initialized', () async {
        final testData = CalibrationData(
          level: 1,
          timestamp: DateTime.now(),
          thresholds: {'kick': 0.5},
        );

        expect(
          () => storageService.saveCalibration(testData),
          throwsA(
            isA<StorageException>().having(
              (e) => e.message,
              'message',
              contains('not initialized'),
            ),
          ),
        );
      });

      test('loadCalibration throws if not initialized', () async {
        expect(
          () => storageService.loadCalibration(),
          throwsA(
            isA<StorageException>().having(
              (e) => e.message,
              'message',
              contains('not initialized'),
            ),
          ),
        );
      });

      test('clearCalibration throws if not initialized', () async {
        expect(
          () => storageService.clearCalibration(),
          throwsA(
            isA<StorageException>().having(
              (e) => e.message,
              'message',
              contains('not initialized'),
            ),
          ),
        );
      });
    });

    group('hasCalibration', () {
      test('returns false when no calibration data exists', () async {
        await storageService.init();
        final hasCalib = await storageService.hasCalibration();
        expect(hasCalib, false);
      });

      test('returns true after calibration is saved', () async {
        await storageService.init();

        final testData = CalibrationData(
          level: 1,
          timestamp: DateTime.now(),
          thresholds: {'kick': 0.5, 'snare': 0.6},
        );

        await storageService.saveCalibration(testData);

        final hasCalib = await storageService.hasCalibration();
        expect(hasCalib, true);
      });

      test('returns false after calibration is cleared', () async {
        await storageService.init();

        final testData = CalibrationData(
          level: 1,
          timestamp: DateTime.now(),
          thresholds: {'kick': 0.5},
        );

        await storageService.saveCalibration(testData);
        await storageService.clearCalibration();

        final hasCalib = await storageService.hasCalibration();
        expect(hasCalib, false);
      });

      test('returns false and clears flag when data is corrupted', () async {
        SharedPreferences.setMockInitialValues({
          'has_calibration': true,
          'calibration_data': 'invalid json {]',
        });

        await storageService.init();

        final hasCalib = await storageService.hasCalibration();
        expect(hasCalib, false);

        // Flag should be cleared after detecting corrupted data
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('has_calibration'), false);
      });

      test('returns false when flag is true but data is missing', () async {
        SharedPreferences.setMockInitialValues({
          'has_calibration': true,
          // No 'calibration_data' key
        });

        await storageService.init();

        final hasCalib = await storageService.hasCalibration();
        expect(hasCalib, false);
      });

      test('returns false when data is empty string', () async {
        SharedPreferences.setMockInitialValues({
          'has_calibration': true,
          'calibration_data': '',
        });

        await storageService.init();

        final hasCalib = await storageService.hasCalibration();
        expect(hasCalib, false);
      });
    });

    group('saveCalibration and loadCalibration', () {
      test('round-trip save and load preserves all data', () async {
        await storageService.init();

        final timestamp = DateTime.now();
        final testData = CalibrationData(
          level: 2,
          timestamp: timestamp,
          thresholds: {
            'kick': 0.5,
            'snare': 0.6,
            'closed_hihat': 0.7,
            'open_hihat': 0.8,
          },
        );

        await storageService.saveCalibration(testData);
        final loadedData = await storageService.loadCalibration();

        expect(loadedData, isNotNull);
        expect(loadedData!.level, testData.level);
        expect(
          loadedData.timestamp.toIso8601String(),
          timestamp.toIso8601String(),
        );
        expect(loadedData.thresholds, testData.thresholds);
      });

      test('loadCalibration returns null when no data exists', () async {
        await storageService.init();

        final loadedData = await storageService.loadCalibration();
        expect(loadedData, isNull);
      });

      test('loadCalibration returns null when data is empty string', () async {
        SharedPreferences.setMockInitialValues({'calibration_data': ''});

        await storageService.init();

        final loadedData = await storageService.loadCalibration();
        expect(loadedData, isNull);
      });

      test('saveCalibration overwrites previous data', () async {
        await storageService.init();

        final firstData = CalibrationData(
          level: 1,
          timestamp: DateTime.now(),
          thresholds: {'kick': 0.5},
        );

        final secondData = CalibrationData(
          level: 2,
          timestamp: DateTime.now(),
          thresholds: {'kick': 0.8},
        );

        await storageService.saveCalibration(firstData);
        await storageService.saveCalibration(secondData);

        final loadedData = await storageService.loadCalibration();
        expect(loadedData!.level, 2);
        expect(loadedData.thresholds['kick'], 0.8);
      });

      test('saveCalibration sets has_calibration flag to true', () async {
        await storageService.init();

        final testData = CalibrationData(
          level: 1,
          timestamp: DateTime.now(),
          thresholds: {'kick': 0.5},
        );

        await storageService.saveCalibration(testData);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('has_calibration'), true);
      });

      test('saveCalibration with empty thresholds works', () async {
        await storageService.init();

        final testData = CalibrationData(
          level: 1,
          timestamp: DateTime.now(),
          thresholds: {},
        );

        await storageService.saveCalibration(testData);
        final loadedData = await storageService.loadCalibration();

        expect(loadedData!.thresholds, isEmpty);
      });
    });

    group('clearCalibration', () {
      test('removes calibration data from storage', () async {
        await storageService.init();

        final testData = CalibrationData(
          level: 1,
          timestamp: DateTime.now(),
          thresholds: {'kick': 0.5},
        );

        await storageService.saveCalibration(testData);
        await storageService.clearCalibration();

        final loadedData = await storageService.loadCalibration();
        expect(loadedData, isNull);
      });

      test('sets has_calibration flag to false', () async {
        await storageService.init();

        final testData = CalibrationData(
          level: 1,
          timestamp: DateTime.now(),
          thresholds: {'kick': 0.5},
        );

        await storageService.saveCalibration(testData);
        await storageService.clearCalibration();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('has_calibration'), false);
      });

      test('can be called when no data exists without error', () async {
        await storageService.init();

        // Should not throw
        await storageService.clearCalibration();

        final hasCalib = await storageService.hasCalibration();
        expect(hasCalib, false);
      });

      test('can be called multiple times without error', () async {
        await storageService.init();

        final testData = CalibrationData(
          level: 1,
          timestamp: DateTime.now(),
          thresholds: {'kick': 0.5},
        );

        await storageService.saveCalibration(testData);
        await storageService.clearCalibration();
        await storageService.clearCalibration();

        final hasCalib = await storageService.hasCalibration();
        expect(hasCalib, false);
      });
    });

    group('JSON error handling', () {
      test(
        'loadCalibration throws StorageException for invalid JSON',
        () async {
          SharedPreferences.setMockInitialValues({
            'calibration_data': 'not valid json {]',
          });

          await storageService.init();

          expect(
            () => storageService.loadCalibration(),
            throwsA(
              isA<StorageException>().having(
                (e) => e.message,
                'message',
                contains('parse'),
              ),
            ),
          );
        },
      );

      test(
        'loadCalibration throws StorageException for JSON with missing fields',
        () async {
          SharedPreferences.setMockInitialValues({
            'calibration_data':
                '{"level": 1}', // Missing timestamp and thresholds
          });

          await storageService.init();

          expect(
            () => storageService.loadCalibration(),
            throwsA(
              isA<StorageException>().having(
                (e) => e.message,
                'message',
                contains('Failed to load calibration data'),
              ),
            ),
          );
        },
      );

      test(
        'loadCalibration throws StorageException for JSON with wrong types',
        () async {
          SharedPreferences.setMockInitialValues({
            'calibration_data':
                '{"level": "one", "timestamp": "2025-11-13T12:00:00.000", "thresholds": {}}',
          });

          await storageService.init();

          expect(
            () => storageService.loadCalibration(),
            throwsA(
              isA<StorageException>().having(
                (e) => e.message,
                'message',
                contains('Failed to load calibration data'),
              ),
            ),
          );
        },
      );

      test(
        'loadCalibration throws StorageException for invalid timestamp',
        () async {
          SharedPreferences.setMockInitialValues({
            'calibration_data':
                '{"level": 1, "timestamp": "not a timestamp", "thresholds": {}}',
          });

          await storageService.init();

          expect(
            () => storageService.loadCalibration(),
            throwsA(
              isA<StorageException>().having(
                (e) => e.message,
                'message',
                contains('parse'),
              ),
            ),
          );
        },
      );
    });

    group('CalibrationData', () {
      test('toJson produces valid JSON structure', () {
        final timestamp = DateTime.parse('2025-11-13T12:00:00.000');
        final data = CalibrationData(
          level: 1,
          timestamp: timestamp,
          thresholds: {'kick': 0.5, 'snare': 0.6},
        );

        final json = data.toJson();

        expect(json['level'], 1);
        expect(json['timestamp'], '2025-11-13T12:00:00.000');
        expect(json['thresholds'], {'kick': 0.5, 'snare': 0.6});
      });

      test('fromJson creates CalibrationData from valid JSON', () {
        final json = {
          'level': 2,
          'timestamp': '2025-11-13T12:00:00.000',
          'thresholds': {'kick': 0.7, 'snare': 0.8},
        };

        final data = CalibrationData.fromJson(json);

        expect(data.level, 2);
        expect(data.timestamp.toIso8601String(), '2025-11-13T12:00:00.000');
        expect(data.thresholds, {'kick': 0.7, 'snare': 0.8});
      });

      test('fromJson and toJson round-trip correctly', () {
        final original = CalibrationData(
          level: 1,
          timestamp: DateTime.parse('2025-11-13T12:00:00.000'),
          thresholds: {'kick': 0.5},
        );

        final json = original.toJson();
        final reconstructed = CalibrationData.fromJson(json);

        expect(reconstructed.level, original.level);
        expect(
          reconstructed.timestamp.toIso8601String(),
          original.timestamp.toIso8601String(),
        );
        expect(reconstructed.thresholds, original.thresholds);
      });
    });

    group('StorageException', () {
      test('toString includes message', () {
        final exception = StorageException('Test error');
        expect(exception.toString(), contains('Test error'));
      });

      test('toString includes cause when provided', () {
        final cause = Exception('Root cause');
        final exception = StorageException('Test error', cause);
        expect(exception.toString(), contains('Test error'));
        expect(exception.toString(), contains('cause:'));
      });

      test('toString does not include cause when not provided', () {
        final exception = StorageException('Test error');
        expect(exception.toString(), isNot(contains('cause:')));
      });
    });
  });
}
