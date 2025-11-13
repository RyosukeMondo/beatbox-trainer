import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beatbox_trainer/ui/screens/settings_screen.dart';
import '../../mocks.dart';

void main() {
  group('SettingsScreen', () {
    late MockSettingsService mockSettingsService;
    late MockStorageService mockStorageService;

    setUp(() {
      mockSettingsService = MockSettingsService();
      mockStorageService = MockStorageService();

      // Default mock responses for successful initialization
      when(() => mockSettingsService.init()).thenAnswer((_) async => {});
      when(() => mockStorageService.init()).thenAnswer((_) async => {});
      when(() => mockSettingsService.getBpm()).thenAnswer((_) async => 120);
      when(
        () => mockSettingsService.getDebugMode(),
      ).thenAnswer((_) async => false);
      when(
        () => mockSettingsService.getClassifierLevel(),
      ).thenAnswer((_) async => 1);
    });

    /// Helper function to pump SettingsScreen with mock dependencies
    Future<void> pumpSettingsScreen(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => SettingsScreen(
              settingsService: mockSettingsService,
              storageService: mockStorageService,
            ),
          ),
          GoRoute(
            path: '/calibration',
            builder: (context, state) =>
                const Scaffold(body: Text('Calibration Screen')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      // Wait for settings to load
      await tester.pumpAndSettle();
    }

    testWidgets('displays Settings title in AppBar', (
      WidgetTester tester,
    ) async {
      await pumpSettingsScreen(tester);

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('loads all settings correctly', (WidgetTester tester) async {
      await pumpSettingsScreen(tester);

      // Verify all services were initialized
      verify(() => mockSettingsService.init()).called(1);
      verify(() => mockStorageService.init()).called(1);
      verify(() => mockSettingsService.getBpm()).called(1);
      verify(() => mockSettingsService.getDebugMode()).called(1);
      verify(() => mockSettingsService.getClassifierLevel()).called(1);
    });

    testWidgets('displays default BPM value', (WidgetTester tester) async {
      await pumpSettingsScreen(tester);

      expect(find.text('Default BPM'), findsOneWidget);
      expect(find.text('120 BPM'), findsOneWidget);
    });

    testWidgets('displays BPM slider with correct range', (
      WidgetTester tester,
    ) async {
      await pumpSettingsScreen(tester);

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, equals(40));
      expect(slider.max, equals(240));
      expect(slider.divisions, equals(200));
      expect(slider.value, equals(120));
    });

    testWidgets('displays BPM range labels', (WidgetTester tester) async {
      await pumpSettingsScreen(tester);

      // Find text widgets showing min and max values
      expect(find.text('40'), findsOneWidget);
      expect(find.text('240'), findsOneWidget);
    });

    testWidgets('updates BPM when slider is changed', (
      WidgetTester tester,
    ) async {
      when(() => mockSettingsService.setBpm(any())).thenAnswer((_) async => {});

      await pumpSettingsScreen(tester);

      // Drag slider to new position
      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pumpAndSettle();

      // BPM display should have changed (exact value depends on drag amount)
      expect(find.text('120 BPM'), findsNothing);
    });

    testWidgets('saves BPM when slider change ends', (
      WidgetTester tester,
    ) async {
      when(() => mockSettingsService.setBpm(any())).thenAnswer((_) async => {});

      await pumpSettingsScreen(tester);

      // Drag slider and release
      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(100, 0));
      await tester.pumpAndSettle();

      // Verify setBpm was called with new value
      verify(() => mockSettingsService.setBpm(any())).called(greaterThan(0));
    });

    testWidgets('shows error dialog when BPM save fails', (
      WidgetTester tester,
    ) async {
      when(
        () => mockSettingsService.setBpm(any()),
      ).thenThrow(Exception('Failed to save BPM'));

      await pumpSettingsScreen(tester);

      // Drag slider to trigger save
      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pumpAndSettle();

      // Verify error dialog is shown
      expect(find.text('Error'), findsOneWidget);
      expect(find.textContaining('Failed to save BPM'), findsOneWidget);
    });

    testWidgets('displays debug mode switch', (WidgetTester tester) async {
      await pumpSettingsScreen(tester);

      expect(find.text('Debug Mode'), findsOneWidget);
      expect(
        find.textContaining('Show real-time audio metrics'),
        findsOneWidget,
      );
    });

    testWidgets('debug mode switch reflects current state', (
      WidgetTester tester,
    ) async {
      // Test with debug mode enabled
      when(
        () => mockSettingsService.getDebugMode(),
      ).thenAnswer((_) async => true);

      await pumpSettingsScreen(tester);

      final switchTile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Debug Mode'),
      );
      expect(switchTile.value, isTrue);
    });

    testWidgets('toggles debug mode when switch is changed', (
      WidgetTester tester,
    ) async {
      when(
        () => mockSettingsService.setDebugMode(any()),
      ).thenAnswer((_) async => {});

      await pumpSettingsScreen(tester);

      // Tap the debug mode switch
      await tester.tap(find.widgetWithText(SwitchListTile, 'Debug Mode'));
      await tester.pumpAndSettle();

      // Verify setDebugMode was called with true
      verify(() => mockSettingsService.setDebugMode(true)).called(1);
    });

    testWidgets('shows error dialog when debug mode save fails', (
      WidgetTester tester,
    ) async {
      when(
        () => mockSettingsService.setDebugMode(any()),
      ).thenThrow(Exception('Failed to save debug mode'));

      await pumpSettingsScreen(tester);

      // Tap the debug mode switch
      await tester.tap(find.widgetWithText(SwitchListTile, 'Debug Mode'));
      await tester.pumpAndSettle();

      // Verify error dialog is shown
      expect(find.text('Error'), findsOneWidget);
      expect(find.textContaining('Failed to save debug mode'), findsOneWidget);
    });

    testWidgets('displays advanced mode switch', (WidgetTester tester) async {
      await pumpSettingsScreen(tester);

      expect(find.text('Advanced Mode'), findsOneWidget);
      expect(find.textContaining('Beginner (3 categories'), findsOneWidget);
    });

    testWidgets('advanced mode subtitle shows correct level description', (
      WidgetTester tester,
    ) async {
      // Test level 1 (beginner)
      when(
        () => mockSettingsService.getClassifierLevel(),
      ).thenAnswer((_) async => 1);

      await pumpSettingsScreen(tester);

      expect(find.textContaining('Beginner (3 categories'), findsOneWidget);

      // Test level 2 (advanced)
      when(
        () => mockSettingsService.getClassifierLevel(),
      ).thenAnswer((_) async => 2);

      // Recreate screen with new mock values
      await tester.pumpWidget(Container()); // Clear widget tree
      await pumpSettingsScreen(tester);

      expect(find.textContaining('Advanced (6 categories'), findsOneWidget);
    });

    testWidgets('cancels level change when Cancel is tapped', (
      WidgetTester tester,
    ) async {
      await pumpSettingsScreen(tester);

      // Tap advanced mode switch
      await tester.tap(find.widgetWithText(SwitchListTile, 'Advanced Mode'));
      await tester.pumpAndSettle();

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify setClassifierLevel was not called
      verifyNever(() => mockSettingsService.setClassifierLevel(any()));
      verifyNever(() => mockStorageService.clearCalibration());
    });

    testWidgets('displays recalibrate button', (WidgetTester tester) async {
      await pumpSettingsScreen(tester);

      expect(find.text('Recalibrate'), findsOneWidget);
      expect(find.textContaining('Clear current calibration'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('shows confirmation dialog when recalibrate is tapped', (
      WidgetTester tester,
    ) async {
      await pumpSettingsScreen(tester);

      // Tap recalibrate button
      await tester.tap(find.text('Recalibrate').last);
      await tester.pumpAndSettle();

      // Verify confirmation dialog is shown
      expect(find.text('Confirm Recalibration'), findsOneWidget);
      expect(
        find.textContaining('Are you sure you want to recalibrate'),
        findsOneWidget,
      );
    });

    testWidgets('cancels recalibration when Cancel is tapped', (
      WidgetTester tester,
    ) async {
      await pumpSettingsScreen(tester);

      // Tap recalibrate button
      await tester.tap(find.text('Recalibrate').last);
      await tester.pumpAndSettle();

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify clearCalibration was not called
      verifyNever(() => mockStorageService.clearCalibration());
    });

    testWidgets(
      'clears calibration and navigates when recalibrate is confirmed',
      (WidgetTester tester) async {
        when(
          () => mockStorageService.clearCalibration(),
        ).thenAnswer((_) async => {});

        await pumpSettingsScreen(tester);

        // Tap recalibrate button
        await tester.tap(find.text('Recalibrate').last);
        await tester.pumpAndSettle();

        // Tap Recalibrate button in dialog (find the second one, in the dialog)
        final recalibrateButtons = find.text('Recalibrate');
        await tester.tap(recalibrateButtons.at(1));
        await tester.pumpAndSettle();

        // Verify calibration was cleared
        verify(() => mockStorageService.clearCalibration()).called(1);

        // Verify navigation to calibration screen
        expect(find.text('Calibration Screen'), findsOneWidget);
      },
    );

    testWidgets('shows error dialog when recalibration fails', (
      WidgetTester tester,
    ) async {
      when(
        () => mockStorageService.clearCalibration(),
      ).thenThrow(Exception('Failed to clear calibration'));

      await pumpSettingsScreen(tester);

      // Tap recalibrate button
      await tester.tap(find.text('Recalibrate').last);
      await tester.pumpAndSettle();

      // Confirm recalibration
      final recalibrateButtons = find.text('Recalibrate');
      await tester.tap(recalibrateButtons.at(1));
      await tester.pumpAndSettle();

      // Verify error dialog is shown
      expect(find.text('Error'), findsOneWidget);
      expect(
        find.textContaining('Failed to clear calibration'),
        findsOneWidget,
      );
    });

    testWidgets('uses ListView for scrollable settings', (
      WidgetTester tester,
    ) async {
      await pumpSettingsScreen(tester);

      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
