import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'baseline_core.dart';

Future<void> main(List<String> args) async {
  late final BaselineDiffCliOptions options;
  try {
    options = BaselineDiffCliOptions.parse(args);
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    _printUsage();
    exit(64);
  } on UsageRequested {
    _printUsage();
    exit(0);
  }

  try {
    if (options.watchMode) {
      await _runWatchLoop(options);
    } else {
      final ok = await _runComparisonOnce(options);
      exit(ok ? 0 : 2);
    }
  } on BaselineDiffException catch (error) {
    stderr.writeln('baseline diff error: ${error.message}');
    exit(2);
  }
}

Future<bool> _runComparisonOnce(BaselineDiffCliOptions options) async {
  final baseline = await BaselineSnapshot.load(options.baselinePath);
  if (options.runPlaybook) {
    await _runPlaybook(options);
  }

  final metricsPath = await _resolveMetricsPath(baseline, options);
  final telemetry = await _loadTelemetry(metricsPath);
  final comparison =
      BaselineDiffEngine().compare(baseline: baseline, telemetry: telemetry);

  _printComparison(
    comparison,
    baseline,
    metricsPath,
    options.projectRoot,
  );

  if (options.regenerate) {
    final updated = baseline.rebaseline(
      telemetry: telemetry,
      relativeArtifact: relativePath(options.projectRoot, metricsPath),
    );
    await updated.save();
    stdout.writeln(
      'Baseline snapshot updated at ${relativePath(options.projectRoot, baseline.path)}',
    );
  }

  if (!comparison.withinTolerance) {
    stdout.writeln('');
    stdout.writeln(
        'Regenerate the baseline with: ${_regenerateCommand(options, metricsPath)}');
  }

  return comparison.withinTolerance;
}

Future<void> _runWatchLoop(BaselineDiffCliOptions options) async {
  final paths = options.watchPaths.isEmpty
      ? _defaultWatchPaths(options.projectRoot)
      : options.watchPaths;
  stdout.writeln('Watching ${paths.length} paths for ${options.scenarioId}:');
  for (final path in paths) {
    stdout.writeln('  • ${relativePath(options.projectRoot, path)}');
  }
  stdout.writeln('Debounce: ${options.debounceSeconds}s');

  final subscriptions = <StreamSubscription<FileSystemEvent>>[];
  Timer? debounceTimer;

  Future<void> runCycle(String reason) async {
    stdout.writeln('\n[watch] Triggered by $reason');
    try {
      final ok = await _runComparisonOnce(options);
      if (ok) {
        stdout.writeln('[watch] Baseline matches ✅');
      } else {
        stdout.writeln('[watch] Baseline drift detected ❌');
      }
    } on BaselineDiffException catch (error) {
      stdout.writeln('[watch] ${error.message}');
    } catch (error, stack) {
      stderr.writeln('[watch] error: $error');
      stderr.writeln(stack);
    }
  }

  void schedule(String reason) {
    debounceTimer?.cancel();
    debounceTimer =
        Timer(Duration(seconds: options.debounceSeconds), () => runCycle(reason));
  }

  for (final path in paths) {
    final directory = Directory(path);
    if (!directory.existsSync()) {
      stdout.writeln(
          '[watch] Skipping missing path ${relativePath(options.projectRoot, path)}');
      continue;
    }
    final subscription = directory
        .watch(recursive: true)
        .listen((event) => schedule(event.path));
    subscriptions.add(subscription);
  }

  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\n[watch] Caught SIGINT, stopping...');
    await Future.wait(subscriptions.map((s) => s.cancel()));
    debounceTimer?.cancel();
    exit(0);
  });

  await runCycle('startup');
  await Completer<void>().future;
}

Future<void> _runPlaybook(BaselineDiffCliOptions options) async {
  final script =
      File('${options.projectRoot}/tools/cli/diagnostics/run.sh');
  if (!script.existsSync()) {
    throw BaselineDiffException(
      'diagnostics runner missing at ${relativePath(options.projectRoot, script.path)}',
    );
  }
  final args = ['--scenario', options.scenarioId];
  if (options.manifestPath != null) {
    args.addAll(['--manifest', options.manifestPath!]);
  }
  final process = await Process.start(
    script.path,
    args,
    workingDirectory: options.projectRoot,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw BaselineDiffException(
      'playbook run failed with exit code $exitCode',
    );
  }
}

Future<String> _resolveMetricsPath(
  BaselineSnapshot baseline,
  BaselineDiffCliOptions options,
) async {
  if (options.metricsPath != null) {
    final path = absolutePath(options.metricsPath!, options.projectRoot);
    if (!File(path).existsSync()) {
      throw BaselineDiffException('metrics file not found at $path');
    }
    return path;
  }
  final logRoot =
      absolutePath(baseline.logRoot ?? 'logs/diagnostics', options.projectRoot);
  final scenarioDir = Directory('$logRoot/${options.scenarioId}');
  if (!scenarioDir.existsSync()) {
    throw BaselineDiffException(
      'no runs found under ${relativePath(options.projectRoot, scenarioDir.path)}',
    );
  }
  final candidates = <ArtifactCandidate>[];
  final metricRelative = baseline.metricsArtifact;
  for (final entry in scenarioDir.listSync().whereType<Directory>()) {
    final file = File('${entry.path}/$metricRelative');
    if (file.existsSync()) {
      final stat = await file.stat();
      candidates.add(ArtifactCandidate(file.path, stat.modified));
    }
  }
  if (candidates.isEmpty) {
    throw BaselineDiffException(
      'no metrics artifacts found at ${baseline.metricsArtifact}. '
      'Last run may have failed.',
    );
  }
  candidates.sort((a, b) => b.modified.compareTo(a.modified));
  return candidates.first.path;
}

Future<Map<String, dynamic>> _loadTelemetry(String path) async {
  try {
    final content = await File(path).readAsString();
    final dynamic decoded = json.decode(content);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw BaselineDiffException(
        'telemetry payload at $path is not a JSON object');
  } on FormatException catch (error) {
    throw BaselineDiffException(
        'telemetry payload at $path is invalid JSON: ${error.message}');
  } on IOException catch (error) {
    throw BaselineDiffException(
        'failed to read telemetry payload at $path (${error.osError?.message ?? ''})');
  }
}

void _printComparison(
  BaselineComparison comparison,
  BaselineSnapshot baseline,
  String metricsPath,
  String projectRoot,
) {
  stdout.writeln(
      'Scenario ${baseline.scenarioId} vs baseline (${relativePath(projectRoot, baseline.path)})');
  stdout.writeln('Telemetry: ${relativePath(projectRoot, metricsPath)}');
  for (final metric in comparison.metrics) {
    final icon = metric.withinTolerance ? '✔' : '✖';
    final label = metric.expectation.label ?? metric.expectation.id;
    final actualString =
        metric.actualValue != null ? metric.actualValue!.toStringAsFixed(3) : 'n/a';
    final delta = metric.actualValue != null
        ? (metric.actualValue! - metric.expectation.expected).toStringAsFixed(3)
        : 'n/a';
    final tolerance =
        metric.expectation.tolerance.describe(metric.expectation.expected);
    stdout.writeln(
        '  $icon $label → actual=$actualString expected=${metric.expectation.expected} '
        'Δ=$delta tolerance=$tolerance');
    if (!metric.withinTolerance) {
      stdout.writeln('    ↳ reason: ${metric.failureReason}');
    }
  }
}

String _regenerateCommand(
  BaselineDiffCliOptions options,
  String metricsPath,
) {
  final relativeMetrics = relativePath(options.projectRoot, metricsPath);
  final buffer = StringBuffer()
    ..write('dart run tools/cli/diagnostics/lib/baseline_diff.dart')
    ..write(' --scenario ${options.scenarioId}')
    ..write(' --metrics "$relativeMetrics"')
    ..write(' --regenerate');
  if (options.baselinePath !=
      '${options.projectRoot}/logs/smoke/baselines/${options.scenarioId}.json') {
    buffer.write(
        ' --baseline ${relativePath(options.projectRoot, options.baselinePath)}');
  }
  return buffer.toString();
}

List<String> _defaultWatchPaths(String projectRoot) {
  final paths = [
    'rust/src',
    'rust/src/bin',
    'tools/cli/diagnostics',
    'lib/services/audio',
    'lib/controllers/debug',
    'scripts/pre-commit',
  ];
  return paths.map((path) => absolutePath(path, projectRoot)).toList();
}

void _printUsage() {
  stdout.writeln('Diagnostics baseline diff utility');
  stdout.writeln('Usage: dart run baseline_diff.dart [options]');
  stdout.writeln('Options:');
  stdout.writeln('  --scenario <id>            Scenario id to diff (default-smoke)');
  stdout.writeln('  --baseline <path>          Path to baseline snapshot');
  stdout.writeln('  --metrics <path>           Path to telemetry JSON (auto-detect otherwise)');
  stdout.writeln('  --manifest <path>          Playbook manifest path');
  stdout.writeln('  --project-root <path>      Repository root (auto-detected)');
  stdout.writeln('  --run-playbook             Execute playbook before diffing');
  stdout.writeln('  --regenerate               Update baseline expected values from metrics');
  stdout.writeln('  --watch                    Watch mode (requires --run-playbook)');
  stdout.writeln('  --debounce-seconds <int>   Debounce duration for watch mode (default 5)');
  stdout.writeln('  --watch-path <path>        Directory to watch (may repeat)');
  stdout.writeln('  --help                     Show this message');
}
