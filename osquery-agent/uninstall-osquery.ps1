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

# Step 1: Stop and remove osquery service
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
        & "$InstallDir\osqueryd.exe" --uninstall 2>$null
        Start-Sleep -Seconds 2
        Write-Host "Service removed" -ForegroundColor Green
    } catch {
        Write-Warning "Service may already be removed or osqueryd.exe not found"
    }
} else {
    Write-Host "osquery service not found" -ForegroundColor Gray
}

# Step 2: Uninstall osquery MSI if installed via Windows Installer
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

# Step 3: Remove scheduled tasks
Write-Host "Removing scheduled tasks..." -ForegroundColor Yellow
$taskNames = @(
    "VigyanShaala-MDM-SyncWebsiteBlocklist",
    "VigyanShaala-MDM-SyncSoftwareBlocklist",
    "VigyanShaala-MDM-SendOsqueryData",
    "VigyanShaala-MDM-CommandProcessor"
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

# Step 4: Remove installation directory
if (Test-Path $InstallDir) {
    Write-Host "Removing installation directory..." -ForegroundColor Yellow
    try {
        # Wait a bit to ensure service is fully stopped
        Start-Sleep -Seconds 2
        
        # Remove directory with retry
        $maxRetries = 5
        $retryCount = 0
        $removed = $false
        
        while ($retryCount -lt $maxRetries -and -not $removed) {
            try {
                Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction Stop
                $removed = $true
                Write-Host "Installation directory removed" -ForegroundColor Green
            } catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Host "Retrying removal (attempt $retryCount/$maxRetries)..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                } else {
                    Write-Warning "Could not remove directory: $_"
                    Write-Host "You may need to manually delete: $InstallDir" -ForegroundColor Yellow
                }
            }
        }
    } catch {
        Write-Warning "Could not remove installation directory: $_"
    }
} else {
    Write-Host "Installation directory not found at: $InstallDir" -ForegroundColor Gray
}

# Step 4: Remove ProgramData directory
$programDataDir = "$env:ProgramData\osquery"
if (Test-Path $programDataDir) {
    Write-Host "Removing ProgramData directory..." -ForegroundColor Yellow
    try {
        Remove-Item -Path $programDataDir -Recurse -Force -ErrorAction Stop
        Write-Host "ProgramData directory removed" -ForegroundColor Green
    } catch {
        Write-Warning "Could not remove ProgramData directory: $_"
        Write-Host "You may need to manually delete: $programDataDir" -ForegroundColor Yellow
    }
}

# Step 5: Remove desktop shortcuts
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

# Step 6: Remove website blocklist from hosts file and registry
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
                        Write-Host "Retry $retryCount/$maxRetries: File may be locked, waiting..." -ForegroundColor Yellow
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

# Step 6b: Remove registry keys that may have been added by prevent-uninstall.ps1 (if it was run)
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

# Step 7: Read environment variables BEFORE removing them (needed for Supabase deletion)
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

# Step 8: Remove device from Supabase (BEFORE removing environment variables)
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

# Step 9: Remove environment variables (AFTER using them for Supabase deletion)
Write-Host "Removing environment variables..." -ForegroundColor Yellow
try {
    [Environment]::SetEnvironmentVariable("SUPABASE_URL", $null, "Machine")
    [Environment]::SetEnvironmentVariable("SUPABASE_ANON_KEY", $null, "Machine")
    [Environment]::SetEnvironmentVariable("FLEET_SERVER_URL", $null, "Machine")
    Write-Host "Environment variables removed" -ForegroundColor Green
} catch {
    Write-Warning "Could not remove environment variables: $_"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Uninstallation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "osquery agent has been removed from this computer." -ForegroundColor Cyan
Write-Host ""

pause

