@echo off
REM Build script pre Vercel (Windows)

echo Building Flutter web app...
flutter build web --release

echo Build completed! Output is in build/web/

