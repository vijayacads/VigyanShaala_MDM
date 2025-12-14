# Silent Installation Script for osquery Agent
# This can be used for manual installation or included in MSI package
# Run with: .\install-osquery.ps1 -SupabaseUrl "https://xxx.supabase.co" -SupabaseKey "xxx" -FleetUrl "https://fleet.example.com"

param(
    [Parameter(Mandatory=$false)]
    [string]$OsqueryMsi = "osquery-5.20.0.msi",  # Latest stable version (Dec 2025) - supports battery table on Windows
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseKey,
    
    [Parameter(Mandatory=$false)]
    [string]$FleetUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$InstallDir = "$env:ProgramFiles\osquery"
)

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires Administrator privileges"
    exit 1
}

Write-Host "Installing osquery agent..." -ForegroundColor Green

# Step 1: Install osquery MSI silently
if (Test-Path $OsqueryMsi) {
    Write-Host "Installing osquery from: $OsqueryMsi" -ForegroundColor Yellow
    $installArgs = "/i `"$OsqueryMsi`" /qn /norestart INSTALLDIR=`"$InstallDir`""
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Host "osquery installed successfully" -ForegroundColor Green
    } else {
        Write-Error "osquery installation failed with exit code: $($process.ExitCode)"
        exit 1
    }
} else {
    Write-Error "osquery MSI not found: $OsqueryMsi"
    exit 1
}

# Step 2: Copy configuration files
$configDir = "$InstallDir\osquery.conf"
if (Test-Path "osquery.conf") {
    Copy-Item "osquery.conf" $configDir -Force
    Write-Host "Configuration file copied" -ForegroundColor Green
} else {
    Write-Warning "osquery.conf not found - using default configuration"
}

# Step 3: Copy enrollment scripts
$enrollScript = "$InstallDir\enroll-device.ps1"
if (Test-Path "enroll-device.ps1") {
    Copy-Item "enroll-device.ps1" $enrollScript -Force
    Write-Host "Enrollment script copied" -ForegroundColor Green
} elseif (Test-Path "enroll-fleet.ps1") {
    Copy-Item "enroll-fleet.ps1" "$InstallDir\enroll-fleet.ps1" -Force
    Write-Host "Legacy enrollment script copied" -ForegroundColor Green
}

# Step 4: Set environment variables for enrollment
if ($SupabaseUrl) {
    [Environment]::SetEnvironmentVariable("SUPABASE_URL", $SupabaseUrl, "Machine")
    Write-Host "Set SUPABASE_URL environment variable" -ForegroundColor Green
}

if ($SupabaseKey) {
    [Environment]::SetEnvironmentVariable("SUPABASE_ANON_KEY", $SupabaseKey, "Machine")
    Write-Host "Set SUPABASE_ANON_KEY environment variable" -ForegroundColor Green
}

if ($FleetUrl) {
    [Environment]::SetEnvironmentVariable("FLEET_SERVER_URL", $FleetUrl, "Machine")
    Write-Host "Set FLEET_SERVER_URL environment variable" -ForegroundColor Green
}

# Step 5: Create log directory (required for osquery to write logs)
$logDir = "C:\ProgramData\osquery\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    Write-Host "Created log directory: $logDir" -ForegroundColor Green
} else {
    Write-Host "Log directory exists: $logDir" -ForegroundColor Green
}

# Step 6: Install osquery service (if not already installed)
$serviceName = "osqueryd"
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if (-not $service) {
    Write-Host "Installing osquery service..." -ForegroundColor Yellow
    & "$InstallDir\osqueryd.exe" --install
    Start-Sleep -Seconds 2
}

# Step 7: Set osquery service to auto-start and start it
try {
    # Set service to automatic startup
    Set-Service -Name $serviceName -StartupType Automatic -ErrorAction Stop
    Write-Host "osquery service set to auto-start" -ForegroundColor Green
    
    # Start the service
    Start-Service -Name $serviceName -ErrorAction Stop
    Write-Host "osquery service started" -ForegroundColor Green
} catch {
    Write-Warning "Could not configure/start osquery service: $_"
}

# Step 8: Run enrollment wizard (if environment variables are set)
if ($SupabaseUrl -and $SupabaseKey) {
    Write-Host "`nStarting enrollment wizard..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    
    # Run enrollment script in new window so user can interact
    # Pass credentials as parameters since environment variables might not be inherited
    # Use -NoExit to keep window open for debugging
    if (Test-Path $enrollScript) {
        $enrollArgs = "-NoExit -ExecutionPolicy Bypass -File `"$enrollScript`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseAnonKey `"$SupabaseKey`""
        Write-Host "Launching enrollment wizard..." -ForegroundColor Cyan
        Start-Process powershell.exe -ArgumentList $enrollArgs -Wait
    } else {
        Write-Warning "Enrollment script not found at $enrollScript"
    }
} else {
    Write-Host "`nEnrollment wizard skipped (missing environment variables)" -ForegroundColor Yellow
    Write-Host "Run enroll-device.ps1 manually after setting environment variables" -ForegroundColor Yellow
}

# Step 9: Apply initial blocklists and create sync tasks
if ($SupabaseUrl -and $SupabaseKey) {
    Write-Host "`nApplying blocklists..." -ForegroundColor Cyan
    
    # Task 4: Website Blocklist Sync
    # ============================================
    Write-Host "`n[4/6] Setting up website blocklist sync..." -ForegroundColor Cyan
    Write-Host "Applying initial website blocklist..." -ForegroundColor Gray
    $websiteBlocklistScript = "$InstallDir\apply-website-blocklist.ps1"
    if (Test-Path "apply-website-blocklist.ps1") {
        Copy-Item "apply-website-blocklist.ps1" $websiteBlocklistScript -Force
        try {
            & $websiteBlocklistScript -SupabaseUrl $SupabaseUrl -SupabaseAnonKey $SupabaseKey
            Write-Host "Website blocklist applied" -ForegroundColor Green
        } catch {
            Write-Warning "Could not apply website blocklist: $_"
        }
    }
    
    Write-Host "Creating scheduled task for website blocklist sync..." -ForegroundColor Gray
    $websiteSyncScript = "$InstallDir\sync-blocklist-scheduled.ps1"
    if (Test-Path "sync-blocklist-scheduled.ps1") {
        Copy-Item "sync-blocklist-scheduled.ps1" $websiteSyncScript -Force
    }
    
    $websiteTaskName = "VigyanShaala-MDM-SyncWebsiteBlocklist"
    $websiteTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -File `"$websiteSyncScript`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseAnonKey `"$SupabaseKey`""
    $websiteTaskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 365)
    $websiteTaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $websiteTaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    try {
        Unregister-ScheduledTask -TaskName $websiteTaskName -Confirm:$false -ErrorAction SilentlyContinue
        $task = Register-ScheduledTask -TaskName $websiteTaskName -Action $websiteTaskAction -Trigger $websiteTaskTrigger -Principal $websiteTaskPrincipal -Settings $websiteTaskSettings -Description "Sync website blocklist from MDM server" -Force
        Enable-ScheduledTask -TaskName $websiteTaskName
        Write-Host "Website blocklist sync task created and enabled (runs every 30 minutes)" -ForegroundColor Green
    } catch {
        Write-Warning "Could not create website blocklist sync task: $_"
    }
    
    # Task 5: Software Blocklist Sync
    # ============================================
    Write-Host "`n[5/6] Setting up software blocklist sync..." -ForegroundColor Cyan
    Write-Host "Applying initial software blocklist..." -ForegroundColor Gray
    $softwareBlocklistScript = "$InstallDir\apply-software-blocklist.ps1"
    if (Test-Path "apply-software-blocklist.ps1") {
        Copy-Item "apply-software-blocklist.ps1" $softwareBlocklistScript -Force
        try {
            & $softwareBlocklistScript -SupabaseUrl $SupabaseUrl -SupabaseAnonKey $SupabaseKey
            Write-Host "Software blocklist checked and applied" -ForegroundColor Green
        } catch {
            Write-Warning "Could not apply software blocklist: $_"
        }
    }
    
    Write-Host "Creating scheduled task for software blocklist sync..." -ForegroundColor Gray
    $softwareSyncScript = "$InstallDir\sync-software-blocklist-scheduled.ps1"
    if (Test-Path "sync-software-blocklist-scheduled.ps1") {
        Copy-Item "sync-software-blocklist-scheduled.ps1" $softwareSyncScript -Force
    }
    
    $softwareTaskName = "VigyanShaala-MDM-SyncSoftwareBlocklist"
    $softwareTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -File `"$softwareSyncScript`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseAnonKey `"$SupabaseKey`""
    $softwareTaskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 365)
    $softwareTaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $softwareTaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    try {
        Unregister-ScheduledTask -TaskName $softwareTaskName -Confirm:$false -ErrorAction SilentlyContinue
        $task = Register-ScheduledTask -TaskName $softwareTaskName -Action $softwareTaskAction -Trigger $softwareTaskTrigger -Principal $softwareTaskPrincipal -Settings $softwareTaskSettings -Description "Check and remove blocked software from MDM server" -Force
        Enable-ScheduledTask -TaskName $softwareTaskName
        Write-Host "Software blocklist sync task created and enabled (runs every hour)" -ForegroundColor Green
    } catch {
        Write-Warning "Could not create software blocklist sync task: $_"
    }
    
    # ============================================
    # SCHEDULED TASKS - SYSTEM LEVEL
    # All tasks run as SYSTEM account for background operations
    # ============================================
    
    # Task 1: Data Sending (sends osquery data to Supabase)
    # ============================================
    Write-Host "`n[1/6] Creating scheduled task to send osquery data..." -ForegroundColor Cyan
    $sendDataScript = "$InstallDir\send-osquery-data.ps1"
    if (Test-Path "send-osquery-data.ps1") {
        Copy-Item "send-osquery-data.ps1" $sendDataScript -Force
        Write-Host "send-osquery-data.ps1 copied" -ForegroundColor Green
    } else {
        Write-Warning "send-osquery-data.ps1 not found in current directory - task may fail"
    }
    
    $dataTaskName = "VigyanShaala-MDM-SendOsqueryData"
    $dataTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -File `"$sendDataScript`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseAnonKey `"$SupabaseKey`""
    
    # Create trigger that runs every 25 minutes, starting now
    $dataTaskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 25) -RepetitionDuration (New-TimeSpan -Days 365)
    
    # Use SYSTEM account to run regardless of logged-in user
    $dataTaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # Create settings to ensure task runs even when user is not logged in
    $dataTaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false
    
    try {
        # Remove existing task if it exists
        Unregister-ScheduledTask -TaskName $dataTaskName -Confirm:$false -ErrorAction SilentlyContinue
        
        # Register the task
        $task = Register-ScheduledTask -TaskName $dataTaskName -Action $dataTaskAction -Trigger $dataTaskTrigger -Principal $dataTaskPrincipal -Settings $dataTaskSettings -Description "Send osquery data to MDM server every 25 minutes" -Force
        
        # Explicitly enable the task (runs regardless of user login)
        Enable-ScheduledTask -TaskName $dataTaskName
        
        Write-Host "Data sending task created and enabled (runs every 25 minutes, regardless of user login)" -ForegroundColor Green
    } catch {
        Write-Warning "Could not create data sending task: $_"
    }
    
    # Task 2: Battery Data Collection (WMI-based)
    # ============================================
    Write-Host "`n[2/6] Creating scheduled task for battery data collection (WMI)..." -ForegroundColor Cyan
    $batteryScript = "$InstallDir\get-battery-wmi.ps1"
    if (Test-Path "get-battery-wmi.ps1") {
        Copy-Item "get-battery-wmi.ps1" $batteryScript -Force
        Write-Host "get-battery-wmi.ps1 copied" -ForegroundColor Green
    } else {
        Write-Warning "get-battery-wmi.ps1 not found - battery data collection will not work"
    }
    
    $batteryTaskName = "VigyanShaala-MDM-CollectBatteryData"
    $batteryTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -File `"$batteryScript`""
    $batteryTaskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 25) -RepetitionDuration (New-TimeSpan -Days 365)
    $batteryTaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $batteryTaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false
    
    try {
        Unregister-ScheduledTask -TaskName $batteryTaskName -Confirm:$false -ErrorAction SilentlyContinue
        $task = Register-ScheduledTask -TaskName $batteryTaskName -Action $batteryTaskAction -Trigger $batteryTaskTrigger -Principal $batteryTaskPrincipal -Settings $batteryTaskSettings -Description "Collect battery data using WMI every 25 minutes" -Force
        Enable-ScheduledTask -TaskName $batteryTaskName
        Write-Host "Battery data collection task created and enabled (runs every 25 minutes)" -ForegroundColor Green
    } catch {
        Write-Warning "Could not create battery data collection task: $_"
    }
    
    # Task 3: Realtime Command Listener (WebSocket-based, primary method)
    # ============================================
    Write-Host "`n[3/6] Creating scheduled task for realtime command listener (WebSocket)..." -ForegroundColor Cyan
    $realtimeScript = "$InstallDir\realtime-command-listener.ps1"
    if (Test-Path "realtime-command-listener.ps1") {
        Copy-Item "realtime-command-listener.ps1" $realtimeScript -Force
        Write-Host "realtime-command-listener.ps1 copied" -ForegroundColor Green
    } else {
        Write-Warning "realtime-command-listener.ps1 not found - realtime command processing will not work"
    }
    
    # Copy execute-commands.ps1 (required by realtime listener for function imports)
    $commandScript = "$InstallDir\execute-commands.ps1"
    if (Test-Path "execute-commands.ps1") {
        Copy-Item "execute-commands.ps1" $commandScript -Force
        Write-Host "execute-commands.ps1 copied (required by realtime listener)" -ForegroundColor Green
    } else {
        Write-Warning "execute-commands.ps1 not found - realtime listener will not work"
    }
    
    $realtimeTaskName = "VigyanShaala-MDM-RealtimeListener"
    $realtimeTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -File `"$realtimeScript`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseKey `"$SupabaseKey`""
    # Run at startup and restart on failure (continuous service-like behavior)
    $realtimeTaskTrigger = New-ScheduledTaskTrigger -AtStartup
    $realtimeTaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $realtimeTaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Hours 0)
    
    try {
        Unregister-ScheduledTask -TaskName $realtimeTaskName -Confirm:$false -ErrorAction SilentlyContinue
        $task = Register-ScheduledTask -TaskName $realtimeTaskName -Action $realtimeTaskAction -Trigger $realtimeTaskTrigger -Principal $realtimeTaskPrincipal -Settings $realtimeTaskSettings -Description "Realtime WebSocket listener for instant command processing (runs continuously)" -Force
        Enable-ScheduledTask -TaskName $realtimeTaskName
        Write-Host "Realtime listener task created and enabled (runs at startup, restarts on failure)" -ForegroundColor Green
    } catch {
        Write-Warning "Could not create realtime listener task: $_"
    }
    
    # ============================================
    # SCHEDULED TASKS - USER LEVEL
    # Runs in user session for UI/audio access
    # ============================================
    
    # Task 6: User Session Notification Agent (runs at user logon)
    # ============================================
    Write-Host "`n[6/6] Setting up user-session notification agent..." -ForegroundColor Cyan
    $userNotifyScript = "$InstallDir\user-notify-agent.ps1"
    if (Test-Path "user-notify-agent.ps1") {
        Copy-Item "user-notify-agent.ps1" $userNotifyScript -Force
        Write-Host "user-notify-agent.ps1 copied" -ForegroundColor Green
    } else {
        Write-Warning "user-notify-agent.ps1 not found - user notifications will not work"
    }
    
    # Create scheduled task that runs at user logon
    # This task runs in each user's session when they log on
    $userNotifyTaskName = "VigyanShaala-UserNotify-Agent"
    $userNotifyTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$userNotifyScript`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseKey `"$SupabaseKey`" -PollInterval 5"
    
    # Trigger: At logon (for any user)
    $userNotifyTaskTrigger = New-ScheduledTaskTrigger -AtLogOn
    
    # Principal: Run as the user who logs on (use "Users" group or current user)
    # For per-user tasks, we need to create it in the user's task folder
    # But for simplicity, we'll create it to run for the "Users" group
    # This will run for any user who logs on
    try {
        # Try to get current logged-on user
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $userNotifyTaskPrincipal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Limited
        Write-Host "Creating user notification task for: $currentUser" -ForegroundColor Gray
    } catch {
        # Fallback: Use "Users" group (runs for any user)
        $userNotifyTaskPrincipal = New-ScheduledTaskPrincipal -GroupId "Users" -LogonType Interactive -RunLevel Limited
        Write-Host "Creating user notification task for Users group" -ForegroundColor Gray
    }
    
    # Settings: Run only when user is logged on, allow start on batteries, no time limit
    $userNotifyTaskSettings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable:$false `
        -ExecutionTimeLimit (New-TimeSpan -Hours 0)  # No time limit (runs continuously)
    
    try {
        # Remove existing task if it exists
        Unregister-ScheduledTask -TaskName $userNotifyTaskName -Confirm:$false -ErrorAction SilentlyContinue
        
        # Register the task
        $task = Register-ScheduledTask -TaskName $userNotifyTaskName `
            -Action $userNotifyTaskAction `
            -Trigger $userNotifyTaskTrigger `
            -Principal $userNotifyTaskPrincipal `
            -Settings $userNotifyTaskSettings `
            -Description "VigyanShaala MDM User Notification Agent - Handles buzz and toast notifications in user session" `
            -Force
        
        Enable-ScheduledTask -TaskName $userNotifyTaskName
        Write-Host "User notification agent task created (runs at user logon)" -ForegroundColor Green
        Write-Host "Note: This task runs in the logged-on user's session for UI/audio access" -ForegroundColor Yellow
    } catch {
        Write-Warning "Could not create user notification agent task: $_"
        Write-Warning "User notifications (buzz/toast) will not work until this task is created"
        Write-Warning "You may need to create this task manually for each user, or run the installer as each user"
    }
    
    # Copy chat interface script
    if (Test-Path "chat-interface.ps1") {
        Copy-Item "chat-interface.ps1" "$InstallDir\chat-interface.ps1" -Force
        Write-Host "Chat interface script copied" -ForegroundColor Green
    }
    
    # Copy logo if available (for desktop shortcut icon)
    $logoPath = "$InstallDir\Logo.png"
    if (Test-Path "Logo.png") {
        Copy-Item "Logo.png" $logoPath -Force
        Write-Host "Logo copied" -ForegroundColor Green
    } elseif (Test-Path "..\dashboard\public\Logo.png") {
        Copy-Item "..\dashboard\public\Logo.png" $logoPath -Force
        Write-Host "Logo copied from dashboard" -ForegroundColor Green
    }
    
    # Create chat launcher batch file
    $launcherPath = "$InstallDir\VigyanShaala_Chat.bat"
    @"
@echo off
cd /d "$InstallDir"

REM Get environment variables from system
set SUPABASE_URL=%SUPABASE_URL%
set SUPABASE_KEY=%SUPABASE_ANON_KEY%

REM Check if script exists
if not exist "chat-interface.ps1" (
    echo ERROR: chat-interface.ps1 not found!
    pause
    exit /b 1
)

REM Run PowerShell script with error handling
powershell.exe -ExecutionPolicy Bypass -NoExit -File "chat-interface.ps1" -SupabaseUrl "%SUPABASE_URL%" -SupabaseKey "%SUPABASE_KEY%"

if errorlevel 1 (
    echo.
    echo ERROR: Chat interface failed to start.
    pause
)
"@ | Out-File $launcherPath -Encoding ASCII -Force
    Write-Host "Chat launcher created" -ForegroundColor Green
    
    # Create desktop shortcut with logo icon
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = "$desktopPath\VigyanShaala Chat.lnk"
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = $launcherPath
        $Shortcut.WorkingDirectory = $InstallDir
        $Shortcut.Description = "VigyanShaala MDM Chat & Broadcast Messages"
        if (Test-Path $logoPath) {
            # Convert PNG to ICO for icon (Windows shortcut icons need ICO format)
            # For now, we'll use the PNG path - Windows 10+ supports PNG in shortcuts
            $Shortcut.IconLocation = "$logoPath,0"
        }
        $Shortcut.Save()
        Write-Host "Desktop shortcut created: VigyanShaala Chat" -ForegroundColor Green
    } catch {
        Write-Warning "Could not create desktop shortcut: $_"
    }
}

Write-Host "`nInstallation complete!" -ForegroundColor Green
Write-Host "`nInstalled components:" -ForegroundColor Cyan
Write-Host "- osquery agent: $InstallDir" -ForegroundColor White
Write-Host "- Service: $serviceName" -ForegroundColor White
Write-Host "- Configuration: $configDir" -ForegroundColor White
