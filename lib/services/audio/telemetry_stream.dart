import '../../bridge/api.dart/telemetry/events.dart' as ffi;

/// Types of diagnostic metrics exposed to the Flutter layer.
enum DiagnosticMetricType {
  latency,
  bufferOccupancy,
  classification,
  jniLifecycle,
  error,
}

/// Domain model representing telemetry collector output.
class DiagnosticMetric {
  const DiagnosticMetric({
    required this.type,
    required this.payload,
    required this.timestamp,
  });

  final DiagnosticMetricType type;
  final Map<String, Object?> payload;
  final DateTime timestamp;

  factory DiagnosticMetric.fromFfi(ffi.MetricEvent event) {
    return event.map(
      latency: (value) {
        return DiagnosticMetric(
          type: DiagnosticMetricType.latency,
          payload: {
            'avgMs': value.avgMs,
            'maxMs': value.maxMs,
            'samples': value.sampleCount.toInt(),
          },
          timestamp: DateTime.now(),
        );
      },
      bufferOccupancy: (value) {
        return DiagnosticMetric(
          type: DiagnosticMetricType.bufferOccupancy,
          payload: {'channel': value.channel, 'percent': value.percent},
          timestamp: DateTime.now(),
        );
      },
      classification: (value) {
        return DiagnosticMetric(
          type: DiagnosticMetricType.classification,
          payload: {
            'sound': value.sound.name,
            'confidence': value.confidence,
            'timingErrorMs': value.timingErrorMs,
          },
          timestamp: DateTime.now(),
        );
      },
      jniLifecycle: (value) {
        return DiagnosticMetric(
          type: DiagnosticMetricType.jniLifecycle,
          payload: {'phase': value.phase.name},
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            value.timestampMs.toInt(),
            isUtc: true,
          ),
        );
      },
      error: (value) {
        return DiagnosticMetric(
          type: DiagnosticMetricType.error,
          payload: {'code': value.code.name, 'context': value.context},
          timestamp: DateTime.now(),
        );
      },
    );
  }
}

/// Helper that maps FFI streams to strongly typed diagnostic metrics.
Stream<DiagnosticMetric> mapDiagnosticMetrics(Stream<ffi.MetricEvent> source) {
  return source.map(DiagnosticMetric.fromFfi);
}
