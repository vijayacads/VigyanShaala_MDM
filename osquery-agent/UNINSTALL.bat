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
    
    REM Try to run from installed location first
    if exist "C:\Program Files\osquery\uninstall-osquery.ps1" (
        powershell.exe -ExecutionPolicy Bypass -File "C:\Program Files\osquery\uninstall-osquery.ps1" -RemoveFromSupabase
    ) else if exist "%~dp0osquery-agent\uninstall-osquery.ps1" (
        REM If not installed, try from installer package
        powershell.exe -ExecutionPolicy Bypass -File "%~dp0osquery-agent\uninstall-osquery.ps1" -RemoveFromSupabase
    ) else if exist "%~dp0uninstall-osquery.ps1" (
        REM Try current directory (for GitHub folder or standalone)
        powershell.exe -ExecutionPolicy Bypass -File "%~dp0uninstall-osquery.ps1" -RemoveFromSupabase
    ) else (
        echo ERROR: Uninstall script not found!
        echo.
        echo Please ensure the MDM agent is installed, or run this from:
        echo   - The installer package folder
        echo   - The osquery-agent folder in GitHub
        echo   - Or place uninstall-osquery.ps1 in the same folder as this batch file
        echo.
        pause
        exit /b 1
    )
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
