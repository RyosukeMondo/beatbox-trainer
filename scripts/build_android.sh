#!/bin/bash
set -e

echo "Building Flutter Android APK..."

# Add FVM to PATH
export PATH="$HOME/.fvm_flutter/bin:$PATH"

# Clean previous builds
fvm flutter clean

# Get dependencies
fvm flutter pub get

# Build APK
fvm flutter build apk --release

echo "Android build complete!"
echo "APK location: build/app/outputs/flutter-apk/app-release.apk"
