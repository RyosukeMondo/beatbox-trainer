@Tags(['slow'])
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beatbox_trainer/ui/screens/calibration_screen.dart';
import 'package:beatbox_trainer/services/error_handler/exceptions.dart';
import '../mocks.dart';

/// Integration tests for CalibrationScreen navigation edge cases
///
/// These tests verify the fix for the black screen bug that occurred when:
/// 1. User taps "Start Calibration"
/// 2. Error occurs
/// 3. User taps "Retry"
/// 4. User taps "Cancel"
///
/// The bug was: Navigator.pop() tried to pop from an empty navigation stack,
/// causing a black screen and assertion error in go_router.
///
/// The fix: Changed to context.go('/') which navigates to home route directly.
void main() {
  group('CalibrationScreen Navigation Edge Cases', () {
    late MockAudioService mockAudioService;
    late MockStorageService mockStorageService;
    late GoRouter router;

    setUp(() {
      mockAudioService = MockAudioService();
      mockStorageService = MockStorageService();

      // Mock storage service init() by default
      when(() => mockStorageService.init()).thenAnswer((_) async {});

      // Mock finishCalibration() to prevent dispose errors
      when(() => mockAudioService.finishCalibration()).thenAnswer((_) async {});

      // Create router with home and calibration routes
      router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Home Screen'))),
          ),
          GoRoute(
            path: '/calibration',
            builder: (context, state) => CalibrationScreen.test(
              audioService: mockAudioService,
              storageService: mockStorageService,
            ),
          ),
        ],
      );
    });

    testWidgets(
      'REGRESSION: Cancel button navigates to home instead of popping (prevents black screen)',
      (WidgetTester tester) async {
        // This test verifies the fix for the black screen bug
        // Setup: calibration start fails
        when(() => mockAudioService.startCalibration()).thenThrow(
          CalibrationServiceException(
            message: 'Calibration failed to start',
            errorCode: 2004,
            originalError: 'CalibrationError::AlreadyInProgress',
          ),
        );

        // Render app with go_router
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Verify we're on home screen
        expect(find.text('Home Screen'), findsOneWidget);

        // Navigate to calibration screen
        router.go('/calibration');
        await tester.pumpAndSettle();

        // Verify we're on calibration screen with error
        expect(find.text('Calibration failed to start'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // Tap Cancel button (this used to cause black screen)
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Verify we navigated back to home (not black screen)
        expect(find.text('Home Screen'), findsOneWidget);
        expect(find.byType(CalibrationScreen), findsNothing);
      },
    );

    testWidgets(
      'REGRESSION: Cancel works even when calibration is the first route (no previous page)',
      (WidgetTester tester) async {
        // This test verifies the fix handles the edge case where
        // calibration screen is opened directly with no navigation history
        when(() => mockAudioService.startCalibration()).thenThrow(
          CalibrationServiceException(
            message: 'Error',
            errorCode: 2004,
            originalError: 'CalibrationError::AlreadyInProgress',
          ),
        );

        // Create router starting directly at /calibration (no previous route)
        final directRouter = GoRouter(
          initialLocation: '/calibration',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('Home Screen'))),
            ),
            GoRoute(
              path: '/calibration',
              builder: (context, state) => CalibrationScreen.test(
                audioService: mockAudioService,
                storageService: mockStorageService,
              ),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: directRouter));
        await tester.pumpAndSettle();

        // Verify we're on calibration screen with error
        expect(find.text('Error'), findsOneWidget);

        // Tap Cancel (this used to cause assertion error: no pages to pop)
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Verify we navigated to home successfully (not crash/black screen)
        expect(find.text('Home Screen'), findsOneWidget);
      },
    );

    testWidgets('Cancel button uses context.go instead of Navigator.pop', (
      WidgetTester tester,
    ) async {
      // This test verifies the implementation detail of the fix
      when(() => mockAudioService.startCalibration()).thenThrow(
        CalibrationServiceException(
          message: 'Test error',
          errorCode: 2004,
          originalError: 'CalibrationError::AlreadyInProgress',
        ),
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Navigate to calibration
      router.go('/calibration');
      await tester.pumpAndSettle();

      // Get current route location
      final locationBeforeCancel = router.routeInformationProvider.value.uri
          .toString();
      expect(locationBeforeCancel, '/calibration');

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify we're at home route (context.go behavior)
      final locationAfterCancel = router.routeInformationProvider.value.uri
          .toString();
      expect(locationAfterCancel, '/');
    });

    testWidgets(
      'Retry → Cancel flow works correctly (reproduces original bug scenario)',
      (WidgetTester tester) async {
        // This test reproduces the exact user flow that caused the bug:
        // Start → Error → Retry → Cancel → Black Screen
        var callCount = 0;
        when(() => mockAudioService.startCalibration()).thenAnswer((_) async {
          callCount++;
          // Both attempts fail
          throw CalibrationServiceException(
            message: 'Calibration error',
            errorCode: 2004,
            originalError: 'CalibrationError::AlreadyInProgress',
          );
        });

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Step 1: Navigate to calibration (auto-starts, fails)
        router.go('/calibration');
        await tester.pumpAndSettle();

        expect(find.text('Calibration error'), findsOneWidget);
        expect(callCount, 1);

        // Step 2: Tap Retry (fails again)
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.text('Calibration error'), findsOneWidget);
        expect(callCount, 2);

        // Step 3: Tap Cancel (this used to cause black screen)
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Verify: We're back at home, NOT black screen
        expect(find.text('Home Screen'), findsOneWidget);
        expect(find.byType(CalibrationScreen), findsNothing);
      },
    );
  });
}
