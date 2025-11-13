import 'package:beatbox_trainer/ui/widgets/error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorDialog', () {
    testWidgets('displays title and message', (WidgetTester tester) async {
      // Arrange
      const title = 'Test Error';
      const message = 'This is a test error message';

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ErrorDialog.show(
                  context,
                  title: title,
                  message: message,
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text(title), findsOneWidget);
      expect(find.text(message), findsOneWidget);
    });

    testWidgets('displays default title when not provided',
        (WidgetTester tester) async {
      // Arrange
      const message = 'This is a test error message';

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ErrorDialog.show(
                  context,
                  message: message,
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Error'), findsOneWidget);
      expect(find.text(message), findsOneWidget);
    });

    testWidgets('displays OK button when no callbacks provided',
        (WidgetTester tester) async {
      // Arrange
      const message = 'This is a test error message';

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ErrorDialog.show(
                  context,
                  message: message,
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('displays Retry button when onRetry provided',
        (WidgetTester tester) async {
      // Arrange
      const message = 'This is a test error message';
      var retryCallbackCalled = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ErrorDialog.show(
                  context,
                  message: message,
                  onRetry: () => retryCallbackCalled = true,
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('OK'), findsNothing);

      // Act - tap retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Assert - callback was called
      expect(retryCallbackCalled, isTrue);
    });

    testWidgets('displays Cancel button when onCancel provided',
        (WidgetTester tester) async {
      // Arrange
      const message = 'This is a test error message';
      var cancelCallbackCalled = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ErrorDialog.show(
                  context,
                  message: message,
                  onCancel: () => cancelCallbackCalled = true,
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Cancel'), findsOneWidget);

      // Act - tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert - callback was called
      expect(cancelCallbackCalled, isTrue);
    });

    testWidgets('displays both Retry and Cancel when both callbacks provided',
        (WidgetTester tester) async {
      // Arrange
      const message = 'This is a test error message';

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ErrorDialog.show(
                  context,
                  message: message,
                  onRetry: () {},
                  onCancel: () {},
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('OK'), findsNothing);
    });

    testWidgets('closes dialog when OK button is tapped',
        (WidgetTester tester) async {
      // Arrange
      const message = 'This is a test error message';

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ErrorDialog.show(
                  context,
                  message: message,
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Assert dialog is open
      expect(find.byType(AlertDialog), findsOneWidget);

      // Act - tap OK
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Assert - dialog is closed
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('closes dialog when Retry button is tapped',
        (WidgetTester tester) async {
      // Arrange
      const message = 'This is a test error message';

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ErrorDialog.show(
                  context,
                  message: message,
                  onRetry: () {},
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Assert dialog is open
      expect(find.byType(AlertDialog), findsOneWidget);

      // Act - tap Retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Assert - dialog is closed
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('can use widget directly without show method',
        (WidgetTester tester) async {
      // Arrange
      const title = 'Direct Error';
      const message = 'Direct error message';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorDialog(
              title: title,
              message: message,
            ),
          ),
        ),
      );

      // Assert
      expect(find.text(title), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });
  });
}
