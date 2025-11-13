import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/classification_result.dart';
import '../../services/audio/i_audio_service.dart';
import '../../services/audio/audio_service_impl.dart';
import '../../services/permission/i_permission_service.dart';
import '../../services/permission/permission_service_impl.dart';
import '../../services/settings/i_settings_service.dart';
import '../../services/settings/settings_service_impl.dart';
import '../../services/debug/i_debug_service.dart';
import '../../services/debug/debug_service_impl.dart';
import '../../services/error_handler/exceptions.dart';
import '../widgets/error_dialog.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/debug_overlay.dart';
import '../utils/display_formatters.dart';

/// TrainingScreen provides the main training UI with real-time feedback
///
/// Features:
/// - BPM control with slider (40-240 range)
/// - Start/Stop training buttons
/// - Real-time classification results stream
/// - Debug overlay toggle (when debug mode enabled)
/// - Error handling for audio engine failures
///
/// This screen uses dependency injection for services, enabling
/// testability and separation of concerns.
class TrainingScreen extends StatefulWidget {
  /// Audio service for engine control
  final IAudioService audioService;

  /// Permission service for microphone access
  final IPermissionService permissionService;

  /// Settings service for debug mode and other settings
  final ISettingsService settingsService;

  /// Debug service for debug overlay data
  final IDebugService debugService;

  TrainingScreen({
    super.key,
    IAudioService? audioService,
    IPermissionService? permissionService,
    ISettingsService? settingsService,
    IDebugService? debugService,
  }) : audioService = audioService ?? AudioServiceImpl(),
       permissionService = permissionService ?? PermissionServiceImpl(),
       settingsService = settingsService ?? SettingsServiceImpl(),
       debugService = debugService ?? DebugServiceImpl();

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  /// Current BPM value (beats per minute)
  int _currentBpm = 120;

  /// Whether the audio engine is currently running
  bool _isTraining = false;

  /// Stream of classification results from audio service
  Stream<ClassificationResult>? _classificationStream;

  /// Current classification result (null when idle)
  ClassificationResult? _currentResult;

  /// Whether debug mode is enabled (loaded from settings)
  bool _debugModeEnabled = false;

  /// Whether debug overlay is currently visible
  bool _debugOverlayVisible = false;

  @override
  void initState() {
    super.initState();
    _loadDebugSettings();
  }

  /// Load debug mode setting from settings service
  Future<void> _loadDebugSettings() async {
    try {
      await widget.settingsService.init();
      final debugMode = await widget.settingsService.getDebugMode();
      if (mounted) {
        setState(() {
          _debugModeEnabled = debugMode;
          _debugOverlayVisible = debugMode;
        });
      }
    } catch (e) {
      // Log error but don't block UI
      debugPrint('Failed to load debug settings: $e');
    }
  }

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
    // Check microphone permission before starting audio
    final hasPermission = await _requestMicrophonePermission();
    if (!hasPermission) {
      return; // Permission denied, cannot proceed
    }

    try {
      // Start audio engine with current BPM
      await widget.audioService.startAudio(bpm: _currentBpm);

      // Subscribe to classification stream
      final stream = widget.audioService.getClassificationStream();

      setState(() {
        _isTraining = true;
        _classificationStream = stream;
        _currentResult = null;
      });
    } on AudioServiceException catch (e) {
      // Show error dialog if audio engine fails to start
      if (mounted) {
        await ErrorDialog.show(
          context,
          title: 'Audio Error',
          message: e.message,
          onRetry: _startTraining,
        );
      }
    } catch (e) {
      // Handle unexpected errors
      if (mounted) {
        await ErrorDialog.show(
          context,
          message: 'Failed to start audio: $e',
          onRetry: _startTraining,
        );
      }
    }
  }

  /// Stop audio engine and end training session
  Future<void> _stopTraining() async {
    try {
      // Stop audio engine
      await widget.audioService.stopAudio();

      setState(() {
        _isTraining = false;
        _classificationStream = null;
        _currentResult = null;
      });
    } on AudioServiceException catch (e) {
      // Show error dialog if stop fails
      if (mounted) {
        await ErrorDialog.show(
          context,
          title: 'Audio Error',
          message: e.message,
        );
      }
    } catch (e) {
      // Handle unexpected errors
      if (mounted) {
        await ErrorDialog.show(context, message: 'Failed to stop audio: $e');
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
        await widget.audioService.setBpm(bpm: newBpm);
      } on AudioServiceException catch (e) {
        // Show error if BPM update fails
        if (mounted) {
          await ErrorDialog.show(
            context,
            title: 'BPM Update Error',
            message: e.message,
          );
        }
      } catch (e) {
        // Handle unexpected errors
        if (mounted) {
          await ErrorDialog.show(context, message: 'Failed to update BPM: $e');
        }
      }
    }
  }

  /// Request microphone permission and handle different states
  Future<bool> _requestMicrophonePermission() async {
    final status = await widget.permissionService.checkMicrophonePermission();

    // Permission already granted
    if (status == PermissionStatus.granted) {
      return true;
    }

    // Permission permanently denied - show settings dialog
    if (status == PermissionStatus.permanentlyDenied) {
      if (mounted) {
        await _showPermissionPermanentlyDeniedDialog();
      }
      return false;
    }

    // Request permission
    final result = await widget.permissionService.requestMicrophonePermission();

    // Permission granted after request
    if (result == PermissionStatus.granted) {
      return true;
    }

    // Permission denied - show rationale dialog
    if (result == PermissionStatus.denied) {
      if (mounted) {
        await _showPermissionDeniedDialog();
      }
      return false;
    }

    // Permission permanently denied after request
    if (result == PermissionStatus.permanentlyDenied) {
      if (mounted) {
        await _showPermissionPermanentlyDeniedDialog();
      }
      return false;
    }

    return false;
  }

  /// Show dialog when permission is denied
  Future<void> _showPermissionDeniedDialog() async {
    return ErrorDialog.show(
      context,
      title: 'Microphone Permission Required',
      message:
          'This app needs microphone access to detect your beatbox sounds. '
          'Please grant permission to continue.',
    );
  }

  /// Show dialog when permission is permanently denied
  Future<void> _showPermissionPermanentlyDeniedDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
          'This app needs microphone access to detect your beatbox sounds. '
          'Please enable microphone permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await widget.permissionService.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Toggle debug overlay visibility
  void _toggleDebugOverlay() {
    setState(() {
      _debugOverlayVisible = !_debugOverlayVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('Beatbox Trainer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_debugModeEnabled)
            IconButton(
              icon: Icon(
                _debugOverlayVisible
                    ? Icons.bug_report
                    : Icons.bug_report_outlined,
              ),
              onPressed: _toggleDebugOverlay,
              tooltip: _debugOverlayVisible
                  ? 'Hide Debug Overlay'
                  : 'Show Debug Overlay',
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // BPM Control Section
            Text(
              DisplayFormatters.formatBpm(_currentBpm),
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // BPM Slider
            Slider(
              value: _currentBpm.toDouble(),
              min: 40,
              max: 240,
              divisions: 200,
              label: DisplayFormatters.formatBpm(_currentBpm),
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
                          return const LoadingOverlay(
                            message: 'Starting audio engine...',
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
                              Icon(Icons.mic, size: 64, color: Colors.grey),
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
                            style: TextStyle(fontSize: 24, color: Colors.grey),
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

    // Wrap with DebugOverlay if debug mode is enabled and overlay is visible
    if (_debugModeEnabled && _debugOverlayVisible) {
      return DebugOverlay(
        debugService: widget.debugService,
        onClose: _toggleDebugOverlay,
        child: scaffold,
      );
    }

    return scaffold;
  }

  /// Build classification result display widget
  Widget _buildClassificationDisplay(ClassificationResult result) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSoundTypeDisplay(result),
          const SizedBox(height: 32),
          _buildTimingFeedbackDisplay(result),
        ],
      ),
    );
  }

  /// Build sound type display with colored container
  Widget _buildSoundTypeDisplay(ClassificationResult result) {
    final soundColor = DisplayFormatters.getSoundColor(result.sound);

    return Container(
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
    );
  }

  /// Build timing feedback display with formatted error
  Widget _buildTimingFeedbackDisplay(ClassificationResult result) {
    final timingColor = DisplayFormatters.getTimingColor(
      result.timing.classification,
    );

    // Format timing error with sign
    final errorMs = result.timing.errorMs;
    String timingText;
    if (errorMs > 0) {
      timingText = '${DisplayFormatters.formatTimingError(errorMs)} LATE';
    } else if (errorMs < 0) {
      timingText = '${DisplayFormatters.formatTimingError(errorMs)} EARLY';
    } else {
      timingText = '${DisplayFormatters.formatTimingError(errorMs)} ON-TIME';
    }

    return Container(
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
    );
  }
}
