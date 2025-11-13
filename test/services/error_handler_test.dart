import 'package:flutter_test/flutter_test.dart';
import 'package:beatbox_trainer/services/error_handler/error_handler.dart';
import 'package:beatbox_trainer/services/error_handler/exceptions.dart';

void main() {
  group('ErrorHandler', () {
    late ErrorHandler errorHandler;

    setUp(() {
      errorHandler = ErrorHandler();
    });

    group('translateAudioError', () {
      test('translates BpmInvalid error (code 1001)', () {
        const rustError =
            'AudioError::BpmInvalid { bpm: 0 } (code 1001): BPM must be greater than 0 (got 0)';
        final result = errorHandler.translateAudioError(rustError);

        expect(result, 'Please choose a tempo between 40 and 240 BPM.');
      });

      test('translates AlreadyRunning error (code 1002)', () {
        const rustError =
            'AudioError::AlreadyRunning (code 1002): Audio engine already running. Call stop_audio() first.';
        final result = errorHandler.translateAudioError(rustError);

        expect(result, 'Audio is already active. Please stop it first.');
      });

      test('translates NotRunning error (code 1003)', () {
        const rustError =
            'AudioError::NotRunning (code 1003): Audio engine not running. Call start_audio() first.';
        final result = errorHandler.translateAudioError(rustError);

        expect(result, 'Audio engine is not running. Please start it first.');
      });

      test('translates HardwareError (code 1004)', () {
        const rustError =
            'AudioError::HardwareError { details: "Device not found" } (code 1004): Hardware error: Device not found';
        final result = errorHandler.translateAudioError(rustError);

        expect(
          result,
          'Audio hardware error occurred. Please check your device settings.',
        );
      });

      test('translates PermissionDenied error (code 1005)', () {
        const rustError =
            'AudioError::PermissionDenied (code 1005): Microphone permission denied';
        final result = errorHandler.translateAudioError(rustError);

        expect(
          result,
          'Microphone access required. Please enable in settings.',
        );
      });

      test('translates StreamOpenFailed error (code 1006)', () {
        const rustError =
            'AudioError::StreamOpenFailed { reason: "Device busy" } (code 1006): Failed to open audio stream: Device busy';
        final result = errorHandler.translateAudioError(rustError);

        expect(
          result,
          'Unable to access audio hardware. Please check if another app is using the microphone.',
        );
      });

      test('translates LockPoisoned error (code 1007)', () {
        const rustError =
            'AudioError::LockPoisoned { component: "AudioEngine" } (code 1007): Lock poisoned for component: AudioEngine';
        final result = errorHandler.translateAudioError(rustError);

        expect(result, 'Internal error occurred. Please restart the app.');
      });

      test('handles error without code using pattern matching - bpm', () {
        const rustError = 'BPM invalid: value out of range';
        final result = errorHandler.translateAudioError(rustError);

        expect(result, 'Please choose a tempo between 40 and 240 BPM.');
      });

      test(
        'handles error without code using pattern matching - already running',
        () {
          const rustError = 'already running';
          final result = errorHandler.translateAudioError(rustError);

          expect(result, 'Audio is already active. Please stop it first.');
        },
      );

      test(
        'handles error without code using pattern matching - permission',
        () {
          const rustError = 'permission denied by user';
          final result = errorHandler.translateAudioError(rustError);

          expect(
            result,
            'Microphone access required. Please enable in settings.',
          );
        },
      );

      test('returns generic message for unknown error', () {
        const rustError = 'Some completely unknown error';
        final result = errorHandler.translateAudioError(rustError);

        expect(result, 'Audio engine error occurred. Please try restarting.');
      });
    });

    group('translateCalibrationError', () {
      test('translates InsufficientSamples error (code 2001)', () {
        const rustError =
            'CalibrationError::InsufficientSamples { required: 10, collected: 5 } (code 2001): Insufficient samples: need 10, got 5';
        final result = errorHandler.translateCalibrationError(rustError);

        expect(
          result,
          'Not enough samples collected. Please continue making sounds.',
        );
      });

      test('translates InvalidFeatures error (code 2002)', () {
        const rustError =
            'CalibrationError::InvalidFeatures { reason: "Too quiet" } (code 2002): Invalid features: Too quiet';
        final result = errorHandler.translateCalibrationError(rustError);

        expect(
          result,
          'Sound quality too low. Please speak louder or move closer to the microphone.',
        );
      });

      test('translates NotComplete error (code 2003)', () {
        const rustError =
            'CalibrationError::NotComplete (code 2003): Calibration not complete';
        final result = errorHandler.translateCalibrationError(rustError);

        expect(result, 'Calibration not finished. Please complete all steps.');
      });

      test('translates AlreadyInProgress error (code 2004)', () {
        const rustError =
            'CalibrationError::AlreadyInProgress (code 2004): Calibration already in progress';
        final result = errorHandler.translateCalibrationError(rustError);

        expect(
          result,
          'Calibration is already in progress. Please finish or cancel it first.',
        );
      });

      test('translates StatePoisoned error (code 2005)', () {
        const rustError =
            'CalibrationError::StatePoisoned (code 2005): Calibration state lock poisoned';
        final result = errorHandler.translateCalibrationError(rustError);

        expect(result, 'Internal error occurred. Please restart the app.');
      });

      test(
        'handles error without code using pattern matching - insufficient',
        () {
          const rustError = 'Insufficient samples collected';
          final result = errorHandler.translateCalibrationError(rustError);

          expect(
            result,
            'Not enough samples collected. Please continue making sounds.',
          );
        },
      );

      test(
        'handles error without code using pattern matching - invalid features',
        () {
          const rustError = 'Invalid features detected';
          final result = errorHandler.translateCalibrationError(rustError);

          expect(
            result,
            'Sound quality too low. Please speak louder or move closer to the microphone.',
          );
        },
      );

      test(
        'handles error without code using pattern matching - not complete',
        () {
          const rustError = 'Calibration not complete';
          final result = errorHandler.translateCalibrationError(rustError);

          expect(
            result,
            'Calibration not finished. Please complete all steps.',
          );
        },
      );

      test('returns generic message for unknown calibration error', () {
        const rustError = 'Some completely unknown calibration error';
        final result = errorHandler.translateCalibrationError(rustError);

        expect(result, 'Calibration error occurred. Please try again.');
      });
    });

    group('createAudioException', () {
      test('creates exception with translated message and error code', () {
        const rustError =
            'AudioError::BpmInvalid { bpm: 0 } (code 1001): BPM must be greater than 0 (got 0)';
        final exception = errorHandler.createAudioException(rustError);

        expect(exception, isA<AudioServiceException>());
        expect(
          exception.message,
          'Please choose a tempo between 40 and 240 BPM.',
        );
        expect(exception.originalError, rustError);
        expect(exception.errorCode, 1001);
      });

      test('creates exception without error code for unparseable error', () {
        const rustError = 'Some error without code';
        final exception = errorHandler.createAudioException(rustError);

        expect(exception, isA<AudioServiceException>());
        expect(exception.originalError, rustError);
        expect(exception.errorCode, isNull);
      });

      test('exception toString returns user-friendly message', () {
        const rustError =
            'AudioError::AlreadyRunning (code 1002): Audio engine already running.';
        final exception = errorHandler.createAudioException(rustError);

        expect(
          exception.toString(),
          'Audio is already active. Please stop it first.',
        );
      });
    });

    group('createCalibrationException', () {
      test('creates exception with translated message and error code', () {
        const rustError =
            'CalibrationError::InsufficientSamples { required: 10, collected: 5 } (code 2001): Insufficient samples';
        final exception = errorHandler.createCalibrationException(rustError);

        expect(exception, isA<CalibrationServiceException>());
        expect(
          exception.message,
          'Not enough samples collected. Please continue making sounds.',
        );
        expect(exception.originalError, rustError);
        expect(exception.errorCode, 2001);
      });

      test('creates exception without error code for unparseable error', () {
        const rustError = 'Some calibration error without code';
        final exception = errorHandler.createCalibrationException(rustError);

        expect(exception, isA<CalibrationServiceException>());
        expect(exception.originalError, rustError);
        expect(exception.errorCode, isNull);
      });

      test('exception toString returns user-friendly message', () {
        const rustError =
            'CalibrationError::NotComplete (code 2003): Calibration not complete';
        final exception = errorHandler.createCalibrationException(rustError);

        expect(
          exception.toString(),
          'Calibration not finished. Please complete all steps.',
        );
      });
    });

    group('error code extraction', () {
      test('extracts error code from standard format', () {
        const rustError = 'AudioError::Something (code 1234): message';
        final exception = errorHandler.createAudioException(rustError);

        expect(exception.errorCode, 1234);
      });

      test('returns null for error without code', () {
        const rustError = 'Error without code';
        final exception = errorHandler.createAudioException(rustError);

        expect(exception.errorCode, isNull);
      });

      test('returns null for malformed code', () {
        const rustError = 'Error (code invalid): message';
        final exception = errorHandler.createAudioException(rustError);

        expect(exception.errorCode, isNull);
      });
    });
  });
}
