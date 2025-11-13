import 'package:mocktail/mocktail.dart';
import 'package:beatbox_trainer/services/audio/i_audio_service.dart';
import 'package:beatbox_trainer/services/storage/i_storage_service.dart';
import 'package:beatbox_trainer/services/settings/i_settings_service.dart';
import 'package:beatbox_trainer/services/debug/i_debug_service.dart';
import 'package:beatbox_trainer/services/permission/i_permission_service.dart';

/// Centralized mock classes for testing.
///
/// This file contains all mock implementations of service interfaces,
/// following the mocktail pattern. These mocks are used throughout the
/// test suite for dependency injection and behavior verification.
///
/// Usage:
/// ```dart
/// import 'package:beatbox_trainer/test/mocks.dart';
///
/// void main() {
///   late MockAudioService mockAudioService;
///
///   setUp(() {
///     mockAudioService = MockAudioService();
///   });
///
///   test('example test', () async {
///     when(() => mockAudioService.startAudio(bpm: any(named: 'bpm')))
///         .thenAnswer((_) async => {});
///     // Test code...
///   });
/// }
/// ```

/// Mock implementation of [IAudioService] for testing.
///
/// Use this mock to test components that depend on audio service
/// functionality without requiring the actual Rust FFI bridge.
class MockAudioService extends Mock implements IAudioService {}

/// Mock implementation of [IStorageService] for testing.
///
/// Use this mock to test components that depend on storage service
/// functionality without requiring actual SharedPreferences.
class MockStorageService extends Mock implements IStorageService {}

/// Mock implementation of [ISettingsService] for testing.
///
/// Use this mock to test components that depend on settings service
/// functionality without requiring actual SharedPreferences.
class MockSettingsService extends Mock implements ISettingsService {}

/// Mock implementation of [IDebugService] for testing.
///
/// Use this mock to test components that depend on debug service
/// functionality without requiring the actual Rust FFI debug streams.
class MockDebugService extends Mock implements IDebugService {}

/// Mock implementation of [IPermissionService] for testing.
///
/// Use this mock to test components that depend on permission service
/// functionality without requiring actual permission_handler package.
class MockPermissionService extends Mock implements IPermissionService {}
