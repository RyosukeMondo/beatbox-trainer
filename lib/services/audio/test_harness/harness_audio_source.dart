/// Declarative description of a diagnostics harness fixture.
///
/// This description can be converted into a Rust [`FixtureSpec`] via an
/// injected builder (see [HarnessFixtureRequest]) so the FRB bridge can start a
/// deterministic PCM session without live hardware.
abstract class HarnessAudioSource {
  const HarnessAudioSource({
    required this.id,
    this.sampleRate = 48_000,
    this.channels = 1,
    this.duration = const Duration(seconds: 1),
    this.loopCount = 1,
    this.metadata = const {},
  });

  /// Identifier surfaced in telemetry/logs.
  final String id;

  /// Fixture sample rate (defaults to engine sample rate).
  final int sampleRate;

  /// Number of channels to feed into the DSP pipeline.
  final int channels;

  /// Length of a single loop iteration.
  final Duration duration;

  /// Number of times the source should repeat.
  final int loopCount;

  /// Optional metadata forwarded to the Rust harness.
  final Map<String, String> metadata;

  /// Whether this source requires a Rust fixture session instead of the live mic.
  bool get requiresFixtureSession;

  /// Convert the declaration into a serializable request.
  HarnessFixtureRequest toRequest();
}

/// Microphone passthrough that exercises the harness plumbing without fixtures.
class MicrophoneProxyHarnessAudioSource extends HarnessAudioSource {
  const MicrophoneProxyHarnessAudioSource({
    super.id = 'microphone_proxy',
    super.duration,
    super.loopCount,
    super.metadata,
  });

  @override
  bool get requiresFixtureSession => false;

  @override
  HarnessFixtureRequest toRequest() {
    return HarnessFixtureRequest(
      id: id,
      sampleRate: sampleRate,
      channels: channels,
      durationMs: duration.inMilliseconds,
      loopCount: loopCount,
      metadata: metadata,
      source: const MicrophoneProxySourceDescriptor(),
    );
  }
}

/// Fixture that streams PCM from an on-disk WAV file.
class FixtureFileHarnessAudioSource extends HarnessAudioSource {
  const FixtureFileHarnessAudioSource({
    required this.path,
    super.id = 'fixture_file',
    super.sampleRate = 48_000,
    super.channels = 1,
    super.duration = const Duration(seconds: 1),
    super.loopCount = 1,
    super.metadata = const {},
  });

  /// Absolute or relative path to the WAV asset.
  final String path;

  @override
  bool get requiresFixtureSession => true;

  @override
  HarnessFixtureRequest toRequest() {
    return HarnessFixtureRequest(
      id: id,
      sampleRate: sampleRate,
      channels: channels,
      durationMs: duration.inMilliseconds,
      loopCount: loopCount,
      metadata: metadata,
      source: FixtureFileSourceDescriptor(path),
    );
  }
}

/// Deterministic synthetic source mirroring the Rust [SyntheticPattern].
class SyntheticPatternHarnessAudioSource extends HarnessAudioSource {
  const SyntheticPatternHarnessAudioSource({
    required this.pattern,
    this.frequencyHz = 220.0,
    this.amplitude = 0.8,
    super.id = 'synthetic_pattern',
    super.sampleRate = 48_000,
    super.channels = 1,
    super.duration = const Duration(seconds: 1),
    super.loopCount = 1,
    super.metadata = const {},
  });

  final SyntheticFixturePattern pattern;
  final double frequencyHz;
  final double amplitude;

  @override
  bool get requiresFixtureSession => true;

  @override
  HarnessFixtureRequest toRequest() {
    return HarnessFixtureRequest(
      id: id,
      sampleRate: sampleRate,
      channels: channels,
      durationMs: duration.inMilliseconds,
      loopCount: loopCount,
      metadata: metadata,
      source: SyntheticSourceDescriptor(
        pattern: pattern,
        frequencyHz: frequencyHz,
        amplitude: amplitude,
      ),
    );
  }
}

/// Enumeration of the synthetic fixture patterns supported by Rust.
enum SyntheticFixturePattern { sine, square, whiteNoise, impulseTrain }

/// Serializable request forwarded to the FRB fixture builder.
class HarnessFixtureRequest {
  const HarnessFixtureRequest({
    required this.id,
    required this.sampleRate,
    required this.channels,
    required this.durationMs,
    required this.loopCount,
    required this.metadata,
    required this.source,
  });

  final String id;
  final int sampleRate;
  final int channels;
  final int durationMs;
  final int loopCount;
  final Map<String, String> metadata;
  final HarnessFixtureSourceDescriptor source;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'sample_rate': sampleRate,
      'channels': channels,
      'duration_ms': durationMs,
      'loop_count': loopCount,
      'metadata': metadata,
      'source': source.toJson(),
    };
  }
}

/// Kinds of fixture sources accepted by the Rust harness.
enum HarnessFixtureSourceKind {
  microphoneProxy('microphone_passthrough'),
  fixtureFile('wav_file'),
  synthetic('synthetic');

  const HarnessFixtureSourceKind(this.serialized);

  final String serialized;
}

/// Base descriptor for fixture sources.
abstract class HarnessFixtureSourceDescriptor {
  const HarnessFixtureSourceDescriptor(this.kind);

  final HarnessFixtureSourceKind kind;

  Map<String, Object?> toJson();
}

/// Descriptor for microphone passthrough.
class MicrophoneProxySourceDescriptor extends HarnessFixtureSourceDescriptor {
  const MicrophoneProxySourceDescriptor()
    : super(HarnessFixtureSourceKind.microphoneProxy);

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'kind': kind.serialized};
  }
}

/// Descriptor for WAV-backed fixtures.
class FixtureFileSourceDescriptor extends HarnessFixtureSourceDescriptor {
  const FixtureFileSourceDescriptor(this.path)
    : super(HarnessFixtureSourceKind.fixtureFile);

  final String path;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'kind': kind.serialized, 'path': path};
  }
}

/// Descriptor for deterministic synthetic fixtures.
class SyntheticSourceDescriptor extends HarnessFixtureSourceDescriptor {
  const SyntheticSourceDescriptor({
    required this.pattern,
    required this.frequencyHz,
    required this.amplitude,
  }) : super(HarnessFixtureSourceKind.synthetic);

  final SyntheticFixturePattern pattern;
  final double frequencyHz;
  final double amplitude;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'kind': kind.serialized,
      'pattern': pattern.name,
      'frequency_hz': frequencyHz,
      'amplitude': amplitude,
    };
  }
}
