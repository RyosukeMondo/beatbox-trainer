/// Domain model describing engine telemetry events surfaced via FRB streams.
enum TelemetryEventType { engineStarted, engineStopped, bpmChanged, warning }

class TelemetryEvent {
  final int timestampMs;
  final TelemetryEventType type;
  final int? bpm;
  final String? detail;

  const TelemetryEvent({
    required this.timestampMs,
    required this.type,
    this.bpm,
    this.detail,
  });

  factory TelemetryEvent.fromJson(Map<String, dynamic> json) {
    final type = _parseType(json['type'] as String? ?? 'warning');
    return TelemetryEvent(
      timestampMs: json['timestamp_ms'] as int? ?? 0,
      type: type,
      bpm: json['bpm'] as int?,
      detail: json['detail'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp_ms': timestampMs,
      'type': type.name,
      if (bpm != null) 'bpm': bpm,
      if (detail != null) 'detail': detail,
    };
  }

  static TelemetryEventType _parseType(String raw) {
    switch (raw) {
      case 'engineStarted':
        return TelemetryEventType.engineStarted;
      case 'engineStopped':
        return TelemetryEventType.engineStopped;
      case 'bpmChanged':
        return TelemetryEventType.bpmChanged;
      default:
        return TelemetryEventType.warning;
    }
  }
}
