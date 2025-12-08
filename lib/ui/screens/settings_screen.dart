import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../di/service_locator.dart';
import '../../services/settings/i_settings_service.dart';
import '../../services/storage/i_storage_service.dart';
import '../widgets/screen_background.dart';

/// Settings screen for configuring app preferences
///
/// Features:
/// - Default BPM slider (40-240 range)
/// - Debug mode toggle
/// - Classifier level selection (Beginner/Advanced)
/// - Recalibrate button
///
/// All settings persist across app restarts via SharedPreferences.
/// Changing classifier level requires recalibration (shows warning dialog).
///
/// This screen uses dependency injection for services, enabling
/// testability and separation of concerns.
///
/// Use [SettingsScreen.create] for production code (resolves from GetIt).
/// Use [SettingsScreen.test] for widget tests (accepts mock services).
class SettingsScreen extends StatefulWidget {
  /// Settings service for BPM, debug mode, and classifier level
  final ISettingsService settingsService;

  /// Storage service for clearing calibration
  final IStorageService storageService;

  /// Private constructor for dependency injection.
  ///
  /// All service dependencies are required and non-nullable.
  /// This enforces proper dependency injection and prevents
  /// default instantiation which blocks testability.
  const SettingsScreen._({
    super.key,
    required this.settingsService,
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
  ///   path: '/settings',
  ///   builder: (context, state) => SettingsScreen.create(),
  /// )
  /// ```
  factory SettingsScreen.create({Key? key}) {
    return SettingsScreen._(
      key: key,
      settingsService: getIt<ISettingsService>(),
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
  ///     home: SettingsScreen.test(
  ///       settingsService: mockSettings,
  ///       storageService: mockStorage,
  ///     ),
  ///   ),
  /// );
  /// ```
  @visibleForTesting
  factory SettingsScreen.test({
    Key? key,
    required ISettingsService settingsService,
    required IStorageService storageService,
  }) {
    return SettingsScreen._(
      key: key,
      settingsService: settingsService,
      storageService: storageService,
    );
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Current default BPM value
  int _defaultBpm = 120;

  /// Whether debug mode is enabled
  bool _debugMode = false;

  /// Current classifier level (1 = beginner, 2 = advanced)
  int _classifierLevel = 1;

  /// Whether settings are currently loading
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Load all settings from persistence
  Future<void> _loadSettings() async {
    try {
      await widget.settingsService.init();
      await widget.storageService.init();

      final bpm = await widget.settingsService.getBpm();
      final debug = await widget.settingsService.getDebugMode();
      final level = await widget.settingsService.getClassifierLevel();

      setState(() {
        _defaultBpm = bpm;
        _debugMode = debug;
        _classifierLevel = level;
        _isLoading = false;
      });
    } catch (e) {
      // Show error dialog if settings fail to load
      if (mounted) {
        _showErrorDialog('Failed to load settings: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ScreenBackground(
      asset: 'assets/images/backgrounds/bg_settings.png',
      overlayOpacity: 0.64,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Colors.black.withValues(alpha: 0.3),
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Theme(
                    data: theme.copyWith(
                      textTheme: theme.textTheme.apply(
                        bodyColor: Colors.white,
                        displayColor: Colors.white,
                      ),
                      sliderTheme: theme.sliderTheme.copyWith(
                        activeTrackColor: Colors.cyanAccent,
                        inactiveTrackColor: Colors.white30,
                        thumbColor: Colors.white,
                      ),
                      switchTheme: theme.switchTheme.copyWith(
                        thumbColor: WidgetStateProperty.resolveWith(
                          (states) => Colors.cyanAccent,
                        ),
                        trackColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.cyanAccent.withValues(alpha: 0.5)
                              : Colors.white24,
                        ),
                      ),
                    ),
                    child: ListView(
                      children: [
                        _buildBpmSetting(),
                        const Divider(),
                        _buildDebugModeSetting(),
                        if (_debugMode) ...[
                          const Divider(),
                          _buildDebugLabEntry(),
                        ],
                        const Divider(),
                        _buildClassifierLevelSetting(),
                        const Divider(),
                        _buildRecalibrateSetting(),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Build BPM slider setting
  Widget _buildBpmSetting() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Default BPM', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Training metronome tempo (beats per minute)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _buildBpmSlider(),
          Center(
            child: Text(
              '$_defaultBpm BPM',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ],
      ),
    );
  }

  /// Build BPM slider widget with labels
  Widget _buildBpmSlider() {
    return Row(
      children: [
        const Text('40'),
        Expanded(
          child: Slider(
            value: _defaultBpm.toDouble(),
            min: 40,
            max: 240,
            divisions: 200,
            label: _defaultBpm.toString(),
            onChanged: (value) {
              setState(() {
                _defaultBpm = value.round();
              });
            },
            onChangeEnd: (value) async {
              final newBpm = value.round();
              try {
                await widget.settingsService.setBpm(newBpm);
              } catch (e) {
                _showErrorDialog('Failed to save BPM: $e');
              }
            },
          ),
        ),
        const Text('240'),
      ],
    );
  }

  /// Build debug mode switch setting
  Widget _buildDebugModeSetting() {
    return SwitchListTile(
      title: const Text('Debug Mode'),
      subtitle: const Text(
        'Show real-time audio metrics and onset events during training',
      ),
      value: _debugMode,
      onChanged: (value) async {
        try {
          await widget.settingsService.setDebugMode(value);
          setState(() {
            _debugMode = value;
          });
        } catch (e) {
          _showErrorDialog('Failed to save debug mode: $e');
        }
      },
    );
  }

  /// Build entry point for the Debug Lab screen.
  Widget _buildDebugLabEntry() {
    return ListTile(
      leading: const Icon(Icons.science),
      title: const Text('Debug Lab'),
      subtitle: const Text(
        'Open diagnostics workspace with charts and SSE streaming.',
      ),
      onTap: () => context.go('/debug'),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  /// Build classifier level switch setting
  Widget _buildClassifierLevelSetting() {
    return SwitchListTile(
      title: const Text('Advanced Mode'),
      subtitle: Text(
        _classifierLevel == 1
            ? 'Beginner (3 categories: KICK, SNARE, HIHAT)'
            : 'Advanced (6 categories with subcategories)',
      ),
      value: _classifierLevel == 2,
      onChanged: (value) async {
        final newLevel = value ? 2 : 1;
        await _showRecalibrationWarningAndSwitchLevel(newLevel);
      },
    );
  }

  /// Build recalibrate button setting
  Widget _buildRecalibrateSetting() {
    return ListTile(
      title: const Text('Recalibrate'),
      subtitle: const Text(
        'Clear current calibration and start fresh calibration process',
      ),
      leading: const Icon(Icons.refresh),
      onTap: _handleRecalibrate,
    );
  }

  /// Show recalibration warning dialog and switch level if confirmed
  Future<void> _showRecalibrationWarningAndSwitchLevel(int newLevel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recalibration Required'),
        content: const Text(
          'Switching classifier levels requires recalibration. '
          'Your current calibration will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Recalibrate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Save new level, clear calibration, navigate to calibration screen
        await widget.settingsService.setClassifierLevel(newLevel);
        await widget.storageService.clearCalibration();

        setState(() {
          _classifierLevel = newLevel;
        });

        // Navigate to calibration screen
        if (mounted) {
          context.go('/calibration');
        }
      } catch (e) {
        _showErrorDialog('Failed to switch classifier level: $e');
      }
    }
  }

  /// Handle recalibrate button tap
  Future<void> _handleRecalibrate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Recalibration'),
        content: const Text(
          'Are you sure you want to recalibrate? '
          'This will clear your current calibration data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Recalibrate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.storageService.clearCalibration();

        // Navigate to calibration screen
        if (mounted) {
          context.go('/calibration');
        }
      } catch (e) {
        _showErrorDialog('Failed to clear calibration: $e');
      }
    }
  }

  /// Show error dialog with message
  void _showErrorDialog(String message) {
    showDialog<void>(
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
}
