import 'package:flutter/material.dart';

/// A reusable error dialog widget that displays error messages
/// with consistent styling and optional actions.
///
/// This widget provides a standardized way to show errors throughout
/// the application, ensuring consistent user experience.
class ErrorDialog extends StatelessWidget {
  /// The title of the error dialog
  final String title;

  /// The error message to display
  final String message;

  /// Optional callback for retry action
  final VoidCallback? onRetry;

  /// Optional callback for cancel action
  final VoidCallback? onCancel;

  const ErrorDialog({
    super.key,
    this.title = 'Error',
    required this.message,
    this.onRetry,
    this.onCancel,
  });

  /// Static method to show the error dialog
  ///
  /// Example:
  /// ```dart
  /// ErrorDialog.show(
  ///   context,
  ///   message: 'Failed to start audio',
  ///   onRetry: () => _retryAudio(),
  /// );
  /// ```
  static Future<void> show(
    BuildContext context, {
    String title = 'Error',
    required String message,
    VoidCallback? onRetry,
    VoidCallback? onCancel,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        onRetry: onRetry,
        onCancel: onCancel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: _buildActions(context),
    );
  }

  /// Build action buttons based on provided callbacks
  List<Widget> _buildActions(BuildContext context) {
    final actions = <Widget>[];

    // Add cancel button if callback provided
    if (onCancel != null) {
      actions.add(
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCancel!();
          },
          child: const Text('Cancel'),
        ),
      );
    }

    // Add retry button if callback provided
    if (onRetry != null) {
      actions.add(
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onRetry!();
          },
          child: const Text('Retry'),
        ),
      );
    }

    // If no specific actions, add default OK button
    if (actions.isEmpty) {
      actions.add(
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      );
    }

    return actions;
  }
}
