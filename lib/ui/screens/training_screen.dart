import 'package:flutter/material.dart';
import '../../bridge/api.dart';
import '../../models/classification_result.dart';
import '../../models/timing_feedback.dart';

/// TrainingScreen provides the main training UI with real-time feedback
///
/// Features:
/// - BPM control with slider (40-240 range)
/// - Start/Stop training buttons
/// - Real-time classification results stream
/// - Error handling for audio engine failures
///
/// This screen connects to the Rust audio engine via flutter_rust_bridge,
/// displaying live classification results as the user makes beatbox sounds.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  /// Current BPM value (beats per minute)
  int _currentBpm = 120;

  /// Whether the audio engine is currently running
  bool _isTraining = false;

  /// Stream of classification results from Rust engine
  Stream<ClassificationResult>? _classificationStream;

  /// Current classification result (null when idle)
  ClassificationResult? _currentResult;

  @override
  void dispose() {
    // Stop audio engine if still running when screen is disposed
    if (_isTraining) {
      _stopTraining();
    }
    super.dispose();
  }

  /// Start audio engine and begin training session
  Future<void> _startTraining() async {
    try {
      // Call Rust API to start audio engine with current BPM
      await startAudio(bpm: _currentBpm);

      // Subscribe to classification stream
      final stream = classificationStream();

      setState(() {
        _isTraining = true;
        _classificationStream = stream;
        _currentResult = null;
      });
    } catch (e) {
      // Show error dialog if audio engine fails to start
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  /// Stop audio engine and end training session
  Future<void> _stopTraining() async {
    try {
      // Call Rust API to stop audio engine
      await stopAudio();

      setState(() {
        _isTraining = false;
        _classificationStream = null;
        _currentResult = null;
      });
    } catch (e) {
      // Show error dialog if stop fails
      if (mounted) {
        _showErrorDialog('Failed to stop audio: $e');
      }
    }
  }

  /// Update BPM dynamically during training
  Future<void> _updateBpm(int newBpm) async {
    setState(() {
      _currentBpm = newBpm;
    });

    // If training is active, update BPM in real-time
    if (_isTraining) {
      try {
        await setBpm(bpm: newBpm);
      } catch (e) {
        // Show error if BPM update fails
        if (mounted) {
          _showErrorDialog('Failed to update BPM: $e');
        }
      }
    }
  }

  /// Show error dialog with message
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beatbox Trainer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // BPM Control Section
            Text(
              '$_currentBpm BPM',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // BPM Slider
            Slider(
              value: _currentBpm.toDouble(),
              min: 40,
              max: 240,
              divisions: 200,
              label: '$_currentBpm BPM',
              onChanged: _isTraining
                  ? (value) => _updateBpm(value.round())
                  : (value) {
                      setState(() {
                        _currentBpm = value.round();
                      });
                    },
            ),
            const SizedBox(height: 32),

            // Classification Results Display
            Expanded(
              child: _isTraining && _classificationStream != null
                  ? StreamBuilder<ClassificationResult>(
                      stream: _classificationStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Starting audio engine...'),
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
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Stream error: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        if (snapshot.hasData) {
                          _currentResult = snapshot.data;
                          return _buildClassificationDisplay(_currentResult!);
                        }

                        // Idle state - waiting for first classification
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.mic,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Make a beatbox sound!',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Press Start to begin training',
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isTraining ? _stopTraining : _startTraining,
        icon: Icon(_isTraining ? Icons.stop : Icons.play_arrow),
        label: Text(_isTraining ? 'Stop' : 'Start'),
        backgroundColor: _isTraining ? Colors.red : Colors.green,
      ),
    );
  }

  /// Build classification result display widget
  Widget _buildClassificationDisplay(ClassificationResult result) {
    // Get color based on sound type
    Color soundColor;
    switch (result.sound) {
      case BeatboxHit.kick:
        soundColor = Colors.red;
        break;
      case BeatboxHit.snare:
        soundColor = Colors.blue;
        break;
      case BeatboxHit.hiHat:
      case BeatboxHit.closedHiHat:
      case BeatboxHit.openHiHat:
        soundColor = Colors.green;
        break;
      case BeatboxHit.kSnare:
        soundColor = Colors.purple;
        break;
      case BeatboxHit.unknown:
        soundColor = Colors.grey;
        break;
    }

    // Get color based on timing
    Color timingColor;
    switch (result.timing.classification) {
      case TimingClassification.onTime:
        timingColor = Colors.green;
        break;
      case TimingClassification.early:
      case TimingClassification.late:
        timingColor = Colors.amber;
        break;
    }

    // Format timing error with sign
    String timingText;
    final errorMs = result.timing.errorMs;
    if (errorMs > 0) {
      timingText = '+${errorMs.toStringAsFixed(1)}ms LATE';
    } else if (errorMs < 0) {
      timingText = '${errorMs.toStringAsFixed(1)}ms EARLY';
    } else {
      timingText = '0ms ON-TIME';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sound type display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: soundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              result.sound.displayName,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Timing feedback display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: timingColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: timingColor, width: 2),
            ),
            child: Text(
              timingText,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: timingColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
