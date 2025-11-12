// Build script for flutter_rust_bridge code generation
//
// This build script is intentionally minimal because flutter_rust_bridge v2
// code generation is typically run via the CLI tool:
//   flutter_rust_bridge_codegen generate
//
// The generated files are:
// - lib/bridge/api.dart (Dart bindings)
// - rust/src/bridge_generated.rs (Rust FFI glue code)
//
// To run codegen:
//   cargo install flutter_rust_bridge_codegen
//   flutter_rust_bridge_codegen generate

fn main() {
    // Tell cargo to rerun this build script if api.rs changes
    println!("cargo:rerun-if-changed=src/api.rs");

    // Note: Code generation should be run manually via CLI or integrated into
    // your build pipeline. Running it automatically in build.rs can cause issues
    // with cargo builds.
}
