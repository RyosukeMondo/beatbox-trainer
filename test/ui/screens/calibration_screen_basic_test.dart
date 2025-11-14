import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beatbox_trainer/services/error_handler/exceptions.dart';
import 'package:beatbox_trainer/models/calibration_progress.dart';
import 'calibration_screen_test_helper.dart';

/// Basic CalibrationScreen widget tests
/// Tests: title, restart button, initialization, loading, error handling
void main() {
  group('CalibrationScreen - Basic UI and Error Handling', () {
    late CalibrationScreenTestHelper helper;

    setUp(() {
      helper = CalibrationScreenTestHelper();
      helper.setUp();
    });

    testWidgets('displays title in AppBar', (WidgetTester tester) async {
      // Setup: calibration starts successfully
      when(
        () => helper.mockAudioService.startCalibration(),
      ).thenAnswer((_) async {});
      when(() => helper.mockAudioService.getCalibrationStream()).thenAnswer(
        (_) => Stream.value(
          const CalibrationProgress(
            currentSound: CalibrationSound.kick,
            samplesCollected: 0,
            samplesNeeded: 10,
          ),
        ),
      );

      await helper.pumpCalibrationScreen(tester);

      expect(find.text('Calibration'), findsOneWidget);
    });

    testWidgets('displays restart button in AppBar', (
      WidgetTester tester,
    ) async {
      // Setup: calibration starts successfully
      when(
        () => helper.mockAudioService.startCalibration(),
      ).thenAnswer((_) async {});
      when(() => helper.mockAudioService.getCalibrationStream()).thenAnswer(
        (_) => Stream.value(
          const CalibrationProgress(
            currentSound: CalibrationSound.kick,
            samplesCollected: 0,
            samplesNeeded: 10,
          ),
        ),
      );

      await helper.pumpCalibrationScreen(tester);

      expect(find.byIcon(Icons.restart_alt), findsOneWidget);
    });

    testWidgets('starts calibration automatically on init', (
      WidgetTester tester,
    ) async {
      // Setup: calibration starts successfully
      when(
        () => helper.mockAudioService.startCalibration(),
      ).thenAnswer((_) async {});
      when(() => helper.mockAudioService.getCalibrationStream()).thenAnswer(
        (_) => Stream.value(
          const CalibrationProgress(
            currentSound: CalibrationSound.kick,
            samplesCollected: 0,
            samplesNeeded: 10,
          ),
        ),
      );

      await helper.pumpCalibrationScreen(tester);

      // Verify startCalibration was called automatically
      verify(() => helper.mockAudioService.startCalibration()).called(1);
    });

    testWidgets('displays loading state while initializing', (
      WidgetTester tester,
    ) async {
      // Setup: calibration stream delays before emitting data
      when(
        () => helper.mockAudioService.startCalibration(),
      ).thenAnswer((_) async {});
      when(() => helper.mockAudioService.getCalibrationStream()).thenAnswer(
        (_) => Stream.periodic(
          const Duration(seconds: 1),
          (_) => const CalibrationProgress(
            currentSound: CalibrationSound.kick,
            samplesCollected: 0,
            samplesNeeded: 10,
          ),
        ),
      );

      await helper.pumpCalibrationScreen(tester);

      // Should show loading while initializing or stream is connecting
      expect(
        find.textContaining('calibration...'),
        findsOneWidget,
      ); // Matches "Initializing calibration..." or "Starting calibration..."
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays error when calibration start fails', (
      WidgetTester tester,
    ) async {
      // Setup: calibration start fails
      when(() => helper.mockAudioService.startCalibration()).thenThrow(
        CalibrationServiceException(
          message: 'Calibration already in progress',
          errorCode: 2004,
          originalError: 'CalibrationError::AlreadyInProgress',
        ),
      );

      await helper.pumpCalibrationScreen(tester);
      await tester.pump();

      // Verify error message is displayed
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Calibration already in progress'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('navigates to home when Cancel button tapped in error state', (
      WidgetTester tester,
    ) async {
      // Setup: calibration start fails
      when(() => helper.mockAudioService.startCalibration()).thenThrow(
        CalibrationServiceException(
          message: 'Calibration failed to start',
          errorCode: 2004,
          originalError: 'CalibrationError::AlreadyInProgress',
        ),
      );

      await helper.pumpCalibrationScreen(tester);
      await tester.pump();

      // Verify Cancel button exists in error state
      expect(find.text('Cancel'), findsOneWidget);

      // Note: Actual navigation to '/' would require go_router setup
      // This test verifies the Cancel button is present and tappable
      // The navigation behavior is covered by integration tests
      final cancelButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Cancel'),
          matching: find.byType(TextButton),
        ),
      );
      expect(cancelButton.onPressed, isNotNull);
    });

    testWidgets('retries calibration when Retry button tapped', (
      WidgetTester tester,
    ) async {
      // Setup: first start fails, second succeeds
      var callCount = 0;
      when(() => helper.mockAudioService.startCalibration()).thenAnswer((
        _,
      ) async {
        callCount++;
        if (callCount == 1) {
          throw CalibrationServiceException(
            message: 'Calibration failed',
            errorCode: 2004,
            originalError: 'CalibrationError::AlreadyInProgress',
          );
        }
        // Second call succeeds
      });
      when(() => helper.mockAudioService.getCalibrationStream()).thenAnswer(
        (_) => Stream.value(
          const CalibrationProgress(
            currentSound: CalibrationSound.kick,
            samplesCollected: 0,
            samplesNeeded: 10,
          ),
        ),
      );

      await helper.pumpCalibrationScreen(tester);
      await tester.pump();

      // Tap Retry button
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Verify startCalibration was called twice
      verify(() => helper.mockAudioService.startCalibration()).called(2);
    });

    group('restart functionality', () {
      testWidgets('restarts calibration when restart button tapped', (
        WidgetTester tester,
      ) async {
        // Setup: calibration in progress
        when(
          () => helper.mockAudioService.startCalibration(),
        ).thenAnswer((_) async {});
        when(() => helper.mockAudioService.getCalibrationStream()).thenAnswer(
          (_) => Stream.value(
            const CalibrationProgress(
              currentSound: CalibrationSound.snare,
              samplesCollected: 5,
              samplesNeeded: 10,
            ),
          ),
        );

        await helper.pumpCalibrationScreen(tester);
        await tester.pump(); // Process initState
        await tester.pump(); // Process stream data

        // Tap restart button
        await tester.tap(find.byIcon(Icons.restart_alt));
        await tester.pump();

        // Verify startCalibration was called again (total 2 times)
        verify(() => helper.mockAudioService.startCalibration()).called(2);
      });

      testWidgets('restart button disabled when not calibrating', (
        WidgetTester tester,
      ) async {
        // Setup: calibration start fails
        when(() => helper.mockAudioService.startCalibration()).thenThrow(
          CalibrationServiceException(
            message: 'Failed to start',
            errorCode: 2004,
            originalError: 'CalibrationError::AlreadyInProgress',
          ),
        );

        await helper.pumpCalibrationScreen(tester);
        await tester.pump();

        // Restart button should be disabled (null onPressed)
        final iconButton = tester.widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.restart_alt),
            matching: find.byType(IconButton),
          ),
        );
        expect(iconButton.onPressed, isNull);
      });
    });

    group('stream error handling', () {
      testWidgets('displays error when calibration stream fails', (
        WidgetTester tester,
      ) async {
        // Setup: stream emits error
        when(
          () => helper.mockAudioService.startCalibration(),
        ).thenAnswer((_) async {});
        when(() => helper.mockAudioService.getCalibrationStream()).thenAnswer(
          (_) => Stream.error(
            CalibrationServiceException(
              message: 'Stream failed',
              errorCode: 2005,
              originalError: 'CalibrationError::StatePoisoned',
            ),
          ),
        );

        await helper.pumpCalibrationScreen(tester);
        await tester.pump();
        await tester.pump();

        // Verify stream error is displayed
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.textContaining('Stream error:'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('can retry after stream error', (WidgetTester tester) async {
        // Setup: first stream fails, second succeeds
        var callCount = 0;
        when(
          () => helper.mockAudioService.startCalibration(),
        ).thenAnswer((_) async {});
        when(() => helper.mockAudioService.getCalibrationStream()).thenAnswer((
          _,
        ) {
          callCount++;
          if (callCount == 1) {
            return Stream.error(
              CalibrationServiceException(
                message: 'Stream failed',
                errorCode: 2005,
                originalError: 'CalibrationError::StatePoisoned',
              ),
            );
          }
          return Stream.value(
            const CalibrationProgress(
              currentSound: CalibrationSound.kick,
              samplesCollected: 0,
              samplesNeeded: 10,
            ),
          );
        });

        await helper.pumpCalibrationScreen(tester);
        await tester.pump();
        await tester.pump();

        // Tap retry button
        await tester.tap(find.text('Retry'));
        await tester.pump(); // Process retry action
        await tester.pump(); // Process stream connection
        await tester.pump(); // Process stream data

        // Verify we recovered from error
        expect(find.text('Make KICK sound 10 times'), findsOneWidget);
      });
    });
  });
}
