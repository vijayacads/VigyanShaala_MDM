@echo off
REM VigyanShaala MDM Installer - Ready to Use!
REM Just run this file as Administrator

echo ========================================
echo VigyanShaala MDM - Device Installer
echo ========================================
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running installer with Administrator privileges...
    echo.
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0INSTALL.ps1"
) else (
    echo.
    echo ERROR: Administrator privileges required!
    echo.
    echo Please right-click on this file and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

