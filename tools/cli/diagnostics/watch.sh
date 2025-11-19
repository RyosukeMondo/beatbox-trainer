#!/usr/bin/env bash
# watch.sh — rerun diagnostics playbooks with baseline diffing when files change.
# Requires Dart/Flutter SDK for `dart run`.

set -euo pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SCENARIO="default-smoke"
BASELINE=""
MANIFEST=""
DEBOUNCE=5
WATCH_PATHS=()

usage() {
    cat <<'USAGE'
Usage: tools/cli/diagnostics/watch.sh [options]

Options:
  --scenario <id>       Scenario id to execute (default-smoke)
  --manifest <path>     Optional playbook manifest override
  --baseline <path>     Optional baseline snapshot path
  --debounce <seconds>  Debounce duration for reruns (min 5, default 5)
  --watch-path <path>   Additional path to watch (may repeat)
  --help                Show this help text

The script streams playbook output inline and runs the baseline diff after
each change. Press Ctrl+C to exit.
USAGE
}

is_absolute() {
    case "$1" in
        /*) return 0 ;;
        ?:/*) return 0 ;; # Windows drive letter
    esac
    return 1
}

make_absolute() {
    if is_absolute "$1"; then
        printf '%s' "$1"
    else
        printf '%s/%s' "$PROJECT_ROOT" "$1"
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --scenario)
            [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 64; }
            SCENARIO="$2"
            shift 2
            ;;
        --manifest)
            [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 64; }
            MANIFEST=$(make_absolute "$2")
            shift 2
            ;;
        --baseline)
            [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 64; }
            BASELINE=$(make_absolute "$2")
            shift 2
            ;;
        --debounce)
            [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 64; }
            DEBOUNCE="$2"
            shift 2
            ;;
        --watch-path)
            [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 64; }
            WATCH_PATHS+=("$(make_absolute "$2")")
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 64
            ;;
    esac
done

if ! command -v dart >/dev/null 2>&1; then
    echo "dart command not found in PATH" >&2
    exit 1
fi

if [ "$DEBOUNCE" -lt 5 ]; then
    echo "Debounce must be at least 5 seconds" >&2
    exit 64
fi

CMD=(
    dart run tools/cli/diagnostics/lib/baseline_diff.dart
    --project-root "$PROJECT_ROOT"
    --scenario "$SCENARIO"
    --watch
    --run-playbook
    --debounce-seconds "$DEBOUNCE"
)

if [ -n "$MANIFEST" ]; then
    CMD+=(--manifest "$MANIFEST")
fi

if [ -n "$BASELINE" ]; then
    CMD+=(--baseline "$BASELINE")
fi

for path in "${WATCH_PATHS[@]}"; do
    CMD+=(--watch-path "$path")
done

exec "${CMD[@]}"
