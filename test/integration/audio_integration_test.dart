import 'package:flutter_test/flutter_test.dart';
import 'package:beatbox_trainer/services/audio/audio_service_impl.dart';
import 'package:beatbox_trainer/services/error_handler/error_handler.dart';
import 'package:beatbox_trainer/services/error_handler/exceptions.dart';

/// Integration tests for AudioServiceImpl with real FFI bridge
///
/// These tests validate the full Dart service layer with the actual
/// Rust FFI bridge (not mocked), including:
/// - Audio lifecycle operations (start/stop)
/// - Error propagation across FFI boundary
/// - Service error translation from Rust errors
/// - Stream behavior with real bridge
///
/// Note: These tests run on non-Android platforms where the audio
/// engine returns HardwareError. This is expected and allows us to
/// test error propagation.
void main() {
  group('AudioServiceImpl Integration Tests', () {
    late AudioServiceImpl audioService;
    late ErrorHandler errorHandler;

    setUp(() {
      errorHandler = ErrorHandler();
      audioService = AudioServiceImpl(errorHandler: errorHandler);
    });

    group('Error propagation across FFI boundary', () {
      test('startAudio propagates errors from Rust on non-Android', () async {
        // On non-Android platforms, Rust returns HardwareError
        // Verify that this error is properly translated to AudioServiceException

        expect(
          () => audioService.startAudio(bpm: 120),
          throwsA(
            isA<AudioServiceException>().having(
              (e) => e.message,
              'message',
              isNotEmpty,
            ),
          ),
        );
      });

      test('stopAudio propagates errors from Rust on non-Android', () async {
        // On non-Android platforms, Rust returns HardwareError for stop
        // Verify that this error is properly translated

        expect(
          () => audioService.stopAudio(),
          throwsA(
            isA<AudioServiceException>().having(
              (e) => e.message,
              'message',
              isNotEmpty,
            ),
          ),
        );
      });

      test('setBpm propagates errors from Rust on non-Android', () async {
        // On non-Android platforms, Rust returns HardwareError for setBpm
        // Verify that this error is properly translated

        expect(
          () => audioService.setBpm(bpm: 140),
          throwsA(
            isA<AudioServiceException>().having(
              (e) => e.message,
              'message',
              isNotEmpty,
            ),
          ),
        );
      });
    });

    group('Service error translation', () {
      test(
        'Invalid BPM is caught by service validation before FFI call',
        () async {
          // Service should validate BPM before calling FFI
          // This tests that validation happens at the Dart level

          expect(
            () => audioService.startAudio(bpm: 0),
            throwsA(
              isA<AudioServiceException>()
                  .having(
                    (e) => e.message,
                    'message',
                    contains('between 40 and 240'),
                  )
                  .having((e) => e.errorCode, 'errorCode', equals(1001)),
            ),
          );
        },
      );

      test('BPM below minimum (40) throws AudioServiceException', () async {
        expect(
          () => audioService.startAudio(bpm: 39),
          throwsA(
            isA<AudioServiceException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('between 40 and 240'),
                )
                .having((e) => e.errorCode, 'errorCode', equals(1001)),
          ),
        );
      });

      test('BPM above maximum (240) throws AudioServiceException', () async {
        expect(
          () => audioService.startAudio(bpm: 241),
          throwsA(
            isA<AudioServiceException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('between 40 and 240'),
                )
                .having((e) => e.errorCode, 'errorCode', equals(1001)),
          ),
        );
      });

      test('setBpm validates BPM before FFI call', () async {
        expect(
          () => audioService.setBpm(bpm: 300),
          throwsA(
            isA<AudioServiceException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('between 40 and 240'),
                )
                .having((e) => e.errorCode, 'errorCode', equals(1001)),
          ),
        );
      });
    });

    group('Calibration error translation', () {
      test('finishCalibration without start propagates error', () async {
        // Try to finish calibration without starting it
        // Should get CalibrationServiceException

        expect(
          () => audioService.finishCalibration(),
          throwsA(
            isA<CalibrationServiceException>().having(
              (e) => e.message,
              'message',
              isNotEmpty,
            ),
          ),
        );
      });

      // Note: startCalibration may fail on non-Android due to hardware error
      // This is expected and doesn't indicate a test failure
    });

    group('Stream behavior with real bridge', () {
      test('getClassificationStream throws on non-Android', () async {
        // On non-Android, FFI calls fail with HardwareError
        // Stream creation will throw an AudioServiceException
        expect(
          () => audioService.getClassificationStream(),
          throwsA(isA<AudioServiceException>()),
        );
      });

      test('getCalibrationStream throws on non-Android', () async {
        // On non-Android, FFI calls fail
        // Stream creation will throw an exception
        expect(
          () => audioService.getCalibrationStream(),
          throwsA(isA<CalibrationServiceException>()),
        );
      });
    });

    group('Full audio lifecycle integration', () {
      test(
        'Audio lifecycle follows expected error patterns on non-Android',
        () async {
          // This test verifies the full lifecycle on non-Android platforms
          // where we expect HardwareError at each step

          // 1. Start audio - expect HardwareError
          expect(
            () => audioService.startAudio(bpm: 120),
            throwsA(isA<AudioServiceException>()),
          );

          // 2. Try to get classification stream - expect NotRunning or HardwareError
          expect(
            () => audioService.getClassificationStream(),
            throwsA(isA<AudioServiceException>()),
          );

          // 3. Stop audio - expect HardwareError on non-Android
          expect(
            () => audioService.stopAudio(),
            throwsA(isA<AudioServiceException>()),
          );
        },
      );
    });

    group('Calibration workflow integration', () {
      test('Calibration error handling', () async {
        // On non-Android, calibration operations may fail with hardware errors
        // Test that errors are properly caught and wrapped in CalibrationServiceException

        // Try to finish calibration without starting - should fail
        expect(
          () => audioService.finishCalibration(),
          throwsA(
            isA<CalibrationServiceException>().having(
              (e) => e.message,
              'message',
              isNotEmpty,
            ),
          ),
        );
      });
    });

    group('Error message quality', () {
      test('AudioServiceException messages are user-friendly', () async {
        try {
          await audioService.startAudio(bpm: 0);
          fail('Should have thrown AudioServiceException');
        } catch (e) {
          expect(e, isA<AudioServiceException>());
          final exception = e as AudioServiceException;

          // Message should be user-friendly (not technical)
          expect(exception.message, isNotEmpty);
          expect(exception.message, isNot(contains('panic')));
          expect(exception.message, isNot(contains('unwrap')));

          // Should have error code
          expect(exception.errorCode, isNotNull);
          expect(exception.errorCode, equals(1001));
        }
      });

      test('CalibrationServiceException messages are user-friendly', () async {
        try {
          await audioService.finishCalibration();
          fail('Should have thrown CalibrationServiceException');
        } catch (e) {
          expect(e, isA<CalibrationServiceException>());
          final exception = e as CalibrationServiceException;

          // Message should be user-friendly
          expect(exception.message, isNotEmpty);
          expect(exception.message, isNot(contains('panic')));
          expect(exception.message, isNot(contains('unwrap')));

          // Error code may be null if Rust doesn't provide it in the expected format
          // That's okay - we're mainly testing that the message is user-friendly
        }
      });
    });
  });
}
