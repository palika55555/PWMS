#!/bin/bash
# Build script pre Vercel

set -e

echo "Building Flutter web app..."

# Configure git to allow all directories (fixes ownership issues in Vercel)
echo "Configuring git for Vercel build environment..."
git config --global --add safe.directory '*' || true

# Ensure Flutter is in PATH
if [ -d "flutter" ]; then
    export PATH="$PATH:`pwd`/flutter/bin"
    # Fix git ownership for Flutter directory
    FLUTTER_DIR="`pwd`/flutter"
    git config --global --add safe.directory "$FLUTTER_DIR" || true
    git config --global --add safe.directory "$FLUTTER_DIR/bin/cache/pkg" || true
    git config --global --add safe.directory "$FLUTTER_DIR/bin/cache" || true
fi

# Suppress root warning (expected in Vercel build environment)
export FLUTTER_ROOT_WARNING_SUPPRESSED=1

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

