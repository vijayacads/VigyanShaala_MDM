# Fix Realtime Listener Task
# Updates the installed script and restarts the task

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_ANON_KEY
)

$InstallDir = "C:\Program Files\osquery"
$realtimeScript = "$InstallDir\realtime-command-listener.ps1"
$taskName = "VigyanShaala-MDM-RealtimeListener"

Write-Host "Fixing Realtime Listener Task..." -ForegroundColor Cyan

# Check if script exists
if (-not (Test-Path $realtimeScript)) {
    Write-Host "ERROR: Script not found at $realtimeScript" -ForegroundColor Red
    Write-Host "Please reinstall the MDM agent" -ForegroundColor Yellow
    exit 1
}

# Get Supabase credentials from environment if not provided
if (-not $SupabaseUrl) {
    $SupabaseUrl = [Environment]::GetEnvironmentVariable("SUPABASE_URL", "Machine")
}
if (-not $SupabaseKey) {
    $SupabaseKey = [Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY", "Machine")
}

if (-not $SupabaseUrl -or -not $SupabaseKey) {
    Write-Host "ERROR: Supabase credentials not found" -ForegroundColor Red
    Write-Host "Please provide -SupabaseUrl and -SupabaseKey parameters" -ForegroundColor Yellow
    exit 1
}

# Stop the task if running
Write-Host "Stopping task..." -ForegroundColor Yellow
try {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
} catch {}

# Remove and recreate the task with correct arguments
Write-Host "Recreating task..." -ForegroundColor Yellow
try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
} catch {}

$taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$realtimeScript`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseKey `"$SupabaseKey`""

$taskTrigger = New-ScheduledTaskTrigger -AtStartup
$taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Create settings with fallback for older PowerShell
try {
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Hours 0)
} catch {
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 0)
}

try {
    $task = Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Description "Realtime WebSocket listener for instant command processing (runs continuously)" -Force
    Enable-ScheduledTask -TaskName $taskName
    
    Write-Host "Task recreated successfully!" -ForegroundColor Green
    
    # Start the task
    Write-Host "Starting task..." -ForegroundColor Yellow
    Start-ScheduledTask -TaskName $taskName
    Start-Sleep -Seconds 3
    
    $info = Get-ScheduledTask -TaskName $taskName | Get-ScheduledTaskInfo
    Write-Host "`nTask Status:" -ForegroundColor Cyan
    Write-Host "  State: $($info.State)" -ForegroundColor Gray
    Write-Host "  Last Run: $($info.LastRunTime)" -ForegroundColor Gray
    Write-Host "  Last Result: $($info.LastTaskResult)" -ForegroundColor $(if ($info.LastTaskResult -eq 0) { "Green" } else { "Red" })
    
    if ($info.LastTaskResult -eq 0) {
        Write-Host "`nTask is running successfully!" -ForegroundColor Green
    } else {
        Write-Host "`nTask started but returned error code: $($info.LastTaskResult)" -ForegroundColor Yellow
        Write-Host "Check the log file: C:\ProgramData\VigyanShaala-MDM\logs\VigyanShaala-RealtimeListener.log" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "ERROR: Failed to recreate task: $_" -ForegroundColor Red
    exit 1
}

