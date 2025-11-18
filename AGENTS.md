# Repository Guidelines

## Project Structure & Module Organization
`lib/` hosts the Flutter UI stack, split into `controllers/`, `services/`, `di/`, and `ui/` widgets, while FFI bindings live in `lib/bridge/` (regenerated via `flutter_rust_bridge.yaml`). Shared widgets and models sit beside `main.dart` to keep entry wiring close to dependencies. Dart tests mirror the source tree under `test/`, and integration specs live in `test/integration/`. Native audio code, lock-free DSP, and cross-platform targets live in `rust/` (with crate sources under `rust/src/`, integration specs in `rust/tests/`, and Android-specific glue under `rust/android/`). Reference docs reside in `docs/` (architecture, testing, release), design assets in `assets/`, and reusable tooling in `scripts/` (quality gates, metrics, coverage, hooks).

## Build, Test, and Development Commands
- `flutter pub get` – install Dart dependencies before any build.
- `flutter run -d <device>` – launch the app with hot reload for UI iterations.
- `cd rust && cargo build --target <triple>` – compile native audio modules (use cargo-ndk triples for Android).
- `flutter build apk` or `flutter build ipa` – produce release artifacts.
- `./scripts/pre-commit` – manual dry-run of the quality gate (formatting, lint, tests) before committing or pushing.
- `./scripts/coverage.sh [--rust-only|--dart-only]` – orchestrate instrumented test runs and HTML reports (filters generated FRB files automatically).
- `python scripts/verify_metrics.py` – one-off check that files and functions stay within the 500/50 line limits enforced in CI hooks.

## Coding Style & Naming Conventions
Install `scripts/pre-commit` into `.git/hooks` so `dart format`, `flutter analyze`, `cargo fmt`, `cargo clippy`, and unit tests all gate commits locally. Dart code follows two-space indentation, PascalCase classes (`AudioLatencyMonitor`), lowerCamelCase members, and snake_case file names. Rust modules use snake_case files, CamelCase types, and avoid `unwrap`/`expect` in production paths. Keep source files under 500 lines and functions under 50 lines; run `python scripts/verify_metrics.py` any time the hook flags a violation.

## Testing Guidelines
Unit and widget tests run with `flutter test`; mirror the source path and suffix files with `_test.dart`. Integration scenarios belong in `test/integration/` with descriptive group names and mock dependencies from `test/mocks.dart`. Rust logic relies on `cargo test` plus hygienic `tests/*.rs` files. Enforce the coverage thresholds baked into `./scripts/coverage.sh`: ≥80% overall and ≥90% for `rust/src/context.rs`, `rust/src/error.rs`, and `lib/services/audio/`. Prefer behavior-focused names like `calibration_controller_handles_timeout`, and document brittle cases in `docs/guides/qa/TESTING.md` when skipping mobile-only specs.

## Commit & Pull Request Guidelines
History follows Conventional Commits (`type(scope): detail`), e.g., `refactor(test): Split oversized calibration_screen_test.dart`. Write commits that narrate a single concern and pass the pre-commit gate. Pull requests should summarize the change, list linked issues or spec tasks, and include screenshots or log snippets for UI/audio-affecting work. Confirm tests, coverage, and analyzer/clippy output in the PR description, and call out any follow-up work or platform-specific caveats.

## Security & Configuration Tips
Keep secrets out of `pubspec.yaml` and `rust/Cargo.toml`; load runtime credentials from platform channels. Validate Android NDK toolchains (r25c+) before building, and rerun `flutter_rust_bridge` codegen whenever the FFI schema changes to prevent drift between Dart and Rust types.
