# Clean Slate: Complete MDM Uninstall and Fresh Install Guide

This document provides a comprehensive guide for completely removing all MDM components from a Windows device and performing a fresh installation. Use this when you need to start from scratch.

---

## Part 1: Complete Uninstallation

### Step 1: Stop All Running Processes

Run these commands in PowerShell (as Administrator):

```powershell
# Stop osquery processes
Get-Process | Where-Object { $_.ProcessName -like "*osquery*" } | Stop-Process -Force -ErrorAction SilentlyContinue

# Stop any PowerShell scripts that might be running
Get-Process | Where-Object { $_.ProcessName -eq "powershell" -and $_.CommandLine -like "*osquery*" } | Stop-Process -Force -ErrorAction SilentlyContinue

# Wait a moment for processes to stop
Start-Sleep -Seconds 2
```

### Step 2: Remove All Scheduled Tasks

Remove all MDM-related scheduled tasks:

```powershell
# List of all MDM scheduled tasks
$tasksToRemove = @(
    "VigyanShaala-MDM-RealtimeListener",
    "VigyanShaala-MDM-UserNotify-Agent",
    "VigyanShaala-UserNotify-Agent",  # Alternative name
    "VigyanShaala-MDM-OsqueryHealth",
    "VigyanShaala-MDM-OsquerySoftware",
    "VigyanShaala-MDM-OsqueryWebActivity",
    "VigyanShaala-MDM-OsqueryGeofence",
    "VigyanShaala-MDM-OsqueryHeartbeat",
    "VigyanShaala-MDM-SendOsqueryData",
    "VigyanShaala-MDM-SyncWebsiteBlocklist",
    "VigyanShaala-MDM-SyncSoftwareBlocklist",
    "VigyanShaala-MDM-CollectBatteryData",
    "VigyanShaala-MDM-CommandProcessor"  # Legacy task name
)

# Remove each task
foreach ($taskName in $tasksToRemove) {
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Host "Removed task: $taskName" -ForegroundColor Green
    } catch {
        Write-Host "Task not found or already removed: $taskName" -ForegroundColor Yellow
    }
}

# Verify all tasks are removed
Write-Host "`nRemaining MDM tasks:" -ForegroundColor Cyan
Get-ScheduledTask | Where-Object { $_.TaskName -like "*VigyanShaala*" -or $_.TaskName -like "*osquery*" } | Select-Object TaskName, State
```

### Step 3: Stop and Remove osquery Service

```powershell
# Stop the service if running
$serviceName = "osqueryd"
try {
    $service = Get-Service -Name $serviceName -ErrorAction Stop
    if ($service.Status -eq "Running") {
        Stop-Service -Name $serviceName -Force
        Write-Host "Stopped service: $serviceName" -ForegroundColor Green
    }
    Start-Sleep -Seconds 2
    
    # Remove the service
    sc.exe delete $serviceName
    Write-Host "Removed service: $serviceName" -ForegroundColor Green
} catch {
    Write-Host "Service not found or already removed: $serviceName" -ForegroundColor Yellow
}
```

### Step 4: Remove All Files and Directories

```powershell
# Main installation directory
$installDir = "C:\Program Files\osquery"

# Kill any processes that might be locking files
Get-Process | Where-Object { $_.Path -like "*osquery*" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Remove read-only attributes and delete files
if (Test-Path $installDir) {
    Write-Host "Removing installation directory: $installDir" -ForegroundColor Yellow
    
    # Remove read-only attributes recursively
    Get-ChildItem -Path $installDir -Recurse -Force | ForEach-Object {
        $_.Attributes = $_.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
    }
    
    # Delete files individually first
    Get-ChildItem -Path $installDir -Recurse -Force -File | Remove-Item -Force -ErrorAction SilentlyContinue
    
    # Then delete directories with retry logic
    $maxRetries = 5
    $retryCount = 0
    while ((Test-Path $installDir) -and $retryCount -lt $maxRetries) {
        try {
            Remove-Item -Path $installDir -Recurse -Force -ErrorAction Stop
            Write-Host "Removed directory: $installDir" -ForegroundColor Green
        } catch {
            $retryCount++
            Write-Host "Retry $retryCount/$maxRetries - Waiting before retry..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            # Kill any processes that might have restarted
            Get-Process | Where-Object { $_.Path -like "*osquery*" } | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }
    
    if (Test-Path $installDir) {
        Write-Warning "Could not fully remove $installDir - some files may be locked"
    }
}

# Remove ProgramData osquery directory
$programDataDir = "C:\ProgramData\osquery"
if (Test-Path $programDataDir) {
    Write-Host "Removing ProgramData directory: $programDataDir" -ForegroundColor Yellow
    Remove-Item -Path $programDataDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Remove log files
$logFiles = @(
    "$env:TEMP\VigyanShaala-RealtimeListener.log",
    "$env:TEMP\VigyanShaala-UserNotify.log",
    "$env:TEMP\VigyanShaala-Osquery*.log",
    "C:\Windows\TEMP\VigyanShaala-*.log"
)

foreach ($logFile in $logFiles) {
    if (Test-Path $logFile) {
        Remove-Item -Path $logFile -Force -ErrorAction SilentlyContinue
        Write-Host "Removed log: $logFile" -ForegroundColor Gray
    }
}

# Remove desktop shortcuts
$desktopShortcuts = @(
    "$env:PUBLIC\Desktop\VigyanShaala Chat.lnk",
    "$env:USERPROFILE\Desktop\VigyanShaala Chat.lnk"
)

foreach ($shortcut in $desktopShortcuts) {
    if (Test-Path $shortcut) {
        Remove-Item -Path $shortcut -Force -ErrorAction SilentlyContinue
        Write-Host "Removed shortcut: $shortcut" -ForegroundColor Gray
    }
}
```

### Step 5: Remove Registry Entries

```powershell
# Registry paths to clean
$registryPaths = @(
    "HKLM:\SOFTWARE\osquery",
    "HKLM:\SOFTWARE\VigyanShaala",
    "HKLM:\SYSTEM\CurrentControlSet\Services\osqueryd",
    "HKCU:\SOFTWARE\osquery",
    "HKCU:\SOFTWARE\VigyanShaala"
)

foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        try {
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
            Write-Host "Removed registry: $regPath" -ForegroundColor Green
        } catch {
            Write-Warning "Could not remove registry: $regPath - $_"
        }
    }
}
```

### Step 6: Remove Windows Firewall Rules

```powershell
# Remove firewall rules
$firewallRules = @(
    "osquery",
    "VigyanShaala"
)

foreach ($ruleName in $firewallRules) {
    try {
        $rules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*$ruleName*" }
        foreach ($rule in $rules) {
            Remove-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue
            Write-Host "Removed firewall rule: $($rule.DisplayName)" -ForegroundColor Gray
        }
    } catch {
        # Ignore errors
    }
}
```

### Step 7: Remove Environment Variables

```powershell
# Remove system-wide environment variables
$envVars = @(
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY"
)

foreach ($varName in $envVars) {
    try {
        [Environment]::SetEnvironmentVariable($varName, $null, "Machine")
        Write-Host "Removed environment variable: $varName" -ForegroundColor Green
    } catch {
        Write-Warning "Could not remove environment variable: $varName - $_"
    }
}

# Also remove from current session
Remove-Item Env:\SUPABASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:\SUPABASE_ANON_KEY -ErrorAction SilentlyContinue
```

### Step 8: Remove Website Blocklist Entries (Hosts File)

```powershell
# Remove entries from hosts file
$hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
if (Test-Path $hostsFile) {
    $hostsContent = Get-Content $hostsFile -ErrorAction SilentlyContinue
    $filteredContent = $hostsContent | Where-Object { $_ -notlike "*VigyanShaala*" -and $_ -notlike "*# MDM Blocklist*" }
    
    if ($filteredContent.Count -ne $hostsContent.Count) {
        try {
            $filteredContent | Set-Content $hostsFile -Force
            Write-Host "Cleaned hosts file" -ForegroundColor Green
        } catch {
            Write-Warning "Could not modify hosts file - may require manual editing"
        }
    }
}
```

### Step 9: Remove Startup Entries

```powershell
# Remove from startup registry
$startupPaths = @(
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)

foreach ($startupPath in $startupPaths) {
    if (Test-Path $startupPath) {
        $startupKeys = Get-ItemProperty $startupPath | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -like "*osquery*" -or $_.Name -like "*VigyanShaala*" }
        foreach ($key in $startupKeys) {
            try {
                Remove-ItemProperty -Path $startupPath -Name $key.Name -Force -ErrorAction Stop
                Write-Host "Removed startup entry: $($key.Name)" -ForegroundColor Green
            } catch {
                # Ignore errors
            }
        }
    }
}
```

### Step 10: Verify Complete Removal

```powershell
Write-Host "`n=== Verification ===" -ForegroundColor Cyan

# Check for remaining processes
$remainingProcesses = Get-Process | Where-Object { $_.ProcessName -like "*osquery*" }
if ($remainingProcesses) {
    Write-Warning "Remaining processes found:"
    $remainingProcesses | Format-Table ProcessName, Id, Path
} else {
    Write-Host "✓ No osquery processes running" -ForegroundColor Green
}

# Check for remaining tasks
$remainingTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*VigyanShaala*" -or $_.TaskName -like "*osquery*" }
if ($remainingTasks) {
    Write-Warning "Remaining scheduled tasks found:"
    $remainingTasks | Format-Table TaskName, State
} else {
    Write-Host "✓ No MDM scheduled tasks found" -ForegroundColor Green
}

# Check for remaining directories
$remainingDirs = @(
    "C:\Program Files\osquery",
    "C:\ProgramData\osquery"
)

foreach ($dir in $remainingDirs) {
    if (Test-Path $dir) {
        Write-Warning "Directory still exists: $dir"
    } else {
        Write-Host "✓ Directory removed: $dir" -ForegroundColor Green
    }
}

# Check for remaining services
$remainingServices = Get-Service | Where-Object { $_.Name -like "*osquery*" }
if ($remainingServices) {
    Write-Warning "Remaining services found:"
    $remainingServices | Format-Table Name, Status
} else {
    Write-Host "✓ No osquery services found" -ForegroundColor Green
}

Write-Host "`nUninstallation verification complete!" -ForegroundColor Cyan
```

---

## Part 2: Fresh Installation

After completing the uninstallation, perform a fresh installation using the installer package.

### Step 1: Download Latest Installer

1. Go to the Render dashboard (production)
2. Navigate to the Downloads section
3. Download `VigyanShaala-MDM-Installer.zip`
4. Extract the ZIP file to a temporary location (e.g., `C:\Temp\MDM-Installer`)

### Step 2: Verify Installer Contents

Before running the installer, verify it contains all required files:

```powershell
$installerPath = "C:\Temp\MDM-Installer"  # Adjust path as needed

$requiredFiles = @(
    "INSTALL.ps1",
    "INSTALL.bat",
    "enroll-device.ps1",
    "install-osquery.ps1",
    "realtime-command-listener.ps1",
    "execute-commands.ps1",
    "user-notify-agent.ps1",
    "uninstall-osquery.ps1",
    "osquery.exe",
    "osquery.conf",
    "osquery.flags",
    "README-TEACHER.md"
)

Write-Host "Checking installer contents..." -ForegroundColor Cyan
$missingFiles = @()

foreach ($file in $requiredFiles) {
    $filePath = Join-Path $installerPath $file
    if (Test-Path $filePath) {
        Write-Host "✓ $file" -ForegroundColor Green
    } else {
        Write-Host "✗ Missing: $file" -ForegroundColor Red
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Warning "Installer is incomplete! Missing files:"
    $missingFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "`nDo not proceed with installation until all files are present." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`n✓ All required files present. Ready for installation." -ForegroundColor Green
}
```

### Step 3: Run Installation

**Option A: Using INSTALL.bat (Recommended for Teachers)**

1. Navigate to the extracted installer directory
2. Double-click `INSTALL.bat`
3. The installer will run automatically with pre-configured Supabase credentials

**Option B: Using INSTALL.ps1 (Manual)**

```powershell
# Navigate to installer directory
cd "C:\Temp\MDM-Installer"

# Run installer with Supabase credentials
.\INSTALL.ps1 `
    -SupabaseUrl "https://thqinhphunrflwlshdmx.supabase.co" `
    -SupabaseKey "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRocWluaHBodW5yZmx3bHNoZG14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4Njk2ODcsImV4cCI6MjA4MTQ0NTY4N30.nVTHifwIDIozcqerE-X7zmebO6Pag8Ji-N3d4jetaQM"
```

### Step 4: Verify Installation

After installation completes, verify all components:

```powershell
Write-Host "=== Installation Verification ===" -ForegroundColor Cyan

# 1. Check osquery service
$service = Get-Service -Name "osqueryd" -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "✓ osquery service installed (Status: $($service.Status))" -ForegroundColor Green
} else {
    Write-Warning "✗ osquery service not found"
}

# 2. Check scheduled tasks
$requiredTasks = @(
    "VigyanShaala-MDM-RealtimeListener",
    "VigyanShaala-MDM-UserNotify-Agent",
    "VigyanShaala-MDM-OsqueryHealth",
    "VigyanShaala-MDM-OsquerySoftware",
    "VigyanShaala-MDM-OsqueryWebActivity",
    "VigyanShaala-MDM-OsqueryGeofence",
    "VigyanShaala-MDM-OsqueryHeartbeat",
    "VigyanShaala-MDM-SendOsqueryData",
    "VigyanShaala-MDM-SyncWebsiteBlocklist",
    "VigyanShaala-MDM-SyncSoftwareBlocklist",
    "VigyanShaala-MDM-CollectBatteryData"
)

Write-Host "`nChecking scheduled tasks..." -ForegroundColor Yellow
foreach ($taskName in $requiredTasks) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
        $status = if ($taskInfo.LastTaskResult -eq 0) { "✓" } else { "⚠" }
        Write-Host "$status $taskName (State: $($task.State), Last Result: $($taskInfo.LastTaskResult))" -ForegroundColor $(if ($taskInfo.LastTaskResult -eq 0) { "Green" } else { "Yellow" })
    } else {
        Write-Host "✗ $taskName - NOT FOUND" -ForegroundColor Red
    }
}

# 3. Check installation directory
$installDir = "C:\Program Files\osquery"
if (Test-Path $installDir) {
    Write-Host "`n✓ Installation directory exists: $installDir" -ForegroundColor Green
    
    # Check critical files
    $criticalFiles = @(
        "osquery.exe",
        "osquery.conf",
        "realtime-command-listener.ps1",
        "execute-commands.ps1",
        "user-notify-agent.ps1"
    )
    
    Write-Host "`nChecking critical files..." -ForegroundColor Yellow
    foreach ($file in $criticalFiles) {
        $filePath = Join-Path $installDir $file
        if (Test-Path $filePath) {
            Write-Host "  ✓ $file" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Missing: $file" -ForegroundColor Red
        }
    }
} else {
    Write-Warning "✗ Installation directory not found: $installDir"
}

# 4. Check environment variables
Write-Host "`nChecking environment variables..." -ForegroundColor Yellow
$supabaseUrl = [Environment]::GetEnvironmentVariable("SUPABASE_URL", "Machine")
$supabaseKey = [Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY", "Machine")

if ($supabaseUrl) {
    Write-Host "  ✓ SUPABASE_URL is set" -ForegroundColor Green
} else {
    Write-Host "  ✗ SUPABASE_URL not set" -ForegroundColor Red
}

if ($supabaseKey) {
    Write-Host "  ✓ SUPABASE_ANON_KEY is set" -ForegroundColor Green
} else {
    Write-Host "  ✗ SUPABASE_ANON_KEY not set" -ForegroundColor Red
}

# 5. Check logs
Write-Host "`nChecking logs..." -ForegroundColor Yellow
$logFiles = @(
    "$env:TEMP\VigyanShaala-RealtimeListener.log",
    "$env:TEMP\VigyanShaala-UserNotify.log"
)

foreach ($logFile in $logFiles) {
    if (Test-Path $logFile) {
        $logSize = (Get-Item $logFile).Length
        Write-Host "  ✓ $(Split-Path $logFile -Leaf) exists ($logSize bytes)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ $(Split-Path $logFile -Leaf) not found (may be created on first run)" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Verification Complete ===" -ForegroundColor Cyan
```

### Step 5: Test Device Commands

After installation, test that commands work:

1. **Test Buzz Command:**
   - Go to dashboard
   - Select the device
   - Send "buzz" command
   - Device should play beep sounds

2. **Test Lock Command:**
   - Send "lock" command from dashboard
   - Device should lock immediately

3. **Test Clear Cache:**
   - Send "clear_cache" command
   - Check logs for completion

4. **Check Realtime Listener:**
   ```powershell
   Get-Content "$env:TEMP\VigyanShaala-RealtimeListener.log" -Tail 20
   ```

5. **Check User Notify Agent:**
   ```powershell
   Get-Content "$env:TEMP\VigyanShaala-UserNotify.log" -Tail 20
   ```

---

## Part 3: Troubleshooting

### Issue: Scheduled Tasks Not Running

```powershell
# Check task state
Get-ScheduledTask -TaskName "VigyanShaala-MDM-UserNotify-Agent" | Format-List *

# Check last run result
Get-ScheduledTaskInfo -TaskName "VigyanShaala-MDM-UserNotify-Agent" | Format-List *

# Manually start task
Start-ScheduledTask -TaskName "VigyanShaala-MDM-UserNotify-Agent"

# Check if task is enabled
Enable-ScheduledTask -TaskName "VigyanShaala-MDM-UserNotify-Agent"
```

### Issue: Commands Not Working

1. **Check Realtime Listener:**
   ```powershell
   Get-Content "C:\Windows\TEMP\VigyanShaala-RealtimeListener.log" -Tail 50 | Select-String "INSERT|Processing|ERROR"
   ```

2. **Check User Notify Agent:**
   ```powershell
   Get-Content "$env:TEMP\VigyanShaala-UserNotify.log" -Tail 50
   ```

3. **Verify Supabase Connection:**
   ```powershell
   # Check environment variables
   [Environment]::GetEnvironmentVariable("SUPABASE_URL", "Machine")
   [Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY", "Machine")
   ```

### Issue: Device Not Enrolling

1. Check enrollment script logs
2. Verify Supabase credentials in installer
3. Check RLS policies in Supabase (device enrollment should work with anon key)

---

## Part 4: Complete Uninstall Script

For convenience, here's a complete uninstall script that combines all steps:

```powershell
# Complete MDM Uninstall Script
# Run as Administrator

Write-Host "=== Complete MDM Uninstall ===" -ForegroundColor Cyan

# Stop processes
Write-Host "`n[1/10] Stopping processes..." -ForegroundColor Yellow
Get-Process | Where-Object { $_.ProcessName -like "*osquery*" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Remove scheduled tasks
Write-Host "`n[2/10] Removing scheduled tasks..." -ForegroundColor Yellow
$tasksToRemove = @(
    "VigyanShaala-MDM-RealtimeListener",
    "VigyanShaala-MDM-UserNotify-Agent",
    "VigyanShaala-UserNotify-Agent",  # Alternative name
    "VigyanShaala-MDM-OsqueryHealth",
    "VigyanShaala-MDM-OsquerySoftware",
    "VigyanShaala-MDM-OsqueryWebActivity",
    "VigyanShaala-MDM-OsqueryGeofence",
    "VigyanShaala-MDM-OsqueryHeartbeat",
    "VigyanShaala-MDM-SendOsqueryData",
    "VigyanShaala-MDM-SyncWebsiteBlocklist",
    "VigyanShaala-MDM-SyncSoftwareBlocklist",
    "VigyanShaala-MDM-CollectBatteryData",
    "VigyanShaala-MDM-CommandProcessor"  # Legacy task name
)
foreach ($taskName in $tasksToRemove) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
}

# Stop and remove service
Write-Host "`n[3/10] Removing service..." -ForegroundColor Yellow
$serviceName = "osqueryd"
try {
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    sc.exe delete $serviceName | Out-Null
} catch {}

# Remove directories
Write-Host "`n[4/10] Removing directories..." -ForegroundColor Yellow
$dirsToRemove = @(
    "C:\Program Files\osquery",
    "C:\ProgramData\osquery"
)
foreach ($dir in $dirsToRemove) {
    if (Test-Path $dir) {
        Get-ChildItem -Path $dir -Recurse -Force | ForEach-Object { $_.Attributes = $_.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly) }
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Remove registry entries
Write-Host "`n[5/10] Removing registry entries..." -ForegroundColor Yellow
$registryPaths = @(
    "HKLM:\SOFTWARE\osquery",
    "HKLM:\SOFTWARE\VigyanShaala",
    "HKLM:\SYSTEM\CurrentControlSet\Services\osqueryd"
)
foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Remove environment variables
Write-Host "`n[6/10] Removing environment variables..." -ForegroundColor Yellow
[Environment]::SetEnvironmentVariable("SUPABASE_URL", $null, "Machine")
[Environment]::SetEnvironmentVariable("SUPABASE_ANON_KEY", $null, "Machine")

# Remove firewall rules
Write-Host "`n[7/10] Removing firewall rules..." -ForegroundColor Yellow
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*osquery*" -or $_.DisplayName -like "*VigyanShaala*" } | Remove-NetFirewallRule -ErrorAction SilentlyContinue

# Remove log files
Write-Host "`n[8/10] Removing log files..." -ForegroundColor Yellow
Remove-Item "$env:TEMP\VigyanShaala-*.log" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\TEMP\VigyanShaala-*.log" -Force -ErrorAction SilentlyContinue

# Remove shortcuts
Write-Host "`n[9/10] Removing shortcuts..." -ForegroundColor Yellow
Remove-Item "$env:PUBLIC\Desktop\VigyanShaala Chat.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Desktop\VigyanShaala Chat.lnk" -Force -ErrorAction SilentlyContinue

# Final verification
Write-Host "`n[10/10] Verification..." -ForegroundColor Yellow
$remaining = Get-ScheduledTask | Where-Object { $_.TaskName -like "*VigyanShaala*" }
if ($remaining) {
    Write-Warning "Some tasks still remain - may need manual removal"
} else {
    Write-Host "✓ All scheduled tasks removed" -ForegroundColor Green
}

Write-Host "`n=== Uninstall Complete ===" -ForegroundColor Green
Write-Host "You can now perform a fresh installation." -ForegroundColor Cyan
```

---

## Summary

This guide provides:

1. **Complete Uninstallation:** Removes all MDM components, tasks, services, files, registry entries, and environment variables
2. **Fresh Installation Steps:** Detailed instructions for installing from scratch
3. **Verification Steps:** Commands to verify both uninstall and install
4. **Troubleshooting:** Common issues and solutions
5. **Complete Script:** Automated uninstall script for convenience

**Next Steps for AI Agent:**
- Execute Part 1 (Uninstallation) completely
- Verify all components are removed
- Then proceed with Part 2 (Fresh Installation)
- Verify installation success
- Test device commands

**Important Notes:**
- All commands must be run as Administrator
- The device will need to be re-enrolled after fresh installation
- Supabase credentials are pre-configured in INSTALL.bat
- User-notify-agent task must run continuously in user session
- All device commands (buzz, lock, cache, unlock) now queue to user-session agent

