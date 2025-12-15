# Tasks Document: Ultra Speed Tech Stack Alignment

## Phase 1: Logging Migration (Tracing)

- [x] 1.1. Add tracing dependencies
  - File: `rust/Cargo.toml`
  - Add `tracing`, `tracing-subscriber`, and `tracing-android` (for Android) to dependencies.
  - Remove `log` and `android_logger` dependencies (eventually, or keep for compat layer).

- [x] 1.2. Configure tracing subscriber
  - File: `rust/src/lib.rs` (or `logging.rs`)
  - Implement a `setup_logging` function that initializes `tracing_subscriber`.
  - On Android, use `tracing_android` layer.
  - On Desktop, use `tracing_subscriber::fmt` layer.

- [x] 1.3. Replace log macros with tracing macros
  - File: `rust/src/**/*.rs`
  - Replace `info!`, `warn!`, `error!`, `debug!`, `trace!` from `log` crate with `tracing` equivalents.
  - Use structured logging fields where appropriate (e.g., `info!(count = 5, "Processed items")`).

## Phase 2: DSP Stack Evaluation (Fundsp)

- [x] 2.1. Investigate fundsp suitability
  - File: `docs/research/FUNDSP_ANALYSIS.md`
  - Create a research note comparing current `rustfft`/custom DSP with `fundsp`.
  - Check if `fundsp` offers better performance or expressiveness for the current feature set (filters, oscillators, etc.).
  - _Requirements: Ultra Speed Doc (Audio: cpal + fundsp)_
  - _Prompt: Role: DSP Engineer | Task: Analyze `fundsp` crate. Compare it with current custom DSP for metronome (white noise, sine) and analysis (FFT-based). Determine if migrating metronome generation to `fundsp` graph is beneficial for "Ultra Speed" goals (e.g., more precise envelope control, easier expansion). Write findings to `docs/research/FUNDSP_ANALYSIS.md`._

## Phase 3: Zero-Copy Optimization

- [x] 3.1. Analyze current data transfer
  - File: `rust/src/api.rs`
  - Review how `ClassificationResult` and audio buffers are passed to Dart.
  - Check if serialization overhead is significant.
  - See `docs/research/ZERO_COPY_PLAN.md` for details.
  - _Requirements: Ultra Speed Doc (Zero-Copy: Vec<f32> to Dart)_
  - _Prompt: Role: Performance Engineer | Task: Review `rust/src/api.rs` and `lib/bridge/api.dart`. Identify where large data (like audio buffers for visualization) might be serialized. The `ClassificationResult` is small, but if we add waveform visualization, we need zero-copy. Create a plan for zero-copy audio buffer streaming if visualization is on the roadmap._
