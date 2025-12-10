@echo off
REM Simple batch file to run the installer
REM This file should be pre-configured with Supabase credentials

echo ========================================
echo VigyanShaala MDM - Device Installer
echo ========================================
echo.
echo Please ensure you have Administrator privileges.
echo.

REM Replace these with your actual Supabase credentials
set SUPABASE_URL=https://YOUR_PROJECT.supabase.co
set SUPABASE_KEY=YOUR_ANON_KEY_HERE

REM Check for PowerShell
powershell.exe -ExecutionPolicy Bypass -Command "& '%~dp0INSTALL.ps1' -SupabaseUrl '%SUPABASE_URL%' -SupabaseKey '%SUPABASE_KEY%'"

pause

