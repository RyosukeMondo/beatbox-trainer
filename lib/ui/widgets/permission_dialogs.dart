import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Dialog shown when microphone permission is denied
///
/// This dialog informs the user that microphone access is required
/// and prompts them to grant the permission.
class PermissionDeniedDialog extends StatelessWidget {
  const PermissionDeniedDialog({super.key});

  /// Static method to show the permission denied dialog
  ///
  /// Example:
  /// ```dart
  /// PermissionDeniedDialog.show(context);
  /// ```
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PermissionDeniedDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Microphone Permission Required'),
      content: const Text(
        'This app needs microphone access to detect your beatbox sounds. '
        'Please grant permission to continue.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Dialog shown when microphone permission is permanently denied
///
/// This dialog informs the user that microphone access is required
/// and provides an option to open app settings to enable the permission.
class PermissionSettingsDialog extends StatelessWidget {
  const PermissionSettingsDialog({super.key});

  /// Static method to show the permission settings dialog
  ///
  /// Example:
  /// ```dart
  /// PermissionSettingsDialog.show(context);
  /// ```
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PermissionSettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Microphone Permission Required'),
      content: const Text(
        'This app needs microphone access to detect your beatbox sounds. '
        'Please enable microphone permission in your device settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await openAppSettings();
          },
          child: const Text('Open Settings'),
        ),
      ],
    );
  }
}
