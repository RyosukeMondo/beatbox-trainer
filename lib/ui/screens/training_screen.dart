import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../di/service_locator.dart';
import '../../models/classification_result.dart';
import '../../controllers/training/training_controller.dart';
import '../../services/debug/i_debug_service.dart';
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
  /// Current classification result (null when idle)
  ClassificationResult? _currentResult;

  /// Whether debug mode is enabled (loaded from settings)
  bool _debugModeEnabled = false;

  /// Whether debug overlay is currently visible
  bool _debugOverlayVisible = false;

  /// Animation controller for fade-out effect of classification feedback
  late AnimationController _fadeAnimationController;

  /// Fade animation for classification feedback (1.0 = fully visible, 0.0 = invisible)
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadDebugSettings();

    // Initialize fade animation controller (500ms fade-out)
    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Create fade animation (linear fade from 1.0 to 0.0)
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeOut),
    );
  }

  /// Load debug mode setting from controller's settings service
  Future<void> _loadDebugSettings() async {
    try {
      final debugMode = await widget.controller.getDebugMode();
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
    // Note: We call dispose without awaiting since Widget.dispose() is synchronous
    // The controller will handle async cleanup internally
    widget.controller.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  /// Handle start training button press
  Future<void> _handleStartTraining() async {
    try {
      await widget.controller.startTraining();
      setState(() {}); // Refresh UI after state change
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
  Future<void> _handleBpmChange(int newBpm) async {
    try {
      await widget.controller.updateBpm(newBpm);
      setState(() {}); // Refresh UI to show new BPM
    } catch (e) {
      if (mounted) {
        await ErrorDialog.show(
          context,
          title: 'BPM Update Error',
          message: 'Failed to update BPM: $e',
        );
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
    setState(() {
      _debugOverlayVisible = !_debugOverlayVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(context),
      floatingActionButton: _buildFloatingActionButton(),
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

  /// Build app bar with title and action buttons
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
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
          Expanded(child: _buildClassificationArea()),
        ],
      ),
    );
  }

  /// Build BPM display text
  Widget _buildBpmDisplay(BuildContext context) {
    return Text(
      DisplayFormatters.formatBpm(widget.controller.currentBpm),
      style: Theme.of(
        context,
      ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    );
  }

  /// Build BPM slider control
  Widget _buildBpmSlider() {
    final currentBpm = widget.controller.currentBpm;
    return Slider(
      value: currentBpm.toDouble(),
      min: 40,
      max: 240,
      divisions: 200,
      label: DisplayFormatters.formatBpm(currentBpm),
      onChanged: (value) => _handleBpmChange(value.round()),
    );
  }

  /// Build classification results area
  Widget _buildClassificationArea() {
    if (!widget.controller.isTraining) {
      return _buildIdleState();
    }

    return StreamBuilder<ClassificationResult>(
      stream: widget.controller.classificationStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingOverlay(message: 'Starting audio engine...');
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (snapshot.hasData) {
          _currentResult = snapshot.data;
          // Restart fade animation on each new result
          _fadeAnimationController.forward(from: 0.0);
          return _buildClassificationDisplay(_currentResult!);
        }

        // Waiting for first classification
        return _buildWaitingForSoundState();
      },
    );
  }

  /// Build idle state (not training)
  Widget _buildIdleState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Press Start to begin training',
            style: TextStyle(fontSize: 24, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// Build waiting for sound state (training but no results yet)
  Widget _buildWaitingForSoundState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Make a beatbox sound!',
            style: TextStyle(fontSize: 24, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Stream error: $error',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build classification result display widget with fade animation
  Widget _buildClassificationDisplay(ClassificationResult result) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSoundTypeDisplay(result),
            const SizedBox(height: 32),
            _buildTimingFeedbackDisplay(result),
            const SizedBox(height: 24),
            _buildConfidenceMeter(result),
          ],
        ),
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

    final errorMs = result.timing.errorMs;
    final timingText = _formatTimingText(errorMs);

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

  /// Format timing error text with sign
  String _formatTimingText(double errorMs) {
    if (errorMs > 0) {
      return '${DisplayFormatters.formatTimingError(errorMs)} LATE';
    } else if (errorMs < 0) {
      return '${DisplayFormatters.formatTimingError(errorMs)} EARLY';
    } else {
      return '${DisplayFormatters.formatTimingError(errorMs)} ON-TIME';
    }
  }

  /// Build confidence meter with color-coded progress bar
  Widget _buildConfidenceMeter(ClassificationResult result) {
    final confidencePercentage = (result.confidence * 100).round();
    final confidenceColor = _getConfidenceColor(result.confidence);

    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConfidenceHeader(confidencePercentage, confidenceColor),
          const SizedBox(height: 8),
          _buildConfidenceBar(result.confidence, confidenceColor),
        ],
      ),
    );
  }

  /// Get confidence color based on confidence level
  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) {
      return Colors.green;
    } else if (confidence >= 0.5) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Build confidence header row
  Widget _buildConfidenceHeader(int percentage, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Confidence',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Build confidence progress bar
  Widget _buildConfidenceBar(double confidence, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: confidence,
        backgroundColor: Colors.grey[300],
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: 20,
      ),
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
