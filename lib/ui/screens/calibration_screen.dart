import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../bridge/api.dart/api.dart' as api;
import '../../di/service_locator.dart';
import '../../models/calibration_progress.dart';
import '../../services/audio/i_audio_service.dart';
import '../../services/error_handler/exceptions.dart';
import '../../services/storage/i_storage_service.dart';
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
///
/// Use [CalibrationScreen.create] for production code (resolves from GetIt).
/// Use [CalibrationScreen.test] for widget tests (accepts mock services).
class CalibrationScreen extends StatefulWidget {
  /// Audio service for calibration control
  final IAudioService audioService;

  /// Storage service for persisting calibration data
  final IStorageService storageService;

  /// Private constructor for dependency injection.
  ///
  /// All service dependencies are required and non-nullable.
  /// This enforces proper dependency injection and prevents
  /// default instantiation which blocks testability.
  const CalibrationScreen._({
    super.key,
    required this.audioService,
    required this.storageService,
  });

  /// Factory constructor for production use.
  ///
  /// Resolves all service dependencies from the GetIt service locator.
  /// Ensures services are properly registered before use.
  ///
  /// Throws [StateError] if services are not registered in GetIt.
  ///
  /// Example:
  /// ```dart
  /// GoRoute(
  ///   path: '/calibration',
  ///   builder: (context, state) => CalibrationScreen.create(),
  /// )
  /// ```
  factory CalibrationScreen.create({Key? key}) {
    return CalibrationScreen._(
      key: key,
      audioService: getIt<IAudioService>(),
      storageService: getIt<IStorageService>(),
    );
  }

  /// Test constructor for widget testing.
  ///
  /// Accepts mock service implementations for testing.
  /// This enables isolated widget testing without real service dependencies.
  ///
  /// Example:
  /// ```dart
  /// await tester.pumpWidget(
  ///   MaterialApp(
  ///     home: CalibrationScreen.test(
  ///       audioService: mockAudio,
  ///       storageService: mockStorage,
  ///     ),
  ///   ),
  /// );
  /// ```
  @visibleForTesting
  factory CalibrationScreen.test({
    Key? key,
    required IAudioService audioService,
    required IStorageService storageService,
  }) {
    return CalibrationScreen._(
      key: key,
      audioService: audioService,
      storageService: storageService,
    );
  }

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
    // Initialize storage service and start calibration
    _initializeAndStart();
  }

  /// Initialize storage service and start calibration
  Future<void> _initializeAndStart() async {
    print('[CalibrationScreen] Initializing and starting...');
    try {
      // Initialize storage service before any operations
      print('[CalibrationScreen] Initializing storage service');
      await widget.storageService.init();
      print('[CalibrationScreen] Storage service initialized');

      // Start calibration automatically when screen loads
      print('[CalibrationScreen] About to start calibration');
      await _startCalibration();
      print('[CalibrationScreen] Calibration start completed');
    } catch (e, stackTrace) {
      print('[CalibrationScreen] Error in _initializeAndStart: $e');
      print('[CalibrationScreen] Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
        _isCalibrating = false;
      });
    }
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
    print('[CalibrationScreen] Starting calibration...');
    try {
      // Start calibration procedure
      print('[CalibrationScreen] Calling audioService.startCalibration()');
      await widget.audioService.startCalibration();
      print('[CalibrationScreen] startCalibration() completed successfully');

      // Subscribe to calibration progress stream
      print('[CalibrationScreen] Getting calibration stream');
      final stream = widget.audioService.getCalibrationStream();
      print('[CalibrationScreen] Got calibration stream');

      setState(() {
        _isCalibrating = true;
        _calibrationStream = stream;
        _currentProgress = null;
        _errorMessage = null;
      });
      print('[CalibrationScreen] State updated, calibration started');
    } on CalibrationServiceException catch (e) {
      print('[CalibrationScreen] CalibrationServiceException: ${e.message}');
      print('[CalibrationScreen] Error code: ${e.errorCode}');
      print('[CalibrationScreen] Original error: ${e.originalError}');
      setState(() {
        _errorMessage = e.message;
        _isCalibrating = false;
      });
    } on AudioServiceException catch (e) {
      print('[CalibrationScreen] AudioServiceException: ${e.message}');
      print('[CalibrationScreen] Error code: ${e.errorCode}');
      print('[CalibrationScreen] Original error: ${e.originalError}');
      setState(() {
        _errorMessage = e.message;
        _isCalibrating = false;
      });
    } catch (e, stackTrace) {
      print('[CalibrationScreen] Unexpected error: $e');
      print('[CalibrationScreen] Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Failed to start calibration: $e';
        _isCalibrating = false;
      });
    }
  }

  /// Finish calibration and compute thresholds
  Future<void> _finishCalibration() async {
    try {
      await widget.audioService.finishCalibration();
      final calibrationData = await _retrieveCalibrationData();
      await widget.storageService.saveCalibration(calibrationData);
      await _handleSuccessfulCalibration();
    } on CalibrationServiceException catch (e) {
      _handleCalibrationError(e.message);
    } on StorageException catch (e) {
      _handleCalibrationError('Failed to save calibration: ${e.message}');
    } catch (e) {
      _handleCalibrationError('Calibration failed: $e');
    }
  }

  /// Retrieve calibration data from Rust backend
  Future<CalibrationData> _retrieveCalibrationData() async {
    final calibrationStateJson = await api.getCalibrationState();
    final calibrationJson =
        jsonDecode(calibrationStateJson) as Map<String, dynamic>;
    return CalibrationData.fromJson(calibrationJson);
  }

  /// Handle successful calibration completion
  Future<void> _handleSuccessfulCalibration() async {
    if (mounted) {
      await _showSuccessDialog();
    }
    if (mounted) {
      context.go('/training');
    }
  }

  /// Handle calibration error by updating state
  void _handleCalibrationError(String message) {
    setState(() {
      _errorMessage = message;
      _isCalibrating = false;
    });
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

  /// Show success dialog after calibration completion
  Future<void> _showSuccessDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to dismiss
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
            onPressed: () => context.go('/'),
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
          return _buildStreamErrorDisplay(snapshot.error);
        }

        _handleProgressUpdate(snapshot.data);

        if (_currentProgress != null) {
          return _buildProgressContent(_currentProgress!);
        } else {
          return _buildWaitingDisplay();
        }
      },
    );
  }

  /// Build stream error display widget
  Widget _buildStreamErrorDisplay(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 24),
          Text(
            'Stream error: $error',
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

  /// Handle progress update from stream
  void _handleProgressUpdate(CalibrationProgress? progress) {
    if (progress != null) {
      _currentProgress = progress;
      if (_currentProgress!.isCalibrationComplete) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _finishCalibration();
        });
      }
    }
  }

  /// Build waiting for data display widget
  Widget _buildWaitingDisplay() {
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

  /// Build progress content widget
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

  /// Build overall progress header with step indicator
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

  /// Build current sound instructions with icon and text
  Widget _buildCurrentSoundInstructions(CalibrationProgress progress) {
    final sound = progress.currentSound;

    return Column(
      children: [
        Icon(Icons.mic, size: 80, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          _getInstructionText(sound),
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

  /// Build progress indicator for current sound
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

  /// Build status message for sound completion and calibration completion
  Widget _buildStatusMessage(CalibrationProgress progress) {
    final sound = progress.currentSound;

    if (progress.isCalibrationComplete) {
      return const StatusCard(
        color: Colors.green,
        icon: Icons.celebration,
        title: 'Calibration Complete!',
        subtitle: 'Computing thresholds...',
        iconSize: 48.0,
      );
    }

    if (progress.isSoundComplete) {
      return StatusCard(
        color: Colors.green,
        icon: Icons.check_circle,
        title: '${sound.displayName} samples complete!',
        subtitle: sound.next != null
            ? 'Moving to ${sound.next!.displayName}...'
            : null,
      );
    }

    return const SizedBox.shrink();
  }
}
