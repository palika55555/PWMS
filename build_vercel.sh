#!/bin/bash
# Build script pre Vercel (optimized)

set -e

echo "Building Flutter web app..."

# Configure git
git config --global --add safe.directory '*' || true

# Ensure Flutter is in PATH
if [ -d "flutter" ]; then
    export PATH="$PATH:`pwd`/flutter/bin"
    FLUTTER_DIR="`pwd`/flutter"
    git config --global --add safe.directory "$FLUTTER_DIR" || true
    git config --global --add safe.directory "$FLUTTER_DIR/bin/cache/pkg" || true
    git config --global --add safe.directory "$FLUTTER_DIR/bin/cache" || true
fi

export FLUTTER_ROOT_WARNING_SUPPRESSED=1

# Verify Flutter
if ! command -v flutter &> /dev/null; then
    echo "ERROR: Flutter not found in PATH!"
    exit 1
fi

echo "Flutter version:"
flutter --version

# Get dependencies (optimized - skip precompile)
echo "Getting Flutter dependencies..."
if [ -f "pubspec.lock" ]; then
    echo "pubspec.lock found, dependencies may be cached..."
fi

# Try to get dependencies with retry (skip precompile for faster build)
if ! flutter pub get --no-example --no-precompile; then
    echo "WARNING: flutter pub get failed, retrying..."
    flutter pub get --no-example --no-precompile || {
        echo "ERROR: Failed to get Flutter dependencies"
        exit 1
    }
fi

# Build for web (optimized - skip Skia for faster build)
echo "Building Flutter web app for production..."
flutter build web \
    --release \
    --base-href / \
    --no-tree-shake-icons \
    --dart-define=FLUTTER_WEB_USE_SKIA=false \
    --web-renderer canvaskit || \
flutter build web --release --base-href /

echo "Build completed! Output is in build/web/"

