# Android Emulator Setup Guide

This guide documents how to provision and operate an Android Virtual Device (AVD) so you can run non-audio Beatbox Trainer checks before UAT on physical hardware.

## 1. Prerequisites
- Android SDK already installed at `~/Android/Sdk` (present in this repo’s workstation image).
- Command-line tools (`sdkmanager`, `avdmanager`), `adb`, and the emulator binary available under the SDK path.
- Flutter SDK installed for building/running the app.

> **Note:** The Codex CLI environment cannot surface GUI windows or real microphone input. These steps are best run locally where you can open Android Studio/emulator GUIs if needed.

## 2. Export Environment Variables
Add the following to your shell profile (e.g., `~/.bashrc`) so the Android tooling is in your PATH:

```bash
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$PATH:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
```

Reload your shell: `source ~/.bashrc`

## 3. Install / Update SDK Components
Fetch the emulator, system image, and platform for Android 14 (API 35). Adjust the API level if you need a different target.

```bash
sdkmanager --list  # optional: inspect installed components

yes | sdkmanager \
  "platforms;android-35" \
  "system-images;android-35;google_apis;x86_64" \
  "emulator" \
  "platform-tools"

yes | sdkmanager --licenses
```

## 4. Create an AVD
Use `avdmanager` to create a Pixel profile. This example provisions a Pixel 7 on API 35 with a 2 GB SD card image.

```bash
avdmanager create avd \
  -n beatboxPixelApi35 \
  -k "system-images;android-35;google_apis;x86_64" \
  --device "pixel_7" \
  --sdcard 2048M
```

Configuration files live under `~/.android/avd/beatboxPixelApi35.avd`.

## 5. Launch the Emulator
### GUI launch (preferred when a desktop session is available)
```bash
emulator -avd beatboxPixelApi35
```

### Headless launch (no GUI/mic support, but works for automated UI navigation)
```bash
emulator -avd beatboxPixelApi35 \
  -gpu swiftshader_indirect \
  -no-snapshot \
  -no-boot-anim \
  -camera-back none \
  -camera-front none
```

Wait for the lock screen to appear (or `adb wait-for-device`) before proceeding.

## 6. Connect Flutter / ADB
```bash
adb devices          # should list emulator-5554
flutter devices      # emulator appears as an Android emulator target
flutter build apk --debug
flutter install --device-id emulator-5554
```

You can now use `flutter run`, `flutter drive`, or integration tests against the emulator.

## 7. Automate Emulator Interactions
- Tap/swipe: `adb shell input tap <x> <y>`, `adb shell input swipe <x1> <y1> <x2> <y2> 300`
- Toggle airplane mode:
  ```bash
  adb shell settings put global airplane_mode_on 1
  adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true
  ```
  (Use `0`/`false` to disable.)
- Collect logs: `adb logcat -d > emulator.log`
- Simulate mic permission grant/deny: `adb shell pm grant|revoke com.beatbox.trainer android.permission.RECORD_AUDIO`

These commands are helpful for regression smoke tests even though calibration audio itself won’t work.

## 8. Optional: Android Studio UI
If you have desktop access, install Android Studio, point it to `~/Android/Sdk`, then use **Tools ▸ Device Manager** to create/launch AVDs with a GUI. This is useful for visually verifying UI flows.

## 9. Limitations
- **No real microphone/audio path**: The emulator (especially headless) cannot provide reliable mic input, so calibration accuracy, latency, and audio-engine behavior must still be validated on physical devices.
- **Performance numbers differ**: Emulator CPU/Memory/App launch metrics do not represent physical hardware targets; only use them for relative comparisons.
- **GUI requirement**: Full emulator or Studio UX needs a graphical environment. Headless mode is available but limited.

## 10. Next Steps for UAT
1. Use the emulator for preliminary smoke checks (navigation, persistence, error screens).
2. Once confident, switch to physical hardware and follow `UAT_TEST_SCENARIOS.md` to capture official UAT results.
3. Document device names/versions and measured metrics in the UAT doc, then move to sign-off tasks.
