#!/bin/bash
set -e

# Jules CI Setup Script for Flutter Build Environment
# This script sets up the complete build environment including:
# - System dependencies
# - Android SDK
# - Flutter/FVM (via modular script)

echo "Starting Jules CI Setup..."

# --- 1. PREPARATION & SYSTEM DEPENDENCIES ---
echo "Installing system dependencies..."

# Ensure we are in the app directory
cd /app

sudo apt-get update
sudo apt-get install -y wget unzip curl git
sudo apt-get install -y openjdk-17-jdk


# --- 2. ANDROID SDK SETUP ---
echo "Setting up Android SDK..."

export ANDROID_HOME=$HOME/android-sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

mkdir -p $ANDROID_HOME/cmdline-tools

echo "Downloading Android Command Line Tools..."
wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip

unzip -q cmdline-tools.zip -d $ANDROID_HOME/cmdline-tools
mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest
rm cmdline-tools.zip

echo "Installing Android SDK Platforms and Tools..."
yes | sdkmanager --licenses > /dev/null
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# --- 3. FLUTTER SETUP ---
echo "Running Flutter setup..."
bash scripts/flutter_setup.sh

# --- 4. DONE ---
echo "Jules CI Setup Complete!"
