import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/calibration/calibration_controller.dart';
import '../../di/service_locator.dart';
import '../../models/calibration_progress.dart';
import '../../services/audio/i_audio_service.dart';
import '../../services/storage/i_storage_service.dart';

/// CalibrationScreen guides users through 3-step calibration workflow
///
/// Calibration sequence:
/// 1. Collect 10 kick drum samples
/// 2. Collect 10 snare drum samples
/// 3. Collect 10 hi-hat samples
///
/// After collection completes, thresholds are computed and stored
/// for use by the classifier during training.
///
/// This refactored version delegates business logic to CalibrationController.
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

class _CalibrationScreenState extends State<CalibrationScreen> {
  late CalibrationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        CalibrationController(
          audioService: getIt<IAudioService>(),
          storageService: getIt<IStorageService>(),
        );
    _initializeAndStart();
  }

  Future<void> _initializeAndStart() async {
    try {
      await _controller.init();
      await _controller.startCalibration();
    } catch (e) {
      // Error is handled by controller's errorNotifier
      debugPrint('[CalibrationScreen] Initialization error: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSuccess() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
          title: const Text('Calibration Complete!'),
          content: const Text(
            'Your calibration has been saved successfully. '
            'You can now start training.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Start Training'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    if (mounted) {
      context.go('/training');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calibration'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ValueListenableBuilder<String?>(
          valueListenable: _controller.errorNotifier,
          builder: (context, error, _) {
            if (error != null) {
              return _buildErrorDisplay(error);
            }

            return ValueListenableBuilder<bool>(
              valueListenable: _controller.isCalibratingNotifier,
              builder: (context, isCalibrating, _) {
                if (!isCalibrating) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ValueListenableBuilder<CalibrationProgress?>(
                  valueListenable: _controller.progressNotifier,
                  builder: (context, progress, _) {
                    if (progress == null) {
                      return _buildWaitingDisplay();
                    }

                    // Auto-navigate to training on completion
                    if (progress.isCalibrationComplete) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _handleSuccess();
                      });
                    }

                    return _buildProgressContent(progress);
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 24),
          Text(
            error,
            style: const TextStyle(fontSize: 18, color: Colors.red),
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
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingDisplay() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Starting calibration...', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildProgressContent(CalibrationProgress progress) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOverallProgressHeader(progress),
        const SizedBox(height: 48),
        _buildCurrentSoundInstructions(progress),
        const SizedBox(height: 48),
        _buildProgressIndicator(progress),
        const SizedBox(height: 48),
        _buildStatusMessage(progress),
      ],
    );
  }

  Widget _buildOverallProgressHeader(CalibrationProgress progress) {
    final sound = progress.currentSound;
    final overallProgress = progress.overallProgressFraction;

    return Column(
      children: [
        Text(
          'Step ${sound.index + 1} of ${CalibrationSound.values.length}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: overallProgress,
          minHeight: 8,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSoundInstructions(CalibrationProgress progress) {
    final sound = progress.currentSound;

    return Column(
      children: [
        Icon(Icons.mic, size: 80, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'Make ${sound.displayName} sound 10 times',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          _getDescriptionText(sound),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getDescriptionText(CalibrationSound sound) {
    switch (sound) {
      case CalibrationSound.kick:
        return 'A low, bass-heavy sound like "boot" or "dum"';
      case CalibrationSound.snare:
        return 'A mid-range sharp sound like "psh" or "tish"';
      case CalibrationSound.hiHat:
        return 'A high-frequency crisp sound like "tss" or "ch"';
    }
  }

  Widget _buildProgressIndicator(CalibrationProgress progress) {
    final collected = progress.samplesCollected;
    final needed = progress.samplesNeeded;
    final progressFraction = progress.progressFraction;

    return Column(
      children: [
        Text(
          '$collected / $needed samples',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: LinearProgressIndicator(
            value: progressFraction,
            minHeight: 12,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMessage(CalibrationProgress progress) {
    final collected = progress.samplesCollected;
    final needed = progress.samplesNeeded;

    if (collected >= needed) {
      return Text(
        'Sound complete! Moving to next...',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      );
    }

    return Text(
      'Keep going!',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
      textAlign: TextAlign.center,
    );
  }
}
