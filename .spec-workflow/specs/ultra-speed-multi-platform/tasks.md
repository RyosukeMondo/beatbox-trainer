# Tasks Document: Ultra-Speed Multi-Platform Support

## Phase 1: CPAL Audio Engine Implementation

- [x] 1.1. Create cpal engine module structure
  - File: `rust/src/audio/engine_cpal.rs`
  - Create `AudioEngine` struct mirroring the Oboe implementation fields (frame_counter, bpm, etc.)
  - Implement `new()` method initializing `cpal` host and devices

- [x] 1.2. Implement cpal audio callbacks
  - File: `rust/src/audio/engine_cpal.rs`
  - Implement input and output stream building with callbacks
  - Port metronome generation logic to cpal output callback
  - Port input capture logic to cpal input callback

- [x] 1.3. Implement start/stop and lifecycle methods
  - File: `rust/src/audio/engine_cpal.rs`
  - Implement `start()`, `stop()`, `set_bpm()`, `get_bpm()`, `get_frame_counter()`
  - Spawn analysis thread in `start()`

## Phase 2: Integration and Cleanup

- [x] 2.1. Expose cpal engine in module tree
  - File: `rust/src/audio/mod.rs`
  - Add `pub mod engine_cpal;` guarded by `#[cfg(not(target_os = "android"))]`

- [x] 2.2. Switch engine selection logic
  - File: `rust/src/audio/engine.rs`
  - Update conditional compilation to use `engine_cpal::AudioEngine` instead of `stubs::AudioEngine` for non-Android targets.

- [x] 2.3. Verify compilation on Linux
  - Run `cargo check` and `cargo test` on Linux environment.
