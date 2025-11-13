import 'package:flutter/material.dart';
import '../../models/calibration_progress.dart';
import '../../services/audio/i_audio_service.dart';
import '../../services/audio/audio_service_impl.dart';
import '../../services/error_handler/exceptions.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/status_card.dart';

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
/// This screen uses dependency injection for services, enabling
/// testability and separation of concerns.
class CalibrationScreen extends StatefulWidget {
  /// Audio service for calibration control
  final IAudioService audioService;

  CalibrationScreen({super.key, IAudioService? audioService})
    : audioService = audioService ?? AudioServiceImpl();

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  /// Stream of calibration progress updates from audio service
  Stream<CalibrationProgress>? _calibrationStream;

  /// Current calibration progress (null when not started)
  CalibrationProgress? _currentProgress;

  /// Whether calibration is currently active
  bool _isCalibrating = false;

  /// Error message to display (null if no error)
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Start calibration automatically when screen loads
    _startCalibration();
  }

  @override
  void dispose() {
    // If calibration is still in progress when screen is disposed, finish it
    if (_isCalibrating && _currentProgress != null) {
      // Note: We don't await here as dispose can't be async
      // The service will clean up the procedure when the stream is dropped
      widget.audioService.finishCalibration().catchError((e) {
        // Ignore errors during cleanup
      });
    }
    super.dispose();
  }

  /// Start calibration workflow
  Future<void> _startCalibration() async {
    try {
      // Start calibration procedure
      await widget.audioService.startCalibration();

      // Subscribe to calibration progress stream
      final stream = widget.audioService.getCalibrationStream();

      setState(() {
        _isCalibrating = true;
        _calibrationStream = stream;
        _currentProgress = null;
        _errorMessage = null;
      });
    } on CalibrationServiceException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isCalibrating = false;
      });
    } on AudioServiceException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isCalibrating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start calibration: $e';
        _isCalibrating = false;
      });
    }
  }

  /// Finish calibration and compute thresholds
  Future<void> _finishCalibration() async {
    try {
      // Finalize calibration and compute thresholds
      await widget.audioService.finishCalibration();

      // Navigate back to previous screen (typically TrainingScreen)
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on CalibrationServiceException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isCalibrating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Calibration failed: $e';
        _isCalibrating = false;
      });
    }
  }

  /// Restart calibration from beginning
  Future<void> _restartCalibration() async {
    setState(() {
      _currentProgress = null;
      _errorMessage = null;
      _isCalibrating = false;
    });

    await _startCalibration();
  }

  /// Get instruction text for current calibration sound
  String _getInstructionText(CalibrationSound sound) {
    return 'Make ${sound.displayName} sound 10 times';
  }

  /// Get description text for current calibration sound
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calibration'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Restart button
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Restart calibration',
            onPressed: _isCalibrating ? _restartCalibration : null,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _errorMessage != null
            ? _buildErrorDisplay()
            : _isCalibrating && _calibrationStream != null
            ? _buildCalibrationDisplay()
            : _buildInitialDisplay(),
      ),
    );
  }

  /// Build error display widget
  Widget _buildErrorDisplay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 24),
          Text(
            _errorMessage!,
            style: const TextStyle(fontSize: 18, color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _restartCalibration,
            child: const Text('Retry'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Build initial loading display
  Widget _buildInitialDisplay() {
    return const LoadingOverlay(message: 'Initializing calibration...');
  }

  /// Build calibration progress display
  Widget _buildCalibrationDisplay() {
    return StreamBuilder<CalibrationProgress>(
      stream: _calibrationStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingOverlay(message: 'Starting calibration...');
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 24),
                Text(
                  'Stream error: ${snapshot.error}',
                  style: const TextStyle(fontSize: 18, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _restartCalibration,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Update current progress
        if (snapshot.hasData) {
          _currentProgress = snapshot.data;

          // Check if calibration is complete
          if (_currentProgress!.isCalibrationComplete) {
            // Automatically finish calibration when all samples collected
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _finishCalibration();
            });
          }
        }

        // Display current progress or idle state
        if (_currentProgress != null) {
          return _buildProgressContent(_currentProgress!);
        } else {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, size: 64, color: Colors.grey),
                SizedBox(height: 24),
                Text(
                  'Waiting for calibration data...',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  /// Build progress content widget
  Widget _buildProgressContent(CalibrationProgress progress) {
    final sound = progress.currentSound;
    final collected = progress.samplesCollected;
    final needed = progress.samplesNeeded;
    final progressFraction = progress.progressFraction;
    final overallProgress = progress.overallProgressFraction;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Overall progress indicator
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
        const SizedBox(height: 48),

        // Current sound icon
        Icon(Icons.mic, size: 80, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),

        // Instruction text
        Text(
          _getInstructionText(sound),
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Description text
        Text(
          _getDescriptionText(sound),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),

        // Progress counter
        Text(
          '$collected / $needed samples',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Current sound progress bar
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
        const SizedBox(height: 48),

        // Status message
        if (progress.isSoundComplete && !progress.isCalibrationComplete)
          StatusCard(
            color: Colors.green,
            icon: Icons.check_circle,
            title: '${sound.displayName} samples complete!',
            subtitle: sound.next != null
                ? 'Moving to ${sound.next!.displayName}...'
                : null,
          ),

        // Completion message
        if (progress.isCalibrationComplete)
          const StatusCard(
            color: Colors.green,
            icon: Icons.celebration,
            title: 'Calibration Complete!',
            subtitle: 'Computing thresholds...',
            iconSize: 48.0,
          ),
      ],
    );
  }
}
