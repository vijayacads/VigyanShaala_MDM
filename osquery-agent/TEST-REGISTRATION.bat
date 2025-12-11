@echo off
REM Simple test script - just double-click this file
REM Tests if device registration works

echo ========================================
echo Testing Device Registration
echo ========================================
echo.

cd /d "%~dp0"

powershell.exe -ExecutionPolicy Bypass -File "enroll-device-debug.ps1"

echo.
echo ========================================
pause

