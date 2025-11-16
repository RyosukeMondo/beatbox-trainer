import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/classification_result.dart';
import '../../models/debug_log_entry.dart';
import '../../models/telemetry_event.dart';
import '../../models/timing_feedback.dart';
import '../../services/audio/i_audio_service.dart';
import '../../services/debug/debug_sse_client.dart';
import '../../services/debug/i_debug_service.dart';

/// Controller orchestrating Debug Lab streams and commands.
class DebugLabController {
  DebugLabController({
    required IAudioService audioService,
    required IDebugService debugService,
    DebugSseClient? sseClient,
    Duration syntheticInterval = const Duration(seconds: 2),
  })  : _audioService = audioService,
        _debugService = debugService,
        _sseClient = sseClient ?? DebugSseClient(),
        _syntheticInterval = syntheticInterval;

  final IAudioService _audioService;
  final IDebugService _debugService;
  final DebugSseClient _sseClient;
  final Duration _syntheticInterval;

  final StreamController<ClassificationResult> _classificationController =
      StreamController.broadcast();
  final StreamController<TelemetryEvent> _telemetryController =
      StreamController.broadcast();
  final StreamController<AudioMetrics> _metricsController =
      StreamController.broadcast();

  StreamSubscription<ClassificationResult>? _classificationSub;
  StreamSubscription<TelemetryEvent>? _telemetrySub;
  StreamSubscription<AudioMetrics>? _metricsSub;
  StreamSubscription<ClassificationResult>? _remoteSub;
  Timer? _syntheticTimer;

  final ValueNotifier<List<DebugLogEntry>> logEntries =
      ValueNotifier<List<DebugLogEntry>>([]);
  final ValueNotifier<bool> remoteConnected = ValueNotifier(false);
  final ValueNotifier<String?> remoteError = ValueNotifier(null);
  final ValueNotifier<bool> syntheticEnabled = ValueNotifier(false);

  /// Initialize stream subscriptions.
  Future<void> init() async {
    _classificationSub = _audioService.getClassificationStream().listen(
      (result) {
        _classificationController.add(result);
        _pushLog(DebugLogEntry.forClassification(
          result,
          source: DebugLogSource.device,
        ));
      },
      onError: (error) => _pushLog(
        DebugLogEntry.error('Classification stream error', '$error'),
      ),
    );

    _telemetrySub = _audioService.getTelemetryStream().listen(
      (event) {
        _telemetryController.add(event);
        _pushLog(DebugLogEntry.forTelemetry(event));
      },
      onError: (error) => _pushLog(
        DebugLogEntry.error('Telemetry stream error', '$error'),
      ),
    );

    try {
      _metricsSub = _debugService.getAudioMetricsStream().listen(
        (metrics) {
          _metricsController.add(metrics);
        },
        onError: (error) => _pushLog(
          DebugLogEntry.error('Metrics stream error', '$error'),
        ),
      );
    } catch (error) {
      _pushLog(DebugLogEntry.error('Metrics unavailable', '$error'));
    }
  }

  Stream<ClassificationResult> get classificationStream =>
      _classificationController.stream;

  Stream<TelemetryEvent> get telemetryStream =>
      _telemetryController.stream;

  Stream<AudioMetrics> get metricsStream => _metricsController.stream;

  /// Apply parameter patch to running engine.
  Future<void> applyParamPatch({
    int? bpm,
    double? centroidThreshold,
    double? zcrThreshold,
  }) {
    return _audioService.applyParamPatch(
      bpm: bpm,
      centroidThreshold: centroidThreshold,
      zcrThreshold: zcrThreshold,
    );
  }

  /// Connect to remote SSE stream.
  Future<void> connectRemote({
    required Uri baseUri,
    required String token,
  }) async {
    remoteError.value = null;
    remoteConnected.value = true;
    await _remoteSub?.cancel();
    _remoteSub = _sseClient
        .connectClassificationStream(baseUri: baseUri, token: token)
        .listen(
      (event) {
        _classificationController.add(event);
        _pushLog(DebugLogEntry.forClassification(
          event,
          source: DebugLogSource.remote,
        ));
      },
      onError: (error) {
        remoteConnected.value = false;
        remoteError.value = error.toString();
        _pushLog(DebugLogEntry.error('Remote SSE error', '$error'));
      },
      onDone: () {
        remoteConnected.value = false;
      },
    );
  }

  Future<void> disconnectRemote() async {
    remoteConnected.value = false;
    remoteError.value = null;
    await _remoteSub?.cancel();
    _remoteSub = null;
  }

  /// Enable or disable synthetic fixtures for offline visualization.
  void setSyntheticInput(bool enabled) {
    syntheticEnabled.value = enabled;
    _syntheticTimer?.cancel();
    if (!enabled) {
      return;
    }

    _syntheticTimer = Timer.periodic(_syntheticInterval, (_) {
      final hit = BeatboxHit.values[
          DateTime.now().millisecondsSinceEpoch %
              BeatboxHit.values.length];
      final synthetic = ClassificationResult(
        sound: hit,
        timing: TimingFeedback(
          classification: TimingClassification.values[
              DateTime.now().second % TimingClassification.values.length],
          errorMs: (DateTime.now().millisecond % 120) - 60,
        ),
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        confidence: 0.5 + (DateTime.now().millisecond % 50) / 100,
      );
      _classificationController.add(synthetic);
      _pushLog(DebugLogEntry.forClassification(
        synthetic,
        source: DebugLogSource.synthetic,
      ));
    });
  }

  void _pushLog(DebugLogEntry entry) {
    final current = List<DebugLogEntry>.from(logEntries.value);
    current.insert(0, entry);
    if (current.length > 200) {
      current.removeRange(200, current.length);
    }
    logEntries.value = current;
  }

  Future<void> dispose() async {
    await _classificationSub?.cancel();
    await _telemetrySub?.cancel();
    await _metricsSub?.cancel();
    await _remoteSub?.cancel();
    await _classificationController.close();
    await _telemetryController.close();
    await _metricsController.close();
    await _sseClient.dispose();
    _syntheticTimer?.cancel();
  }
}
