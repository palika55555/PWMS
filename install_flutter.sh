#!/bin/bash
# Install Flutter for Vercel build (optimized with cache)

set -e
set -o pipefail

echo "=== Installing Flutter SDK ==="

# Configure git
git config --global --add safe.directory '*' || true
git config --global user.name "Vercel Build" || true
git config --global user.email "build@vercel.com" || true

# Cache directory for Flutter SDK
# Vercel preserves /tmp between builds, so use that for caching
CACHE_DIR="/tmp/flutter-cache"
FLUTTER_VERSION="3.38.5"

# Check cache first (Vercel preserves /tmp between builds)
if [ -d "$CACHE_DIR/flutter" ] && [ -f "$CACHE_DIR/flutter/bin/flutter" ]; then
    echo "Using cached Flutter SDK from $CACHE_DIR..."
    cp -r "$CACHE_DIR/flutter" ./flutter
    export PATH="$PATH:`pwd`/flutter/bin"
    FLUTTER_DIR="`pwd`/flutter"
    git config --global --add safe.directory "$FLUTTER_DIR" || true
    git config --global --add safe.directory "$FLUTTER_DIR/bin/cache/pkg" || true
    git config --global --add safe.directory "$FLUTTER_DIR/bin/cache" || true
    export FLUTTER_ROOT_WARNING_SUPPRESSED=1
    flutter --version
    flutter config --no-analytics
    echo "=== Using cached Flutter SDK ==="
    exit 0
fi

# Check if Flutter is already in current directory
if [ -d "flutter" ] && [ -f "flutter/bin/flutter" ]; then
    echo "Flutter already installed, using existing installation..."
    export PATH="$PATH:`pwd`/flutter/bin"
    FLUTTER_DIR="`pwd`/flutter"
    git config --global --add safe.directory "$FLUTTER_DIR" || true
    git config --global --add safe.directory "$FLUTTER_DIR/bin/cache/pkg" || true
    git config --global --add safe.directory "$FLUTTER_DIR/bin/cache" || true
    export FLUTTER_ROOT_WARNING_SUPPRESSED=1
    flutter --version
    flutter config --no-analytics
    
    # Cache for next build (Vercel preserves /tmp)
    mkdir -p "$CACHE_DIR"
    cp -r flutter "$CACHE_DIR/flutter" 2>/dev/null || true
    echo "Flutter cached to $CACHE_DIR for future builds"
    
    exit 0
fi

# Download Flutter (with progress bar)
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

echo "Downloading Flutter ${FLUTTER_VERSION} (this may take a minute)..."
if command -v wget &> /dev/null; then
    wget --progress=bar:force "$FLUTTER_URL" -O flutter.tar.xz 2>&1
else
    curl -L --progress-bar "$FLUTTER_URL" -o flutter.tar.xz
fi

echo "Extracting Flutter..."
tar xf flutter.tar.xz
rm -f flutter.tar.xz

# Cache Flutter for next build (Vercel preserves /tmp between builds)
mkdir -p "$CACHE_DIR"
cp -r flutter "$CACHE_DIR/flutter" 2>/dev/null || true
echo "Flutter cached to $CACHE_DIR for future builds"

export PATH="$PATH:`pwd`/flutter/bin"

# Configure git
FLUTTER_DIR="`pwd`/flutter"
git config --global --add safe.directory "$FLUTTER_DIR" || true
git config --global --add safe.directory "$FLUTTER_DIR/bin/cache/pkg" || true
git config --global --add safe.directory "$FLUTTER_DIR/bin/cache" || true
export FLUTTER_ROOT_WARNING_SUPPRESSED=1

echo "Flutter installed successfully!"
flutter --version
flutter config --no-analytics

echo "=== Flutter installation completed! ==="

