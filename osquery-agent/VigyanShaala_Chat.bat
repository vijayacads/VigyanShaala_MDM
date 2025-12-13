@echo off
cd /d "%~dp0"

REM Get environment variables from system
set SUPABASE_URL=%SUPABASE_URL%
set SUPABASE_KEY=%SUPABASE_ANON_KEY%

REM Check if script exists
if not exist "chat-interface.ps1" (
    echo ERROR: chat-interface.ps1 not found!
    echo.
    echo Please ensure the chat interface is installed.
    echo.
    pause
    exit /b 1
)

REM Run PowerShell script with error handling
powershell.exe -ExecutionPolicy Bypass -NoExit -File "chat-interface.ps1" -SupabaseUrl "%SUPABASE_URL%" -SupabaseKey "%SUPABASE_KEY%"

REM If PowerShell exits, keep window open
if errorlevel 1 (
    echo.
    echo ERROR: Chat interface failed to start.
    echo.
    echo Check that:
    echo 1. Environment variables SUPABASE_URL and SUPABASE_ANON_KEY are set
    echo 2. Device is enrolled in the MDM system
    echo.
    pause
)
