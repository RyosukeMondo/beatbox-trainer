import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/classification_result.dart';
import '../../models/debug/fixture_anomaly_notice.dart';
import '../../models/debug_log_entry.dart';
import '../../models/telemetry_event.dart';
import '../../models/timing_feedback.dart';
import '../../services/audio/i_audio_service.dart';
import '../../services/debug/debug_sse_client.dart';
import '../../services/debug/fixture_metadata_service.dart';
import '../../services/debug/i_debug_service.dart';
import 'fixture_validation_tracker.dart';

/// Controller orchestrating Debug Lab streams and commands.
class DebugLabController {
  DebugLabController({
    required IAudioService audioService,
    required IDebugService debugService,
    required IFixtureMetadataService fixtureMetadataService,
    DebugSseClient? sseClient,
    Duration syntheticInterval = const Duration(seconds: 2),
    String anomalyLogPath = _defaultAnomalyLogPath,
  }) : _audioService = audioService,
       _debugService = debugService,
       _fixtureMetadataService = fixtureMetadataService,
       _sseClient = sseClient ?? DebugSseClient(),
       _syntheticInterval = syntheticInterval,
       _anomalyLogFile = File(anomalyLogPath);

  static const String _defaultAnomalyLogPath =
      'logs/smoke/debug_lab_anomalies.log';

  final IAudioService _audioService;
  final IDebugService _debugService;
  final IFixtureMetadataService _fixtureMetadataService;
  final DebugSseClient _sseClient;
  final Duration _syntheticInterval;
  final File _anomalyLogFile;

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
  final ValueNotifier<FixtureAnomalyNotice?> fixtureAnomaly =
      ValueNotifier<FixtureAnomalyNotice?>(null);

  FixtureManifestEntry? _activeFixture;
  String? _activeFixtureId;
  FixtureValidationTracker? _validationTracker;
  bool _anomalyLogged = false;

  /// Initialize stream subscriptions.
  Future<void> init() async {
    _classificationSub = _audioService.getClassificationStream().listen(
      (result) {
        _classificationController.add(result);
        _pushLog(
          DebugLogEntry.forClassification(
            result,
            source: DebugLogSource.device,
          ),
        );
        _maybeTrackFixture(result);
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
      onError: (error) =>
          _pushLog(DebugLogEntry.error('Telemetry stream error', '$error')),
    );

    try {
      _metricsSub = _debugService.getAudioMetricsStream().listen(
        (metrics) {
          _metricsController.add(metrics);
        },
        onError: (error) =>
            _pushLog(DebugLogEntry.error('Metrics stream error', '$error')),
      );
    } catch (error) {
      _pushLog(DebugLogEntry.error('Metrics unavailable', '$error'));
    }
  }

  Stream<ClassificationResult> get classificationStream =>
      _classificationController.stream;

  Stream<TelemetryEvent> get telemetryStream => _telemetryController.stream;

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
            _pushLog(
              DebugLogEntry.forClassification(
                event,
                source: DebugLogSource.remote,
              ),
            );
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
      final hit =
          BeatboxHit.values[DateTime.now().millisecondsSinceEpoch %
              BeatboxHit.values.length];
      final synthetic = ClassificationResult(
        sound: hit,
        timing: TimingFeedback(
          classification:
              TimingClassification.values[DateTime.now().second %
                  TimingClassification.values.length],
          errorMs: (DateTime.now().millisecond % 120) - 60,
        ),
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        confidence: 0.5 + (DateTime.now().millisecond % 50) / 100,
      );
      _classificationController.add(synthetic);
      _pushLog(
        DebugLogEntry.forClassification(
          synthetic,
          source: DebugLogSource.synthetic,
        ),
      );
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
    fixtureAnomaly.dispose();
  }

  Future<void> setFixtureUnderTest(String? fixtureId) async {
    final normalized = fixtureId?.trim();
    _activeFixture = null;
    _activeFixtureId = normalized?.isEmpty ?? true ? null : normalized;
    _validationTracker = null;
    _anomalyLogged = false;
    fixtureAnomaly.value = null;

    if (_activeFixtureId == null) {
      return;
    }

    try {
      final entry = await _fixtureMetadataService.loadById(_activeFixtureId!);
      if (entry == null) {
        _pushLog(
          DebugLogEntry.error(
            'Fixture metadata unavailable',
            'No manifest entry for ${_activeFixtureId!}',
          ),
        );
        return;
      }
      _activeFixture = entry;
      _validationTracker = _FixtureValidationTracker();
      _pushLog(
        DebugLogEntry(
          timestamp: DateTime.now(),
          source: DebugLogSource.system,
          severity: DebugLogSeverity.info,
          title: 'Fixture validation armed',
          detail: entry.id,
        ),
      );
    } catch (error, stackTrace) {
      _pushLog(
        DebugLogEntry.error('Failed to load fixture metadata', '$error'),
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void dismissAnomalyNotice() {
    fixtureAnomaly.value = null;
  }

  void _maybeTrackFixture(ClassificationResult result) {
    final fixture = _activeFixture;
    if (fixture == null || _anomalyLogged) {
      return;
    }

    final tracker = _validationTracker ??= FixtureValidationTracker();
    tracker.record(result);
    final anomalies = tracker.evaluate(fixture);
    if (anomalies.isEmpty) {
      return;
    }

    _anomalyLogged = true;
    final stats = tracker.toStatsJson();
    final snapshots = anomalies.map((anomaly) => anomaly.toJson()).toList();
    _persistAnomaly(fixture.id, stats, snapshots)
        .then((logPath) {
          fixtureAnomaly.value = FixtureAnomalyNotice(
            fixtureId: fixture.id,
            messages: anomalies.map((a) => a.message).toList(),
            logPath: logPath,
            timestamp: DateTime.now(),
          );
        })
        .catchError((error, stackTrace) {
          _pushLog(DebugLogEntry.error('Failed to log anomaly', '$error'));
          debugPrintStack(stackTrace: stackTrace);
          fixtureAnomaly.value = FixtureAnomalyNotice(
            fixtureId: fixture.id,
            messages: anomalies.map((a) => a.message).toList(),
            logPath: _anomalyLogFile.path,
            timestamp: DateTime.now(),
          );
        });
  }

  Future<String> _persistAnomaly(
    String fixtureId,
    Map<String, dynamic> stats,
    List<Map<String, dynamic>> anomalies,
  ) async {
    final dir = _anomalyLogFile.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final payload = jsonEncode({
      'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
      'fixture_id': fixtureId,
      'source': 'debug-lab',
      'stats': stats,
      'anomalies': anomalies,
    });
    await _anomalyLogFile.writeAsString(
      '$payload\n',
      mode: FileMode.append,
      flush: true,
    );
    return _anomalyLogFile.path;
  }
}
