import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/calibration/calibration_controller.dart';
import '../../di/service_locator.dart';
import '../../models/calibration_progress.dart';
import '../../services/audio/i_audio_service.dart';
import '../../services/storage/i_storage_service.dart';
import '../widgets/calibration_confirmation_buttons.dart';
import '../widgets/calibration_level_feedback.dart';
import '../widgets/sample_progress_dots.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Calibration'),
        backgroundColor: const Color(0xFF16213E),
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

                  return _buildCalibrationUI(progress);
                },
              );
            },
          );
        },
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

  Widget _buildCalibrationUI(CalibrationProgress progress) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Overall progress header
            _buildOverallProgress(progress),
            const SizedBox(height: 24),

            // Sound type indicator with animation
            _buildSoundTypeIndicator(progress),
            const SizedBox(height: 24),

            // Enhanced visual feedback with level bar and thresholds
            ValueListenableBuilder<double?>(
              valueListenable: _controller.audioRmsNotifier,
              builder: (context, currentRms, _) => CalibrationLevelFeedback(
                currentRms: currentRms,
                debug: progress.debug,
                sound: progress.currentSound,
              ),
            ),
            const SizedBox(height: 16),

            // Quick pass/fail status summary for sound phases
            if (progress.currentSound.isSoundPhase)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: CalibrationStatusSummary(
                  debug: progress.debug,
                  sound: progress.currentSound,
                ),
              ),

            // Live guidance banner when we hear sound but haven't accepted samples
            ValueListenableBuilder<String?>(
              valueListenable: _controller.guidanceNotifier,
              builder: (context, guidance, _) {
                if (guidance == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _GuidanceBanner(message: guidance),
                );
              },
            ),

            // Manual accept button
            ValueListenableBuilder<bool>(
              valueListenable: _controller.manualAcceptAvailableNotifier,
              builder: (context, available, _) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: available ? _onManualAccept : null,
                      icon: const Icon(Icons.rule),
                      label: const Text('Count last hit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.lightBlueAccent,
                        side: BorderSide(
                          color: Colors.lightBlueAccent.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Sample collection progress
            SampleProgressDots(
              collected: progress.samplesCollected,
              needed: progress.samplesNeeded,
              color: progress.currentSound.color,
            ),
            const SizedBox(height: 20),

            // Show confirmation buttons or instructions based on state
            if (progress.waitingForConfirmation)
              CalibrationConfirmationButtons(
                sound: progress.currentSound,
                onRetry: () async {
                  try {
                    await _controller.retryStep();
                  } catch (e) {
                    debugPrint('[CalibrationScreen] Retry error: $e');
                  }
                },
                onConfirm: () async {
                  try {
                    final hasNext = await _controller.confirmStep();
                    // If no next step, calibration is complete and saved
                    if (!hasNext && mounted) {
                      await _handleSuccess();
                    }
                  } catch (e) {
                    debugPrint('[CalibrationScreen] Confirm error: $e');
                  }
                },
              )
            else
              _buildInstructions(progress),
            const SizedBox(height: 20),

            // Tips at bottom
            _buildTips(progress),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallProgress(CalibrationProgress progress) {
    final currentStep = progress.currentSound.index + 1;
    const totalSteps = 4; // NoiseFloor, Kick, Snare, HiHat
    final overallProgress = progress.overallProgressFraction;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step $currentStep of $totalSteps',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(overallProgress * 100).toInt()}% Complete',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: overallProgress,
            minHeight: 8,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D9FF)),
          ),
        ),
      ],
    );
  }

  Widget _buildSoundTypeIndicator(CalibrationProgress progress) {
    final sound = progress.currentSound;
    final color = sound.color;
    final icon = sound.icon;

    return AnimatedBuilder(
      animation: _flashAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(
                  alpha: 0.3 + (_flashAnimation.value * 0.5),
                ),
                blurRadius: 30 + (_flashAnimation.value * 20),
                spreadRadius: 5 + (_flashAnimation.value * 10),
              ),
            ],
          ),
          child: ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color, width: 3),
              ),
              child: Icon(icon, size: 70, color: color),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructions(CalibrationProgress progress) {
    final sound = progress.currentSound;
    final isNoiseFloor = sound == CalibrationSound.noiseFloor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            isNoiseFloor
                ? 'Measuring Ambient Noise'
                : 'Make the ${sound.displayName} sound',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sound.instructionText,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: sound.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              sound.phoneticHint,
              style: TextStyle(
                color: sound.color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontStyle: isNoiseFloor ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTips(CalibrationProgress progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.amber[300], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              progress.currentSound.tipText,
              style: TextStyle(color: Colors.amber[100], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidanceBanner extends StatelessWidget {
  const _GuidanceBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hearing, color: Colors.lightBlueAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
