import 'dart:io';

import 'playbook_models.dart';

class PlaybookRunResult {
  PlaybookRunResult({
    required this.scenarioId,
    required this.scenarioSummary,
    required this.scenarioDir,
    required this.succeeded,
    required this.dryRun,
    required this.steps,
    required this.artifacts,
  });

  final String scenarioId;
  final String scenarioSummary;
  final String scenarioDir;
  final bool succeeded;
  final bool dryRun;
  final List<StepRunSummary> steps;
  final List<ResolvedArtifact> artifacts;
}

class StepRunSummary {
  StepRunSummary({
    required this.id,
    required this.succeeded,
    required this.attempts,
    required this.logPath,
    required this.elapsed,
    required this.message,
  });

  final String id;
  final bool succeeded;
  final int attempts;
  final String logPath;
  final Duration elapsed;
  final String message;
}

class ResolvedArtifact {
  ResolvedArtifact({
    required this.definition,
    required this.path,
    required this.scope,
  });

  final ArtifactDefinition definition;
  final String path;
  final String scope;
}

void renderRunSummary(PlaybookRunResult result) {
  final statusColor = result.succeeded ? ansiGreen : ansiRed;
  stdout.writeln('');
  stdout.writeln(
      '$statusColor${result.succeeded ? 'PASS' : 'FAIL'}$ansiReset '
      '${result.scenarioId} — ${result.scenarioSummary}');
  stdout.writeln('Logs: ${result.scenarioDir}');
  for (final step in result.steps) {
    final icon = step.succeeded ? '✔' : '✖';
    final color = step.succeeded ? ansiGreen : ansiRed;
    stdout.writeln(
        '  $color$icon$ansiReset ${step.id} '
        '(attempts=${step.attempts}, log=${step.logPath}) '
        '${step.message}');
  }
  if (result.artifacts.isNotEmpty) {
    stdout.writeln('Artifacts:');
    for (final artifact in result.artifacts) {
      final tag = artifact.definition.required ? 'required' : 'optional';
      stdout.writeln('  • [${artifact.scope}] ${artifact.definition.name}: '
          '${artifact.path} ($tag)');
    }
  }
  if (result.dryRun) {
    stdout.writeln('${ansiYellow}Dry run — no commands were executed$ansiReset');
  }
}

const ansiReset = '\x1B[0m';
const ansiGreen = '\x1B[32m';
const ansiRed = '\x1B[31m';
const ansiYellow = '\x1B[33m';
const ansiBlue = '\x1B[34m';
