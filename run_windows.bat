@echo off
echo Running ProBlock PWMS on Windows...
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

REM Run Windows app
echo.
echo Starting Windows application...
call flutter run -d windows
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to run application
    pause
    exit /b 1
)

pause







