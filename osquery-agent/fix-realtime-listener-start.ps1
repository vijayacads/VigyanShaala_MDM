# Quick Fix: Start Realtime Listener Task
# This starts the realtime listener task if it exists but hasn't run

$taskName = "VigyanShaala-MDM-RealtimeListener"

Write-Host "Checking realtime listener task..." -ForegroundColor Cyan

$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if (-not $task) {
    Write-Host "ERROR: Task '$taskName' not found!" -ForegroundColor Red
    Write-Host "Please run install-osquery.ps1 to create the task." -ForegroundColor Yellow
    exit 1
}

$info = Get-ScheduledTaskInfo -TaskName $taskName
Write-Host "Current State: $($info.State)" -ForegroundColor Gray
Write-Host "Last Result: $($info.LastTaskResult)" -ForegroundColor Gray

if ($info.State -eq "Running") {
    Write-Host "Task is already running!" -ForegroundColor Green
    exit 0
}

Write-Host "`nStarting task..." -ForegroundColor Yellow
try {
    Start-ScheduledTask -TaskName $taskName
    Start-Sleep -Seconds 3
    
    $info = Get-ScheduledTaskInfo -TaskName $taskName
    Write-Host "Task started!" -ForegroundColor Green
    Write-Host "New State: $($info.State)" -ForegroundColor Gray
    Write-Host "Last Result: $($info.LastTaskResult)" -ForegroundColor Gray
    
    if ($info.LastTaskResult -eq 267009) {
        Write-Host "`n✓ Task is now running (267009 = running)" -ForegroundColor Green
    } elseif ($info.LastTaskResult -eq 0) {
        Write-Host "`n✓ Task completed successfully" -ForegroundColor Green
    } else {
        Write-Host "`n⚠ Task may have issues. Check log file:" -ForegroundColor Yellow
        Write-Host "  C:\ProgramData\VigyanShaala-MDM\logs\VigyanShaala-RealtimeListener.log" -ForegroundColor White
    }
} catch {
    Write-Host "ERROR: Failed to start task: $_" -ForegroundColor Red
    Write-Host "`nTry running as Administrator" -ForegroundColor Yellow
    exit 1
}

