part of 'core.dart';

mixin _$TelemetryEventKind {}

class TelemetryEventKind_EngineStarted extends TelemetryEventKind {
  const TelemetryEventKind_EngineStarted({required this.bpm}) : super._();

  final int bpm;

  @override
  int get hashCode => bpm.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TelemetryEventKind_EngineStarted && other.bpm == bpm;
}

class TelemetryEventKind_EngineStopped extends TelemetryEventKind {
  const TelemetryEventKind_EngineStopped() : super._();
}

class TelemetryEventKind_BpmChanged extends TelemetryEventKind {
  const TelemetryEventKind_BpmChanged({required this.bpm}) : super._();

  final int bpm;

  @override
  int get hashCode => bpm.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TelemetryEventKind_BpmChanged && other.bpm == bpm;
}

class TelemetryEventKind_Warning extends TelemetryEventKind {
  const TelemetryEventKind_Warning() : super._();
}
