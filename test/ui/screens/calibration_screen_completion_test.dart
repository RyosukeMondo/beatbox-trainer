import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beatbox_trainer/services/error_handler/exceptions.dart';
import 'package:beatbox_trainer/models/calibration_progress.dart';
import 'calibration_screen_test_helper.dart';

/// CalibrationScreen completion tests
/// Tests: finishCalibration calls, navigation, completion errors
void main() {
  group('CalibrationScreen - Calibration Completion', () {
    late CalibrationScreenTestHelper helper;

    setUp(() {
      helper = CalibrationScreenTestHelper();
      helper.setUp();
    });

    testWidgets('calls finishCalibration when all samples collected', (
      WidgetTester tester,
    ) async {
      // Setup: calibration completes
      when(
        () => helper.mockAudioService.startCalibration(),
      ).thenAnswer((_) async {});
      when(() => helper.mockAudioService.getCalibrationStream()).thenAnswer(
        (_) => Stream.value(
          const CalibrationProgress(
            currentSound: CalibrationSound.hiHat,
            samplesCollected: 10,
            samplesNeeded: 10,
          ),
        ),
      );
      when(
        () => helper.mockAudioService.finishCalibration(),
      ).thenAnswer((_) async {});

      await helper.pumpCalibrationScreen(tester);
      await tester.pump();
      await tester.pump();

      // Verify finishCalibration was called
      verify(() => helper.mockAudioService.finishCalibration()).called(1);
    });

    // Note: Navigation test skipped because _retrieveCalibrationData()
    // calls api.getCalibrationState() which is an FFI call that cannot
    // be mocked in widget tests. Navigation behavior is covered by
    // integration/end-to-end tests.
    testWidgets(
      'navigates back after successful calibration',
      (WidgetTester tester) async {},
      skip: true,
    );

    testWidgets('displays error when finishCalibration fails', (
      WidgetTester tester,
    ) async {
      // Setup: calibration completes but finish fails
      when(
        () => helper.mockAudioService.startCalibration(),
      ).thenAnswer((_) async {});
      when(() => helper.mockAudioService.getCalibrationStream()).thenAnswer(
        (_) => Stream.value(
          const CalibrationProgress(
            currentSound: CalibrationSound.hiHat,
            samplesCollected: 10,
            samplesNeeded: 10,
          ),
        ),
      );
      when(() => helper.mockAudioService.finishCalibration()).thenThrow(
        CalibrationServiceException(
          message: 'Insufficient samples for threshold computation',
          errorCode: 2001,
          originalError: 'CalibrationError::InsufficientSamples',
        ),
      );

      await helper.pumpCalibrationScreen(tester);
      await tester.pump(); // Process stream data
      await tester.pumpAndSettle(); // Let all async operations complete

      // Verify error is displayed
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(
        find.text('Insufficient samples for threshold computation'),
        findsOneWidget,
      );
    });
  });
}
