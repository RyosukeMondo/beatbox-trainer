/// Debug service interface for audio metrics and onset event streams.
///
/// This interface provides access to real-time debug data from the Rust
/// audio engine, enabling debug visualizations and developer insights.
///
/// The service exposes two primary streams:
/// - Audio metrics: Real-time DSP metrics (RMS, spectral features)
/// - Onset events: Detected percussive transients with classification
abstract class IDebugService {
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
  /// final stream = debugService.getAudioMetricsStream();
  /// await for (final metrics in stream) {
  ///   print('RMS: ${metrics.rms}, Centroid: ${metrics.spectralCentroid} Hz');
  /// }
  /// ```
  Stream<AudioMetrics> getAudioMetricsStream();

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
  /// final stream = debugService.getOnsetEventsStream();
  /// await for (final event in stream) {
  ///   print('Onset at ${event.timestamp}ms: ${event.classification?.sound}');
  /// }
  /// ```
  Stream<OnsetEvent> getOnsetEventsStream();
}

/// Audio metrics from the DSP pipeline.
///
/// Contains real-time metrics computed during audio processing.
/// Matches the Rust AudioMetrics struct from api.rs.
class AudioMetrics {
  /// Root mean square (RMS) amplitude level (0.0 to 1.0)
  final double rms;

  /// Spectral centroid in Hz (weighted mean frequency)
  final double spectralCentroid;

  /// Spectral flux (measure of spectral change over time)
  final double spectralFlux;

  /// Frame number in audio stream
  final int frameNumber;

  /// Timestamp in milliseconds since engine start
  final int timestamp;

  AudioMetrics({
    required this.rms,
    required this.spectralCentroid,
    required this.spectralFlux,
    required this.frameNumber,
    required this.timestamp,
  });

  /// Create AudioMetrics from JSON map.
  ///
  /// Used when deserializing from FFI bridge or stored logs.
  ///
  /// Parameters:
  /// - [json]: Map containing metric fields
  ///
  /// Example:
  /// ```dart
  /// final metrics = AudioMetrics.fromJson({
  ///   'rms': 0.45,
  ///   'spectral_centroid': 2500.0,
  ///   'spectral_flux': 0.12,
  ///   'frame_number': 1024,
  ///   'timestamp': 5000,
  /// });
  /// ```
  factory AudioMetrics.fromJson(Map<String, dynamic> json) {
    return AudioMetrics(
      rms: (json['rms'] as num).toDouble(),
      spectralCentroid: (json['spectral_centroid'] as num).toDouble(),
      spectralFlux: (json['spectral_flux'] as num).toDouble(),
      frameNumber: json['frame_number'] as int,
      timestamp: json['timestamp'] as int,
    );
  }

  /// Convert AudioMetrics to JSON map.
  ///
  /// Used when serializing for log export.
  ///
  /// Returns:
  /// - Map with all metric fields
  ///
  /// Example:
  /// ```dart
  /// final json = metrics.toJson();
  /// final jsonString = jsonEncode(json);
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'rms': rms,
      'spectral_centroid': spectralCentroid,
      'spectral_flux': spectralFlux,
      'frame_number': frameNumber,
      'timestamp': timestamp,
    };
  }
}

/// Onset event with classification details.
///
/// Emitted whenever an onset (percussive transient) is detected.
/// Includes extracted features and classification result.
/// Matches the Rust OnsetEvent struct from api.rs.
class OnsetEvent {
  /// Timestamp in milliseconds since engine start
  final int timestamp;

  /// Onset energy/strength (unnormalized)
  final double energy;

  /// Spectral centroid in Hz
  final double centroid;

  /// Zero-crossing rate (0.0 to 1.0)
  final double zcr;

  /// Spectral flatness (0.0 to 1.0)
  final double flatness;

  /// Spectral rolloff in Hz
  final double rolloff;

  /// Decay time in milliseconds
  final double decayTimeMs;

  /// Classification result (if available)
  final dynamic classification;

  OnsetEvent({
    required this.timestamp,
    required this.energy,
    required this.centroid,
    required this.zcr,
    required this.flatness,
    required this.rolloff,
    required this.decayTimeMs,
    this.classification,
  });

  /// Create OnsetEvent from JSON map.
  ///
  /// Used when deserializing from FFI bridge or stored logs.
  ///
  /// Parameters:
  /// - [json]: Map containing event fields
  ///
  /// Example:
  /// ```dart
  /// final event = OnsetEvent.fromJson({
  ///   'timestamp': 5000,
  ///   'energy': 0.85,
  ///   'centroid': 2500.0,
  ///   'zcr': 0.3,
  ///   'flatness': 0.2,
  ///   'rolloff': 5000.0,
  ///   'decay_time_ms': 50.0,
  ///   'classification': {...},
  /// });
  /// ```
  factory OnsetEvent.fromJson(Map<String, dynamic> json) {
    return OnsetEvent(
      timestamp: json['timestamp'] as int,
      energy: (json['energy'] as num).toDouble(),
      centroid: (json['centroid'] as num).toDouble(),
      zcr: (json['zcr'] as num).toDouble(),
      flatness: (json['flatness'] as num).toDouble(),
      rolloff: (json['rolloff'] as num).toDouble(),
      decayTimeMs: (json['decay_time_ms'] as num).toDouble(),
      classification: json['classification'],
    );
  }

  /// Convert OnsetEvent to JSON map.
  ///
  /// Used when serializing for log export.
  ///
  /// Returns:
  /// - Map with all event fields
  ///
  /// Example:
  /// ```dart
  /// final json = event.toJson();
  /// final jsonString = jsonEncode(json);
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'energy': energy,
      'centroid': centroid,
      'zcr': zcr,
      'flatness': flatness,
      'rolloff': rolloff,
      'decay_time_ms': decayTimeMs,
      'classification': classification,
    };
  }
}

/// Exception thrown by debug service operations.
///
/// Used to wrap underlying errors (FFI failures, file I/O errors, etc.)
/// with clear context.
class DebugException implements Exception {
  final String message;
  final Object? cause;

  DebugException(this.message, [this.cause]);

  @override
  String toString() =>
      'DebugException: $message${cause != null ? ' (cause: $cause)' : ''}';
}
