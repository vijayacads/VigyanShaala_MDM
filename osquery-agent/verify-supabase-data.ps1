# verify-supabase-data.ps1
# Verifies that data was successfully stored in Supabase

param(
    [Parameter(Mandatory=$false)]
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY,
    
    [Parameter(Mandatory=$false)]
    [string]$Hostname = $env:COMPUTERNAME
)

# Try to get from environment if not provided
if (-not $SupabaseUrl) { $SupabaseUrl = $env:SUPABASE_URL }
if (-not $SupabaseAnonKey) { $SupabaseAnonKey = $env:SUPABASE_ANON_KEY }

if (-not $SupabaseUrl -or -not $SupabaseAnonKey) {
    Write-Host "ERROR: SUPABASE_URL and SUPABASE_ANON_KEY must be set" -ForegroundColor Red
    Write-Host "Set them as environment variables or pass as parameters" -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Verifying Data in Supabase ===" -ForegroundColor Cyan
Write-Host "Hostname: $Hostname" -ForegroundColor Yellow
Write-Host ""

# Query device_health table
$headers = @{
    "apikey" = $SupabaseAnonKey
    "Authorization" = "Bearer $SupabaseAnonKey"
    "Content-Type" = "application/json"
}

try {
    # Get device_health data
    $healthUrl = "$SupabaseUrl/rest/v1/device_health?device_hostname=eq.$Hostname&select=*"
    $healthResponse = Invoke-RestMethod -Uri $healthUrl -Method GET -Headers $headers -ErrorAction Stop
    
    Write-Host "=== Device Health Data ===" -ForegroundColor Yellow
    if ($healthResponse -and $healthResponse.Count -gt 0) {
        $health = $healthResponse[0]
        Write-Host "  Battery: $($health.battery_health_percent)%" -ForegroundColor $(if ($health.battery_health_percent) { "Green" } else { "Gray" })
        Write-Host "  Storage Used: $($health.storage_used_percent)%" -ForegroundColor $(if ($health.storage_used_percent) { "Green" } else { "Gray" })
        Write-Host "  Boot Time: $($health.boot_time_avg_seconds) seconds" -ForegroundColor $(if ($health.boot_time_avg_seconds) { "Green" } else { "Gray" })
        Write-Host "  Crash Count: $($health.crash_error_count)" -ForegroundColor Green
        Write-Host "  Performance: $($health.performance_status)" -ForegroundColor $(switch ($health.performance_status) { "good" { "Green" } "warning" { "Yellow" } "critical" { "Red" } default { "Gray" } })
        Write-Host "  Last Updated: $($health.updated_at)" -ForegroundColor Gray
    } else {
        Write-Host "  [WARN] No device_health data found" -ForegroundColor Yellow
    }
    
    Write-Host ""
    
    # Get device last_seen
    $deviceUrl = "$SupabaseUrl/rest/v1/devices?hostname=eq.$Hostname&select=hostname,last_seen"
    $deviceResponse = Invoke-RestMethod -Uri $deviceUrl -Method GET -Headers $headers -ErrorAction Stop
    
    Write-Host "=== Device Status ===" -ForegroundColor Yellow
    if ($deviceResponse -and $deviceResponse.Count -gt 0) {
        $device = $deviceResponse[0]
        Write-Host "  Hostname: $($device.hostname)" -ForegroundColor Green
        Write-Host "  Last Seen: $($device.last_seen)" -ForegroundColor Green
        
        $lastSeen = [DateTime]::Parse($device.last_seen)
        $timeSince = (Get-Date) - $lastSeen
        if ($timeSince.TotalMinutes -lt 10) {
            Write-Host "  Status: Online (seen $([Math]::Round($timeSince.TotalMinutes, 1)) minutes ago)" -ForegroundColor Green
        } elseif ($timeSince.TotalMinutes -lt 30) {
            Write-Host "  Status: Recent (seen $([Math]::Round($timeSince.TotalMinutes, 1)) minutes ago)" -ForegroundColor Yellow
        } else {
            Write-Host "  Status: Stale (seen $([Math]::Round($timeSince.TotalHours, 1)) hours ago)" -ForegroundColor Red
        }
    } else {
        Write-Host "  [ERROR] Device not found in Supabase" -ForegroundColor Red
        Write-Host "  Device must be enrolled first!" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "=== Summary ===" -ForegroundColor Cyan
    if ($healthResponse -and $healthResponse.Count -gt 0 -and $health.battery_health_percent -ne $null) {
        Write-Host "  [OK] Data is being stored correctly in Supabase" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Some data may be missing. Check Edge Function logs." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "ERROR: Failed to query Supabase: $_" -ForegroundColor Red
    Write-Host "Make sure:" -ForegroundColor Yellow
    Write-Host "  1. Device is enrolled in Supabase" -ForegroundColor White
    Write-Host "  2. SUPABASE_URL and SUPABASE_ANON_KEY are correct" -ForegroundColor White
    Write-Host "  3. RLS policies allow reading device_health data" -ForegroundColor White
    exit 1
}

