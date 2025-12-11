# Master Installer Script for VigyanShaala MDM
# Pre-configured with Supabase credentials

param(
    [Parameter(Mandatory=$false)]
    [string]$SupabaseUrl = "https://ujmcjezpmyvpiasfrwhm.supabase.co",
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqbWNqZXpwbXl2cGlhc2Zyd2htIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzOTQ2NzQsImV4cCI6MjA4MDk3MDY3NH0.LNeLEQs2K1AXyTG2vlCHyfRLpavFBSGgqjtwLoXdyMQ"
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
Set-Location "$scriptDir\osquery-agent"

# Check if osquery MSI exists
$osqueryMsi = Get-ChildItem -Path $scriptDir -Filter "osquery-*.msi" -Recurse | Select-Object -First 1

if ($null -eq $osqueryMsi) {
    $osqueryMsi = Get-ChildItem -Path $PSScriptRoot -Filter "osquery-*.msi" | Select-Object -First 1
}

if ($null -eq $osqueryMsi) {
    Write-Host "osquery installer not found. Downloading..." -ForegroundColor Yellow
    Write-Host ""
    $downloadUrl = "https://pkg.osquery.io/windows/osquery-5.11.0.msi"
    $osqueryMsiPath = Join-Path $scriptDir "osquery-5.11.0.msi"
    try {
        Write-Host "Downloading osquery (this may take a few minutes)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $downloadUrl -OutFile $osqueryMsiPath -UseBasicParsing
        $osqueryMsi = Get-Item $osqueryMsiPath
        Write-Host "Download complete!" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to download osquery: $_" -ForegroundColor Red
        Write-Host "Please download manually from: https://osquery.io/downloads" -ForegroundColor Yellow
        pause
        exit 1
    }
}

Write-Host "Installing osquery and configuring device..." -ForegroundColor Cyan
Write-Host ""

try {
    if ($osqueryMsi.DirectoryName -ne $PWD) {
        Copy-Item $osqueryMsi.FullName $PWD -Force
        $osqueryMsiName = $osqueryMsi.Name
    } else {
        $osqueryMsiName = $osqueryMsi.Name
    }
    
    & ".\install-osquery.ps1" `
        -OsqueryMsi $osqueryMsiName `
        -SupabaseUrl $SupabaseUrl `
        -SupabaseKey $SupabaseKey
    
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

