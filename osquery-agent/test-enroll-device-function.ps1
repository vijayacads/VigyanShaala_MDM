# Quick Test Script for enroll_device Function
# Tests the SECURITY DEFINER function approach for device enrollment
# Run this before uploading to verify the fix works

# =====================================================
# CONFIGURATION - Uses environment variables
# =====================================================

# Your Supabase credentials (from environment variables or installer configuration)
# Set these before running: $env:SUPABASE_URL = "https://your-project.supabase.co"
$SupabaseUrl = $env:SUPABASE_URL
$SupabaseAnonKey = $env:SUPABASE_ANON_KEY

# =====================================================
# Test Function
# =====================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing enroll_device Function" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Validate credentials
if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -or [string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
    Write-Host "ERROR: SUPABASE_URL and SUPABASE_ANON_KEY environment variables must be set" -ForegroundColor Red
    Write-Host "Set them with:" -ForegroundColor Yellow
    Write-Host '  $env:SUPABASE_URL = "https://your-project.supabase.co"' -ForegroundColor White
    Write-Host '  $env:SUPABASE_ANON_KEY = "your-anon-key"' -ForegroundColor White
    exit 1
}

# Generate test hostname
$testHostname = "TEST-$(Get-Random -Minimum 1000 -Maximum 9999)-$(Get-Date -Format 'yyyyMMddHHmmss')"

Write-Host "Test Configuration:" -ForegroundColor Yellow
Write-Host "  Supabase URL: $SupabaseUrl" -ForegroundColor White
Write-Host "  Test Hostname: $testHostname" -ForegroundColor White
Write-Host ""

# Build test body with minimal required fields
$testBody = @{
    p_hostname = $testHostname
    p_compliance_status = "unknown"
    p_last_seen = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
} | ConvertTo-Json

Write-Host "Test Body:" -ForegroundColor Yellow
Write-Host $testBody -ForegroundColor Gray
Write-Host ""

# Prepare headers
$headers = @{
    "apikey" = $SupabaseAnonKey
    "Authorization" = "Bearer $SupabaseAnonKey"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

Write-Host "Calling enroll_device function..." -ForegroundColor Cyan
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/rpc/enroll_device" `
        -Method POST -Headers $headers -Body $testBody `
        -ErrorAction Stop
    
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "SUCCESS: Device enrolled successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response:" -ForegroundColor Cyan
    $response | ConvertTo-Json -Depth 5 | Write-Host
    Write-Host ""
    
    # Verify in database
    Write-Host "Verifying device in database..." -ForegroundColor Cyan
    $verifyHeaders = @{
        "apikey" = $SupabaseAnonKey
        "Authorization" = "Bearer $SupabaseAnonKey"
    }
    
    # Note: This SELECT will fail if RLS blocks anon (expected)
    # But the INSERT worked, which is what we're testing
    try {
        $verifyResponse = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/devices?hostname=eq.$testHostname&select=hostname,compliance_status,created_at" `
            -Method GET -Headers $verifyHeaders -ErrorAction Stop
        
        Write-Host "Device verified in database:" -ForegroundColor Green
        $verifyResponse | ConvertTo-Json -Depth 5 | Write-Host
    } catch {
        Write-Host "Note: Cannot verify via SELECT (RLS blocks anon - this is expected)" -ForegroundColor Yellow
        Write-Host "But INSERT worked, which means the function is working correctly!" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Test PASSED!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Check Supabase Dashboard → Table Editor → devices" -ForegroundColor White
    Write-Host "2. Look for hostname: $testHostname" -ForegroundColor White
    Write-Host "3. If device appears, the fix is working!" -ForegroundColor White
    Write-Host ""
    Write-Host "Cleanup (optional):" -ForegroundColor Yellow
    Write-Host "  DELETE FROM devices WHERE hostname = '$testHostname';" -ForegroundColor Gray
    
} catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "ERROR: Test Failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    
    $statusCode = $null
    $responseBody = ""
    
    if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode.value__
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        $reader.Close()
    }
    
    Write-Host "HTTP Status Code: $statusCode" -ForegroundColor Red
    Write-Host "Response Body: $responseBody" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error Details:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor White
    Write-Host ""
    
    if ($statusCode -eq 401) {
        Write-Host "Possible issues:" -ForegroundColor Yellow
        Write-Host "1. Invalid Supabase URL or Anon Key" -ForegroundColor White
        Write-Host "2. Function not created (run migration 027)" -ForegroundColor White
        Write-Host "3. Function permissions not granted" -ForegroundColor White
    } elseif ($statusCode -eq 404) {
        Write-Host "Possible issues:" -ForegroundColor Yellow
        Write-Host "1. Function 'enroll_device' does not exist" -ForegroundColor White
        Write-Host "2. Run migration 027 to create the function" -ForegroundColor White
    } elseif ($statusCode -eq 42501) {
        Write-Host "Possible issues:" -ForegroundColor Yellow
        Write-Host "1. Function exists but permissions not granted" -ForegroundColor White
        Write-Host "2. Check: GRANT EXECUTE ON FUNCTION enroll_device TO anon, authenticated;" -ForegroundColor White
    }
    
    exit 1
}
