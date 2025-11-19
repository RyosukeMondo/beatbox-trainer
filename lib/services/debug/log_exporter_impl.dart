import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';

import 'i_log_exporter.dart';

/// Default implementation that writes Debug Lab evidence bundles to disk.
class LogExporterImpl implements ILogExporter {
  LogExporterImpl({
    Directory? exportRoot,
    HttpClient? httpClient,
    DateTime Function()? clock,
  }) : _exportRoot = exportRoot ?? Directory('logs/smoke/export'),
       _httpClient = httpClient ?? HttpClient(),
       _clock = clock ?? DateTime.now;

  final Directory _exportRoot;
  final HttpClient _httpClient;
  final DateTime Function() _clock;

  @override
  Future<LogExportResult> exportLogs(LogExportRequest request) async {
    final now = _clock();
    if (!await _exportRoot.exists()) {
      await _exportRoot.create(recursive: true);
    }

    final baseName = 'debug_lab_${_formatTimestamp(now)}';
    final requestMap = request.toMap();
    final sanitizedReferences = _sanitizeReferences(
      request.cliReferences,
      request.metricsToken,
    );
    final metricsSnapshot = await _captureMetricsSnapshot(
      endpoint: request.metricsEndpoint,
      token: request.metricsToken,
    );

    final payload = _LogExportPayload(
      baseName: baseName,
      exportDir: _exportRoot.path,
      manifest: {
        'exported_at': now.toIso8601String(),
        'fixture_id': request.fixtureId,
        'fixture_log_path': request.fixtureLogPath,
        'log_entry_count': request.logEntries.length,
        'audio_metrics_samples': request.audioMetrics.length,
        'onset_event_samples': request.onsetEvents.length,
        'param_patch_events': request.paramPatches.length,
        'metrics_endpoint': request.metricsEndpoint?.toString(),
        'metrics_snapshot_collected': metricsSnapshot != null,
      },
      logsJson: jsonEncode(requestMap['logs']),
      audioMetricsJson: jsonEncode(requestMap['audioMetrics']),
      onsetEventsJson: jsonEncode(requestMap['onsetEvents']),
      paramPatchesJson: jsonEncode(requestMap['paramPatches']),
      metricsSnapshot: metricsSnapshot,
      cliReferences: sanitizedReferences,
    );

    final resultMap = await Isolate.run(() => _writeArchive(payload));
    return LogExportResult(
      zipPath: resultMap['zipPath']!,
      cliNotesPath: resultMap['cliNotesPath']!,
    );
  }

  Future<String?> _captureMetricsSnapshot({
    required Uri? endpoint,
    required String? token,
  }) async {
    if (endpoint == null) {
      return null;
    }
    try {
      final needsQueryToken =
          token != null &&
          token.isNotEmpty &&
          !endpoint.queryParameters.containsKey('token');
      final uri = needsQueryToken
          ? endpoint.replace(
              queryParameters: {...endpoint.queryParameters, 'token': token},
            )
          : endpoint;
      final request = await _httpClient.getUrl(uri);
      if (token != null && token.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $token');
        request.headers.set('X-Debug-Token', token);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return await response.transform(utf8.decoder).join();
      }
    } catch (_) {
      // Snapshot is best-effort to avoid blocking exports.
    }
    return null;
  }
}

Future<Map<String, String>> _writeArchive(_LogExportPayload payload) async {
  final archive = Archive();
  archive.addFile(_textFile('manifest.json', jsonEncode(payload.manifest)));

  archive.addFile(_textFile('logs/debug_lab_entries.json', payload.logsJson));
  archive.addFile(
    _textFile('streams/audio_metrics.json', payload.audioMetricsJson),
  );
  archive.addFile(
    _textFile('streams/onset_events.json', payload.onsetEventsJson),
  );
  archive.addFile(
    _textFile('commands/param_patches.json', payload.paramPatchesJson),
  );
  archive.addFile(
    _textFile(
      'commands/cli_reference.txt',
      _formatCliReference(payload.cliReferences),
    ),
  );
  final metricsSnapshot =
      payload.metricsSnapshot ??
      'Metrics snapshot unavailable (server offline or token rejected).';
  archive.addFile(_textFile('streams/metrics_snapshot.txt', metricsSnapshot));

  if (payload.fixtureLogPath != null) {
    final fixtureFile = File(payload.fixtureLogPath!);
    if (await fixtureFile.exists()) {
      final contents = await fixtureFile.readAsString();
      archive.addFile(_textFile('logs/anomalies.log', contents));
    } else {
      archive.addFile(
        _textFile(
          'logs/anomalies.log',
          'Fixture anomaly log not found at ${payload.fixtureLogPath}',
        ),
      );
    }
  }

  final encoder = ZipEncoder();
  final data = encoder.encode(archive)!;
  final zipPath = '${payload.exportDir}/${payload.baseName}.zip';
  final zipFile = File(zipPath);
  await zipFile.writeAsBytes(data, flush: true);

  final cliNotes = _buildCliNotes(zipPath, payload.cliReferences);
  final notesPath = '${payload.exportDir}/${payload.baseName}.txt';
  await File(notesPath).writeAsString(cliNotes, flush: true);

  return {'zipPath': zipPath, 'cliNotesPath': notesPath};
}

String _formatTimestamp(DateTime value) {
  final mm = value.month.toString().padLeft(2, '0');
  final dd = value.day.toString().padLeft(2, '0');
  final hh = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  final ss = value.second.toString().padLeft(2, '0');
  return '${value.year}$mm${dd}_$hh$min$ss';
}

List<String> _sanitizeReferences(List<String> refs, String? token) {
  if (token == null || token.isEmpty) {
    return List<String>.from(refs);
  }
  return refs
      .map((ref) => ref.replaceAll(token, '***'))
      .toList(growable: false);
}

ArchiveFile _textFile(String name, String contents) {
  final bytes = utf8.encode(contents);
  return ArchiveFile(name, bytes.length, bytes);
}

String _formatCliReference(List<String> references) {
  if (references.isEmpty) {
    return 'No CLI references recorded for this session.';
  }
  final buffer = StringBuffer('CLI references (tokens redacted)\n');
  for (final ref in references) {
    buffer.writeln('- $ref');
  }
  return buffer.toString();
}

String _buildCliNotes(String zipPath, List<String> references) {
  final buffer = StringBuffer()
    ..writeln('Debug Lab evidence export ready.')
    ..writeln('ZIP: $zipPath')
    ..writeln('');
  if (references.isNotEmpty) {
    buffer.writeln('CLI references (ready to paste into keynote decks):');
    for (final ref in references) {
      buffer.writeln('- $ref');
    }
  } else {
    buffer.writeln('No CLI references recorded during this session.');
  }
  buffer.writeln('');
  buffer.writeln('All commands redact secrets with ***.');
  return buffer.toString();
}

class _LogExportPayload {
  const _LogExportPayload({
    required this.baseName,
    required this.exportDir,
    required this.manifest,
    required this.logsJson,
    required this.audioMetricsJson,
    required this.onsetEventsJson,
    required this.paramPatchesJson,
    required this.metricsSnapshot,
    required this.cliReferences,
  });

  final String baseName;
  final String exportDir;
  final Map<String, dynamic> manifest;
  final String logsJson;
  final String audioMetricsJson;
  final String onsetEventsJson;
  final String paramPatchesJson;
  final String? metricsSnapshot;
  final List<String> cliReferences;

  String? get fixtureLogPath => manifest['fixture_log_path'] as String?;
}
