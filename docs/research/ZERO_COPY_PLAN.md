# Zero-Copy Optimization Plan

## Current State Analysis
*   **Data Streams**: The application currently streams `ClassificationResult`, `AudioMetrics`, `TelemetryEvent`, and `CalibrationProgress`.
*   **Payload Size**: All current payloads are lightweight structs containing primitive types (`f64`, `u64`, enums).
*   **Serialization**: Types derive `serde::Serialize`, and `flutter_rust_bridge` (FRB) v2 is used. FRB v2 typically uses `Sse` (Simple Serialization) or `Cst` (C-Struct) codecs. While `serde` is derived, FRB's efficient codec should be preferred over JSON serialization for high-frequency streams.

## Findings
1.  **No Bulk Data**: We are currently *not* streaming raw audio buffers (PCM data) to Dart. The analysis happens entirely in Rust, and only derived features/metrics are sent.
2.  **Low Overhead**: For the current feature set (metronome, classification, simple metrics), the current transfer mechanism is performant enough. Overhead is negligible compared to the 16ms (60fps) frame budget.

## Future Waveform Visualization
To support real-time waveform or spectrum visualization (e.g., drawing the raw audio wave or FFT buckets in Flutter), we would need to transfer `Vec<f32>` buffers (e.g., 1024 samples) at 60Hz or higher.

### Optimization Strategy
1.  **Avoid JSON**: Ensure audio buffers are never serialized to JSON strings.
2.  **FRB Zero-Copy**: Use `flutter_rust_bridge`'s native support for `Vec<f32>`.
    *   In FRB v2, returning `Vec<f32>` or `Float32List` (in Dart) usually invokes an efficient memory copy or direct buffer mapping depending on the backend.
    *   Avoid wrapping in complex structs if possible for the hot path.
3.  **Shared Memory (Advanced)**: For extreme cases, allocate a circular buffer in shared memory (Rust write, Dart read via FFI pointer), but this introduces synchronization complexity (atomics/fences across languages).
    *   *Recommendation*: Stick to FRB stream with `Vec<f32>` first. Benchmarks suggest FRB handles ~100MB/s throughput easily, which is far above audio requirements (48kHz * 4 bytes = ~192KB/s).

## Action Plan
1.  **Monitor**: Keep using current architecture.
2.  **Trigger**: When "Waveform Visualization" feature is started.
3.  **Implement**: Add `audio_waveform_stream` to `api.rs` yielding `Vec<f32>`.
4.  **Verify**: Profile the UI thread impact when receiving these buffers.

## Conclusion
Zero-copy optimization is **not currently required** for the shipped features. The architecture is "Ultra Speed" compatible by design (processing in Rust, minimal data to Dart).
