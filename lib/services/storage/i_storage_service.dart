import '../../models/calibration_state.dart';

/// Storage service interface for calibration and settings persistence.
///
/// This interface abstracts persistent storage operations (via SharedPreferences),
/// enabling dependency injection in screens and mocking in tests.
///
/// The service handles calibration data persistence, allowing users to skip
/// calibration on subsequent app launches if calibration data exists.
abstract class IStorageService {
  /// Initialize the storage service.
  ///
  /// Must be called before using any other methods. This initializes the
  /// underlying SharedPreferences instance asynchronously.
  ///
  /// Example:
  /// ```dart
  /// await storageService.init();
  /// ```
  Future<void> init();

  /// Check if calibration data exists in storage.
  ///
  /// Returns true if valid calibration data is present, false otherwise.
  /// Used during app startup to determine whether to show onboarding or
  /// proceed directly to training screen.
  ///
  /// Returns:
  /// - true if calibration data exists and is valid
  /// - false if no calibration data or data is corrupted
  ///
  /// Example:
  /// ```dart
  /// final hasCalib = await storageService.hasCalibration();
  /// if (hasCalib) {
  ///   // Load calibration and go to training
  /// } else {
  ///   // Show onboarding
  /// }
  /// ```
  Future<bool> hasCalibration();

  /// Save calibration data to persistent storage.
  ///
  /// Stores calibration data as JSON, including level, timestamp, and thresholds.
  /// This data can be loaded on subsequent app launches to skip recalibration.
  ///
  /// Parameters:
  /// - [data]: The calibration data to persist
  ///
  /// Throws:
  /// - [StorageException] if serialization fails
  /// - [StorageException] if storage write operation fails
  ///
  /// Example:
  /// ```dart
  /// final calibData = CalibrationData(
  ///   level: 1,
  ///   timestamp: DateTime.now(),
  ///   thresholds: {'kick_threshold': 0.5, 'snare_threshold': 0.6},
  /// );
  /// await storageService.saveCalibration(calibData);
  /// ```
  Future<void> saveCalibration(CalibrationData data);

  /// Load calibration data from persistent storage.
  ///
  /// Retrieves previously saved calibration data. Returns null if no data
  /// exists or if deserialization fails.
  ///
  /// Returns:
  /// - [CalibrationData] if valid data exists
  /// - null if no data or deserialization fails
  ///
  /// Example:
  /// ```dart
  /// final calibData = await storageService.loadCalibration();
  /// if (calibData != null) {
  ///   print('Loaded calibration from ${calibData.timestamp}');
  /// }
  /// ```
  Future<CalibrationData?> loadCalibration();

  /// Clear calibration data from storage.
  ///
  /// Removes all stored calibration data. Used when user explicitly
  /// requests recalibration or switches classifier level.
  ///
  /// Example:
  /// ```dart
  /// await storageService.clearCalibration();
  /// // Navigate to calibration screen
  /// ```
  Future<void> clearCalibration();
}

/// Data class representing calibration state for persistence.
///
/// Contains all information needed to restore a calibration session:
/// - [level]: Classifier level (1 = beginner, 2 = advanced)
/// - [timestamp]: When calibration was performed
/// - [thresholds]: Map of feature names to threshold values
class CalibrationData {
  /// Classifier level (1 = beginner with 3 categories, 2 = advanced with 6 categories)
  final int level;

  /// Timestamp when calibration was performed
  final DateTime timestamp;

  /// Map of feature names to threshold values computed during calibration
  final Map<String, double> thresholds;

  CalibrationData({
    required this.level,
    required this.timestamp,
    required this.thresholds,
  });

  /// Create CalibrationData with sensible default thresholds.
  ///
  /// Useful for skipping calibration during testing or for users who want
  /// to try the app immediately. These defaults work reasonably well for
  /// most users but personalized calibration is recommended.
  ///
  /// Default thresholds match Rust CalibrationState::new_default():
  /// - t_kick_centroid = 1500 Hz
  /// - t_kick_zcr = 0.1
  /// - t_snare_centroid = 4000 Hz
  /// - t_hihat_zcr = 0.3
  factory CalibrationData.fromDefaults() {
    return CalibrationData(
      level: 1,
      timestamp: DateTime.now(),
      thresholds: {
        't_kick_centroid': 1500.0,
        't_kick_zcr': 0.1,
        't_snare_centroid': 4000.0,
        't_hihat_zcr': 0.3,
      },
    );
  }

  /// Create CalibrationData from JSON map.
  ///
  /// Used when deserializing from SharedPreferences storage.
  ///
  /// Parameters:
  /// - [json]: Map containing 'level', 'timestamp', and 'thresholds' keys
  ///
  /// Throws:
  /// - [FormatException] if JSON structure is invalid
  ///
  /// Example:
  /// ```dart
  /// final data = CalibrationData.fromJson({
  ///   'level': 1,
  ///   'timestamp': '2025-11-13T12:00:00.000',
  ///   'thresholds': {'kick_threshold': 0.5}
  /// });
  /// ```
  factory CalibrationData.fromJson(Map<String, dynamic> json) {
    return CalibrationData(
      level: json['level'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      thresholds: Map<String, double>.from(json['thresholds'] as Map),
    );
  }

  /// Convert CalibrationData to JSON map.
  ///
  /// Used when serializing for SharedPreferences storage.
  ///
  /// Returns:
  /// - Map with 'level', 'timestamp', and 'thresholds' keys
  ///
  /// Example:
  /// ```dart
  /// final json = calibData.toJson();
  /// final jsonString = jsonEncode(json);
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'timestamp': timestamp.toIso8601String(),
      'thresholds': thresholds,
    };
  }

  /// Convert CalibrationData to Rust CalibrationState JSON format.
  ///
  /// Flattens the thresholds map into top-level fields as expected by
  /// Rust's CalibrationState struct.
  ///
  /// Returns:
  /// - Map with 'level', 't_kick_centroid', 't_kick_zcr', 't_snare_centroid',
  ///   't_hihat_zcr', and 'is_calibrated' keys
  ///
  /// Example:
  /// ```dart
  /// final rustJson = calibData.toRustJson();
  /// final jsonString = jsonEncode(rustJson);
  /// await audioService.loadCalibrationState(jsonString);
  /// ```
  Map<String, dynamic> toRustJson() {
    final state = CalibrationState(
      level: level,
      tKickCentroid: thresholds['t_kick_centroid'] ?? 1500.0,
      tKickZcr: thresholds['t_kick_zcr'] ?? 0.1,
      tSnareCentroid: thresholds['t_snare_centroid'] ?? 4000.0,
      tHihatZcr: thresholds['t_hihat_zcr'] ?? 0.3,
      isCalibrated: false, // Default is false when loading manually
    );

    return state.toJson();
  }
}

/// Exception thrown by storage service operations.
///
/// Used to wrap underlying storage errors (SharedPreferences failures,
/// JSON serialization errors, etc.) with clear context.
class StorageException implements Exception {
  final String message;
  final Object? cause;

  StorageException(this.message, [this.cause]);

  @override
  String toString() =>
      'StorageException: $message${cause != null ? ' (cause: $cause)' : ''}';
}
