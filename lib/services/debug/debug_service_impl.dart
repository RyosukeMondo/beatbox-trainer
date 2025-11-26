import 'dart:async';
import '../../bridge/api.dart/api/streams.dart' as ffi;
import '../../bridge/api.dart/api/types.dart' as ffi_types;
import 'i_debug_service.dart';
import 'i_audio_metrics_provider.dart';
import 'i_onset_event_provider.dart';
import 'i_debug_capabilities.dart';

/// Implementation of debug service interfaces wrapping FFI debug streams.
///
/// This service provides access to real-time debug data from the Rust audio
/// engine by wrapping FFI stream methods. It converts between the generated
/// FFI types and the service layer types.
///
/// This implementation follows the Interface Segregation Principle by
/// implementing focused interfaces:
/// - [IAudioMetricsProvider]: Provides audio metrics streaming
/// - [IOnsetEventProvider]: Provides onset event streaming
///
/// The class also implements the legacy [IDebugService] interface for
/// backward compatibility during the migration period.
class DebugServiceImpl
    implements
        IDebugService,
        IAudioMetricsProvider,
        IOnsetEventProvider,
        DebugTelemetryAvailability {
  /// Stream controllers for debug data
  StreamController<AudioMetrics>? _metricsController;
  StreamController<OnsetEvent>? _onsetController;

  /// Subscriptions to FFI streams
  StreamSubscription<ffi_types.AudioMetrics>? _metricsSubscription;
  StreamSubscription<ffi_types.OnsetEvent>? _onsetSubscription;

  /// Whether real telemetry streams are available (FFI wired).
  @override
  final bool telemetryAvailable;

  DebugServiceImpl({this.telemetryAvailable = true});

  /// Initialize the debug service
  ///
  /// Sets up internal stream controllers and subscribes to FFI streams.
  /// Call this before using the service.
  Future<void> init() async {
    _metricsController = StreamController<AudioMetrics>.broadcast();
    _onsetController = StreamController<OnsetEvent>.broadcast();

    if (telemetryAvailable) {
      // Subscribe to FFI audio metrics stream
      _metricsSubscription = ffi.audioMetricsStream().listen(
        (ffiMetrics) {
          _metricsController?.add(_convertAudioMetrics(ffiMetrics));
        },
        onError: (Object error) {
          _metricsController?.addError(error);
        },
      );

      // Subscribe to FFI onset events stream
      _onsetSubscription = ffi.onsetEventsStream().listen(
        (ffiEvent) {
          _onsetController?.add(_convertOnsetEvent(ffiEvent));
        },
        onError: (Object error) {
          _onsetController?.addError(error);
        },
      );
    }
  }

  /// Convert FFI AudioMetrics to service AudioMetrics
  AudioMetrics _convertAudioMetrics(ffi_types.AudioMetrics ffi) {
    return AudioMetrics(
      rms: ffi.rms,
      spectralCentroid: ffi.spectralCentroid,
      spectralFlux: ffi.spectralFlux,
      frameNumber: ffi.frameNumber.toInt(),
      timestamp: ffi.timestamp.toInt(),
    );
  }

  /// Convert FFI OnsetEvent to service OnsetEvent
  OnsetEvent _convertOnsetEvent(ffi_types.OnsetEvent ffi) {
    return OnsetEvent(
      timestamp: ffi.timestamp.toInt(),
      energy: ffi.energy,
      centroid: ffi.centroid,
      zcr: ffi.zcr,
      flatness: ffi.flatness,
      rolloff: ffi.rolloff,
      decayTimeMs: ffi.decayTimeMs,
      classification: ffi.classification,
    );
  }

  /// Dispose of resources
  ///
  /// Cancels FFI stream subscriptions and closes stream controllers.
  void dispose() {
    _metricsSubscription?.cancel();
    _onsetSubscription?.cancel();
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

    return _onsetController!.stream;
  }
}
