#!/bin/bash
# Build script pre Vercel

echo "Building Flutter web app..."
flutter build web --release

echo "Build completed! Output is in build/web/"

