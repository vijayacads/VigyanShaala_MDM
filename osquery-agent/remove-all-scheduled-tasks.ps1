# Remove All VigyanShaala MDM Scheduled Tasks
# Run as Administrator to remove all MDM scheduled tasks manually

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Remove All MDM Scheduled Tasks" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Comprehensive list of all possible MDM task names
$allTaskNames = @(
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

Write-Host "Checking for MDM scheduled tasks..." -ForegroundColor Yellow
Write-Host ""

$foundTasks = @()
$removedTasks = @()
$failedTasks = @()

foreach ($taskName in $allTaskNames) {
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            $foundTasks += $taskName
            Write-Host "Found: $taskName" -ForegroundColor Cyan
            
            # Stop the task first
            try {
                Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                Write-Host "  Stopped task" -ForegroundColor Gray
            } catch {
                Write-Host "  Task not running" -ForegroundColor Gray
            }
            
            # Remove the task
            try {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
                Write-Host "  ✓ Removed successfully" -ForegroundColor Green
                $removedTasks += $taskName
            } catch {
                Write-Host "  ✗ Failed to remove: $_" -ForegroundColor Red
                $failedTasks += $taskName
            }
        }
    } catch {
        # Task doesn't exist, skip
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($foundTasks.Count -eq 0) {
    Write-Host "No MDM scheduled tasks found." -ForegroundColor Green
} else {
    Write-Host "Found: $($foundTasks.Count) task(s)" -ForegroundColor White
    Write-Host "Removed: $($removedTasks.Count) task(s)" -ForegroundColor Green
    if ($failedTasks.Count -gt 0) {
        Write-Host "Failed: $($failedTasks.Count) task(s)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Failed tasks:" -ForegroundColor Yellow
        foreach ($task in $failedTasks) {
            Write-Host "  - $task" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "Try running this script again, or manually remove via:" -ForegroundColor Yellow
        Write-Host "  Task Scheduler (taskschd.msc)" -ForegroundColor White
    }
}

# Verify all tasks are gone
Write-Host ""
Write-Host "Verifying all tasks removed..." -ForegroundColor Yellow
$remainingTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*VigyanShaala*" }

if ($remainingTasks) {
    Write-Host "WARNING: Some tasks still exist:" -ForegroundColor Red
    $remainingTasks | ForEach-Object {
        Write-Host "  - $($_.TaskName)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "You may need to:" -ForegroundColor Yellow
    Write-Host "  1. Restart the computer" -ForegroundColor White
    Write-Host "  2. Run this script again" -ForegroundColor White
    Write-Host "  3. Or manually remove via Task Scheduler (taskschd.msc)" -ForegroundColor White
} else {
    Write-Host "✓ All MDM scheduled tasks removed!" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

