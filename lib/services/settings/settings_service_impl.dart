import 'package:shared_preferences/shared_preferences.dart';
import 'i_settings_service.dart';

/// Concrete implementation of [ISettingsService] using SharedPreferences
///
/// This implementation persists app settings to device storage using
/// SharedPreferences, allowing configuration to survive app restarts.
///
/// All settings have sensible defaults and validation to ensure data integrity.
/// The service follows async initialization pattern - [init] must be called
/// before using any other methods.
///
/// Storage keys and defaults:
/// - 'default_bpm': 120 (range: 40-240)
/// - 'debug_mode': false
/// - 'classifier_level': 1 (range: 1-2)
class SettingsServiceImpl implements ISettingsService {
  /// SharedPreferences instance for persistent storage
  SharedPreferences? _prefs;

  /// Storage key for default BPM setting
  static const String _keyDefaultBpm = 'default_bpm';

  /// Storage key for debug mode setting
  static const String _keyDebugMode = 'debug_mode';

  /// Storage key for classifier level setting
  static const String _keyClassifierLevel = 'classifier_level';

  /// Default BPM value
  static const int _defaultBpm = 120;

  /// Default debug mode value
  static const bool _defaultDebugMode = false;

  /// Default classifier level value
  static const int _defaultClassifierLevel = 1;

  /// Minimum valid BPM value
  static const int _minBpm = 40;

  /// Maximum valid BPM value
  static const int _maxBpm = 240;

  /// Minimum valid classifier level
  static const int _minLevel = 1;

  /// Maximum valid classifier level
  static const int _maxLevel = 2;

  @override
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      throw SettingsException('Failed to initialize SharedPreferences', e);
    }
  }

  /// Ensure SharedPreferences is initialized before use
  ///
  /// Throws [SettingsException] if [init] has not been called.
  void _ensureInitialized() {
    if (_prefs == null) {
      throw SettingsException(
        'SettingsService not initialized. Call init() before using.',
      );
    }
  }

  @override
  Future<int> getBpm() async {
    _ensureInitialized();

    try {
      final bpm = _prefs!.getInt(_keyDefaultBpm) ?? _defaultBpm;

      // Validate stored value is in range, return default if not
      if (bpm < _minBpm || bpm > _maxBpm) {
        return _defaultBpm;
      }

      return bpm;
    } catch (e) {
      throw SettingsException('Failed to get BPM setting', e);
    }
  }

  @override
  Future<void> setBpm(int bpm) async {
    _ensureInitialized();

    // Validate BPM range
    if (bpm < _minBpm || bpm > _maxBpm) {
      throw ArgumentError(
        'BPM must be between $_minBpm and $_maxBpm, got: $bpm',
      );
    }

    try {
      await _prefs!.setInt(_keyDefaultBpm, bpm);
    } catch (e) {
      throw SettingsException('Failed to set BPM setting', e);
    }
  }

  @override
  Future<bool> getDebugMode() async {
    _ensureInitialized();

    try {
      return _prefs!.getBool(_keyDebugMode) ?? _defaultDebugMode;
    } catch (e) {
      throw SettingsException('Failed to get debug mode setting', e);
    }
  }

  @override
  Future<void> setDebugMode(bool enabled) async {
    _ensureInitialized();

    try {
      await _prefs!.setBool(_keyDebugMode, enabled);
    } catch (e) {
      throw SettingsException('Failed to set debug mode setting', e);
    }
  }

  @override
  Future<int> getClassifierLevel() async {
    _ensureInitialized();

    try {
      final level =
          _prefs!.getInt(_keyClassifierLevel) ?? _defaultClassifierLevel;

      // Validate stored value is in range, return default if not
      if (level < _minLevel || level > _maxLevel) {
        return _defaultClassifierLevel;
      }

      return level;
    } catch (e) {
      throw SettingsException('Failed to get classifier level setting', e);
    }
  }

  @override
  Future<void> setClassifierLevel(int level) async {
    _ensureInitialized();

    // Validate classifier level
    if (level < _minLevel || level > _maxLevel) {
      throw ArgumentError(
        'Classifier level must be between $_minLevel and $_maxLevel, got: $level',
      );
    }

    try {
      await _prefs!.setInt(_keyClassifierLevel, level);
    } catch (e) {
      throw SettingsException('Failed to set classifier level setting', e);
    }
  }
}

/// Exception thrown when settings operations fail
///
/// This exception wraps underlying errors from SharedPreferences operations
/// or validation failures, providing context about what operation failed.
class SettingsException implements Exception {
  /// Human-readable error message
  final String message;

  /// Optional underlying error that caused this exception
  final Object? cause;

  /// Creates a new SettingsException
  ///
  /// Parameters:
  /// - [message]: Description of what operation failed
  /// - [cause]: Optional underlying error
  const SettingsException(this.message, [this.cause]);

  @override
  String toString() {
    if (cause != null) {
      return 'SettingsException: $message (caused by: $cause)';
    }
    return 'SettingsException: $message';
  }
}
