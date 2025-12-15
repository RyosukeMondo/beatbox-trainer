# Fundsp vs Custom DSP Analysis

## Overview
This document evaluates the `fundsp` crate as a potential replacement or augmentation for the current DSP stack (`rustfft` + custom logic) in the Beatbox Trainer "Ultra Speed" architecture.

## Comparison

### 1. Analysis Capabilities
*   **Current (`rustfft`)**: The core of Beatbox Trainer is *spectral analysis* (onset detection, feature extraction). `rustfft` provides industry-standard FFT implementation which is essential for computing spectral centroid, flatness, and rolloff.
*   **Fundsp**: Primarily a *synthesis* library (functional DSP graph). While it has some analysis nodes, it is not optimized for windowed STFT feature extraction. Replicating the current multi-resolution analysis pipeline (256-sample onset, 1024-sample features) would be non-trivial and likely less efficient than direct buffer manipulation.

### 2. Synthesis (Metronome)
*   **Current**: Pre-generated 20ms buffers (white noise/sine). Zero allocation during playback, extremely simple.
*   **Fundsp**: Capable of generating complex synthesized sounds (envelopes, filtered noise, oscillators) in real-time.
    *   *Pros*: Could allow for "musical" metronomes, dynamic pitch accents, or procedural beat generation.
    *   *Cons*: Introduces graph overhead for what is currently a `memcpy`.

### 3. Architecture Fit
*   **Data Flow**: The current architecture is "Block Processing" (chunks of audio). `fundsp` operates sample-by-sample (or block-by-block with wrappers).
*   **Integration**: Integrating `fundsp` into the `cpal`/`oboe` callback is straightforward for output, but replacing the input analysis pipeline would be a regression in clarity and control.

## Conclusion & Recommendation
**Do not replace the analysis pipeline with fundsp.** The current `rustfft`-based approach is optimal for the feature extraction requirements.

**Consider fundsp for future features:**
1.  **Metronome Enhancements**: If we need customizable metronome sounds (pitch, timbre controls), `fundsp` is a better choice than managing a library of WAV files.
2.  **Practice Tracks**: Generating backing tracks or drone notes.

For the current "Ultra Speed" scope, adding `fundsp` adds dependency weight without immediate performance benefit for the core *analysis* loop.

**Decision**: Defer `fundsp` adoption until synthesis features are required. Stick to `rustfft` + lock-free buffers for analysis.
