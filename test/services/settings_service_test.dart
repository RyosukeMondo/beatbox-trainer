import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beatbox_trainer/services/settings/settings_service_impl.dart';

void main() {
  group('SettingsServiceImpl', () {
    late SettingsServiceImpl settingsService;

    setUp(() {
      // Reset SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      settingsService = SettingsServiceImpl();
    });

    group('initialization', () {
      test('init() completes successfully with empty storage', () async {
        await settingsService.init();
        // No exception means success
      });

      test('init() can be called multiple times without error', () async {
        await settingsService.init();
        await settingsService.init();
        // Should not throw
      });

      test('throws SettingsException if getBpm called before init()', () async {
        // Don't call init()
        expect(
          () => settingsService.getBpm(),
          throwsA(
            isA<SettingsException>().having(
              (e) => e.message,
              'message',
              contains('not initialized'),
            ),
          ),
        );
      });

      test('throws SettingsException if setBpm called before init()', () async {
        expect(
          () => settingsService.setBpm(120),
          throwsA(
            isA<SettingsException>().having(
              (e) => e.message,
              'message',
              contains('not initialized'),
            ),
          ),
        );
      });

      test(
        'throws SettingsException if getDebugMode called before init()',
        () async {
          expect(
            () => settingsService.getDebugMode(),
            throwsA(
              isA<SettingsException>().having(
                (e) => e.message,
                'message',
                contains('not initialized'),
              ),
            ),
          );
        },
      );

      test(
        'throws SettingsException if setDebugMode called before init()',
        () async {
          expect(
            () => settingsService.setDebugMode(true),
            throwsA(
              isA<SettingsException>().having(
                (e) => e.message,
                'message',
                contains('not initialized'),
              ),
            ),
          );
        },
      );

      test(
        'throws SettingsException if getClassifierLevel called before init()',
        () async {
          expect(
            () => settingsService.getClassifierLevel(),
            throwsA(
              isA<SettingsException>().having(
                (e) => e.message,
                'message',
                contains('not initialized'),
              ),
            ),
          );
        },
      );

      test(
        'throws SettingsException if setClassifierLevel called before init()',
        () async {
          expect(
            () => settingsService.setClassifierLevel(2),
            throwsA(
              isA<SettingsException>().having(
                (e) => e.message,
                'message',
                contains('not initialized'),
              ),
            ),
          );
        },
      );
    });

    group('BPM settings', () {
      test('getBpm returns default value (120) when no data stored', () async {
        await settingsService.init();
        final bpm = await settingsService.getBpm();
        expect(bpm, 120);
      });

      test('getBpm returns stored value after setBpm', () async {
        await settingsService.init();

        await settingsService.setBpm(150);
        final bpm = await settingsService.getBpm();

        expect(bpm, 150);
      });

      test('setBpm persists value across service instances', () async {
        await settingsService.init();
        await settingsService.setBpm(180);

        // Create new service instance
        final newService = SettingsServiceImpl();
        await newService.init();

        final bpm = await newService.getBpm();
        expect(bpm, 180);
      });

      test('setBpm overwrites previous value', () async {
        await settingsService.init();

        await settingsService.setBpm(100);
        await settingsService.setBpm(200);

        final bpm = await settingsService.getBpm();
        expect(bpm, 200);
      });

      test(
        'getBpm returns default when stored value is below minimum',
        () async {
          // Pre-populate with invalid value
          SharedPreferences.setMockInitialValues({'default_bpm': 30});

          await settingsService.init();
          final bpm = await settingsService.getBpm();

          expect(bpm, 120); // Should return default instead of invalid value
        },
      );

      test(
        'getBpm returns default when stored value is above maximum',
        () async {
          // Pre-populate with invalid value
          SharedPreferences.setMockInitialValues({'default_bpm': 300});

          await settingsService.init();
          final bpm = await settingsService.getBpm();

          expect(bpm, 120); // Should return default instead of invalid value
        },
      );

      test(
        'setBpm throws ArgumentError for value below minimum (40)',
        () async {
          await settingsService.init();

          expect(
            () => settingsService.setBpm(39),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                contains('between 40 and 240'),
              ),
            ),
          );
        },
      );

      test(
        'setBpm throws ArgumentError for value above maximum (240)',
        () async {
          await settingsService.init();

          expect(
            () => settingsService.setBpm(241),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                contains('between 40 and 240'),
              ),
            ),
          );
        },
      );

      test('setBpm accepts minimum value (40)', () async {
        await settingsService.init();

        await settingsService.setBpm(40);
        final bpm = await settingsService.getBpm();

        expect(bpm, 40);
      });

      test('setBpm accepts maximum value (240)', () async {
        await settingsService.init();

        await settingsService.setBpm(240);
        final bpm = await settingsService.getBpm();

        expect(bpm, 240);
      });

      test('setBpm accepts value in valid range', () async {
        await settingsService.init();

        await settingsService.setBpm(120);
        final bpm = await settingsService.getBpm();

        expect(bpm, 120);
      });
    });

    group('Debug mode settings', () {
      test(
        'getDebugMode returns default value (false) when no data stored',
        () async {
          await settingsService.init();
          final debugMode = await settingsService.getDebugMode();
          expect(debugMode, false);
        },
      );

      test('getDebugMode returns true after setDebugMode(true)', () async {
        await settingsService.init();

        await settingsService.setDebugMode(true);
        final debugMode = await settingsService.getDebugMode();

        expect(debugMode, true);
      });

      test('getDebugMode returns false after setDebugMode(false)', () async {
        await settingsService.init();

        await settingsService.setDebugMode(true);
        await settingsService.setDebugMode(false);
        final debugMode = await settingsService.getDebugMode();

        expect(debugMode, false);
      });

      test('setDebugMode persists value across service instances', () async {
        await settingsService.init();
        await settingsService.setDebugMode(true);

        // Create new service instance
        final newService = SettingsServiceImpl();
        await newService.init();

        final debugMode = await newService.getDebugMode();
        expect(debugMode, true);
      });

      test('setDebugMode can toggle between true and false', () async {
        await settingsService.init();

        await settingsService.setDebugMode(true);
        expect(await settingsService.getDebugMode(), true);

        await settingsService.setDebugMode(false);
        expect(await settingsService.getDebugMode(), false);

        await settingsService.setDebugMode(true);
        expect(await settingsService.getDebugMode(), true);
      });
    });

    group('Classifier level settings', () {
      test(
        'getClassifierLevel returns default value (1) when no data stored',
        () async {
          await settingsService.init();
          final level = await settingsService.getClassifierLevel();
          expect(level, 1);
        },
      );

      test(
        'getClassifierLevel returns stored value after setClassifierLevel',
        () async {
          await settingsService.init();

          await settingsService.setClassifierLevel(2);
          final level = await settingsService.getClassifierLevel();

          expect(level, 2);
        },
      );

      test(
        'setClassifierLevel persists value across service instances',
        () async {
          await settingsService.init();
          await settingsService.setClassifierLevel(2);

          // Create new service instance
          final newService = SettingsServiceImpl();
          await newService.init();

          final level = await newService.getClassifierLevel();
          expect(level, 2);
        },
      );

      test('setClassifierLevel can switch between levels', () async {
        await settingsService.init();

        await settingsService.setClassifierLevel(2);
        expect(await settingsService.getClassifierLevel(), 2);

        await settingsService.setClassifierLevel(1);
        expect(await settingsService.getClassifierLevel(), 1);

        await settingsService.setClassifierLevel(2);
        expect(await settingsService.getClassifierLevel(), 2);
      });

      test(
        'getClassifierLevel returns default when stored value is below minimum',
        () async {
          // Pre-populate with invalid value
          SharedPreferences.setMockInitialValues({'classifier_level': 0});

          await settingsService.init();
          final level = await settingsService.getClassifierLevel();

          expect(level, 1); // Should return default instead of invalid value
        },
      );

      test(
        'getClassifierLevel returns default when stored value is above maximum',
        () async {
          // Pre-populate with invalid value
          SharedPreferences.setMockInitialValues({'classifier_level': 3});

          await settingsService.init();
          final level = await settingsService.getClassifierLevel();

          expect(level, 1); // Should return default instead of invalid value
        },
      );

      test(
        'setClassifierLevel throws ArgumentError for value below minimum (1)',
        () async {
          await settingsService.init();

          expect(
            () => settingsService.setClassifierLevel(0),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                contains('between 1 and 2'),
              ),
            ),
          );
        },
      );

      test(
        'setClassifierLevel throws ArgumentError for value above maximum (2)',
        () async {
          await settingsService.init();

          expect(
            () => settingsService.setClassifierLevel(3),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                contains('between 1 and 2'),
              ),
            ),
          );
        },
      );

      test('setClassifierLevel accepts minimum value (1)', () async {
        await settingsService.init();

        await settingsService.setClassifierLevel(1);
        final level = await settingsService.getClassifierLevel();

        expect(level, 1);
      });

      test('setClassifierLevel accepts maximum value (2)', () async {
        await settingsService.init();

        await settingsService.setClassifierLevel(2);
        final level = await settingsService.getClassifierLevel();

        expect(level, 2);
      });
    });

    group('Multiple settings interaction', () {
      test('all settings can be set and retrieved independently', () async {
        await settingsService.init();

        // Set all settings
        await settingsService.setBpm(180);
        await settingsService.setDebugMode(true);
        await settingsService.setClassifierLevel(2);

        // Verify all settings
        expect(await settingsService.getBpm(), 180);
        expect(await settingsService.getDebugMode(), true);
        expect(await settingsService.getClassifierLevel(), 2);
      });

      test('changing one setting does not affect others', () async {
        await settingsService.init();

        // Set initial values
        await settingsService.setBpm(100);
        await settingsService.setDebugMode(true);
        await settingsService.setClassifierLevel(2);

        // Change only BPM
        await settingsService.setBpm(200);

        // Verify others unchanged
        expect(await settingsService.getDebugMode(), true);
        expect(await settingsService.getClassifierLevel(), 2);
      });

      test('all settings persist across service instances', () async {
        await settingsService.init();

        // Set all settings
        await settingsService.setBpm(150);
        await settingsService.setDebugMode(true);
        await settingsService.setClassifierLevel(2);

        // Create new service instance
        final newService = SettingsServiceImpl();
        await newService.init();

        // Verify all settings persisted
        expect(await newService.getBpm(), 150);
        expect(await newService.getDebugMode(), true);
        expect(await newService.getClassifierLevel(), 2);
      });
    });

    group('SettingsException', () {
      test('toString includes message', () {
        final exception = SettingsException('Test error');
        expect(exception.toString(), contains('Test error'));
      });

      test('toString includes cause when provided', () {
        final cause = Exception('Root cause');
        final exception = SettingsException('Test error', cause);
        expect(exception.toString(), contains('Test error'));
        expect(exception.toString(), contains('caused by:'));
      });

      test('toString does not include cause when not provided', () {
        final exception = SettingsException('Test error');
        expect(exception.toString(), isNot(contains('cause:')));
      });
    });
  });
}
