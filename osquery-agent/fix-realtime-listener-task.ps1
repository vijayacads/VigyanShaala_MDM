# Fix Realtime Listener Task
# Run as Administrator to fix the scheduled task

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_ANON_KEY
)

if (-not $SupabaseUrl -or -not $SupabaseKey) {
    Write-Host "ERROR: Supabase URL and Key must be provided" -ForegroundColor Red
    Write-Host "Usage: .\fix-realtime-listener-task.ps1 -SupabaseUrl 'URL' -SupabaseKey 'KEY'" -ForegroundColor Yellow
    exit 1
}

$taskName = "VigyanShaala-MDM-RealtimeListener"
$scriptPath = "C:\Program Files\osquery\realtime-command-listener.ps1"
$installDir = "C:\Program Files\osquery"

Write-Host "=== Fixing Realtime Listener Task ===" -ForegroundColor Cyan
Write-Host ""

# Check if script exists
if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: Script not found at: $scriptPath" -ForegroundColor Red
    Write-Host "Please reinstall the MDM agent first." -ForegroundColor Yellow
    exit 1
}

# Stop and remove existing task
Write-Host "1. Stopping and removing existing task..." -ForegroundColor Yellow
try {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-Host "   [OK] Task removed" -ForegroundColor Green
} catch {
    Write-Host "   [INFO] Task doesn't exist or already removed" -ForegroundColor Gray
}

# Create new task action
Write-Host "2. Creating new task action..." -ForegroundColor Yellow
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseKey `"$SupabaseKey`""

# Create trigger (at startup)
$trigger = New-ScheduledTaskTrigger -AtStartup

# Create principal (SYSTEM account)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Create settings
try {
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Hours 0)
} catch {
    # Fallback for older PowerShell
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 0)
}

# Register the task
Write-Host "3. Registering new task..." -ForegroundColor Yellow
try {
    $task = Register-ScheduledTask -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "Realtime WebSocket listener for instant command processing (runs continuously)" `
        -Force
    
    Enable-ScheduledTask -TaskName $taskName
    Write-Host "   [OK] Task registered and enabled" -ForegroundColor Green
} catch {
    Write-Host "   [ERROR] Failed to register task: $_" -ForegroundColor Red
    exit 1
}

# Start the task
Write-Host "4. Starting task..." -ForegroundColor Yellow
try {
    Start-ScheduledTask -TaskName $taskName
    Start-Sleep -Seconds 3
    
    $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
    Write-Host "   [OK] Task started" -ForegroundColor Green
    Write-Host "   State: $($taskInfo.State)" -ForegroundColor Gray
    Write-Host "   Last Result: $($taskInfo.LastTaskResult)" -ForegroundColor $(if ($taskInfo.LastTaskResult -eq 0) { "Green" } else { "Yellow" })
} catch {
    Write-Host "   [WARNING] Could not start task: $_" -ForegroundColor Yellow
}

# Verify log file
$logFile = "C:\ProgramData\VigyanShaala-MDM\logs\VigyanShaala-RealtimeListener.log"
Write-Host "5. Checking log file..." -ForegroundColor Yellow
if (Test-Path $logFile) {
    Write-Host "   [OK] Log file exists: $logFile" -ForegroundColor Green
    $logContent = Get-Content $logFile -Tail 5 -ErrorAction SilentlyContinue
    if ($logContent) {
        Write-Host "   Recent log entries:" -ForegroundColor Gray
        $logContent | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    }
} else {
    Write-Host "   [INFO] Log file not created yet (will be created when script runs)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Fix Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "To monitor the task:" -ForegroundColor Cyan
Write-Host "  Get-ScheduledTaskInfo -TaskName `"$taskName`"" -ForegroundColor Gray
Write-Host ""
Write-Host "To view logs:" -ForegroundColor Cyan
Write-Host "  Get-Content `"$logFile`" -Tail 50 -Wait" -ForegroundColor Gray

