# Script to create installer package for teachers
# This packages everything needed for deployment

param(
    [Parameter(Mandatory=$true)]
    [string]$SupabaseUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$SupabaseAnonKey,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\VigyanShaala-MDM-Installer"
)

Write-Host "Creating installer package..." -ForegroundColor Cyan

# Create output directory
if (Test-Path $OutputPath) {
    Remove-Item $OutputPath -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputPath | Out-Null
New-Item -ItemType Directory -Path "$OutputPath\osquery-agent" | Out-Null

# Copy required files
$filesToCopy = @(
    "install-osquery.ps1",
    "enroll-device.ps1",
    "osquery.conf",
    "apply-website-blocklist.ps1",
    "apply-software-blocklist.ps1",
    "sync-blocklist-scheduled.ps1",
    "sync-software-blocklist-scheduled.ps1",
    "execute-commands.ps1",
    "chat-interface.ps1"
)

foreach ($file in $filesToCopy) {
    if (Test-Path $file) {
        Copy-Item $file "$OutputPath\osquery-agent\" -Force
        Write-Host "Copied: $file" -ForegroundColor Green
    } else {
        Write-Warning "File not found: $file"
    }
}

# Create configured INSTALL.bat
$installBatContent = @"
@echo off
REM VigyanShaala MDM Installer - Pre-configured
echo ========================================
echo VigyanShaala MDM - Device Installer
echo ========================================
echo.

set SUPABASE_URL=$SupabaseUrl
set SUPABASE_KEY=$SupabaseAnonKey

cd osquery-agent
powershell.exe -ExecutionPolicy Bypass -Command "& '%~dp0INSTALL.ps1' -SupabaseUrl '%SUPABASE_URL%' -SupabaseKey '%SUPABASE_KEY%'"

pause
"@

Set-Content -Path "$OutputPath\INSTALL.bat" -Value $installBatContent
Write-Host "Created: INSTALL.bat (pre-configured)" -ForegroundColor Green

# Copy INSTALL.ps1
Copy-Item "INSTALL.ps1" "$OutputPath\" -Force -ErrorAction SilentlyContinue

# Copy README
Copy-Item "README-TEACHER.md" "$OutputPath\README.txt" -Force -ErrorAction SilentlyContinue

# Create a simple launcher that checks admin
$launcherContent = @"
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
"@

Set-Content -Path "$OutputPath\RUN-AS-ADMIN.bat" -Value $launcherContent
Write-Host "Created: RUN-AS-ADMIN.bat" -ForegroundColor Green

# Create ZIP file
$zipPath = "$OutputPath.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Write-Host ""
Write-Host "Creating ZIP package..." -ForegroundColor Cyan
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($OutputPath, $zipPath)

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Package created successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Package location: $zipPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "To distribute:" -ForegroundColor Yellow
Write-Host "1. Share the ZIP file with teachers" -ForegroundColor White
Write-Host "2. Teachers extract and run RUN-AS-ADMIN.bat" -ForegroundColor White
Write-Host "3. If osquery MSI is needed, it will auto-download" -ForegroundColor White
Write-Host ""

