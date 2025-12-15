# Tasks Document: Ultra-Speed Multi-Platform Support

## Phase 1: CPAL Audio Engine Implementation

- [x] 1.1. Create cpal engine module structure
  - Status: completed
  - File: `rust/src/audio/engine_cpal.rs`
  - Create `AudioEngine` struct mirroring the Oboe implementation fields (frame_counter, bpm, etc.)
  - Implement `new()` method initializing `cpal` host and devices
  - _Leverage: `rust/src/audio/engine.rs` structure, `cpal` documentation_
  - _Requirements: Ultra-Speed Doc (Multi-platform support)_
  - _Prompt: Role: Rust audio developer | Task: Create `rust/src/audio/engine_cpal.rs` and define the `AudioEngine` struct to match the fields in `rust/src/audio/engine.rs` (Oboe impl), but using `cpal::Stream` instead of Oboe streams. Implement `new(bpm, sample_rate, buffer_channels)` that initializes the default host and input/output devices using `cpal`. Ensure all atomic fields (frame_counter, bpm) and Arc shared structures are present. | Restrictions: Must use `cpal` crate, struct fields must be compatible with existing public API usage, do not implement start/stop yet._

- [x] 1.2. Implement cpal audio callbacks
  - Status: completed
  - File: `rust/src/audio/engine_cpal.rs`
  - Implement input and output stream building with callbacks
  - Port metronome generation logic to cpal output callback
  - Port input capture logic to cpal input callback
  - _Leverage: `rust/src/audio/callback.rs` (Oboe callback logic), `rust/src/audio/metronome.rs`_
  - _Requirements: Ultra-Speed Doc (Real-time safety)_
  - _Prompt: Role: Real-time audio engineer | Task: Implement `create_input_stream` and `create_output_stream` in `rust/src/audio/engine_cpal.rs`. The output callback must generate metronome clicks (using `generate_click_sample` logic adapted for cpal's buffer format) and manage `frame_counter`. The input callback must push data to `buffer_channels`. Note that cpal usually has separate threads for input/output, unlike Oboe's full-duplex callback. Use a ring buffer or similar mechanism if synchronization is needed, or simpler: just capture input and play output independently but synced via shared atomics. Ensure no allocations in callbacks. | Restrictions: Must handle `cpal::SampleFormat` (F32), handle device errors._

- [x] 1.3. Implement start/stop and lifecycle methods
  - Status: completed
  - File: `rust/src/audio/engine_cpal.rs`
  - Implement `start()`, `stop()`, `set_bpm()`, `get_bpm()`, `get_frame_counter()`
  - Spawn analysis thread in `start()`
  - _Leverage: `rust/src/audio/engine.rs` logic_
  - _Requirements: Ultra-Speed Doc_
  - _Prompt: Role: Rust systems engineer | Task: Implement `start`, `stop`, `set_bpm`, `get_bpm` methods in `rust/src/audio/engine_cpal.rs`. `start` must build streams, play them, and spawn the analysis thread using `spawn_analysis_thread_internal` logic (adapted from engine.rs). `stop` must pause/drop streams. | Restrictions: Must match public API signature of Oboe engine._

## Phase 2: Integration and Cleanup

- [x] 2.1. Expose cpal engine in module tree
  - Status: completed
  - File: `rust/src/audio/mod.rs`
  - Add `pub mod engine_cpal;` guarded by `#[cfg(not(target_os = "android"))]`
  - _Prompt: Role: Rust developer | Task: Update `rust/src/audio/mod.rs` to expose `engine_cpal` module when target is NOT android._

- [x] 2.2. Switch engine selection logic
  - Status: completed
  - File: `rust/src/audio/engine.rs`
  - Update conditional compilation to use `engine_cpal::AudioEngine` instead of `stubs::AudioEngine` for non-Android targets.
  - _Prompt: Role: Rust developer | Task: Modify `rust/src/audio/engine.rs` to alias `PlatformAudioEngine` and `AudioEngine` to `crate::audio::engine_cpal::AudioEngine` when `not(target_os = "android")`. Remove or cfg-gate the stub usage._

- [x] 2.3. Verify compilation on Linux
  - Status: completed
  - Run `cargo check` and `cargo test` on Linux environment.
  - _Prompt: Role: QA | Task: Run `cargo check` and `cargo test` in `rust/` directory to ensure cpal engine compiles and passes tests on Linux._