import 'dart:convert';
import 'dart:io';

class BaselineDiffCliOptions {
  BaselineDiffCliOptions({
    required this.scenarioId,
    required this.baselinePath,
    required this.projectRoot,
    required this.manifestPath,
    required this.metricsPath,
    required this.watchMode,
    required this.watchPaths,
    required this.debounceSeconds,
    required this.regenerate,
    required this.runPlaybook,
  });

  factory BaselineDiffCliOptions.parse(List<String> args) {
    var scenarioId = 'default-smoke';
    String? baselinePath;
    String? manifestPath;
    String? metricsPath;
    String? projectRoot;
    var watchMode = false;
    final watchPaths = <String>[];
    var debounceSeconds = 5;
    var regenerate = false;
    var runPlaybook = false;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      switch (arg) {
        case '--scenario':
          scenarioId = readArgValue(args, ++i, arg);
          break;
        case '--baseline':
          baselinePath = readArgValue(args, ++i, arg);
          break;
        case '--manifest':
          manifestPath = readArgValue(args, ++i, arg);
          break;
        case '--metrics':
          metricsPath = readArgValue(args, ++i, arg);
          break;
        case '--project-root':
          projectRoot = readArgValue(args, ++i, arg);
          break;
        case '--watch':
          watchMode = true;
          break;
        case '--watch-path':
          watchPaths.add(readArgValue(args, ++i, arg));
          break;
        case '--debounce-seconds':
          debounceSeconds = int.parse(readArgValue(args, ++i, arg));
          break;
        case '--regenerate':
          regenerate = true;
          break;
        case '--run-playbook':
          runPlaybook = true;
          break;
        case '--help':
        case '-h':
          throw UsageRequested();
        default:
          throw ArgumentError('Unknown flag $arg');
      }
    }

    final resolvedRoot =
        Directory(projectRoot ?? Directory.current.path).absolute.path;
    final resolvedBaseline =
        absolutePath(baselinePath ?? 'logs/smoke/baselines/$scenarioId.json', resolvedRoot);
    final resolvedManifest = manifestPath == null
        ? '$resolvedRoot/tools/cli/diagnostics/playbooks/keynote.yaml'
        : absolutePath(manifestPath, resolvedRoot);
    final resolvedMetrics =
        metricsPath != null ? absolutePath(metricsPath, resolvedRoot) : null;
    final resolvedWatchPaths =
        watchPaths.map((path) => absolutePath(path, resolvedRoot)).toList();

    if (watchMode && !runPlaybook) {
      throw ArgumentError('--run-playbook required when --watch is used');
    }
    if (debounceSeconds < 5) {
      throw ArgumentError('Debounce must be at least 5 seconds');
    }

    return BaselineDiffCliOptions(
      scenarioId: scenarioId,
      baselinePath: resolvedBaseline,
      projectRoot: resolvedRoot,
      manifestPath: resolvedManifest,
      metricsPath: resolvedMetrics,
      watchMode: watchMode,
      watchPaths: resolvedWatchPaths,
      debounceSeconds: debounceSeconds,
      regenerate: regenerate,
      runPlaybook: runPlaybook,
    );
  }

  final String scenarioId;
  final String baselinePath;
  final String projectRoot;
  final String? manifestPath;
  final String? metricsPath;
  final bool watchMode;
  final List<String> watchPaths;
  final int debounceSeconds;
  final bool regenerate;
  final bool runPlaybook;

  BaselineDiffCliOptions copyWith({String? baselinePath}) {
    return BaselineDiffCliOptions(
      scenarioId: scenarioId,
      baselinePath: baselinePath ?? this.baselinePath,
      projectRoot: projectRoot,
      manifestPath: manifestPath,
      metricsPath: metricsPath,
      watchMode: watchMode,
      watchPaths: watchPaths,
      debounceSeconds: debounceSeconds,
      regenerate: regenerate,
      runPlaybook: runPlaybook,
    );
  }
}

class BaselineSnapshot {
  BaselineSnapshot({
    required this.path,
    required this.schemaVersion,
    required this.scenarioId,
    required this.metricsArtifact,
    required this.metrics,
    this.logRoot,
    this.regenerateCommand,
    this.capturedAt,
    this.sourceArtifact,
  });

  static Future<BaselineSnapshot> load(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw BaselineDiffException('baseline snapshot not found at $path');
    }
    final content = await file.readAsString();
    final dynamic decoded = json.decode(content);
    if (decoded is! Map<String, dynamic>) {
      throw BaselineDiffException('baseline snapshot is not an object: $path');
    }
    return BaselineSnapshot.fromJson(decoded, path);
  }

  factory BaselineSnapshot.fromJson(Map<String, dynamic> json, String path) {
    final metricsJson = json['metrics'];
    if (metricsJson is! List) {
      throw BaselineDiffException('baseline metrics must be a list');
    }
    final metrics = metricsJson
        .map((entry) => MetricExpectation.fromJson(entry))
        .toList()
        .cast<MetricExpectation>();
    return BaselineSnapshot(
      path: path,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      scenarioId: json['scenario'] as String? ??
          (throw BaselineDiffException('baseline missing "scenario" field')),
      metricsArtifact: json['metricsArtifact'] as String? ??
          (throw BaselineDiffException(
              'baseline missing "metricsArtifact" field')),
      metrics: metrics,
      logRoot: json['logRoot'] as String?,
      regenerateCommand: json['regenerateCommand'] as String?,
      capturedAt: json['capturedAt'] as String?,
      sourceArtifact: json['sourceArtifact'] as String?,
    );
  }

  final String path;
  final int schemaVersion;
  final String scenarioId;
  final String metricsArtifact;
  final List<MetricExpectation> metrics;
  final String? logRoot;
  final String? regenerateCommand;
  final String? capturedAt;
  final String? sourceArtifact;

  BaselineSnapshot rebaseline({
    required Map<String, dynamic> telemetry,
    required String relativeArtifact,
  }) {
    final updatedMetrics = metrics
        .map(
          (metric) => metric.updateExpected(
            metric.readValue(telemetry),
          ),
        )
        .toList();
    return BaselineSnapshot(
      path: path,
      schemaVersion: schemaVersion,
      scenarioId: scenarioId,
      metricsArtifact: metricsArtifact,
      metrics: updatedMetrics,
      logRoot: logRoot,
      regenerateCommand: regenerateCommand,
      capturedAt: DateTime.now().toUtc().toIso8601String(),
      sourceArtifact: relativeArtifact,
    );
  }

  Future<void> save() async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final encoder = const JsonEncoder.withIndent('  ');
    final snapshot = <String, Object?>{
      'schemaVersion': schemaVersion,
      'scenario': scenarioId,
      'metricsArtifact': metricsArtifact,
      if (logRoot != null) 'logRoot': logRoot,
      if (regenerateCommand != null)
        'regenerateCommand': regenerateCommand,
      'capturedAt': capturedAt,
      'sourceArtifact': sourceArtifact,
      'metrics': metrics.map((metric) => metric.toJson()).toList(),
    };
    await file.writeAsString('${encoder.convert(snapshot)}\n');
  }
}

class MetricExpectation {
  MetricExpectation({
    required this.id,
    required this.path,
    required this.expected,
    required this.tolerance,
    this.label,
    this.warnOnly = false,
  });

  factory MetricExpectation.fromJson(Map<String, dynamic> json) {
    final toleranceJson = json['tolerance'];
    if (toleranceJson is! Map<String, dynamic>) {
      throw BaselineDiffException(
          'metric ${json['id']} missing tolerance definition');
    }
    return MetricExpectation(
      id: json['id'] as String? ??
          (throw BaselineDiffException('metric missing "id" field')),
      path: json['path'] as String? ??
          (throw BaselineDiffException('metric ${json['id']} missing "path"')),
      expected: parseNumeric(json['expected'], json['id']),
      label: json['label'] as String?,
      tolerance: BaselineTolerance.fromJson(toleranceJson),
      warnOnly: json['warnOnly'] as bool? ?? false,
    );
  }

  final String id;
  final String path;
  final double expected;
  final BaselineTolerance tolerance;
  final String? label;
  final bool warnOnly;

  MetricExpectation updateExpected(double? value) {
    if (value == null) {
      return this;
    }
    return MetricExpectation(
      id: id,
      path: path,
      expected: value,
      tolerance: tolerance,
      label: label,
      warnOnly: warnOnly,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'path': path,
      'label': label,
      'expected': expected,
      'warnOnly': warnOnly,
      'tolerance': tolerance.toJson(),
    };
  }

  double? readValue(Map<String, dynamic> telemetry) {
    final parts = path.split('.');
    dynamic current = telemetry;
    for (final segment in parts) {
      if (current is Map<String, dynamic> && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return null;
      }
    }
    if (current is num) {
      return current.toDouble();
    }
    return null;
  }
}

class BaselineTolerance {
  const BaselineTolerance({
    this.absolute,
    this.percent,
  });

  factory BaselineTolerance.fromJson(Map<String, dynamic> json) {
    final absolute = json['absolute'];
    final percent = json['percent'];
    if (absolute == null && percent == null) {
      throw BaselineDiffException(
          'tolerance requires "absolute" and/or "percent"');
    }
    return BaselineTolerance(
      absolute: absolute == null ? null : parseNumeric(absolute, 'tolerance'),
      percent: percent == null ? null : parseNumeric(percent, 'tolerance'),
    );
  }

  final double? absolute;
  final double? percent;

  bool allows(num actual, num expected) {
    final diff = (actual - expected).abs().toDouble();
    if (absolute != null && diff > absolute!) {
      return false;
    }
    if (percent != null) {
      final base = expected.abs();
      final limit =
          base == 0 ? (percent! / 100.0) : base * (percent! / 100.0);
      if (diff > limit) {
        return false;
      }
    }
    return true;
  }

  String describe(double expected) {
    final parts = <String>[];
    if (absolute != null) {
      parts.add('±$absolute');
    }
    if (percent != null) {
      parts.add('$percent%');
    }
    if (parts.isEmpty) {
      return 'none';
    }
    return parts.join(' & ');
  }

  Map<String, Object?> toJson() {
    return {
      if (absolute != null) 'absolute': absolute,
      if (percent != null) 'percent': percent,
    };
  }
}

class BaselineDiffEngine {
  BaselineComparison compare({
    required BaselineSnapshot baseline,
    required Map<String, dynamic> telemetry,
  }) {
    final metrics = <MetricComparison>[];
    for (final metric in baseline.metrics) {
      final actual = metric.readValue(telemetry);
      if (actual == null) {
        metrics.add(MetricComparison(
          expectation: metric,
          actualValue: null,
          withinTolerance: metric.warnOnly,
          failureReason: 'value not found at ${metric.path}',
        ));
        continue;
      }
      final within = metric.tolerance.allows(actual, metric.expected);
      metrics.add(MetricComparison(
        expectation: metric,
        actualValue: actual,
        withinTolerance: within || metric.warnOnly,
        failureReason: within
            ? null
            : 'difference ${formatDiff(actual, metric.expected)} exceeds tolerance',
      ));
    }
    return BaselineComparison(metrics: metrics);
  }
}

class BaselineComparison {
  BaselineComparison({required this.metrics});

  final List<MetricComparison> metrics;

  bool get withinTolerance =>
      metrics.every((metric) => metric.withinTolerance);
}

class MetricComparison {
  MetricComparison({
    required this.expectation,
    required this.actualValue,
    required this.withinTolerance,
    required this.failureReason,
  });

  final MetricExpectation expectation;
  final double? actualValue;
  final bool withinTolerance;
  final String? failureReason;
}

class BaselineDiffException implements Exception {
  BaselineDiffException(this.message);

  final String message;
}

class ArtifactCandidate {
  ArtifactCandidate(this.path, this.modified);

  final String path;
  final DateTime modified;
}

class UsageRequested implements Exception {}

String absolutePath(String path, String projectRoot) {
  if (isAbsolutePath(path)) {
    return path;
  }
  return '$projectRoot/$path';
}

String relativePath(String root, String target) {
  if (target.startsWith(root)) {
    final relative = target.substring(root.length);
    if (relative.startsWith('/')) {
      return relative.substring(1);
    }
    return relative;
  }
  return target;
}

bool isAbsolutePath(String path) {
  if (path.startsWith('/')) {
    return true;
  }
  final windowsPattern = RegExp(r'^[a-zA-Z]:[\\/]');
  return windowsPattern.hasMatch(path);
}

String readArgValue(List<String> args, int index, String flag) {
  if (index >= args.length) {
    throw ArgumentError('Missing value for $flag');
  }
  return args[index];
}

double parseNumeric(Object? input, Object? context) {
  if (input is num) {
    return input.toDouble();
  }
  if (input is String) {
    return double.parse(input);
  }
  throw BaselineDiffException('Expected numeric value for $context');
}

String formatDiff(double actual, double expected) {
  final diff = actual - expected;
  final sign = diff >= 0 ? '+' : '-';
  return '$sign${diff.abs().toStringAsFixed(3)}';
}
