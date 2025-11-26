import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../di/service_locator.dart';
import '../../controllers/training/training_controller.dart';
import '../../services/debug/i_debug_service.dart';
import '../../services/debug/i_debug_capabilities.dart';
import '../widgets/error_dialog.dart';
import '../widgets/debug_overlay.dart';
import '../widgets/training_classification_section.dart';
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
    // Note: We call dispose without awaiting since Widget.dispose() is synchronous
    // The controller will handle async cleanup internally
    widget.controller.dispose();
    super.dispose();
  }

  /// Handle start training button press
  Future<void> _handleStartTraining() async {
    try {
      await widget.controller.startTraining();
      setState(() {
        _bpmValue = widget.controller.currentBpm.toDouble();
      }); // Refresh UI after state change
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
      await widget.controller.stopTraining();
      setState(() {}); // Refresh UI after state change
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
      appBar: _buildAppBar(context),
      body: _buildBody(context),
      floatingActionButton: _buildFloatingActionButton(),
    );

    // Wrap with DebugOverlay if debug mode is enabled and overlay is visible
    if (_canShowDebugOverlay && _debugOverlayVisible) {
      return DebugOverlay(
        debugService: widget.debugService,
        onClose: _toggleDebugOverlay,
        child: scaffold,
      );
    }

    return scaffold;
  }

  /// Build app bar with title and action buttons
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Beatbox Trainer'),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => context.go('/settings'),
          tooltip: 'Settings',
        ),
      ],
    );
  }

  /// Build main body content
  Widget _buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBpmDisplay(context),
          const SizedBox(height: 16),
          _buildBpmSlider(),
          const SizedBox(height: 32),
          Expanded(
            child: TrainingClassificationSection(
              isTraining: widget.controller.isTraining,
              classificationStream: widget.controller.classificationStream,
            ),
          ),
        ],
      ),
    );
  }

  /// Build BPM display text
  Widget _buildBpmDisplay(BuildContext context) {
    return Text(
      DisplayFormatters.formatBpm(_bpmValue.round()),
      style: Theme.of(
        context,
      ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
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
    return FloatingActionButton.extended(
      onPressed: isTraining ? _handleStopTraining : _handleStartTraining,
      icon: Icon(isTraining ? Icons.stop : Icons.play_arrow),
      label: Text(isTraining ? 'Stop' : 'Start'),
      backgroundColor: isTraining ? Colors.red : Colors.green,
    );
  }
}
