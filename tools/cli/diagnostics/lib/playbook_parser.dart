import 'dart:io';

import 'package:yaml/yaml.dart';

import 'playbook_models.dart';

class DiagnosticsPlaybookParser {
  const DiagnosticsPlaybookParser({
    required this.manifestPath,
  });

  final String manifestPath;

  DiagnosticsPlaybook parse() {
    final file = File(manifestPath);
    if (!file.existsSync()) {
      throw FileSystemException('Playbook manifest not found', manifestPath);
    }

    final raw = file.readAsStringSync();
    final yaml = loadYaml(raw);
    if (yaml is! YamlMap) {
      throw const FormatException('Playbook manifest must be a YAML map');
    }

    final root = _mapFromYaml(yaml);
    final schemaVersion = _readInt(root, 'schemaVersion');
    if (schemaVersion != 1) {
      throw FormatException('Unsupported schemaVersion $schemaVersion');
    }

    final metadata = _parseMetadata(root['metadata']);
    final defaults = _parseDefaults(root['defaults']);
    final scenarios = _parseScenarios(root['scenarios']);

    if (scenarios.isEmpty) {
      throw const FormatException('Playbook must define at least one scenario');
    }

    return DiagnosticsPlaybook(
      schemaVersion: schemaVersion,
      metadata: metadata,
      defaults: defaults,
      scenarios: scenarios,
    );
  }

  PlaybookMetadata _parseMetadata(dynamic value) {
    final map = _mapFromYaml(value);
    return PlaybookMetadata(
      name: _readString(map, 'name'),
      description: _readString(map, 'description'),
      owner: _readString(map, 'owner'),
      generated: _readString(map, 'generated'),
      notes: map['notes']?.toString(),
    );
  }

  PlaybookDefaults _parseDefaults(dynamic value) {
    final map = _mapFromYaml(value);
    final templates = _mapFromYaml(map['artifactTemplates']);
    return PlaybookDefaults(
      logRoot: _readString(map, 'logRoot'),
      scenarioEnv: _stringMap(map['scenarioEnv']),
      retries: _parseRetryPolicy(map['retries']),
      stepTimeoutSeconds: _readInt(map, 'stepTimeoutSeconds'),
      artifactTemplates: ArtifactTemplates(
        scenarioDir: _readString(templates, 'scenarioDir'),
        stepLog: _readString(templates, 'stepLog'),
        attachmentsDir: _readString(templates, 'attachmentsDir'),
      ),
    );
  }

  Map<String, ScenarioDefinition> _parseScenarios(dynamic value) {
    final map = _mapFromYaml(value);
    final scenarios = <String, ScenarioDefinition>{};
    map.forEach((key, rawScenario) {
      final scenarioMap = _mapFromYaml(rawScenario);
      final summary = _readString(scenarioMap, 'summary');
      final stepsRaw = scenarioMap['steps'];
      if (stepsRaw is! List) {
        throw FormatException('Scenario "$key" must define steps');
      }
      final steps = <PlaybookStep>[];
      final stepIds = <String>{};
      for (final entry in stepsRaw) {
        final step = _parseStep(entry, scenarioId: key);
        if (!stepIds.add(step.id)) {
          throw FormatException('Scenario "$key" contains duplicate '
              'step id "${step.id}"');
        }
        steps.add(step);
      }
      if (steps.isEmpty) {
        throw FormatException('Scenario "$key" has no steps');
      }

      final artifacts = _parseArtifacts(scenarioMap['artifacts']);
      final tags = _stringList(scenarioMap['tags']);
      final env = _stringMap(scenarioMap['env']);
      final guards = _optionalStringKeyMap(scenarioMap['guards']);

      scenarios[key] = ScenarioDefinition(
        id: key,
        summary: summary,
        steps: steps,
        artifacts: artifacts,
        tags: tags,
        env: env,
        guards: guards,
      );
    });
    return scenarios;
  }

  PlaybookStep _parseStep(dynamic value, {required String scenarioId}) {
    final map = _mapFromYaml(value);
    final id = _readString(map, 'id');
    final run = _readString(map, 'run');
    final args = _stringList(map['args']);
    final description = map['description']?.toString();
    final env = _stringMap(map['env']);
    final timeoutSeconds = map.containsKey('timeoutSeconds')
        ? _readInt(map, 'timeoutSeconds')
        : null;
    final retries = map.containsKey('retries')
        ? _parseRetryPolicy(map['retries'])
        : null;
    final continueOnFailure = map['continueOnFailure'] == true;
    final artifacts = _parseArtifacts(map['artifacts']);
    final produces = _stringList(map['produces']);

    if (id.isEmpty) {
      throw FormatException('Scenario "$scenarioId" has step with empty id');
    }

    return PlaybookStep(
      id: id,
      run: run,
      args: args,
      description: description,
      env: env,
      timeoutSeconds: timeoutSeconds,
      retries: retries,
      continueOnFailure: continueOnFailure,
      artifacts: artifacts,
      produces: produces,
    );
  }

  List<ArtifactDefinition> _parseArtifacts(dynamic value) {
    if (value == null) {
      return const <ArtifactDefinition>[];
    }
    if (value is! List) {
      throw const FormatException('artifacts must be a list');
    }

    return value.map((raw) {
      final map = _mapFromYaml(raw);
      return ArtifactDefinition(
        name: _readString(map, 'name'),
        path: _readString(map, 'path'),
        type: map['type']?.toString(),
        description: map['description']?.toString(),
        required: map['required'] == true,
      );
    }).toList(growable: false);
  }

  RetryPolicy _parseRetryPolicy(dynamic value) {
    final map = _mapFromYaml(value);
    return RetryPolicy(
      maxAttempts: _readInt(map, 'maxAttempts'),
      initialBackoffSeconds: _readInt(map, 'initialBackoffSeconds'),
      backoffMultiplier: _readDouble(map, 'backoffMultiplier'),
    );
  }

  Map<String, dynamic> _mapFromYaml(dynamic value) {
    if (value is YamlMap) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), _convertYamlValue(v)));
    }
    if (value is Map) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), _convertYamlValue(v)));
    }
    throw const FormatException('YAML entry must be a map');
  }

  Map<String, String> _stringMap(dynamic value) {
    if (value == null) {
      return const <String, String>{};
    }
    if (value is! Map) {
      throw const FormatException('Expected a key/value map');
    }
    return value.map((key, dynamic v) => MapEntry(key.toString(), v.toString()));
  }

  Map<String, Object?> _optionalStringKeyMap(dynamic value) {
    if (value == null) {
      return const <String, Object?>{};
    }
    if (value is! Map) {
      throw const FormatException('Expected a key/value map');
    }
    return value.map((key, dynamic v) => MapEntry(key.toString(), _convertYamlValue(v)));
  }

  List<String> _stringList(dynamic value) {
    if (value == null) {
      return const <String>[];
    }
    if (value is! List) {
      throw const FormatException('Expected a list of scalars');
    }
    return value.map((item) => item.toString()).toList(growable: false);
  }

  int _readInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw FormatException('Expected integer for "$key" but got $value');
  }

  double _readDouble(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    throw FormatException('Expected number for "$key" but got $value');
  }

  String _readString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) {
      throw FormatException('Required key "$key" missing');
    }
    return value.toString();
  }

  dynamic _convertYamlValue(dynamic value) {
    if (value is YamlMap) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), _convertYamlValue(v)));
    }
    if (value is YamlList) {
      return value.map(_convertYamlValue).toList();
    }
    return value;
  }
}
