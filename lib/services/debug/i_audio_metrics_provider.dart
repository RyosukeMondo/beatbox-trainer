import 'i_debug_service.dart';

/// Audio metrics provider interface (ISP).
///
/// This interface follows the Interface Segregation Principle by providing
/// only audio metrics streaming capability. Components that need only metrics
/// can depend on this interface instead of the full IDebugService.
///
/// The metrics stream provides real-time DSP metrics from the audio engine:
/// - RMS amplitude level (0.0 to 1.0)
/// - Spectral centroid in Hz (weighted mean frequency)
/// - Spectral flux (measure of spectral change over time)
/// - Frame numbers and timestamps
///
/// Example:
/// ```dart
/// final metricsProvider = getIt<IAudioMetricsProvider>();
/// final stream = metricsProvider.getAudioMetricsStream();
/// await for (final metrics in stream) {
///   print('RMS: ${metrics.rms}, Centroid: ${metrics.spectralCentroid} Hz');
/// }
/// ```
abstract class IAudioMetricsProvider {
  /// Get stream of real-time audio metrics.
  ///
  /// Returns a stream that yields AudioMetrics containing DSP metrics
  /// from the audio processing pipeline. Useful for debug visualization
  /// and understanding audio engine behavior.
  ///
  /// Metrics include:
  /// - RMS amplitude level (0.0 to 1.0)
  /// - Spectral centroid in Hz
  /// - Spectral flux (spectral change over time)
  /// - Frame numbers and timestamps
  ///
  /// Returns:
  /// - `Stream<AudioMetrics>` that yields metrics while audio engine is running
  ///
  /// Example:
  /// ```dart
  /// final stream = metricsProvider.getAudioMetricsStream();
  /// await for (final metrics in stream) {
  ///   print('RMS: ${metrics.rms}, Centroid: ${metrics.spectralCentroid} Hz');
  /// }
  /// ```
  Stream<AudioMetrics> getAudioMetricsStream();
}
