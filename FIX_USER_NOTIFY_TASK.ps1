# Fix User-Notify-Agent Task to Run Continuously
# Run this as Administrator to update the existing task

$SupabaseUrl = "https://thqinhphunrflwlshdmx.supabase.co"
$SupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRocWluaHBodW5yZmx3bHNoZG14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4Njk2ODcsImV4cCI6MjA4MTQ0NTY4N30.nVTHifwIDIozcqerE-X7zmebO6Pag8Ji-N3d4jetaQM"
$userNotifyScript = "C:\Program Files\osquery\user-notify-agent.ps1"
$userNotifyTaskName = "VigyanShaala-UserNotify-Agent"

Write-Host "Fixing User-Notify-Agent task to run continuously..." -ForegroundColor Cyan

# Create action with hidden window
$userNotifyTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$userNotifyScript`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseKey `"$SupabaseKey`" -PollInterval 5"

# Create multiple triggers
$triggers = @()
$triggers += New-ScheduledTaskTrigger -AtLogOn
$triggers += New-ScheduledTaskTrigger -AtStartup

# Principal: Run as current user
try {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $userNotifyTaskPrincipal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Limited
    Write-Host "Task will run as: $currentUser" -ForegroundColor Gray
} catch {
    $userNotifyTaskPrincipal = New-ScheduledTaskPrincipal -GroupId "Users" -LogonType Interactive -RunLevel Limited
    Write-Host "Task will run as: Users group" -ForegroundColor Gray
}

# Settings: Continuous, restart on failure
$userNotifyTaskSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1)

# Remove existing task
Unregister-ScheduledTask -TaskName $userNotifyTaskName -Confirm:$false -ErrorAction SilentlyContinue

# Register new task
$task = Register-ScheduledTask -TaskName $userNotifyTaskName `
    -Action $userNotifyTaskAction `
    -Trigger $triggers `
    -Principal $userNotifyTaskPrincipal `
    -Settings $userNotifyTaskSettings `
    -Description "VigyanShaala MDM User Notification Agent - Handles buzz and toast notifications (runs continuously)" `
    -Force

Enable-ScheduledTask -TaskName $userNotifyTaskName

# Start the task now
Start-ScheduledTask -TaskName $userNotifyTaskName

Write-Host "Task updated and started!" -ForegroundColor Green
Write-Host "Triggers: AtLogOn, AtStartup" -ForegroundColor Gray
Write-Host "Restart: Up to 999 times on failure" -ForegroundColor Gray
Write-Host "Window: Hidden (no visible window)" -ForegroundColor Gray


