# Update Installed Script
# Copies the latest realtime-command-listener.ps1 to the installed location
# Run as Administrator

$InstallDir = "C:\Program Files\osquery"
$scriptName = "realtime-command-listener.ps1"
$sourceScript = Join-Path $PSScriptRoot $scriptName
$targetScript = Join-Path $InstallDir $scriptName

Write-Host "Updating installed script..." -ForegroundColor Cyan

# Check if source exists
if (-not (Test-Path $sourceScript)) {
    Write-Host "ERROR: Source script not found: $sourceScript" -ForegroundColor Red
    Write-Host "Make sure you're running this from the osquery-agent directory" -ForegroundColor Yellow
    exit 1
}

# Check if install directory exists
if (-not (Test-Path $InstallDir)) {
    Write-Host "ERROR: Installation directory not found: $InstallDir" -ForegroundColor Red
    Write-Host "Please install the MDM agent first" -ForegroundColor Yellow
    exit 1
}

# Stop the task if running
$taskName = "VigyanShaala-MDM-RealtimeListener"
Write-Host "Stopping scheduled task..." -ForegroundColor Yellow
try {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-Host "Task stopped" -ForegroundColor Green
} catch {
    Write-Host "Task not running or doesn't exist" -ForegroundColor Gray
}

# Backup old script
if (Test-Path $targetScript) {
    $backupPath = "$targetScript.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $targetScript $backupPath -Force
    Write-Host "Backed up old script to: $backupPath" -ForegroundColor Gray
}

# Copy new script
Write-Host "Copying new script..." -ForegroundColor Yellow
try {
    Copy-Item $sourceScript $targetScript -Force
    Write-Host "✓ Script updated successfully" -ForegroundColor Green
    Write-Host "  Source: $sourceScript" -ForegroundColor Gray
    Write-Host "  Target: $targetScript" -ForegroundColor Gray
} catch {
    Write-Host "ERROR: Failed to copy script: $_" -ForegroundColor Red
    exit 1
}

# Verify the log path in the new script
Write-Host "`nVerifying log path in updated script..." -ForegroundColor Yellow
$scriptContent = Get-Content $targetScript -Raw
if ($scriptContent -match 'LogFile.*ProgramData.*VigyanShaala-MDM') {
    Write-Host "✓ Log path is correct: C:\ProgramData\VigyanShaala-MDM\logs\" -ForegroundColor Green
} elseif ($scriptContent -match 'LogFile.*TEMP') {
    Write-Host "✗ WARNING: Script still uses old TEMP path!" -ForegroundColor Red
    Write-Host "  The script may not have been updated correctly" -ForegroundColor Yellow
} else {
    Write-Host "⚠ Could not verify log path" -ForegroundColor Yellow
}

# Restart the task
Write-Host "`nRestarting scheduled task..." -ForegroundColor Yellow
try {
    Start-ScheduledTask -TaskName $taskName
    Start-Sleep -Seconds 3
    
    $info = Get-ScheduledTaskInfo -TaskName $taskName
    if ($info.State -eq "Running" -or $info.LastTaskResult -eq 267009) {
        Write-Host "✓ Task restarted successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠ Task may have issues. State: $($info.State), Result: $($info.LastTaskResult)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "WARNING: Could not restart task: $_" -ForegroundColor Yellow
    Write-Host "  You may need to start it manually: Start-ScheduledTask -TaskName '$taskName'" -ForegroundColor Gray
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Update complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nNew log file location:" -ForegroundColor White
Write-Host "  C:\ProgramData\VigyanShaala-MDM\logs\VigyanShaala-RealtimeListener.log" -ForegroundColor Cyan

