import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'playbook_models.dart';
import 'runner_types.dart';

class PlaybookRunner {
  PlaybookRunner({
    required this.playbook,
    required this.scenarioId,
    required String projectRoot,
    this.dryRun = false,
    DateTime Function()? now,
  }) : projectRoot = Directory(projectRoot).absolute.path,
       _now = now ?? DateTime.now;

  final DiagnosticsPlaybook playbook;
  final String scenarioId;
  final String projectRoot;
  final bool dryRun;
  final DateTime Function() _now;

  Future<PlaybookRunResult> run() async {
    final scenario = playbook.scenarioById(scenarioId);
    final context = _ScenarioContext(
      defaults: playbook.defaults,
      scenario: scenario,
      projectRoot: projectRoot,
      timestamp: _formatTimestamp(_now()),
    );
    final scenarioArtifacts = _prepareScenarioArtifacts(context);
    final stepArtifacts = <ResolvedArtifact>[];
    final steps = dryRun
        ? _planDryRunSteps(context, stepArtifacts)
        : await _runScenarioSteps(context, stepArtifacts);
    final succeeded = dryRun || steps.every((result) => result.succeeded);
    return PlaybookRunResult(
      scenarioId: scenario.id,
      scenarioSummary: scenario.summary,
      scenarioDir: context.scenarioDir,
      succeeded: succeeded,
      dryRun: dryRun,
      steps: steps,
      artifacts: [...scenarioArtifacts, ...stepArtifacts],
    );
  }

  List<ResolvedArtifact> _prepareScenarioArtifacts(_ScenarioContext context) {
    final artifacts = _resolveArtifacts(
      context,
      context.scenario.artifacts,
      scope: 'scenario',
    );
    for (final artifact in artifacts) {
      _ensureParentDirectory(artifact.path);
    }
    return artifacts;
  }

  List<StepRunSummary> _planDryRunSteps(
    _ScenarioContext context,
    List<ResolvedArtifact> accumulator,
  ) {
    final summaries = <StepRunSummary>[];
    stdout.writeln(
      '[dry-run] Scenario ${context.scenario.id} -> '
      '${context.scenario.summary}',
    );
    for (final step in context.scenario.steps) {
      final plan = _buildStepPlan(context, step);
      accumulator.addAll(plan.artifacts);
      stdout.writeln('  • ${step.id}: ${step.run} ${step.args.join(' ')}');
      summaries.add(
        StepRunSummary(
          id: step.id,
          succeeded: true,
          attempts: 0,
          logPath: plan.logFile.path,
          elapsed: Duration.zero,
          message: 'dry-run',
        ),
      );
    }
    return summaries;
  }

  Future<List<StepRunSummary>> _runScenarioSteps(
    _ScenarioContext context,
    List<ResolvedArtifact> accumulator,
  ) async {
    final summaries = <StepRunSummary>[];
    for (final step in context.scenario.steps) {
      final plan = _buildStepPlan(context, step);
      accumulator.addAll(plan.artifacts);
      final summary = await _runStep(plan);
      summaries.add(summary);
      if (!summary.succeeded && !step.continueOnFailure) {
        break;
      }
    }
    return summaries;
  }

  _StepPlan _buildStepPlan(_ScenarioContext context, PlaybookStep step) {
    final values = context.valuesForStep(step.id);
    final logPath = _interpolate(
      context.defaults.artifactTemplates.stepLog,
      values,
    );
    final logFile = File(context.absolutePath(logPath));
    logFile.parent.createSync(recursive: true);
    final artifacts = _resolveArtifacts(
      context,
      step.artifacts,
      scope: 'step:${step.id}',
      values: values,
    );
    for (final artifact in artifacts) {
      _ensureParentDirectory(artifact.path);
    }
    final environment = <String, String>{}
      ..addAll(Platform.environment)
      ..addAll(context.defaults.scenarioEnv)
      ..addAll(context.scenario.env)
      ..addAll(step.env);
    final timeoutSeconds =
        step.timeoutSeconds ?? context.defaults.stepTimeoutSeconds;
    final retryPolicy = step.retries ?? context.defaults.retries;
    return _StepPlan(
      step: step,
      logFile: logFile,
      environment: environment,
      timeout: Duration(seconds: timeoutSeconds),
      retryPolicy: retryPolicy,
      artifacts: artifacts,
      workingDirectory: context.projectRoot,
    );
  }

  Future<StepRunSummary> _runStep(_StepPlan plan) async {
    var lastMessage = '';
    for (var attempt = 1; attempt <= plan.retryPolicy.maxAttempts; attempt++) {
      final outcome = await _runSingleAttempt(plan, attempt);
      if (outcome.exitCode == 0) {
        stdout.writeln(
          '$ansiGreen✔$ansiReset [${plan.step.id}] '
          'Completed in ${outcome.elapsed.inSeconds}s',
        );
        return StepRunSummary(
          id: plan.step.id,
          succeeded: true,
          attempts: attempt,
          logPath: plan.logFile.path,
          elapsed: outcome.elapsed,
          message: 'exitCode 0',
        );
      }
      lastMessage = outcome.message;
      if (attempt < plan.retryPolicy.maxAttempts) {
        final delaySeconds = _backoffDelaySeconds(plan.retryPolicy, attempt);
        stdout.writeln(
          '$ansiYellow!$ansiReset [${plan.step.id}] '
          'Retrying in ${delaySeconds}s ($lastMessage)',
        );
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
    stdout.writeln(
      '$ansiRed✖$ansiReset [${plan.step.id}] Failed '
      '($lastMessage)',
    );
    return StepRunSummary(
      id: plan.step.id,
      succeeded: false,
      attempts: plan.retryPolicy.maxAttempts,
      logPath: plan.logFile.path,
      elapsed: Duration.zero,
      message: lastMessage,
    );
  }

  Future<_AttemptOutcome> _runSingleAttempt(_StepPlan plan, int attempt) async {
    final sink = plan.logFile.openWrite(
      mode: attempt == 1 ? FileMode.writeOnly : FileMode.append,
    );
    final stopwatch = Stopwatch()..start();
    sink.writeln(
      '===== ${plan.step.id} attempt $attempt/'
      '${plan.retryPolicy.maxAttempts} '
      '(${DateTime.now().toIso8601String()}) =====',
    );
    stdout.writeln(
      '$ansiBlue⇒$ansiReset [${plan.step.id}] Attempt '
      '$attempt/${plan.retryPolicy.maxAttempts}',
    );
    try {
      final exitCode = await _spawnProcess(plan, sink);
      stopwatch.stop();
      sink.writeln(
        '===== exitCode=$exitCode '
        'duration=${stopwatch.elapsed} =====',
      );
      return _AttemptOutcome(
        exitCode: exitCode,
        elapsed: stopwatch.elapsed,
        message: 'exitCode $exitCode',
      );
    } on TimeoutException catch (error) {
      stopwatch.stop();
      sink.writeln(
        '[runner] Timed out after '
        '${plan.timeout.inSeconds}s',
      );
      return _AttemptOutcome(
        exitCode: -1,
        elapsed: stopwatch.elapsed,
        message: error.message ?? 'timeout',
      );
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  Future<int> _spawnProcess(_StepPlan plan, IOSink logSink) async {
    final process = await Process.start(
      plan.step.run,
      plan.step.args,
      workingDirectory: plan.workingDirectory,
      environment: plan.environment,
    );
    final pipes = _ProcessPipes(
      stepId: plan.step.id,
      logSink: logSink,
      process: process,
    );
    final completer = Completer<int>();
    final timer = Timer(plan.timeout, () {
      logSink.writeln('[runner] Timeout after ${plan.timeout.inSeconds}s');
      final terminated = process.kill(ProcessSignal.sigterm);
      if (!terminated) {
        process.kill(ProcessSignal.sigkill);
      }
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Timed out', plan.timeout));
      }
    });
    process.exitCode.then((code) {
      if (!completer.isCompleted) {
        timer.cancel();
        completer.complete(code);
      }
    });
    try {
      return await completer.future;
    } finally {
      await pipes.dispose();
    }
  }
}

class _ScenarioContext {
  _ScenarioContext({
    required this.defaults,
    required this.scenario,
    required String projectRoot,
    required this.timestamp,
  }) : projectRoot = Directory(projectRoot).absolute.path,
       baseValues = {
         'logRoot': defaults.logRoot,
         'scenario': scenario.id,
         'timestamp': timestamp,
       } {
    final scenarioDirRelative = _interpolate(
      defaults.artifactTemplates.scenarioDir,
      baseValues,
    );
    baseValues['scenarioDir'] = scenarioDirRelative;
    scenarioDir = _absolutePath(this.projectRoot, scenarioDirRelative);
    Directory(scenarioDir).createSync(recursive: true);
    final attachmentsRelative = _interpolate(
      defaults.artifactTemplates.attachmentsDir,
      baseValues,
    );
    attachmentsDir = _absolutePath(this.projectRoot, attachmentsRelative);
    Directory(attachmentsDir).createSync(recursive: true);
  }

  final PlaybookDefaults defaults;
  final ScenarioDefinition scenario;
  final String projectRoot;
  final String timestamp;
  final Map<String, String> baseValues;
  late final String scenarioDir;
  late final String attachmentsDir;

  Map<String, String> valuesForStep(String stepId) {
    final values = Map<String, String>.from(baseValues);
    values['stepId'] = stepId;
    return values;
  }

  String absolutePath(String path) => _absolutePath(projectRoot, path);
}

class _StepPlan {
  _StepPlan({
    required this.step,
    required this.logFile,
    required this.environment,
    required this.timeout,
    required this.retryPolicy,
    required this.artifacts,
    required this.workingDirectory,
  });

  final PlaybookStep step;
  final File logFile;
  final Map<String, String> environment;
  final Duration timeout;
  final RetryPolicy retryPolicy;
  final List<ResolvedArtifact> artifacts;
  final String workingDirectory;
}

class _AttemptOutcome {
  _AttemptOutcome({
    required this.exitCode,
    required this.elapsed,
    required this.message,
  });

  final int exitCode;
  final Duration elapsed;
  final String message;
}

class _ProcessPipes {
  _ProcessPipes({
    required String stepId,
    required this.logSink,
    required Process process,
  }) : stdoutPrinter = PrefixedPrinter('[$stepId]', stdout),
       stderrPrinter = PrefixedPrinter('[$stepId][stderr]', stderr) {
    stdoutSubscription = process.stdout.listen(_handleStdout);
    stderrSubscription = process.stderr.listen(_handleStderr);
  }

  final IOSink logSink;
  final PrefixedPrinter stdoutPrinter;
  final PrefixedPrinter stderrPrinter;
  late final StreamSubscription<List<int>> stdoutSubscription;
  late final StreamSubscription<List<int>> stderrSubscription;

  void _handleStdout(List<int> data) {
    logSink.add(data);
    stdoutPrinter.addBytes(data);
  }

  void _handleStderr(List<int> data) {
    logSink.add(data);
    stderrPrinter.addBytes(data);
  }

  Future<void> dispose() async {
    await stdoutSubscription.cancel();
    await stderrSubscription.cancel();
    stdoutPrinter.flush();
    stderrPrinter.flush();
  }
}

class PrefixedPrinter {
  PrefixedPrinter(this.prefix, this.sink);

  final String prefix;
  final IOSink sink;
  String _remainder = '';

  void addBytes(List<int> data) {
    final chunk = utf8.decode(data);
    _remainder += chunk;
    while (true) {
      final newlineIndex = _remainder.indexOf('\n');
      if (newlineIndex == -1) {
        break;
      }
      final line = _remainder.substring(0, newlineIndex);
      sink.writeln('$prefix $line');
      _remainder = _remainder.substring(newlineIndex + 1);
    }
  }

  void flush() {
    if (_remainder.isNotEmpty) {
      sink.writeln('$prefix $_remainder');
      _remainder = '';
    }
  }
}

List<ResolvedArtifact> _resolveArtifacts(
  _ScenarioContext context,
  List<ArtifactDefinition> artifacts, {
  required String scope,
  Map<String, String>? values,
}) {
  if (artifacts.isEmpty) {
    return const <ResolvedArtifact>[];
  }
  final templateValues = values ?? context.baseValues;
  return artifacts
      .map((definition) {
        final relative = _interpolate(definition.path, templateValues);
        final absolute = context.absolutePath(relative);
        return ResolvedArtifact(
          definition: definition,
          path: absolute,
          scope: scope,
        );
      })
      .toList(growable: false);
}

void _ensureParentDirectory(String path) {
  File(path).parent.createSync(recursive: true);
}

String _absolutePath(String projectRoot, String path) {
  if (_isAbsolute(path)) {
    return path;
  }
  return '$projectRoot/$path';
}

bool _isAbsolute(String path) {
  if (path.startsWith('/')) {
    return true;
  }
  final windowsPattern = RegExp(r'^[a-zA-Z]:[\\/]');
  return windowsPattern.hasMatch(path);
}

int _backoffDelaySeconds(RetryPolicy policy, int attemptNumber) {
  final exponent = max(0, attemptNumber - 1);
  final delay =
      policy.initialBackoffSeconds * pow(policy.backoffMultiplier, exponent);
  return delay.ceil();
}

String _interpolate(String template, Map<String, String> values) {
  final pattern = RegExp(r'{{\s*(\w+)\s*}}');
  return template.replaceAllMapped(pattern, (match) {
    final key = match.group(1)!;
    return values[key] ?? match.group(0)!;
  });
}

String _formatTimestamp(DateTime value) {
  return value.toUtc().toIso8601String().replaceAll(':', '-');
}
