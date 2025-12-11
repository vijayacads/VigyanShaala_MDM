# Silent Installation Script for osquery Agent
# This can be used for manual installation or included in MSI package
# Run with: .\install-osquery.ps1 -SupabaseUrl "https://xxx.supabase.co" -SupabaseKey "xxx" -FleetUrl "https://fleet.example.com"

param(
    [Parameter(Mandatory=$false)]
    [string]$OsqueryMsi = "osquery-5.11.0.msi",
    
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

# Step 5: Install osquery service (if not already installed)
$serviceName = "osqueryd"
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if (-not $service) {
    Write-Host "Installing osquery service..." -ForegroundColor Yellow
    & "$InstallDir\osqueryd.exe" --install
    Start-Sleep -Seconds 2
}

# Step 6: Start osquery service
try {
    Start-Service -Name $serviceName -ErrorAction Stop
    Write-Host "osquery service started" -ForegroundColor Green
} catch {
    Write-Warning "Could not start osquery service: $_"
}

# Step 7: Run enrollment wizard (if environment variables are set)
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

# Step 8: Apply initial blocklists and create sync tasks
if ($SupabaseUrl -and $SupabaseKey) {
    Write-Host "`nApplying blocklists..." -ForegroundColor Cyan
    
    # ============================================
    # Website Blocklist
    # ============================================
    Write-Host "Applying website blocklist..." -ForegroundColor Cyan
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
    
    # Create scheduled task to sync website blocklist every 30 minutes
    Write-Host "Creating scheduled task for website blocklist sync..." -ForegroundColor Cyan
    $websiteSyncScript = "$InstallDir\sync-blocklist-scheduled.ps1"
    if (Test-Path "sync-blocklist-scheduled.ps1") {
        Copy-Item "sync-blocklist-scheduled.ps1" $websiteSyncScript -Force
    }
    
    $websiteTaskName = "VigyanShaala-MDM-SyncWebsiteBlocklist"
    $websiteTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -File `"$websiteSyncScript`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseAnonKey `"$SupabaseKey`""
    $websiteTaskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 365)
    $websiteTaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    try {
        Unregister-ScheduledTask -TaskName $websiteTaskName -ErrorAction SilentlyContinue
        Register-ScheduledTask -TaskName $websiteTaskName -Action $websiteTaskAction -Trigger $websiteTaskTrigger -Principal $websiteTaskPrincipal -Description "Sync website blocklist from MDM server" -Force | Out-Null
        Write-Host "Website blocklist sync task created (runs every 30 minutes)" -ForegroundColor Green
    } catch {
        Write-Warning "Could not create website blocklist sync task: $_"
    }
    
    # ============================================
    # Software Blocklist
    # ============================================
    Write-Host "`nApplying software blocklist..." -ForegroundColor Cyan
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
    
    # Create scheduled task to sync software blocklist every hour
    Write-Host "Creating scheduled task for software blocklist sync..." -ForegroundColor Cyan
    $softwareSyncScript = "$InstallDir\sync-software-blocklist-scheduled.ps1"
    if (Test-Path "sync-software-blocklist-scheduled.ps1") {
        Copy-Item "sync-software-blocklist-scheduled.ps1" $softwareSyncScript -Force
    }
    
    $softwareTaskName = "VigyanShaala-MDM-SyncSoftwareBlocklist"
    $softwareTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -File `"$softwareSyncScript`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseAnonKey `"$SupabaseKey`""
    $softwareTaskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 365)
    $softwareTaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    try {
        Unregister-ScheduledTask -TaskName $softwareTaskName -ErrorAction SilentlyContinue
        Register-ScheduledTask -TaskName $softwareTaskName -Action $softwareTaskAction -Trigger $softwareTaskTrigger -Principal $softwareTaskPrincipal -Description "Check and remove blocked software from MDM server" -Force | Out-Null
        Write-Host "Software blocklist sync task created (runs every hour)" -ForegroundColor Green
    } catch {
        Write-Warning "Could not create software blocklist sync task: $_"
    }
    
    # ============================================
    # Data Sending Task (sends osquery data to Supabase)
    # ============================================
    $sendDataScript = "$InstallDir\send-osquery-data.ps1"
    if (Test-Path "send-osquery-data.ps1") {
        Write-Host "`nCreating scheduled task to send osquery data..." -ForegroundColor Cyan
        Copy-Item "send-osquery-data.ps1" $sendDataScript -Force
        
        $dataTaskName = "VigyanShaala-MDM-SendOsqueryData"
        $dataTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-ExecutionPolicy Bypass -File `"$sendDataScript`" -SupabaseUrl `"$SupabaseUrl`" -SupabaseAnonKey `"$SupabaseKey`""
        $dataTaskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 365)
        $dataTaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        try {
            Unregister-ScheduledTask -TaskName $dataTaskName -ErrorAction SilentlyContinue
            Register-ScheduledTask -TaskName $dataTaskName -Action $dataTaskAction -Trigger $dataTaskTrigger -Principal $dataTaskPrincipal -Description "Send osquery data to MDM server every 5 minutes" -Force | Out-Null
            Write-Host "Data sending task created (runs every 5 minutes)" -ForegroundColor Green
        } catch {
            Write-Warning "Could not create data sending task: $_"
        }
    }
}

Write-Host "`nInstallation complete!" -ForegroundColor Green
Write-Host "`nInstalled components:" -ForegroundColor Cyan
Write-Host "- osquery agent: $InstallDir" -ForegroundColor White
Write-Host "- Service: $serviceName" -ForegroundColor White
Write-Host "- Configuration: $configDir" -ForegroundColor White
