# Visualization Pipeline Architecture

## Overview
This document outlines the architecture for the "Ultra Speed" visualization pipeline, enabling high-performance audio visualization (waveforms, spectrograms) in the Beatbox Trainer app.

## Data Flow

```mermaid
graph TD
    A[Audio Thread] -->|Push Samples| B(RingBuffer / Lock-Free Queue)
    B --> C[Vis Thread (Rust)]
    C -->|Process (FFT/Decimate)| D[Render Buffer]
    D -->|Zero-Copy Stream| E[Flutter UI]
    E -->|CustomPainter| F[Canvas]
```

### 1. Audio Capture (Real-Time Thread)
*   **Source**: `AudioEngine` callback (Oboe/CPAL).
*   **Action**: Copy audio samples (mono, f32) into a lock-free Single-Producer Single-Consumer (SPSC) ring buffer.
*   **Constraint**: Zero allocation, non-blocking.

### 2. Processing (Visualization Thread)
*   **Component**: `VisualizationEngine` (Rust).
*   **Action**: Consumes samples from the ring buffer.
*   **Processing**:
    *   **Waveform**: Decimation (min/max per pixel window) or raw buffering.
    *   **Spectrum**: FFT (using `rustfft`) -> Magnitude -> Log/Mel scale.
*   **Output**: Writes to a shared `Vec<u8>` or `Vec<f32>` buffer ready for rendering.

### 3. Transport (FFI)
*   **Mechanism**: `flutter_rust_bridge` Stream with `ZeroCopyBuffer`.
*   **Latency**: Pushed at ~60Hz (16ms).

### 4. Rendering (Flutter)
*   **Component**: `WaveformWidget` / `SpectrumWidget`.
*   **Action**: Receives the buffer. Uses `CustomPainter` to draw points/lines directly from the float list.
    *   *Optimization*: Use `vertices` (drawVertices) for batch rendering.

## GPU Texture Path (Future / High-End)
For advanced visualizations (shadertoy-style), the "Render Buffer" step would perform drawing to an OpenGL/Vulkan texture, and the "Transport" step would pass a `TextureId`.

## Implementation Plan (Phase 2/3)
1.  Add `audio_waveform_stream` to `api.rs`.
2.  Implement `VisualizationManager` in Rust.
3.  Connect `AudioEngine` to `VisualizationManager` via `rtrb`.
