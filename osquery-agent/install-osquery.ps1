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
    if (Test-Path $enrollScript) {
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$enrollScript`"" -Wait
    } else {
        Write-Warning "Enrollment script not found at $enrollScript"
    }
} else {
    Write-Host "`nEnrollment wizard skipped (missing environment variables)" -ForegroundColor Yellow
    Write-Host "Run enroll-fleet.ps1 manually after setting environment variables" -ForegroundColor Yellow
}

Write-Host "`nInstallation complete!" -ForegroundColor Green
Write-Host "`nInstalled components:" -ForegroundColor Cyan
Write-Host "- osquery agent: $InstallDir" -ForegroundColor White
Write-Host "- Service: $serviceName" -ForegroundColor White
Write-Host "- Configuration: $configDir" -ForegroundColor White

