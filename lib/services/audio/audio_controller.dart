import '../../models/classification_result.dart';
import 'i_audio_service.dart';
import 'telemetry_stream.dart';
import 'test_harness/diagnostics_controller.dart';
import 'test_harness/harness_audio_source.dart';

/// High-level orchestrator for audio workflows with optional diagnostics harness.
class AudioController {
  AudioController({
    required IAudioService audioService,
    DiagnosticsController? diagnosticsController,
  }) : _audioService = audioService,
       _diagnosticsController = diagnosticsController;

  final IAudioService _audioService;
  final DiagnosticsController? _diagnosticsController;
  HarnessAudioSource? _harnessAudioSource;

  /// Harness fixture used for diagnostics runs (if any).
  HarnessAudioSource? get harnessAudioSource => _harnessAudioSource;

  /// Update the harness fixture declaration.
  set harnessAudioSource(HarnessAudioSource? source) {
    if (identical(_harnessAudioSource, source)) {
      return;
    }
    _harnessAudioSource = source;
  }

  /// Stream of classification results resilient to harness swaps.
  Stream<ClassificationResult> get classificationStream {
    return _diagnosticsController?.classificationStream ??
        _audioService.getClassificationStream();
  }

  /// Stream of diagnostic metrics regardless of harness usage.
  Stream<DiagnosticMetric> get diagnosticMetricsStream {
    return _diagnosticsController?.diagnosticMetricsStream ??
        _audioService.getDiagnosticMetricsStream();
  }

  /// Start audio playback (fixture session if harness requires it).
  Future<void> start({required int bpm}) async {
    final harness = _harnessAudioSource;
    if (harness != null && harness.requiresFixtureSession) {
      final diagnostics = _diagnosticsController;
      if (diagnostics == null) {
        throw StateError(
          'DiagnosticsController required when using fixture harnesses.',
        );
      }
      await diagnostics.startFixtureSession(harness);
      return;
    }

    await _audioService.startAudio(bpm: bpm);
  }

  /// Stop playback and tear down any running fixture session.
  Future<void> stop() async {
    final diagnostics = _diagnosticsController;
    if (diagnostics != null && diagnostics.isFixtureSessionActive.value) {
      await diagnostics.stopFixtureSession();
    }

    await _audioService.stopAudio();
  }

  /// Convenience setter for swapping back to live microphone.
  void clearHarness() {
    _harnessAudioSource = null;
  }
}
