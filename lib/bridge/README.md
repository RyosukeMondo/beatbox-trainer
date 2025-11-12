# Flutter Rust Bridge Integration

This directory contains the generated Dart bindings for the Rust FFI.

## Setup

### 1. Install the codegen tool

```bash
cargo install flutter_rust_bridge_codegen
```

### 2. Generate the bindings

```bash
flutter_rust_bridge_codegen generate
```

This will:
- Read `rust/src/api.rs` (Rust functions with `#[flutter_rust_bridge::frb]` annotations)
- Generate `lib/bridge/api.dart` (Dart bindings)
- Generate `rust/src/bridge_generated.rs` (Rust FFI glue code)

### 3. Configuration

The codegen is configured via `flutter_rust_bridge.yaml` in the project root.

## Usage

Import the generated API in your Dart code:

```dart
import 'package:beatbox_trainer/bridge/api.dart';

// Use the API
final result = await greet(name: "World");
print(result); // "Hello, World! Flutter Rust Bridge is working."
```

## Development

When you add new functions to `rust/src/api.rs`:
1. Add the `#[flutter_rust_bridge::frb]` attribute
2. Use `Result<T>` return types for error handling
3. Run `flutter_rust_bridge_codegen generate` to update bindings
4. The Dart bindings will be automatically updated

## Files

- `api.dart` - Generated Dart bindings (DO NOT EDIT MANUALLY)
- `../rust/src/api.rs` - Source Rust API functions
- `../rust/src/bridge_generated.rs` - Generated Rust FFI glue (DO NOT EDIT MANUALLY)
