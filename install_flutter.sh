#!/bin/bash
# Install Flutter for Vercel build

set -e

echo "=== Installing Flutter SDK ==="

# Check if Flutter is already installed
if [ -d "flutter" ] && [ -f "flutter/bin/flutter" ]; then
    echo "Flutter already installed, using existing installation..."
    export PATH="$PATH:`pwd`/flutter/bin"
    flutter --version
    flutter pub get
    exit 0
fi

# Download and install Flutter
FLUTTER_VERSION="3.24.3"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

echo "Downloading Flutter ${FLUTTER_VERSION} from ${FLUTTER_URL}..."
curl -L "$FLUTTER_URL" -o flutter.tar.xz
tar xf flutter.tar.xz
rm flutter.tar.xz

export PATH="$PATH:`pwd`/flutter/bin"

echo "Flutter installed successfully!"
flutter --version

echo "Pre-configuring Flutter (this may take a moment)..."
flutter config --no-analytics
flutter doctor || true

echo "Getting Flutter dependencies..."
flutter pub get

echo "=== Flutter installation completed! ==="

