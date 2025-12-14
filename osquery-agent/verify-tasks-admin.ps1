# Verify all MDM scheduled tasks (run as Administrator)
# This script checks if tasks exist and their status

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "MDM Scheduled Tasks Verification" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "WARNING: Not running as Administrator!" -ForegroundColor Red
    Write-Host "Some tasks may not be visible. Please run as Administrator for full check.`n" -ForegroundColor Yellow
}

$taskNames = @(
    "VigyanShaala-MDM-SendOsqueryData",
    "VigyanShaala-MDM-CommandProcessor",
    "VigyanShaala-MDM-SyncWebsiteBlocklist",
    "VigyanShaala-MDM-SyncSoftwareBlocklist",
    "VigyanShaala-MDM-CollectBatteryData"
)

$foundCount = 0
$enabledCount = 0

foreach ($taskName in $taskNames) {
    Write-Host "Checking: $taskName" -NoNewline -ForegroundColor Yellow
    
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
        
        $foundCount++
        Write-Host " - FOUND" -ForegroundColor Green
        
        Write-Host "  State: $($task.State)" -ForegroundColor $(if ($task.State -eq "Ready") { "Green" } else { "Yellow" })
        if ($task.State -eq "Ready") { $enabledCount++ }
        
        Write-Host "  Last Run: $($taskInfo.LastRunTime)" -ForegroundColor Gray
        Write-Host "  Last Result: $($taskInfo.LastTaskResult)" -ForegroundColor $(if ($taskInfo.LastTaskResult -eq 0) { "Green" } else { "Red" })
        Write-Host "  Next Run: $($taskInfo.NextRunTime)" -ForegroundColor Gray
        
        # Check if script exists
        $action = $task.Actions[0]
        if ($action.Arguments -match '-File "([^"]+)"') {
            $scriptPath = $matches[1]
            if (Test-Path $scriptPath) {
                Write-Host "  Script: EXISTS" -ForegroundColor Green
            } else {
                Write-Host "  Script: MISSING ($scriptPath)" -ForegroundColor Red
            }
        }
        
    } catch {
        Write-Host " - NOT FOUND" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor DarkRed
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary: $foundCount/$($taskNames.Count) tasks found, $enabledCount enabled" -ForegroundColor $(if ($foundCount -eq $taskNames.Count) { "Green" } else { "Yellow" })
Write-Host "========================================`n" -ForegroundColor Cyan

if ($foundCount -lt $taskNames.Count) {
    Write-Host "To create missing tasks, run as Administrator:" -ForegroundColor Yellow
    Write-Host "  .\fix-all-scheduled-tasks.ps1 -SupabaseUrl 'YOUR_URL' -SupabaseKey 'YOUR_KEY'" -ForegroundColor White
}

