# Fix device to use new Supabase project
# Run this on the device as Administrator

Write-Host "=== Updating Device to New Supabase Project ===" -ForegroundColor Cyan
Write-Host ""

$taskName = "VigyanShaala-MDM-RealtimeListener"
$newSupabaseUrl = "https://thqinhphunrflwlshdmx.supabase.co"
$newSupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRocWluaHBodW5yZmx3bHNoZG14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4Njk2ODcsImV4cCI6MjA4MTQ0NTY4N30.nVTHifwIDIozcqerE-X7zmebO6Pag8Ji-N3d4jetaQM"

# Check if task exists
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Host "ERROR: Task not found: $taskName" -ForegroundColor Red
    exit 1
}

Write-Host "1. Stopping task..." -ForegroundColor Yellow
Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "2. Updating task with new Supabase credentials..." -ForegroundColor Yellow
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\Program Files\osquery\realtime-command-listener.ps1`" -SupabaseUrl `"$newSupabaseUrl`" -SupabaseKey `"$newSupabaseKey`""

Set-ScheduledTask -TaskName $taskName -Action $action

Write-Host "3. Starting task..." -ForegroundColor Yellow
Start-ScheduledTask -TaskName $taskName

Start-Sleep -Seconds 3

Write-Host ""
Write-Host "4. Verifying..." -ForegroundColor Yellow
$taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
$currentAction = (Get-ScheduledTask -TaskName $taskName).Actions[0]

Write-Host "Task State: $($taskInfo.State)" -ForegroundColor $(if ($taskInfo.State -eq 'Running') { 'Green' } else { 'Yellow' })
Write-Host "Current URL in task:" -ForegroundColor Gray
if ($currentAction.Arguments -match "thqinhphunrflwlshdmx") {
    Write-Host "  ✓ Using NEW Supabase project" -ForegroundColor Green
} else {
    Write-Host "  ✗ Still using OLD Supabase project!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Done! Check logs in 10 seconds:" -ForegroundColor Cyan
Write-Host 'Get-Content "$env:TEMP\VigyanShaala-RealtimeListener.log" -Tail 20' -ForegroundColor Gray


