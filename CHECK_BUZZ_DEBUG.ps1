# Quick debug script for buzz command
# Run this on the device where buzz didn't work

Write-Host "=== BUZZ COMMAND DEBUG ===" -ForegroundColor Cyan
Write-Host ""

# 1. Check recent logs
Write-Host "1. Recent Realtime Listener Logs:" -ForegroundColor Yellow
$logFile = "$env:TEMP\VigyanShaala-RealtimeListener.log"
if (Test-Path $logFile) {
    Write-Host "Last 30 lines with 'buzz' or 'command':" -ForegroundColor Gray
    Get-Content $logFile -Tail 100 | Select-String -Pattern "buzz|Buzz|command|Command" -Context 2
} else {
    Write-Host "Log file not found: $logFile" -ForegroundColor Red
}

Write-Host ""
Write-Host "2. Check Scheduled Task Status:" -ForegroundColor Yellow
$task = Get-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener" -ErrorAction SilentlyContinue
if ($task) {
    $taskInfo = Get-ScheduledTaskInfo -TaskName "VigyanShaala-MDM-RealtimeListener"
    Write-Host "State: $($task.State)" -ForegroundColor $(if ($task.State -eq 'Running') { 'Green' } else { 'Red' })
    Write-Host "Last Run: $($taskInfo.LastRunTime)" -ForegroundColor Gray
    Write-Host "Last Result: $($taskInfo.LastTaskResult)" -ForegroundColor Gray
} else {
    Write-Host "Task not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "3. Check if execute-commands.ps1 has buzz function:" -ForegroundColor Yellow
$execFile = "C:\Program Files\osquery\execute-commands.ps1"
if (Test-Path $execFile) {
    $hasBuzz = Select-String -Path $execFile -Pattern "function Buzz-Device|Playing buzzer sound directly" -Quiet
    if ($hasBuzz) {
        Write-Host "✓ Buzz function found" -ForegroundColor Green
    } else {
        Write-Host "✗ Buzz function NOT found!" -ForegroundColor Red
    }
} else {
    Write-Host "✗ execute-commands.ps1 not found at: $execFile" -ForegroundColor Red
}

Write-Host ""
Write-Host "4. Test buzz directly:" -ForegroundColor Yellow
Write-Host "Run this to test if beep works:" -ForegroundColor Gray
Write-Host '[console]::beep(800, 500)' -ForegroundColor White
Write-Host ""
Write-Host "5. Check device_commands table in Supabase:" -ForegroundColor Yellow
Write-Host "Go to: https://thqinhphunrflwlshdmx.supabase.co" -ForegroundColor Gray
Write-Host "Table Editor → device_commands" -ForegroundColor Gray
Write-Host "Look for your buzz command and check:" -ForegroundColor Gray
Write-Host "  - status (should be 'completed' or 'failed')" -ForegroundColor Gray
Write-Host "  - executed_at (should have timestamp)" -ForegroundColor Gray
Write-Host "  - error_message (if failed)" -ForegroundColor Gray


