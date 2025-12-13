@echo off
REM VigyanShaala MDM Installer - Pre-configured
echo ========================================
echo VigyanShaala MDM - Device Installer
echo ========================================
echo.

set SUPABASE_URL=https://ujmcjezpmyvpiasfrwhm.supabase.co
set SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqbWNqZXpwbXl2cGlhc2Zyd2htIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzOTQ2NzQsImV4cCI6MjA4MDk3MDY3NH0.LNeLEQs2K1AXyTG2vlCHyfRLpavFBSGgqjtwLoXdyMQ

cd osquery-agent
powershell.exe -ExecutionPolicy Bypass -Command "& '%~dp0INSTALL.ps1' -SupabaseUrl '%SUPABASE_URL%' -SupabaseKey '%SUPABASE_KEY%'"

pause
