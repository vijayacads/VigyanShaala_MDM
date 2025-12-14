# Fix/Recreate Command Processor Scheduled Task
# This ensures the device control command processor is running

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_ANON_KEY
)

if (-not $SupabaseUrl -or -not $SupabaseKey) {
    Write-Error "Supabase URL and Key must be provided as parameters or environment variables"
    Write-Host "Usage: .\fix-command-processor-task.ps1 -SupabaseUrl 'https://xxx.supabase.co' -SupabaseKey 'your-key'" -ForegroundColor Yellow
    exit 1
}

$InstallDir = "C:\Program Files\osquery"
$commandScript = "$InstallDir\execute-commands.ps1"
$commandTaskName = "VigyanShaala-MDM-CommandProcessor"

Write-Host "`nFixing Command Processor Scheduled Task..." -ForegroundColor Cyan
Write-Host "Task Name: $commandTaskName" -ForegroundColor Gray
Write-Host "Script: $commandScript" -ForegroundColor Gray

# Check if script exists
if (-not (Test-Path $commandScript)) {
    Write-Warning "Script not found at $commandScript"
    Write-Host "Make sure execute-commands.ps1 is in the installation directory" -ForegroundColor Yellow
    exit 1
}

# Remove existing task if it exists
Write-Host "`nRemoving existing task (if any)..." -ForegroundColor Yellow
try {
    Unregister-ScheduledTask -TaskName $commandTaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Old task removed" -ForegroundColor Green
} catch {
    Write-Host "No existing task to remove" -ForegroundColor Gray
}

# Create new task
Write-Host "`nCreating new scheduled task..." -ForegroundColor Yellow

$commandTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File `"$commandScript`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseKey `"$SupabaseKey`""

# Run every 1 minute, starting now
$commandTaskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 365)

# Use SYSTEM account
$commandTaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Settings to ensure it runs
$commandTaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false

try {
    $task = Register-ScheduledTask -TaskName $commandTaskName -Action $commandTaskAction -Trigger $commandTaskTrigger -Principal $commandTaskPrincipal -Settings $commandTaskSettings -Description "Process MDM commands and messages every 1 minute" -Force
    
    # Enable the task
    Enable-ScheduledTask -TaskName $commandTaskName
    
    Write-Host "`nTask created and enabled successfully!" -ForegroundColor Green
    
    # Show task info
    $taskInfo = Get-ScheduledTask -TaskName $commandTaskName | Get-ScheduledTaskInfo
    Write-Host "`nTask Status:" -ForegroundColor Cyan
    Write-Host "  State: $($task.State)" -ForegroundColor Gray
    Write-Host "  Next Run: $($taskInfo.NextRunTime)" -ForegroundColor Gray
    Write-Host "  Last Run: $($taskInfo.LastRunTime)" -ForegroundColor Gray
    
    # Test run immediately
    Write-Host "`nTriggering immediate test run..." -ForegroundColor Yellow
    Start-ScheduledTask -TaskName $commandTaskName
    Start-Sleep -Seconds 3
    
    $taskInfo = Get-ScheduledTask -TaskName $commandTaskName | Get-ScheduledTaskInfo
    Write-Host "  Last Run: $($taskInfo.LastRunTime)" -ForegroundColor Gray
    Write-Host "  Last Result: $($taskInfo.LastTaskResult)" -ForegroundColor $(if ($taskInfo.LastTaskResult -eq 0) { "Green" } else { "Red" })
    
    Write-Host "`nTask is now running every 1 minute!" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to create scheduled task: $_"
    exit 1
}

