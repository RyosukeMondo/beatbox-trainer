import 'package:flutter/material.dart';
import '../../bridge/api.dart';
import '../../models/calibration_progress.dart';

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
/// Follows design from: design.md Component 9 (CalibrationScreen)
/// Requirements: Req 7 (Calibration System), Req 9 (Flutter UI)
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  /// Stream of calibration progress updates from Rust
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
      // The Rust side will clean up the procedure when the stream is dropped
      finishCalibration().catchError((e) {
        // Ignore errors during cleanup
      });
    }
    super.dispose();
  }

  /// Start calibration workflow
  Future<void> _startCalibration() async {
    try {
      // Call Rust API to start calibration procedure
      await startCalibration();

      // Subscribe to calibration progress stream
      final stream = calibrationStream();

      setState(() {
        _isCalibrating = true;
        _calibrationStream = stream;
        _currentProgress = null;
        _errorMessage = null;
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
      // Call Rust API to finalize calibration and compute thresholds
      await finishCalibration();

      // Navigate back to previous screen (typically TrainingScreen)
      if (mounted) {
        Navigator.of(context).pop();
      }
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
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          const SizedBox(height: 24),
          Text(
            _errorMessage!,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.red,
            ),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Initializing calibration...',
            style: TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }

  /// Build calibration progress display
  Widget _buildCalibrationDisplay() {
    return StreamBuilder<CalibrationProgress>(
      stream: _calibrationStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text(
                  'Starting calibration...',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  'Stream error: ${snapshot.error}',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                  ),
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
                Icon(
                  Icons.mic,
                  size: 64,
                  color: Colors.grey,
                ),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
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
        Icon(
          Icons.mic,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),

        // Instruction text
        Text(
          _getInstructionText(sound),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Description text
        Text(
          _getDescriptionText(sound),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[700],
              ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${sound.displayName} samples complete!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (sound.next != null)
                    Text(
                      'Moving to ${sound.next!.displayName}...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),

        // Completion message
        if (progress.isCalibrationComplete)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.celebration,
                    color: Colors.green,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Calibration Complete!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Computing thresholds...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
