import 'package:beatbox_trainer/ui/widgets/permission_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionDeniedDialog', () {
    testWidgets('displays correct title and message',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PermissionDeniedDialog.show(context),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Microphone Permission Required'), findsOneWidget);
      expect(
        find.text(
          'This app needs microphone access to detect your beatbox sounds. '
          'Please grant permission to continue.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays OK button', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PermissionDeniedDialog.show(context),
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
    });

    testWidgets('closes dialog when OK button is tapped',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PermissionDeniedDialog.show(context),
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

    testWidgets('can use widget directly without show method',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PermissionDeniedDialog(),
          ),
        ),
      );

      // Assert
      expect(find.text('Microphone Permission Required'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });
  });

  group('PermissionSettingsDialog', () {
    testWidgets('displays correct title and message',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PermissionSettingsDialog.show(context),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Microphone Permission Required'), findsOneWidget);
      expect(
        find.text(
          'This app needs microphone access to detect your beatbox sounds. '
          'Please enable microphone permission in your device settings.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays Cancel and Open Settings buttons',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PermissionSettingsDialog.show(context),
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
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('closes dialog when Cancel button is tapped',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PermissionSettingsDialog.show(context),
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

      // Act - tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert - dialog is closed
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('closes dialog when Open Settings button is tapped',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PermissionSettingsDialog.show(context),
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

      // Act - tap Open Settings
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Assert - dialog is closed
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('can use widget directly without show method',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PermissionSettingsDialog(),
          ),
        ),
      );

      // Assert
      expect(find.text('Microphone Permission Required'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
    });
  });
}
