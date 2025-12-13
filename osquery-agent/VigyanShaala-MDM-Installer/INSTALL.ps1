# Master Installer Script for VigyanShaala MDM
# This script installs osquery and runs device enrollment
# Run as Administrator

param(
    [Parameter(Mandatory=$true)]
    [string]$SupabaseUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$SupabaseKey
)

$ErrorActionPreference = "Stop"

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
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
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$osqueryAgentDir = Join-Path $scriptDir "osquery-agent"

# Check if osquery MSI exists (look in both root and osquery-agent folder)
$osqueryMsi = Get-ChildItem -Path $scriptDir -Filter "osquery-*.msi" -Recurse | Select-Object -First 1

if (-not $osqueryMsi) {
    Write-Host "ERROR: osquery MSI installer not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please download osquery from: https://osquery.io/downloads" -ForegroundColor Yellow
    Write-Host "Save it as 'osquery-5.20.0.msi' (or similar) in this folder." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Would you like to download it now? (Y/N)" -ForegroundColor Cyan
    $response = Read-Host
    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Host "Downloading osquery 5.20.0 (latest stable)..." -ForegroundColor Yellow
        $downloadUrl = "https://pkg.osquery.io/windows/osquery-5.20.0.msi"
        $osqueryMsiPath = Join-Path $osqueryAgentDir "osquery-5.20.0.msi"
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $osqueryMsiPath -UseBasicParsing
            $osqueryMsi = Get-Item $osqueryMsiPath
            Write-Host "Download complete!" -ForegroundColor Green
        } catch {
            Write-Host "ERROR: Failed to download osquery: $_" -ForegroundColor Red
            Write-Host "Please download manually from: https://osquery.io/downloads" -ForegroundColor Yellow
            pause
            exit 1
        }
    } else {
        pause
        exit 1
    }
}

Write-Host "Found osquery installer: $($osqueryMsi.Name)" -ForegroundColor Green
Write-Host ""

# Run the installation script
Write-Host "Installing osquery and configuring device..." -ForegroundColor Cyan
Write-Host ""

try {
    # If MSI is not in osquery-agent folder, copy it there
    $targetMsiPath = Join-Path $osqueryAgentDir $osqueryMsi.Name
    if ($osqueryMsi.FullName -ne $targetMsiPath) {
        Copy-Item $osqueryMsi.FullName $targetMsiPath -Force
        Write-Host "Copied osquery installer to osquery-agent folder" -ForegroundColor Gray
    }
    
    # Change to osquery-agent directory and run install script
    Push-Location $osqueryAgentDir
    & ".\install-osquery.ps1" `
        -OsqueryMsi $osqueryMsi.Name `
        -SupabaseUrl $SupabaseUrl `
        -SupabaseKey $SupabaseKey
    Pop-Location
    
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
    Write-Host "ERROR: Installation failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please contact administrator for support." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

pause

