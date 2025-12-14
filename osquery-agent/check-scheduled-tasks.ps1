# Check Status of All VigyanShaala MDM Scheduled Tasks
# Shows task status, last run, next run, and errors

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "VigyanShaala MDM Scheduled Tasks Status" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$taskNames = @(
    "VigyanShaala-MDM-SendOsqueryData",
    "VigyanShaala-MDM-CommandProcessor",
    "VigyanShaala-MDM-SyncWebsiteBlocklist",
    "VigyanShaala-MDM-SyncSoftwareBlocklist",
    "VigyanShaala-MDM-CollectBatteryData"
)

$allTasksFound = $true

foreach ($taskName in $taskNames) {
    Write-Host "`n--- $taskName ---" -ForegroundColor Yellow
    
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
        
        # Task exists
        Write-Host "  Status: " -NoNewline
        if ($task.State -eq "Ready") {
            Write-Host "READY (Enabled)" -ForegroundColor Green
        } elseif ($task.State -eq "Running") {
            Write-Host "RUNNING" -ForegroundColor Cyan
        } else {
            Write-Host "$($task.State)" -ForegroundColor Yellow
        }
        
        # Last run
        Write-Host "  Last Run: " -NoNewline
        if ($taskInfo.LastRunTime) {
            $timeSince = (Get-Date) - $taskInfo.LastRunTime
            $timeSinceStr = if ($timeSince.TotalMinutes -lt 60) {
                "$([math]::Round($timeSince.TotalMinutes, 1)) minutes ago"
            } elseif ($timeSince.TotalHours -lt 24) {
                "$([math]::Round($timeSince.TotalHours, 1)) hours ago"
            } else {
                "$([math]::Round($timeSince.TotalDays, 1)) days ago"
            }
            Write-Host "$($taskInfo.LastRunTime) ($timeSinceStr)" -ForegroundColor Gray
        } else {
            Write-Host "Never" -ForegroundColor Red
        }
        
        # Last result
        Write-Host "  Last Result: " -NoNewline
        if ($taskInfo.LastTaskResult -eq 0) {
            Write-Host "SUCCESS (0)" -ForegroundColor Green
        } else {
            Write-Host "FAILED ($($taskInfo.LastTaskResult))" -ForegroundColor Red
        }
        
        # Next run
        Write-Host "  Next Run: " -NoNewline
        if ($taskInfo.NextRunTime) {
            $timeUntil = $taskInfo.NextRunTime - (Get-Date)
            $timeUntilStr = if ($timeUntil.TotalMinutes -lt 60) {
                "in $([math]::Round($timeUntil.TotalMinutes, 1)) minutes"
            } elseif ($timeUntil.TotalHours -lt 24) {
                "in $([math]::Round($timeUntil.TotalHours, 1)) hours"
            } else {
                "in $([math]::Round($timeUntil.TotalDays, 1)) days"
            }
            Write-Host "$($taskInfo.NextRunTime) ($timeUntilStr)" -ForegroundColor Gray
        } else {
            Write-Host "Not scheduled" -ForegroundColor Yellow
        }
        
        # Missed runs
        Write-Host "  Missed Runs: " -NoNewline
        if ($taskInfo.NumberOfMissedRuns -eq 0) {
            Write-Host "0" -ForegroundColor Green
        } else {
            Write-Host "$($taskInfo.NumberOfMissedRuns)" -ForegroundColor Red
        }
        
        # Task action (what it runs)
        Write-Host "  Action: " -NoNewline
        $action = $task.Actions[0]
        if ($action.Execute -like "*PowerShell*") {
            Write-Host "PowerShell Script" -ForegroundColor Gray
            Write-Host "    File: $($action.Arguments -replace '.*-File "([^"]+)".*', '$1')" -ForegroundColor DarkGray
        } else {
            Write-Host "$($action.Execute) $($action.Arguments)" -ForegroundColor Gray
        }
        
        # Check for recent errors in Event Log
        Write-Host "  Recent Errors: " -NoNewline
        $errors = Get-WinEvent -FilterHashtable @{
            LogName = "Microsoft-Windows-TaskScheduler/Operational"
            ID = 201, 202, 203, 204, 205
            StartTime = (Get-Date).AddHours(-24)
        } -ErrorAction SilentlyContinue | Where-Object {
            $_.Message -like "*$taskName*"
        } | Select-Object -First 5
        
        if ($errors) {
            Write-Host "$($errors.Count) error(s) in last 24 hours" -ForegroundColor Red
            foreach ($err in $errors) {
                $cleanMessage = $err.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", ""
                Write-Host "    - $($err.TimeCreated): $cleanMessage" -ForegroundColor DarkRed
            }
        } else {
            Write-Host "None" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "  Status: NOT FOUND" -ForegroundColor Red
        Write-Host "  Error: Task does not exist or cannot be accessed" -ForegroundColor Red
        $allTasksFound = $false
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($allTasksFound) {
    Write-Host "All tasks found. Check status above for issues." -ForegroundColor Green
} else {
    Write-Host "Some tasks are missing. Run install-osquery.ps1 to create them." -ForegroundColor Yellow
}

# Quick commands to fix issues
Write-Host "`nQuick Fix Commands:" -ForegroundColor Cyan
Write-Host "  To manually run CommandProcessor: " -NoNewline -ForegroundColor Gray
Write-Host "Get-ScheduledTask -TaskName 'VigyanShaala-MDM-CommandProcessor' | Start-ScheduledTask" -ForegroundColor White
Write-Host "  To enable a disabled task: " -NoNewline -ForegroundColor Gray
Write-Host "Enable-ScheduledTask -TaskName 'VigyanShaala-MDM-CommandProcessor'" -ForegroundColor White
Write-Host "  To check task history: " -NoNewline -ForegroundColor Gray
Write-Host "Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' | Where-Object {`$_.Message -like '*VigyanShaala-MDM-CommandProcessor*'} | Select-Object -First 10" -ForegroundColor White

Write-Host "`n"

