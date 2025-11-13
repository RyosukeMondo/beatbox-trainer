import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'di/service_locator.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/calibration_screen.dart';
import 'ui/screens/training_screen.dart';
import 'ui/screens/settings_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized before async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Setup dependency injection container before running the app
  await setupServiceLocator();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Beatbox Trainer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: _router,
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
      builder: (context, state) => CalibrationScreen(),
    ),
    GoRoute(
      path: '/training',
      builder: (context, state) => TrainingScreen.create(),
    ),
    GoRoute(path: '/settings', builder: (context, state) => SettingsScreen()),
  ],
);
