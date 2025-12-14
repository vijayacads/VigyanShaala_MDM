# Fix/Recreate ALL VigyanShaala MDM Scheduled Tasks
# This ensures all tasks (data collection, commands, blocklists) are running

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_ANON_KEY
)

if (-not $SupabaseUrl -or -not $SupabaseKey) {
    Write-Error "Supabase URL and Key must be provided as parameters or environment variables"
    Write-Host "Usage: .\fix-all-scheduled-tasks.ps1 -SupabaseUrl 'https://xxx.supabase.co' -SupabaseKey 'your-key'" -ForegroundColor Yellow
    exit 1
}

$InstallDir = "C:\Program Files\osquery"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Fixing ALL MDM Scheduled Tasks" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Function to create a scheduled task
function Create-ScheduledTask {
    param(
        [string]$TaskName,
        [string]$ScriptPath,
        [int]$IntervalMinutes,
        [string]$Description
    )
    
    Write-Host "`n--- $TaskName ---" -ForegroundColor Yellow
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Host "  ERROR: Script not found at $ScriptPath" -ForegroundColor Red
        return $false
    }
    
    # Remove existing task
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "  Removed old task (if existed)" -ForegroundColor Gray
    } catch {
        Write-Host "  No existing task to remove" -ForegroundColor Gray
    }
    
    # Create task action - use correct parameter name based on script
    if ($ScriptPath -like "*execute-commands*") {
        $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseKey `"$SupabaseKey`""
    } elseif ($ScriptPath -like "*get-battery-wmi*") {
        # Battery script uses environment variables, no params needed
        $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    } else {
        # All other scripts use -SupabaseAnonKey
        $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseAnonKey `"$SupabaseKey`""
    }
    
    # Create trigger (run every X minutes)
    $taskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 365)
    
    # Use SYSTEM account
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # Settings
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false
    
    try {
        $task = Register-ScheduledTask -TaskName $TaskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Description $Description -Force
        Enable-ScheduledTask -TaskName $TaskName
        
        $taskInfo = Get-ScheduledTask -TaskName $TaskName | Get-ScheduledTaskInfo
        Write-Host "  Status: CREATED and ENABLED" -ForegroundColor Green
        Write-Host "  Next Run: $($taskInfo.NextRunTime)" -ForegroundColor Gray
        return $true
    } catch {
        Write-Host "  ERROR: Failed to create task - $_" -ForegroundColor Red
        return $false
    }
}

# 1. Data Collection Task (every 5 minutes)
Create-ScheduledTask `
    -TaskName "VigyanShaala-MDM-SendOsqueryData" `
    -ScriptPath "$InstallDir\send-osquery-data.ps1" `
    -IntervalMinutes 5 `
    -Description "Send osquery data to MDM server every 5 minutes"

# 2. Command Processor Task (every 1 minute)
Create-ScheduledTask `
    -TaskName "VigyanShaala-MDM-CommandProcessor" `
    -ScriptPath "$InstallDir\execute-commands.ps1" `
    -IntervalMinutes 1 `
    -Description "Process MDM commands and messages every 1 minute"

# 3. Website Blocklist Sync (every 30 minutes)
Create-ScheduledTask `
    -TaskName "VigyanShaala-MDM-SyncWebsiteBlocklist" `
    -ScriptPath "$InstallDir\sync-blocklist-scheduled.ps1" `
    -IntervalMinutes 30 `
    -Description "Sync website blocklist every 30 minutes"

# 4. Software Blocklist Sync (every 60 minutes)
Create-ScheduledTask `
    -TaskName "VigyanShaala-MDM-SyncSoftwareBlocklist" `
    -ScriptPath "$InstallDir\sync-software-blocklist-scheduled.ps1" `
    -IntervalMinutes 60 `
    -Description "Sync software blocklist every 60 minutes"

# 5. Battery Data Collection (every 15 minutes) - if script exists
if (Test-Path "$InstallDir\get-battery-wmi.ps1") {
    Create-ScheduledTask `
        -TaskName "VigyanShaala-MDM-CollectBatteryData" `
        -ScriptPath "$InstallDir\get-battery-wmi.ps1" `
        -IntervalMinutes 15 `
        -Description "Collect battery data every 15 minutes"
} else {
    Write-Host "`n--- VigyanShaala-MDM-CollectBatteryData ---" -ForegroundColor Yellow
    Write-Host "  SKIPPED: Script not found" -ForegroundColor Gray
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "All tasks processed!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Verifying tasks..." -ForegroundColor Yellow
Get-ScheduledTask | Where-Object {$_.TaskName -like "*VigyanShaala*"} | ForEach-Object {
    $info = $_ | Get-ScheduledTaskInfo
    Write-Host "  $($_.TaskName): $($_.State) - Next: $($info.NextRunTime)" -ForegroundColor $(if ($_.State -eq "Ready") { "Green" } else { "Yellow" })
}

Write-Host "`nDone! All tasks should now be running." -ForegroundColor Green

