# Simple test - just run this file
# Tests device registration with your Supabase credentials
# NOTE: Uses environment variables SUPABASE_URL and SUPABASE_ANON_KEY
# Set these before running: $env:SUPABASE_URL = "https://your-project.supabase.co"

$SupabaseUrl = $env:SUPABASE_URL
$SupabaseKey = $env:SUPABASE_ANON_KEY

if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -or [string]::IsNullOrWhiteSpace($SupabaseKey)) {
    Write-Host "ERROR: SUPABASE_URL and SUPABASE_ANON_KEY environment variables must be set" -ForegroundColor Red
    Write-Host "Set them with:" -ForegroundColor Yellow
    Write-Host '  $env:SUPABASE_URL = "https://your-project.supabase.co"' -ForegroundColor White
    Write-Host '  $env:SUPABASE_ANON_KEY = "your-anon-key"' -ForegroundColor White
    exit 1
}

Write-Host "Testing device registration..." -ForegroundColor Cyan
Write-Host ""

$hostname = $env:COMPUTERNAME
Write-Host "Hostname: $hostname" -ForegroundColor Yellow

$testDevice = @{
    hostname = $hostname
    device_inventory_code = "TEST-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    host_location = "Test Location"
    latitude = 18.5204
    longitude = 73.8567
    compliance_status = "unknown"
    last_seen = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
} | ConvertTo-Json

Write-Host "Device Data:" -ForegroundColor Yellow
Write-Host $testDevice
Write-Host ""

$headers = @{
    "apikey" = $SupabaseKey
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $SupabaseKey"
    "Prefer" = "return=representation"
}

try {
    Write-Host "Sending request to Supabase..." -ForegroundColor Cyan
    
    $response = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/devices" `
        -Method POST -Headers $headers -Body $testDevice
    
    Write-Host ""
    Write-Host "SUCCESS! Device registered!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response:" -ForegroundColor Cyan
    $response | ConvertTo-Json -Depth 5 | Write-Host
    
    Write-Host ""
    Write-Host "Now check Supabase dashboard or run:" -ForegroundColor Yellow
    Write-Host "SELECT * FROM devices WHERE hostname = '$hostname';" -ForegroundColor White
    
} catch {
    Write-Host ""
    Write-Host "ERROR: Registration failed!" -ForegroundColor Red
    Write-Host ""
    
    if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode.value__
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        
        Write-Host "HTTP Status: $statusCode" -ForegroundColor Red
        Write-Host "Error: $responseBody" -ForegroundColor Red
    } else {
        Write-Host "Error: $_" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Possible issues:" -ForegroundColor Yellow
    Write-Host "1. Run migration 006 in Supabase (allows anonymous inserts)" -ForegroundColor White
    Write-Host "2. Run migration 008 if you removed ID column" -ForegroundColor White
    Write-Host "3. Check Supabase URL and key are correct" -ForegroundColor White
}

Write-Host ""
pause



