// ignore_for_file: avoid_relative_lib_imports

import 'dart:io';

import 'package:test/test.dart';

import '../lib/playbook_parser.dart';
import '../lib/runner_core.dart';

void main() {
  group('PlaybookRunner integration', () {
    test('executes trimmed CI scenario and writes logs', () async {
      final projectRoot = Directory.systemTemp.createTempSync(
        'playbook_ci_trimmed',
      );
      addTearDown(() {
        if (projectRoot.existsSync()) {
          projectRoot.deleteSync(recursive: true);
        }
      });

      final manifestPath =
          '${Directory.current.path}/tools/cli/diagnostics/test/fixtures/ci_smoke.yaml';
      final parser = DiagnosticsPlaybookParser(manifestPath: manifestPath);
      final playbook = parser.parse();

      final runner = PlaybookRunner(
        playbook: playbook,
        scenarioId: 'ci-trimmed',
        projectRoot: projectRoot.path,
        now: () => DateTime.utc(2025, 01, 01, 12),
      );

      final result = await runner.run();
      expect(result.succeeded, isTrue);
      expect(result.steps, hasLength(2));
      expect(result.steps.every((step) => step.succeeded), isTrue);

      final greetLog = File(result.steps.first.logPath);
      expect(greetLog.readAsStringSync(), contains('hello from ci-trimmed'));
      final summarizeLog = File(result.steps.last.logPath);
      expect(summarizeLog.readAsStringSync(), contains('runner ok'));

      final scenarioDir = Directory(result.scenarioDir);
      expect(scenarioDir.existsSync(), isTrue);
      expect(scenarioDir.path.startsWith(projectRoot.path), isTrue);
    });
  });
}
