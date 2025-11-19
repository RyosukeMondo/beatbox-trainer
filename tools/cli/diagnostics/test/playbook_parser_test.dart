// ignore_for_file: avoid_relative_lib_imports

import 'dart:io';

import 'package:test/test.dart';

import '../lib/playbook_parser.dart';

void main() {
  final harness = _ParserTestHarness();
  group('DiagnosticsPlaybookParser', () {
    setUp(harness.setUp);
    tearDown(harness.tearDown);
    test('parses manifest into strongly typed models', harness.parsesManifest);
    test(
      'throws FormatException for duplicate step ids',
      harness.rejectsDuplicateSteps,
    );
  });
}

class _ParserTestHarness {
  late Directory tempDir;

  void setUp() {
    tempDir = Directory.systemTemp.createTempSync('playbook_parser_test');
  }

  void tearDown() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }

  void parsesManifest() {
    final parser = _parserFor(_validManifest());
    final playbook = parser.parse();

    expect(playbook.schemaVersion, equals(1));
    expect(playbook.metadata.name, equals('smoke'));
    expect(playbook.defaults.retries.maxAttempts, equals(2));
    final scenario = playbook.scenarioById('smoke');
    expect(scenario.summary, equals('quick run'));
    expect(scenario.tags, contains('smoke'));
    expect(scenario.artifacts.single.path, contains('{{scenarioDir}}'));
    expect(scenario.steps, hasLength(2));
    final warmup = scenario.steps.first;
    expect(warmup.id, equals('warmup'));
    expect(warmup.retries!.maxAttempts, equals(3));
    expect(warmup.artifacts.single.name, equals('warmup-log'));
    expect(warmup.produces, contains('telemetry'));
    expect(scenario.steps.last.continueOnFailure, isTrue);
  }

  void rejectsDuplicateSteps() {
    final parser = _parserFor(_duplicateStepsManifest());
    expect(
      parser.parse,
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('duplicate'),
        ),
      ),
    );
  }

  DiagnosticsPlaybookParser _parserFor(String manifest) {
    final path = _writeManifest(manifest);
    return DiagnosticsPlaybookParser(manifestPath: path);
  }

  String _writeManifest(String contents) {
    final file = File('${tempDir.path}/manifest.yaml');
    file.writeAsStringSync(contents);
    return file.path;
  }

  String _validManifest() => '''
schemaVersion: 1
metadata:
  name: smoke
  description: Parser coverage
  owner: qa@example.com
  generated: 2025-11-19
defaults:
  logRoot: logs/diagnostics
  scenarioEnv:
    RUST_LOG: warn
  retries:
    maxAttempts: 2
    initialBackoffSeconds: 5
    backoffMultiplier: 2
  stepTimeoutSeconds: 30
  artifactTemplates:
    scenarioDir: "{{logRoot}}/{{scenario}}/{{timestamp}}"
    stepLog: "{{scenarioDir}}/{{stepId}}.log"
    attachmentsDir: "{{scenarioDir}}/artifacts"
scenarios:
  smoke:
    summary: quick run
    tags: [smoke]
    env:
      BBT_DIAG_PROFILE: debug
    artifacts:
      - name: aggregate
        path: "{{scenarioDir}}/aggregates.json"
        type: json
    steps:
      - id: warmup
        run: echo
        args: ["warmup"]
        artifacts:
          - name: warmup-log
            path: "{{stepLog}}"
            required: true
        retries:
          maxAttempts: 3
          initialBackoffSeconds: 1
          backoffMultiplier: 1.5
        produces: ["telemetry"]
      - id: capture
        run: echo
        args: ["capture"]
        continueOnFailure: true
''';

  String _duplicateStepsManifest() => '''
schemaVersion: 1
metadata:
  name: smoke
  description: invalid scenario
  owner: qa@example.com
  generated: 2025-11-19
defaults:
  logRoot: logs/diagnostics
  scenarioEnv: {}
  retries:
    maxAttempts: 1
    initialBackoffSeconds: 1
    backoffMultiplier: 2
  stepTimeoutSeconds: 10
  artifactTemplates:
    scenarioDir: logs
    stepLog: logs/{{stepId}}.log
    attachmentsDir: logs/artifacts
scenarios:
  duplicate:
    summary: invalid steps
    steps:
      - id: only-step
        run: echo
      - id: only-step
        run: echo again
''';
}
