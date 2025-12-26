@echo off
echo Building ProBlock PWMS for Windows...
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter is not installed or not in PATH
    echo Please install Flutter and add it to your PATH
    pause
    exit /b 1
)

REM Get dependencies
echo Getting Flutter dependencies...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)

REM Build Windows app
echo.
echo Building Windows application...
call flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Build failed
    pause
    exit /b 1
)

echo.
echo Build completed successfully!
echo The application is in: build\windows\runner\Release\problock_pwms.exe
echo.
pause







