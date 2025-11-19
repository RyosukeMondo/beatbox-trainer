#!/usr/bin/env bash
# bbt-diag wrapper to simplify local + CI runs.
# Usage:
#   tools/cli/diagnostics/run.sh run --synthetic sine --watch-ms 1000
#   tools/cli/diagnostics/run.sh record --fixture rust/fixtures/basic_hits.wav --output logs/smoke/basic.json
set -euo pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
LOG_DIR="$PROJECT_ROOT/logs/diagnostics"
mkdir -p "$LOG_DIR"

if [ $# -gt 0 ] && [ "$1" = "--scenario" ]; then
    shift
    SCENARIO="default-smoke"
    if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
        SCENARIO="$1"
        shift
    fi

    MANIFEST_PATH="$PROJECT_ROOT/tools/cli/diagnostics/playbooks/keynote.yaml"
    EXTRA_ARGS=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --manifest|-m)
                if [ $# -lt 2 ]; then
                    echo "Missing value for $1" >&2
                    exit 64
                fi
                shift
                if [[ "$1" = /* ]]; then
                    MANIFEST_PATH="$1"
                else
                    MANIFEST_PATH="$PROJECT_ROOT/$1"
                fi
                ;;
            --dry-run)
                EXTRA_ARGS+=(--dry-run)
                ;;
            --help|-h)
                EXTRA_ARGS+=(--help)
                ;;
            *)
                echo "Unknown playbook runner flag: $1" >&2
                exit 64
                ;;
        esac
        shift
    done

    RUNNER_ARGS=(
        --project-root "$PROJECT_ROOT"
        --manifest "$MANIFEST_PATH"
        --scenario "$SCENARIO"
    )

    if [ ${#EXTRA_ARGS[@]} -gt 0 ]; then
        RUNNER_ARGS+=("${EXTRA_ARGS[@]}")
    fi

    (
        cd "$PROJECT_ROOT"
        dart run tools/cli/diagnostics/lib/playbook_runner.dart "${RUNNER_ARGS[@]}"
    )
    exit $?
fi

FEATURES="${BBT_DIAG_FEATURES:-diagnostics_fixtures}"
CARGO_PROFILE="${BBT_DIAG_PROFILE:-debug}"
ARGS=("$@")

if [ ${#ARGS[@]} -eq 0 ]; then
    ARGS=(run --synthetic sine --watch-ms 1500 --telemetry-format table)
fi

LOG_FILE="$LOG_DIR/bbt-diag-$(date -Iseconds).log"

echo "[bbt-diag] features=$FEATURES profile=$CARGO_PROFILE" | tee "$LOG_FILE"
(
    cd "$PROJECT_ROOT/rust"
    if [ "$CARGO_PROFILE" = "release" ]; then
        cargo run --release --features "$FEATURES" --bin bbt-diag -- "${ARGS[@]}"
    else
        cargo run --features "$FEATURES" --bin bbt-diag -- "${ARGS[@]}"
    fi
) | tee -a "$LOG_FILE"

echo "bbt-diag log written to $LOG_FILE"
