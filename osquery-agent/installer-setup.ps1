# OSQuery Agent Installer Setup Script
# This script prepares the environment for osquery installation
# Run this before packaging the MSI installer

param(
    [string]$OsqueryVersion = "5.11.0",
    [string]$InstallDir = "$env:ProgramFiles\osquery"
)

Write-Host "Preparing osquery agent installer environment..." -ForegroundColor Green

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# Create installation directory structure
$directories = @(
    "$InstallDir",
    "$InstallDir\logs",
    "$InstallDir\packs",
    "$InstallDir\config"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created directory: $dir" -ForegroundColor Yellow
    }
}

# Copy configuration files
if (Test-Path "osquery.conf") {
    Copy-Item "osquery.conf" "$InstallDir\config\osquery.conf" -Force
    Write-Host "Copied osquery.conf" -ForegroundColor Yellow
} else {
    Write-Warning "osquery.conf not found in current directory"
}

if (Test-Path "enroll-fleet.ps1") {
    Copy-Item "enroll-fleet.ps1" "$InstallDir\enroll-fleet.ps1" -Force
    Write-Host "Copied enroll-fleet.ps1" -ForegroundColor Yellow
} else {
    Write-Warning "enroll-fleet.ps1 not found in current directory"
}

# Download osquery (if not already present)
$osqueryMsi = "osquery-$OsqueryVersion.msi"
if (-not (Test-Path $osqueryMsi)) {
    Write-Host "Downloading osquery $OsqueryVersion..." -ForegroundColor Yellow
    $downloadUrl = "https://pkg.osquery.io/windows/osquery-$OsqueryVersion.msi"
    
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $osqueryMsi -UseBasicParsing
        Write-Host "Downloaded: $osqueryMsi" -ForegroundColor Green
    } catch {
        Write-Error "Failed to download osquery: $_"
        Write-Host "Please download manually from: https://osquery.io/downloads"
    }
} else {
    Write-Host "osquery MSI already present: $osqueryMsi" -ForegroundColor Green
}

Write-Host "`nInstallation preparation complete!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Review and configure osquery.conf" -ForegroundColor White
Write-Host "2. Update enroll-fleet.ps1 with your Supabase/Fleet URLs" -ForegroundColor White
Write-Host "3. Package everything into an MSI using WiX Toolset" -ForegroundColor White
Write-Host "4. Or use this directory structure with a custom installer" -ForegroundColor White
