#!/bin/bash
# Build script pre Vercel

set -e

echo "Building Flutter web app..."

# Ensure Flutter is in PATH
if [ -d "flutter" ]; then
    export PATH="$PATH:`pwd`/flutter/bin"
fi

# Verify Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "ERROR: Flutter not found in PATH!"
    echo "Please ensure install_flutter.sh ran successfully."
    exit 1
fi

echo "Flutter version:"
flutter --version

# Get dependencies (should already be done in install, but ensure it's done)
echo "Getting Flutter dependencies..."
flutter pub get

# Build for web
echo "Building Flutter web app for production..."
flutter build web --release --base-href /

echo "Build completed! Output is in build/web/"
ls -la build/web/ | head -20

