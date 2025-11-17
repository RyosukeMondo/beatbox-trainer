# Task 9.2 – Workspace Flutter Attempt

**Timestamp:** 2025-11-17T09:15:00Z  
**Engineer:** Codex QA (CLI session)  
**Objective:** Execute the UAT scenario suite or at least generate APK/test evidence from within the sandbox by cloning the Flutter SDK into the repository.

---

## Actions
1. **Local Flutter bootstrap**
   - Copied `/home/rmondo/flutter` into `.flutter-sdk/` under the repo to gain write access to `bin/cache`.
   - Redirected `HOME`, `PUB_CACHE`, and `GRADLE_USER_HOME` to workspace folders and synced caches from `/home/rmondo/.pub-cache` & `/home/rmondo/.gradle`.
   - Verified the toolchain runs offline: `flutter --version` and `flutter pub get --offline` completed successfully.
2. **Integration harness**
   - Ran `flutter test --no-pub test/integration/calibration_flow_test.dart` to simulate onboarding/calibration scenarios.
   - **Result:** Compilation failed immediately; generated FRB/Freezed files never created constructors such as `AudioError_StreamFailure` or `CalibrationError_Timeout`, so the analyzer stops before any tests execute.
3. **APK assembly**
   - Attempted `flutter build apk --debug --no-pub`.
   - **Result:** Gradle begins but aborts with `Could not determine a usable wildcard IP for this machine.`, preventing APK creation even though artifacts/caches are local.
4. **ADB verification**
   - Re-ran `adb devices` (with and without alternate ports). Daemon startup still fails with `failed to initialize libusb` / `could not install *smartsocket* listener: Operation not permitted`, so no physical hardware can be addressed from the sandbox.

---

## Outcome
- ✅ Documented a reproducible procedure for running Flutter tooling offline inside the repo, including required environment overrides/caches.
- ❌ Unable to execute UAT scenarios: integration tests do not compile until FRB/Freezed outputs are regenerated, Gradle cannot determine a wildcard IP in this environment, and `adb` remains blocked from starting.
- ✍ Updated `UAT_TEST_SCENARIOS.md` (root + spec copies) and `UAT_SIGN_OFF_REPORT.md` with the new evidence so QA knows exactly what to fix/redo on a workstation.

---

## Next Steps
1. On a developer workstation (outside the sandbox), rerun `flutter_rust_bridge_codegen` so the generated Dart types expose `AudioError_StreamFailure` and `CalibrationError_Timeout`, then regenerate Freezed parts via `flutter pub run build_runner build`.
2. Re-attempt `flutter test --no-pub test/integration/calibration_flow_test.dart` to confirm compilation succeeds before moving to device-based UAT.
3. Build the APK (`flutter build apk --debug`) on that workstation and sideload it with `adb install` to execute every scenario on a physical Android handset as defined in `UAT_TEST_SCENARIOS.md`.
