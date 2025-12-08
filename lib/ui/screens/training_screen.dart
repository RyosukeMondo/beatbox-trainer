import 'dart:async';
import 'package:flutter/material.dart';
import '../../di/service_locator.dart';
import '../../controllers/training/training_controller.dart';
import '../../services/debug/i_debug_service.dart';
import '../../services/debug/i_debug_capabilities.dart';
import '../widgets/error_dialog.dart';
import '../widgets/debug_overlay.dart';
import '../widgets/training_classification_section.dart';
import '../widgets/training_level_indicator.dart';
import '../utils/display_formatters.dart';
import '../widgets/screen_background.dart';

/// TrainingScreen provides the main training UI with real-time feedback
///
/// Features:
/// - BPM control with slider (40-240 range)
/// - Start/Stop training buttons
/// - Real-time classification results stream
/// - Debug overlay toggle (when debug mode enabled)
/// - Error handling for audio engine failures
///
/// This screen uses dependency injection for the controller and debug service,
/// enabling testability and separation of concerns.
///
/// Use [TrainingScreen.create] for production code (resolves from GetIt).
/// Use [TrainingScreen.test] for widget tests (accepts mock controller).
class TrainingScreen extends StatefulWidget {
  /// Controller handling business logic
  final TrainingController controller;

  /// Debug service for debug overlay data
  final IDebugService debugService;

  /// Private constructor for dependency injection.
  ///
  /// All dependencies are required and non-nullable.
  /// This enforces proper dependency injection and prevents
  /// default instantiation which blocks testability.
  const TrainingScreen._({
    super.key,
    required this.controller,
    required this.debugService,
  });

  /// Factory constructor for production use.
  ///
  /// Resolves all service dependencies from the GetIt service locator
  /// and creates the TrainingController.
  ///
  /// Throws [StateError] if services are not registered in GetIt.
  ///
  /// Example:
  /// ```dart
  /// GoRoute(
  ///   path: '/training',
  ///   builder: (context, state) => TrainingScreen.create(),
  /// )
  /// ```
  factory TrainingScreen.create({Key? key}) {
    return TrainingScreen._(
      key: key,
      controller: TrainingController(
        audioService: getIt(),
        permissionService: getIt(),
        settingsService: getIt(),
        storageService: getIt(),
      ),
      debugService: getIt(),
    );
  }

  /// Test constructor for widget testing.
  ///
  /// Accepts mock controller and debug service for testing.
  /// This enables isolated widget testing without real dependencies.
  ///
  /// Example:
  /// ```dart
  /// await tester.pumpWidget(
  ///   MaterialApp(
  ///     home: TrainingScreen.test(
  ///       controller: mockController,
  ///       debugService: mockDebug,
  ///     ),
  ///   ),
  /// );
  /// ```
  @visibleForTesting
  factory TrainingScreen.test({
    Key? key,
    required TrainingController controller,
    required IDebugService debugService,
  }) {
    return TrainingScreen._(
      key: key,
      controller: controller,
      debugService: debugService,
    );
  }

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen>
    with SingleTickerProviderStateMixin {
  /// Current BPM value reflected in the UI slider
  double _bpmValue = 120;

  /// Avoid overlapping BPM commits while slider settles
  bool _isUpdatingBpm = false;

  /// Whether debug mode is enabled (loaded from settings)
  bool _debugModeEnabled = false;

  /// Whether telemetry streams are available from the debug service
  bool _telemetryAvailable = true;

  /// Whether debug overlay is currently visible
  bool _debugOverlayVisible = false;

  /// Current audio metrics for level indicator
  AudioMetrics? _currentMetrics;

  /// Subscription to audio metrics stream
  StreamSubscription<AudioMetrics>? _metricsSubscription;

  /// Noise floor RMS from calibration (for gate calculation)
  double _noiseFloorRms = 0.01;

  @override
  void initState() {
    super.initState();
    _bpmValue = widget.controller.currentBpm.toDouble();
    _loadDebugSettings();
  }

  /// Load debug mode setting from controller's settings service
  Future<void> _loadDebugSettings() async {
    try {
      final debugMode = await widget.controller.getDebugMode();
      final telemetryAvailable = _resolveTelemetryAvailability();
      if (mounted) {
        setState(() {
          _debugModeEnabled = debugMode;
          _telemetryAvailable = telemetryAvailable;
          _debugOverlayVisible = debugMode && telemetryAvailable;
        });
      }
    } catch (e) {
      // Log error but don't block UI
      debugPrint('Failed to load debug settings: $e');
    }
  }

  @override
  void dispose() {
    // Cancel metrics subscription
    _metricsSubscription?.cancel();
    // Note: We call dispose without awaiting since Widget.dispose() is synchronous
    // The controller will handle async cleanup internally
    widget.controller.dispose();
    super.dispose();
  }

  /// Handle start training button press
  Future<void> _handleStartTraining() async {
    debugPrint('[TrainingScreen] _handleStartTraining called');
    try {
      debugPrint('[TrainingScreen] Calling controller.startTraining()...');
      await widget.controller.startTraining();
      debugPrint('[TrainingScreen] controller.startTraining() completed');

      // Load noise floor RMS from calibration
      final noiseFloor = await widget.controller.getNoiseFloorRms();

      // Start audio metrics subscription for level indicator
      _metricsSubscription?.cancel();
      _metricsSubscription = widget.debugService.getAudioMetricsStream().listen(
        (metrics) {
          if (mounted) {
            setState(() {
              _currentMetrics = metrics;
            });
          }
        },
        onError: (e) {
          debugPrint('[TrainingScreen] Audio metrics stream error: $e');
        },
      );

      setState(() {
        _bpmValue = widget.controller.currentBpm.toDouble();
        _noiseFloorRms = noiseFloor;
      });
    } on PermissionException catch (e) {
      if (mounted) {
        await _showPermissionDialog(e.message);
      }
    } catch (e) {
      if (mounted) {
        await ErrorDialog.show(
          context,
          message: 'Failed to start training: $e',
          onRetry: _handleStartTraining,
        );
      }
    }
  }

  /// Handle stop training button press
  Future<void> _handleStopTraining() async {
    try {
      // Cancel metrics subscription
      _metricsSubscription?.cancel();
      _metricsSubscription = null;

      await widget.controller.stopTraining();
      setState(() {
        _currentMetrics = null;
      });
    } catch (e) {
      if (mounted) {
        await ErrorDialog.show(context, message: 'Failed to stop training: $e');
      }
    }
  }

  /// Handle BPM slider change
  void _handleBpmDrag(double newValue) {
    if (_isUpdatingBpm) {
      return;
    }
    setState(() {
      _bpmValue = newValue;
    });
  }

  /// Commit BPM change when slider drag ends to avoid spamming FFI + storage
  Future<void> _commitBpmChange(double newValue) async {
    if (_isUpdatingBpm) {
      return;
    }

    final newBpm = newValue.round();
    setState(() {
      _isUpdatingBpm = true;
      _bpmValue = newValue;
    });

    try {
      await widget.controller.updateBpm(newBpm);
      if (mounted) {
        setState(() {
          _bpmValue = widget.controller.currentBpm.toDouble();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bpmValue = widget.controller.currentBpm.toDouble();
        });
        await ErrorDialog.show(
          context,
          title: 'BPM Update Error',
          message: 'Failed to update BPM: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingBpm = false;
        });
      }
    }
  }

  /// Show permission dialog
  Future<void> _showPermissionDialog(String message) async {
    return ErrorDialog.show(
      context,
      title: 'Microphone Permission Required',
      message: message,
    );
  }

  /// Toggle debug overlay visibility
  void _toggleDebugOverlay() {
    if (!_telemetryAvailable) {
      return;
    }
    setState(() {
      _debugOverlayVisible = !_debugOverlayVisible;
    });
  }

  /// Whether debug overlay affordances should be visible
  bool get _canShowDebugOverlay => _debugModeEnabled && _telemetryAvailable;

  bool _resolveTelemetryAvailability() {
    final candidate = widget.debugService;
    if (candidate is DebugTelemetryAvailability) {
      final availability = candidate as DebugTelemetryAvailability;
      return availability.telemetryAvailable;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(context),
      body: _buildBody(context),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );

    final wrapped = ScreenBackground(
      asset: 'assets/images/backgrounds/bg_training.png',
      overlayOpacity: 0.62,
      child: scaffold,
    );

    // Wrap with DebugOverlay if debug mode is enabled and overlay is visible
    if (_canShowDebugOverlay && _debugOverlayVisible) {
      return DebugOverlay(
        debugService: widget.debugService,
        onClose: _toggleDebugOverlay,
        child: wrapped,
      );
    }

    return wrapped;
  }

  /// Build app bar with title and action buttons
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Beatbox Trainer'),
      backgroundColor: Colors.black.withValues(alpha: 0.25),
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      actions: [
        if (_canShowDebugOverlay)
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
      ],
    );
  }

  /// Build main body content
  Widget _buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              offset: Offset(0, 12),
              blurRadius: 28,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBpmDisplay(context),
              const SizedBox(height: 16),
              _buildBpmSlider(),
              const SizedBox(height: 16),
              // Real-time audio level indicator (visible when training)
              if (widget.controller.isTraining)
                TrainingLevelIndicator(
                  metrics: _currentMetrics,
                  noiseFloorRms: _noiseFloorRms,
                ),
              const SizedBox(height: 16),
              Expanded(
                child: TrainingClassificationSection(
                  isTraining: widget.controller.isTraining,
                  classificationStream: widget.controller.classificationStream,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build BPM display text
  Widget _buildBpmDisplay(BuildContext context) {
    return Text(
      DisplayFormatters.formatBpm(_bpmValue.round()),
      style: Theme.of(context).textTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Build BPM slider control
  Widget _buildBpmSlider() {
    return Slider(
      value: _bpmValue,
      min: 40,
      max: 240,
      divisions: 200,
      label: DisplayFormatters.formatBpm(_bpmValue.round()),
      onChanged: _isUpdatingBpm ? null : _handleBpmDrag,
      onChangeEnd: _commitBpmChange,
    );
  }

  /// Build floating action button for start/stop
  Widget _buildFloatingActionButton() {
    final isTraining = widget.controller.isTraining;
    final asset = isTraining
        ? 'assets/images/buttons/cta_secondary.png'
        : 'assets/images/buttons/cta_primary.png';
    final iconAsset = isTraining
        ? 'assets/images/icons/icon_stop.png'
        : 'assets/images/icons/icon_play.png';
    final label = isTraining ? 'Stop' : 'Start';

    return SizedBox(
      width: 220,
      height: 72,
      child: ElevatedButton(
        onPressed: isTraining ? _handleStopTraining : _handleStartTraining,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          elevation: 10,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.deepPurpleAccent.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(36),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(asset, fit: BoxFit.cover),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(iconAsset, height: 26, fit: BoxFit.contain),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
