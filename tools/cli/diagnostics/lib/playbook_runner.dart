import 'dart:io';

import 'playbook_parser.dart';
import 'runner_core.dart';
import 'runner_types.dart';

Future<void> main(List<String> args) async {
  RunnerCliOptions options;
  try {
    options = RunnerCliOptions.fromArgs(args);
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    _printUsage();
    exit(64);
  }
  if (options.printHelp) {
    _printUsage();
    exit(0);
  }

  final parser = DiagnosticsPlaybookParser(manifestPath: options.manifestPath);
  try {
    final playbook = parser.parse();
    final runner = PlaybookRunner(
      playbook: playbook,
      scenarioId: options.scenarioId,
      projectRoot: options.projectRoot,
      dryRun: options.dryRun,
    );
    final result = await runner.run();
    renderRunSummary(result);
    exit(result.succeeded ? 0 : 1);
  } on FormatException catch (error) {
    stderr.writeln('Playbook parse error: ${error.message}');
    exit(64);
  } on FileSystemException catch (error) {
    stderr.writeln('Playbook IO error: ${error.message} (${error.path})');
    exit(66);
  }
}

class RunnerCliOptions {
  RunnerCliOptions({
    required this.manifestPath,
    required this.scenarioId,
    required this.projectRoot,
    required this.dryRun,
    required this.printHelp,
  });

  factory RunnerCliOptions.fromArgs(List<String> args) {
    var manifestPath = 'tools/cli/diagnostics/playbooks/keynote.yaml';
    var scenarioId = 'default-smoke';
    var projectRoot = Directory.current.path;
    var dryRun = false;
    var printHelp = false;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      switch (arg) {
        case '--manifest':
        case '-m':
          manifestPath = _nextValue(args, ++i, arg);
          break;
        case '--scenario':
        case '-s':
          scenarioId = _nextValue(args, ++i, arg);
          break;
        case '--project-root':
          projectRoot = _nextValue(args, ++i, arg);
          break;
        case '--dry-run':
          dryRun = true;
          break;
        case '--help':
        case '-h':
          printHelp = true;
          break;
        default:
          throw ArgumentError('Unknown flag $arg');
      }
    }

    return RunnerCliOptions(
      manifestPath: manifestPath,
      scenarioId: scenarioId,
      projectRoot: projectRoot,
      dryRun: dryRun,
      printHelp: printHelp,
    );
  }

  final String manifestPath;
  final String scenarioId;
  final String projectRoot;
  final bool dryRun;
  final bool printHelp;
}

String _nextValue(List<String> args, int index, String flag) {
  if (index >= args.length) {
    throw ArgumentError('Missing value for $flag');
  }
  return args[index];
}

void _printUsage() {
  stdout.writeln('Diagnostics playbook runner');
  stdout.writeln('Usage: dart run playbook_runner.dart --scenario <id>');
  stdout.writeln('Flags:');
  stdout.writeln('  --manifest, -m      Path to playbook YAML');
  stdout.writeln('  --scenario, -s      Scenario id to execute');
  stdout.writeln('  --project-root      Repository root for relative commands');
  stdout.writeln('  --dry-run           Parse manifest without executing commands');
  stdout.writeln('  --help, -h          Show usage information');
}
