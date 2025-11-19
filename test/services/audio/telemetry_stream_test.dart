import 'package:beatbox_trainer/bridge/api.dart/analysis/classifier.dart'
    as ffi_classifier;
import 'package:beatbox_trainer/bridge/api.dart/telemetry/events.dart' as ffi;
import 'package:beatbox_trainer/services/audio/telemetry_stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiagnosticMetric', () {
    test('converts latency events', () {
      final metric = DiagnosticMetric.fromFfi(
        ffi.MetricEvent.latency(
          avgMs: 12.5,
          maxMs: 18.0,
          sampleCount: BigInt.from(8),
        ),
      );

      expect(metric.type, DiagnosticMetricType.latency);
      expect(metric.payload['avgMs'], 12.5);
      expect(metric.payload['samples'], 8);
    });

    test('maps buffer occupancy stream', () async {
      final events = [
        ffi.MetricEvent.bufferOccupancy(
          channel: 'analysis_accumulator',
          percent: 72.0,
        ),
        ffi.MetricEvent.classification(
          sound: ffi_classifier.BeatboxHit.kick,
          confidence: 0.82,
          timingErrorMs: 4.0,
        ),
      ];

      final metrics = await mapDiagnosticMetrics(
        Stream.fromIterable(events),
      ).toList();

      expect(metrics, hasLength(2));
      expect(metrics.first.payload['channel'], 'analysis_accumulator');
      expect(metrics.last.type, DiagnosticMetricType.classification);
    });
  });
}
