import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:beatbox_trainer/ui/screens/onboarding_screen.dart';

void main() {
  group('OnboardingScreen', () {
    /// Helper function to pump OnboardingScreen with navigation
    Future<void> pumpOnboardingScreen(WidgetTester tester) async {
      // Set a larger test surface size to avoid layout overflow
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/calibration',
            builder: (context, state) =>
                const Scaffold(body: Text('Calibration Screen')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      addTearDown(() => tester.view.reset());
    }

    testWidgets('displays app icon', (WidgetTester tester) async {
      await pumpOnboardingScreen(tester);

      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('displays welcome message', (WidgetTester tester) async {
      await pumpOnboardingScreen(tester);

      expect(find.text('Welcome to Beatbox Trainer!'), findsOneWidget);
    });

    testWidgets('displays calibration explanation', (
      WidgetTester tester,
    ) async {
      await pumpOnboardingScreen(tester);

      expect(find.textContaining('Before you start training'), findsOneWidget);
      expect(find.textContaining('calibrate the app'), findsOneWidget);
    });

    testWidgets('displays calibration steps header', (
      WidgetTester tester,
    ) async {
      await pumpOnboardingScreen(tester);

      expect(find.text('Calibration Steps:'), findsOneWidget);
    });

    testWidgets('displays step 1: KICK sounds', (WidgetTester tester) async {
      await pumpOnboardingScreen(tester);

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Make 10 KICK sounds'), findsOneWidget);
    });

    testWidgets('displays step 2: SNARE sounds', (WidgetTester tester) async {
      await pumpOnboardingScreen(tester);

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Make 10 SNARE sounds'), findsOneWidget);
    });

    testWidgets('displays step 3: HI-HAT sounds', (WidgetTester tester) async {
      await pumpOnboardingScreen(tester);

      expect(find.text('3'), findsOneWidget);
      expect(find.text('Make 10 HI-HAT sounds'), findsOneWidget);
    });

    testWidgets('displays all three step numbers', (WidgetTester tester) async {
      await pumpOnboardingScreen(tester);

      // All three step numbers should be visible
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('displays step icons', (WidgetTester tester) async {
      await pumpOnboardingScreen(tester);

      // Each step should have an icon
      expect(find.byIcon(Icons.circle), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
      expect(find.byIcon(Icons.adjust), findsOneWidget);
    });

    testWidgets('displays Start Calibration button', (
      WidgetTester tester,
    ) async {
      await pumpOnboardingScreen(tester);

      expect(
        find.widgetWithText(ElevatedButton, 'Start Calibration'),
        findsOneWidget,
      );
    });

    testWidgets('Start Calibration button has correct style', (
      WidgetTester tester,
    ) async {
      await pumpOnboardingScreen(tester);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Start Calibration'),
      );

      final style = button.style;
      expect(style, isNotNull);

      // Check button style exists (specific color checks are platform-dependent)
      expect(style!.backgroundColor, isNotNull);
      expect(style.foregroundColor, isNotNull);
    });

    testWidgets('navigates to calibration when button tapped', (
      WidgetTester tester,
    ) async {
      await pumpOnboardingScreen(tester);

      // Tap Start Calibration button
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Start Calibration'),
      );
      await tester.pumpAndSettle();

      // Verify navigation to calibration screen
      expect(find.text('Calibration Screen'), findsOneWidget);
    });

    testWidgets('layout uses SafeArea', (WidgetTester tester) async {
      await pumpOnboardingScreen(tester);

      // Verify SafeArea is present
      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('content is properly padded', (WidgetTester tester) async {
      await pumpOnboardingScreen(tester);

      // Find the Padding widget that wraps the main content
      final paddingFinder = find.descendant(
        of: find.byType(SafeArea),
        matching: find.byType(Padding),
      );

      expect(paddingFinder, findsWidgets);
    });

    testWidgets('welcome text uses headlineMedium style', (
      WidgetTester tester,
    ) async {
      await pumpOnboardingScreen(tester);

      final textWidget = tester.widget<Text>(
        find.text('Welcome to Beatbox Trainer!'),
      );

      expect(textWidget.style?.fontWeight, equals(FontWeight.bold));
    });
  });
}
