/// Permission service interface for dependency injection and testing.
///
/// This interface abstracts microphone permission management,
/// enabling dependency injection in screens and mocking in tests.
///
/// Wraps the permission_handler package with a consistent API.
abstract class IPermissionService {
  /// Check current microphone permission status without requesting.
  ///
  /// Query the current permission state without showing any system dialogs
  /// or prompts to the user.
  ///
  /// Returns:
  /// - [PermissionStatus.granted]: Microphone permission is granted
  /// - [PermissionStatus.denied]: Permission denied but can be requested
  /// - [PermissionStatus.permanentlyDenied]: Permission permanently denied,
  ///   user must go to app settings to grant permission
  ///
  /// Example:
  /// ```dart
  /// final status = await permissionService.checkMicrophonePermission();
  /// if (status == PermissionStatus.granted) {
  ///   // Can use microphone
  /// }
  /// ```
  Future<PermissionStatus> checkMicrophonePermission();

  /// Request microphone permission from user.
  ///
  /// Shows system permission dialog asking user to grant microphone access.
  /// Should only be called if permission is not already granted.
  ///
  /// Returns:
  /// - [PermissionStatus.granted]: User granted permission
  /// - [PermissionStatus.denied]: User denied permission this time
  /// - [PermissionStatus.permanentlyDenied]: User denied and selected "Don't ask again"
  ///
  /// Example:
  /// ```dart
  /// final status = await permissionService.requestMicrophonePermission();
  /// switch (status) {
  ///   case PermissionStatus.granted:
  ///     // Permission granted, can use microphone
  ///     break;
  ///   case PermissionStatus.denied:
  ///     // Show rationale and ask user to retry
  ///     break;
  ///   case PermissionStatus.permanentlyDenied:
  ///     // Direct user to app settings
  ///     break;
  /// }
  /// ```
  Future<PermissionStatus> requestMicrophonePermission();

  /// Open app settings page where user can grant permissions.
  ///
  /// Opens the platform-specific app settings screen where the user
  /// can manually enable microphone permission. Use this when permission
  /// is [PermissionStatus.permanentlyDenied].
  ///
  /// Returns:
  /// - true if settings page opened successfully
  /// - false if failed to open settings
  ///
  /// Example:
  /// ```dart
  /// if (status == PermissionStatus.permanentlyDenied) {
  ///   final opened = await permissionService.openAppSettings();
  ///   if (!opened) {
  ///     // Failed to open settings, show error
  ///   }
  /// }
  /// ```
  Future<bool> openAppSettings();
}

/// Permission status for microphone access.
///
/// Represents the three possible states of permission status:
/// - granted: Permission is granted, can use microphone
/// - denied: Permission denied, but can request again
/// - permanentlyDenied: Permission denied permanently, must use app settings
enum PermissionStatus {
  /// Microphone permission is granted.
  ///
  /// App can record audio from the microphone.
  granted,

  /// Microphone permission is denied.
  ///
  /// Permission was denied by user, but can be requested again.
  /// Show rationale explaining why permission is needed.
  denied,

  /// Microphone permission is permanently denied.
  ///
  /// User selected "Don't ask again" or denied multiple times.
  /// App cannot request permission again through system dialog.
  /// User must go to app settings to manually grant permission.
  permanentlyDenied,
}
