#!/bin/bash
# Build script pre Vercel

set -e

echo "Building Flutter web app..."

# Ensure Flutter is in PATH (should be set by installCommand)
export PATH="$PATH:`pwd`/flutter/bin"

# Verify Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "Flutter not found in PATH. Installing..."
    curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.3-stable.tar.xz | tar xJ
    export PATH="$PATH:`pwd`/flutter/bin"
fi

# Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Build for web
echo "Building Flutter web app..."
flutter build web --release --base-href /

echo "Build completed! Output is in build/web/"

