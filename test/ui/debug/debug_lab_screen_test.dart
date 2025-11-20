@Tags(['slow'])
import 'dart:async';

import 'package:beatbox_trainer/bridge/api.dart/testing/fixture_manifest.dart';
import 'package:beatbox_trainer/controllers/debug/debug_lab_controller.dart';
import 'package:beatbox_trainer/models/calibration_progress.dart';
import 'package:beatbox_trainer/models/classification_result.dart';
import 'package:beatbox_trainer/models/debug/fixture_anomaly_notice.dart';
import 'package:beatbox_trainer/models/telemetry_event.dart';
import 'package:beatbox_trainer/services/audio/i_audio_service.dart';
import 'package:beatbox_trainer/services/audio/telemetry_stream.dart';
import 'package:beatbox_trainer/services/debug/i_debug_service.dart';
import 'package:beatbox_trainer/services/debug/i_log_exporter.dart';
import 'package:beatbox_trainer/services/debug/fixture_metadata_service.dart';
import 'package:beatbox_trainer/ui/screens/debug_lab_screen.dart';
import 'package:beatbox_trainer/ui/widgets/debug/anomaly_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final harness = _DebugLabScreenTestHarness();
  group('DebugLabScreen anomaly banner', () {
    setUp(harness.setUp);
    tearDown(harness.tearDown);
    testWidgets(
      'hides anomaly banner when no notice available',
      harness.showsNoBanner,
    );
    testWidgets(
      'renders and dismisses anomaly banner',
      harness.showsAndDismissesNotice,
    );
  });
}

class _DebugLabScreenTestHarness {
  late _HarnessDebugLabController controller;
  late _FakeLogExporter exporter;

  void setUp() {
    controller = _HarnessDebugLabController();
    exporter = _FakeLogExporter();
  }

  Future<void> tearDown() async {
    await controller.dispose();
  }

  Future<void> _pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DebugLabScreen.test(
          controller: controller,
          logExporter: exporter,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> showsNoBanner(WidgetTester tester) async {
    await _pump(tester);
    expect(find.byType(DebugAnomalyBanner), findsNothing);
  }

  Future<void> showsAndDismissesNotice(WidgetTester tester) async {
    await _pump(tester);
    controller.fixtureAnomaly.value = FixtureAnomalyNotice(
      fixtureId: 'basic_hits',
      messages: const ['BPM drift exceeded tolerance'],
      logPath: '/tmp/anomalies.log',
      timestamp: DateTime(2025),
    );
    await tester.pump();

    expect(find.byType(DebugAnomalyBanner), findsOneWidget);
    expect(find.textContaining('basic_hits'), findsOneWidget);
    expect(find.textContaining('BPM drift exceeded tolerance'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(find.byType(DebugAnomalyBanner), findsNothing);
    expect(controller.fixtureAnomaly.value, isNull);
  }
}

class _HarnessDebugLabController extends DebugLabController {
  _HarnessDebugLabController()
    : super(
        audioService: _NoopAudioService(),
        debugService: _NoopDebugService(),
        fixtureMetadataService: _NoopFixtureMetadataService(),
        anomalyLogPath: 'logs/smoke/test_anomalies.log',
      );

  @override
  Future<void> init() async {
    // Skip wiring streams during widget tests.
  }
}

class _NoopAudioService implements IAudioService {
  final StreamController<ClassificationResult> _classificationController =
      StreamController.broadcast();
  final StreamController<TelemetryEvent> _telemetryController =
      StreamController.broadcast();
  final StreamController<DiagnosticMetric> _diagnosticController =
      StreamController.broadcast();

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

  @override
  Future<void> finishCalibration() => Future.value();

  @override
  Stream<CalibrationProgress> getCalibrationStream() => const Stream.empty();

  @override
  Future<void> setBpm({required int bpm}) => Future.value();

  @override
  Future<void> startAudio({required int bpm}) => Future.value();

  @override
  Future<void> startCalibration() => Future.value();

  @override
  Future<void> stopAudio() => Future.value();
}

class _NoopDebugService implements IDebugService {
  @override
  Stream<AudioMetrics> getAudioMetricsStream() => const Stream.empty();

  @override
  Stream<OnsetEvent> getOnsetEventsStream() => const Stream.empty();
}

class _NoopFixtureMetadataService implements IFixtureMetadataService {
  @override
  bool get hasCache => false;

  @override
  Future<List<FixtureManifestEntry>> loadCatalog({
    bool forceRefresh = false,
  }) async => <FixtureManifestEntry>[];

  @override
  Future<FixtureManifestEntry?> loadById(
    String id, {
    bool forceRefresh = false,
  }) async => null;
}

class _FakeLogExporter implements ILogExporter {
  @override
  Future<LogExportResult> exportLogs(LogExportRequest request) async {
    return const LogExportResult(
      zipPath: '/tmp/debug_lab.zip',
      cliNotesPath: '/tmp/debug_lab_cli.txt',
    );
  }
}
