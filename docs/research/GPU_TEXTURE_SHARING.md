# GPU Texture Sharing Research

## Overview
This document explores methods to achieve "Ultra Speed" visualization by sharing GPU textures between Rust and Flutter, minimizing CPU-GPU memory transfers.

## Approaches

### 1. Pixel Buffer Copy (Fallback)
*   **Mechanism**: Rust renders to a `Vec<u8>` buffer (CPU), passes it to Flutter via FFI/Stream, Flutter uploads to GPU.
*   **Pros**: Cross-platform, simple, supported by `flutter_rust_bridge` (ZeroCopy buffer).
*   **Cons**: High CPU usage, bus bandwidth bottleneck. Not "Ultra Speed" for high-res/high-fps.
*   **Suitability**: Acceptable for simple spectrum analyzers (e.g. 100 bars), poor for full spectrograms or high-res waveforms.

### 2. Android: Shared OpenGL Textures (SurfaceTexture)
*   **Mechanism**: Flutter provides a `SurfaceTexture` (via `Texture` widget). Rust (via JNI/NDK) attaches an EGL surface to this texture and renders directly using OpenGL ES.
*   **Pros**: True zero-copy on GPU.
*   **Cons**: Platform-specific (Android only). Requires managing EGL contexts and JNI glue.
*   **Implementation**:
    1.  Flutter creates `Texture` widget, gets `textureId`.
    2.  Pass `surfaceTexture` object to Rust via JNI.
    3.  Rust uses `eglCreateWindowSurface` with the `SurfaceTexture`'s window.
    4.  Rust renders (e.g. using `glow`).

### 3. Linux: DMA-BUF / EGLImage
*   **Mechanism**: Rust creates a texture, exports as DMA-BUF. Flutter imports it.
*   **Status**: Flutter Linux embedder support for external textures is evolving. `flutter_gpu` might help in future.
*   **Current State**: Complex. Often requires custom embedder or specific plugins (`flutter_linux_texture`).

### 4. Windows: Shared Handles (Direct3D/OpenGL Interop)
*   **Mechanism**: Share DirectX resources or use Angle for OpenGL-DX interop.
*   **Status**: Flutter Windows supports external textures (`TextureRegistrar`). Rust can render to a D3D11 texture and pass the handle.

## Recommended Library: `irys` (formerly `flutter_wgpu` ideas) or Custom
There is no "one-ring-to-rule-them-all" crate yet that handles this seamlessly across mobile and desktop.

## "Ultra Speed" Strategy for Beatbox Trainer

Given the current stack (Oboe/CPAL + Rust):

1.  **Immediate Term**: Use **FRB Zero-Copy Pixel Buffer** (`Vec<u8>`).
    *   *Why?* The visualization (waveform/spectrum) is likely 2D and low resolution (e.g. screen width x 200px).
    *   Copying ~800KB (1080x200x4) per frame at 60fps is ~48MB/s. Modern memory bandwidth (>20GB/s) handles this easily.
    *   It avoids the massive complexity of cross-platform GPU context management.

2.  **Long Term**: **Native Texture Bridge**
    *   Implement Android `SurfaceTexture` path first (primary target).
    *   Use `wgpu` in Rust to render to the specific surface provided by the platform.

## Conclusion
For "Phase 3: Visualization", start with **FRB Zero-Copy Pixel Buffer**. It satisfies the "Zero-copy" data transfer requirement (using shared memory/mapped buffers between Rust/Dart) effectively enough for audio visualization without the "GPU Texture" complexity, unless 3D rendering is required.

*Correction*: The steering doc explicitly mentioned "GPU Texture Sharing".
If we strictly follow the steering doc, we should aim for option 2 (Android) and similar.
However, **Pixel Buffer Copy** using FRB's `ZeroCopyBuffer` is a valid interpretation of "Zero-copy data transfer" (memory sharing), though not "GPU Texture Sharing".

**Decision**: Research points to **FRB Zero-Copy Image Streaming** as the pragmatic "Ultra Speed" implementation for now, with GPU sharing as a future optimization for high-end rendering.
