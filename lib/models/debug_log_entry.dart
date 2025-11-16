import 'package:flutter/foundation.dart';
import 'classification_result.dart';
import 'telemetry_event.dart';

/// Source of a debug log entry, used for styling and filtering.
enum DebugLogSource { device, remote, synthetic, telemetry, system }

/// Severity level for debug events.
enum DebugLogSeverity { info, warning, error }

/// Represents an item rendered in the Debug Lab log view.
class DebugLogEntry {
  final DateTime timestamp;
  final DebugLogSource source;
  final DebugLogSeverity severity;
  final String title;
  final String? detail;
  final ClassificationResult? classification;
  final TelemetryEvent? telemetry;

  const DebugLogEntry({
    required this.timestamp,
    required this.source,
    required this.severity,
    required this.title,
    this.detail,
    this.classification,
    this.telemetry,
  });

  /// Factory for classification entries.
  factory DebugLogEntry.forClassification(
    ClassificationResult result, {
    required DebugLogSource source,
  }) {
    return DebugLogEntry(
      timestamp: DateTime.now(),
      source: source,
      severity: DebugLogSeverity.info,
      title: result.sound.displayName,
      detail:
          '${describeEnum(result.timing.classification)} • '
          '${result.timing.formattedError} • '
          '${(result.confidence * 100).toStringAsFixed(1)}%',
      classification: result,
    );
  }

  /// Factory for telemetry entries.
  factory DebugLogEntry.forTelemetry(
    TelemetryEvent event, {
    DebugLogSeverity? overrideSeverity,
  }) {
    final severity = overrideSeverity ??
        (event.type == TelemetryEventType.warning
            ? DebugLogSeverity.warning
            : DebugLogSeverity.info);
    return DebugLogEntry(
      timestamp: DateTime.now(),
      source: DebugLogSource.telemetry,
      severity: severity,
      title: describeEnum(event.type),
      detail: event.detail,
      telemetry: event,
    );
  }

  /// Factory for errors.
  factory DebugLogEntry.error(String title, String? detail) {
    return DebugLogEntry(
      timestamp: DateTime.now(),
      source: DebugLogSource.system,
      severity: DebugLogSeverity.error,
      title: title,
      detail: detail,
    );
  }
}
