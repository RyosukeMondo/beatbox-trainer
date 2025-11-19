import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../services/audio/audio_service_impl.dart';
import '../services/audio/i_audio_service.dart';
import '../services/debug/debug_service_impl.dart';
import '../services/debug/i_debug_service.dart';
import '../services/debug/i_audio_metrics_provider.dart';
import '../services/debug/i_onset_event_provider.dart';
import '../services/debug/i_log_exporter.dart';
import '../services/debug/fixture_metadata_service.dart';
import '../services/error_handler/error_handler.dart';
import '../services/navigation/go_router_navigation_service.dart';
import '../services/navigation/i_navigation_service.dart';
import '../services/permission/i_permission_service.dart';
import '../services/permission/permission_service_impl.dart';
import '../services/settings/i_settings_service.dart';
import '../services/settings/settings_service_impl.dart';
import '../services/storage/i_storage_service.dart';
import '../services/storage/storage_service_impl.dart';

/// Global service locator instance for dependency injection.
///
/// This singleton instance is used throughout the app to resolve service
/// dependencies. Services are registered during app initialization and can
/// be resolved by widgets and other components as needed.
///
/// Example usage:
/// ```dart
/// final audioService = getIt<IAudioService>();
/// await audioService.startAudio(bpm: 120);
/// ```
final getIt = GetIt.instance;

/// Set up dependency injection container with all app services.
///
/// Registers all services as lazy singletons in the GetIt container:
/// - [IAudioService]: Audio engine and calibration workflow
/// - [IPermissionService]: Microphone permission management
/// - [ISettingsService]: App settings persistence
/// - [IStorageService]: Calibration data persistence
/// - [IDebugService]: Debug metrics and event streams (legacy interface)
/// - [IAudioMetricsProvider]: Audio metrics streaming (ISP)
/// - [IOnsetEventProvider]: Onset event streaming (ISP)
/// - [ILogExporter]: Log export functionality (ISP)
/// - [INavigationService]: Navigation abstraction for testability
/// - [ErrorHandler]: Error translation for audio/calibration errors
///
/// Services are registered as lazy singletons, meaning they are instantiated
/// only when first requested and then reused throughout the app lifecycle.
///
/// **Note**: DebugServiceImpl is registered as all four debug interfaces
/// (IDebugService, IAudioMetricsProvider, IOnsetEventProvider, ILogExporter).
/// All four registrations return the same singleton instance, supporting
/// both the legacy interface and the new ISP-compliant interfaces.
///
/// Services that require async initialization (SettingsService, StorageService,
/// DebugService) are registered but not initialized here. Initialization
/// happens on-demand when first accessed.
///
/// This function should be called once during app startup, before [runApp].
///
/// Parameters:
/// - [router]: The GoRouter instance to use for navigation. Required for
///   registering the NavigationService.
///
/// Throws:
/// - [StateError] if called multiple times without calling [resetServiceLocator]
///
/// Example:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final router = GoRouter(routes: [...]);
///   await setupServiceLocator(router);
///   runApp(MyApp());
/// }
/// ```
Future<void> setupServiceLocator(GoRouter router) async {
  // Fail fast if services are already registered
  if (getIt.isRegistered<IAudioService>()) {
    throw StateError(
      'Service locator already initialized. '
      'Call resetServiceLocator() before re-initializing.',
    );
  }

  // Register ErrorHandler (used by AudioService)
  getIt.registerLazySingleton<ErrorHandler>(() => ErrorHandler());

  // Register AudioService
  getIt.registerLazySingleton<IAudioService>(
    () => AudioServiceImpl(errorHandler: getIt<ErrorHandler>()),
  );

  // Register PermissionService
  getIt.registerLazySingleton<IPermissionService>(
    () => PermissionServiceImpl(),
  );

  // Register SettingsService
  getIt.registerLazySingleton<ISettingsService>(() => SettingsServiceImpl());

  // Register StorageService
  getIt.registerLazySingleton<IStorageService>(() => StorageServiceImpl());

  // Register DebugService as a singleton instance
  // This single instance is registered under all four interfaces:
  // - IDebugService (legacy interface for backward compatibility)
  // - IAudioMetricsProvider (ISP: audio metrics streaming)
  // - IOnsetEventProvider (ISP: onset event streaming)
  // - ILogExporter (ISP: log export functionality)
  final debugServiceInstance = DebugServiceImpl();
  await debugServiceInstance.init();

  // Register the same instance under all four interfaces
  getIt.registerSingleton<IDebugService>(debugServiceInstance);
  getIt.registerSingleton<IAudioMetricsProvider>(debugServiceInstance);
  getIt.registerSingleton<IOnsetEventProvider>(debugServiceInstance);
  getIt.registerSingleton<ILogExporter>(debugServiceInstance);

  // Register fixture metadata registry service shared by Debug Lab/CLI overlays.
  getIt.registerLazySingleton<IFixtureMetadataService>(
    () => FixtureMetadataService(),
  );

  // Register NavigationService with the provided router instance
  getIt.registerLazySingleton<INavigationService>(
    () => GoRouterNavigationService(router),
  );

  // Note: Services with async initialization (SettingsService, StorageService,
  // DebugService) are registered as lazy singletons. They will be initialized
  // on first access. For production use, the app should call their init()
  // methods after setupServiceLocator() completes. For tests, mocks can be
  // registered instead to avoid SharedPreferences dependency.
}

/// Reset the service locator for testing.
///
/// Unregisters all services and disposes resources. This is primarily used
/// in test teardown to ensure test isolation - each test can register its
/// own mock services without interference from previous tests.
///
/// After calling this function, [setupServiceLocator] can be called again
/// to re-register services (with real or mock implementations).
///
/// This function is safe to call even if no services are registered.
///
/// **Note**: Since DebugServiceImpl is registered as four interfaces
/// (IDebugService, IAudioMetricsProvider, IOnsetEventProvider, ILogExporter),
/// we only need to dispose it once. We check for any of the interfaces to
/// avoid redundant disposal calls.
///
/// Example usage in tests:
/// ```dart
/// setUp(() async {
///   await resetServiceLocator();
///   // Register mock services
///   getIt.registerSingleton<IAudioService>(MockAudioService());
/// });
///
/// tearDown(() async {
///   await resetServiceLocator();
/// });
/// ```
Future<void> resetServiceLocator() async {
  // Dispose any services that need cleanup
  // Note: DebugServiceImpl is registered as four interfaces, but we only
  // need to dispose it once. Check for IDebugService which is always registered.
  if (getIt.isRegistered<IDebugService>()) {
    final debugService = getIt<IDebugService>();
    if (debugService is DebugServiceImpl) {
      debugService.dispose();
    }
  }

  // Reset the GetIt instance (unregisters all services)
  await getIt.reset();
}
