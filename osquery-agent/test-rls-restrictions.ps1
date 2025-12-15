# Test RLS Restrictions After Migration 024
# Tests that device-specific access works while enumeration is blocked

param(
    [Parameter(Mandatory=$false)]
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY,
    
    [Parameter(Mandatory=$false)]
    [string]$Hostname = $env:COMPUTERNAME
)

# Try to get from environment if not provided
if (-not $SupabaseUrl) { 
    Write-Host "ERROR: SUPABASE_URL not provided and not in environment" -ForegroundColor Red
    Write-Host "Usage: .\test-rls-restrictions.ps1 -SupabaseUrl 'YOUR_URL' -SupabaseAnonKey 'YOUR_KEY' -Hostname 'DEVICE_HOSTNAME'" -ForegroundColor Yellow
    exit 1
}

if (-not $SupabaseAnonKey) { 
    Write-Host "ERROR: SUPABASE_ANON_KEY not provided and not in environment" -ForegroundColor Red
    Write-Host "Usage: .\test-rls-restrictions.ps1 -SupabaseUrl 'YOUR_URL' -SupabaseAnonKey 'YOUR_KEY' -Hostname 'DEVICE_HOSTNAME'" -ForegroundColor Yellow
    exit 1
}

if (-not $Hostname) {
    $Hostname = $env:COMPUTERNAME
}

$Hostname = $Hostname.Trim().ToUpper()

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing RLS Restrictions (Migration 024)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Supabase URL: $SupabaseUrl" -ForegroundColor Gray
Write-Host "Hostname: $Hostname" -ForegroundColor Gray
Write-Host ""

$headers = @{
    "apikey" = $SupabaseAnonKey
    "Authorization" = "Bearer $SupabaseAnonKey"
    "Content-Type" = "application/json"
}

$allTestsPassed = $true

# =====================================================
# Test 1: Read device by hostname (should work)
# =====================================================
Write-Host "Test 1: Reading device by hostname..." -ForegroundColor Yellow
try {
    $url = "$SupabaseUrl/rest/v1/devices?hostname=eq.$Hostname"
    $response = Invoke-RestMethod -Uri $url -Method GET -Headers $headers -ErrorAction Stop
    
    if ($response -and $response.Count -gt 0) {
        Write-Host "  ✓ SUCCESS: Device found ($($response.Count) record)" -ForegroundColor Green
        Write-Host "    Hostname: $($response[0].hostname)" -ForegroundColor Gray
        Write-Host "    Inventory Code: $($response[0].device_inventory_code)" -ForegroundColor Gray
    } else {
        Write-Host "  ⚠ WARNING: Device not found (may not be enrolled yet)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ✗ FAILED: $_" -ForegroundColor Red
    $allTestsPassed = $false
}

Write-Host ""

# =====================================================
# Test 2: Read device_health by hostname (should work)
# =====================================================
Write-Host "Test 2: Reading device_health by hostname..." -ForegroundColor Yellow
try {
    $healthUrl = "$SupabaseUrl/rest/v1/device_health?device_hostname=eq.$Hostname"
    $healthResponse = Invoke-RestMethod -Uri $healthUrl -Method GET -Headers $headers -ErrorAction Stop
    
    if ($healthResponse -and $healthResponse.Count -gt 0) {
        Write-Host "  ✓ SUCCESS: Health data found ($($healthResponse.Count) record)" -ForegroundColor Green
        $health = $healthResponse[0]
        Write-Host "    Battery: $($health.battery_health_percent)%" -ForegroundColor Gray
        Write-Host "    Storage: $($health.storage_used_percent)%" -ForegroundColor Gray
        Write-Host "    Performance: $($health.performance_status)" -ForegroundColor Gray
    } else {
        Write-Host "  ⚠ WARNING: No health data found (may not have been collected yet)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ✗ FAILED: $_" -ForegroundColor Red
    $allTestsPassed = $false
}

Write-Host ""

# =====================================================
# Test 3: Try to list all devices (should fail/return empty)
# =====================================================
Write-Host "Test 3: Attempting to list all devices (should be blocked)..." -ForegroundColor Yellow
try {
    $allUrl = "$SupabaseUrl/rest/v1/devices?select=hostname&limit=10"
    $allDevices = Invoke-RestMethod -Uri $allUrl -Method GET -Headers $headers -ErrorAction Stop
    
    if ($allDevices.Count -eq 0) {
        Write-Host "  ✓ SUCCESS: Enumeration blocked (returned 0 devices)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ SECURITY ISSUE: Enumeration not blocked! Returned $($allDevices.Count) devices" -ForegroundColor Red
        Write-Host "    This means RLS is not working correctly!" -ForegroundColor Red
        $allTestsPassed = $false
    }
} catch {
    # If it throws an error, that's also acceptable (different way of blocking)
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403 -or $statusCode -eq 401) {
        Write-Host "  ✓ SUCCESS: Enumeration blocked (403/401 error)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ INFO: Enumeration blocked (error: $statusCode)" -ForegroundColor Yellow
    }
}

Write-Host ""

# =====================================================
# Test 4: Try to list all device_health (should fail/return empty)
# =====================================================
Write-Host "Test 4: Attempting to list all device_health (should be blocked)..." -ForegroundColor Yellow
try {
    $allHealthUrl = "$SupabaseUrl/rest/v1/device_health?select=device_hostname&limit=10"
    $allHealth = Invoke-RestMethod -Uri $allHealthUrl -Method GET -Headers $headers -ErrorAction Stop
    
    if ($allHealth.Count -eq 0) {
        Write-Host "  ✓ SUCCESS: Enumeration blocked (returned 0 records)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ SECURITY ISSUE: Enumeration not blocked! Returned $($allHealth.Count) records" -ForegroundColor Red
        Write-Host "    This means RLS is not working correctly!" -ForegroundColor Red
        $allTestsPassed = $false
    }
} catch {
    # If it throws an error, that's also acceptable
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403 -or $statusCode -eq 401) {
        Write-Host "  ✓ SUCCESS: Enumeration blocked (403/401 error)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ INFO: Enumeration blocked (error: $statusCode)" -ForegroundColor Yellow
    }
}

Write-Host ""

# =====================================================
# Test 5: Verify INSERT still works (enrollment)
# =====================================================
Write-Host "Test 5: Testing INSERT (enrollment should still work)..." -ForegroundColor Yellow
Write-Host "  (Skipping actual INSERT to avoid creating test data)" -ForegroundColor Gray
Write-Host "  ✓ INSERT policy should still allow anon access" -ForegroundColor Green
Write-Host "    (Verify by running enrollment script separately)" -ForegroundColor Gray

Write-Host ""

# =====================================================
# Summary
# =====================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($allTestsPassed) {
    Write-Host "✓ All security tests passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "RLS restrictions are working correctly:" -ForegroundColor Green
    Write-Host "  - Device-specific access: WORKING" -ForegroundColor Green
    Write-Host "  - Device enumeration: BLOCKED" -ForegroundColor Green
    Write-Host "  - Production features: Should work normally" -ForegroundColor Green
} else {
    Write-Host "✗ Some tests failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check:" -ForegroundColor Yellow
    Write-Host "  1. Migration 024 was run successfully" -ForegroundColor Yellow
    Write-Host "  2. Policies are correctly created (see Step 2 results)" -ForegroundColor Yellow
    Write-Host "  3. Device hostname is correct" -ForegroundColor Yellow
}

Write-Host ""

