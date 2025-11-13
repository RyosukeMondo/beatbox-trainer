import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beatbox_trainer/ui/screens/splash_screen.dart';
import '../../mocks.dart';

void main() {
  group('SplashScreen', () {
    late MockStorageService mockStorageService;

    setUp(() {
      mockStorageService = MockStorageService();
    });

    /// Helper function to pump SplashScreen with mock dependencies
    Future<void> pumpSplashScreen(
      WidgetTester tester, {
      String? initialRoute,
    }) async {
      final router = GoRouter(
        initialLocation: initialRoute ?? '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                SplashScreen(storageService: mockStorageService),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (context, state) =>
                const Scaffold(body: Text('Onboarding Screen')),
          ),
          GoRoute(
            path: '/training',
            builder: (context, state) =>
                const Scaffold(body: Text('Training Screen')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    }

    testWidgets('displays app logo and title', (WidgetTester tester) async {
      // Setup: no calibration data (simple case)
      when(() => mockStorageService.init()).thenAnswer((_) async => {});
      when(
        () => mockStorageService.hasCalibration(),
      ).thenAnswer((_) async => false);

      await pumpSplashScreen(tester);

      expect(find.byIcon(Icons.music_note), findsOneWidget);
      expect(find.text('Beatbox Trainer'), findsOneWidget);
    });

    testWidgets('navigates to onboarding when no calibration exists', (
      WidgetTester tester,
    ) async {
      // Setup: no calibration data
      when(() => mockStorageService.init()).thenAnswer((_) async => {});
      when(
        () => mockStorageService.hasCalibration(),
      ).thenAnswer((_) async => false);

      await pumpSplashScreen(tester);

      // Wait for navigation
      await tester.pumpAndSettle();

      // Verify navigated to onboarding
      expect(find.text('Onboarding Screen'), findsOneWidget);
      verify(() => mockStorageService.init()).called(1);
      verify(() => mockStorageService.hasCalibration()).called(1);
    });

    testWidgets('navigates to onboarding when calibration data is corrupted', (
      WidgetTester tester,
    ) async {
      // Setup: hasCalibration is true but loadCalibration returns null
      when(() => mockStorageService.init()).thenAnswer((_) async => {});
      when(
        () => mockStorageService.hasCalibration(),
      ).thenAnswer((_) async => true);
      when(
        () => mockStorageService.loadCalibration(),
      ).thenAnswer((_) async => null);

      await pumpSplashScreen(tester);

      // Wait for navigation
      await tester.pumpAndSettle();

      // Verify navigated to onboarding (to recalibrate)
      expect(find.text('Onboarding Screen'), findsOneWidget);
      verify(() => mockStorageService.init()).called(1);
      verify(() => mockStorageService.hasCalibration()).called(1);
      verify(() => mockStorageService.loadCalibration()).called(1);
    });
  });
}
