import 'dart:collection';

class DiagnosticsPlaybook {
  DiagnosticsPlaybook({
    required this.schemaVersion,
    required this.metadata,
    required this.defaults,
    required Map<String, ScenarioDefinition> scenarios,
  }) : scenarios = UnmodifiableMapView(scenarios);

  final int schemaVersion;
  final PlaybookMetadata metadata;
  final PlaybookDefaults defaults;
  final Map<String, ScenarioDefinition> scenarios;

  ScenarioDefinition scenarioById(String id) {
    final scenario = scenarios[id];
    if (scenario == null) {
      throw ArgumentError('Unknown scenario "$id". Available: '
          '${scenarios.keys.toList()..sort()}');
    }
    return scenario;
  }
}

class PlaybookMetadata {
  const PlaybookMetadata({
    required this.name,
    required this.description,
    required this.owner,
    required this.generated,
    this.notes,
  });

  final String name;
  final String description;
  final String owner;
  final String generated;
  final String? notes;
}

class PlaybookDefaults {
  const PlaybookDefaults({
    required this.logRoot,
    required this.scenarioEnv,
    required this.retries,
    required this.stepTimeoutSeconds,
    required this.artifactTemplates,
  });

  final String logRoot;
  final Map<String, String> scenarioEnv;
  final RetryPolicy retries;
  final int stepTimeoutSeconds;
  final ArtifactTemplates artifactTemplates;
}

class ArtifactTemplates {
  const ArtifactTemplates({
    required this.scenarioDir,
    required this.stepLog,
    required this.attachmentsDir,
  });

  final String scenarioDir;
  final String stepLog;
  final String attachmentsDir;
}

class ScenarioDefinition {
  const ScenarioDefinition({
    required this.id,
    required this.summary,
    required this.steps,
    this.tags = const <String>[],
    this.env = const <String, String>{},
    this.artifacts = const <ArtifactDefinition>[],
    this.guards = const <String, Object?>{},
  });

  final String id;
  final String summary;
  final List<String> tags;
  final Map<String, String> env;
  final List<ArtifactDefinition> artifacts;
  final Map<String, Object?> guards;
  final List<PlaybookStep> steps;
}

class PlaybookStep {
  const PlaybookStep({
    required this.id,
    required this.run,
    this.args = const <String>[],
    this.description,
    this.env = const <String, String>{},
    this.timeoutSeconds,
    this.retries,
    this.continueOnFailure = false,
    this.artifacts = const <ArtifactDefinition>[],
    this.produces = const <String>[],
  });

  final String id;
  final String run;
  final List<String> args;
  final String? description;
  final Map<String, String> env;
  final int? timeoutSeconds;
  final RetryPolicy? retries;
  final bool continueOnFailure;
  final List<ArtifactDefinition> artifacts;
  final List<String> produces;
}

class ArtifactDefinition {
  const ArtifactDefinition({
    required this.name,
    required this.path,
    this.type,
    this.description,
    this.required = false,
  });

  final String name;
  final String path;
  final String? type;
  final String? description;
  final bool required;
}

class RetryPolicy {
  const RetryPolicy({
    required this.maxAttempts,
    required this.initialBackoffSeconds,
    required this.backoffMultiplier,
  });

  final int maxAttempts;
  final int initialBackoffSeconds;
  final double backoffMultiplier;
}
