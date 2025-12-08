#!/bin/bash
# Full rebuild script for beatbox-trainer
# Use when FRB content hash mismatch or after Rust changes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "=== Full Build ==="
echo ""

# Optional clean to avoid stale artifacts causing hash mismatches
echo "[0/5] Cleaning build outputs..."
flutter clean >/dev/null
(cd rust && cargo clean >/dev/null)

# Step 1: Regenerate FRB bindings
echo "[1/5] Regenerating Flutter Rust Bridge bindings..."
flutter_rust_bridge_codegen generate

# Step 2: Get Flutter dependencies
echo "[2/5] Getting Flutter dependencies..."
flutter pub get

# Step 3: Build Rust (after bindings regenerate)
echo "[3/5] Building Rust..."
cd rust
cargo build --features debug_http
cd ..

# Step 4: Build Flutter
echo "[4/5] Building Flutter..."
flutter build linux --debug

# Step 5: Copy native library into the Linux bundle for flutter run
echo "[5/5] Staging native library for desktop..."
RUST_LIB_PATH="rust/target/debug/libbeatbox_trainer.so"
LINUX_BUNDLE_LIB_DIR="build/linux/x64/debug/bundle/lib"
if [[ -f "$RUST_LIB_PATH" ]]; then
  mkdir -p "$LINUX_BUNDLE_LIB_DIR"
  cp "$RUST_LIB_PATH" "$LINUX_BUNDLE_LIB_DIR/"
  echo "Copied $(basename "$RUST_LIB_PATH") into $LINUX_BUNDLE_LIB_DIR"
else
  echo "WARNING: $RUST_LIB_PATH not found; desktop run may fail to load the Rust library."
fi

echo ""
echo "=== Build Complete ==="
echo "Run: LD_LIBRARY_PATH=rust/target/debug flutter run -d linux"
