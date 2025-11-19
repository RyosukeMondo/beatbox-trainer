import 'dart:async';

import 'package:beatbox_trainer/models/classification_result.dart';
import 'package:beatbox_trainer/models/timing_feedback.dart';
import 'package:beatbox_trainer/services/audio/i_audio_service.dart';
import 'package:beatbox_trainer/services/audio/test_harness/diagnostics_controller.dart';
import 'package:beatbox_trainer/services/audio/telemetry_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAudioService extends Mock implements IAudioService {}

void main() {
  group('DiagnosticsController (widget wiring)', () {
    late _MockAudioService audioService;
    late DiagnosticsController controller;
    late StreamController<ClassificationResult> classificationController;

    setUp(() {
      audioService = _MockAudioService();
      classificationController = StreamController.broadcast();
      when(
        () => audioService.getClassificationStream(),
      ).thenAnswer((_) => classificationController.stream);
      when(
        () => audioService.getDiagnosticMetricsStream(),
      ).thenAnswer((_) => const Stream<DiagnosticMetric>.empty());

      controller = DiagnosticsController(
        audioService: audioService,
        fixtureSessionClient: const NoopFixtureSessionClient(),
      );
    });

    tearDown(() async {
      await classificationController.close();
      controller.dispose();
    });

    testWidgets('updates UI when classification stream emits', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamBuilder<ClassificationResult>(
              stream: controller.classificationStream,
              builder: (context, snapshot) {
                return Text(
                  snapshot.hasData ? snapshot.data!.sound.name : 'waiting',
                  textDirection: TextDirection.ltr,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('waiting'), findsOneWidget);

      classificationController.add(_classificationResult());
      await tester.pump();

      expect(find.text('kick'), findsOneWidget);
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
    timestampMs: 1234,
    confidence: 0.86,
  );
}
