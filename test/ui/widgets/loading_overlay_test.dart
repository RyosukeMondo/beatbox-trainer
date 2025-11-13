import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beatbox_trainer/ui/widgets/loading_overlay.dart';

void main() {
  group('LoadingOverlay', () {
    testWidgets('displays CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingOverlay())),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays default message when message is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingOverlay())),
      );

      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('displays custom message when provided', (tester) async {
      const customMessage = 'Initializing calibration...';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingOverlay(message: customMessage)),
        ),
      );

      expect(find.text(customMessage), findsOneWidget);
      expect(find.text('Loading...'), findsNothing);
    });

    testWidgets('displays message with correct styling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingOverlay())),
      );

      final textWidget = tester.widget<Text>(find.text('Loading...'));
      expect(textWidget.style?.fontSize, 18);
      expect(textWidget.textAlign, TextAlign.center);
    });

    testWidgets('centers content vertically and horizontally', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingOverlay())),
      );

      final centerWidget = tester.widget<Center>(find.byType(Center));
      expect(centerWidget, isNotNull);

      final columnWidget = tester.widget<Column>(find.byType(Column));
      expect(columnWidget.mainAxisAlignment, MainAxisAlignment.center);
    });

    testWidgets('has correct spacing between spinner and text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingOverlay())),
      );

      final column = tester.widget<Column>(find.byType(Column));
      final sizedBox = column.children[1] as SizedBox;
      expect(sizedBox.height, 24);
    });
  });
}
