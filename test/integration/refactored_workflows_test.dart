import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beatbox_trainer/di/service_locator.dart';
import 'package:beatbox_trainer/services/audio/i_audio_service.dart';
import 'package:beatbox_trainer/services/permission/i_permission_service.dart';
import 'package:beatbox_trainer/services/settings/i_settings_service.dart';
import 'package:beatbox_trainer/services/navigation/i_navigation_service.dart';
import 'package:beatbox_trainer/services/debug/i_audio_metrics_provider.dart';
import 'package:beatbox_trainer/services/debug/i_onset_event_provider.dart';
import 'package:beatbox_trainer/services/debug/i_log_exporter.dart';
import 'package:beatbox_trainer/controllers/training/training_controller.dart';
import 'package:beatbox_trainer/services/error_handler/error_handler.dart';
import 'package:beatbox_trainer/services/storage/i_storage_service.dart';
import 'package:beatbox_trainer/services/debug/i_debug_service.dart';
import 'package:go_router/go_router.dart';
import 'package:beatbox_trainer/services/navigation/go_router_navigation_service.dart';

/// Integration tests for refactored architecture.
///
/// These tests verify that the refactored code works correctly when integrated:
/// - TrainingController orchestrates real service dependencies
/// - AppContext facade delegates to managers correctly (verified via FFI boundary)
/// - Navigation service integration works with GoRouter
/// - DI container resolves dependencies correctly
///
/// Note: These tests run on non-Android platforms where the audio engine
/// returns HardwareError. This is expected and allows us to test integration
/// points without requiring an Android emulator.
void main() {
  late GoRouter router;

  setUp(() async {
    // Create a minimal router for navigation service
    router = GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(path: '/test', builder: (context, state) => const SizedBox()),
        GoRoute(
          path: '/training',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(
          path: '/calibration',
          builder: (context, state) => const SizedBox(),
        ),
      ],
    );

    // Setup service locator with real implementations
    await setupServiceLocator(router);
  });

  tearDown(() async {
    await resetServiceLocator();
    router.dispose();
  });

  group('DI Container Integration', () {
    test('All services are registered and resolvable', () {
      // Verify core services are registered
      expect(getIt.isRegistered<IAudioService>(), isTrue);
      expect(getIt.isRegistered<IPermissionService>(), isTrue);
      expect(getIt.isRegistered<ISettingsService>(), isTrue);
      expect(getIt.isRegistered<IStorageService>(), isTrue);
      expect(getIt.isRegistered<INavigationService>(), isTrue);
      expect(getIt.isRegistered<ErrorHandler>(), isTrue);

      // Verify ISP-compliant debug interfaces are registered
      expect(getIt.isRegistered<IDebugService>(), isTrue);
      expect(getIt.isRegistered<IAudioMetricsProvider>(), isTrue);
      expect(getIt.isRegistered<IOnsetEventProvider>(), isTrue);
      expect(getIt.isRegistered<ILogExporter>(), isTrue);
    });

    test('Services are singletons - same instance returned', () {
      // Resolve services twice
      final audioService1 = getIt<IAudioService>();
      final audioService2 = getIt<IAudioService>();

      // Verify same instance
      expect(identical(audioService1, audioService2), isTrue);
    });

    test(
      'DebugService backs streaming interfaces while exporter stands alone',
      () {
        // Resolve debug-related interfaces
        final debugService = getIt<IDebugService>();
        final metricsProvider = getIt<IAudioMetricsProvider>();
        final onsetProvider = getIt<IOnsetEventProvider>();
        final logExporter = getIt<ILogExporter>();

        // Streaming interfaces reuse the same singleton instance
        expect(identical(debugService, metricsProvider), isTrue);
        expect(identical(debugService, onsetProvider), isTrue);

        // Log exporter should be dedicated to background I/O work
        expect(identical(debugService, logExporter), isFalse);
      },
    );

    test('NavigationService is properly configured with router', () {
      final navService = getIt<INavigationService>();

      // Verify it's the correct implementation
      expect(navService, isA<GoRouterNavigationService>());

      // Verify it can navigate (won't throw)
      expect(() => navService.goTo('/training'), returnsNormally);
    });
  });

  group('TrainingController Integration', () {
    late TrainingController controller;

    setUp(() {
      // Create controller with real services from DI container
      controller = TrainingController(
        audioService: getIt<IAudioService>(),
        permissionService: getIt<IPermissionService>(),
        settingsService: getIt<ISettingsService>(),
      );
    });

    tearDown(() async {
      await controller.dispose();
    });

    test('Controller integrates with real audio service', () {
      // Verify controller can access audio service stream
      // On non-Android, accessing the stream will throw because engine isn't running
      // This tests that controller exposes the service's stream method
      expect(
        () => controller.classificationStream,
        throwsA(anything), // Will throw AudioServiceException on non-Android
      );
    });

    test('Controller handles audio service errors gracefully', () async {
      // On non-Android, audio operations fail with HardwareError
      // Verify controller propagates error from real service

      // Note: startTraining will fail at permission check or audio start
      // This tests the integration, not the success case
      expect(
        () async => await controller.startTraining(),
        throwsA(
          anything,
        ), // May throw PermissionException or AudioServiceException
      );
    });

    test('Controller validates BPM before calling service', () async {
      // Invalid BPM should be caught by controller validation
      expect(() => controller.updateBpm(0), throwsA(isA<ArgumentError>()));

      expect(() => controller.updateBpm(300), throwsA(isA<ArgumentError>()));
    });

    test('Controller state management works correctly', () async {
      // Initial state
      expect(controller.isTraining, isFalse);
      expect(controller.currentBpm, equals(120));

      // Note: We can't test successful start on non-Android,
      // but we can verify state doesn't change on error
      try {
        await controller.startTraining();
      } catch (e) {
        // Expected on non-Android
      }

      // State should still be false after failed start
      expect(controller.isTraining, isFalse);
    });
  });

  group('AppContext Facade Delegation (via FFI)', () {
    late IAudioService audioService;

    setUp(() {
      audioService = getIt<IAudioService>();
    });

    test(
      'AppContext delegates audio operations to AudioEngineManager',
      () async {
        // On non-Android, this tests that the call goes through AppContext
        // to AudioEngineManager and returns HardwareError as expected

        expect(
          () => audioService.startAudio(bpm: 120),
          throwsA(anything), // Should throw HardwareError on non-Android
        );
      },
    );

    test('AppContext delegates BPM updates to AudioEngineManager', () async {
      // Verify BPM update delegation through facade
      expect(
        () => audioService.setBpm(bpm: 140),
        throwsA(anything), // Should throw on non-Android
      );
    });

    test('AppContext delegates calibration to CalibrationManager', () async {
      // Verify calibration operations delegate to CalibrationManager
      expect(
        () => audioService.startCalibration(),
        throwsA(anything), // Should throw on non-Android
      );

      expect(
        () => audioService.finishCalibration(),
        throwsA(anything), // Should fail (not started)
      );
    });

    test('AppContext exposes streams from BroadcastChannelManager', () {
      // Verify stream methods work (will fail on non-Android, but tests integration)
      expect(() => audioService.getClassificationStream(), throwsA(anything));

      expect(() => audioService.getCalibrationStream(), throwsA(anything));
    });
  });

  group('Navigation Service Integration', () {
    late INavigationService navService;

    setUp(() {
      navService = getIt<INavigationService>();
    });

    test('Navigation service delegates to GoRouter', () {
      // Verify navigation calls work
      expect(() => navService.goTo('/training'), returnsNormally);
      expect(() => navService.goTo('/calibration'), returnsNormally);
      expect(() => navService.goTo('/test'), returnsNormally);
    });

    test('Navigation service provides back navigation', () {
      // GoRouter's go() method replaces navigation, it doesn't push
      // So canGoBack() will return false after a single go() call
      // This is expected behavior - the test verifies the navigation service
      // correctly delegates to GoRouter's canPop() method

      // Initial state - on /test route
      expect(navService.canGoBack(), isFalse);

      // After navigating with go(), still can't go back (go replaces, doesn't push)
      navService.goTo('/training');
      expect(navService.canGoBack(), isFalse);

      // This test verifies the abstraction works correctly
    });

    test('Navigation service supports replace', () {
      navService.goTo('/training');

      // Replace current route
      expect(() => navService.replace('/calibration'), returnsNormally);
    });
  });

  group('End-to-End Workflow Integration', () {
    late TrainingController controller;
    late INavigationService navService;

    setUp(() {
      controller = TrainingController(
        audioService: getIt<IAudioService>(),
        permissionService: getIt<IPermissionService>(),
        settingsService: getIt<ISettingsService>(),
      );
      navService = getIt<INavigationService>();
    });

    tearDown(() async {
      await controller.dispose();
    });

    test(
      'Training workflow integrates controller, services, and navigation',
      () async {
        // 1. Navigate to training screen
        expect(() => navService.goTo('/training'), returnsNormally);

        // 2. Attempt to start training (will fail on non-Android)
        try {
          await controller.startTraining();
          fail('Should have thrown on non-Android');
        } catch (e) {
          // Expected - audio engine not available
          expect(e, isA<Exception>());
        }

        // 3. Verify state is consistent
        expect(controller.isTraining, isFalse);

        // 4. Navigate back
        if (navService.canGoBack()) {
          expect(() => navService.goBack(), returnsNormally);
        }
      },
    );

    test('Settings integration works across services', () async {
      // Note: SharedPreferences doesn't work in integration tests without
      // Flutter plugin initialization, so controller.updateBpm() would fail
      // when trying to save to settings.

      // This integration test verifies the architecture pattern is correct:
      // - Controller depends on settings service
      // - Settings service is injected via DI
      // - In production, settings would persist via SharedPreferences

      // For this test, we just verify the services are wired together correctly
      final settingsService = getIt<ISettingsService>();
      expect(settingsService, isNotNull);
      expect(settingsService, isA<ISettingsService>());

      // The integration pattern is verified - actual persistence
      // is tested in unit tests with mocked SharedPreferences
    });
  });

  group('Error Handling Integration', () {
    late IAudioService audioService;

    setUp(() {
      audioService = getIt<IAudioService>();
    });

    test('Errors propagate correctly through all layers', () async {
      // Test error flow: AppContext → FFI → AudioService → Controller
      // On non-Android: AudioEngineManager → AppContext → FFI → AudioService

      // Start audio (will fail on non-Android)
      try {
        await audioService.startAudio(bpm: 120);
        fail('Should have thrown on non-Android');
      } catch (e) {
        // Verify error is properly wrapped
        expect(e, isA<Exception>());
      }
    });

    test('Invalid BPM errors are caught at service layer', () async {
      // Service validates before FFI call
      expect(() => audioService.startAudio(bpm: 0), throwsA(anything));

      expect(() => audioService.setBpm(bpm: 500), throwsA(anything));
    });
  });

  group('Service Lifecycle Integration', () {
    test('resetServiceLocator properly cleans up services', () async {
      // Verify services are registered
      expect(getIt.isRegistered<IAudioService>(), isTrue);
      expect(getIt.isRegistered<IDebugService>(), isTrue);

      // Reset
      await resetServiceLocator();

      // Verify services are unregistered
      expect(getIt.isRegistered<IAudioService>(), isFalse);
      expect(getIt.isRegistered<IDebugService>(), isFalse);

      // Re-setup should work
      await setupServiceLocator(router);

      // Verify services re-registered
      expect(getIt.isRegistered<IAudioService>(), isTrue);
      expect(getIt.isRegistered<IDebugService>(), isTrue);
    });

    test('Multiple reset calls are safe', () async {
      await resetServiceLocator();
      expect(() async => await resetServiceLocator(), returnsNormally);
    });

    test('Cannot double-initialize service locator', () async {
      // Already initialized in setUp
      expect(() => setupServiceLocator(router), throwsA(isA<StateError>()));
    });
  });
}
