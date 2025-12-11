@echo off
REM VigyanShaala MDM - Complete Device Installer
REM This installer sets up:
REM   - Osquery agent (monitoring)
REM   - Website blocking (all browsers)
REM   - Software blocking (automatic removal)
REM   - Device enrollment

echo ========================================
echo VigyanShaala MDM - Device Installer
echo ========================================
echo.
echo This installer will:
echo   - Install osquery monitoring agent
echo   - Set up website blocking (all browsers)
echo   - Set up software blocking (automatic removal)
echo   - Enroll device in MDM system
echo.
echo Please ensure you have Administrator privileges.
echo.

REM Replace these with your actual Supabase credentials
set SUPABASE_URL=https://YOUR_PROJECT.supabase.co
set SUPABASE_KEY=YOUR_ANON_KEY_HERE

REM Check for PowerShell and run installer
powershell.exe -ExecutionPolicy Bypass -Command "& '%~dp0INSTALL.ps1' -SupabaseUrl '%SUPABASE_URL%' -SupabaseKey '%SUPABASE_KEY%'"

pause

