import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'bridge/api.dart/frb_generated.dart';
import 'di/service_locator.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/calibration_screen.dart';
import 'ui/screens/training_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'services/settings/i_settings_service.dart';
import 'services/storage/i_storage_service.dart';

void main() async {
  // Ensure Flutter bindings are initialized before async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flutter_rust_bridge before any FFI calls
  await RustLib.init();

  // Setup dependency injection container with router before running the app
  await setupServiceLocator(_router);

  // Initialize async services that depend on SharedPreferences before use
  await Future.wait([
    getIt<ISettingsService>().init(),
    getIt<IStorageService>().init(),
  ]);

  runApp(MyApp(router: _router));
}

class MyApp extends StatelessWidget {
  /// Router configuration used by the Material app.
  final GoRouter router;

  /// Creates the root widget with an optional router override.
  ///
  /// Tests can pass a custom [GoRouter] instance to validate navigation flows
  /// without mutating the global router configuration.
  MyApp({super.key, GoRouter? router}) : router = router ?? _router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Beatbox Trainer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

/// GoRouter configuration with all app routes
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/calibration',
      builder: (context, state) => CalibrationScreen.create(),
    ),
    GoRoute(
      path: '/training',
      builder: (context, state) => TrainingScreen.create(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => SettingsScreen.create(),
    ),
  ],
);
