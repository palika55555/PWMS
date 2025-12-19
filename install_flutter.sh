#!/bin/bash
# Install Flutter for Vercel build

# Don't exit on error immediately - log errors first
set -e
set -o pipefail

echo "=== Installing Flutter SDK ==="

# Configure git to allow all directories (fixes ownership issues in Vercel)
echo "Configuring git for Vercel build environment..."
git config --global --add safe.directory '*' || true
git config --global user.name "Vercel Build" || true
git config --global user.email "build@vercel.com" || true

# Check if Flutter is already installed
if [ -d "flutter" ] && [ -f "flutter/bin/flutter" ]; then
    echo "Flutter already installed, using existing installation..."
    export PATH="$PATH:`pwd`/flutter/bin"
    # Ensure git config is set for existing installation
    FLUTTER_DIR="`pwd`/flutter"
    git config --global --add safe.directory "$FLUTTER_DIR" || true
    git config --global --add safe.directory "$FLUTTER_DIR/bin/cache/pkg" || true
    git config --global --add safe.directory "$FLUTTER_DIR/bin/cache" || true
    
    # Suppress root warning
    export FLUTTER_ROOT_WARNING_SUPPRESSED=1
    
    flutter --version
    flutter pub get
    exit 0
fi

# Download and install Flutter
FLUTTER_VERSION="3.24.3"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

echo "Downloading Flutter ${FLUTTER_VERSION} from ${FLUTTER_URL}..."
if ! curl -L "$FLUTTER_URL" -o flutter.tar.xz; then
    echo "ERROR: Failed to download Flutter"
    exit 1
fi

echo "Extracting Flutter..."
if ! tar xf flutter.tar.xz; then
    echo "ERROR: Failed to extract Flutter"
    exit 1
fi

rm -f flutter.tar.xz
echo "Flutter extracted successfully"

export PATH="$PATH:`pwd`/flutter/bin"

# Fix git ownership issue for Flutter repository (set before any flutter commands)
echo "Configuring git for Flutter repository..."
FLUTTER_DIR="`pwd`/flutter"
git config --global --add safe.directory "$FLUTTER_DIR" || true
git config --global --add safe.directory "$FLUTTER_DIR/bin/cache/pkg" || true
git config --global --add safe.directory "$FLUTTER_DIR/bin/cache" || true

# Suppress root warning - it's expected in Vercel build environment
export FLUTTER_ROOT_WARNING_SUPPRESSED=1

echo "Flutter installed successfully!"
flutter --version

echo "Pre-configuring Flutter..."
flutter config --no-analytics

# Skip flutter doctor - not needed for web builds and would show Android/iOS warnings
echo "Skipping flutter doctor (not needed for web builds)..."

echo "Getting Flutter dependencies..."
if ! flutter pub get; then
    echo "ERROR: Failed to get Flutter dependencies"
    exit 1
fi

echo "=== Flutter installation completed successfully! ==="

