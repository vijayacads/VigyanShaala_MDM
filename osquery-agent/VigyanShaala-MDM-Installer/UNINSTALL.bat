@echo off
REM Uninstaller for VigyanShaala MDM osquery Agent
REM Run as Administrator

echo ========================================
echo VigyanShaala MDM - Uninstaller
echo ========================================
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running uninstaller with Administrator privileges...
    echo.
    cd osquery-agent
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0uninstall-osquery.ps1" -RemoveFromSupabase
) else (
    echo.
    echo ERROR: Administrator privileges required!
    echo.
    echo Please right-click on this file and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)
pause
