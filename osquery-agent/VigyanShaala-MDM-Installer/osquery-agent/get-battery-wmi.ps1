# get-battery-wmi.ps1
# Gets battery data using WMI and writes to osquery results log in the same format

$ErrorActionPreference = "Stop"

# Osquery log path (same format as osquery writes)
$logPath = "C:\ProgramData\osquery\logs\osqueryd.results.log"

# Ensure log directory exists
$logDir = Split-Path -Parent $logPath
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Get battery data using WMI
try {
    $battery = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($battery -and $battery.EstimatedChargeRemaining -ne $null) {
        # Map WMI battery status codes to health status
        $healthStatus = switch ($battery.BatteryStatus) {
            1 { "Other" }
            2 { "Unknown" }
            3 { "Fully Charged" }
            4 { "Low" }
            5 { "Critical" }
            6 { "Charging" }
            7 { "Charging and High" }
            8 { "Charging and Low" }
            9 { "Charging and Critical" }
            10 { "Undefined" }
            11 { "Partially Charged" }
            default { "Unknown" }
        }
        
        # Determine charging state
        $isCharging = $false
        if ($battery.BatteryStatus -in @(6, 7, 8, 9)) {
            $isCharging = $true
        }
        
        # Determine state
        $state = switch ($battery.BatteryStatus) {
            3 { "Fully Charged" }
            6 { "Charging" }
            7 { "Charging" }
            8 { "Charging" }
            9 { "Charging" }
            11 { "Partially Charged" }
            default { "Discharging" }
        }
        
        $batteryData = @{
            percentage = $battery.EstimatedChargeRemaining
            health = $healthStatus
            state = $state
            charging = if ($isCharging) { "1" } else { "0" }
        }
        
        # Create log entry in osquery format
        $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $hostname = $env:COMPUTERNAME
        $calTime = (Get-Date).ToUniversalTime().ToString('ddd MMM dd HH:mm:ss yyyy UTC')
        
        $entry = @{
            name = 'battery_health'
            hostIdentifier = $hostname
            calendarTime = $calTime
            unixTime = $timestamp
            epoch = 0
            counter = 0
            numerics = $false
            decorations = @{
                hostname = $hostname
            }
            columns = $batteryData
            action = 'added'
        } | ConvertTo-Json -Depth 10 -Compress
        
        # Write to log file
        Add-Content -Path $logPath -Value $entry -Force -ErrorAction SilentlyContinue
        
        Write-Host "Battery data written: $($batteryData.percentage)% ($($batteryData.state))" -ForegroundColor Green
    } else {
        Write-Host "No battery detected (desktop or battery not available)" -ForegroundColor Gray
    }
} catch {
    Write-Host "Error getting battery data: $_" -ForegroundColor Red
    exit 1
}




