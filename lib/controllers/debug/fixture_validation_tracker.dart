import '../../bridge/api.dart/testing/fixture_manifest.dart';
import '../../models/classification_result.dart';

class FixtureValidationTracker {
  final Map<String, int> counts = <String, int>{};
  int? _firstTimestamp;
  int? _lastTimestamp;

  void record(ClassificationResult result) {
    final label = _canonicalLabel(result.sound);
    counts[label] = (counts[label] ?? 0) + 1;
    _firstTimestamp ??= result.timestampMs;
    _lastTimestamp = result.timestampMs;
  }

  List<FixtureAnomalySnapshot> evaluate(FixtureManifestEntry fixture) {
    final anomalies = <FixtureAnomalySnapshot>[];
    final tolerance = fixture.tolerances.bpmDeviationPct.max;
    final expectedMin = fixture.bpm.min.toDouble();
    final expectedMax = fixture.bpm.max.toDouble();
    final paddedMin = (expectedMin - expectedMin * tolerance / 100).clamp(
      0,
      double.infinity,
    );
    final paddedMax = expectedMax + expectedMax * tolerance / 100;
    final observed = observedBpm;

    if (observed == null || observed < paddedMin || observed > paddedMax) {
      anomalies.add(FixtureAnomalySnapshot.bpm(observed, paddedMin, paddedMax));
    }

    final dropTolerance = fixture.tolerances.classificationDropPct.max;
    fixture.expectedCounts.forEach((label, expected) {
      if (expected == 0) return;
      final normalized = _normalizeLabel(label);
      final observedCount = counts[normalized] ?? 0;
      if (observedCount < expected) {
        final dropPct = ((expected - observedCount) / expected) * 100;
        if (dropPct > dropTolerance) {
          anomalies.add(
            FixtureAnomalySnapshot.classification(
              normalized,
              expected,
              observedCount,
              dropPct,
            ),
          );
        }
      }
    });

    if (totalEvents == 0) {
      anomalies.add(FixtureAnomalySnapshot.insufficient());
    }

    return anomalies;
  }

  Map<String, dynamic> toStatsJson() {
    return {
      'observed_bpm': observedBpm,
      'total_events': totalEvents,
      'duration_ms': durationMs,
      'counts': counts,
    };
  }

  int get totalEvents => counts.values.fold(0, (sum, value) => sum + value);

  int? get durationMs {
    final first = _firstTimestamp;
    final last = _lastTimestamp;
    if (first == null || last == null || last <= first) {
      return null;
    }
    return last - first;
  }

  double? get observedBpm {
    final duration = durationMs;
    final total = totalEvents;
    if (duration == null || total <= 1) {
      return null;
    }
    final avgInterval = duration / (total - 1);
    if (avgInterval <= 0) {
      return null;
    }
    return 60000 / avgInterval;
  }
}

class FixtureAnomalySnapshot {
  FixtureAnomalySnapshot({
    required this.kind,
    required this.message,
    this.label,
    this.expectedMinBpm,
    this.expectedMaxBpm,
    this.observedBpm,
    this.expectedCount,
    this.observedCount,
    this.dropPct,
  });

  final String kind;
  final String message;
  final String? label;
  final double? expectedMinBpm;
  final double? expectedMaxBpm;
  final double? observedBpm;
  final int? expectedCount;
  final int? observedCount;
  final double? dropPct;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'message': message,
    'label': label,
    'expected_min_bpm': expectedMinBpm,
    'expected_max_bpm': expectedMaxBpm,
    'observed_bpm': observedBpm,
    'expected_count': expectedCount,
    'observed_count': observedCount,
    'drop_pct': dropPct,
  };

  static FixtureAnomalySnapshot bpm(double? observed, double min, double max) {
    final text = observed == null
        ? 'Unable to compute BPM for fixture session'
        : 'Observed BPM ${observed.toStringAsFixed(1)} outside range ${min.toStringAsFixed(1)}-${max.toStringAsFixed(1)}';
    return FixtureAnomalySnapshot(
      kind: 'bpm_out_of_range',
      message: text,
      expectedMinBpm: min,
      expectedMaxBpm: max,
      observedBpm: observed,
    );
  }

  static FixtureAnomalySnapshot classification(
    String label,
    int expected,
    int observed,
    double dropPct,
  ) {
    return FixtureAnomalySnapshot(
      kind: 'classification_drop',
      message:
          'Observed $observed $label events (expected $expected, drop ${dropPct.toStringAsFixed(1)}%)',
      label: label,
      expectedCount: expected,
      observedCount: observed,
      dropPct: dropPct,
    );
  }

  static FixtureAnomalySnapshot insufficient() {
    return FixtureAnomalySnapshot(
      kind: 'insufficient_observations',
      message: 'Fixture session did not produce enough events to analyze',
    );
  }
}

String _canonicalLabel(BeatboxHit hit) {
  switch (hit) {
    case BeatboxHit.kick:
      return 'kick';
    case BeatboxHit.snare:
    case BeatboxHit.kSnare:
      return 'snare';
    case BeatboxHit.hiHat:
    case BeatboxHit.closedHiHat:
    case BeatboxHit.openHiHat:
      return 'hihat';
    default:
      return 'unknown';
  }
}

String _normalizeLabel(String label) {
  final collapsed = label.trim().toLowerCase().replaceAll(
    RegExp(r'[\s-]'),
    '_',
  );
  if (collapsed.startsWith('hi')) {
    return 'hihat';
  }
  if (collapsed.contains('snare')) {
    return 'snare';
  }
  if (collapsed.contains('kick')) {
    return 'kick';
  }
  return collapsed;
}
