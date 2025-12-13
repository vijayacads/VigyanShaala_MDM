# sync-installer-package.ps1
# Syncs all updated files to the installer package

$ErrorActionPreference = "Stop"

Write-Host "=== Syncing Files to Installer Package ===" -ForegroundColor Cyan
Write-Host ""

$installerPath = "VigyanShaala-MDM-Installer\osquery-agent"

# Ensure installer directory exists
if (-not (Test-Path $installerPath)) {
    New-Item -ItemType Directory -Path $installerPath -Force | Out-Null
    Write-Host "Created installer directory: $installerPath" -ForegroundColor Green
}

# Files to sync
$filesToSync = @(
    "install-osquery.ps1",
    "enroll-device.ps1",
    "osquery.conf",
    "apply-website-blocklist.ps1",
    "apply-software-blocklist.ps1",
    "sync-blocklist-scheduled.ps1",
    "sync-software-blocklist-scheduled.ps1",
    "send-osquery-data.ps1",
    "trigger-osquery-queries.ps1",
    "get-battery-wmi.ps1",
    "execute-commands.ps1",
    "chat-interface.ps1",
    "VigyanShaala_Chat.bat",
    "uninstall-osquery.ps1"
)

$synced = 0
$skipped = 0
$missing = 0

foreach ($file in $filesToSync) {
    if (Test-Path $file) {
        $destPath = "$installerPath\$file"
        Copy-Item $file $destPath -Force
        Write-Host "  [SYNCED] $file" -ForegroundColor Green
        $synced++
    } else {
        Write-Host "  [MISSING] $file (not found in source)" -ForegroundColor Yellow
        $missing++
    }
}

Write-Host ""
Write-Host "=== Sync Complete ===" -ForegroundColor Cyan
Write-Host "  Synced: $synced files" -ForegroundColor Green
Write-Host "  Missing: $missing files" -ForegroundColor $(if ($missing -gt 0) { "Yellow" } else { "Green" })
Write-Host ""

# Also sync the installer package script itself
if (Test-Path "create-installer-package.ps1") {
    Write-Host "Installer package script is up to date" -ForegroundColor Green
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review the synced files" -ForegroundColor White
Write-Host "  2. Run create-installer-package.ps1 to create the final ZIP" -ForegroundColor White
Write-Host "  3. Test the installer on a clean system" -ForegroundColor White

