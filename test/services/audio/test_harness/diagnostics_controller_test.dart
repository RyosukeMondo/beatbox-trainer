import 'dart:async';

import 'package:beatbox_trainer/models/classification_result.dart';
import 'package:beatbox_trainer/models/timing_feedback.dart';
import 'package:beatbox_trainer/services/audio/i_audio_service.dart';
import 'package:beatbox_trainer/services/audio/telemetry_stream.dart';
import 'package:beatbox_trainer/services/audio/test_harness/diagnostics_controller.dart';
import 'package:beatbox_trainer/services/audio/test_harness/harness_audio_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAudioService extends Mock implements IAudioService {}

class _MockFixtureSessionClient extends Mock implements FixtureSessionClient {}

class _HarnessFixtureRequestFake extends Fake
    implements HarnessFixtureRequest {}

void main() {
  setUpAll(() {
    registerFallbackValue(_HarnessFixtureRequestFake());
  });

  group('DiagnosticsController', () {
    late _MockAudioService audioService;
    late _MockFixtureSessionClient fixtureClient;
    late DiagnosticsController controller;
    late StreamController<ClassificationResult> classificationController;
    late StreamController<DiagnosticMetric> diagnosticsStream;

    setUp(() {
      audioService = _MockAudioService();
      fixtureClient = _MockFixtureSessionClient();
      classificationController = StreamController.broadcast();
      diagnosticsStream = StreamController.broadcast();

      when(
        () => audioService.getClassificationStream(),
      ).thenAnswer((_) => classificationController.stream);
      when(
        () => audioService.getDiagnosticMetricsStream(),
      ).thenAnswer((_) => diagnosticsStream.stream);

      controller = DiagnosticsController(
        audioService: audioService,
        fixtureSessionClient: fixtureClient,
      );
    });

    tearDown(() async {
      await classificationController.close();
      await diagnosticsStream.close();
      controller.dispose();
    });

    test('delegates fixture-backed sources to the session client', () async {
      final source = FixtureFileHarnessAudioSource(
        path: 'rust/fixtures/wav.wav',
      );
      when(() => fixtureClient.start(any())).thenAnswer((_) async {});

      await controller.startFixtureSession(source);

      verify(
        () => fixtureClient.start(any(that: isA<HarnessFixtureRequest>())),
      ).called(1);
      expect(controller.isFixtureSessionActive.value, isTrue);
      expect(controller.selectedSource.value, source);
    });

    test('bypasses fixtures for microphone proxy sources', () async {
      final source = MicrophoneProxyHarnessAudioSource();

      await controller.startFixtureSession(source);

      verifyNever(() => fixtureClient.start(any()));
      expect(controller.isFixtureSessionActive.value, isFalse);
    });

    test('stops fixture session when active', () async {
      when(() => fixtureClient.start(any())).thenAnswer((_) async {});
      when(() => fixtureClient.stop()).thenAnswer((_) async {});
      final source = FixtureFileHarnessAudioSource(path: 'some.wav');

      await controller.startFixtureSession(source);
      await controller.stopFixtureSession();

      verify(() => fixtureClient.stop()).called(1);
      expect(controller.isFixtureSessionActive.value, isFalse);
    });

    test('exposes broadcast classification stream', () async {
      final results = <ClassificationResult>[];
      final sub = controller.classificationStream.listen(results.add);

      classificationController.add(_classificationResult());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(results, hasLength(1));
      await sub.cancel();
    });

    test('exposes broadcast diagnostic metrics stream', () async {
      final metrics = <DiagnosticMetric>[];
      final sub = controller.diagnosticMetricsStream.listen(metrics.add);

      diagnosticsStream.add(
        DiagnosticMetric(
          type: DiagnosticMetricType.latency,
          payload: const {'avgMs': 10.0},
          timestamp: DateTime(2024),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(metrics, hasLength(1));
      await sub.cancel();
    });
  });
}

ClassificationResult _classificationResult() {
  return ClassificationResult(
    sound: BeatboxHit.kick,
    timing: const TimingFeedback(
      classification: TimingClassification.onTime,
      errorMs: 0,
    ),
    timestampMs: 0,
    confidence: 0.9,
  );
}
