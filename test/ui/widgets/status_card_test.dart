import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beatbox_trainer/ui/widgets/status_card.dart';

void main() {
  group('StatusCard', () {
    testWidgets('displays icon with correct color and size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusCard(
              color: Colors.green,
              icon: Icons.check_circle,
              title: 'Success',
            ),
          ),
        ),
      );

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(iconWidget.color, Colors.green);
      expect(iconWidget.size, 32.0);
    });

    testWidgets('displays custom icon size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusCard(
              color: Colors.green,
              icon: Icons.celebration,
              title: 'Complete',
              iconSize: 48.0,
            ),
          ),
        ),
      );

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.celebration));
      expect(iconWidget.size, 48.0);
    });

    testWidgets('displays title with correct styling', (tester) async {
      const titleText = 'Test Title';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusCard(
              color: Colors.blue,
              icon: Icons.info,
              title: titleText,
            ),
          ),
        ),
      );

      expect(find.text(titleText), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text(titleText));
      expect(textWidget.style?.fontSize, 18);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
      expect(textWidget.style?.color, Colors.blue);
      expect(textWidget.textAlign, TextAlign.center);
    });

    testWidgets('displays subtitle when provided', (tester) async {
      const titleText = 'Title';
      const subtitleText = 'Subtitle content';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusCard(
              color: Colors.red,
              icon: Icons.error,
              title: titleText,
              subtitle: subtitleText,
            ),
          ),
        ),
      );

      expect(find.text(titleText), findsOneWidget);
      expect(find.text(subtitleText), findsOneWidget);

      final subtitleWidget = tester.widget<Text>(find.text(subtitleText));
      expect(subtitleWidget.style?.fontSize, 14);
      expect(subtitleWidget.textAlign, TextAlign.center);
    });

    testWidgets('does not display subtitle when null', (tester) async {
      const titleText = 'Title Only';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusCard(
              color: Colors.green,
              icon: Icons.check,
              title: titleText,
            ),
          ),
        ),
      );

      expect(find.text(titleText), findsOneWidget);
      // Only one Text widget should be present (the title)
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('container has correct decoration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusCard(
              color: Colors.green,
              icon: Icons.check,
              title: 'Test',
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(StatusCard),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.green.withValues(alpha: 0.1));
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(decoration.border, isA<Border>());

      final border = decoration.border as Border;
      expect(border.top.color, Colors.green);
      expect(border.top.width, 2);
    });

    testWidgets('has correct padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusCard(
              color: Colors.green,
              icon: Icons.check,
              title: 'Test',
            ),
          ),
        ),
      );

      final outerPadding = tester.widget<Padding>(
        find.ancestor(
          of: find.byType(Container),
          matching: find.byType(Padding),
        ).first,
      );
      expect(
        outerPadding.padding,
        const EdgeInsets.symmetric(horizontal: 32.0),
      );

      final container = tester.widget<Container>(
        find.byType(Container),
      );
      expect(container.padding, const EdgeInsets.all(16));
    });

    testWidgets('displays with green success styling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusCard(
              color: Colors.green,
              icon: Icons.check_circle,
              title: 'Success!',
              subtitle: 'Operation completed',
            ),
          ),
        ),
      );

      expect(find.text('Success!'), findsOneWidget);
      expect(find.text('Operation completed'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('displays with red error styling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusCard(
              color: Colors.red,
              icon: Icons.error_outline,
              title: 'Error',
              subtitle: 'Something went wrong',
            ),
          ),
        ),
      );

      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
