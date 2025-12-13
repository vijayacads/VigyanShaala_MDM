# create-send-data-task.ps1
# Creates the scheduled task to send osquery data to Supabase
# Run this if the task wasn't created during installation

param(
    [Parameter(Mandatory=$false)]
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseKey = $env:SUPABASE_ANON_KEY,
    
    [Parameter(Mandatory=$false)]
    [string]$InstallDir = "C:\Program Files\osquery"
)

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires Administrator privileges"
    exit 1
}

if (-not $SupabaseUrl -or -not $SupabaseKey) {
    Write-Error "SUPABASE_URL and SUPABASE_ANON_KEY must be set as environment variables or passed as parameters"
    exit 1
}

Write-Host "Creating scheduled task to send osquery data..." -ForegroundColor Cyan

$sendDataScript = "$InstallDir\send-osquery-data.ps1"

# Verify script exists
if (-not (Test-Path $sendDataScript)) {
    Write-Error "send-osquery-data.ps1 not found at: $sendDataScript"
    Write-Host "Please copy send-osquery-data.ps1 to $InstallDir first" -ForegroundColor Yellow
    exit 1
}

$dataTaskName = "VigyanShaala-MDM-SendOsqueryData"

# Create action
$dataTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File `"$sendDataScript`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseAnonKey `"$SupabaseKey`""

# Create trigger that runs every 5 minutes, starting now
$dataTaskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 365)

# Use SYSTEM account to run regardless of logged-in user
$dataTaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Create settings to ensure task runs even when user is not logged in
$dataTaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false

try {
    # Remove existing task if it exists
    Unregister-ScheduledTask -TaskName $dataTaskName -Confirm:$false -ErrorAction SilentlyContinue
    
    # Register the task
    $task = Register-ScheduledTask -TaskName $dataTaskName -Action $dataTaskAction -Trigger $dataTaskTrigger -Principal $dataTaskPrincipal -Settings $dataTaskSettings -Description "Send osquery data to MDM server every 5 minutes" -Force
    
    # Explicitly enable the task
    Enable-ScheduledTask -TaskName $dataTaskName
    
    Write-Host "Scheduled task created and enabled successfully!" -ForegroundColor Green
    Write-Host "Task Name: $dataTaskName" -ForegroundColor Gray
    Write-Host "Runs: Every 5 minutes" -ForegroundColor Gray
    Write-Host "Account: SYSTEM (runs regardless of user login)" -ForegroundColor Gray
    
    # Show task info
    $taskInfo = Get-ScheduledTask -TaskName $dataTaskName | Get-ScheduledTaskInfo
    Write-Host "`nTask Status:" -ForegroundColor Cyan
    Write-Host "  Next Run: $($taskInfo.NextRunTime)" -ForegroundColor Gray
    Write-Host "  Last Run: $($taskInfo.LastRunTime)" -ForegroundColor Gray
    
} catch {
    Write-Error "Failed to create scheduled task: $_"
    exit 1
}

