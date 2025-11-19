import 'package:beatbox_trainer/models/classification_result.dart';
import 'package:beatbox_trainer/models/timing_feedback.dart';
import 'package:beatbox_trainer/services/audio/audio_controller.dart';
import 'package:beatbox_trainer/services/audio/i_audio_service.dart';
import 'package:beatbox_trainer/services/audio/test_harness/diagnostics_controller.dart';
import 'package:beatbox_trainer/services/audio/test_harness/harness_audio_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAudioService extends Mock implements IAudioService {}

class _MockDiagnosticsController extends Mock
    implements DiagnosticsController {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      FixtureFileHarnessAudioSource(path: 'fixtures/kick.wav'),
    );
  });

  group('AudioController', () {
    late _MockAudioService audioService;

    setUp(() {
      audioService = _MockAudioService();
      when(
        () => audioService.getClassificationStream(),
      ).thenAnswer((_) => Stream<ClassificationResult>.empty());
      when(
        () => audioService.getDiagnosticMetricsStream(),
      ).thenAnswer((_) => const Stream.empty());
    });

    test('starts diagnostics harness when fixture is provided', () async {
      final diagnostics = _MockDiagnosticsController();
      when(
        () => diagnostics.classificationStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => diagnostics.diagnosticMetricsStream,
      ).thenAnswer((_) => const Stream.empty());
      final sessionFlag = ValueNotifier(false);
      when(() => diagnostics.isFixtureSessionActive).thenReturn(sessionFlag);
      when(
        () => diagnostics.startFixtureSession(any()),
      ).thenAnswer((_) async {});
      when(() => diagnostics.stopFixtureSession()).thenAnswer((_) async {});

      final controller =
          AudioController(
              audioService: audioService,
              diagnosticsController: diagnostics,
            )
            ..harnessAudioSource = FixtureFileHarnessAudioSource(
              path: 'fixtures/kick.wav',
            );

      await controller.start(bpm: 120);

      verify(() => diagnostics.startFixtureSession(any())).called(1);
      verifyNever(() => audioService.startAudio(bpm: any(named: 'bpm')));
    });

    test('throws when fixture requires diagnostics controller', () async {
      final controller =
          AudioController(
              audioService: audioService,
              diagnosticsController: null,
            )
            ..harnessAudioSource = FixtureFileHarnessAudioSource(
              path: 'fixtures/snare.wav',
            );

      expect(() => controller.start(bpm: 120), throwsA(isA<StateError>()));
    });

    test('starts live audio when harness not provided', () async {
      final controller = AudioController(
        audioService: audioService,
        diagnosticsController: null,
      );
      when(
        () => audioService.startAudio(bpm: any(named: 'bpm')),
      ).thenAnswer((_) async {});
      when(() => audioService.stopAudio()).thenAnswer((_) async {});

      await controller.start(bpm: 110);
      await controller.stop();

      verify(() => audioService.startAudio(bpm: 110)).called(1);
      verify(() => audioService.stopAudio()).called(1);
    });
  });
}
