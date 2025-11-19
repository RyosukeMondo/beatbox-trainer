import 'dart:async';
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
import 'package:beatbox_trainer/services/debug/i_debug_service.dart';

void main() {
  test('DebugLabController logs device stream events', () async {
    final audio = _FakeAudioService();
    final debug = _FakeDebugService();
    final controller = DebugLabController(
      audioService: audio,
      debugService: debug,
      sseClient: _MockDebugSseClient(Stream.empty()),
      syntheticInterval: const Duration(milliseconds: 5),
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

  test('Synthetic input toggle generates entries', () async {
    final audio = _FakeAudioService();
    final debug = _FakeDebugService();
    final controller = DebugLabController(
      audioService: audio,
      debugService: debug,
      sseClient: _MockDebugSseClient(Stream.empty()),
      syntheticInterval: const Duration(milliseconds: 5),
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

  @override
  Future<String> exportLogs() async => '{}';
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
