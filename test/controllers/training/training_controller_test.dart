import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beatbox_trainer/controllers/training/training_controller.dart';
import 'package:beatbox_trainer/models/classification_result.dart';
import 'package:beatbox_trainer/services/permission/i_permission_service.dart';
import 'package:beatbox_trainer/services/error_handler/exceptions.dart';
import '../../mocks.dart';

void main() {
  late TrainingController controller;
  late MockAudioService mockAudioService;
  late MockPermissionService mockPermissionService;
  late MockSettingsService mockSettingsService;
  late MockStorageService mockStorageService;

  setUp(() {
    mockAudioService = MockAudioService();
    mockPermissionService = MockPermissionService();
    mockSettingsService = MockSettingsService();
    mockStorageService = MockStorageService();

    controller = TrainingController(
      audioService: mockAudioService,
      permissionService: mockPermissionService,
      settingsService: mockSettingsService,
      storageService: mockStorageService,
    );
  });

  group('TrainingController - Initial State', () {
    test('should start with training inactive', () {
      expect(controller.isTraining, isFalse);
    });

    test('should start with default BPM of 120', () {
      expect(controller.currentBpm, equals(120));
    });

    test('should expose classification stream', () {
      final mockStream = Stream<ClassificationResult>.empty();
      when(
        () => mockAudioService.getClassificationStream(),
      ).thenAnswer((_) => mockStream);

      expect(controller.classificationStream, equals(mockStream));
      verify(() => mockAudioService.getClassificationStream()).called(1);
    });

    test('should get debug mode from settings', () async {
      // Arrange
      when(
        () => mockSettingsService.getDebugMode(),
      ).thenAnswer((_) async => true);

      // Act
      final debugMode = await controller.getDebugMode();

      // Assert
      expect(debugMode, isTrue);
      verify(() => mockSettingsService.getDebugMode()).called(1);
    });
  });

  group('TrainingController - startTraining', () {
    test(
      'should request permission, load BPM, and start audio when permission granted',
      () async {
        // Arrange
        when(
          () => mockPermissionService.checkMicrophonePermission(),
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(() => mockSettingsService.getBpm()).thenAnswer((_) async => 140);
        when(
          () => mockAudioService.startAudio(bpm: any(named: 'bpm')),
        ).thenAnswer((_) async => {});

        // Act
        await controller.startTraining();

        // Assert
        expect(controller.isTraining, isTrue);
        expect(controller.currentBpm, equals(140));
        verify(
          () => mockPermissionService.checkMicrophonePermission(),
        ).called(1);
        verify(() => mockSettingsService.getBpm()).called(1);
        verify(() => mockAudioService.startAudio(bpm: 140)).called(1);
      },
    );

    test(
      'should request permission when initially denied and succeed if granted',
      () async {
        // Arrange
        when(
          () => mockPermissionService.checkMicrophonePermission(),
        ).thenAnswer((_) async => PermissionStatus.denied);
        when(
          () => mockPermissionService.requestMicrophonePermission(),
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(() => mockSettingsService.getBpm()).thenAnswer((_) async => 120);
        when(
          () => mockAudioService.startAudio(bpm: any(named: 'bpm')),
        ).thenAnswer((_) async => {});

        // Act
        await controller.startTraining();

        // Assert
        expect(controller.isTraining, isTrue);
        verify(
          () => mockPermissionService.checkMicrophonePermission(),
        ).called(1);
        verify(
          () => mockPermissionService.requestMicrophonePermission(),
        ).called(1);
        verify(() => mockAudioService.startAudio(bpm: 120)).called(1);
      },
    );

    test(
      'should throw PermissionException when permission denied after request',
      () async {
        // Arrange
        when(
          () => mockPermissionService.checkMicrophonePermission(),
        ).thenAnswer((_) async => PermissionStatus.denied);
        when(
          () => mockPermissionService.requestMicrophonePermission(),
        ).thenAnswer((_) async => PermissionStatus.denied);

        // Act & Assert
        expect(
          () => controller.startTraining(),
          throwsA(isA<PermissionException>()),
        );

        expect(controller.isTraining, isFalse);
        verifyNever(() => mockAudioService.startAudio(bpm: any(named: 'bpm')));
      },
    );

    test(
      'should open app settings and throw PermissionException when permanently denied',
      () async {
        // Arrange
        when(
          () => mockPermissionService.checkMicrophonePermission(),
        ).thenAnswer((_) async => PermissionStatus.permanentlyDenied);
        when(
          () => mockPermissionService.openAppSettings(),
        ).thenAnswer((_) async => true);

        // Act & Assert
        await expectLater(
          () => controller.startTraining(),
          throwsA(isA<PermissionException>()),
        );

        expect(controller.isTraining, isFalse);
        verify(() => mockPermissionService.openAppSettings()).called(1);
        verifyNever(() => mockAudioService.startAudio(bpm: any(named: 'bpm')));
      },
    );

    test('should throw StateError when training already in progress', () async {
      // Arrange
      when(
        () => mockPermissionService.checkMicrophonePermission(),
      ).thenAnswer((_) async => PermissionStatus.granted);
      when(() => mockSettingsService.getBpm()).thenAnswer((_) async => 120);
      when(
        () => mockAudioService.startAudio(bpm: any(named: 'bpm')),
      ).thenAnswer((_) async => {});

      await controller.startTraining();

      // Act & Assert
      expect(() => controller.startTraining(), throwsA(isA<StateError>()));

      // Should only call services once (from first start)
      verify(() => mockAudioService.startAudio(bpm: 120)).called(1);
    });

    test(
      'should propagate AudioServiceException when audio start fails',
      () async {
        // Arrange
        when(
          () => mockPermissionService.checkMicrophonePermission(),
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(() => mockSettingsService.getBpm()).thenAnswer((_) async => 120);
        when(
          () => mockAudioService.startAudio(bpm: any(named: 'bpm')),
        ).thenThrow(
          const AudioServiceException(
            message: 'Audio engine failed to start',
            originalError: 'Oboe stream open failed',
          ),
        );

        // Act & Assert
        expect(
          () => controller.startTraining(),
          throwsA(isA<AudioServiceException>()),
        );

        expect(controller.isTraining, isFalse);
      },
    );
  });

  group('TrainingController - stopTraining', () {
    test(
      'should stop audio and update state when training is active',
      () async {
        // Arrange - start training first
        when(
          () => mockPermissionService.checkMicrophonePermission(),
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(() => mockSettingsService.getBpm()).thenAnswer((_) async => 120);
        when(
          () => mockAudioService.startAudio(bpm: any(named: 'bpm')),
        ).thenAnswer((_) async => {});
        when(() => mockAudioService.stopAudio()).thenAnswer((_) async => {});

        await controller.startTraining();
        expect(controller.isTraining, isTrue);

        // Act
        await controller.stopTraining();

        // Assert
        expect(controller.isTraining, isFalse);
        verify(() => mockAudioService.stopAudio()).called(1);
      },
    );

    test('should be no-op when training is not active', () async {
      // Arrange
      expect(controller.isTraining, isFalse);
      when(() => mockAudioService.stopAudio()).thenAnswer((_) async => {});

      // Act
      await controller.stopTraining();

      // Assert
      expect(controller.isTraining, isFalse);
      verifyNever(() => mockAudioService.stopAudio());
    });

    test('should propagate AudioServiceException when stop fails', () async {
      // Arrange - start training first
      when(
        () => mockPermissionService.checkMicrophonePermission(),
      ).thenAnswer((_) async => PermissionStatus.granted);
      when(() => mockSettingsService.getBpm()).thenAnswer((_) async => 120);
      when(
        () => mockAudioService.startAudio(bpm: any(named: 'bpm')),
      ).thenAnswer((_) async => {});
      when(() => mockAudioService.stopAudio()).thenThrow(
        const AudioServiceException(
          message: 'Failed to stop audio',
          originalError: 'Oboe stream close failed',
        ),
      );

      await controller.startTraining();

      // Act & Assert
      expect(
        () => controller.stopTraining(),
        throwsA(isA<AudioServiceException>()),
      );
    });
  });

  group('TrainingController - updateBpm', () {
    test(
      'should validate BPM range and throw ArgumentError for invalid values',
      () async {
        // Act & Assert - below minimum
        expect(() => controller.updateBpm(39), throwsA(isA<ArgumentError>()));

        // Act & Assert - above maximum
        expect(() => controller.updateBpm(241), throwsA(isA<ArgumentError>()));

        verifyNever(() => mockAudioService.setBpm(bpm: any(named: 'bpm')));
        verifyNever(() => mockSettingsService.setBpm(any()));
      },
    );

    test(
      'should update BPM in audio service and settings when training is active',
      () async {
        // Arrange - start training first
        when(
          () => mockPermissionService.checkMicrophonePermission(),
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(() => mockSettingsService.getBpm()).thenAnswer((_) async => 120);
        when(
          () => mockAudioService.startAudio(bpm: any(named: 'bpm')),
        ).thenAnswer((_) async => {});
        when(
          () => mockAudioService.setBpm(bpm: any(named: 'bpm')),
        ).thenAnswer((_) async => {});
        when(
          () => mockSettingsService.setBpm(any()),
        ).thenAnswer((_) async => {});

        await controller.startTraining();

        // Act
        await controller.updateBpm(150);

        // Assert
        expect(controller.currentBpm, equals(150));
        verify(() => mockAudioService.setBpm(bpm: 150)).called(1);
        verify(() => mockSettingsService.setBpm(150)).called(1);
      },
    );

    test('should only update settings when training is inactive', () async {
      // Arrange
      when(() => mockSettingsService.setBpm(any())).thenAnswer((_) async => {});

      expect(controller.isTraining, isFalse);

      // Act
      await controller.updateBpm(140);

      // Assert
      expect(controller.currentBpm, equals(140));
      verifyNever(() => mockAudioService.setBpm(bpm: any(named: 'bpm')));
      verify(() => mockSettingsService.setBpm(140)).called(1);
    });

    test('should accept valid BPM range boundaries', () async {
      // Arrange
      when(() => mockSettingsService.setBpm(any())).thenAnswer((_) async => {});

      // Act & Assert - minimum valid BPM
      await controller.updateBpm(40);
      expect(controller.currentBpm, equals(40));

      // Act & Assert - maximum valid BPM
      await controller.updateBpm(240);
      expect(controller.currentBpm, equals(240));
    });

    test('should propagate AudioServiceException when setBpm fails', () async {
      // Arrange - start training first
      when(
        () => mockPermissionService.checkMicrophonePermission(),
      ).thenAnswer((_) async => PermissionStatus.granted);
      when(() => mockSettingsService.getBpm()).thenAnswer((_) async => 120);
      when(
        () => mockAudioService.startAudio(bpm: any(named: 'bpm')),
      ).thenAnswer((_) async => {});
      when(() => mockAudioService.setBpm(bpm: any(named: 'bpm'))).thenThrow(
        const AudioServiceException(
          message: 'Failed to update BPM',
          originalError: 'Invalid BPM value',
        ),
      );

      await controller.startTraining();

      // Act & Assert
      expect(
        () => controller.updateBpm(150),
        throwsA(isA<AudioServiceException>()),
      );
    });
  });

  group('TrainingController - dispose', () {
    test('should stop training when active', () async {
      // Arrange - start training first
      when(
        () => mockPermissionService.checkMicrophonePermission(),
      ).thenAnswer((_) async => PermissionStatus.granted);
      when(() => mockSettingsService.getBpm()).thenAnswer((_) async => 120);
      when(
        () => mockAudioService.startAudio(bpm: any(named: 'bpm')),
      ).thenAnswer((_) async => {});
      when(() => mockAudioService.stopAudio()).thenAnswer((_) async => {});

      await controller.startTraining();
      expect(controller.isTraining, isTrue);

      // Act
      await controller.dispose();

      // Assert
      expect(controller.isTraining, isFalse);
      verify(() => mockAudioService.stopAudio()).called(1);
    });

    test('should be no-op when training is not active', () async {
      // Arrange
      expect(controller.isTraining, isFalse);

      // Act
      await controller.dispose();

      // Assert
      verifyNever(() => mockAudioService.stopAudio());
    });
  });

  group('TrainingController - Edge Cases', () {
    test(
      'should handle permission request returning permanentlyDenied after denied',
      () async {
        // Arrange
        when(
          () => mockPermissionService.checkMicrophonePermission(),
        ).thenAnswer((_) async => PermissionStatus.denied);
        when(
          () => mockPermissionService.requestMicrophonePermission(),
        ).thenAnswer((_) async => PermissionStatus.permanentlyDenied);

        // Act & Assert
        await expectLater(
          () => controller.startTraining(),
          throwsA(isA<PermissionException>()),
        );

        // Should request once, then get permanently denied and fail
        verify(
          () => mockPermissionService.requestMicrophonePermission(),
        ).called(1);
        // Note: openAppSettings is NOT called because permanentlyDenied came from request, not initial check
        verifyNever(() => mockPermissionService.openAppSettings());
      },
    );

    test('should maintain state consistency after failed start', () async {
      // Arrange
      when(
        () => mockPermissionService.checkMicrophonePermission(),
      ).thenAnswer((_) async => PermissionStatus.granted);
      when(() => mockSettingsService.getBpm()).thenAnswer((_) async => 120);
      when(() => mockAudioService.startAudio(bpm: any(named: 'bpm'))).thenThrow(
        const AudioServiceException(
          message: 'Audio failed',
          originalError: 'error',
        ),
      );

      // Act
      try {
        await controller.startTraining();
      } catch (_) {
        // Ignore error
      }

      // Assert - state should remain unchanged
      expect(controller.isTraining, isFalse);
      expect(controller.currentBpm, equals(120)); // Should keep loaded BPM
    });

    test('PermissionException toString should return message', () {
      // Arrange
      const exception = PermissionException('Microphone access denied');

      // Act & Assert
      expect(exception.toString(), equals('Microphone access denied'));
    });
  });
}
