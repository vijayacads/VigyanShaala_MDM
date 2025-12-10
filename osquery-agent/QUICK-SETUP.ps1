# Quick Setup Script - Creates installer package with your Supabase credentials
# Run this to generate the installer for testing

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VigyanShaala MDM - Quick Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get Supabase credentials
Write-Host "Enter your Supabase credentials:" -ForegroundColor Yellow
Write-Host ""

$supabaseUrl = Read-Host "Supabase Project URL (e.g., https://xxxxx.supabase.co)"
$supabaseKey = Read-Host "Supabase Anon Key"

if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or [string]::IsNullOrWhiteSpace($supabaseKey)) {
    Write-Host "ERROR: Credentials cannot be empty!" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "Creating installer package..." -ForegroundColor Cyan
Write-Host ""

# Run the package creation script
& ".\create-installer-package.ps1" -SupabaseUrl $supabaseUrl -SupabaseKey $supabaseKey

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run migration: supabase/migrations/006_allow_anonymous_device_registration.sql" -ForegroundColor White
Write-Host "2. Extract VigyanShaala-MDM-Installer.zip on a test Windows machine" -ForegroundColor White
Write-Host "3. Run RUN-AS-ADMIN.bat (right-click, Run as Administrator)" -ForegroundColor White
Write-Host "4. Check dashboard to see if device appears" -ForegroundColor White
Write-Host ""

pause

