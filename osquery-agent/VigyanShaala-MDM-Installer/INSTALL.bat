@echo off
REM VigyanShaala MDM Installer - Pre-configured
echo ========================================
echo VigyanShaala MDM - Device Installer
echo ========================================
echo.

set SUPABASE_URL=https://thqinhphunrflwlshdmx.supabase.co
set SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRocWluaHBodW5yZmx3bHNoZG14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4Njk2ODcsImV4cCI6MjA4MTQ0NTY4N30.nVTHifwIDIozcqerE-X7zmebO6Pag8Ji-N3d4jetaQM

powershell.exe -ExecutionPolicy Bypass -Command "& '%~dp0INSTALL.ps1' -SupabaseUrl '%SUPABASE_URL%' -SupabaseKey '%SUPABASE_KEY%'"

pause
