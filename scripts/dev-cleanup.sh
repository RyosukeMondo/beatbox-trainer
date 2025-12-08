#!/bin/bash
# dev-cleanup.sh - Clean up stale development processes
#
# Use this script before starting a new development session to ensure
# no zombie processes from previous sessions are consuming resources.

set -e

echo "=== Beatbox Trainer Development Cleanup ==="

# Kill any running Flutter processes
echo "Cleaning up Flutter processes..."
pkill -f "flutter run" 2>/dev/null || true
pkill -f "flutter_tools" 2>/dev/null || true

# Kill any running app instances
echo "Cleaning up app instances..."
killall beatbox_trainer 2>/dev/null || true

# Kill any stale Dart processes
echo "Cleaning up Dart processes..."
pkill -f "dart:flutter_tools" 2>/dev/null || true

# Kill any debug server instances
echo "Cleaning up debug servers..."
pkill -f "debug-server" 2>/dev/null || true

# Check for any remaining processes
echo ""
echo "=== Remaining processes (if any) ==="
ps aux | grep -E "(flutter|beatbox|dart)" | grep -v grep || echo "None found"

echo ""
echo "=== Cleanup complete ==="
echo ""
echo "To start the app fresh:"
echo "  cd $(dirname "$0")/.."
echo "  cargo build"
echo "  cp rust/target/debug/libbeatbox_trainer.so build/linux/x64/debug/bundle/lib/"
echo "  LD_LIBRARY_PATH=rust/target/debug flutter run -d linux"
