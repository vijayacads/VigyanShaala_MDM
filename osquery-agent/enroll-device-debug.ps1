# Enhanced enrollment script with detailed debugging
# Copy of enroll-device.ps1 with better error logging

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY
)

# Add detailed logging function
function Write-DebugLog {
    param($Message, $Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

Write-DebugLog "Starting device enrollment..." "Cyan"

# Get device info
function Get-DeviceInfo {
    $hostname = $env:COMPUTERNAME
    try {
        $serial = (Get-WmiObject Win32_BIOS).SerialNumber
    } catch {
        $serial = "UNKNOWN"
    }
    
    try {
        $osVersion = (Get-WmiObject Win32_OperatingSystem).Version
    } catch {
        $osVersion = "Unknown"
    }
    
    try {
        $laptopModel = (Get-WmiObject Win32_ComputerSystem).Model
    } catch {
        $laptopModel = ""
    }
    
    return @{
        hostname = $hostname
        serial_number = $serial
        os_version = $osVersion
        laptop_model = $laptopModel
    }
}

# Check environment variables
if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -or [string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
    Write-DebugLog "ERROR: Missing Supabase credentials" "Red"
    Write-DebugLog "SUPABASE_URL: $SupabaseUrl" "Yellow"
    Write-DebugLog "SUPABASE_ANON_KEY: [$(if($SupabaseAnonKey){'SET'}else{'NOT SET'})]" "Yellow"
    exit 1
}

Write-DebugLog "Supabase URL: $SupabaseUrl" "Gray"
Write-DebugLog "Credentials: OK" "Green"

# For testing - create a simple test device
$testData = @{
    device_inventory_code = "TEST-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    hostname = (Get-DeviceInfo).hostname
    serial_number = (Get-DeviceInfo).serial_number
    host_location = "Test Location"
    city_town_village = "Test City"
    laptop_model = (Get-DeviceInfo).laptop_model
    os_version = (Get-DeviceInfo).os_version
    latitude = 18.5204
    longitude = 73.8567
}

Write-DebugLog "Test device data prepared" "Cyan"
Write-DebugLog "Hostname: $($testData.hostname)" "Gray"

# Register device
$headers = @{
    "apikey" = $SupabaseAnonKey
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $SupabaseAnonKey"
    "Prefer" = "return=representation"
}

$body = @{
    hostname = $testData.hostname
    device_inventory_code = $testData.device_inventory_code
    serial_number = $testData.serial_number
    host_location = $testData.host_location
    city_town_village = $testData.city_town_village
    laptop_model = $testData.laptop_model
    os_version = $testData.os_version
    latitude = $testData.latitude
    longitude = $testData.longitude
    compliance_status = "unknown"
    last_seen = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
} | ConvertTo-Json -Depth 10

Write-DebugLog "Request body:" "Cyan"
Write-Host $body -ForegroundColor Gray
Write-Host ""

try {
    Write-DebugLog "Sending POST request to: $SupabaseUrl/rest/v1/devices" "Cyan"
    
    $response = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/devices" `
        -Method POST -Headers $headers -Body $body `
        -ErrorAction Stop
    
    Write-DebugLog "SUCCESS: Device registered!" "Green"
    Write-Host ""
    Write-Host "Response from Supabase:" -ForegroundColor Cyan
    $response | ConvertTo-Json -Depth 5 | Write-Host
    Write-Host ""
    
    # Verify it was saved
    Write-DebugLog "Verifying device was saved..." "Cyan"
    Start-Sleep -Seconds 1
    
    $verify = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/devices?hostname=eq.$($testData.hostname)&select=*" `
        -Method GET -Headers $headers
    
    if ($verify -and $verify.Count -gt 0) {
        Write-DebugLog "VERIFIED: Device exists in database" "Green"
        Write-Host "Device Details:" -ForegroundColor Cyan
        $verify[0] | ConvertTo-Json -Depth 5 | Write-Host
    } else {
        Write-DebugLog "WARNING: Device not found when verifying (might be RLS)" "Yellow"
    }
    
} catch {
    Write-DebugLog "ERROR: Registration failed" "Red"
    Write-Host ""
    
    $statusCode = $null
    $responseBody = ""
    
    if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode.value__
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        
        Write-Host "HTTP Status Code: $statusCode" -ForegroundColor Red
        Write-Host "Response Body: $responseBody" -ForegroundColor Red
    } else {
        Write-Host "Exception: $_" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Check if migration 006 was run (allows anonymous inserts)" -ForegroundColor White
    Write-Host "2. Check if migration 008 was run (if you removed ID column)" -ForegroundColor White
    Write-Host "3. Verify Supabase URL and key are correct" -ForegroundColor White
    Write-Host "4. Check Supabase logs for more details" -ForegroundColor White
    
    exit 1
}

Write-Host ""
Write-DebugLog "Diagnostic complete" "Cyan"




