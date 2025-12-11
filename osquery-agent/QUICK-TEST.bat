@echo off
REM Quick Test - Double-click this file to test device registration
REM This will try to register your device and show you any errors

echo ========================================
echo Quick Device Registration Test
echo ========================================
echo.
echo This will test if device registration works.
echo.
pause

cd /d "%~dp0"

powershell.exe -ExecutionPolicy Bypass -File "SIMPLE-TEST.ps1"

pause

