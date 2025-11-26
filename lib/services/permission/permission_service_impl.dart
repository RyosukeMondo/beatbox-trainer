import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'i_permission_service.dart';

/// Concrete implementation of [IPermissionService] wrapping permission_handler.
///
/// This implementation provides microphone permission management by wrapping
/// the permission_handler package. It translates between permission_handler's
/// status types and our custom [PermissionStatus] enum.
///
/// Platform support:
/// - Android/iOS: Uses permission_handler for runtime permissions
/// - Linux/Windows/macOS: Returns granted (desktop platforms use system audio
///   permissions managed by the OS, not runtime permission dialogs)
///
/// Example usage:
/// ```dart
/// final permissionService = PermissionServiceImpl();
/// final status = await permissionService.checkMicrophonePermission();
/// if (status == PermissionStatus.denied) {
///   final newStatus = await permissionService.requestMicrophonePermission();
///   if (newStatus == PermissionStatus.permanentlyDenied) {
///     await permissionService.openAppSettings();
///   }
/// }
/// ```
class PermissionServiceImpl implements IPermissionService {
  /// Create a new permission service instance.
  ///
  /// No configuration required - uses permission_handler package directly.
  PermissionServiceImpl();

  /// Check if running on a desktop platform (Linux, Windows, macOS).
  ///
  /// Desktop platforms don't require runtime permission dialogs for microphone
  /// access - permissions are handled by the OS audio subsystem.
  bool get _isDesktopPlatform {
    if (kIsWeb) return false;
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  }

  @override
  Future<PermissionStatus> checkMicrophonePermission() async {
    // Desktop platforms don't use permission_handler - always granted
    if (_isDesktopPlatform) {
      return PermissionStatus.granted;
    }

    final status = await ph.Permission.microphone.status;
    return _convertStatus(status);
  }

  @override
  Future<PermissionStatus> requestMicrophonePermission() async {
    // Desktop platforms don't use permission_handler - always granted
    if (_isDesktopPlatform) {
      return PermissionStatus.granted;
    }

    final status = await ph.Permission.microphone.request();
    return _convertStatus(status);
  }

  @override
  Future<bool> openAppSettings() async {
    // Desktop platforms don't have app settings like mobile
    if (_isDesktopPlatform) {
      return false;
    }

    try {
      return await ph.openAppSettings();
    } catch (e) {
      // If opening settings fails, return false
      // This can happen on some devices or emulators
      return false;
    }
  }

  /// Convert permission_handler status to our custom [PermissionStatus].
  ///
  /// Maps permission_handler's status types to our simplified enum:
  /// - isGranted -> granted
  /// - isPermanentlyDenied -> permanentlyDenied
  /// - all other states (isDenied, isRestricted, isLimited) -> denied
  ///
  /// The isRestricted and isLimited states are iOS-specific and shouldn't
  /// occur on Android, but we treat them as denied for safety.
  PermissionStatus _convertStatus(ph.PermissionStatus status) {
    if (status.isGranted) {
      return PermissionStatus.granted;
    } else if (status.isPermanentlyDenied) {
      return PermissionStatus.permanentlyDenied;
    } else {
      // status.isDenied, status.isRestricted, or status.isLimited
      return PermissionStatus.denied;
    }
  }
}
