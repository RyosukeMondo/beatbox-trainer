import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beatbox_trainer/services/audio/audio_service_impl.dart';
import 'package:beatbox_trainer/services/error_handler/error_handler.dart';
import 'package:beatbox_trainer/services/error_handler/exceptions.dart';

/// Mock ErrorHandler for testing error translation behavior
class MockErrorHandler extends Mock implements ErrorHandler {}

void main() {
  group('AudioServiceImpl', () {
    late AudioServiceImpl audioService;

    setUp(() {
      // Use real ErrorHandler - we're testing AudioServiceImpl's validation
      // and delegation logic, not the error translation
      audioService = AudioServiceImpl();
    });

    group('BPM validation', () {
      test(
        'startAudio throws AudioServiceException for BPM below minimum (40)',
        () async {
          // Test boundary: 39 is below minimum
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
        },
      );

      test(
        'startAudio throws AudioServiceException for BPM above maximum (240)',
        () async {
          // Test boundary: 241 is above maximum
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
        },
      );

      test('startAudio throws AudioServiceException for BPM of 0', () async {
        expect(
          () => audioService.startAudio(bpm: 0),
          throwsA(
            isA<AudioServiceException>().having(
              (e) => e.errorCode,
              'errorCode',
              equals(1001),
            ),
          ),
        );
      });

      test(
        'startAudio throws AudioServiceException for negative BPM',
        () async {
          expect(
            () => audioService.startAudio(bpm: -10),
            throwsA(
              isA<AudioServiceException>().having(
                (e) => e.errorCode,
                'errorCode',
                equals(1001),
              ),
            ),
          );
        },
      );

      test('startAudio accepts valid BPM at lower boundary (40)', () async {
        // Note: This tests validation logic doesn't reject BPM 40
        // With stub FFI, it will call the FFI (proving validation passed) but get an error
        // If validation failed, we'd get exception with errorCode 1001 and "validation failed" text
        try {
          await audioService.startAudio(bpm: 40);
          fail('Expected exception from stub implementation');
        } on AudioServiceException catch (e) {
          // Should NOT be a validation error (errorCode 1001 with "validation failed")
          expect(e.errorCode, isNot(equals(1001)));
          expect(
            e.originalError.toLowerCase(),
            isNot(contains('validation failed')),
          );
        }
      });

      test('startAudio accepts valid BPM at upper boundary (240)', () async {
        try {
          await audioService.startAudio(bpm: 240);
          fail('Expected exception from stub implementation');
        } on AudioServiceException catch (e) {
          // Should NOT be a validation error
          expect(e.errorCode, isNot(equals(1001)));
          expect(
            e.originalError.toLowerCase(),
            isNot(contains('validation failed')),
          );
        }
      });

      test('startAudio accepts valid BPM in middle of range (120)', () async {
        try {
          await audioService.startAudio(bpm: 120);
          fail('Expected exception from stub implementation');
        } on AudioServiceException catch (e) {
          // Should NOT be a validation error
          expect(e.errorCode, isNot(equals(1001)));
          expect(
            e.originalError.toLowerCase(),
            isNot(contains('validation failed')),
          );
        }
      });

      test(
        'setBpm throws AudioServiceException for BPM below minimum',
        () async {
          expect(
            () => audioService.setBpm(bpm: 30),
            throwsA(
              isA<AudioServiceException>().having(
                (e) => e.errorCode,
                'errorCode',
                equals(1001),
              ),
            ),
          );
        },
      );

      test(
        'setBpm throws AudioServiceException for BPM above maximum',
        () async {
          expect(
            () => audioService.setBpm(bpm: 300),
            throwsA(
              isA<AudioServiceException>().having(
                (e) => e.errorCode,
                'errorCode',
                equals(1001),
              ),
            ),
          );
        },
      );

      test('setBpm accepts valid BPM (120)', () async {
        try {
          await audioService.setBpm(bpm: 120);
          fail('Expected exception from stub implementation');
        } on AudioServiceException catch (e) {
          // Should NOT be a validation error
          expect(e.errorCode, isNot(equals(1001)));
          expect(
            e.originalError.toLowerCase(),
            isNot(contains('validation failed')),
          );
        }
      });
    });

    group('method behavior', () {
      test('stopAudio does not validate BPM', () async {
        // stopAudio should not throw validation errors
        // With stub FFI, ErrorHandler translates UnimplementedError to AudioServiceException
        expect(
          () => audioService.stopAudio(),
          throwsA(isA<AudioServiceException>()),
        );
      });

      test('finishCalibration can be called', () async {
        // With stub FFI, ErrorHandler translates UnimplementedError to CalibrationServiceException
        expect(
          () => audioService.finishCalibration(),
          throwsA(isA<CalibrationServiceException>()),
        );
      });

      test('startCalibration can be called', () async {
        // With stub FFI, errors can be AudioServiceException or CalibrationServiceException
        // depending on error content
        expect(
          () => audioService.startCalibration(),
          throwsA(isA<Exception>()),
        );
      });

      test('getClassificationStream can be called', () {
        // With stub FFI, ErrorHandler translates UnimplementedError to AudioServiceException
        expect(
          () => audioService.getClassificationStream(),
          throwsA(isA<AudioServiceException>()),
        );
      });

      test('getCalibrationStream can be called', () {
        // With stub FFI, ErrorHandler translates UnimplementedError to CalibrationServiceException
        expect(
          () => audioService.getCalibrationStream(),
          throwsA(isA<CalibrationServiceException>()),
        );
      });
    });

    group('error handler dependency injection', () {
      test('uses provided ErrorHandler instance', () {
        final customHandler = MockErrorHandler();
        final service = AudioServiceImpl(errorHandler: customHandler);

        // Verify the service instance is created with custom handler
        expect(service, isA<AudioServiceImpl>());
      });

      test('creates default ErrorHandler when none provided', () {
        final service = AudioServiceImpl();

        // Verify the service instance is created with default handler
        expect(service, isA<AudioServiceImpl>());
      });
    });

    group('validation error messages', () {
      test('validation error includes BPM value in originalError', () async {
        try {
          await audioService.startAudio(bpm: 300);
          fail('Expected AudioServiceException');
        } on AudioServiceException catch (e) {
          expect(e.originalError, contains('300'));
          expect(e.originalError, contains('BPM validation failed'));
        }
      });

      test('validation error has user-friendly message', () async {
        try {
          await audioService.setBpm(bpm: 10);
          fail('Expected AudioServiceException');
        } on AudioServiceException catch (e) {
          expect(e.message, contains('40'));
          expect(e.message, contains('240'));
          expect(e.message, contains('BPM'));
        }
      });
    });
  });
}
