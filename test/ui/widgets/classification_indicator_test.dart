import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beatbox_trainer/ui/widgets/classification_indicator.dart';
import 'package:beatbox_trainer/models/classification_result.dart';
import 'package:beatbox_trainer/models/timing_feedback.dart';

void main() {
  group('ClassificationIndicator', () {
    testWidgets('displays idle state with "---" when result is null', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClassificationIndicator(result: null)),
        ),
      );

      // Assert
      expect(find.text('---'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.grey);
    });

    testWidgets('displays KICK in red container when sound is kick', (
      WidgetTester tester,
    ) async {
      // Arrange
      const result = ClassificationResult(
        sound: BeatboxHit.kick,
        timing: TimingFeedback(
          classification: TimingClassification.onTime,
          errorMs: 0.0,
        ),
        timestampMs: 1000,
        confidence: 0.95,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClassificationIndicator(result: result)),
        ),
      );

      // Assert
      expect(find.text('KICK'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.red);
    });

    testWidgets('displays SNARE in blue container when sound is snare', (
      WidgetTester tester,
    ) async {
      // Arrange
      const result = ClassificationResult(
        sound: BeatboxHit.snare,
        timing: TimingFeedback(
          classification: TimingClassification.onTime,
          errorMs: 0.0,
        ),
        timestampMs: 1000,
        confidence: 0.95,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClassificationIndicator(result: result)),
        ),
      );

      // Assert
      expect(find.text('SNARE'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.blue);
    });

    testWidgets('displays HI-HAT in green container when sound is hiHat', (
      WidgetTester tester,
    ) async {
      // Arrange
      const result = ClassificationResult(
        sound: BeatboxHit.hiHat,
        timing: TimingFeedback(
          classification: TimingClassification.onTime,
          errorMs: 0.0,
        ),
        timestampMs: 1000,
        confidence: 0.95,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClassificationIndicator(result: result)),
        ),
      );

      // Assert
      expect(find.text('HI-HAT'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.green);
    });

    testWidgets(
      'displays CLOSED HI-HAT in green container when sound is closedHiHat',
      (WidgetTester tester) async {
        // Arrange
        const result = ClassificationResult(
          sound: BeatboxHit.closedHiHat,
          timing: TimingFeedback(
            classification: TimingClassification.onTime,
            errorMs: 0.0,
          ),
          timestampMs: 1000,
          confidence: 0.95,
        );

        // Act
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: ClassificationIndicator(result: result)),
          ),
        );

        // Assert
        expect(find.text('CLOSED HI-HAT'), findsOneWidget);
        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, Colors.green);
      },
    );

    testWidgets(
      'displays OPEN HI-HAT in green container when sound is openHiHat',
      (WidgetTester tester) async {
        // Arrange
        const result = ClassificationResult(
          sound: BeatboxHit.openHiHat,
          timing: TimingFeedback(
            classification: TimingClassification.onTime,
            errorMs: 0.0,
          ),
          timestampMs: 1000,
          confidence: 0.95,
        );

        // Act
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: ClassificationIndicator(result: result)),
          ),
        );

        // Assert
        expect(find.text('OPEN HI-HAT'), findsOneWidget);
        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, Colors.green);
      },
    );

    testWidgets('displays K-SNARE in purple container when sound is kSnare', (
      WidgetTester tester,
    ) async {
      // Arrange
      const result = ClassificationResult(
        sound: BeatboxHit.kSnare,
        timing: TimingFeedback(
          classification: TimingClassification.onTime,
          errorMs: 0.0,
        ),
        timestampMs: 1000,
        confidence: 0.95,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClassificationIndicator(result: result)),
        ),
      );

      // Assert
      expect(find.text('K-SNARE'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.purple);
    });

    testWidgets('displays UNKNOWN in grey container when sound is unknown', (
      WidgetTester tester,
    ) async {
      // Arrange
      const result = ClassificationResult(
        sound: BeatboxHit.unknown,
        timing: TimingFeedback(
          classification: TimingClassification.onTime,
          errorMs: 0.0,
        ),
        timestampMs: 1000,
        confidence: 0.95,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClassificationIndicator(result: result)),
        ),
      );

      // Assert
      expect(find.text('UNKNOWN'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.grey);
    });

    testWidgets('updates display when result changes', (
      WidgetTester tester,
    ) async {
      // Arrange - Initial state
      const initialResult = ClassificationResult(
        sound: BeatboxHit.kick,
        timing: TimingFeedback(
          classification: TimingClassification.onTime,
          errorMs: 0.0,
        ),
        timestampMs: 1000,
        confidence: 0.95,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClassificationIndicator(result: initialResult)),
        ),
      );

      // Verify initial state
      expect(find.text('KICK'), findsOneWidget);
      Container container = tester.widget<Container>(
        find.byType(Container).first,
      );
      BoxDecoration decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.red);

      // Act - Update to new result
      const newResult = ClassificationResult(
        sound: BeatboxHit.snare,
        timing: TimingFeedback(
          classification: TimingClassification.onTime,
          errorMs: 0.0,
        ),
        timestampMs: 2000,
        confidence: 0.95,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClassificationIndicator(result: newResult)),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Verify updated state
      expect(find.text('SNARE'), findsOneWidget);
      expect(find.text('KICK'), findsNothing);
      container = tester.widget<Container>(find.byType(Container).first);
      decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.blue);
    });

    testWidgets('displays text with correct styling', (
      WidgetTester tester,
    ) async {
      // Arrange
      const result = ClassificationResult(
        sound: BeatboxHit.kick,
        timing: TimingFeedback(
          classification: TimingClassification.onTime,
          errorMs: 0.0,
        ),
        timestampMs: 1000,
        confidence: 0.95,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClassificationIndicator(result: result)),
        ),
      );

      // Assert
      final textWidget = tester.widget<Text>(find.text('KICK'));
      expect(textWidget.style?.fontSize, 48);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
      expect(textWidget.style?.color, Colors.white);
    });
  });
}
