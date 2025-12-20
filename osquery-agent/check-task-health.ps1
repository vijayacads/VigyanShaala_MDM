# Health Check Script for VigyanShaala MDM Scheduled Tasks
# Checks status of critical MDM agent tasks
# Usage: .\check-task-health.ps1

$tasks = @(
    "VigyanShaala-MDM-RealtimeListener",
    "VigyanShaala-UserNotify-Agent"
)

Write-Host "`nChecking VigyanShaala MDM Task Health..." -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

foreach ($taskName in $tasks) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    
    if (-not $task) {
        Write-Host "`n[$taskName]" -ForegroundColor Yellow
        Write-Host "  Status: NOT FOUND" -ForegroundColor Red
        continue
    }
    
    $info = Get-ScheduledTaskInfo -TaskName $taskName
    $state = $info.State
    $lastRun = $info.LastRunTime
    $lastResult = $info.LastTaskResult
    
    # Interpret LastTaskResult
    $resultText = switch ($lastResult) {
        0 { "Success (task exited normally)" }
        267009 { "Running (task is currently running)" }
        267011 { "Not yet run (task has never executed)" }
        default { "Code: $lastResult" }
    }
    
    Write-Host "`n[$taskName]" -ForegroundColor Cyan
    Write-Host "  State: $state" -ForegroundColor $(if ($state -eq "Running") { "Green" } elseif ($state -eq "Ready") { "Yellow" } else { "Red" })
    Write-Host "  Last Run: $lastRun" -ForegroundColor White
    Write-Host "  Last Result: $resultText" -ForegroundColor $(if ($lastResult -eq 0 -or $lastResult -eq 267009) { "Green" } else { "Yellow" })
}

Write-Host "`n" + ("=" * 60) -ForegroundColor Gray
Write-Host "Note: LastTaskResult = 267009 means the task is currently running (normal for long-running agents)" -ForegroundColor Gray
Write-Host "      LastTaskResult = 267011 means the task has never run (needs manual start or reboot)" -ForegroundColor Gray
Write-Host "`n"

