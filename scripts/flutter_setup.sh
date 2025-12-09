#!/bin/bash
set -e

# Flutter & FVM Setup Script
# This script sets up FVM and Flutter for the project.
# It should be run after Android SDK is installed and ANDROID_HOME is set.

echo "Starting Flutter/FVM Setup..."

# Verify ANDROID_HOME is set
if [ -z "$ANDROID_HOME" ]; then
    echo "ERROR: ANDROID_HOME is not set. Please install Android SDK first."
    exit 1
fi

# --- 1. INSTALL FVM ---
echo "Installing FVM..."
curl -fsSL https://fvm.app/install.sh | bash

# Add FVM to PATH for this script session
export PATH="$HOME/.fvm_flutter/bin:$PATH"

# --- 2. INSTALL FLUTTER ---
echo "Installing Flutter..."
# FVM will read version from .fvmrc in the repo
fvm install

# --- 3. CONFIGURE PROJECT TO USE FVM ---
echo "Configuring project to use FVM Flutter..."
fvm use --force

# --- 4. CONFIGURE FLUTTER ---
echo "Configuring Flutter with Android SDK..."
fvm flutter config --android-sdk "$ANDROID_HOME"

# --- 5. VERIFY SETUP ---
echo "Verifying Flutter setup..."
fvm flutter doctor -v

# --- 6. CLEANUP ---
echo "Cleaning up FVM-generated git changes..."
# FVM modifies .gitignore, .vscode/settings.json, and creates .fvm/fvm_config.json
# We reset these since our repo already has the correct committed versions
git reset --hard HEAD
git clean -fd

echo "Flutter/FVM setup complete!"
