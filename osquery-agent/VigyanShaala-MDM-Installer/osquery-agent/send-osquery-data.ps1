# send-osquery-data.ps1
# Reads osquery results and sends to Supabase edge function

param(
    [Parameter(Mandatory=$false)]
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY
)

# Get hostname
$hostname = $env:COMPUTERNAME

# Osquery log path
$logPath = "C:\ProgramData\osquery\logs\osqueryd.results.log"

# Check if log exists
if (-not (Test-Path $logPath)) {
    Write-Host "Osquery log not found: $logPath" -ForegroundColor Yellow
    exit 0
}

# Read recent log entries (last 200 lines to capture more data including battery)
$logLines = Get-Content $logPath -Tail 200 -ErrorAction SilentlyContinue

if (-not $logLines) {
    Write-Host "No log entries found" -ForegroundColor Yellow
    exit 0
}

# Build payload structure matching edge function expectations
$payload = @{
    hostname = $hostname
    wifi_networks = @()
    installed_programs = @()
    browser_history = @()
    system_info = @()
    device_health = @()
    battery_health = @()
    system_uptime = @()
    crash_events = @()
}

# Parse log entries (each line is a JSON object)
foreach ($line in $logLines) {
    try {
        $entry = $line | ConvertFrom-Json
        
        # Only process "added" actions (ignore "removed" actions)
        if ($entry.action -ne "added") {
            continue
        }
        
        # Map osquery query names to payload fields
        $queryName = $entry.name
        
        switch ($queryName) {
            "wifi_networks" {
                if ($entry.columns) {
                    $payload.wifi_networks += $entry.columns
                }
            }
            "installed_programs" {
                if ($entry.columns) {
                    $payload.installed_programs += $entry.columns
                }
            }
            "browser_history" {
                if ($entry.columns) {
                    $payload.browser_history += $entry.columns
                }
            }
            "system_info" {
                if ($entry.columns) {
                    $payload.system_info += $entry.columns
                }
            }
            "device_health" {
                if ($entry.columns) {
                    $payload.device_health += $entry.columns
                }
            }
            "battery_health" {
                if ($entry.columns) {
                    $payload.battery_health += $entry.columns
                }
            }
            "system_uptime" {
                if ($entry.columns) {
                    $payload.system_uptime += $entry.columns
                }
            }
            "crash_events" {
                if ($entry.columns) {
                    $payload.crash_events += $entry.columns
                }
            }
        }
    } catch {
        # Skip invalid JSON lines
        continue
    }
}

# Debug: Show what data we collected
Write-Host "`n=== Collected Data Summary ===" -ForegroundColor Cyan
Write-Host "  - wifi_networks: $($payload.wifi_networks.Count)" -ForegroundColor Gray
Write-Host "  - installed_programs: $($payload.installed_programs.Count)" -ForegroundColor Gray
Write-Host "  - browser_history: $($payload.browser_history.Count)" -ForegroundColor Gray
Write-Host "  - system_info: $($payload.system_info.Count)" -ForegroundColor Gray
Write-Host "  - device_health: $($payload.device_health.Count)" -ForegroundColor Gray
Write-Host "  - battery_health: $($payload.battery_health.Count)" -ForegroundColor Gray
Write-Host "  - system_uptime: $($payload.system_uptime.Count)" -ForegroundColor Gray
Write-Host "  - crash_events: $($payload.crash_events.Count)" -ForegroundColor Gray

# Show detailed data for key metrics
if ($payload.device_health.Count -gt 0) {
    Write-Host "`n=== Device Health Data ===" -ForegroundColor Yellow
    $payload.device_health | ForEach-Object { $_ | ConvertTo-Json -Compress | Write-Host -ForegroundColor White }
}

if ($payload.battery_health.Count -gt 0) {
    Write-Host "`n=== Battery Health Data ===" -ForegroundColor Yellow
    $payload.battery_health | ForEach-Object { $_ | ConvertTo-Json -Compress | Write-Host -ForegroundColor White }
}

if ($payload.system_uptime.Count -gt 0) {
    Write-Host "`n=== System Uptime Data ===" -ForegroundColor Yellow
    $payload.system_uptime | ForEach-Object { $_ | ConvertTo-Json -Compress | Write-Host -ForegroundColor White }
}

# Only send if we have some data
$hasData = $payload.wifi_networks.Count -gt 0 -or 
           $payload.installed_programs.Count -gt 0 -or 
           $payload.browser_history.Count -gt 0 -or 
           $payload.system_info.Count -gt 0 -or
           $payload.device_health.Count -gt 0 -or
           $payload.battery_health.Count -gt 0 -or
           $payload.system_uptime.Count -gt 0 -or
           $payload.crash_events.Count -gt 0

if (-not $hasData) {
    Write-Host "No data to send" -ForegroundColor Yellow
    exit 0
}

# Send to Supabase edge function
try {
    $edgeFunctionUrl = "$SupabaseUrl/functions/v1/fetch-osquery-data"
    
    $headers = @{
        "apikey" = $SupabaseAnonKey
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $SupabaseAnonKey"
    }
    
    $body = $payload | ConvertTo-Json -Depth 10
    
    # Debug: Show full payload being sent
    Write-Host "`n=== Full Payload Being Sent ===" -ForegroundColor Cyan
    Write-Host $body -ForegroundColor White
    Write-Host "`n=== Payload Summary ===" -ForegroundColor Cyan
    Write-Host "  device_health entries: $($payload.device_health.Count)" -ForegroundColor $(if ($payload.device_health.Count -gt 0) { "Green" } else { "Yellow" })
    Write-Host "  battery_health entries: $($payload.battery_health.Count)" -ForegroundColor $(if ($payload.battery_health.Count -gt 0) { "Green" } else { "Yellow" })
    Write-Host "  system_uptime entries: $($payload.system_uptime.Count)" -ForegroundColor $(if ($payload.system_uptime.Count -gt 0) { "Green" } else { "Yellow" })
    Write-Host "`n=== Sending to Supabase... ===" -ForegroundColor Cyan
    
    $response = Invoke-RestMethod -Uri $edgeFunctionUrl -Method POST -Headers $headers -Body $body -ErrorAction Stop
    
    Write-Host "Data sent successfully: $($response | ConvertTo-Json)" -ForegroundColor Green
} catch {
    Write-Host "Error sending data: $_" -ForegroundColor Red
    exit 1
}

