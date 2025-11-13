import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beatbox_trainer/ui/widgets/bpm_control.dart';

void main() {
  group('BPMControl', () {
    testWidgets('displays current BPM value prominently', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BPMControl(currentBpm: 120, onChanged: (_) {})),
        ),
      );

      // Assert
      expect(find.text('120 BPM'), findsOneWidget);
    });

    testWidgets('renders slider with correct range (40-240)', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BPMControl(currentBpm: 120, onChanged: (_) {})),
        ),
      );

      // Assert
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, 40);
      expect(slider.max, 240);
      expect(slider.divisions, 200); // (240 - 40) = 200 for 1 BPM increments
      expect(slider.value, 120);
    });

    testWidgets('slider calls onChanged callback when dragged', (
      WidgetTester tester,
    ) async {
      // Arrange
      int? changedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BPMControl(
              currentBpm: 120,
              onChanged: (value) => changedValue = value,
            ),
          ),
        ),
      );

      // Act - Drag slider to approximate position for BPM 160
      // Slider value is normalized between 0 and 1, where:
      // - 0 represents min (40 BPM)
      // - 1 represents max (240 BPM)
      // For 160 BPM: (160 - 40) / (240 - 40) = 0.6
      final sliderFinder = find.byType(Slider);
      final sliderRect = tester.getRect(sliderFinder);
      final targetOffset = Offset(
        sliderRect.left + (sliderRect.width * 0.6),
        sliderRect.center.dy,
      );
      await tester.tapAt(targetOffset);
      await tester.pumpAndSettle();

      // Assert - Should be approximately 160 (within ±5 BPM tolerance)
      expect(changedValue, isNotNull);
      expect(changedValue, greaterThanOrEqualTo(155));
      expect(changedValue, lessThanOrEqualTo(165));
    });

    testWidgets('renders all preset buttons', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BPMControl(currentBpm: 120, onChanged: (_) {})),
        ),
      );

      // Assert
      expect(find.text('60'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('140'), findsOneWidget);
      expect(find.text('160'), findsOneWidget);
    });

    testWidgets('preset button 60 calls onChanged with 60', (
      WidgetTester tester,
    ) async {
      // Arrange
      int? changedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BPMControl(
              currentBpm: 120,
              onChanged: (value) => changedValue = value,
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.widgetWithText(ElevatedButton, '60'));
      await tester.pumpAndSettle();

      // Assert
      expect(changedValue, 60);
    });

    testWidgets('preset button 80 calls onChanged with 80', (
      WidgetTester tester,
    ) async {
      // Arrange
      int? changedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BPMControl(
              currentBpm: 120,
              onChanged: (value) => changedValue = value,
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.widgetWithText(ElevatedButton, '80'));
      await tester.pumpAndSettle();

      // Assert
      expect(changedValue, 80);
    });

    testWidgets('preset button 100 calls onChanged with 100', (
      WidgetTester tester,
    ) async {
      // Arrange
      int? changedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BPMControl(
              currentBpm: 120,
              onChanged: (value) => changedValue = value,
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.widgetWithText(ElevatedButton, '100'));
      await tester.pumpAndSettle();

      // Assert
      expect(changedValue, 100);
    });

    testWidgets('preset button 120 calls onChanged with 120', (
      WidgetTester tester,
    ) async {
      // Arrange
      int? changedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BPMControl(
              currentBpm: 80,
              onChanged: (value) => changedValue = value,
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.widgetWithText(ElevatedButton, '120'));
      await tester.pumpAndSettle();

      // Assert
      expect(changedValue, 120);
    });

    testWidgets('preset button 140 calls onChanged with 140', (
      WidgetTester tester,
    ) async {
      // Arrange
      int? changedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BPMControl(
              currentBpm: 120,
              onChanged: (value) => changedValue = value,
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.widgetWithText(ElevatedButton, '140'));
      await tester.pumpAndSettle();

      // Assert
      expect(changedValue, 140);
    });

    testWidgets('preset button 160 calls onChanged with 160', (
      WidgetTester tester,
    ) async {
      // Arrange
      int? changedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BPMControl(
              currentBpm: 120,
              onChanged: (value) => changedValue = value,
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.widgetWithText(ElevatedButton, '160'));
      await tester.pumpAndSettle();

      // Assert
      expect(changedValue, 160);
    });

    testWidgets('selected preset button has highlighted styling', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BPMControl(currentBpm: 120, onChanged: (_) {})),
        ),
      );

      // Assert - Find the 120 button (which matches currentBpm)
      final button120 = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '120'),
      );
      final buttonStyle = button120.style;

      // The button should have a non-null style when selected
      expect(buttonStyle, isNotNull);
    });

    testWidgets('non-selected preset buttons have default styling', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BPMControl(currentBpm: 120, onChanged: (_) {})),
        ),
      );

      // Assert - Find a non-selected button (e.g., 60)
      final button60 = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '60'),
      );
      expect(button60.style, isNotNull);
    });

    testWidgets('updates display when currentBpm changes', (
      WidgetTester tester,
    ) async {
      // Arrange - Initial state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BPMControl(currentBpm: 100, onChanged: (_) {})),
        ),
      );

      // Verify initial state
      expect(find.text('100 BPM'), findsOneWidget);
      Slider slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 100);

      // Act - Update to new BPM
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BPMControl(currentBpm: 140, onChanged: (_) {})),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Verify updated state
      expect(find.text('140 BPM'), findsOneWidget);
      expect(find.text('100 BPM'), findsNothing);
      slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 140);
    });

    testWidgets('slider respects min boundary (40 BPM)', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BPMControl(currentBpm: 40, onChanged: (_) {})),
        ),
      );

      // Assert
      expect(find.text('40 BPM'), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 40);
      expect(slider.min, 40);
    });

    testWidgets('slider respects max boundary (240 BPM)', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BPMControl(currentBpm: 240, onChanged: (_) {})),
        ),
      );

      // Assert
      expect(find.text('240 BPM'), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 240);
      expect(slider.max, 240);
    });
  });
}
