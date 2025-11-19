import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../bridge/api.dart/api/diagnostics.dart' as diagnostics_api;
import '../../../bridge/api.dart/testing/fixtures.dart';
import '../../../models/classification_result.dart';
import '../../../services/audio/i_audio_service.dart';
import '../../../services/audio/telemetry_stream.dart';
import 'harness_audio_source.dart';

/// Abstraction for starting/stopping fixture sessions via flutter_rust_bridge.
abstract class FixtureSessionClient {
  Future<void> start(HarnessFixtureRequest request);

  Future<void> stop();
}

/// Builder that converts a Dart [HarnessFixtureRequest] into a Rust [FixtureSpec].
typedef FixtureSpecFactory =
    Future<FixtureSpec> Function(HarnessFixtureRequest request);

/// FRB-backed client that issues start/stop commands through the generated API.
class FrbFixtureSessionClient implements FixtureSessionClient {
  const FrbFixtureSessionClient({required FixtureSpecFactory specFactory})
    : _specFactory = specFactory;

  final FixtureSpecFactory _specFactory;

  @override
  Future<void> start(HarnessFixtureRequest request) async {
    final spec = await _specFactory(request);
    await diagnostics_api.startFixtureSession(spec: spec);
  }

  @override
  Future<void> stop() async {
    await diagnostics_api.stopFixtureSession();
  }
}

/// No-op client used in unit tests when the harness is mocked.
class NoopFixtureSessionClient implements FixtureSessionClient {
  const NoopFixtureSessionClient();

  @override
  Future<void> start(HarnessFixtureRequest request) async {}

  @override
  Future<void> stop() async {}
}

/// Controller that exposes classification/diagnostic streams for harness tests.
///
/// This orchestrates fixture sessions (via [FixtureSessionClient]) and surfaces
/// broadcast streams derived from [IAudioService].
class DiagnosticsController {
  DiagnosticsController({
    required IAudioService audioService,
    FixtureSessionClient? fixtureSessionClient,
  }) : _audioService = audioService,
       _fixtureSessionClient =
           fixtureSessionClient ?? const NoopFixtureSessionClient();

  final IAudioService _audioService;
  final FixtureSessionClient _fixtureSessionClient;

  final ValueNotifier<bool> isFixtureSessionActive = ValueNotifier(false);
  final ValueNotifier<HarnessAudioSource?> selectedSource = ValueNotifier(null);

  Stream<ClassificationResult>? _classificationStream;
  Stream<DiagnosticMetric>? _diagnosticMetricsStream;

  /// Broadcast classification stream for widget/controller tests.
  Stream<ClassificationResult> get classificationStream {
    return _classificationStream ??= _audioService
        .getClassificationStream()
        .asBroadcastStream();
  }

  /// Broadcast diagnostic metric stream aggregated by the Rust telemetry layer.
  Stream<DiagnosticMetric> get diagnosticMetricsStream {
    return _diagnosticMetricsStream ??= _audioService
        .getDiagnosticMetricsStream()
        .asBroadcastStream();
  }

  /// Start a harness source, delegating to the FRB fixture session when needed.
  Future<void> startFixtureSession(HarnessAudioSource source) async {
    selectedSource.value = source;

    if (!source.requiresFixtureSession) {
      isFixtureSessionActive.value = false;
      return;
    }

    await _fixtureSessionClient.start(source.toRequest());
    isFixtureSessionActive.value = true;
  }

  /// Stop the currently running fixture session (if any).
  Future<void> stopFixtureSession() async {
    if (!isFixtureSessionActive.value) {
      return;
    }

    await _fixtureSessionClient.stop();
    isFixtureSessionActive.value = false;
  }

  /// Dispose notifiers when the controller is no longer needed.
  void dispose() {
    selectedSource.dispose();
    isFixtureSessionActive.dispose();
  }
}
