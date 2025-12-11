# Super Simple Installer Creator
# Just provide your Supabase credentials and get a ready-to-use installer

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VigyanShaala MDM - Installer Creator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will create a complete installer package" -ForegroundColor Yellow
Write-Host "with your Supabase credentials pre-configured." -ForegroundColor Yellow
Write-Host ""
Write-Host "Teachers will just need to:" -ForegroundColor Green
Write-Host "  1. Extract ZIP" -ForegroundColor White
Write-Host "  2. Run INSTALL.bat as Administrator" -ForegroundColor White
Write-Host "  3. Fill enrollment form" -ForegroundColor White
Write-Host "  4. Done!" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get Supabase credentials
$supabaseUrl = Read-Host "Enter Supabase Project URL (e.g., https://xxxxx.supabase.co)"
$supabaseKey = Read-Host "Enter Supabase Anon Key"

if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or [string]::IsNullOrWhiteSpace($supabaseKey)) {
    Write-Host ""
    Write-Host "ERROR: Credentials cannot be empty!" -ForegroundColor Red
    pause
    exit 1
}

# Validate URL format
if ($supabaseUrl -notmatch '^https://.+\.supabase\.co$') {
    Write-Host ""
    Write-Host "WARNING: URL format looks incorrect. Expected: https://xxxxx.supabase.co" -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (Y/N)"
    if ($continue -ne 'Y' -and $continue -ne 'y') {
        exit 0
    }
}

Write-Host ""
Write-Host "Creating installer package..." -ForegroundColor Cyan
Write-Host ""

# Run the package creation script
try {
    & ".\create-installer-with-keys.ps1" -SupabaseUrl $supabaseUrl -SupabaseKey $supabaseKey
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "IMPORTANT: Before distributing, run this SQL in Supabase:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "File: supabase/migrations/006_allow_anonymous_device_registration.sql" -ForegroundColor White
    Write-Host ""
    Write-Host "This allows devices to register from the installer." -ForegroundColor Yellow
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "ERROR: Failed to create installer: $_" -ForegroundColor Red
    Write-Host ""
    pause
    exit 1
}

Write-Host "Ready to test!" -ForegroundColor Green
Write-Host ""
pause

