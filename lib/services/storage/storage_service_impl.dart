import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'i_storage_service.dart';

/// Concrete implementation of [IStorageService] using SharedPreferences
///
/// This implementation persists calibration data to device storage using
/// SharedPreferences, allowing calibration state to survive app restarts.
///
/// All data is stored as JSON strings for human-readable persistence and
/// easy debugging. The service follows async initialization pattern -
/// [init] must be called before using any other methods.
///
/// Storage keys:
/// - 'calibration_data': JSON string of CalibrationData
/// - 'has_calibration': Boolean flag for quick existence check
class StorageServiceImpl implements IStorageService {
  /// SharedPreferences instance for persistent storage
  SharedPreferences? _prefs;

  /// Storage key for calibration data JSON
  static const String _keyCalibrationData = 'calibration_data';

  /// Storage key for calibration existence flag
  static const String _keyHasCalibration = 'has_calibration';

  @override
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      throw StorageException('Failed to initialize SharedPreferences', e);
    }
  }

  /// Ensure SharedPreferences is initialized before use
  ///
  /// Throws [StorageException] if [init] has not been called.
  void _ensureInitialized() {
    if (_prefs == null) {
      throw StorageException(
        'StorageService not initialized. Call init() before using.',
      );
    }
  }

  @override
  Future<bool> hasCalibration() async {
    _ensureInitialized();

    try {
      // Check the boolean flag first for quick check
      final hasFlag = _prefs!.getBool(_keyHasCalibration) ?? false;
      if (!hasFlag) {
        return false;
      }

      // Verify data actually exists and is valid
      final jsonString = _prefs!.getString(_keyCalibrationData);
      if (jsonString == null || jsonString.isEmpty) {
        // Flag is set but data is missing - clear flag
        await _prefs!.setBool(_keyHasCalibration, false);
        return false;
      }

      // Try parsing to ensure data is valid
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        CalibrationData.fromJson(json);
        return true;
      } catch (parseError) {
        // Data is corrupted - clear it
        await clearCalibration();
        return false;
      }
    } catch (e) {
      throw StorageException('Failed to check calibration existence', e);
    }
  }

  @override
  Future<void> saveCalibration(CalibrationData data) async {
    _ensureInitialized();

    try {
      // Serialize CalibrationData to JSON
      final json = data.toJson();
      final jsonString = jsonEncode(json);

      // Store JSON string and set flag
      await _prefs!.setString(_keyCalibrationData, jsonString);
      await _prefs!.setBool(_keyHasCalibration, true);
    } on FormatException catch (e) {
      throw StorageException('Failed to serialize calibration data to JSON', e);
    } catch (e) {
      throw StorageException('Failed to save calibration data', e);
    }
  }

  @override
  Future<CalibrationData?> loadCalibration() async {
    _ensureInitialized();

    try {
      final jsonString = _prefs!.getString(_keyCalibrationData);

      // Return null if no data exists
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }

      // Deserialize JSON to CalibrationData
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return CalibrationData.fromJson(json);
      } on FormatException catch (e) {
        // JSON parsing failed - data is corrupted
        throw StorageException(
          'Failed to parse stored calibration data. Data may be corrupted.',
          e,
        );
      }
    } catch (e) {
      if (e is StorageException) {
        rethrow;
      }
      throw StorageException('Failed to load calibration data', e);
    }
  }

  @override
  Future<void> clearCalibration() async {
    _ensureInitialized();

    try {
      await _prefs!.remove(_keyCalibrationData);
      await _prefs!.setBool(_keyHasCalibration, false);
    } catch (e) {
      throw StorageException('Failed to clear calibration data', e);
    }
  }
}
