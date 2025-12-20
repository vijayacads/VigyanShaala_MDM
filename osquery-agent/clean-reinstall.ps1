# Clean Reinstall Script
# Removes all old MDM components and reinstalls fresh
# Run as Administrator

param(
    [Parameter(Mandatory=$true)]
    [string]$SupabaseUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$SupabaseKey
)

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Clean Reinstall - VigyanShaala MDM" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Stop all running processes
Write-Host "[1/5] Stopping all MDM processes..." -ForegroundColor Yellow
Get-Process | Where-Object { $_.ProcessName -like "*osquery*" } | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process | Where-Object { $_.ProcessName -eq "powershell" -and $_.MainWindowTitle -like "*VigyanShaala*" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "Processes stopped" -ForegroundColor Green

# Step 2: Remove ALL scheduled tasks (comprehensive list)
Write-Host "`n[2/5] Removing all MDM scheduled tasks..." -ForegroundColor Yellow
$allTasks = @(
    "VigyanShaala-MDM-RealtimeListener",
    "VigyanShaala-MDM-UserNotify-Agent",
    "VigyanShaala-UserNotify-Agent",
    "VigyanShaala-MDM-SendOsqueryData",
    "VigyanShaala-MDM-CollectBatteryData",
    "VigyanShaala-MDM-SyncWebsiteBlocklist",
    "VigyanShaala-MDM-SyncSoftwareBlocklist",
    "VigyanShaala-MDM-CommandProcessor",
    "VigyanShaala-MDM-OsqueryHealth",
    "VigyanShaala-MDM-OsquerySoftware",
    "VigyanShaala-MDM-OsqueryWebActivity",
    "VigyanShaala-MDM-OsqueryGeofence",
    "VigyanShaala-MDM-OsqueryHeartbeat",
    "VigyanShaala-MDM-HealthCheck",
    "VigyanShaala-MDM-OsqueryData"
)

$removedCount = 0
foreach ($taskName in $allTasks) {
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
            Write-Host "  Removed: $taskName" -ForegroundColor Green
            $removedCount++
        }
    } catch {
        # Task doesn't exist or already removed
    }
}

if ($removedCount -eq 0) {
    Write-Host "  No tasks found to remove" -ForegroundColor Gray
} else {
    Write-Host "  Removed $removedCount task(s)" -ForegroundColor Green
}

# Step 3: Verify all tasks are gone
Write-Host "`n[3/5] Verifying all tasks removed..." -ForegroundColor Yellow
$remainingTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*VigyanShaala*" }
if ($remainingTasks) {
    Write-Host "  WARNING: Some tasks still exist:" -ForegroundColor Red
    $remainingTasks | ForEach-Object { Write-Host "    - $($_.TaskName)" -ForegroundColor Red }
} else {
    Write-Host "  All tasks removed successfully" -ForegroundColor Green
}

# Step 4: Run the installer
Write-Host "`n[4/5] Running fresh installation..." -ForegroundColor Yellow
$installScript = Join-Path $PSScriptRoot "install-osquery.ps1"
if (-not (Test-Path $installScript)) {
    Write-Host "ERROR: install-osquery.ps1 not found at: $installScript" -ForegroundColor Red
    exit 1
}

& $installScript -SupabaseUrl $SupabaseUrl -SupabaseKey $SupabaseKey

# Step 5: Verify realtime listener task is running
Write-Host "`n[5/5] Verifying realtime listener task..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

$taskName = "VigyanShaala-MDM-RealtimeListener"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if (-not $task) {
    Write-Host "  ERROR: Task not found after installation!" -ForegroundColor Red
    exit 1
}

# Try to start it if not running
$info = Get-ScheduledTaskInfo -TaskName $taskName
if ($info.State -ne "Running" -and $info.LastTaskResult -eq 267011) {
    Write-Host "  Task exists but not running. Starting..." -ForegroundColor Yellow
    try {
        Start-ScheduledTask -TaskName $taskName
        Start-Sleep -Seconds 3
        $info = Get-ScheduledTaskInfo -TaskName $taskName
    } catch {
        Write-Host "  ERROR: Could not start task: $_" -ForegroundColor Red
    }
}

# Final status
$info = Get-ScheduledTaskInfo -TaskName $taskName
Write-Host "`nFinal Status:" -ForegroundColor Cyan
Write-Host "  Task Name: $taskName" -ForegroundColor White
Write-Host "  State: $($info.State)" -ForegroundColor $(if ($info.State -eq "Running") { "Green" } else { "Yellow" })
Write-Host "  Last Result: $($info.LastTaskResult)" -ForegroundColor White
Write-Host "  Last Run: $($info.LastRunTime)" -ForegroundColor White

if ($info.State -eq "Running" -or $info.LastTaskResult -eq 267009) {
    Write-Host "`n✓ Realtime listener is running!" -ForegroundColor Green
} elseif ($info.LastTaskResult -eq 0) {
    Write-Host "`n✓ Task completed successfully" -ForegroundColor Green
} else {
    Write-Host "`n⚠ Task may have issues. Check log:" -ForegroundColor Yellow
    Write-Host "  C:\ProgramData\VigyanShaala-MDM\logs\VigyanShaala-RealtimeListener.log" -ForegroundColor White
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Clean reinstall complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

