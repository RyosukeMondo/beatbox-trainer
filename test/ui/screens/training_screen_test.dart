import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beatbox_trainer/ui/screens/training_screen.dart';
import 'package:beatbox_trainer/controllers/training/training_controller.dart';
import 'package:beatbox_trainer/services/debug/i_debug_service.dart';
import 'package:beatbox_trainer/models/classification_result.dart';
import 'package:beatbox_trainer/models/timing_feedback.dart';

/// Mock training controller for testing TrainingScreen UI behavior
class MockTrainingController extends Mock implements TrainingController {}

/// Mock debug service for testing debug overlay
class MockDebugService extends Mock implements IDebugService {}

void main() {
  group('TrainingScreen', () {
    late MockTrainingController mockController;
    late MockDebugService mockDebugService;

    setUp(() {
      mockController = MockTrainingController();
      mockDebugService = MockDebugService();

      // Setup default mock responses
      when(() => mockController.currentBpm).thenReturn(120);
      when(() => mockController.isTraining).thenReturn(false);
      when(() => mockController.getDebugMode()).thenAnswer((_) async => false);
      when(
        () => mockController.classificationStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockController.dispose()).thenAnswer((_) async {});
    });

    /// Helper function to pump TrainingScreen with mock dependencies
    Future<void> pumpTrainingScreen(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => TrainingScreen.test(
              controller: mockController,
              debugService: mockDebugService,
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) =>
                const Scaffold(body: Text('Settings Screen')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      // Wait for initState to complete
      await tester.pumpAndSettle();
    }

    testWidgets('displays title in AppBar', (WidgetTester tester) async {
      await pumpTrainingScreen(tester);

      expect(find.text('Beatbox Trainer'), findsOneWidget);
    });

    testWidgets('displays current BPM from controller', (
      WidgetTester tester,
    ) async {
      when(() => mockController.currentBpm).thenReturn(140);
      await pumpTrainingScreen(tester);

      expect(find.text('140 BPM'), findsOneWidget);
    });

    testWidgets('displays BPM slider with correct range', (
      WidgetTester tester,
    ) async {
      await pumpTrainingScreen(tester);

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, equals(40));
      expect(slider.max, equals(240));
      expect(slider.divisions, equals(200));
      expect(slider.value, equals(120));
    });

    testWidgets('displays Start button when not training', (
      WidgetTester tester,
    ) async {
      when(() => mockController.isTraining).thenReturn(false);
      await pumpTrainingScreen(tester);

      expect(
        find.widgetWithText(FloatingActionButton, 'Start'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('displays Stop button when training', (
      WidgetTester tester,
    ) async {
      when(() => mockController.isTraining).thenReturn(true);
      when(() => mockController.classificationStream).thenAnswer(
        (_) => Stream.value(
          const ClassificationResult(
            sound: BeatboxHit.kick,
            timing: TimingFeedback(
              classification: TimingClassification.onTime,
              errorMs: 0,
            ),
            timestampMs: 1000,
            confidence: 0.95,
          ),
        ),
      );

      await pumpTrainingScreen(tester);

      expect(find.widgetWithText(FloatingActionButton, 'Stop'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    testWidgets('displays idle message when not training', (
      WidgetTester tester,
    ) async {
      when(() => mockController.isTraining).thenReturn(false);
      await pumpTrainingScreen(tester);

      expect(find.text('Press Start to begin training'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    });

    testWidgets('calls controller.updateBpm when slider moved', (
      WidgetTester tester,
    ) async {
      when(() => mockController.updateBpm(any())).thenAnswer((_) async {});
      await pumpTrainingScreen(tester);

      // Simulate slider change to 150 BPM
      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(100, 0));
      await tester.pump();

      // Verify updateBpm was called (exact value depends on drag)
      verify(() => mockController.updateBpm(any())).called(greaterThan(0));
    });

    testWidgets('calls controller.startTraining when Start button tapped', (
      WidgetTester tester,
    ) async {
      when(() => mockController.startTraining()).thenAnswer((_) async {});
      await pumpTrainingScreen(tester);

      // Tap Start button
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Start'));
      await tester.pump();

      // Verify startTraining was called
      verify(() => mockController.startTraining()).called(1);
    });

    testWidgets('calls controller.stopTraining when Stop button tapped', (
      WidgetTester tester,
    ) async {
      when(() => mockController.isTraining).thenReturn(true);
      when(() => mockController.stopTraining()).thenAnswer((_) async {});
      when(() => mockController.classificationStream).thenAnswer(
        (_) => Stream.value(
          const ClassificationResult(
            sound: BeatboxHit.kick,
            timing: TimingFeedback(
              classification: TimingClassification.onTime,
              errorMs: 0,
            ),
            timestampMs: 1000,
            confidence: 0.95,
          ),
        ),
      );

      await pumpTrainingScreen(tester);

      // Tap Stop button
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Stop'));
      await tester.pump();

      // Verify stopTraining was called
      verify(() => mockController.stopTraining()).called(1);
    });

    testWidgets('shows permission dialog when PermissionException thrown', (
      WidgetTester tester,
    ) async {
      when(
        () => mockController.startTraining(),
      ).thenThrow(const PermissionException('Microphone permission denied'));
      await pumpTrainingScreen(tester);

      // Tap Start button
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Start'));
      await tester.pump();
      await tester.pump();

      // Verify permission dialog is shown
      expect(find.text('Microphone Permission Required'), findsOneWidget);
      expect(find.text('Microphone permission denied'), findsOneWidget);
    });

    testWidgets('shows error dialog when startTraining fails', (
      WidgetTester tester,
    ) async {
      when(
        () => mockController.startTraining(),
      ).thenThrow(Exception('Failed to start audio engine'));
      await pumpTrainingScreen(tester);

      // Tap Start button
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Start'));
      await tester.pump();
      await tester.pump();

      // Verify error dialog is shown
      expect(find.textContaining('Failed to start training:'), findsOneWidget);
    });

    testWidgets('shows error dialog when stopTraining fails', (
      WidgetTester tester,
    ) async {
      when(() => mockController.isTraining).thenReturn(true);
      when(
        () => mockController.stopTraining(),
      ).thenThrow(Exception('Failed to stop audio engine'));
      when(() => mockController.classificationStream).thenAnswer(
        (_) => Stream.value(
          const ClassificationResult(
            sound: BeatboxHit.kick,
            timing: TimingFeedback(
              classification: TimingClassification.onTime,
              errorMs: 0,
            ),
            timestampMs: 1000,
            confidence: 0.95,
          ),
        ),
      );

      await pumpTrainingScreen(tester);

      // Tap Stop button
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Stop'));
      await tester.pump();
      await tester.pump();

      // Verify error dialog is shown
      expect(find.textContaining('Failed to stop training:'), findsOneWidget);
    });

    testWidgets('shows error dialog when updateBpm fails', (
      WidgetTester tester,
    ) async {
      when(
        () => mockController.updateBpm(any()),
      ).thenThrow(ArgumentError('BPM must be between 40 and 240'));
      await pumpTrainingScreen(tester);

      // Move slider
      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pump();
      await tester.pump();

      // Verify error dialog is shown
      expect(find.text('BPM Update Error'), findsOneWidget);
    });

    group('classification display', () {
      testWidgets('displays classification result when data received', (
        WidgetTester tester,
      ) async {
        when(() => mockController.isTraining).thenReturn(true);
        when(() => mockController.classificationStream).thenAnswer(
          (_) => Stream.value(
            const ClassificationResult(
              sound: BeatboxHit.kick,
              timing: TimingFeedback(
                classification: TimingClassification.onTime,
                errorMs: 0,
              ),
              timestampMs: 1000,
              confidence: 0.95,
            ),
          ),
        );

        await pumpTrainingScreen(tester);
        await tester.pump(); // Let stream builder process data

        // Verify classification result is displayed
        expect(find.text('KICK'), findsOneWidget);
        expect(find.text('0.0ms ON-TIME'), findsOneWidget);
      });

      testWidgets('displays early timing feedback correctly', (
        WidgetTester tester,
      ) async {
        when(() => mockController.isTraining).thenReturn(true);
        when(() => mockController.classificationStream).thenAnswer(
          (_) => Stream.value(
            const ClassificationResult(
              sound: BeatboxHit.snare,
              timing: TimingFeedback(
                classification: TimingClassification.early,
                errorMs: -25,
              ),
              timestampMs: 2000,
              confidence: 0.95,
            ),
          ),
        );

        await pumpTrainingScreen(tester);
        await tester.pump(); // Let stream builder process data

        // Verify timing feedback shows early
        expect(find.text('SNARE'), findsOneWidget);
        expect(find.text('-25.0ms EARLY'), findsOneWidget);
      });

      testWidgets('displays late timing feedback correctly', (
        WidgetTester tester,
      ) async {
        when(() => mockController.isTraining).thenReturn(true);
        when(() => mockController.classificationStream).thenAnswer(
          (_) => Stream.value(
            const ClassificationResult(
              sound: BeatboxHit.hiHat,
              timing: TimingFeedback(
                classification: TimingClassification.late,
                errorMs: 50,
              ),
              timestampMs: 3000,
              confidence: 0.95,
            ),
          ),
        );

        await pumpTrainingScreen(tester);
        await tester.pump(); // Let stream builder process data

        // Verify timing feedback shows late
        expect(find.text('HI-HAT'), findsOneWidget);
        expect(find.text('+50.0ms LATE'), findsOneWidget);
      });

      testWidgets('displays stream error when stream fails', (
        WidgetTester tester,
      ) async {
        when(() => mockController.isTraining).thenReturn(true);
        when(
          () => mockController.classificationStream,
        ).thenAnswer((_) => Stream.error(Exception('Stream failed')));

        await pumpTrainingScreen(tester);

        // Verify stream error is displayed
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.textContaining('Stream error:'), findsOneWidget);
      });

      // Note: Stream connection state tests removed as they test
      // StreamBuilder internals rather than TrainingScreen UI logic
    });

    // Note: Debug overlay tests are skipped as they involve async state loading
    // in initState which is difficult to test reliably. The functionality is covered
    // by integration tests and manual testing.

    testWidgets('disposes controller on widget dispose', (
      WidgetTester tester,
    ) async {
      when(() => mockController.dispose()).thenAnswer((_) async {});
      await pumpTrainingScreen(tester);

      // Navigate away to trigger dispose
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Verify controller.dispose was called
      verify(() => mockController.dispose()).called(1);
    });
  });
}
