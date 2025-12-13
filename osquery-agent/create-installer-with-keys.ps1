# Create installer package with Supabase keys pre-configured
# This creates a completely ready-to-use installer - no configuration needed!

param(
    [Parameter(Mandatory=$true)]
    [string]$SupabaseUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$SupabaseAnonKey,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\VigyanShaala-MDM-Installer"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Creating Installer Package" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create output directory
if (Test-Path $OutputPath) {
    Remove-Item $OutputPath -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputPath | Out-Null
New-Item -ItemType Directory -Path "$OutputPath\osquery-agent" | Out-Null

Write-Host "Copying files..." -ForegroundColor Yellow

# Copy required files
$filesToCopy = @(
    "install-osquery.ps1",
    "enroll-device.ps1",
    "osquery.conf",
    "apply-website-blocklist.ps1",
    "apply-software-blocklist.ps1",
    "sync-blocklist-scheduled.ps1",
    "sync-software-blocklist-scheduled.ps1",
    "send-osquery-data.ps1",
    "trigger-osquery-queries.ps1",  # For debugging/manual testing
    "get-battery-wmi.ps1",  # WMI-based battery data collection
    "execute-commands.ps1",
    "user-notify-agent.ps1",  # User-session notification agent for buzz/toast
    "chat-interface.ps1",
    "VigyanShaala_Chat.bat",
    "uninstall-osquery.ps1"
)

foreach ($file in $filesToCopy) {
    if (Test-Path $file) {
        # For PowerShell files, preserve UTF-8 BOM encoding (needed for emojis)
        if ($file -like "*.ps1") {
            $content = Get-Content $file -Raw
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText("$OutputPath\osquery-agent\$file", $content, $utf8WithBom)
            Write-Host "  ✓ $file (with UTF-8 BOM)" -ForegroundColor Green
        } else {
            Copy-Item $file "$OutputPath\osquery-agent\" -Force
            Write-Host "  ✓ $file" -ForegroundColor Green
        }
    } else {
        Write-Warning "  ✗ File not found: $file"
    }
}

# Copy Logo.png if it exists (for chat interface and desktop shortcut)
if (Test-Path "Logo.png") {
    Copy-Item "Logo.png" "$OutputPath\osquery-agent\" -Force
    Write-Host "  ✓ Logo.png" -ForegroundColor Green
} elseif (Test-Path "..\dashboard\public\Logo.png") {
    Copy-Item "..\dashboard\public\Logo.png" "$OutputPath\osquery-agent\" -Force
    Write-Host "  ✓ Logo.png (from dashboard)" -ForegroundColor Green
}

# Create INSTALL.ps1 with keys baked in
$supabaseUrlEscaped = $SupabaseUrl -replace '"', '`"'
$supabaseKeyEscaped = $SupabaseAnonKey -replace '"', '`"'

$installPs1Content = @"
# Master Installer Script for VigyanShaala MDM
# Pre-configured with Supabase credentials

param(
    [Parameter(Mandatory=`$false)]
    [string]`$SupabaseUrl = "$supabaseUrlEscaped",
    
    [Parameter(Mandatory=`$false)]
    [string]`$SupabaseKey = "$supabaseKeyEscaped"
)

`$ErrorActionPreference = "Stop"

# Check for Administrator privileges
`$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not `$isAdmin) {
    Write-Host "ERROR: This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VigyanShaala MDM - Device Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get script directory
`$scriptDir = Split-Path -Parent `$MyInvocation.MyCommand.Path
Set-Location `$scriptDir

# Check if osquery MSI exists
`$osqueryMsi = Get-ChildItem -Path `$scriptDir -Filter "osquery-*.msi" | Select-Object -First 1

if (-not `$osqueryMsi) {
    Write-Host "osquery installer not found. Downloading..." -ForegroundColor Yellow
    Write-Host ""
    `$downloadUrl = "https://pkg.osquery.io/windows/osquery-5.11.0.msi"
    `$osqueryMsiPath = Join-Path `$scriptDir "osquery-5.11.0.msi"
    try {
        Write-Host "Downloading osquery (this may take a few minutes)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri `$downloadUrl -OutFile `$osqueryMsiPath -UseBasicParsing
        `$osqueryMsi = Get-Item `$osqueryMsiPath
        Write-Host "Download complete!" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to download osquery: `$_" -ForegroundColor Red
        Write-Host "Please download manually from: https://osquery.io/downloads" -ForegroundColor Yellow
        pause
        exit 1
    }
}

Write-Host "Installing osquery and configuring device..." -ForegroundColor Cyan
Write-Host ""

try {
    & "`$scriptDir\install-osquery.ps1" `
        -OsqueryMsi `$osqueryMsi.Name `
        -SupabaseUrl `$SupabaseUrl `
        -SupabaseKey `$SupabaseKey
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your device should now appear in the dashboard." -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "ERROR: Installation failed: `$_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please contact administrator for support." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

pause
"@

Set-Content -Path "$OutputPath\INSTALL.ps1" -Value $installPs1Content -Encoding UTF8
Write-Host "  ✓ INSTALL.ps1 (with pre-configured keys)" -ForegroundColor Green

# Create simple launcher batch file
$launcherBat = @"
@echo off
REM VigyanShaala MDM Installer - Ready to Use!
REM Just run this file as Administrator

echo ========================================
echo VigyanShaala MDM - Device Installer
echo ========================================
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %%errorLevel%% == 0 (
    echo Running installer with Administrator privileges...
    echo.
    cd osquery-agent
    powershell.exe -ExecutionPolicy Bypass -Command "& '%~dp0INSTALL.ps1'"
) else (
    echo.
    echo ERROR: Administrator privileges required!
    echo.
    echo Please right-click on this file and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)
"@

Set-Content -Path "$OutputPath\INSTALL.bat" -Value $launcherBat -Encoding ASCII
Write-Host "  ✓ INSTALL.bat" -ForegroundColor Green

# Also create RUN-AS-ADMIN.bat (same as INSTALL.bat for clarity)
Copy-Item "$OutputPath\INSTALL.bat" "$OutputPath\RUN-AS-ADMIN.bat"
Write-Host "  ✓ RUN-AS-ADMIN.bat" -ForegroundColor Green

# Copy README
if (Test-Path "README-TEACHER.md") {
    Copy-Item "README-TEACHER.md" "$OutputPath\README.txt" -Force
    Write-Host "  ✓ README.txt" -ForegroundColor Green
}

# Create simple instructions file
$instructions = @"
========================================
VigyanShaala MDM - Device Installer
========================================

INSTALLATION INSTRUCTIONS:
==========================

1. Right-click on "INSTALL.bat" or "RUN-AS-ADMIN.bat"
2. Select "Run as Administrator"
3. Wait for installation to complete
4. Fill in the enrollment form when it appears
5. Done! Your device will appear in the dashboard.

REQUIRED INFORMATION:
- Device Inventory Code (e.g., INV-001)
- Host Location (e.g., Computer Lab, Classroom 101)
- Latitude and Longitude (use Google Maps to find)
- School Location (select from dropdown)

TROUBLESHOOTING:
- If installation fails, ensure you're running as Administrator
- Check your internet connection
- Contact administrator if problems persist

========================================
"@

Set-Content -Path "$OutputPath\INSTRUCTIONS.txt" -Value $instructions -Encoding UTF8
Write-Host "  ✓ INSTRUCTIONS.txt" -ForegroundColor Green

# Create ZIP file
$zipPath = "$OutputPath.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Write-Host ""
Write-Host "Creating ZIP package..." -ForegroundColor Yellow
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($OutputPath, $zipPath)

$zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Package Created Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Package: $zipPath" -ForegroundColor Cyan
Write-Host "Size: $zipSize MB" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Supabase credentials pre-configured" -ForegroundColor Green
Write-Host "✓ No configuration needed by teachers" -ForegroundColor Green
Write-Host "✓ Ready to distribute!" -ForegroundColor Green
Write-Host ""
Write-Host "DISTRIBUTION:" -ForegroundColor Yellow
Write-Host "1. Share the ZIP file with teachers" -ForegroundColor White
Write-Host "2. Teachers extract and run INSTALL.bat as Administrator" -ForegroundColor White
Write-Host "3. That's it! No editing required." -ForegroundColor White
Write-Host ""

