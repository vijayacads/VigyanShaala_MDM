# Check if device exists in database

param(
    [string]$SupabaseUrl = "https://ujmcjezpmyvpiasfrwhm.supabase.co",
    [string]$SupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqbWNqZXpwbXl2cGlhc2Zyd2htIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzOTQ2NzQsImV4cCI6MjA4MDk3MDY3NH0.LNeLEQs2K1AXyTG2vlCHyfRLpavFBSGgqjtwLoXdyMQ",
    [string]$DeviceHostname = $env:COMPUTERNAME
)

$DeviceHostname = $DeviceHostname.Trim().ToUpper()

Write-Host "Checking device: $DeviceHostname" -ForegroundColor Yellow

$headers = @{
    "apikey" = $SupabaseKey
    "Authorization" = "Bearer $SupabaseKey"
    "Content-Type" = "application/json"
}

try {
    $url = "$SupabaseUrl/rest/v1/devices?hostname=eq.$DeviceHostname&select=hostname,device_inventory_code,location_id"
    $device = Invoke-RestMethod -Uri $url -Method GET -Headers $headers
    
    if ($device -and $device.Count -gt 0) {
        Write-Host "Device found!" -ForegroundColor Green
        Write-Host "  Hostname: $($device[0].hostname)" -ForegroundColor Gray
        Write-Host "  Inventory Code: $($device[0].device_inventory_code)" -ForegroundColor Gray
        Write-Host "  Location ID: $($device[0].location_id)" -ForegroundColor Gray
    } else {
        Write-Host "Device NOT found in database!" -ForegroundColor Red
        Write-Host "You need to enroll the device first." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}




