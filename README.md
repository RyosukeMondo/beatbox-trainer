# beatbox_trainer

A Flutter-based beatbox training application with real-time audio analysis.

## Getting Started

### Prerequisites

- Flutter SDK (3.0+)
- Rust toolchain (for native audio processing)
- Android SDK (for mobile deployment)

### Development Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   cd rust && cargo build
   ```

3. Install the pre-commit hook for code quality enforcement:
   ```bash
   cp scripts/pre-commit .git/hooks/pre-commit
   chmod +x .git/hooks/pre-commit
   ```

### Pre-Commit Quality Gates

This project uses a pre-commit hook to enforce code quality standards. The hook automatically runs before each commit and checks:

- **Code Formatting**: Dart code must be formatted with `dart format`, Rust code with `cargo fmt`
- **Linting**: Flutter analyzer and Clippy must pass with no warnings
- **File Size**: Source files must not exceed 500 lines (excluding tests)
- **Function Size**: Functions should not exceed 50 lines (warning only)
- **Tests**: All tests must pass

If any check fails, the commit will be blocked. You can see detailed error messages to help fix the issues.

To bypass the hook (not recommended):
```bash
git commit --no-verify
```

### Running Tests

```bash
# Run Flutter tests
flutter test

# Run Rust tests
cd rust && cargo test
```

### Code Quality Metrics

The project enforces the following quality standards:

- Maximum file size: 500 lines (excluding tests)
- Maximum function size: 50 lines (guideline)
- Test coverage: 80% overall, 90% for critical paths
- Zero unwrap/expect calls in production code
- Zero global state in business logic

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Rust Documentation](https://doc.rust-lang.org/)
