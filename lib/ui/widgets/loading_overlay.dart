import 'package:flutter/material.dart';

/// A reusable loading overlay widget that displays a centered spinner
/// with an optional message.
///
/// This widget is designed to be used as a loading state indicator across
/// the application, providing visual feedback during asynchronous operations.
///
/// Example usage:
/// ```dart
/// LoadingOverlay(message: 'Loading data...')
/// ```
class LoadingOverlay extends StatelessWidget {
  /// Creates a loading overlay with an optional message.
  ///
  /// The [message] parameter allows customizing the text displayed below
  /// the loading spinner. If null, a default message is shown.
  const LoadingOverlay({super.key, this.message});

  /// Optional message to display below the loading spinner.
  ///
  /// If null, a default message ('Loading...') will be shown.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            message ?? 'Loading...',
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
