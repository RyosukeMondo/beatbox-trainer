import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beatbox_trainer/ui/widgets/timing_feedback_widget.dart';
import 'package:beatbox_trainer/models/classification_result.dart';
import 'package:beatbox_trainer/models/timing_feedback.dart';

void main() {
  group('TimingFeedbackWidget', () {
    testWidgets('displays idle state with "---" when result is null', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TimingFeedbackWidget(result: null)),
        ),
      );

      // Assert
      expect(find.text('---'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.grey);
    });

    testWidgets('displays "0.0ms ON-TIME" in green when timing is on-time', (
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
          home: Scaffold(body: TimingFeedbackWidget(result: result)),
        ),
      );

      // Assert
      expect(find.text('0.0ms ON-TIME'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.green);
    });

    testWidgets('displays "+12.5ms LATE" in amber when timing is late', (
      WidgetTester tester,
    ) async {
      // Arrange
      const result = ClassificationResult(
        sound: BeatboxHit.kick,
        timing: TimingFeedback(
          classification: TimingClassification.late,
          errorMs: 12.5,
        ),
        timestampMs: 1000,
              confidence: 0.95,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TimingFeedbackWidget(result: result)),
        ),
      );

      // Assert
      expect(find.text('+12.5ms LATE'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.amber);
    });

    testWidgets('displays "-5.0ms EARLY" in amber when timing is early', (
      WidgetTester tester,
    ) async {
      // Arrange
      const result = ClassificationResult(
        sound: BeatboxHit.kick,
        timing: TimingFeedback(
          classification: TimingClassification.early,
          errorMs: -5.0,
        ),
        timestampMs: 1000,
              confidence: 0.95,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TimingFeedbackWidget(result: result)),
        ),
      );

      // Assert
      expect(find.text('-5.0ms EARLY'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.amber);
    });

    testWidgets('formats positive error correctly with + sign', (
      WidgetTester tester,
    ) async {
      // Arrange
      const result = ClassificationResult(
        sound: BeatboxHit.kick,
        timing: TimingFeedback(
          classification: TimingClassification.late,
          errorMs: 25.7,
        ),
        timestampMs: 1000,
              confidence: 0.95,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TimingFeedbackWidget(result: result)),
        ),
      );

      // Assert
      expect(find.text('+25.7ms LATE'), findsOneWidget);
    });

    testWidgets('formats negative error correctly without extra sign', (
      WidgetTester tester,
    ) async {
      // Arrange
      const result = ClassificationResult(
        sound: BeatboxHit.kick,
        timing: TimingFeedback(
          classification: TimingClassification.early,
          errorMs: -15.3,
        ),
        timestampMs: 1000,
              confidence: 0.95,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TimingFeedbackWidget(result: result)),
        ),
      );

      // Assert
      expect(find.text('-15.3ms EARLY'), findsOneWidget);
    });

    testWidgets('rounds error to 1 decimal place', (WidgetTester tester) async {
      // Arrange
      const result = ClassificationResult(
        sound: BeatboxHit.kick,
        timing: TimingFeedback(
          classification: TimingClassification.late,
          errorMs: 12.56789,
        ),
        timestampMs: 1000,
              confidence: 0.95,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TimingFeedbackWidget(result: result)),
        ),
      );

      // Assert
      expect(find.text('+12.6ms LATE'), findsOneWidget);
    });

    testWidgets('updates display immediately when result changes', (
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
          home: Scaffold(body: TimingFeedbackWidget(result: initialResult)),
        ),
      );

      // Verify initial state
      expect(find.text('0.0ms ON-TIME'), findsOneWidget);
      Container container = tester.widget<Container>(
        find.byType(Container).first,
      );
      BoxDecoration decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.green);

      // Act - Update to new result
      const newResult = ClassificationResult(
        sound: BeatboxHit.kick,
        timing: TimingFeedback(
          classification: TimingClassification.late,
          errorMs: 15.0,
        ),
        timestampMs: 2000,
              confidence: 0.95,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TimingFeedbackWidget(result: newResult)),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Verify updated state
      expect(find.text('+15.0ms LATE'), findsOneWidget);
      expect(find.text('0.0ms ON-TIME'), findsNothing);
      container = tester.widget<Container>(find.byType(Container).first);
      decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.amber);
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
          home: Scaffold(body: TimingFeedbackWidget(result: result)),
        ),
      );

      // Assert
      final textWidget = tester.widget<Text>(find.text('0.0ms ON-TIME'));
      expect(textWidget.style?.fontSize, 32);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
      expect(textWidget.style?.color, Colors.white);
    });

    testWidgets('handles null result transition to valid result correctly', (
      WidgetTester tester,
    ) async {
      // Arrange - Start with null
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TimingFeedbackWidget(result: null)),
        ),
      );

      expect(find.text('---'), findsOneWidget);

      // Act - Transition to valid result
      const result = ClassificationResult(
        sound: BeatboxHit.kick,
        timing: TimingFeedback(
          classification: TimingClassification.late,
          errorMs: 10.0,
        ),
        timestampMs: 1000,
              confidence: 0.95,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TimingFeedbackWidget(result: result)),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('+10.0ms LATE'), findsOneWidget);
      expect(find.text('---'), findsNothing);
    });
  });
}
