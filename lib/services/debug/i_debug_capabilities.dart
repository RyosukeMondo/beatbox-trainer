/// Capability flag for debug services that expose telemetry streams.
///
/// Implement this alongside [IDebugService] to signal whether real telemetry
/// streams are available. This allows the UI to hide debug affordances when
/// telemetry is stubbed out (e.g., before FFI streams are wired).
abstract class DebugTelemetryAvailability {
  /// Whether audio metrics/onset telemetry streams are available.
  bool get telemetryAvailable;
}
