# Geofence Debug Script
# Comprehensive debugging for geofence issues

# =====================================================
# UPDATE THESE VALUES
# =====================================================
$SupabaseUrl = "https://ujmcjezpmyvpiasfrwhm.supabase.co"
$SupabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqbWNqZXpwbXl2cGlhc2Zyd2htIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzOTQ2NzQsImV4cCI6MjA4MDk3MDY3NH0.LNeLEQs2K1AXyTG2vlCHyfRLpavFBSGgqjtwLoXdyMQ"
$DeviceHostname = $env:COMPUTERNAME  # Or set to specific hostname like "PC-LAB-001"

# Service Role Key is needed for manual geofence trigger
# Get it from: Supabase Dashboard > Settings > API > service_role key
$SupabaseServiceRoleKey = Read-Host "Enter Supabase Service Role Key (or press Enter to skip manual trigger test)"

# =====================================================
# NO NEED TO EDIT BELOW THIS LINE
# =====================================================

$DeviceHostname = $DeviceHostname.Trim().ToUpper()

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Geofence Debug Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Supabase URL: $SupabaseUrl" -ForegroundColor Gray
Write-Host "Device Hostname: $DeviceHostname" -ForegroundColor Gray
Write-Host ""

$anonHeaders = @{
    "apikey" = $SupabaseAnonKey
    "Authorization" = "Bearer $SupabaseAnonKey"
    "Content-Type" = "application/json"
}

$serviceHeaders = @{
    "apikey" = $SupabaseServiceRoleKey
    "Authorization" = "Bearer $SupabaseServiceRoleKey"
    "Content-Type" = "application/json"
}

$allChecksPassed = $true

# =====================================================
# Check 1: Device exists and has location_id
# =====================================================
Write-Host "Check 1: Device location_id assignment..." -ForegroundColor Yellow
$device = $null
try {
    # Note: This requires authenticated access or service role key
    # Using service role key if available, otherwise anon key
    $headersToUse = if ($SupabaseServiceRoleKey) { $serviceHeaders } else { $anonHeaders }
    
    # Try exact match first
    $url = "$SupabaseUrl/rest/v1/devices?hostname=eq.$DeviceHostname&select=hostname,location_id,latitude,longitude,compliance_status"
    $response = Invoke-RestMethod -Uri $url -Method GET -Headers $headersToUse -ErrorAction Stop
    
    if ($response -and $response.Count -gt 0) {
        $device = $response[0]
        Write-Host "  [OK] Device found: $($device.hostname)" -ForegroundColor Green
        Write-Host "    Location ID: $($device.location_id)" -ForegroundColor $(if ($device.location_id) { "Green" } else { "Red" })
        Write-Host "    Current Lat: $($device.latitude)" -ForegroundColor Gray
        Write-Host "    Current Lon: $($device.longitude)" -ForegroundColor Gray
        Write-Host "    Compliance: $($device.compliance_status)" -ForegroundColor Gray
        
        if (-not $device.location_id) {
            Write-Host "  [ISSUE] Device has no location_id assigned!" -ForegroundColor Red
            Write-Host "    Fix: Assign a location to this device in the dashboard" -ForegroundColor Yellow
            $allChecksPassed = $false
        }
    } else {
        # Try case-insensitive search if service role key available
        if ($SupabaseServiceRoleKey) {
            Write-Host "  [INFO] Exact match not found, searching case-insensitive..." -ForegroundColor Yellow
            $url = "$SupabaseUrl/rest/v1/devices?select=hostname,location_id&limit=100"
            $allDevices = Invoke-RestMethod -Uri $url -Method GET -Headers $headersToUse -ErrorAction Stop
            
            $matchingDevices = $allDevices | Where-Object { $_.hostname -eq $DeviceHostname -or $_.hostname.ToUpper() -eq $DeviceHostname.ToUpper() }
            
            if ($matchingDevices -and $matchingDevices.Count -gt 0) {
                $device = $matchingDevices[0]
                Write-Host "  [OK] Device found (case variation): $($device.hostname)" -ForegroundColor Green
                Write-Host "    Location ID: $($device.location_id)" -ForegroundColor $(if ($device.location_id) { "Green" } else { "Red" })
                
                if (-not $device.location_id) {
                    Write-Host "  [ISSUE] Device has no location_id assigned!" -ForegroundColor Red
                    $allChecksPassed = $false
                }
            } else {
                Write-Host "  [ERROR] Device not found: $DeviceHostname" -ForegroundColor Red
                Write-Host "    Available devices (first 10):" -ForegroundColor Yellow
                foreach ($d in $allDevices | Select-Object -First 10) {
                    Write-Host "      - $($d.hostname)" -ForegroundColor Gray
                }
                if ($allDevices.Count -gt 10) {
                    Write-Host "      ... and $($allDevices.Count - 10) more" -ForegroundColor Gray
                }
                Write-Host ""
                Write-Host "  [ACTION REQUIRED] Device needs to be enrolled first!" -ForegroundColor Red
                Write-Host "    Run: .\enroll-device.ps1 -SupabaseUrl `"$SupabaseUrl`" -SupabaseAnonKey `"$SupabaseAnonKey`"" -ForegroundColor Yellow
                $allChecksPassed = $false
            }
        } else {
            Write-Host "  [ERROR] Device not found: $DeviceHostname" -ForegroundColor Red
            Write-Host "    Possible reasons:" -ForegroundColor Yellow
            Write-Host "      1. Device not enrolled yet" -ForegroundColor Gray
            Write-Host "      2. Hostname mismatch (case-sensitive)" -ForegroundColor Gray
            Write-Host "      3. RLS blocking query (need service role key to verify)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "    To enroll device, run:" -ForegroundColor Yellow
            Write-Host "      .\enroll-device.ps1 -SupabaseUrl `"$SupabaseUrl`" -SupabaseAnonKey `"$SupabaseAnonKey`"" -ForegroundColor Cyan
            $allChecksPassed = $false
        }
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "  [ERROR] Failed to query device: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    Status Code: $statusCode" -ForegroundColor Red
    
    if ($statusCode -eq 403 -or $statusCode -eq 401) {
        Write-Host "    [RLS BLOCKED] Query blocked by Row Level Security" -ForegroundColor Yellow
        Write-Host "      Solution: Provide service role key at script start to bypass RLS" -ForegroundColor Yellow
    } elseif ($statusCode -eq 404) {
        Write-Host "    Device not found or endpoint doesn't exist" -ForegroundColor Yellow
    }
    
    $allChecksPassed = $false
}

Write-Host ""

# =====================================================
# Check 2: Location has radius_meters set
# =====================================================
Write-Host "Check 2: Location radius_meters configuration..." -ForegroundColor Yellow
try {
    if ($device -and $device.location_id) {
        $url = "$SupabaseUrl/rest/v1/locations?id=eq.$($device.location_id)&select=id,name,latitude,longitude,radius_meters,is_active"
        $response = Invoke-RestMethod -Uri $url -Method GET -Headers $anonHeaders -ErrorAction Stop
        
        if ($response -and $response.Count -gt 0) {
            $location = $response[0]
            Write-Host "  [OK] Location found: $($location.name)" -ForegroundColor Green
            Write-Host "    Location ID: $($location.id)" -ForegroundColor Gray
            Write-Host "    Center Lat: $($location.latitude)" -ForegroundColor Gray
            Write-Host "    Center Lon: $($location.longitude)" -ForegroundColor Gray
            Write-Host "    Radius: $($location.radius_meters) meters" -ForegroundColor $(if ($location.radius_meters -and $location.radius_meters -gt 0) { "Green" } else { "Red" })
            Write-Host "    Active: $($location.is_active)" -ForegroundColor Gray
            
            if (-not $location.radius_meters -or $location.radius_meters -eq 0) {
                Write-Host "  [ISSUE] Location has no radius_meters set!" -ForegroundColor Red
                Write-Host "    Fix: Update location in dashboard to set radius_meters (default: 1000m)" -ForegroundColor Yellow
                $allChecksPassed = $false
            }
            
            if (-not $location.is_active) {
                Write-Host "  [WARNING] Location is not active" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [ERROR] Location not found for ID: $($device.location_id)" -ForegroundColor Red
            $allChecksPassed = $false
        }
    } else {
        Write-Host "  [SKIP] Cannot check location - device has no location_id" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [ERROR] Failed to query location: $($_.Exception.Message)" -ForegroundColor Red
    $allChecksPassed = $false
}

Write-Host ""

# =====================================================
# Check 3: Check WiFi mappings for location
# =====================================================
Write-Host "Check 3: WiFi mappings for location..." -ForegroundColor Yellow
try {
    if ($device -and $device.location_id) {
        $url = "$SupabaseUrl/rest/v1/location_wifi_mappings?location_id=eq.$($device.location_id)&select=wifi_ssid,is_active"
        $response = Invoke-RestMethod -Uri $url -Method GET -Headers $anonHeaders -ErrorAction Stop
        
        if ($response -and $response.Count -gt 0) {
            $activeMappings = $response | Where-Object { $_.is_active -eq $true }
            Write-Host "  [OK] Found $($activeMappings.Count) active WiFi mapping(s)" -ForegroundColor Green
            foreach ($mapping in $activeMappings) {
                Write-Host "    - SSID: $($mapping.wifi_ssid)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  [INFO] No WiFi mappings found for this location" -ForegroundColor Yellow
            Write-Host "    Geofencing will use GPS-based method only" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [SKIP] Cannot check WiFi mappings - device has no location_id" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [WARNING] Failed to query WiFi mappings: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# =====================================================
# Check 4: Check existing geofence alerts
# =====================================================
Write-Host "Check 4: Existing geofence alerts..." -ForegroundColor Yellow
try {
    if ($device) {
        # Try with service role key first, fallback to anon
        $headersToUse = if ($SupabaseServiceRoleKey) { $serviceHeaders } else { $anonHeaders }
        
        $url = "$SupabaseUrl/rest/v1/geofence_alerts?device_id=eq.$DeviceHostname&select=id,violation_type,latitude,longitude,distance_meters,created_at,resolved_at&order=created_at.desc&limit=5"
        $response = Invoke-RestMethod -Uri $url -Method GET -Headers $headersToUse -ErrorAction Stop
        
        if ($response -and $response.Count -gt 0) {
            $unresolved = $response | Where-Object { -not $_.resolved_at }
            Write-Host "  [INFO] Found $($response.Count) recent alert(s), $($unresolved.Count) unresolved" -ForegroundColor $(if ($unresolved.Count -gt 0) { "Yellow" } else { "Green" })
            foreach ($alert in $response | Select-Object -First 3) {
                $status = if ($alert.resolved_at) { "RESOLVED" } else { "UNRESOLVED" }
                Write-Host "    - ${status}: $($alert.violation_type) at ($($alert.latitude), $($alert.longitude))" -ForegroundColor Gray
                if ($alert.distance_meters) {
                    Write-Host "      Distance: $($alert.distance_meters)m" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "  [OK] No geofence alerts found for this device" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "  [WARNING] Failed to query alerts: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "    This may be due to RLS policies - alerts require authenticated access" -ForegroundColor Gray
}

Write-Host ""

# =====================================================
# Check 5: Test geofence-alert function deployment
# =====================================================
Write-Host "Check 5: Testing geofence-alert function..." -ForegroundColor Yellow
if (-not $SupabaseServiceRoleKey) {
    Write-Host "  [SKIP] Service role key not provided - cannot test function" -ForegroundColor Yellow
    Write-Host "    To test: Provide service role key at the start of this script" -ForegroundColor Gray
} else {
    try {
        # Test with a minimal request (will fail validation but confirms function exists)
        $testBody = @{
            device_id = $DeviceHostname
            latitude = 0
            longitude = 0
        } | ConvertTo-Json
        
        $url = "$SupabaseUrl/functions/v1/geofence-alert"
        $response = Invoke-RestMethod -Uri $url -Method POST -Headers $serviceHeaders -Body $testBody -ErrorAction Stop
        
        Write-Host "  [OK] Function is deployed and responding" -ForegroundColor Green
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            Write-Host "  [ISSUE] Function not found (404) - geofence-alert may not be deployed" -ForegroundColor Red
            Write-Host "    Fix: Run: supabase functions deploy geofence-alert" -ForegroundColor Yellow
            $allChecksPassed = $false
        } elseif ($statusCode -eq 400) {
            # 400 is expected for invalid data - means function exists
            Write-Host "  [OK] Function is deployed (400 = validation error, which is expected)" -ForegroundColor Green
        } else {
            Write-Host "  [WARNING] Function returned status $statusCode" -ForegroundColor Yellow
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
        }
    }
}

Write-Host ""

# =====================================================
# Check 6: Manual geofence trigger (if service key provided)
# =====================================================
if ($SupabaseServiceRoleKey -and $device -and $device.location_id) {
    Write-Host "Check 6: Manual geofence trigger test..." -ForegroundColor Yellow
    Write-Host "  Testing with coordinates outside geofence..." -ForegroundColor Gray
    
    # Use coordinates far from location (Delhi coordinates as example)
    $testLat = 28.7041
    $testLon = 77.1025
    
    try {
        $testBody = @{
            device_id = $DeviceHostname
            latitude = $testLat
            longitude = $testLon
        } | ConvertTo-Json
        
        $url = "$SupabaseUrl/functions/v1/geofence-alert"
        $response = Invoke-RestMethod -Uri $url -Method POST -Headers $serviceHeaders -Body $testBody -ErrorAction Stop
        
        Write-Host "  [OK] Geofence check triggered successfully" -ForegroundColor Green
        Write-Host "    Status: $($response.status)" -ForegroundColor Gray
        Write-Host "    Message: $($response.message)" -ForegroundColor Gray
        if ($response.distance_meters) {
            Write-Host "    Distance: $($response.distance_meters)m" -ForegroundColor Gray
        }
        if ($response.radius_meters) {
            Write-Host "    Radius: $($response.radius_meters)m" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [ERROR] Failed to trigger geofence check: $($_.Exception.Message)" -ForegroundColor Red
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "    Status Code: $statusCode" -ForegroundColor Red
        
        # Try to parse error response
        try {
            $errorStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorStream)
            $errorBody = $reader.ReadToEnd() | ConvertFrom-Json
            Write-Host "    Error: $($errorBody.error)" -ForegroundColor Red
        } catch {
            # Ignore JSON parse errors
        }
    }
} else {
    Write-Host "Check 6: Manual geofence trigger..." -ForegroundColor Yellow
    if (-not $SupabaseServiceRoleKey) {
        Write-Host "  [SKIP] Service role key not provided" -ForegroundColor Yellow
    } elseif (-not $device -or -not $device.location_id) {
        Write-Host "  [SKIP] Device has no location_id assigned" -ForegroundColor Yellow
    }
}

Write-Host ""

# =====================================================
# Summary
# =====================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($allChecksPassed -and $device) {
    Write-Host "All critical checks passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "If geofence is still not working:" -ForegroundColor Yellow
    Write-Host "  1. Ensure device is sending osquery data (GPS or WiFi)" -ForegroundColor Gray
    Write-Host "  2. Geofence only triggers when device sends data, not on manual DB updates" -ForegroundColor Gray
    Write-Host "  3. Check device logs for osquery data transmission" -ForegroundColor Gray
    Write-Host "  4. Verify fetch-osquery-data function is processing location data" -ForegroundColor Gray
} elseif (-not $device) {
    Write-Host "Device not found in database!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Enroll the device first:" -ForegroundColor Cyan
    Write-Host "     .\enroll-device.ps1 -SupabaseUrl `"$SupabaseUrl`" -SupabaseAnonKey `"$SupabaseAnonKey`"" -ForegroundColor White
    Write-Host ""
    Write-Host "  2. After enrollment, assign a location to the device in the dashboard" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. Then run this debug script again" -ForegroundColor Cyan
} else {
    Write-Host "Issues found! Fix the items marked with [ISSUE] above." -ForegroundColor Red
}

Write-Host ""
Write-Host "To manually trigger geofence check:" -ForegroundColor Cyan
Write-Host '  $body = @{' -ForegroundColor Gray
Write-Host "    device_id = '$DeviceHostname'" -ForegroundColor Gray
Write-Host "    latitude = 28.7041" -ForegroundColor Gray
Write-Host "    longitude = 77.1025" -ForegroundColor Gray
Write-Host '  } | ConvertTo-Json' -ForegroundColor Gray
Write-Host "  `$headers = @{" -ForegroundColor Gray
Write-Host "    'Authorization' = 'Bearer YOUR_SERVICE_ROLE_KEY'" -ForegroundColor Gray
Write-Host "    'Content-Type' = 'application/json'" -ForegroundColor Gray
Write-Host "  }" -ForegroundColor Gray
Write-Host "  Invoke-RestMethod -Uri '$SupabaseUrl/functions/v1/geofence-alert' -Method POST -Headers `$headers -Body `$body" -ForegroundColor Gray
Write-Host ""

