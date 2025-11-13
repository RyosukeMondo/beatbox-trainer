# Android Build Setup Guide

This guide covers the complete setup and build process for the beatbox trainer application on Android, including native Rust library cross-compilation, packaging, and deployment.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Building for Android](#building-for-android)
4. [Architecture Details](#architecture-details)
5. [Troubleshooting](#troubleshooting)
6. [Development Workflow](#development-workflow)

## Prerequisites

### Required Tools

#### 1. Android NDK (r25c or newer)

The Android Native Development Kit (NDK) is required for cross-compiling Rust code to Android targets.

**Installation via Android Studio:**
1. Open Android Studio
2. Go to Tools → SDK Manager
3. Navigate to SDK Tools tab
4. Check "NDK (Side by side)" - version 25.2.9519653 or newer
5. Click Apply to download and install

**Verify installation:**
```bash
# Check NDK version
ls $ANDROID_HOME/ndk/

# Should output something like: 25.2.9519653
```

**Environment Setup:**
Add to your `~/.bashrc` or `~/.zshrc`:
```bash
export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/25.2.9519653
export PATH=$PATH:$ANDROID_NDK_HOME
```

#### 2. Rust Toolchain with Android Targets

Install Rust if not already installed:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Add Android target architectures:
```bash
rustup target add aarch64-linux-android    # ARM64 (most modern devices)
rustup target add armv7-linux-androideabi  # ARMv7 (older devices)
rustup target add x86_64-linux-android     # x86_64 (emulators)
```

**Verify targets:**
```bash
rustup target list --installed | grep android
```

#### 3. cargo-ndk

The `cargo-ndk` tool automates Rust cross-compilation for Android.

**Installation:**
```bash
cargo install cargo-ndk
```

**Verify installation:**
```bash
cargo ndk --version
# Should output: cargo-ndk 3.x.x or newer
```

#### 4. Flutter SDK

Ensure Flutter is installed and configured:
```bash
flutter doctor -v
```

Required:
- Flutter SDK 3.0+
- Android SDK (API level 28+)
- Android toolchain configured

### Summary Checklist

Before proceeding, verify you have:

- [ ] Android NDK r25c+ installed (`$ANDROID_NDK_HOME` set)
- [ ] Rust toolchain installed
- [ ] Android targets added (`aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android`)
- [ ] `cargo-ndk` installed and in PATH
- [ ] Flutter SDK 3.0+ configured
- [ ] Android device or emulator available for testing

## Initial Setup

### 1. Clone and Configure Project

```bash
git clone https://github.com/yourusername/beatbox-trainer.git
cd beatbox-trainer
```

### 2. Install Dependencies

**Flutter dependencies:**
```bash
flutter pub get
```

**Rust dependencies:**
```bash
cd rust
cargo fetch
cd ..
```

### 3. Verify Build Configuration

The project includes a custom Gradle task (`buildRustAndroid`) that automatically:
- Checks for `cargo-ndk` installation
- Cross-compiles Rust library for all Android architectures
- Copies `.so` files to `android/app/src/main/jniLibs/`

Verify the task exists:
```bash
cd android
./gradlew tasks --group=build | grep buildRustAndroid
```

Expected output:
```
buildRustAndroid - Builds Rust library for Android using cargo-ndk
```

## Building for Android

### Clean Build (Full Compilation)

For a complete clean build from scratch:

```bash
# From project root
flutter clean
flutter build apk
```

**Expected build time:** < 5 minutes on modern hardware

**Build process:**
1. Flutter cleans build artifacts
2. Gradle executes `buildRustAndroid` task
3. `cargo-ndk` cross-compiles Rust for 3 architectures:
   - `arm64-v8a` (ARM64)
   - `armeabi-v7a` (ARMv7)
   - `x86_64` (x86_64 emulators)
4. `.so` files copied to `jniLibs/`
5. Gradle packages APK with native libraries

### Incremental Build (Fast Rebuild)

After modifying Rust code:

```bash
flutter build apk
```

**Expected build time:** < 30 seconds

Gradle detects Rust source changes and triggers recompilation only for modified code.

### Building Specific Architectures

To build only specific architectures (for faster development):

```bash
cd rust
cargo ndk -t aarch64-linux-android -- build --release
```

Available targets:
- `aarch64-linux-android` (ARM64 - recommended for testing)
- `armv7-linux-androideabi` (ARMv7 - older devices)
- `x86_64-linux-android` (x86_64 - emulators)

### Verify APK Contents

After building, verify native libraries are packaged correctly:

```bash
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep libbeatbox_trainer.so
```

Expected output:
```
lib/arm64-v8a/libbeatbox_trainer.so
lib/armeabi-v7a/libbeatbox_trainer.so
lib/x86_64/libbeatbox_trainer.so
```

All three architectures should be present.

## Architecture Details

### Build Pipeline

```
flutter build apk
    ↓
Gradle assembleDebug
    ↓
buildRustAndroid (custom task)
    ↓
cargo ndk -t arm64-v8a -- build --release
cargo ndk -t armeabi-v7a -- build --release
cargo ndk -t x86_64 -- build --release
    ↓
Copy .so files to jniLibs/{arch}/
    ↓
Gradle packages APK
    ↓
APK contains libbeatbox_trainer.so for all architectures
```

### Runtime Initialization

```
App Launch
    ↓
MainActivity.onCreate()
    ↓
System.loadLibrary("beatbox_trainer")
    ↓
JNI_OnLoad() called (Rust)
    ↓
ndk_context::initialize_android_context(vm, context)
    ↓
Library ready - Audio engine can start
```

### Native Library Structure

The Rust library (`libbeatbox_trainer.so`) provides:
- Real-time audio processing via Oboe (C++)
- Lock-free metronome generation
- FFI bridge for Flutter integration
- JNI initialization for Android context

Library name matches `rust/Cargo.toml`:
```toml
[lib]
name = "beatbox_trainer"
crate-type = ["cdylib", "rlib"]
```

## Troubleshooting

### Error: "cargo-ndk not found"

**Symptoms:**
```
FAILURE: Build failed with an exception.
* What went wrong:
Execution failed for task ':app:buildRustAndroid'.
> cargo-ndk not found. Install with: cargo install cargo-ndk
```

**Solution:**
```bash
# Install cargo-ndk
cargo install cargo-ndk

# Verify installation
cargo ndk --version

# Ensure cargo bin directory is in PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Retry build
flutter build apk
```

### Error: "Rust target not installed"

**Symptoms:**
```
error: toolchain 'stable-aarch64-linux-android' is not installed
```

**Solution:**
```bash
# Install all required Android targets
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add x86_64-linux-android

# Verify installation
rustup target list --installed | grep android

# Retry build
flutter build apk
```

### Error: "Android NDK not found"

**Symptoms:**
```
error: linker `aarch64-linux-android21-clang` not found
```

**Solution:**

1. **Verify NDK installation:**
   ```bash
   ls $ANDROID_HOME/ndk/
   # Should list version directories like: 25.2.9519653
   ```

2. **Set environment variables:**
   ```bash
   export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/25.2.9519653
   export PATH=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH
   ```

3. **Install NDK via Android Studio if missing:**
   - Open Android Studio → SDK Manager → SDK Tools
   - Check "NDK (Side by side)" → Apply

4. **Retry build:**
   ```bash
   flutter clean
   flutter build apk
   ```

### Error: "UnsatisfiedLinkError" at runtime

**Symptoms:**
```
java.lang.UnsatisfiedLinkError: dlopen failed: library "libbeatbox_trainer.so" not found
```

**Diagnosis:**

1. **Check if .so files are in APK:**
   ```bash
   unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep libbeatbox_trainer.so
   ```

   If empty, the native library was not packaged.

2. **Verify jniLibs directory:**
   ```bash
   ls -R android/app/src/main/jniLibs/
   ```

   Expected structure:
   ```
   jniLibs/
   ├── arm64-v8a/
   │   └── libbeatbox_trainer.so
   ├── armeabi-v7a/
   │   └── libbeatbox_trainer.so
   └── x86_64/
       └── libbeatbox_trainer.so
   ```

**Solution:**

1. **Clean and rebuild:**
   ```bash
   flutter clean
   rm -rf android/app/src/main/jniLibs/*
   flutter build apk
   ```

2. **Verify Gradle task executed:**
   ```bash
   cd android
   ./gradlew clean buildRustAndroid
   ```

   Check for output:
   ```
   Building Rust library for arm64-v8a...
   ✓ Copied libbeatbox_trainer.so to jniLibs/arm64-v8a/
   ```

3. **Check library name matches:**

   Ensure `MainActivity.kt` loads correct library:
   ```kotlin
   System.loadLibrary("beatbox_trainer")  // No "lib" prefix, no ".so" suffix
   ```

### Error: "JNI initialization failed" (Code 1008)

**Symptoms:**
```
ERROR: JNI_OnLoad failed to initialize Android context
AudioError: JniInitFailed { reason: "Failed to get application context" }
```

**Diagnosis:**

Check logcat for detailed JNI errors:
```bash
adb logcat -s beatbox_trainer:V AndroidRuntime:E
```

**Common causes:**

1. **Application context not available:**
   - Verify `MainActivity.kt` calls `System.loadLibrary()` in `init` block
   - Ensure library loads before any native method calls

2. **JNI version mismatch:**
   - Verify `JNI_OnLoad` returns `JNI_VERSION_1_6`
   - Check Android API level compatibility (minimum API 24)

**Solution:**

1. **Verify MainActivity implementation:**
   ```bash
   cat android/app/src/main/kotlin/com/ryosukemondo/beatbox_trainer/MainActivity.kt
   ```

   Should contain:
   ```kotlin
   class MainActivity: FlutterActivity() {
       companion object {
           init {
               System.loadLibrary("beatbox_trainer")
           }
       }
   }
   ```

2. **Check minimum SDK version:**
   ```bash
   cat android/app/build.gradle.kts | grep minSdk
   ```

   Should be API 24 or higher (Android 7.0+).

3. **Reinstall and test:**
   ```bash
   flutter clean
   flutter build apk
   flutter install
   ```

### Error: "ContextNotInitialized" (Code 1009)

**Symptoms:**
```
AudioError: ContextNotInitialized
App crashes when tapping "Start" button
```

**Diagnosis:**

This error indicates the Android context was not initialized before the audio engine attempted to use it.

**Solution:**

1. **Check initialization order:**

   The correct sequence is:
   ```
   MainActivity.onCreate()
     → System.loadLibrary()
     → JNI_OnLoad()
     → ndk_context::initialize_android_context()
     → Audio engine can start
   ```

2. **Verify JNI_OnLoad execution:**

   Check logcat for initialization message:
   ```bash
   adb logcat | grep "JNI_OnLoad"
   ```

   Expected:
   ```
   I/beatbox_trainer: JNI_OnLoad called, initializing Android context
   I/beatbox_trainer: Android context initialized successfully
   ```

3. **Ensure audio engine starts after library load:**

   Do not call any native methods before MainActivity.onCreate() completes.

4. **Reinstall with clean build:**
   ```bash
   flutter clean
   flutter build apk --debug
   flutter install
   adb logcat -c  # Clear logcat
   # Launch app and tap Start button
   adb logcat -s beatbox_trainer:V
   ```

### Build Performance Issues

**Symptom: Build takes > 5 minutes**

**Diagnosis:**

1. **Check if full rebuild is triggered:**
   ```bash
   cd rust
   cargo clean
   cd ..
   time flutter build apk
   ```

2. **Identify bottleneck:**
   - Rust compilation: Check rustc CPU usage
   - Flutter compilation: Check Gradle output
   - Network: Verify cargo dependencies are cached

**Solutions:**

1. **Use release profile optimization:**

   Already configured in `rust/Cargo.toml`:
   ```toml
   [profile.release]
   opt-level = 3
   lto = true
   codegen-units = 1
   ```

2. **Enable incremental compilation for debug builds:**

   Add to `rust/Cargo.toml`:
   ```toml
   [profile.dev]
   incremental = true
   ```

3. **Reduce architecture targets during development:**

   Temporarily modify `android/app/build.gradle.kts`:
   ```kotlin
   val rustTargets = mapOf(
       "arm64-v8a" to "aarch64-linux-android"  // Build only ARM64
   )
   ```

   Remember to restore all architectures for release builds.

4. **Use ccache for C++ compilation:**
   ```bash
   sudo apt install ccache  # Linux
   export RUSTC_WRAPPER=ccache
   ```

### Device-Specific Issues

#### Pixel 9a (ARM64)

**Known working configuration:**
- Device ID: 4C041JEBF15065
- Android API: 34
- Architecture: arm64-v8a
- APK size with native libs: ~45MB

**Deployment:**
```bash
flutter run -d 4C041JEBF15065
```

**Common issues:**
- None reported with current build configuration

#### Android Emulators (x86_64)

**Known issue: Audio may not work on emulators**

Emulators lack proper low-latency audio hardware support. Use physical devices for audio testing.

**Configuration for emulator testing:**
```bash
# Create AVD with Google APIs (x86_64)
avdmanager create avd -n test_avd -k "system-images;android-30;google_apis;x86_64"

# Launch emulator
emulator -avd test_avd

# Deploy
flutter run -d emulator-5554
```

**Expected behavior:**
- App launches successfully
- UI renders correctly
- Audio engine may fail to start (expected on emulator)

## Development Workflow

### Typical Development Cycle

1. **Modify Rust code:**
   ```bash
   # Edit files in rust/src/
   vim rust/src/audio/engine.rs
   ```

2. **Quick local test (no Android):**
   ```bash
   cd rust
   cargo test
   cargo check
   cd ..
   ```

3. **Build for Android:**
   ```bash
   flutter build apk
   ```

4. **Install on device:**
   ```bash
   flutter install -d 4C041JEBF15065
   ```

5. **Monitor logs:**
   ```bash
   adb logcat -s beatbox_trainer:V flutter:I
   ```

### Debugging Tips

#### Enable Rust debug logs

Modify `rust/src/lib.rs`:
```rust
#[cfg(target_os = "android")]
android_logger::init_once(
    android_logger::Config::default()
        .with_max_level(log::LevelFilter::Debug)  // Changed from Info
);
```

#### View audio callback execution

Check for metronome timing logs:
```bash
adb logcat | grep "audio callback"
```

#### Inspect APK structure

```bash
cd build/app/outputs/flutter-apk/
unzip -l app-debug.apk
```

#### Test specific architecture

```bash
# Build only ARM64
cd rust
cargo ndk -t aarch64-linux-android -- build --release

# Manually copy to jniLibs
cp target/aarch64-linux-android/release/libbeatbox_trainer.so \
   ../android/app/src/main/jniLibs/arm64-v8a/

# Build APK (skips Rust compilation)
cd ..
flutter build apk --no-build-number
```

### CI/CD Integration

For automated builds in CI environments:

```yaml
# .github/workflows/android-build.yml
name: Android Build

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'

      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          override: true

      - name: Install Android targets
        run: |
          rustup target add aarch64-linux-android
          rustup target add armv7-linux-androideabi
          rustup target add x86_64-linux-android

      - name: Install cargo-ndk
        run: cargo install cargo-ndk

      - name: Setup Android SDK
        uses: android-actions/setup-android@v2

      - name: Build APK
        run: flutter build apk

      - name: Verify native libraries
        run: |
          unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep libbeatbox_trainer.so
          unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep arm64-v8a
          unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep armeabi-v7a
          unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep x86_64

      - name: Upload APK artifact
        uses: actions/upload-artifact@v3
        with:
          name: app-debug.apk
          path: build/app/outputs/flutter-apk/app-debug.apk
```

## Additional Resources

### Documentation

- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Rust Cross-Compilation Guide](https://rust-lang.github.io/rustup/cross-compilation.html)
- [cargo-ndk Documentation](https://github.com/bbqsrc/cargo-ndk)
- [Android NDK Documentation](https://developer.android.com/ndk)
- [Oboe Audio Library](https://github.com/google/oboe)

### Project Architecture

- [docs/ARCHITECTURE.md](ARCHITECTURE.md) - Application architecture overview
- [docs/TESTING.md](TESTING.md) - Testing strategy and coverage

### Error Codes Reference

Android-specific error codes:

- **1008** - `JniInitFailed`: JNI initialization failed during library load
- **1009** - `ContextNotInitialized`: Audio engine started before Android context initialized

See `rust/src/error.rs` for complete error code definitions.

## Getting Help

If you encounter issues not covered in this guide:

1. **Check logcat output:**
   ```bash
   adb logcat -s beatbox_trainer:V AndroidRuntime:E
   ```

2. **Verify build configuration:**
   ```bash
   cat android/app/build.gradle.kts | grep -A 10 "buildRustAndroid"
   ```

3. **Check Android NDK version:**
   ```bash
   cat $ANDROID_HOME/ndk/*/source.properties | grep Pkg.Revision
   ```

4. **Review implementation logs:**

   Check `.spec-workflow/specs/android-build-integration/Implementation Logs/` for detailed implementation history and known issues.

5. **Open an issue:**

   If problems persist, open a GitHub issue with:
   - Build output (`flutter build apk -v`)
   - Logcat output (`adb logcat`)
   - Environment details (`flutter doctor -v`)
   - APK verification (`unzip -l app-debug.apk | grep libbeatbox_trainer.so`)
