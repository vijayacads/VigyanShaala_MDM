# Test script to verify device registration and check Supabase
# Run this to troubleshoot why device isn't showing up

param(
    [Parameter(Mandatory=$false)]
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY,
    
    [Parameter(Mandatory=$false)]
    [string]$Hostname = $env:COMPUTERNAME
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Device Registration Diagnostic Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check credentials
if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -or [string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
    Write-Host "ERROR: Supabase credentials not found" -ForegroundColor Red
    Write-Host "SupabaseUrl: $SupabaseUrl" -ForegroundColor Yellow
    Write-Host "SupabaseKey: [SET: $(![string]::IsNullOrWhiteSpace($SupabaseAnonKey))]" -ForegroundColor Yellow
    exit 1
}

Write-Host "Testing Supabase connection..." -ForegroundColor Cyan
Write-Host "URL: $SupabaseUrl" -ForegroundColor Gray
Write-Host "Hostname: $Hostname" -ForegroundColor Gray
Write-Host ""

$headers = @{
    "apikey" = $SupabaseAnonKey
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $SupabaseAnonKey"
}

# Test 1: Check if device exists
Write-Host "Test 1: Checking if device exists..." -ForegroundColor Yellow
try {
    $checkUrl = "$SupabaseUrl/rest/v1/devices?hostname=eq.$Hostname&select=*"
    Write-Host "Query URL: $checkUrl" -ForegroundColor Gray
    
    $existing = Invoke-RestMethod -Uri $checkUrl -Method GET -Headers $headers
    
    if ($existing -and $existing.Count -gt 0) {
        Write-Host "✓ Device FOUND in database!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Device Details:" -ForegroundColor Cyan
        $existing[0] | ConvertTo-Json -Depth 5 | Write-Host
        Write-Host ""
        Write-Host "If you can't see it in Supabase dashboard, RLS policies might be blocking." -ForegroundColor Yellow
        Write-Host "Try running: SELECT * FROM devices WHERE hostname = '$Hostname'; in Supabase SQL Editor" -ForegroundColor Yellow
    } else {
        Write-Host "✗ Device NOT found" -ForegroundColor Red
        Write-Host ""
        
        # Test 2: Try to list all devices (might be blocked by RLS)
        Write-Host "Test 2: Checking all devices (might be blocked by RLS)..." -ForegroundColor Yellow
        try {
            $allDevices = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/devices?select=hostname&limit=10" -Method GET -Headers $headers
            Write-Host "✓ Can query devices table" -ForegroundColor Green
            Write-Host "Found $($allDevices.Count) devices" -ForegroundColor Cyan
            if ($allDevices.Count -gt 0) {
                Write-Host "Sample hostnames:" -ForegroundColor Gray
                $allDevices | ForEach-Object { Write-Host "  - $($_.hostname)" -ForegroundColor Gray }
            }
        } catch {
            Write-Host "✗ Cannot query devices (RLS blocking or table doesn't exist)" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
        }
        
        # Test 3: Try to insert a test device
        Write-Host ""
        Write-Host "Test 3: Attempting test device registration..." -ForegroundColor Yellow
        
        $testDevice = @{
            hostname = "$Hostname-TEST"
            device_inventory_code = "TEST-REGISTRATION"
            host_location = "Test Location"
            latitude = 18.5204
            longitude = 73.8567
            compliance_status = "unknown"
            last_seen = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        } | ConvertTo-Json -Depth 10
        
        Write-Host "Test device data:" -ForegroundColor Gray
        Write-Host $testDevice -ForegroundColor Gray
        Write-Host ""
        
        try {
            $response = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/devices" `
                -Method POST -Headers $headers -Body $testDevice
            
            Write-Host "✓ Test device registered successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Response:" -ForegroundColor Cyan
            $response | ConvertTo-Json -Depth 5 | Write-Host
            Write-Host ""
            Write-Host "Registration works! Your original device might have failed silently." -ForegroundColor Yellow
            Write-Host "Check the PowerShell window where you ran the installer for error messages." -ForegroundColor Yellow
            
        } catch {
            $statusCode = $null
            $responseBody = ""
            
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode.value__
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd()
            }
            
            Write-Host "✗ Test registration FAILED" -ForegroundColor Red
            Write-Host ""
            Write-Host "HTTP Status: $statusCode" -ForegroundColor Red
            Write-Host "Error Details: $responseBody" -ForegroundColor Red
            Write-Host "Exception: $_" -ForegroundColor Red
            Write-Host ""
            Write-Host "Possible issues:" -ForegroundColor Yellow
            Write-Host "1. RLS policy not allowing inserts - Run migration 006" -ForegroundColor White
            Write-Host "2. Table structure changed - Run migration 008 if you removed ID column" -ForegroundColor White
            Write-Host "3. Invalid data format" -ForegroundColor White
        }
    }
} catch {
    Write-Host "✗ Error checking device: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible issues:" -ForegroundColor Yellow
    Write-Host "1. Network connectivity" -ForegroundColor White
    Write-Host "2. Invalid Supabase URL or key" -ForegroundColor White
    Write-Host "3. RLS blocking queries" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Diagnostic Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

