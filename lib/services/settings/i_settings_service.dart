/// Settings service interface for app configuration persistence.
///
/// This interface abstracts settings storage operations (via SharedPreferences),
/// enabling dependency injection in screens and mocking in tests.
///
/// The service handles app configuration including BPM, debug mode, and
/// classifier level, allowing users to customize their training experience.
abstract class ISettingsService {
  /// Initialize the settings service.
  ///
  /// Must be called before using any other methods. This initializes the
  /// underlying SharedPreferences instance asynchronously.
  ///
  /// Example:
  /// ```dart
  /// await settingsService.init();
  /// ```
  Future<void> init();

  /// Get the default BPM (beats per minute) setting.
  ///
  /// Returns the user's preferred BPM for training sessions. If no value
  /// is set, returns the default value of 120 BPM.
  ///
  /// Returns:
  /// - int: BPM value between 40 and 240 (default: 120)
  ///
  /// Example:
  /// ```dart
  /// final bpm = await settingsService.getBpm();
  /// print('Training at $bpm BPM');
  /// ```
  Future<int> getBpm();

  /// Set the default BPM (beats per minute) setting.
  ///
  /// Stores the user's preferred BPM for training sessions. The value
  /// must be between 40 and 240 BPM.
  ///
  /// Parameters:
  /// - [bpm]: BPM value to store (must be 40-240)
  ///
  /// Throws:
  /// - [ArgumentError] if BPM is outside valid range (40-240)
  ///
  /// Example:
  /// ```dart
  /// await settingsService.setBpm(140);
  /// ```
  Future<void> setBpm(int bpm);

  /// Get the debug mode setting.
  ///
  /// Returns whether debug mode is enabled. Debug mode shows real-time
  /// audio metrics and onset event logs during training.
  ///
  /// Returns:
  /// - true if debug mode is enabled
  /// - false if debug mode is disabled (default)
  ///
  /// Example:
  /// ```dart
  /// final debugEnabled = await settingsService.getDebugMode();
  /// if (debugEnabled) {
  ///   // Show debug overlay
  /// }
  /// ```
  Future<bool> getDebugMode();

  /// Set the debug mode setting.
  ///
  /// Enables or disables debug mode. When enabled, the training screen
  /// shows real-time audio metrics and onset event logs.
  ///
  /// Parameters:
  /// - [enabled]: true to enable debug mode, false to disable
  ///
  /// Example:
  /// ```dart
  /// await settingsService.setDebugMode(true);
  /// ```
  Future<void> setDebugMode(bool enabled);

  /// Get the classifier level setting.
  ///
  /// Returns the current classifier level:
  /// - Level 1: Beginner (3 categories: KICK, SNARE, HIHAT)
  /// - Level 2: Advanced (6 categories with subcategories)
  ///
  /// Returns:
  /// - int: Classifier level (1 or 2, default: 1)
  ///
  /// Example:
  /// ```dart
  /// final level = await settingsService.getClassifierLevel();
  /// print('Using classifier level $level');
  /// ```
  Future<int> getClassifierLevel();

  /// Set the classifier level setting.
  ///
  /// Changes the classifier level. Note that changing the classifier level
  /// requires recalibration, as different levels have different threshold
  /// requirements.
  ///
  /// Parameters:
  /// - [level]: Classifier level (1 = beginner, 2 = advanced)
  ///
  /// Throws:
  /// - [ArgumentError] if level is not 1 or 2
  ///
  /// Example:
  /// ```dart
  /// await settingsService.setClassifierLevel(2);
  /// // User should be prompted to recalibrate
  /// ```
  Future<void> setClassifierLevel(int level);
}
