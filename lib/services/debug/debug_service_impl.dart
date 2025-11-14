import 'dart:async';
import 'dart:convert';
import 'i_debug_service.dart';
import 'i_audio_metrics_provider.dart';
import 'i_onset_event_provider.dart';
import 'i_log_exporter.dart';

/// Implementation of debug service interfaces wrapping FFI debug streams.
///
/// This service provides access to real-time debug data from the Rust audio
/// engine by wrapping FFI stream methods. It also maintains a circular buffer
/// of recent events for log export functionality.
///
/// **Note**: FFI stream methods (`audio_metrics_stream`, `onset_events_stream`)
/// currently have generation errors in flutter_rust_bridge due to `impl Stream`
/// return types. This implementation provides placeholder streams that will work
/// once the FFI bridge is properly configured or when stream methods are fixed.
///
/// This implementation follows the Interface Segregation Principle by
/// implementing three focused interfaces:
/// - [IAudioMetricsProvider]: Provides audio metrics streaming
/// - [IOnsetEventProvider]: Provides onset event streaming
/// - [ILogExporter]: Provides log export functionality
///
/// The class also implements the legacy [IDebugService] interface for
/// backward compatibility during the migration period.
///
/// Temporary workaround: Empty streams until FFI generation is resolved.
/// See: lib/bridge/api.dart/api.dart line 12 for generation errors.
class DebugServiceImpl
    implements
        IDebugService,
        IAudioMetricsProvider,
        IOnsetEventProvider,
        ILogExporter {
  /// Maximum number of events to keep in log buffer
  static const int _maxLogBufferSize = 1000;

  /// Circular buffer for onset events (for log export)
  final List<OnsetEvent> _onsetEventBuffer = [];

  /// Circular buffer for audio metrics (for log export)
  final List<AudioMetrics> _audioMetricsBuffer = [];

  /// Stream controllers for debug data
  StreamController<AudioMetrics>? _metricsController;
  StreamController<OnsetEvent>? _onsetController;

  /// Initialize the debug service
  ///
  /// Sets up internal stream controllers and prepares for FFI stream forwarding.
  /// Call this before using the service.
  Future<void> init() async {
    _metricsController = StreamController<AudioMetrics>.broadcast();
    _onsetController = StreamController<OnsetEvent>.broadcast();

    // TODO(FFI): Once flutter_rust_bridge generates stream methods properly,
    // forward FFI streams to controllers here:
    //
    // final ffiMetricsStream = await api.audioMetricsStream();
    // ffiMetricsStream.listen((metrics) {
    //   _addToBuffer(_audioMetricsBuffer, metrics);
    //   _metricsController?.add(metrics);
    // });
    //
    // final ffiOnsetStream = await api.onsetEventsStream();
    // ffiOnsetStream.listen((event) {
    //   _addToBuffer(_onsetEventBuffer, event);
    //   _onsetController?.add(event);
    // });
  }

  /// Dispose of resources
  ///
  /// Closes stream controllers and clears buffers.
  void dispose() {
    _metricsController?.close();
    _onsetController?.close();
    _audioMetricsBuffer.clear();
    _onsetEventBuffer.clear();
  }

  @override
  Stream<AudioMetrics> getAudioMetricsStream() {
    if (_metricsController == null) {
      throw DebugException('DebugService not initialized. Call init() first.');
    }

    // Return the broadcast stream
    // Once FFI streams are available, this will forward real-time data
    return _metricsController!.stream;
  }

  @override
  Stream<OnsetEvent> getOnsetEventsStream() {
    if (_onsetController == null) {
      throw DebugException('DebugService not initialized. Call init() first.');
    }

    // Return the broadcast stream
    // Once FFI streams are available, this will forward real-time data
    return _onsetController!.stream;
  }

  @override
  Future<String> exportLogs() async {
    try {
      // Create log export data structure
      final logData = {
        'exported_at': DateTime.now().toIso8601String(),
        'audio_metrics': _audioMetricsBuffer.map((m) => m.toJson()).toList(),
        'onset_events': _onsetEventBuffer.map((e) => e.toJson()).toList(),
        'metrics_count': _audioMetricsBuffer.length,
        'events_count': _onsetEventBuffer.length,
      };

      // Serialize to JSON and return as string
      // Caller can save this to a file or share it as needed
      final jsonString = const JsonEncoder.withIndent('  ').convert(logData);

      return jsonString;
    } catch (e) {
      throw DebugException('Failed to export logs', e);
    }
  }

  /// Add item to circular buffer, removing oldest if at capacity
  ///
  /// Maintains a fixed-size buffer by removing the oldest item when the
  /// buffer reaches [_maxLogBufferSize].
  ///
  /// Parameters:
  /// - [buffer]: The buffer to add to
  /// - [item]: The item to add
  ///
  /// Note: Currently unused until FFI streams are properly generated.
  /// Will be used in init() once flutter_rust_bridge supports the stream methods.
  // ignore: unused_element
  void _addToBuffer<T>(List<T> buffer, T item) {
    if (buffer.length >= _maxLogBufferSize) {
      buffer.removeAt(0); // Remove oldest
    }
    buffer.add(item);
  }
}
