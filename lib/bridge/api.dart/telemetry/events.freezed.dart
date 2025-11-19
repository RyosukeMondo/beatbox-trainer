// Minimal stand-in for Freezed output so we can compile without running build_runner.

part of 'events.dart';

mixin _$MetricEvent {
  T map<T>({
    required T Function(MetricEvent_Latency value) latency,
    required T Function(MetricEvent_BufferOccupancy value) bufferOccupancy,
    required T Function(MetricEvent_Classification value) classification,
    required T Function(MetricEvent_JniLifecycle value) jniLifecycle,
    required T Function(MetricEvent_Error value) error,
  });
}

class MetricEvent_Latency extends MetricEvent {
  const MetricEvent_Latency({
    required this.avgMs,
    required this.maxMs,
    required this.sampleCount,
  }) : super._();

  final double avgMs;
  final double maxMs;
  final BigInt sampleCount;

  @override
  T map<T>({
    required T Function(MetricEvent_Latency value) latency,
    required T Function(MetricEvent_BufferOccupancy value) bufferOccupancy,
    required T Function(MetricEvent_Classification value) classification,
    required T Function(MetricEvent_JniLifecycle value) jniLifecycle,
    required T Function(MetricEvent_Error value) error,
  }) {
    return latency(this);
  }

  @override
  String toString() =>
      'MetricEvent.latency(avgMs: $avgMs, maxMs: $maxMs, sampleCount: $sampleCount)';

  @override
  int get hashCode => Object.hash(runtimeType, avgMs, maxMs, sampleCount);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MetricEvent_Latency &&
            other.avgMs == avgMs &&
            other.maxMs == maxMs &&
            other.sampleCount == sampleCount);
  }
}

class MetricEvent_BufferOccupancy extends MetricEvent {
  const MetricEvent_BufferOccupancy({
    required this.channel,
    required this.percent,
  }) : super._();

  final String channel;
  final double percent;

  @override
  T map<T>({
    required T Function(MetricEvent_Latency value) latency,
    required T Function(MetricEvent_BufferOccupancy value) bufferOccupancy,
    required T Function(MetricEvent_Classification value) classification,
    required T Function(MetricEvent_JniLifecycle value) jniLifecycle,
    required T Function(MetricEvent_Error value) error,
  }) {
    return bufferOccupancy(this);
  }

  @override
  String toString() =>
      'MetricEvent.bufferOccupancy(channel: $channel, percent: $percent)';

  @override
  int get hashCode => Object.hash(runtimeType, channel, percent);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MetricEvent_BufferOccupancy &&
            other.channel == channel &&
            other.percent == percent);
  }
}

class MetricEvent_Classification extends MetricEvent {
  const MetricEvent_Classification({
    required this.sound,
    required this.confidence,
    required this.timingErrorMs,
  }) : super._();

  final BeatboxHit sound;
  final double confidence;
  final double timingErrorMs;

  @override
  T map<T>({
    required T Function(MetricEvent_Latency value) latency,
    required T Function(MetricEvent_BufferOccupancy value) bufferOccupancy,
    required T Function(MetricEvent_Classification value) classification,
    required T Function(MetricEvent_JniLifecycle value) jniLifecycle,
    required T Function(MetricEvent_Error value) error,
  }) {
    return classification(this);
  }

  @override
  String toString() =>
      'MetricEvent.classification(sound: $sound, confidence: $confidence, timingErrorMs: $timingErrorMs)';

  @override
  int get hashCode =>
      Object.hash(runtimeType, sound, confidence, timingErrorMs);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MetricEvent_Classification &&
            other.sound == sound &&
            other.confidence == confidence &&
            other.timingErrorMs == timingErrorMs);
  }
}

class MetricEvent_JniLifecycle extends MetricEvent {
  const MetricEvent_JniLifecycle({
    required this.phase,
    required this.timestampMs,
  }) : super._();

  final LifecyclePhase phase;
  final BigInt timestampMs;

  @override
  T map<T>({
    required T Function(MetricEvent_Latency value) latency,
    required T Function(MetricEvent_BufferOccupancy value) bufferOccupancy,
    required T Function(MetricEvent_Classification value) classification,
    required T Function(MetricEvent_JniLifecycle value) jniLifecycle,
    required T Function(MetricEvent_Error value) error,
  }) {
    return jniLifecycle(this);
  }

  @override
  String toString() =>
      'MetricEvent.jniLifecycle(phase: $phase, timestampMs: $timestampMs)';

  @override
  int get hashCode => Object.hash(runtimeType, phase, timestampMs);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MetricEvent_JniLifecycle &&
            other.phase == phase &&
            other.timestampMs == timestampMs);
  }
}

class MetricEvent_Error extends MetricEvent {
  const MetricEvent_Error({required this.code, required this.context})
    : super._();

  final DiagnosticError code;
  final String context;

  @override
  T map<T>({
    required T Function(MetricEvent_Latency value) latency,
    required T Function(MetricEvent_BufferOccupancy value) bufferOccupancy,
    required T Function(MetricEvent_Classification value) classification,
    required T Function(MetricEvent_JniLifecycle value) jniLifecycle,
    required T Function(MetricEvent_Error value) error,
  }) {
    return error(this);
  }

  @override
  String toString() => 'MetricEvent.error(code: $code, context: $context)';

  @override
  int get hashCode => Object.hash(runtimeType, code, context);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MetricEvent_Error &&
            other.code == code &&
            other.context == context);
  }
}
