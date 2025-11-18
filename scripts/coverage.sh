#!/usr/bin/env bash
#
# coverage.sh - Unified Test Coverage Reporting
#
# This script generates test coverage reports for both Rust and Dart code,
# enforces coverage thresholds, and produces unified HTML reports.
# Generated files (frb_generated, bridge_generated, *.g.dart, *.freezed.dart)
# are automatically filtered from Dart coverage reports.
#
# Requirements:
#   - cargo-llvm-cov: cargo install cargo-llvm-cov
#   - Flutter SDK with test coverage support
#   - lcov (for Dart coverage): sudo apt install lcov (Linux) or brew install lcov (macOS)
#
# Usage:
#   ./scripts/coverage.sh [OPTIONS]
#
# Options:
#   --rust-only       Run Rust coverage only
#   --dart-only       Run Dart/Flutter coverage only
#   --no-threshold    Skip threshold enforcement
#   --open            Open HTML report in browser after generation
#   --clean           Clean coverage artifacts before running
#   -h, --help        Show this help message
#
# Coverage Thresholds:
#   - Overall: 80% minimum
#   - Critical paths: 90% minimum (AppContext, ErrorHandler, AudioService)
#
# Exit Codes:
#   0 - Success, all thresholds met
#   1 - Coverage below threshold
#   2 - Tool/dependency not found
#   3 - Test execution failed

set -e  # Exit on error

# ANSI color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
RUN_RUST=true
RUN_DART=true
ENFORCE_THRESHOLD=true
OPEN_REPORT=false
CLEAN_FIRST=false

# Coverage thresholds
OVERALL_THRESHOLD=80
CRITICAL_THRESHOLD=90

# Directories
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUST_DIR="$PROJECT_ROOT/rust"
COVERAGE_DIR="$PROJECT_ROOT/coverage"
RUST_COVERAGE_DIR="$COVERAGE_DIR/rust"
DART_COVERAGE_DIR="$COVERAGE_DIR/dart"
ARTIFACT_DIR="$PROJECT_ROOT/logs/smoke"

# Critical paths (require 90% coverage)
CRITICAL_PATHS=(
    "context.rs"
    "error.rs"
)

DART_CRITICAL_PREFIXES=(
    "lib/services/audio/"
)

# Parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --rust-only)
                RUN_RUST=true
                RUN_DART=false
                shift
                ;;
            --dart-only)
                RUN_RUST=false
                RUN_DART=true
                shift
                ;;
            --no-threshold)
                ENFORCE_THRESHOLD=false
                shift
                ;;
            --open)
                OPEN_REPORT=true
                shift
                ;;
            --clean)
                CLEAN_FIRST=true
                shift
                ;;
            -h|--help)
                grep '^#' "$0" | sed 's/^# //' | sed 's/^#//'
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 2
                ;;
        esac
    done
}

# Print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Check if required tools are installed
check_dependencies() {
    print_section "Checking Dependencies"

    local missing_deps=false

    if $RUN_RUST; then
        if ! command -v cargo &> /dev/null; then
            print_error "cargo not found. Please install Rust toolchain."
            missing_deps=true
        fi

        if ! command -v cargo-llvm-cov &> /dev/null; then
            print_error "cargo-llvm-cov not found. Install with: cargo install cargo-llvm-cov"
            missing_deps=true
        else
            print_success "cargo-llvm-cov found"
        fi
    fi

    if $RUN_DART; then
        if ! command -v flutter &> /dev/null; then
            print_error "flutter not found. Please install Flutter SDK."
            missing_deps=true
        else
            print_success "flutter found"
        fi

        # lcov is required for filtering generated files and creating HTML reports
        if ! command -v lcov &> /dev/null; then
            print_error "lcov not found. Required for filtering generated files and HTML reports."
            print_error "  Linux: sudo apt install lcov"
            print_error "  macOS: brew install lcov"
            missing_deps=true
        else
            print_success "lcov found"
        fi
    fi

    if $missing_deps; then
        exit 2
    fi
}

# Clean previous coverage artifacts
clean_coverage() {
    if $CLEAN_FIRST; then
        print_section "Cleaning Coverage Artifacts"
        rm -rf "$COVERAGE_DIR"
        rm -rf "$RUST_DIR/target/llvm-cov-target"
        rm -rf "$PROJECT_ROOT/coverage"
        print_success "Coverage artifacts cleaned"
    fi
}

# Run Rust test coverage
run_rust_coverage() {
    print_section "Running Rust Test Coverage"

    cd "$RUST_DIR"

    # Create coverage output directory
    mkdir -p "$RUST_COVERAGE_DIR"

    print_info "Running tests with coverage instrumentation..."

    # Run tests with llvm-cov, excluding Android-specific code
    # Generate both HTML and text reports
    if cargo llvm-cov \
        --all-features \
        --workspace \
        --html \
        --output-dir "$RUST_COVERAGE_DIR" \
        --ignore-filename-regex "(tests/|build\.rs)" \
        -- --test-threads=1; then

        print_success "Rust tests completed with coverage"

        # Also generate text summary for threshold checking
        cargo llvm-cov \
            --all-features \
            --workspace \
            --ignore-filename-regex "(tests/|build\.rs)" \
            > "$RUST_COVERAGE_DIR/summary.txt" 2>&1 || true

    else
        print_error "Rust tests failed"
        exit 3
    fi

    cd "$PROJECT_ROOT"
}

# Run Dart/Flutter test coverage
run_dart_coverage() {
    print_section "Running Dart/Flutter Test Coverage"

    # Check if test directory exists
    if [ ! -d "$PROJECT_ROOT/test" ]; then
        print_warning "No test directory found. Creating placeholder..."
        mkdir -p "$PROJECT_ROOT/test"

        # Create a placeholder test file
        cat > "$PROJECT_ROOT/test/placeholder_test.dart" <<'EOF'
// Placeholder test file
// TODO: Add actual widget and unit tests

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder test', () {
    expect(1 + 1, equals(2));
  });
}
EOF

        print_info "Created placeholder test. Run task 3.5, 4.5 to add real tests."
    fi

    print_info "Running Flutter tests with coverage..."

    # Create coverage output directory
    mkdir -p "$DART_COVERAGE_DIR"

    # Run flutter test with coverage
    if flutter test --coverage; then
        print_success "Dart tests completed with coverage"

        # Filter out generated files from coverage report
        if [ -f "$PROJECT_ROOT/coverage/lcov.info" ]; then
            print_info "Filtering out generated files from coverage..."

            # Remove generated files from lcov.info
            if command -v lcov &> /dev/null; then
                lcov --remove "$PROJECT_ROOT/coverage/lcov.info" \
                    '**/frb_generated.dart' \
                    '**/bridge_generated.dart' \
                    '**/frb_generated.*.dart' \
                    '**/*.freezed.dart' \
                    '**/*.g.dart' \
                    --output-file "$PROJECT_ROOT/coverage/lcov_filtered.info" \
                    --quiet

                # Replace original with filtered version
                mv "$PROJECT_ROOT/coverage/lcov_filtered.info" "$PROJECT_ROOT/coverage/lcov.info"
                print_success "Generated files filtered from coverage"
            else
                print_warning "lcov not found. Skipping file filtering."
            fi
        fi

        # Check if lcov is available for HTML report generation
        if command -v lcov &> /dev/null && command -v genhtml &> /dev/null; then
            print_info "Generating HTML coverage report..."

            # Generate HTML report from lcov data
            genhtml coverage/lcov.info \
                --output-directory "$DART_COVERAGE_DIR" \
                --title "Beatbox Trainer - Dart Coverage" \
                --legend \
                --quiet

            print_success "HTML report generated at $DART_COVERAGE_DIR/index.html"
        else
            print_warning "lcov not found. Skipping HTML report generation."
            print_warning "Install lcov to generate HTML reports:"
            print_warning "  Linux: sudo apt install lcov"
            print_warning "  macOS: brew install lcov"
        fi

        # Move lcov.info to Dart coverage directory
        if [ -f "$PROJECT_ROOT/coverage/lcov.info" ]; then
            cp "$PROJECT_ROOT/coverage/lcov.info" "$DART_COVERAGE_DIR/"
        fi

    else
        print_error "Dart tests failed"
        exit 3
    fi
}

# Parse coverage percentage from Rust output
parse_rust_coverage() {
    local summary_file="$RUST_COVERAGE_DIR/summary.txt"

    if [ -f "$summary_file" ]; then
        # Extract overall coverage percentage from llvm-cov output
        # Example line: "TOTAL  4046  368  90.90%  286  16  94.41%  2526  256  89.87%  0  0  -"
        # Column 10 is Lines Cover (89.87%)
        local coverage=$(grep "^TOTAL" "$summary_file" | awk '{print $10}' | sed 's/%//')
        echo "${coverage:-0}"
    else
        echo "0"
    fi
}

# Parse coverage percentage from Dart lcov.info
parse_dart_coverage() {
    local lcov_file="$DART_COVERAGE_DIR/lcov.info"

    if [ -f "$lcov_file" ]; then
        # Calculate coverage from lcov.info
        local lines_found=$(grep -E "^LF:" "$lcov_file" | cut -d: -f2 | awk '{s+=$1} END {print s}')
        local lines_hit=$(grep -E "^LH:" "$lcov_file" | cut -d: -f2 | awk '{s+=$1} END {print s}')

        if [ "$lines_found" -gt 0 ]; then
            echo "scale=2; ($lines_hit / $lines_found) * 100" | bc
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

collect_dart_coverages_for_prefix() {
    local prefix="$1"
    local lcov_file="$DART_COVERAGE_DIR/lcov.info"

    if [ ! -f "$lcov_file" ]; then
        return
    fi

    awk -v prefix="$prefix" -v root="$PROJECT_ROOT/" '
        /^SF:/ {
            file = substr($0, 4)
            rel = file
            gsub(root, "", rel)
            if (index(rel, prefix) == 1) {
                in_file = 1
                path = rel
            } else {
                in_file = 0
            }
        }
        in_file && /^LH:/ { lh = $2 }
        in_file && /^LF:/ {
            lf = $2
            if (lf > 0) {
                printf "%s %.2f\n", path, (lh/lf)*100
            } else {
                printf "%s 0\n", path
            }
            in_file = 0
        }
    ' "$lcov_file"
}

get_dart_critical_coverages() {
    local prefix
    for prefix in "${DART_CRITICAL_PREFIXES[@]}"; do
        collect_dart_coverages_for_prefix "$prefix"
    done
}

get_rust_critical_coverages() {
    local summary_file="$RUST_COVERAGE_DIR/summary.txt"
    if [ ! -f "$summary_file" ]; then
        return
    fi

    local path
    for path in "${CRITICAL_PATHS[@]}"; do
        local coverage=$(grep "$path" "$summary_file" 2>/dev/null | awk '{print $10}' | sed 's/%//' | head -n1)
        if [ -n "$coverage" ]; then
            echo "$path $coverage"
        fi
    done
}

write_summary_artifact() {
    mkdir -p "$ARTIFACT_DIR"
    if ! command -v python3 >/dev/null 2>&1; then
        print_warning "python3 not found; skipping coverage summary artifact"
        return 0
    fi

    local summary_file="$ARTIFACT_DIR/coverage_summary.json"
    local rust_overall=$(parse_rust_coverage)
    local dart_overall=$(parse_dart_coverage)
    local rust_entries=$(get_rust_critical_coverages)
    local dart_entries=$(get_dart_critical_coverages)

    SUMMARY_TIMESTAMP="$(date -Iseconds)" \
    RUST_OVERALL_VALUE="${rust_overall:-0}" \
    DART_OVERALL_VALUE="${dart_overall:-0}" \
    RUST_CRITICAL_ENTRIES="$rust_entries" \
    DART_CRITICAL_ENTRIES="$dart_entries" \
    python3 - "$summary_file" <<'PY'
import json
import os
import sys

summary_file = sys.argv[1]

def parse_entries(env_name):
    entries = {}
    raw = os.environ.get(env_name, "")
    for line in raw.strip().splitlines():
        if not line.strip():
            continue
        path, value = line.rsplit(" ", 1)
        try:
            entries[path] = float(value)
        except ValueError:
            continue
    return entries

payload = {
    "generated_at": os.environ.get("SUMMARY_TIMESTAMP"),
    "rust": {
        "overall": float(os.environ.get("RUST_OVERALL_VALUE") or 0),
        "critical": parse_entries("RUST_CRITICAL_ENTRIES"),
    },
    "dart": {
        "overall": float(os.environ.get("DART_OVERALL_VALUE") or 0),
        "critical": parse_entries("DART_CRITICAL_ENTRIES"),
    },
}

with open(summary_file, "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2)
PY

    print_success "Coverage summary written to $summary_file"
}

# Check coverage thresholds
check_thresholds() {
    if ! $ENFORCE_THRESHOLD; then
        print_warning "Threshold enforcement disabled (--no-threshold)"
        return 0
    fi

    print_section "Checking Coverage Thresholds"

    local threshold_failed=false

    if $RUN_RUST; then
        local rust_coverage=$(parse_rust_coverage)
        print_info "Rust overall coverage: ${rust_coverage}%"

        # Use integer comparison to avoid bc issues
        local rust_coverage_int=$(echo "$rust_coverage" | cut -d. -f1)
        if [ "$rust_coverage_int" -lt "$OVERALL_THRESHOLD" ]; then
            print_error "Rust coverage ($rust_coverage%) below threshold ($OVERALL_THRESHOLD%)"
            threshold_failed=true
        else
            print_success "Rust coverage meets threshold ($OVERALL_THRESHOLD%)"
        fi

        # Check critical paths coverage
        print_info "Checking critical paths (${CRITICAL_THRESHOLD}% required):"
        local rust_entries
        rust_entries=$(get_rust_critical_coverages)
        if [ -z "$rust_entries" ]; then
            print_warning "  No Rust critical coverage data found"
        else
            while read -r path file_coverage; do
                [ -z "$path" ] && continue
                local file_coverage_int=$(echo "$file_coverage" | cut -d. -f1)
                if [ "$file_coverage_int" -lt "$CRITICAL_THRESHOLD" ]; then
                    print_error "  $path: ${file_coverage}% (below ${CRITICAL_THRESHOLD}%)"
                    threshold_failed=true
                else
                    print_success "  $path: ${file_coverage}%"
                fi
            done <<< "$rust_entries"
        fi
    fi

    if $RUN_DART; then
        local dart_coverage=$(parse_dart_coverage)
        print_info "Dart overall coverage: ${dart_coverage}%"

        # Use integer comparison to avoid bc issues
        local dart_coverage_int=$(echo "$dart_coverage" | cut -d. -f1)
        if [ -n "$dart_coverage_int" ] && [ "$dart_coverage_int" -lt "$OVERALL_THRESHOLD" ]; then
            print_error "Dart coverage ($dart_coverage%) below threshold ($OVERALL_THRESHOLD%)"
            threshold_failed=true
        else
            print_success "Dart coverage meets threshold ($OVERALL_THRESHOLD%)"
        fi

        local dart_entries
        dart_entries=$(get_dart_critical_coverages)

        if [ -n "$dart_entries" ]; then
            print_info "Checking Dart critical paths (${CRITICAL_THRESHOLD}% required):"
            while read -r file coverage; do
                [ -z "$file" ] && continue
                local coverage_int=$(echo "$coverage" | cut -d. -f1)
                if [ "$coverage_int" -lt "$CRITICAL_THRESHOLD" ]; then
                    print_error "  $file: ${coverage}% (below ${CRITICAL_THRESHOLD}%)"
                    threshold_failed=true
                else
                    print_success "  $file: ${coverage}%"
                fi
            done <<< "$dart_entries"
        else
            print_warning "  lib/services/audio/*: No coverage data found"
        fi
    fi

    echo ""

    if $threshold_failed; then
        print_error "Coverage thresholds not met!"
        print_info "Run with --no-threshold to generate reports without enforcement"
        return 1
    else
        print_success "All coverage thresholds met!"
        return 0
    fi
}

# Generate unified coverage report
generate_unified_report() {
    print_section "Generating Unified Coverage Report"

    local report_file="$COVERAGE_DIR/COVERAGE_REPORT.md"

    cat > "$report_file" <<EOF
# Test Coverage Report

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')

## Summary

EOF

    if $RUN_RUST; then
        local rust_coverage=$(parse_rust_coverage)
        local rust_coverage_int=$(echo "$rust_coverage" | cut -d. -f1)
        local rust_status="❌ FAIL"
        if [ -n "$rust_coverage_int" ] && [ "$rust_coverage_int" -ge "$OVERALL_THRESHOLD" ]; then
            rust_status="✅ PASS"
        fi
        cat >> "$report_file" <<EOF
### Rust Coverage

- **Overall:** ${rust_coverage}%
- **Threshold:** ${OVERALL_THRESHOLD}% ($rust_status)
- **Report:** [View HTML Report](rust/index.html)

#### Critical Paths (${CRITICAL_THRESHOLD}% required)

EOF

        for path in "${CRITICAL_PATHS[@]}"; do
            local file_coverage=$(grep "$path" "$RUST_COVERAGE_DIR/summary.txt" 2>/dev/null | awk '{print $10}' | sed 's/%//' || echo "N/A")
            local status="❓"
            if [ "$file_coverage" != "N/A" ] && [ "$file_coverage" != "0" ] && [ "$file_coverage" != "-" ]; then
                # Use integer comparison to avoid bc issues
                local coverage_int=$(echo "$file_coverage" | cut -d. -f1)
                if [ "$coverage_int" -ge "$CRITICAL_THRESHOLD" ]; then
                    status="✅"
                else
                    status="❌"
                fi
            fi
            echo "- \`$path\`: ${file_coverage}% $status" >> "$report_file"
        done

        echo "" >> "$report_file"
    fi

    if $RUN_DART; then
        local dart_coverage=$(parse_dart_coverage)
        local dart_coverage_int=$(echo "$dart_coverage" | cut -d. -f1)
        local dart_status="❌ FAIL"
        if [ -n "$dart_coverage_int" ] && [ "$dart_coverage_int" -ge "$OVERALL_THRESHOLD" ]; then
            dart_status="✅ PASS"
        fi
        cat >> "$report_file" <<EOF
### Dart/Flutter Coverage

- **Overall:** ${dart_coverage}%
- **Threshold:** ${OVERALL_THRESHOLD}% ($dart_status)
- **Report:** [View HTML Report](dart/index.html)

EOF
    fi

    cat >> "$report_file" <<EOF
## Coverage Details

### What's Tested

EOF

    if $RUN_RUST; then
        cat >> "$report_file" <<EOF
**Rust:**
- Error handling infrastructure (AudioError, CalibrationError)
- Dependency injection (AppContext)
- Business logic methods (start_audio, stop_audio, calibration lifecycle)
- Lock poisoning recovery
- Input validation

EOF
    fi

    if $RUN_DART; then
        cat >> "$report_file" <<EOF
**Dart:**
- Service layer (AudioService, PermissionService)
- Error translation (ErrorHandler)
- Widget composition (shared dialogs, loading overlays)
- Screen interactions (TrainingScreen, CalibrationScreen)

EOF
    fi

    cat >> "$report_file" <<EOF
## How to Improve Coverage

1. **Add missing unit tests** for uncovered functions
2. **Add integration tests** for end-to-end flows
3. **Test error paths** explicitly (invalid inputs, failures)
4. **Mock dependencies** in tests to isolate logic
5. **Focus on critical paths** first (90% threshold)

## Commands

\`\`\`bash
# Run all coverage
./scripts/coverage.sh

# Rust only
./scripts/coverage.sh --rust-only

# Dart only
./scripts/coverage.sh --dart-only

# Generate without threshold enforcement
./scripts/coverage.sh --no-threshold

# Open report in browser
./scripts/coverage.sh --open
\`\`\`

---
*For more information, see [TESTING.md](../docs/guides/qa/TESTING.md)*
EOF

    print_success "Unified report generated: $report_file"
}

# Open coverage report in browser
open_report() {
    if $OPEN_REPORT; then
        print_section "Opening Coverage Reports"

        if $RUN_RUST && [ -f "$RUST_COVERAGE_DIR/index.html" ]; then
            print_info "Opening Rust coverage report..."
            if command -v xdg-open &> /dev/null; then
                xdg-open "$RUST_COVERAGE_DIR/index.html" 2>/dev/null &
            elif command -v open &> /dev/null; then
                open "$RUST_COVERAGE_DIR/index.html"
            else
                print_warning "Cannot open browser automatically. Open manually:"
                print_info "  file://$RUST_COVERAGE_DIR/index.html"
            fi
        fi

        if $RUN_DART && [ -f "$DART_COVERAGE_DIR/index.html" ]; then
            print_info "Opening Dart coverage report..."
            if command -v xdg-open &> /dev/null; then
                xdg-open "$DART_COVERAGE_DIR/index.html" 2>/dev/null &
            elif command -v open &> /dev/null; then
                open "$DART_COVERAGE_DIR/index.html"
            else
                print_warning "Cannot open browser automatically. Open manually:"
                print_info "  file://$DART_COVERAGE_DIR/index.html"
            fi
        fi
    fi
}

# Main execution
main() {
    parse_args "$@"

    print_section "Beatbox Trainer - Test Coverage Report"
    print_info "Project: $PROJECT_ROOT"
    print_info "Coverage threshold: ${OVERALL_THRESHOLD}% (overall), ${CRITICAL_THRESHOLD}% (critical)"

    check_dependencies
    clean_coverage

    # Run coverage based on options
    if $RUN_RUST; then
        run_rust_coverage
    fi

    if $RUN_DART; then
        run_dart_coverage
    fi

    # Generate unified report
    generate_unified_report
    write_summary_artifact

    # Check thresholds (this may exit with code 1)
    local threshold_result=0
    check_thresholds || threshold_result=$?

    # Open reports if requested
    open_report

    # Print final summary
    print_section "Coverage Report Complete"

    if $RUN_RUST; then
        print_info "Rust HTML Report: file://$RUST_COVERAGE_DIR/index.html"
    fi

    if $RUN_DART; then
        print_info "Dart HTML Report: file://$DART_COVERAGE_DIR/index.html"
    fi

    print_info "Unified Report: $COVERAGE_DIR/COVERAGE_REPORT.md"

    echo ""

    exit $threshold_result
}

# Run main function
main "$@"
