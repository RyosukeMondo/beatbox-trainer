import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beatbox_trainer/models/debug_log_entry.dart';
import 'package:beatbox_trainer/services/debug/i_debug_service.dart';
import 'package:beatbox_trainer/services/debug/i_log_exporter.dart';
import 'package:beatbox_trainer/services/debug/log_exporter_impl.dart';

void main() {
  test(
    'LogExporterImpl creates ZIP bundles with sanitized CLI references',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('log_exporter');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final exporter = LogExporterImpl(
        exportRoot: tempDir,
        clock: () => DateTime.utc(2024, 1, 1, 12, 0, 0),
      );

      final anomalyLog = File('${tempDir.path}/debug_lab_anomalies.log')
        ..writeAsStringSync('{"fixture_id":"basic_hits"}\n');

      final request = LogExportRequest(
        logEntries: [
          DebugLogEntry(
            timestamp: DateTime.utc(2024, 1, 1, 12),
            source: DebugLogSource.system,
            severity: DebugLogSeverity.info,
            title: 'Fixture armed',
            detail: 'basic_hits',
          ),
        ],
        audioMetrics: [
          AudioMetrics(
            rms: 0.5,
            spectralCentroid: 2200,
            spectralFlux: 0.1,
            frameNumber: 1,
            timestamp: 50,
          ),
        ],
        onsetEvents: const [],
        paramPatches: [
          ParamPatchEvent(
            timestamp: DateTime.utc(2024, 1, 1, 12, 0, 5),
            status: ParamPatchStatus.success,
            bpm: 120,
          ),
        ],
        cliReferences: [
          'curl -H "Authorization: Bearer secret-token" '
              'http://127.0.0.1:8787/metrics?token=secret-token',
        ],
        fixtureId: 'basic_hits',
        fixtureLogPath: anomalyLog.path,
        metricsEndpoint: null,
        metricsToken: 'secret-token',
      );

      final result = await exporter.exportLogs(request);

      final zipFile = File(result.zipPath);
      expect(zipFile.existsSync(), isTrue);
      expect(
        File(result.cliNotesPath).readAsStringSync(),
        contains('CLI references'),
      );

      final archive = ZipDecoder().decodeBytes(zipFile.readAsBytesSync());
      final manifest =
          archive.files
                  .firstWhere((file) => file.name == 'manifest.json')
                  .content
              as List<int>;
      expect(
        String.fromCharCodes(manifest),
        contains('"fixture_id":"basic_hits"'),
      );

      final cliFile =
          archive.files
                  .firstWhere(
                    (file) => file.name == 'commands/cli_reference.txt',
                  )
                  .content
              as List<int>;
      expect(String.fromCharCodes(cliFile), isNot(contains('secret-token')));
      expect(String.fromCharCodes(cliFile), contains('***'));
    },
  );
}
