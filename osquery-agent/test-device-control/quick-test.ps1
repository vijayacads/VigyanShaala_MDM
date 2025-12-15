# Quick Local Test for Device Control
param(
    [string]$SupabaseUrl = "https://ujmcjezpmyvpiasfrwhm.supabase.co",
    [string]$SupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqbWNqZXpwbXl2cGlhc2Zyd2htIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzOTQ2NzQsImV4cCI6MjA4MDk3MDY3NH0.LNeLEQs2K1AXyTG2vlCHyfRLpavFBSGgqjtwLoXdyMQ",
    [string]$DeviceHostname = $env:COMPUTERNAME,
    [string]$CommandType = "clear_cache"
)

$DeviceHostname = $DeviceHostname.Trim().ToUpper()

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Quick Device Control Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Device: $DeviceHostname" -ForegroundColor Yellow
Write-Host "Command: $CommandType" -ForegroundColor Yellow
Write-Host ""

$headers = @{
    "apikey" = $SupabaseKey
    "Authorization" = "Bearer $SupabaseKey"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

# Step 0: Check if device exists
Write-Host "Step 0: Checking if device exists..." -ForegroundColor Yellow
try {
    $checkDeviceUrl = "$SupabaseUrl/rest/v1/devices?hostname=eq.$DeviceHostname"
    $checkDeviceUrl = $checkDeviceUrl + [char]38 + 'select=hostname'
    $deviceCheck = Invoke-RestMethod -Uri $checkDeviceUrl -Method GET -Headers $headers
    
    if (-not $deviceCheck -or $deviceCheck.Count -eq 0) {
        Write-Host "  Device NOT found in database!" -ForegroundColor Red
        Write-Host "  You need to enroll this device first." -ForegroundColor Yellow
        Write-Host "  Run: enroll-device.ps1 or install the MDM agent" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  Device found" -ForegroundColor Green
} catch {
    Write-Host "  Failed to check device: $_" -ForegroundColor Red
    exit 1
}

# Step 1: Create command
Write-Host ""
Write-Host "Step 1: Creating command..." -ForegroundColor Yellow
$testCommand = @{
    device_hostname = $DeviceHostname
    command_type = $CommandType
    status = "pending"
} | ConvertTo-Json

try {
    $createUrl = "$SupabaseUrl/rest/v1/device_commands"
    $response = Invoke-RestMethod -Uri $createUrl -Method POST -Headers $headers -Body $testCommand
    $commandId = $response.id
    Write-Host "  Command created: $commandId" -ForegroundColor Green
} catch {
    Write-Host "  Failed: $_" -ForegroundColor Red
    if ($_.Exception.Response.StatusCode -eq 409) {
        Write-Host "  Conflict error - device might not exist or constraint violation" -ForegroundColor Yellow
    }
    exit 1
}

# Step 2: Immediately run the command processor
Write-Host ""
Write-Host "Step 2: Running command processor..." -ForegroundColor Yellow
# Try source file first (for testing), then fall back to installed
$sourceScript = "C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent\execute-commands.ps1"
$installedScript = "C:\Program Files\osquery\execute-commands.ps1"

$commandScript = $null
if (Test-Path $sourceScript) {
    $commandScript = $sourceScript
    Write-Host "  Using source file (for testing)" -ForegroundColor Gray
} elseif (Test-Path $installedScript) {
    $commandScript = $installedScript
    Write-Host "  Using installed file" -ForegroundColor Gray
} else {
    Write-Host "  Script not found at either location" -ForegroundColor Red
    Write-Host "  Make sure MDM agent is installed" -ForegroundColor Yellow
    exit 1
}

try {
    Write-Host "  Executing: $commandScript" -ForegroundColor Gray
    powershell.exe -ExecutionPolicy Bypass -Command "& '$commandScript' -SupabaseUrl '$SupabaseUrl' -SupabaseKey '$SupabaseKey'"
    Write-Host "  Script executed" -ForegroundColor Green
} catch {
    Write-Host "  Failed: $_" -ForegroundColor Red
}

# Step 3: Check result
Write-Host ""
Write-Host "Step 3: Checking result..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

try {
    $checkUrl = "$SupabaseUrl/rest/v1/device_commands?id=eq.$commandId"
    $result = Invoke-RestMethod -Uri $checkUrl -Method GET -Headers $headers
    
    if ($result -and $result.Count -gt 0) {
        $cmd = $result[0]
        $statusColor = "Yellow"
        if ($cmd.status -eq "completed") { $statusColor = "Green" }
        if ($cmd.status -eq "failed") { $statusColor = "Red" }
        
        Write-Host "  Status: $($cmd.status)" -ForegroundColor $statusColor
        
        if ($cmd.executed_at) {
            Write-Host "  Executed: $($cmd.executed_at)" -ForegroundColor Gray
        }
        
        if ($cmd.error_message) {
            Write-Host "  Error: $($cmd.error_message)" -ForegroundColor Red
        }
        
        if ($cmd.status -eq "completed") {
            Write-Host ""
            Write-Host "  SUCCESS! Command executed successfully!" -ForegroundColor Green
        } elseif ($cmd.status -eq "failed") {
            Write-Host ""
            Write-Host "  FAILED! Check error message above" -ForegroundColor Red
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
