import 'package:permission_handler/permission_handler.dart' as ph;
import 'i_permission_service.dart';

/// Concrete implementation of [IPermissionService] wrapping permission_handler.
///
/// This implementation provides microphone permission management by wrapping
/// the permission_handler package. It translates between permission_handler's
/// status types and our custom [PermissionStatus] enum.
///
/// Supports Android platform with microphone permission handling.
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

  @override
  Future<PermissionStatus> checkMicrophonePermission() async {
    final status = await ph.Permission.microphone.status;
    return _convertStatus(status);
  }

  @override
  Future<PermissionStatus> requestMicrophonePermission() async {
    final status = await ph.Permission.microphone.request();
    return _convertStatus(status);
  }

  @override
  Future<bool> openAppSettings() async {
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
