import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:beatbox_trainer/controllers/debug/debug_lab_controller.dart';
import 'package:beatbox_trainer/models/calibration_progress.dart';
import 'package:beatbox_trainer/models/classification_result.dart';
import 'package:beatbox_trainer/models/debug_log_entry.dart';
import 'package:beatbox_trainer/models/timing_feedback.dart';
import 'package:beatbox_trainer/services/audio/telemetry_stream.dart';
import 'package:beatbox_trainer/models/telemetry_event.dart';
import 'package:beatbox_trainer/services/audio/i_audio_service.dart';
import 'package:beatbox_trainer/services/debug/debug_sse_client.dart';
import 'package:beatbox_trainer/services/debug/fixture_metadata_service.dart';
import 'package:beatbox_trainer/services/debug/i_debug_service.dart';
import 'package:beatbox_trainer/bridge/api.dart/testing/fixture_manifest.dart';

void main() {
  _testLogsDeviceStream();
  _testSyntheticToggle();
  _testFixtureValidation();
  _testExportRequestIncludesContext();
}

void _testLogsDeviceStream() {
  test('DebugLabController logs device stream events', () async {
    final audio = _FakeAudioService();
    final debug = _FakeDebugService();
    final controller = DebugLabController(
      audioService: audio,
      debugService: debug,
      sseClient: _MockDebugSseClient(Stream.empty()),
      syntheticInterval: const Duration(milliseconds: 5),
      fixtureMetadataService: _FakeMetadataService(),
      anomalyLogPath: _tempLogPath(),
    );

    await controller.init();
    audio.emitClassification(_sampleResult());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.logEntries.value, isNotEmpty);
    expect(
      controller.logEntries.value.first.classification?.sound,
      equals(BeatboxHit.kick),
    );
  });
}

void _testSyntheticToggle() {
  test('Synthetic input toggle generates entries', () async {
    final audio = _FakeAudioService();
    final debug = _FakeDebugService();
    final controller = DebugLabController(
      audioService: audio,
      debugService: debug,
      sseClient: _MockDebugSseClient(Stream.empty()),
      syntheticInterval: const Duration(milliseconds: 5),
      fixtureMetadataService: _FakeMetadataService(),
      anomalyLogPath: _tempLogPath(),
    );

    await controller.init();
    controller.setSyntheticInput(true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      controller.logEntries.value.any(
        (entry) => entry.source == DebugLogSource.synthetic,
      ),
      isTrue,
    );
  });
}

void _testFixtureValidation() {
  test('Fixture validation surfaces anomalies', () async {
    final audio = _FakeAudioService();
    final debug = _FakeDebugService();
    final metadata = _FakeMetadataService(entry: _manifestEntry());
    final controller = DebugLabController(
      audioService: audio,
      debugService: debug,
      sseClient: _MockDebugSseClient(Stream.empty()),
      syntheticInterval: const Duration(milliseconds: 5),
      fixtureMetadataService: metadata,
      anomalyLogPath: _tempLogPath(),
    );

    await controller.init();
    await controller.setFixtureUnderTest('basic_hits');
    audio.emitClassification(_sampleResult());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.fixtureAnomaly.value, isNotNull);
  });
}

void _testExportRequestIncludesContext() {
  test('buildExportRequest captures fixture id and CLI references', () async {
    final audio = _FakeAudioService();
    final debug = _FakeDebugService();
    final controller = DebugLabController(
      audioService: audio,
      debugService: debug,
      sseClient: _MockDebugSseClient(Stream.empty()),
      syntheticInterval: const Duration(milliseconds: 5),
      fixtureMetadataService: _FakeMetadataService(entry: _manifestEntry()),
      anomalyLogPath: _tempLogPath(),
    );

    await controller.init();
    await controller.setFixtureUnderTest('basic_hits');

    final request = controller.buildExportRequest();
    expect(request.fixtureId, equals('basic_hits'));
    expect(request.cliReferences.first, contains('basic_hits'));
    expect(request.cliReferences.last, equals('ls logs/smoke/export'));
  });
}

ClassificationResult _sampleResult() {
  return ClassificationResult(
    sound: BeatboxHit.kick,
    timing: const TimingFeedback(
      classification: TimingClassification.onTime,
      errorMs: 0,
    ),
    timestampMs: 0,
    confidence: 0.9,
  );
}

class _FakeAudioService implements IAudioService {
  final _classificationController =
      StreamController<ClassificationResult>.broadcast();
  final _telemetryController = StreamController<TelemetryEvent>.broadcast();
  final _diagnosticController = StreamController<DiagnosticMetric>.broadcast();

  void emitClassification(ClassificationResult result) {
    _classificationController.add(result);
  }

  @override
  Stream<ClassificationResult> getClassificationStream() =>
      _classificationController.stream;

  @override
  Stream<TelemetryEvent> getTelemetryStream() => _telemetryController.stream;

  @override
  Stream<DiagnosticMetric> getDiagnosticMetricsStream() =>
      _diagnosticController.stream;

  @override
  Future<void> applyParamPatch({
    int? bpm,
    double? centroidThreshold,
    double? zcrThreshold,
  }) async {}

  // Remaining interface methods are unused in tests.
  @override
  Future<void> finishCalibration() => throw UnimplementedError();

  @override
  Stream<CalibrationProgress> getCalibrationStream() =>
      throw UnimplementedError();

  @override
  Future<void> setBpm({required int bpm}) => throw UnimplementedError();

  @override
  Future<void> startAudio({required int bpm}) => throw UnimplementedError();

  @override
  Future<void> startCalibration() => throw UnimplementedError();

  @override
  Future<void> stopAudio() => throw UnimplementedError();
}

class _FakeDebugService implements IDebugService {
  final _metricsController = StreamController<AudioMetrics>.broadcast();

  @override
  Stream<AudioMetrics> getAudioMetricsStream() => _metricsController.stream;

  @override
  Stream<OnsetEvent> getOnsetEventsStream() => const Stream<OnsetEvent>.empty();
}

class _MockDebugSseClient extends DebugSseClient {
  _MockDebugSseClient(this._stream);
  final Stream<ClassificationResult> _stream;

  @override
  Stream<ClassificationResult> connectClassificationStream({
    required Uri baseUri,
    required String token,
  }) => _stream;

  @override
  Future<void> dispose() async {}
}

class _FakeMetadataService implements IFixtureMetadataService {
  _FakeMetadataService({FixtureManifestEntry? entry}) : _entry = entry;
  final FixtureManifestEntry? _entry;

  @override
  bool get hasCache => _entry != null;

  @override
  Future<List<FixtureManifestEntry>> loadCatalog({
    bool forceRefresh = false,
  }) async {
    return _entry == null
        ? <FixtureManifestEntry>[]
        : <FixtureManifestEntry>[_entry!];
  }

  @override
  Future<FixtureManifestEntry?> loadById(
    String id, {
    bool forceRefresh = false,
  }) async {
    return _entry;
  }
}

String _tempLogPath() {
  final dir = Directory.systemTemp.createTempSync('debug_lab_test');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  return File.fromUri(dir.uri.resolve('anomalies.log')).path;
}

FixtureManifestEntry _manifestEntry() {
  return FixtureManifestEntry(
    id: 'basic_hits',
    description: null,
    source: const FixtureSourceDescriptor.synthetic(
      pattern: ManifestSyntheticPattern.sine,
      frequencyHz: 1.0,
      amplitude: 0.5,
    ),
    sampleRate: 48000,
    durationMs: 1000,
    loopCount: 1,
    channels: 1,
    metadata: const {},
    bpm: const FixtureBpmRange(min: 100, max: 120),
    expectedCounts: const {'kick': 2},
    anomalyTags: const ['smoke'],
    tolerances: FixtureToleranceEnvelope(
      latencyMs: const FixtureThreshold(max: 10),
      classificationDropPct: const FixtureThreshold(max: 0.0),
      bpmDeviationPct: const FixtureThreshold(max: 1.0),
    ),
  );
}
