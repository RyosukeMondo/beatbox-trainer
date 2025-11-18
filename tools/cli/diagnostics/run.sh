#!/usr/bin/env bash
# bbt-diag wrapper to simplify local + CI runs.
# Usage:
#   tools/cli/diagnostics/run.sh run --synthetic sine --watch-ms 1000
#   tools/cli/diagnostics/run.sh record --fixture rust/fixtures/basic_hits.wav --output logs/smoke/basic.json
set -euo pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
LOG_DIR="$PROJECT_ROOT/logs/diagnostics"
mkdir -p "$LOG_DIR"

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
