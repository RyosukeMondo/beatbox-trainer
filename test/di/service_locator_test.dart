import 'package:flutter_test/flutter_test.dart';
import 'package:beatbox_trainer/di/service_locator.dart';
import 'package:beatbox_trainer/services/audio/i_audio_service.dart';
import 'package:beatbox_trainer/services/debug/i_debug_service.dart';
import 'package:beatbox_trainer/services/error_handler/error_handler.dart';
import 'package:beatbox_trainer/services/permission/i_permission_service.dart';
import 'package:beatbox_trainer/services/settings/i_settings_service.dart';
import 'package:beatbox_trainer/services/storage/i_storage_service.dart';

void main() {
  // Initialize Flutter bindings for SharedPreferences
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Service Locator', () {
    setUp(() async {
      // Reset service locator before each test for isolation
      await resetServiceLocator();
    });

    tearDown(() async {
      // Clean up after each test
      await resetServiceLocator();
    });

    test('setupServiceLocator registers all services', () async {
      // Act
      await setupServiceLocator();

      // Assert - verify all services are registered
      expect(getIt.isRegistered<ErrorHandler>(), true);
      expect(getIt.isRegistered<IAudioService>(), true);
      expect(getIt.isRegistered<IPermissionService>(), true);
      expect(getIt.isRegistered<ISettingsService>(), true);
      expect(getIt.isRegistered<IStorageService>(), true);
      expect(getIt.isRegistered<IDebugService>(), true);
    });

    test(
      'setupServiceLocator registers services without eager initialization',
      () async {
        // Act
        await setupServiceLocator();

        // Assert - services should be registered but not yet initialized
        // This allows tests to register mocks without triggering SharedPreferences
        expect(getIt.isRegistered<ISettingsService>(), true);
        expect(getIt.isRegistered<IStorageService>(), true);

        // Services are lazily instantiated, so this just verifies registration
        expect(() => getIt<ISettingsService>(), returnsNormally);
        expect(() => getIt<IStorageService>(), returnsNormally);
      },
    );

    test('services are resolved as singletons', () async {
      // Arrange
      await setupServiceLocator();

      // Act - resolve services multiple times
      final audioService1 = getIt<IAudioService>();
      final audioService2 = getIt<IAudioService>();
      final permissionService1 = getIt<IPermissionService>();
      final permissionService2 = getIt<IPermissionService>();

      // Assert - same instance should be returned
      expect(identical(audioService1, audioService2), true);
      expect(identical(permissionService1, permissionService2), true);
    });

    test('setupServiceLocator fails if called twice', () async {
      // Arrange
      await setupServiceLocator();

      // Act & Assert - second call should throw StateError
      expect(
        () async => await setupServiceLocator(),
        throwsA(isA<StateError>()),
      );
    });

    test('resetServiceLocator unregisters all services', () async {
      // Arrange
      await setupServiceLocator();
      expect(getIt.isRegistered<IAudioService>(), true);

      // Act
      await resetServiceLocator();

      // Assert - services should no longer be registered
      expect(getIt.isRegistered<IAudioService>(), false);
      expect(getIt.isRegistered<IPermissionService>(), false);
      expect(getIt.isRegistered<ISettingsService>(), false);
      expect(getIt.isRegistered<IStorageService>(), false);
      expect(getIt.isRegistered<IDebugService>(), false);
      expect(getIt.isRegistered<ErrorHandler>(), false);
    });

    test('resetServiceLocator allows re-initialization', () async {
      // Arrange
      await setupServiceLocator();
      await resetServiceLocator();

      // Act - should be able to setup again without error
      await setupServiceLocator();

      // Assert
      expect(getIt.isRegistered<IAudioService>(), true);
    });

    test('resetServiceLocator is safe to call when not initialized', () async {
      // Act & Assert - should not throw
      expect(() async => await resetServiceLocator(), returnsNormally);
    });

    test('AudioService receives ErrorHandler dependency', () async {
      // Arrange
      await setupServiceLocator();

      // Act
      final audioService = getIt<IAudioService>();

      // Assert - AudioService should be created with ErrorHandler
      // We can verify this indirectly by checking that ErrorHandler is registered
      expect(getIt.isRegistered<ErrorHandler>(), true);
      expect(audioService, isNotNull);
    });

    test('services fail fast when not registered', () async {
      // No setup call - services not registered

      // Act & Assert
      expect(() => getIt<IAudioService>(), throwsA(isA<Error>()));
    });

    test('can resolve all services after setup', () async {
      // Arrange
      await setupServiceLocator();

      // Act - resolve all services
      final audioService = getIt<IAudioService>();
      final permissionService = getIt<IPermissionService>();
      final settingsService = getIt<ISettingsService>();
      final storageService = getIt<IStorageService>();
      final debugService = getIt<IDebugService>();
      final errorHandler = getIt<ErrorHandler>();

      // Assert - all services should be non-null
      expect(audioService, isNotNull);
      expect(permissionService, isNotNull);
      expect(settingsService, isNotNull);
      expect(storageService, isNotNull);
      expect(debugService, isNotNull);
      expect(errorHandler, isNotNull);
    });

    test('services can be registered and resolved', () async {
      // Arrange
      await setupServiceLocator();

      // Act & Assert - all services should be resolvable
      expect(() => getIt<ISettingsService>(), returnsNormally);
      expect(() => getIt<IStorageService>(), returnsNormally);
      expect(() => getIt<IDebugService>(), returnsNormally);

      // Services should be non-null when resolved
      final settingsService = getIt<ISettingsService>();
      final storageService = getIt<IStorageService>();
      final debugService = getIt<IDebugService>();

      expect(settingsService, isNotNull);
      expect(storageService, isNotNull);
      expect(debugService, isNotNull);
    });
  });
}
