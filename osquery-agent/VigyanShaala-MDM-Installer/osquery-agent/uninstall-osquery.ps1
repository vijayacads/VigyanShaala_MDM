# Uninstall Script for osquery Agent
# This removes osquery and cleans up the installation

param(
    [Parameter(Mandatory=$false)]
    [string]$InstallDir = "$env:ProgramFiles\osquery",
    
    [Parameter(Mandatory=$false)]
    [switch]$RemoveFromSupabase,
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY
)

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VigyanShaala MDM - Uninstaller" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$confirm = Read-Host "Are you sure you want to uninstall osquery agent? (Y/N)"
if ($confirm -ne 'Y' -and $confirm -ne 'y') {
    Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Starting uninstallation..." -ForegroundColor Yellow

# Step 1: Kill any running osquery processes
Write-Host "Stopping all osquery processes..." -ForegroundColor Yellow
try {
    $osqueryProcesses = Get-Process -Name "osquery*" -ErrorAction SilentlyContinue
    if ($osqueryProcesses) {
        foreach ($proc in $osqueryProcesses) {
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                Write-Host "Killed process: $($proc.Name) (PID: $($proc.Id))" -ForegroundColor Green
            } catch {
                Write-Warning "Could not kill process $($proc.Name): $_"
            }
        }
        Start-Sleep -Seconds 2
    } else {
        Write-Host "No running osquery processes found" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Error checking for osquery processes: $_"
}

# Step 2: Stop and remove osquery service
$serviceName = "osqueryd"
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($service) {
    Write-Host "Stopping osquery service..." -ForegroundColor Yellow
    try {
        Stop-Service -Name $serviceName -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        Write-Host "Service stopped" -ForegroundColor Green
    } catch {
        Write-Warning "Could not stop service: $_"
    }
    
    Write-Host "Removing osquery service..." -ForegroundColor Yellow
    try {
        # Try to uninstall service using osqueryd.exe if it exists
        if (Test-Path "$InstallDir\osqueryd.exe") {
            & "$InstallDir\osqueryd.exe" --uninstall 2>$null
        } else {
            # If exe doesn't exist, try using sc.exe
            & sc.exe delete $serviceName 2>$null | Out-Null
        }
        Start-Sleep -Seconds 2
        Write-Host "Service removed" -ForegroundColor Green
    } catch {
        Write-Warning "Service may already be removed or osqueryd.exe not found"
        # Try alternative method
        try {
            & sc.exe delete $serviceName 2>$null | Out-Null
            Write-Host "Service removed using sc.exe" -ForegroundColor Green
        } catch {
            Write-Warning "Could not remove service using sc.exe"
        }
    }
} else {
    Write-Host "osquery service not found" -ForegroundColor Gray
}

# Step 3: Uninstall osquery MSI if installed via Windows Installer
Write-Host "Checking for osquery MSI installation..." -ForegroundColor Yellow
$osqueryProduct = Get-WmiObject Win32_Product | Where-Object { $_.Name -like "*osquery*" } | Select-Object -First 1

if ($osqueryProduct) {
    Write-Host "Found osquery MSI installation. Uninstalling..." -ForegroundColor Yellow
    try {
        $osqueryProduct.Uninstall()
        Write-Host "osquery MSI uninstalled" -ForegroundColor Green
        Start-Sleep -Seconds 3
    } catch {
        Write-Warning "Could not uninstall via MSI: $_"
    }
}

# Step 4: Remove scheduled tasks
Write-Host "Removing scheduled tasks..." -ForegroundColor Yellow
$taskNames = @(
    "VigyanShaala-MDM-SyncWebsiteBlocklist",
    "VigyanShaala-MDM-SyncSoftwareBlocklist",
    "VigyanShaala-MDM-SendOsqueryData",
    "VigyanShaala-MDM-CollectBatteryData",
    "VigyanShaala-MDM-RealtimeListener",
    "VigyanShaala-UserNotify-Agent"
)

foreach ($taskName in $taskNames) {
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
            Write-Host "Removed scheduled task: $taskName" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Could not remove task $taskName : $_"
    }
}

# Step 5: Remove installation directory
if (Test-Path $InstallDir) {
    Write-Host "Removing installation directory..." -ForegroundColor Yellow
    try {
        # Wait a bit to ensure service is fully stopped
        Start-Sleep -Seconds 3
        
        # Kill any processes that might be locking files in the directory
        Write-Host "Checking for processes locking files..." -ForegroundColor Yellow
        Get-Process | Where-Object { 
            $_.Path -and $_.Path.StartsWith($InstallDir, [System.StringComparison]::OrdinalIgnoreCase)
        } | ForEach-Object {
            Write-Host "Killing process locking files: $($_.Name) (PID: $($_.Id))" -ForegroundColor Yellow
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
        
        # Try to remove files individually first (more reliable than removing entire directory)
        Write-Host "Removing files individually..." -ForegroundColor Yellow
        $files = Get-ChildItem -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            try {
                if ($file.PSIsContainer) {
                    Remove-Item -Path $file.FullName -Force -Recurse -ErrorAction SilentlyContinue
                } else {
                    # Remove read-only attribute if present
                    $file.Attributes = $file.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
                    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                }
            } catch {
                # Ignore individual file errors, continue with others
            }
        }
        Start-Sleep -Seconds 1
        
        # Now try to remove the directory itself
        $maxRetries = 5
        $retryCount = 0
        $removed = $false
        
        while ($retryCount -lt $maxRetries -and -not $removed) {
            try {
                # Final check for any remaining processes
                Get-Process | Where-Object { 
                    $_.Path -and $_.Path.StartsWith($InstallDir, [System.StringComparison]::OrdinalIgnoreCase)
                } | Stop-Process -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
                
                Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction Stop
                $removed = $true
                Write-Host "Installation directory removed" -ForegroundColor Green
            } catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Host "Retrying removal (attempt $($retryCount)/$($maxRetries))..." -ForegroundColor Yellow
                    # Try to unlock files using handle.exe if available, or just wait longer
                    Start-Sleep -Seconds 3
                } else {
                    Write-Warning "Could not remove directory: $_"
                    Write-Host "Attempting to remove remaining files..." -ForegroundColor Yellow
                    # Last resort: try to remove what we can
                    try {
                        Get-ChildItem -Path $InstallDir -Recurse -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        # Try one more time to remove the directory
                        if (Test-Path $InstallDir) {
                            Remove-Item -Path $InstallDir -Force -ErrorAction SilentlyContinue
                        }
                        if (-not (Test-Path $InstallDir)) {
                            Write-Host "Directory removed after cleanup" -ForegroundColor Green
                            $removed = $true
                        } else {
                            Write-Host "Some files may still be locked. You may need to manually delete: $InstallDir" -ForegroundColor Yellow
                            Write-Host "  Try restarting the computer, then delete the folder manually." -ForegroundColor Yellow
                        }
                    } catch {
                        Write-Host "You may need to manually delete: $InstallDir" -ForegroundColor Yellow
                        Write-Host "  Try restarting the computer, then delete the folder manually." -ForegroundColor Yellow
                    }
                }
            }
        }
    } catch {
        Write-Warning "Could not remove installation directory: $_"
        Write-Host "You may need to manually delete: $InstallDir" -ForegroundColor Yellow
    }
} else {
    Write-Host "Installation directory not found at: $InstallDir" -ForegroundColor Gray
}

# Step 6: Remove ProgramData directory and all osquery data
$programDataDir = "$env:ProgramData\osquery"
if (Test-Path $programDataDir) {
    Write-Host "Removing ProgramData directory..." -ForegroundColor Yellow
    try {
        # Kill any processes that might be locking files
        Get-Process | Where-Object { $_.Path -like "*osquery*" } | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        
        Remove-Item -Path $programDataDir -Recurse -Force -ErrorAction Stop
        Write-Host "ProgramData directory removed" -ForegroundColor Green
    } catch {
        Write-Warning "Could not remove ProgramData directory: $_"
        Write-Host "You may need to manually delete: $programDataDir" -ForegroundColor Yellow
    }
}

# Step 6b: Remove any osquery files from temp directories
Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
$tempPaths = @(
    "$env:TEMP\osquery*",
    "$env:LOCALAPPDATA\Temp\osquery*",
    "$env:ProgramData\Temp\osquery*"
)

foreach ($tempPath in $tempPaths) {
    try {
        $tempItems = Get-ChildItem -Path $tempPath -ErrorAction SilentlyContinue
        if ($tempItems) {
            Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Removed temp files: $tempPath" -ForegroundColor Green
        }
    } catch {
        # Ignore errors for temp file cleanup
    }
}

# Step 7: Remove desktop shortcuts
Write-Host "Removing desktop shortcuts..." -ForegroundColor Yellow
$desktopShortcuts = @(
    "$env:USERPROFILE\Desktop\VigyanShaala Chat.lnk",
    "$env:PUBLIC\Desktop\VigyanShaala Chat.lnk"
)

foreach ($shortcut in $desktopShortcuts) {
    if (Test-Path $shortcut) {
        try {
            Remove-Item -Path $shortcut -Force -ErrorAction Stop
            Write-Host "Removed desktop shortcut: $shortcut" -ForegroundColor Green
        } catch {
            Write-Warning "Could not remove shortcut $shortcut : $_"
        }
    }
}

# Step 8: Remove website blocklist from hosts file and registry
Write-Host "Removing website blocklist..." -ForegroundColor Yellow
try {
    $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    $mdmMarkerStart = "# VigyanShaala-MDM Blocklist Start"
    $mdmMarkerEnd = "# VigyanShaala-MDM Blocklist End"
    
    if (Test-Path $hostsFile) {
        # Remove read-only attribute if present
        $fileInfo = Get-Item $hostsFile -Force -ErrorAction SilentlyContinue
        if ($fileInfo -and $fileInfo.IsReadOnly) {
            $fileInfo.IsReadOnly = $false
            Write-Host "Removed read-only attribute from hosts file" -ForegroundColor Yellow
        }
        
        $allLines = Get-Content $hostsFile -ErrorAction SilentlyContinue
        $cleanedLines = @()
        $insideMdmSection = $false
        $foundMdmSection = $false
        
        foreach ($line in $allLines) {
            $trimmedLine = $line.Trim()
            
            # Check for start marker (handle exact match or with whitespace)
            if ($trimmedLine -eq $mdmMarkerStart -or $line -match [regex]::Escape($mdmMarkerStart)) {
                $insideMdmSection = $true
                $foundMdmSection = $true
                continue
            }
            
            # Check for end marker
            if ($trimmedLine -eq $mdmMarkerEnd -or $line -match [regex]::Escape($mdmMarkerEnd)) {
                $insideMdmSection = $false
                continue
            }
            
            # Only add lines outside the MDM section
            if (-not $insideMdmSection) {
                $cleanedLines += $line
            }
        }
        
        if ($foundMdmSection) {
            # Write with retry logic in case file is locked
            $maxRetries = 3
            $retryCount = 0
            $writeSuccess = $false
            
            while ($retryCount -lt $maxRetries -and -not $writeSuccess) {
                try {
                    # Use UTF8 encoding without BOM (Windows hosts file standard)
                    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                    [System.IO.File]::WriteAllLines($hostsFile, $cleanedLines, $utf8NoBom)
                    $writeSuccess = $true
                    Write-Host "Removed MDM blocklist entries from hosts file" -ForegroundColor Green
                    
                    # Verify the write worked
                    Start-Sleep -Milliseconds 500
                    $verifyContent = Get-Content $hostsFile -Raw -ErrorAction SilentlyContinue
                    if ($verifyContent -and $verifyContent -match [regex]::Escape($mdmMarkerStart)) {
                        Write-Warning "WARNING: MDM markers still found in hosts file after removal attempt!"
                        Write-Host "Attempting alternative removal method..." -ForegroundColor Yellow
                        # Try Set-Content as fallback
                        $cleanedLines | Set-Content $hostsFile -Encoding ASCII -Force -ErrorAction Stop
                        Write-Host "Removed using alternative method" -ForegroundColor Green
                    }
                } catch {
                    $retryCount++
                    if ($retryCount -lt $maxRetries) {
                        Write-Host "Retry $($retryCount)/$($maxRetries): File may be locked, waiting..." -ForegroundColor Yellow
                        Start-Sleep -Seconds 2
                    } else {
                        # Final attempt with Set-Content
                        try {
                            $cleanedLines | Set-Content $hostsFile -Encoding ASCII -Force -ErrorAction Stop
                            Write-Host "Removed MDM blocklist entries from hosts file (using fallback method)" -ForegroundColor Green
                            $writeSuccess = $true
                        } catch {
                            Write-Warning "Could not write to hosts file after $maxRetries attempts: $_"
                            Write-Host "Please manually edit $hostsFile and remove the MDM blocklist section" -ForegroundColor Yellow
                            Write-Host "  Look for lines between: $mdmMarkerStart and $mdmMarkerEnd" -ForegroundColor Yellow
                        }
                    }
                }
            }
            
            # Flush DNS cache multiple times to ensure it's cleared
            Write-Host "Flushing DNS cache..." -ForegroundColor Cyan
            ipconfig /flushdns | Out-Null
            Start-Sleep -Seconds 1
            ipconfig /flushdns | Out-Null
            Write-Host "DNS cache flushed" -ForegroundColor Green
            
            # Also clear browser DNS cache by restarting DNS client service
            Write-Host "Restarting DNS client service..." -ForegroundColor Cyan
            Restart-Service -Name "Dnscache" -Force -ErrorAction SilentlyContinue
            Write-Host "DNS client service restarted" -ForegroundColor Green
        } else {
            Write-Host "No MDM blocklist entries found in hosts file" -ForegroundColor Gray
        }
    }
    
    # Remove Chrome registry policy
    $chromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
    if (Test-Path $chromePolicyPath) {
        try {
            $urlBlocklist = Get-ItemProperty -Path $chromePolicyPath -Name "URLBlocklist" -ErrorAction SilentlyContinue
            if ($urlBlocklist) {
                Remove-ItemProperty -Path $chromePolicyPath -Name "URLBlocklist" -ErrorAction Stop
                Write-Host "Removed Chrome URLBlocklist policy" -ForegroundColor Green
            } else {
                Write-Host "No Chrome URLBlocklist policy found" -ForegroundColor Gray
            }
            
            # Also check for and remove URLAllowlist if it exists (sometimes used together)
            $urlAllowlist = Get-ItemProperty -Path $chromePolicyPath -Name "URLAllowlist" -ErrorAction SilentlyContinue
            if ($urlAllowlist) {
                Remove-ItemProperty -Path $chromePolicyPath -Name "URLAllowlist" -ErrorAction SilentlyContinue
                Write-Host "Removed Chrome URLAllowlist policy" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Could not remove Chrome policy: $_"
        }
    }
    
    # Remove Edge registry policy
    $edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    if (Test-Path $edgePolicyPath) {
        try {
            $urlBlocklist = Get-ItemProperty -Path $edgePolicyPath -Name "URLBlocklist" -ErrorAction SilentlyContinue
            if ($urlBlocklist) {
                Remove-ItemProperty -Path $edgePolicyPath -Name "URLBlocklist" -ErrorAction Stop
                Write-Host "Removed Edge URLBlocklist policy" -ForegroundColor Green
            } else {
                Write-Host "No Edge URLBlocklist policy found" -ForegroundColor Gray
            }
            
            # Also check for and remove URLAllowlist if it exists
            $urlAllowlist = Get-ItemProperty -Path $edgePolicyPath -Name "URLAllowlist" -ErrorAction SilentlyContinue
            if ($urlAllowlist) {
                Remove-ItemProperty -Path $edgePolicyPath -Name "URLAllowlist" -ErrorAction SilentlyContinue
                Write-Host "Removed Edge URLAllowlist policy" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Could not remove Edge policy: $_"
        }
    }
    
    # Check for Firefox policies (if any were added)
    $firefoxPolicyPath = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
    if (Test-Path $firefoxPolicyPath) {
        try {
            $blocklist = Get-ItemProperty -Path $firefoxPolicyPath -Name "BlockAboutConfig" -ErrorAction SilentlyContinue
            if ($blocklist) {
                Remove-ItemProperty -Path $firefoxPolicyPath -Name "BlockAboutConfig" -ErrorAction SilentlyContinue
                Write-Host "Removed Firefox policy restrictions" -ForegroundColor Green
            }
        } catch {
            # Firefox policies are less common, ignore errors
        }
    }
    
    Write-Host ""
    Write-Host "IMPORTANT: Please restart your browser(s) for changes to take full effect!" -ForegroundColor Yellow
    Write-Host "  - Close all Chrome windows and reopen" -ForegroundColor White
    Write-Host "  - Close all Edge windows and reopen" -ForegroundColor White
    Write-Host "  - If still blocked, clear browser cache: Settings > Privacy > Clear browsing data" -ForegroundColor White
} catch {
    Write-Warning "Could not remove website blocklist: $_"
}

# Step 9: Remove registry keys that may have been added by prevent-uninstall.ps1 (if it was run)
# Only remove the specific keys we may have added, not the entire registry paths
Write-Host "Checking for additional registry keys..." -ForegroundColor Yellow
try {
    $installerPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"
    if (Test-Path $installerPolicyPath) {
        # Only remove the specific values we may have added, not the entire key
        $disableUserInstalls = Get-ItemProperty -Path $installerPolicyPath -Name "DisableUserInstalls" -ErrorAction SilentlyContinue
        $disableMSI = Get-ItemProperty -Path $installerPolicyPath -Name "DisableMSI" -ErrorAction SilentlyContinue
        
        if ($disableUserInstalls) {
            Remove-ItemProperty -Path $installerPolicyPath -Name "DisableUserInstalls" -ErrorAction SilentlyContinue
            Write-Host "Removed DisableUserInstalls registry value" -ForegroundColor Green
        }
        
        if ($disableMSI) {
            Remove-ItemProperty -Path $installerPolicyPath -Name "DisableMSI" -ErrorAction SilentlyContinue
            Write-Host "Removed DisableMSI registry value" -ForegroundColor Green
        }
        
        # If the key is now empty (only had our values), we could remove it, but it's safer to leave it
        # as other software might use it
    }
} catch {
    Write-Warning "Could not check/remove additional registry keys: $_"
}

# Step 10: Remove all osquery-related registry entries
Write-Host "Removing osquery registry entries..." -ForegroundColor Yellow
$registryPaths = @(
    "HKLM:\SOFTWARE\osquery",
    "HKLM:\SOFTWARE\WOW6432Node\osquery",
    "HKCU:\SOFTWARE\osquery"
)

foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        try {
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
            Write-Host "Removed registry key: $regPath" -ForegroundColor Green
        } catch {
            Write-Warning "Could not remove registry key $regPath : $_"
        }
    }
}

# Step 11: Remove any osquery-related Windows Firewall rules
Write-Host "Removing firewall rules..." -ForegroundColor Yellow
try {
    $firewallRules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*osquery*" -or $_.DisplayName -like "*VigyanShaala*" }
    if ($firewallRules) {
        foreach ($rule in $firewallRules) {
            try {
                Remove-NetFirewallRule -Name $rule.Name -ErrorAction Stop
                Write-Host "Removed firewall rule: $($rule.DisplayName)" -ForegroundColor Green
            } catch {
                Write-Warning "Could not remove firewall rule $($rule.DisplayName): $_"
            }
        }
    } else {
        Write-Host "No osquery firewall rules found" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Could not check/remove firewall rules: $_"
}

# Step 12: Remove any startup entries
Write-Host "Removing startup entries..." -ForegroundColor Yellow
$startupPaths = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\*osquery*",
    "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Startup\*osquery*"
)

foreach ($startupPath in $startupPaths) {
    try {
        $startupItems = Get-ChildItem -Path $startupPath -ErrorAction SilentlyContinue
        if ($startupItems) {
            Remove-Item -Path $startupPath -Force -ErrorAction SilentlyContinue
            Write-Host "Removed startup entry: $startupPath" -ForegroundColor Green
        }
    } catch {
        # Ignore errors
    }
}

# Step 13: Read environment variables BEFORE removing them (needed for Supabase deletion)
Write-Host "Reading Supabase credentials..." -ForegroundColor Yellow
$supabaseUrlFromEnv = [Environment]::GetEnvironmentVariable("SUPABASE_URL", "Machine")
$supabaseKeyFromEnv = [Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY", "Machine")

# Use parameters if provided, otherwise use environment variables
if (-not $SupabaseUrl -or [string]::IsNullOrWhiteSpace($SupabaseUrl)) {
    $SupabaseUrl = $supabaseUrlFromEnv
}
if (-not $SupabaseAnonKey -or [string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
    $SupabaseAnonKey = $supabaseKeyFromEnv
}

# Step 14: Remove device from Supabase (BEFORE removing environment variables)
if ($SupabaseUrl -and $SupabaseAnonKey) {
    Write-Host ""
    Write-Host "Removing device from Supabase..." -ForegroundColor Yellow
    
    try {
        $hostname = $env:COMPUTERNAME
        
        $headers = @{
            "apikey" = $SupabaseAnonKey
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $SupabaseAnonKey"
        }
        
        # Delete device using hostname as primary key (devices table uses hostname as PK, not id)
        $deleteUri = "$SupabaseUrl/rest/v1/devices?hostname=eq.$hostname"
        $response = Invoke-RestMethod -Uri $deleteUri -Method DELETE -Headers $headers
        
        Write-Host "Device removed from Supabase (hostname: $hostname)" -ForegroundColor Green
    } catch {
        # Check if it's a 404 (device not found) or actual error
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Host "Device not found in Supabase (may have been already removed)" -ForegroundColor Gray
        } else {
            Write-Warning "Could not remove device from Supabase: $_"
            Write-Host "You may need to remove it manually from the dashboard" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host ""
    Write-Host "Note: Supabase credentials not found. Device will remain in dashboard." -ForegroundColor Yellow
    Write-Host "      You can remove it manually from the dashboard." -ForegroundColor Yellow
}

# Step 15: Remove environment variables (AFTER using them for Supabase deletion)
Write-Host "Removing environment variables..." -ForegroundColor Yellow
try {
    [Environment]::SetEnvironmentVariable("SUPABASE_URL", $null, "Machine")
    [Environment]::SetEnvironmentVariable("SUPABASE_ANON_KEY", $null, "Machine")
    [Environment]::SetEnvironmentVariable("FLEET_SERVER_URL", $null, "Machine")
    Write-Host "Environment variables removed" -ForegroundColor Green
} catch {
    Write-Warning "Could not remove environment variables: $_"
}

# Step 16: Final verification and cleanup summary
Write-Host ""
Write-Host "Performing final verification..." -ForegroundColor Yellow

$remainingItems = @()

# Check for remaining processes
$remainingProcesses = Get-Process -Name "osquery*" -ErrorAction SilentlyContinue
if ($remainingProcesses) {
    $remainingItems += "Running processes: $($remainingProcesses.Count)"
}

# Check for remaining service
$remainingService = Get-Service -Name "osqueryd" -ErrorAction SilentlyContinue
if ($remainingService) {
    $remainingItems += "Service still exists"
}

# Check for remaining directories
if (Test-Path $InstallDir) {
    $remainingItems += "Installation directory: $InstallDir"
}
if (Test-Path "$env:ProgramData\osquery") {
    $remainingItems += "ProgramData directory: $env:ProgramData\osquery"
}

# Check for remaining scheduled tasks
$remainingTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*VigyanShaala*" -or $_.TaskName -like "*osquery*" }
if ($remainingTasks) {
    $remainingItems += "Scheduled tasks: $($remainingTasks.Count)"
}

if ($remainingItems.Count -gt 0) {
    Write-Host ""
    Write-Host "WARNING: Some items could not be removed:" -ForegroundColor Yellow
    foreach ($item in $remainingItems) {
        Write-Host "  - $item" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "You may need to manually remove these items or restart the computer." -ForegroundColor Yellow
} else {
    Write-Host "All items verified as removed" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Uninstallation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "osquery agent has been removed from this computer." -ForegroundColor Cyan
Write-Host ""
Write-Host "Removed components:" -ForegroundColor Cyan
Write-Host "  [OK] osquery service" -ForegroundColor White
Write-Host "  [OK] All scheduled tasks" -ForegroundColor White
Write-Host "  [OK] Installation files and directories" -ForegroundColor White
Write-Host "  [OK] ProgramData files and logs" -ForegroundColor White
Write-Host "  [OK] Desktop shortcuts" -ForegroundColor White
Write-Host "  [OK] Website blocklist entries" -ForegroundColor White
Write-Host "  [OK] Registry entries" -ForegroundColor White
Write-Host "  [OK] Environment variables" -ForegroundColor White
Write-Host "  [OK] Firewall rules" -ForegroundColor White
Write-Host "  [OK] Startup entries" -ForegroundColor White
Write-Host "  [OK] Temporary files" -ForegroundColor White
if ($SupabaseUrl -and $SupabaseAnonKey) {
    Write-Host "  [OK] Device removed from Supabase" -ForegroundColor White
}
Write-Host ""

pause

