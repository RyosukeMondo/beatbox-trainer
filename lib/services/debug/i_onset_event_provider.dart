import 'i_debug_service.dart';

/// Onset event provider interface (ISP).
///
/// This interface follows the Interface Segregation Principle by providing
/// only onset event streaming capability. Components that need only onset
/// events can depend on this interface instead of the full IDebugService.
///
/// The onset events stream provides real-time onset detection events:
/// - Timestamp in milliseconds since engine start
/// - Onset energy/strength (unnormalized)
/// - Spectral centroid in Hz
/// - Zero-crossing rate (0.0 to 1.0)
/// - Spectral flatness (0.0 to 1.0)
/// - Spectral rolloff in Hz
/// - Decay time in milliseconds
/// - Classification result (if available)
///
/// Example:
/// ```dart
/// final onsetProvider = getIt<IOnsetEventProvider>();
/// final stream = onsetProvider.getOnsetEventsStream();
/// await for (final event in stream) {
///   print('Onset at ${event.timestamp}ms: ${event.classification?.sound}');
/// }
/// ```
abstract class IOnsetEventProvider {
  /// Get stream of onset events with classification details.
  ///
  /// Returns a stream that yields OnsetEvent whenever an onset (percussive
  /// transient) is detected. Each event includes extracted features and
  /// classification result.
  ///
  /// Useful for:
  /// - Understanding onset detection behavior
  /// - Debugging classification issues
  /// - Visualizing feature extraction in real-time
  ///
  /// Returns:
  /// - `Stream<OnsetEvent>` that yields onset events while audio engine is running
  ///
  /// Example:
  /// ```dart
  /// final stream = onsetProvider.getOnsetEventsStream();
  /// await for (final event in stream) {
  ///   print('Onset at ${event.timestamp}ms: ${event.classification?.sound}');
  /// }
  /// ```
  Stream<OnsetEvent> getOnsetEventsStream();
}
