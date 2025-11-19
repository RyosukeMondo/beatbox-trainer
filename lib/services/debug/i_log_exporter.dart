import '../../models/debug_log_entry.dart';
import '../../services/debug/i_debug_service.dart';

/// Interface for bundling Debug Lab evidence packages.
///
/// The exporter ingests stream samples captured by Debug Lab and produces a
/// timestamped ZIP under `logs/smoke/export/` that contains:
/// - FRB audio metric samples + onset events
/// - Captured Debug Lab log entries
/// - `/metrics` HTTP snapshot (when remote server available)
/// - Fixture context and ParamPatch command history
/// - CLI instructions with tokens redacted for sharing
abstract class ILogExporter {
  /// Bundles Debug Lab evidence into a single ZIP archive.
  ///
  /// [request] describes the collected evidence from Debug Lab.
  ///
  /// Returns a [LogExportResult] containing the ZIP path and a companion text
  /// file that mirrors the CLI references stored inside the archive.
  Future<LogExportResult> exportLogs(LogExportRequest request);
}

/// Request payload describing what should be included in an evidence bundle.
class LogExportRequest {
  const LogExportRequest({
    required this.logEntries,
    required this.audioMetrics,
    required this.onsetEvents,
    required this.paramPatches,
    required this.cliReferences,
    this.fixtureId,
    this.fixtureLogPath,
    this.metricsEndpoint,
    this.metricsToken,
  });

  final List<DebugLogEntry> logEntries;
  final List<AudioMetrics> audioMetrics;
  final List<OnsetEvent> onsetEvents;
  final List<ParamPatchEvent> paramPatches;
  final List<String> cliReferences;
  final String? fixtureId;
  final String? fixtureLogPath;
  final Uri? metricsEndpoint;
  final String? metricsToken;

  /// Converts request to a serializable map for isolate hand-off.
  Map<String, dynamic> toMap() {
    return {
      'logs': logEntries.map(_logEntryToJson).toList(),
      'audioMetrics': audioMetrics.map((m) => m.toJson()).toList(),
      'onsetEvents': onsetEvents.map((e) => e.toJson()).toList(),
      'paramPatches': paramPatches.map((p) => p.toJson()).toList(),
      'cliReferences': cliReferences,
      'fixtureId': fixtureId,
      'fixtureLogPath': fixtureLogPath,
      'metricsEndpoint': metricsEndpoint?.toString(),
      'metricsToken': metricsToken,
    };
  }
}

/// Result bundle paths returned by [ILogExporter].
class LogExportResult {
  const LogExportResult({required this.zipPath, required this.cliNotesPath});

  final String zipPath;
  final String cliNotesPath;
}

/// Metadata describing a ParamPatch invocation for evidence bundles.
class ParamPatchEvent {
  const ParamPatchEvent({
    required this.timestamp,
    required this.status,
    this.bpm,
    this.centroidThreshold,
    this.zcrThreshold,
    this.error,
  });

  final DateTime timestamp;
  final ParamPatchStatus status;
  final int? bpm;
  final double? centroidThreshold;
  final double? zcrThreshold;
  final String? error;

  ParamPatchEvent copyWith({
    DateTime? timestamp,
    ParamPatchStatus? status,
    int? bpm,
    double? centroidThreshold,
    double? zcrThreshold,
    String? error,
  }) {
    return ParamPatchEvent(
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      bpm: bpm ?? this.bpm,
      centroidThreshold: centroidThreshold ?? this.centroidThreshold,
      zcrThreshold: zcrThreshold ?? this.zcrThreshold,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'bpm': bpm,
      'centroid_threshold': centroidThreshold,
      'zcr_threshold': zcrThreshold,
      'error': error,
    };
  }
}

/// Outcome of a ParamPatch invocation.
enum ParamPatchStatus { success, failure }

Map<String, dynamic> _logEntryToJson(DebugLogEntry entry) {
  return {
    'timestamp': entry.timestamp.toIso8601String(),
    'source': entry.source.name,
    'severity': entry.severity.name,
    'title': entry.title,
    'detail': entry.detail,
    'classification': entry.classification?.toJson(),
    'telemetry': entry.telemetry?.toJson(),
  };
}
