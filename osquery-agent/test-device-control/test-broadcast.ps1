# Test Broadcast Message (Toast Notification)
param(
    [string]$Message = "Test broadcast message from MDM"
)

$SupabaseUrl = "https://ujmcjezpmyvpiasfrwhm.supabase.co"
$SupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqbWNqZXpwbXl2cGlhc2Zyd2htIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzOTQ2NzQsImV4cCI6MjA4MDk3MDY3NH0.LNeLEQs2K1AXyTG2vlCHyfRLpavFBSGgqjtwLoXdyMQ"
$DeviceHostname = $env:COMPUTERNAME.Trim().ToUpper()

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Broadcast Message Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Device: $DeviceHostname" -ForegroundColor Yellow
Write-Host "Message: $Message" -ForegroundColor Yellow
Write-Host ""

$headers = @{
    "apikey" = $SupabaseKey
    "Authorization" = "Bearer $SupabaseKey"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

# Check if device exists
Write-Host "Step 0: Checking if device exists..." -ForegroundColor Yellow
try {
    $checkDeviceUrl = "$SupabaseUrl/rest/v1/devices?hostname=eq.$DeviceHostname"
    $checkDeviceUrl = $checkDeviceUrl + [char]38 + 'select=hostname'
    $deviceCheck = Invoke-RestMethod -Uri $checkDeviceUrl -Method GET -Headers $headers
    
    if (-not $deviceCheck -or $deviceCheck.Count -eq 0) {
        Write-Host "  Device NOT found in database!" -ForegroundColor Red
        Write-Host "  You need to enroll this device first." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  Device found" -ForegroundColor Green
} catch {
    Write-Host "  Failed to check device: $_" -ForegroundColor Red
    exit 1
}

# Create broadcast message
Write-Host ""
Write-Host "Step 1: Creating broadcast message..." -ForegroundColor Yellow
$broadcastCommand = @{
    device_hostname = $DeviceHostname
    command_type = "broadcast_message"
    message = $Message
    status = "pending"
} | ConvertTo-Json

try {
    $createUrl = "$SupabaseUrl/rest/v1/device_commands"
    $response = Invoke-RestMethod -Uri $createUrl -Method POST -Headers $headers -Body $broadcastCommand
    $commandId = $response.id
    Write-Host "  Broadcast message created: $commandId" -ForegroundColor Green
} catch {
    Write-Host "  Failed: $_" -ForegroundColor Red
    exit 1
}

# Run command processor
Write-Host ""
Write-Host "Step 2: Processing broadcast message..." -ForegroundColor Yellow
$sourceScript = "C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent\execute-commands.ps1"
$installedScript = "C:\Program Files\osquery\execute-commands.ps1"

$commandScript = $null
if (Test-Path $sourceScript) {
    $commandScript = $sourceScript
} elseif (Test-Path $installedScript) {
    $commandScript = $installedScript
} else {
    Write-Host "  Script not found" -ForegroundColor Red
    exit 1
}

try {
    Write-Host "  Executing: $commandScript" -ForegroundColor Gray
    powershell.exe -ExecutionPolicy Bypass -Command "& '$commandScript' -SupabaseUrl '$SupabaseUrl' -SupabaseKey '$SupabaseKey'"
    Write-Host "  Script executed" -ForegroundColor Green
} catch {
    Write-Host "  Failed: $_" -ForegroundColor Red
}

# Check result
Write-Host ""
Write-Host "Step 3: Checking result..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

try {
    $checkUrl = "$SupabaseUrl/rest/v1/device_commands?id=eq.$commandId"
    $result = Invoke-RestMethod -Uri $checkUrl -Method GET -Headers $headers
    
    if ($result -and $result.Count -gt 0) {
        $cmd = $result[0]
        Write-Host "  Status: $($cmd.status)" -ForegroundColor $(if ($cmd.status -eq "dismissed") { "Green" } else { "Yellow" })
        
        if ($cmd.executed_at) {
            Write-Host "  Executed: $($cmd.executed_at)" -ForegroundColor Gray
        }
        
        if ($cmd.status -eq "dismissed") {
            Write-Host ""
            Write-Host "  SUCCESS! Broadcast message should have appeared as toast notification!" -ForegroundColor Green
            Write-Host "  Check your Windows notification center for the message." -ForegroundColor Gray
        } else {
            Write-Host ""
            Write-Host "  Still pending - scheduled task will process it" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  Failed to check status: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

