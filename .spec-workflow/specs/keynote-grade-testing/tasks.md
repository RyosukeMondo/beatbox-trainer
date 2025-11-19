# Tasks Document

 - [x] 1. Introduce diagnostics playbook manifests
  - Files: `tools/cli/diagnostics/playbooks/keynote.yaml`, `tools/cli/diagnostics/README.md`
  - Define YAML schema for ordered steps, env overrides, retries, and artifact outputs
  - Provide sample scenarios (`default-smoke`, `keynote-latency`, `calibration-stress`)
  - Document how QA extends/executes playbooks and how logs map to `logs/diagnostics/`
  - _Leverage: requirements §1, design §§Overview, Components/DiagnosticsPlaybookParser_
  - _Prompt: Role: QA Tooling Engineer with YAML/schema expertise | Task: Author manifest schema + sample scenarios for diagnostics playbooks, documenting usage for QA teams | Restrictions: Keep manifests declarative (no shell logic), reference only commands already available in repo | Success: CLI runner can parse manifests without code changes, docs make QA self-sufficient_

- [x] 2. Build DiagnosticsPlaybookParser and runner
  - Files: `tools/cli/diagnostics/lib/playbook_parser.dart`, `tools/cli/diagnostics/lib/playbook_runner.dart`, `tools/cli/diagnostics/run.sh`
  - Parse YAML manifests into strongly typed models; validate required fields
  - Execute ordered steps, enforce retries/timeouts, stream output to scenario-specific log directories, emit PASS/FAIL summary with artifact paths
  - Expose `tools/cli/diagnostics/run.sh --scenario <id>` flag, defaulting to `default-smoke`
  - _Leverage: design §§Components (DiagnosticsPlaybookParser, PlaybookRunner), Architecture diagram_
  - _Prompt: Role: Diagnostics CLI developer | Task: Implement parser + runner with clear logging and ANSI status output, wiring into existing run.sh | Restrictions: No external deps beyond Dart SDK/stdlib, keep runner cross-platform | Success: Running `./tools/cli/diagnostics/run.sh --scenario keynote-latency` executes manifest-defined steps and writes logs under `logs/diagnostics/keynote-latency/<timestamp>`_

- [x] 3. Create fixture metadata registry
  - Files: `rust/fixtures/catalog.json`, `rust/src/testing/fixture_manifest.rs`, `lib/bridge/api.dart` (FRB), `lib/services/debug/fixture_metadata_service.dart`
  - Define manifest schema (source, BPM bounds, expected counts, anomaly tags, tolerances)
  - Implement Rust loader + validator returning typed metadata; expose via FRB for Dart consumers
  - Add Dart service caching metadata for Debug Lab and CLI overlays
  - _Leverage: requirements §2, design §§FixtureMetadataRegistry, Data Models_
  - _Prompt: Role: Rust/Dart FFI engineer | Task: Build shared metadata access + validation bridging Rust manifest to Dart | Restrictions: Keep manifest parsing in Rust (serde_json), ensure FRB codegen stays deterministic, tests cover malformed manifests | Success: `bbt-diag run --fixture basic_hits` automatically reads metadata, Debug Lab can query same data_

- [x] 4. Validate fixtures during CLI + Debug Lab flows
  - Files: `rust/src/testing/fixture_engine.rs`, `rust/src/bin/bbt-diag.rs`, `lib/controllers/debug/debug_lab_controller.dart`, `lib/ui/screens/debug_lab_screen.dart`, `lib/ui/widgets/debug/anomaly_banner.dart`
  - Extend fixture engine + bbt-diag to enforce BPM/expected count tolerances, writing anomalies to `logs/smoke/debug_lab_anomalies.log`
  - Add Debug Lab ValueNotifier + UI banner that highlights mismatches with actionable text and links to log artifact
  - _Leverage: requirements §2 acceptance criteria, design §§DebugLabAnomalyOverlay_
  - _Prompt: Role: Diagnostics UX engineer | Task: Surface metadata mismatches in both CLI output and Debug Lab UI | Restrictions: Keep UI under 500 lines, logs redacted for tokens, highlight card must be dismissible | Success: Running synthetic toggle that deviates beyond tolerance shows warning banner + structured log entry_

- [x] 5. Implement baseline diff + watch loops
  - Files: `scripts/pre-commit`, `tools/cli/diagnostics/lib/baseline_diff.dart`, `tools/cli/diagnostics/watch.sh`, `logs/smoke/baselines/README.md`
  - Create baseline storage format (JSON snapshots per scenario) and diff engine with tolerances; output human-readable delta + regeneration command
  - Add watch mode script (fsnotify/inotifywait) that reruns playbooks when DSP-critical files change and streams status inline
  - Integrate baseline diff reporting into pre-commit when relevant paths change
  - _Leverage: requirements §3, design §§BaselineDiffEngine_
  - _Prompt: Role: Tooling engineer specializing in developer experience | Task: Deliver watch + diff loop for diagnostics telemetry | Restrictions: Use portable shell/Dart only (no long-running Python deps), ensure watch loop debounces to ≥5s, keep baselines versioned in repo | Success: `tools/cli/diagnostics/watch.sh` highlights regressions live; failing diffs block pre-commit with actionable instructions_

- [ ] 6. Bundle Debug Lab exports with evidence artifacts
  - Files: `lib/services/debug/i_log_exporter.dart`, `lib/services/debug/log_exporter_impl.dart`, `lib/controllers/debug/debug_lab_controller.dart`, `logs/smoke/export/`
  - Extend exporter to collect FRB stream samples, `/metrics` snapshots, fixture IDs, and ParamPatch events into single ZIP per export
  - Ensure CLI references (paths, tokens redacted) accompany zipped artifact for keynote sharing
  - _Leverage: requirements §3 acceptance criteria #3, design §§Overview, Components (DebugLabAnomalyOverlay)_
  - _Prompt: Role: Flutter services engineer | Task: Improve Debug Lab export so QA can hand evidence to stakeholders | Restrictions: Keep exports off main thread, reuse existing log storage conventions, surface success/failure toast in UI | Success: Tapping export icon creates zipped package logged in console and accessible through path banner_

- [ ] 7. Testing matrix for keynote-grade workflows
  - Files: `tools/cli/diagnostics/test/playbook_parser_test.dart`, `rust/src/testing/fixture_manifest.rs` (unit tests), `test/ui/debug/debug_lab_screen_test.dart`, CI docs in `docs/guides/qa/diagnostics.md`
  - Add parser unit tests (valid/invalid manifests), Rust metadata validation tests, widget tests for anomaly banner, and integration test running a trimmed playbook in CI
  - Update diagnostics guide with instructions for running new tests + interpreting artifacts
  - _Leverage: requirements all, design §§Testing Strategy_
  - _Prompt: Role: QA automation engineer | Task: Ensure every new component ships with unit + integration coverage plus doc updates | Restrictions: Keep tests deterministic (use synthetic fixtures), tie CI instructions to existing scripts | Success: `flutter test`, `cargo test`, and new `dart test tools/cli/diagnostics/test` suites cover the added logic; docs show how to run them_
