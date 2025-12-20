# Fix User-Notify-Agent Task to Run Continuously
# This script ensures the user-notify-agent task is running and configured correctly
# Run this as Administrator

param(
    [string]$SupabaseUrl = "https://thqinhphunrflwlshdmx.supabase.co",
    [string]$SupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRocWluaHBodW5yZmx3bHNoZG14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4Njk2ODcsImV4cCI6MjA4MTQ0NTY4N30.nVTHifwIDIozcqerE-X7zmebO6Pag8Ji-N3d4jetaQM",
    [string]$DeviceHostname = $env:COMPUTERNAME
)

$userNotifyTaskName = "VigyanShaala-MDM-UserNotify-Agent"
$userNotifyScript = "C:\Program Files\osquery\user-notify-agent.ps1"

Write-Host "=== Fixing User-Notify-Agent Task ===" -ForegroundColor Cyan
Write-Host ""

# 1. Check if script exists
if (-not (Test-Path $userNotifyScript)) {
    Write-Error "Error: User notification script not found at $userNotifyScript"
    Write-Host "Please ensure the agent is installed correctly." -ForegroundColor Yellow
    exit 1
}

# 2. Check current task status
Write-Host "Checking current task status..." -ForegroundColor Yellow
try {
    $task = Get-ScheduledTask -TaskName $userNotifyTaskName -ErrorAction Stop
    $taskInfo = Get-ScheduledTaskInfo -TaskName $userNotifyTaskName
    Write-Host "Task State: $($task.State)" -ForegroundColor Gray
    Write-Host "Last Run: $($taskInfo.LastRunTime)" -ForegroundColor Gray
    Write-Host "Last Result: $($taskInfo.LastTaskResult)" -ForegroundColor Gray
} catch {
    Write-Host "Task does not exist or cannot be accessed" -ForegroundColor Yellow
}

# 3. Define the action (with -WindowStyle Hidden to prevent visible window)
$userNotifyTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$userNotifyScript`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseKey `"$SupabaseKey`" -PollInterval 5"

# 4. Define triggers: AtLogOn AND AtStartup (for continuous running)
$triggers = @(
    (New-ScheduledTaskTrigger -AtLogOn),
    (New-ScheduledTaskTrigger -AtStartup)
)

# 5. Define principal (run as the user who logs on, interactive)
try {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $userNotifyTaskPrincipal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Limited
    Write-Host "Task principal set for current user: $currentUser" -ForegroundColor Gray
} catch {
    $userNotifyTaskPrincipal = New-ScheduledTaskPrincipal -GroupId "Users" -LogonType Interactive -RunLevel Limited
    Write-Host "Task principal set for 'Users' group (fallback)" -ForegroundColor Gray
}

# 6. Define settings for continuous, hidden execution with restarts
$userNotifyTaskSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0) ` # No time limit (runs continuously)
    -RestartCount 999 ` # Restart up to 999 times
    -RestartInterval (New-TimeSpan -Minutes 1) # Restart every 1 minute

# 7. Register/Update the task
try {
    Write-Host "`nUnregistering existing task (if any)..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $userNotifyTaskName -Confirm:$false -ErrorAction SilentlyContinue
    
    Write-Host "Registering new task configuration..." -ForegroundColor Yellow
    $task = Register-ScheduledTask -TaskName $userNotifyTaskName `
        -Action $userNotifyTaskAction `
        -Trigger $triggers `
        -Principal $userNotifyTaskPrincipal `
        -Settings $userNotifyTaskSettings `
        -Description "VigyanShaala MDM User Notification Agent - Handles buzz, lock, cache, and toast notifications in user session (runs continuously, hidden)" `
        -Force
    
    Enable-ScheduledTask -TaskName $userNotifyTaskName
    Write-Host "Task '$userNotifyTaskName' updated and enabled successfully." -ForegroundColor Green
    
    # 8. Start the task immediately
    Write-Host "`nStarting task immediately..." -ForegroundColor Yellow
    Start-ScheduledTask -TaskName $userNotifyTaskName
    
    # 9. Wait and verify
    Start-Sleep -Seconds 3
    $taskInfo = Get-ScheduledTaskInfo -TaskName $userNotifyTaskName
    Write-Host "Task State: $($taskInfo.State)" -ForegroundColor Green
    Write-Host "Last Run: $($taskInfo.LastRunTime)" -ForegroundColor Green
    
    Write-Host "`n=== Task Fixed Successfully ===" -ForegroundColor Green
    Write-Host "The task will now run continuously in the background." -ForegroundColor Green
    Write-Host "Check logs at: $env:TEMP\VigyanShaala-UserNotify.log" -ForegroundColor Cyan

} catch {
    Write-Error "Failed to update or start task '$userNotifyTaskName': $($_.Exception.Message)"
    exit 1
}


