/// Log export interface (ISP).
///
/// This interface follows the Interface Segregation Principle by providing
/// only log export capability. Components that need only log export
/// functionality can depend on this interface instead of the full IDebugService.
///
/// The log exporter serializes recent debug events (last 1000 events) to a
/// JSON file for offline analysis. Useful for sharing debug data with
/// developers or analyzing patterns over time.
///
/// Example:
/// ```dart
/// final logExporter = getIt<ILogExporter>();
/// final logPath = await logExporter.exportLogs();
/// print('Logs exported to: $logPath');
/// ```
abstract class ILogExporter {
  /// Export recent logs to JSON file.
  ///
  /// Serializes recent debug events (last 1000 events) to a JSON file
  /// for offline analysis. Useful for sharing debug data with developers
  /// or analyzing patterns over time.
  ///
  /// Returns:
  /// - String path to the exported JSON file
  ///
  /// Throws:
  /// - DebugException if export fails (e.g., file I/O error)
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final logPath = await logExporter.exportLogs();
  ///   print('Logs exported to: $logPath');
  /// } catch (e) {
  ///   print('Failed to export logs: $e');
  /// }
  /// ```
  Future<String> exportLogs();
}
