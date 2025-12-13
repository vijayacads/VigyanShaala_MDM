@echo off
REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running installer with Administrator privileges...
    echo.
    call INSTALL.bat
) else (
    echo ERROR: Administrator privileges required!
    echo.
    echo Please right-click on this file and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)
