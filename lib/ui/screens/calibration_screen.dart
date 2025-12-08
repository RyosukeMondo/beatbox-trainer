import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/calibration/calibration_controller.dart';
import '../../di/service_locator.dart';
import '../../models/calibration_progress.dart';
import '../../services/audio/i_audio_service.dart';
import '../../services/storage/i_storage_service.dart';
import '../widgets/calibration_content.dart';
import '../widgets/screen_background.dart';

/// CalibrationScreen guides users through 4-step calibration workflow
///
/// Calibration sequence:
/// 1. Measure ambient noise floor (stay quiet)
/// 2. Collect 10 kick drum samples
/// 3. Collect 10 snare drum samples
/// 4. Collect 10 hi-hat samples
///
/// Features:
/// - Live audio level meter for visual feedback
/// - Clear instructions for each sound type
/// - Animated sample collection indicators
/// - Progress tracking across all sounds
class CalibrationScreen extends StatefulWidget {
  final CalibrationController? controller;

  /// Private constructor for dependency injection.
  const CalibrationScreen._({super.key, this.controller});

  /// Factory constructor for production use (resolves from GetIt).
  factory CalibrationScreen.create({Key? key}) {
    final controller = CalibrationController(
      audioService: getIt<IAudioService>(),
      storageService: getIt<IStorageService>(),
    );
    return CalibrationScreen._(key: key, controller: controller);
  }

  /// Test constructor for widget testing (accepts mock controller).
  @visibleForTesting
  factory CalibrationScreen.test({
    Key? key,
    required CalibrationController controller,
  }) {
    return CalibrationScreen._(key: key, controller: controller);
  }

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with TickerProviderStateMixin {
  late CalibrationController _controller;
  late AnimationController _pulseController;
  late AnimationController _sampleFlashController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        CalibrationController(
          audioService: getIt<IAudioService>(),
          storageService: getIt<IStorageService>(),
        );

    // Pulse animation for the microphone icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Flash animation for sample collection
    _sampleFlashController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sampleFlashController, curve: Curves.easeOut),
    );

    // Listen for sample collection to trigger flash
    _controller.sampleCollectedNotifier.addListener(_onSampleCollected);

    _initializeAndStart();
  }

  void _onSampleCollected() {
    _sampleFlashController.forward(from: 0.0);
  }

  Future<void> _initializeAndStart() async {
    try {
      await _controller.init();
      await _controller.startCalibration();
    } catch (e) {
      debugPrint('[CalibrationScreen] Initialization error: $e');
    }
  }

  @override
  void dispose() {
    _controller.sampleCollectedNotifier.removeListener(_onSampleCollected);
    _pulseController.dispose();
    _sampleFlashController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSuccess() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
          title: const Text(
            'Calibration Complete!',
            style: TextStyle(color: Colors.black87),
          ),
          content: const Text(
            'Your calibration has been saved successfully. '
            'You can now start training.',
            style: TextStyle(color: Colors.black54),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Start Training'),
            ),
          ],
        );
      },
    );

    if (mounted) {
      context.go('/training');
    }
  }

  Future<void> _onManualAccept() async {
    final progress = await _controller.manualAcceptLastCandidate();
    if (!mounted) return;
    if (progress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not count last hit. Try another clear hit.',
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final soundName = progress.currentSound.displayName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Counted last $soundName hit'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenBackground(
      asset: 'assets/images/backgrounds/bg_calibration.png',
      overlayOpacity: 0.64,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Calibration'),
          backgroundColor: Colors.black.withValues(alpha: 0.32),
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: _controller.isCalibratingNotifier,
              builder: (context, isCalibrating, _) {
                return IconButton(
                  icon: const Icon(Icons.restart_alt),
                  tooltip: 'Restart calibration',
                  onPressed: isCalibrating
                      ? () async {
                          await _controller.cancelCalibration();
                          await _controller.startCalibration();
                        }
                      : null,
                );
              },
            ),
          ],
        ),
        body: ValueListenableBuilder<String?>(
          valueListenable: _controller.errorNotifier,
          builder: (context, error, _) {
            if (error != null) {
              return _buildErrorDisplay(error);
            }

            return ValueListenableBuilder<bool>(
              valueListenable: _controller.isCalibratingNotifier,
              builder: (context, isCalibrating, _) {
                if (!isCalibrating) {
                  return _buildInitializingDisplay();
                }

                return ValueListenableBuilder<CalibrationProgress?>(
                  valueListenable: _controller.progressNotifier,
                  builder: (context, progress, _) {
                    if (progress == null) {
                      return _buildInitializingDisplay();
                    }

                    // Note: Success dialog is shown from confirmStep() callback
                    // when calibration is complete and saved, not here.
                    // This ensures finishCalibration() is called first to persist data.

                    return CalibrationContent(
                      progress: progress,
                      audioRms: _controller.audioRmsNotifier,
                      guidance: _controller.guidanceNotifier,
                      manualAcceptAvailable:
                          _controller.manualAcceptAvailableNotifier,
                      onManualAccept: _onManualAccept,
                      onRetry: () async {
                        try {
                          await _controller.retryStep();
                        } catch (e) {
                          debugPrint('[CalibrationScreen] Retry error: $e');
                        }
                      },
                      onConfirm: () async {
                        try {
                          return await _controller.confirmStep();
                        } catch (e) {
                          debugPrint('[CalibrationScreen] Confirm error: $e');
                          rethrow;
                        }
                      },
                      onComplete: () async {
                        if (mounted) {
                          await _handleSuccess();
                        }
                      },
                      pulseAnimation: _pulseAnimation,
                      flashAnimation: _flashAnimation,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorDisplay(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 80),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await _controller.cancelCalibration();
                await _controller.startCalibration();
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitializingDisplay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 24),
          Text(
            'Initializing microphone...',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'Please allow microphone access if prompted',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
