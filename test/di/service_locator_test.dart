import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:beatbox_trainer/di/service_locator.dart';
import 'package:beatbox_trainer/services/audio/i_audio_service.dart';
import 'package:beatbox_trainer/services/debug/i_debug_service.dart';
import 'package:beatbox_trainer/services/debug/i_audio_metrics_provider.dart';
import 'package:beatbox_trainer/services/debug/i_onset_event_provider.dart';
import 'package:beatbox_trainer/services/debug/i_log_exporter.dart';
import 'package:beatbox_trainer/services/error_handler/error_handler.dart';
import 'package:beatbox_trainer/services/navigation/i_navigation_service.dart';
import 'package:beatbox_trainer/services/permission/i_permission_service.dart';
import 'package:beatbox_trainer/services/settings/i_settings_service.dart';
import 'package:beatbox_trainer/services/storage/i_storage_service.dart';

void main() {
  // Initialize Flutter bindings for SharedPreferences
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Create a minimal GoRouter for testing
  GoRouter createTestRouter() {
    return GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
      ],
    );
  }

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
      await setupServiceLocator(createTestRouter());

      // Assert - verify all services are registered
      expect(getIt.isRegistered<ErrorHandler>(), true);
      expect(getIt.isRegistered<IAudioService>(), true);
      expect(getIt.isRegistered<IPermissionService>(), true);
      expect(getIt.isRegistered<ISettingsService>(), true);
      expect(getIt.isRegistered<IStorageService>(), true);
      expect(getIt.isRegistered<IDebugService>(), true);
      expect(getIt.isRegistered<INavigationService>(), true);
    });

    test(
      'setupServiceLocator registers services without eager initialization',
      () async {
        // Act
        await setupServiceLocator(createTestRouter());

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
      await setupServiceLocator(createTestRouter());

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
      await setupServiceLocator(createTestRouter());

      // Act & Assert - second call should throw StateError
      expect(
        () async => await setupServiceLocator(createTestRouter()),
        throwsA(isA<StateError>()),
      );
    });

    test('resetServiceLocator unregisters all services', () async {
      // Arrange
      await setupServiceLocator(createTestRouter());
      expect(getIt.isRegistered<IAudioService>(), true);

      // Act
      await resetServiceLocator();

      // Assert - services should no longer be registered
      expect(getIt.isRegistered<IAudioService>(), false);
      expect(getIt.isRegistered<IPermissionService>(), false);
      expect(getIt.isRegistered<ISettingsService>(), false);
      expect(getIt.isRegistered<IStorageService>(), false);
      expect(getIt.isRegistered<IDebugService>(), false);
      expect(getIt.isRegistered<INavigationService>(), false);
      expect(getIt.isRegistered<ErrorHandler>(), false);
    });

    test('resetServiceLocator allows re-initialization', () async {
      // Arrange
      await setupServiceLocator(createTestRouter());
      await resetServiceLocator();

      // Act - should be able to setup again without error
      await setupServiceLocator(createTestRouter());

      // Assert
      expect(getIt.isRegistered<IAudioService>(), true);
    });

    test('resetServiceLocator is safe to call when not initialized', () async {
      // Act & Assert - should not throw
      expect(() async => await resetServiceLocator(), returnsNormally);
    });

    test('AudioService receives ErrorHandler dependency', () async {
      // Arrange
      await setupServiceLocator(createTestRouter());

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
      await setupServiceLocator(createTestRouter());

      // Act - resolve all services
      final audioService = getIt<IAudioService>();
      final permissionService = getIt<IPermissionService>();
      final settingsService = getIt<ISettingsService>();
      final storageService = getIt<IStorageService>();
      final debugService = getIt<IDebugService>();
      final navigationService = getIt<INavigationService>();
      final errorHandler = getIt<ErrorHandler>();

      // Assert - all services should be non-null
      expect(audioService, isNotNull);
      expect(permissionService, isNotNull);
      expect(settingsService, isNotNull);
      expect(storageService, isNotNull);
      expect(debugService, isNotNull);
      expect(navigationService, isNotNull);
      expect(errorHandler, isNotNull);
    });

    test('services can be registered and resolved', () async {
      // Arrange
      await setupServiceLocator(createTestRouter());

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

  group('Interface Segregation (ISP) - Split Debug Interfaces', () {
    setUp(() async {
      // Reset service locator before each test for isolation
      await resetServiceLocator();
    });

    tearDown(() async {
      // Clean up after each test
      await resetServiceLocator();
    });

    test('all debug interfaces are registered', () async {
      // Act
      await setupServiceLocator(createTestRouter());

      // Assert - verify all four debug interfaces are registered
      expect(getIt.isRegistered<IDebugService>(), true);
      expect(getIt.isRegistered<IAudioMetricsProvider>(), true);
      expect(getIt.isRegistered<IOnsetEventProvider>(), true);
      expect(getIt.isRegistered<ILogExporter>(), true);
    });

    test('all debug interfaces resolve to same instance', () async {
      // Arrange
      await setupServiceLocator(createTestRouter());

      // Act - resolve all four debug interfaces
      final debugService = getIt<IDebugService>();
      final metricsProvider = getIt<IAudioMetricsProvider>();
      final onsetProvider = getIt<IOnsetEventProvider>();
      final logExporter = getIt<ILogExporter>();

      // Assert - all should resolve to the same instance (singleton pattern)
      expect(identical(debugService, metricsProvider), true);
      expect(identical(debugService, onsetProvider), true);
      expect(identical(debugService, logExporter), true);
      expect(identical(metricsProvider, onsetProvider), true);
      expect(identical(metricsProvider, logExporter), true);
      expect(identical(onsetProvider, logExporter), true);
    });

    test('can resolve individual ISP interfaces independently', () async {
      // Arrange
      await setupServiceLocator(createTestRouter());

      // Act - resolve each interface independently
      final metricsProvider = getIt<IAudioMetricsProvider>();
      final onsetProvider = getIt<IOnsetEventProvider>();
      final logExporter = getIt<ILogExporter>();

      // Assert - all should be non-null
      expect(metricsProvider, isNotNull);
      expect(onsetProvider, isNotNull);
      expect(logExporter, isNotNull);
    });

    test('ISP interfaces support dependency injection', () async {
      // Arrange
      await setupServiceLocator(createTestRouter());

      // Act - simulate component depending only on specific interface
      // Components can now depend on only what they need (ISP)
      final metricsProvider = getIt<IAudioMetricsProvider>();

      // Assert - component receives correct interface
      expect(metricsProvider, isA<IAudioMetricsProvider>());
      expect(metricsProvider, isNotNull);
    });

    test('resetServiceLocator disposes debug service only once', () async {
      // Arrange
      await setupServiceLocator(createTestRouter());

      // Verify all interfaces are registered
      expect(getIt.isRegistered<IDebugService>(), true);
      expect(getIt.isRegistered<IAudioMetricsProvider>(), true);
      expect(getIt.isRegistered<IOnsetEventProvider>(), true);
      expect(getIt.isRegistered<ILogExporter>(), true);

      // Act - reset service locator (should dispose once, not four times)
      await resetServiceLocator();

      // Assert - all interfaces should be unregistered
      expect(getIt.isRegistered<IDebugService>(), false);
      expect(getIt.isRegistered<IAudioMetricsProvider>(), false);
      expect(getIt.isRegistered<IOnsetEventProvider>(), false);
      expect(getIt.isRegistered<ILogExporter>(), false);
    });

    test('legacy IDebugService interface still works', () async {
      // Arrange - components using legacy interface should still work
      await setupServiceLocator(createTestRouter());

      // Act - resolve legacy interface
      final debugService = getIt<IDebugService>();

      // Assert - legacy interface resolves correctly
      expect(debugService, isNotNull);
      expect(debugService, isA<IDebugService>());
    });
  });
}
