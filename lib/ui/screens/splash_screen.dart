import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/storage/i_storage_service.dart';
import '../../services/storage/storage_service_impl.dart';
import '../../bridge/api.dart/api.dart' as api;
import '../widgets/error_dialog.dart';
import '../widgets/screen_background.dart';

/// Splash screen that checks for existing calibration data
///
/// This screen is the entry point of the application. It performs
/// the following flow:
/// 1. Shows app logo and loading indicator
/// 2. Initializes StorageService
/// 3. Checks if calibration data exists
/// 4. If calibration exists: loads it into Rust backend and navigates to /training
/// 5. If no calibration: navigates to /onboarding
///
/// All operations are performed asynchronously with proper error handling.
class SplashScreen extends StatefulWidget {
  /// Storage service for checking calibration data
  final IStorageService? _storageService;

  const SplashScreen({super.key, IStorageService? storageService})
    : _storageService = storageService;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Error message to display if initialization fails
  String? _errorMessage;

  /// Storage service instance (lazy-initialized)
  late final IStorageService _storageService;

  @override
  void initState() {
    super.initState();
    // Initialize storage service with default if not provided
    _storageService = widget._storageService ?? StorageServiceImpl();
    // Start calibration check when screen is mounted
    _checkCalibrationAndNavigate();
  }

  /// Check for existing calibration and navigate accordingly
  ///
  /// This method orchestrates the entire splash screen flow:
  /// 1. Initialize storage service
  /// 2. Check if calibration exists
  /// 3. Load calibration into Rust if it exists
  /// 4. Navigate to appropriate screen
  ///
  /// If any step fails, an error dialog is shown with retry option.
  Future<void> _checkCalibrationAndNavigate() async {
    try {
      // Step 1: Initialize storage service
      await _storageService.init();

      // Step 2: Check if calibration data exists
      final hasCalibration = await _storageService.hasCalibration();

      if (!hasCalibration) {
        // No calibration - navigate to onboarding
        if (mounted) {
          context.go('/onboarding');
        }
        return;
      }

      // Step 3: Load calibration data from storage
      final calibrationData = await _storageService.loadCalibration();

      if (calibrationData == null) {
        // Data exists flag was set but actual data is missing (corrupted)
        // Navigate to onboarding to recalibrate
        if (mounted) {
          context.go('/onboarding');
        }
        return;
      }

      // Step 4: Load calibration into Rust backend
      // Convert CalibrationData to Rust CalibrationState format
      final calibrationState = calibrationData.toRustState();
      await api.loadCalibrationState(state: calibrationState);

      // Step 5: Navigate to training screen
      if (mounted) {
        context.go('/training');
      }
    } catch (e) {
      // Handle any errors during initialization
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize: $e';
        });

        // Show error dialog with retry option
        await ErrorDialog.show(
          context,
          title: 'Initialization Error',
          message: _errorMessage!,
          onRetry: () {
            setState(() {
              _errorMessage = null;
            });
            _checkCalibrationAndNavigate();
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenBackground(
      asset: 'assets/images/backgrounds/bg_splash.png',
      overlayOpacity: 0.6,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo/icon
              Image.asset(
                'assets/images/icons/icon_play.png',
                height: 96,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),

              // App title
              Text(
                'Beatbox Trainer',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Loading indicator (or error message)
              if (_errorMessage == null)
                const CircularProgressIndicator.adaptive(
                  backgroundColor: Colors.white24,
                )
              else
                Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
