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
        $allLines = Get-Content $hostsFile -ErrorAction SilentlyContinue
        $cleanedLines = @()
        $insideMdmSection = $false
        $foundMdmSection = $false
        
        foreach ($line in $allLines) {
            if ($line -eq $mdmMarkerStart) {
                $insideMdmSection = $true
                $foundMdmSection = $true
                continue
            }
            if ($line -eq $mdmMarkerEnd) {
                $insideMdmSection = $false
                continue
            }
            if (-not $insideMdmSection) {
                $cleanedLines += $line
            }
        }
        
        if ($foundMdmSection) {
            $cleanedLines | Set-Content $hostsFile -Encoding ASCII -Force
            Write-Host "Removed MDM blocklist entries from hosts file" -ForegroundColor Green
            
            # Flush DNS cache
            Write-Host "Flushing DNS cache..." -ForegroundColor Cyan
            ipconfig /flushdns | Out-Null
            Write-Host "DNS cache flushed" -ForegroundColor Green
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
        } catch {
            Write-Warning "Could not remove Edge policy: $_"
        }
    }
} catch {
    Write-Warning "Could not remove website blocklist: $_"
}

# Step 7: Remove environment variables (optional - commented out to preserve for reinstall)
# Uncomment if you want to remove environment variables
<#
Write-Host "Removing environment variables..." -ForegroundColor Yellow
try {
    [Environment]::SetEnvironmentVariable("SUPABASE_URL", $null, "Machine")
    [Environment]::SetEnvironmentVariable("SUPABASE_ANON_KEY", $null, "Machine")
    [Environment]::SetEnvironmentVariable("FLEET_SERVER_URL", $null, "Machine")
    Write-Host "Environment variables removed" -ForegroundColor Green
} catch {
    Write-Warning "Could not remove environment variables: $_"
}
#>

# Step 8: Remove device from Supabase (if credentials available)
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
        
        # First, find the device
        $response = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/devices?hostname=eq.$hostname&select=id" `
            -Method GET -Headers $headers
        
        if ($response -and $response.Count -gt 0) {
            $deviceId = $response[0].id
            # Delete device
            Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/devices?id=eq.$deviceId" `
                -Method DELETE -Headers $headers | Out-Null
            Write-Host "Device removed from Supabase (ID: $deviceId)" -ForegroundColor Green
        } else {
            Write-Host "Device not found in Supabase" -ForegroundColor Gray
        }
    } catch {
        Write-Warning "Could not remove device from Supabase: $_"
        Write-Host "You may need to remove it manually from the dashboard" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "Note: Supabase credentials not found. Device will remain in dashboard." -ForegroundColor Yellow
    Write-Host "      You can remove it manually from the dashboard." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Uninstallation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "osquery agent has been removed from this computer." -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: Environment variables were kept (in case you want to reinstall)." -ForegroundColor Gray
Write-Host "      To remove them, edit this script and uncomment the environment variable removal section." -ForegroundColor Gray
Write-Host ""

pause

