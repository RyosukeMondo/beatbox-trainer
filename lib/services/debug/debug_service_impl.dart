import 'dart:async';
import 'i_debug_service.dart';
import 'i_audio_metrics_provider.dart';
import 'i_onset_event_provider.dart';
import 'i_debug_capabilities.dart';

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
/// implementing focused interfaces:
/// - [IAudioMetricsProvider]: Provides audio metrics streaming
/// - [IOnsetEventProvider]: Provides onset event streaming
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
        DebugTelemetryAvailability {
  /// Stream controllers for debug data
  StreamController<AudioMetrics>? _metricsController;
  StreamController<OnsetEvent>? _onsetController;

  /// Whether real telemetry streams are available (FFI wired).
  @override
  final bool telemetryAvailable;

  DebugServiceImpl({this.telemetryAvailable = false});

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
  /// Closes stream controllers.
  void dispose() {
    _metricsController?.close();
    _onsetController?.close();
  }

  @override
  Stream<AudioMetrics> getAudioMetricsStream() {
    if (!telemetryAvailable) {
      return Stream<AudioMetrics>.error(
        DebugException('Telemetry unavailable (FFI stream not wired)'),
      );
    }

    if (_metricsController == null) {
      throw DebugException('DebugService not initialized. Call init() first.');
    }

    // Return the broadcast stream
    // Once FFI streams are available, this will forward real-time data
    return _metricsController!.stream;
  }

  @override
  Stream<OnsetEvent> getOnsetEventsStream() {
    if (!telemetryAvailable) {
      return Stream<OnsetEvent>.error(
        DebugException('Telemetry unavailable (FFI stream not wired)'),
      );
    }

    if (_onsetController == null) {
      throw DebugException('DebugService not initialized. Call init() first.');
    }

    // Return the broadcast stream
    // Once FFI streams are available, this will forward real-time data
    return _onsetController!.stream;
  }
}
