# trigger-osquery-queries.ps1
# Manually triggers osquery scheduled queries to run immediately
# This forces osquery to execute queries and write results to the log file

$osqueryiPath = "C:\Program Files\osquery\osqueryi.exe"
$logPath = "C:\ProgramData\osquery\logs\osqueryd.results.log"

Write-Host "Triggering osquery queries immediately..." -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $osqueryiPath)) {
    Write-Host "ERROR: osqueryi.exe not found at: $osqueryiPath" -ForegroundColor Red
    exit 1
}

# Helper function to extract JSON array from osquery output
function Get-JsonFromOsqueryOutput {
    param([string[]]$Output)
    $jsonLines = @()
    $inJson = $false
    $braceCount = 0
    foreach ($line in $Output) {
        if ($line -match '^\[') {
            $inJson = $true
            $braceCount = ($line.ToCharArray() | Where-Object { $_ -eq '[' }).Count - ($line.ToCharArray() | Where-Object { $_ -eq ']' }).Count
        }
        if ($inJson) {
            $jsonLines += $line
            $braceCount += ($line.ToCharArray() | Where-Object { $_ -eq '[' }).Count - ($line.ToCharArray() | Where-Object { $_ -eq ']' }).Count
            if ($braceCount -le 0) {
                break
            }
        }
    }
    if ($jsonLines.Count -gt 0) {
        return ($jsonLines -join "`n")
    }
    return $null
}

# Run queries directly using osqueryi and append to results log
Write-Host "Running device_health query..." -ForegroundColor Yellow
$deviceHealthQuery = "SELECT size as total_storage, (size - free_space) as used_storage FROM logical_drives WHERE device_id = 'C:';"
$deviceHealthOutput = & $osqueryiPath --json $deviceHealthQuery 2>&1
$deviceHealthJson = Get-JsonFromOsqueryOutput -Output $deviceHealthOutput
if ($deviceHealthJson) {
    try {
        $dhArray = $deviceHealthJson | ConvertFrom-Json
        if ($dhArray -and $dhArray.Count -gt 0 -and $dhArray[0]) {
            $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $hostname = $env:COMPUTERNAME
            $calTime = (Get-Date).ToUniversalTime().ToString('ddd MMM dd HH:mm:ss yyyy UTC')
            $entry = @{
                name = 'device_health'
                hostIdentifier = $hostname
                calendarTime = $calTime
                unixTime = $timestamp
                epoch = 0
                counter = 0
                numerics = $false
                decorations = @{
                    hostname = $hostname
                }
                columns = $dhArray[0]
                action = 'added'
            } | ConvertTo-Json -Depth 10 -Compress
            Add-Content -Path $logPath -Value $entry -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] device_health data written to log" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [ERROR] Error processing device_health: $_" -ForegroundColor Red
    }
}

Write-Host "Running battery_health query (WMI only)..." -ForegroundColor Yellow
# Use WMI only for battery data (more reliable on Windows)
$batteryData = $null

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
        Write-Host "  [OK] Battery data from WMI (Percentage: $($batteryData.percentage)%)" -ForegroundColor Green
    }
} catch {
    Write-Host "  [ERROR] Failed to get battery data from WMI: $_" -ForegroundColor Red
}

# Write battery data if we got it
if ($batteryData) {
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
    Add-Content -Path $logPath -Value $entry -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] battery_health data written to log (Percentage: $($batteryData.percentage)%)" -ForegroundColor Green
} else {
    Write-Host "  [WARN] No battery data (device may not have battery or battery not detected)" -ForegroundColor Gray
}

Write-Host "Running system_uptime query..." -ForegroundColor Yellow
$uptimeQuery = "SELECT total_seconds as uptime FROM uptime;"
$uptimeOutput = & $osqueryiPath --json $uptimeQuery 2>&1
$uptimeJson = Get-JsonFromOsqueryOutput -Output $uptimeOutput
if ($uptimeJson) {
    try {
        $uptimeArray = $uptimeJson | ConvertFrom-Json
        if ($uptimeArray -and $uptimeArray.Count -gt 0 -and $uptimeArray[0]) {
            $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $hostname = $env:COMPUTERNAME
            $calTime = (Get-Date).ToUniversalTime().ToString('ddd MMM dd HH:mm:ss yyyy UTC')
            $entry = @{
                name = 'system_uptime'
                hostIdentifier = $hostname
                calendarTime = $calTime
                unixTime = $timestamp
                epoch = 0
                counter = 0
                numerics = $false
                decorations = @{
                    hostname = $hostname
                }
                columns = $uptimeArray[0]
                action = 'added'
            } | ConvertTo-Json -Depth 10 -Compress
            Add-Content -Path $logPath -Value $entry -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] system_uptime data written to log" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [ERROR] Error processing system_uptime: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Queries executed! Now run:" -ForegroundColor Cyan
Write-Host "  cd 'C:\Program Files\osquery'" -ForegroundColor White
Write-Host "  .\send-osquery-data.ps1" -ForegroundColor White
Write-Host ""
Write-Host "To verify data was written, check:" -ForegroundColor Cyan
Write-Host "  Get-Content '$logPath' | Select-String 'device_health|battery_health|system_uptime' | Select-Object -Last 3" -ForegroundColor White
