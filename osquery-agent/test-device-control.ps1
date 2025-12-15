# Test Device Control Features Locally
# This creates a test command and checks if it gets executed

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_ANON_KEY,
    [string]$DeviceHostname = $env:COMPUTERNAME
)

if (-not $SupabaseUrl -or -not $SupabaseKey) {
    Write-Error "Supabase URL and Key must be provided"
    Write-Host "Usage: .\test-device-control.ps1 -SupabaseUrl 'https://xxx.supabase.co' -SupabaseKey 'your-key'" -ForegroundColor Yellow
    exit 1
}

# Normalize hostname
$DeviceHostname = $DeviceHostname.Trim().ToUpper()

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Device Control Test" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "Device Hostname: $DeviceHostname" -ForegroundColor Yellow
Write-Host "Supabase URL: $SupabaseUrl`n" -ForegroundColor Gray

$headers = @{
    "apikey" = $SupabaseKey
    "Authorization" = "Bearer $SupabaseKey"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

# Test 1: Create a test command
Write-Host "Test 1: Creating test command (clear_cache)..." -ForegroundColor Yellow

$testCommand = @{
    device_hostname = $DeviceHostname
    command_type = "clear_cache"
    status = "pending"
} | ConvertTo-Json

try {
    $createUrl = "$SupabaseUrl/rest/v1/device_commands"
    $response = Invoke-RestMethod -Uri $createUrl -Method POST -Headers $headers -Body $testCommand
    $commandId = $response.id
    
    Write-Host "  ✓ Command created: $commandId" -ForegroundColor Green
    Write-Host "  Command Type: clear_cache" -ForegroundColor Gray
    Write-Host "  Status: pending" -ForegroundColor Gray
} catch {
    Write-Host "  ✗ Failed to create command: $_" -ForegroundColor Red
    exit 1
}

# Test 2: Wait and check if command is picked up
Write-Host "`nTest 2: Waiting for scheduled task to process command..." -ForegroundColor Yellow
Write-Host "  (CommandProcessor runs every 1 minute, waiting 90 seconds...)" -ForegroundColor Gray

$maxWait = 90
$elapsed = 0
$commandProcessed = $false

while ($elapsed -lt $maxWait -and -not $commandProcessed) {
    Start-Sleep -Seconds 10
    $elapsed += 10
    
    try {
        $checkUrl = "$SupabaseUrl/rest/v1/device_commands?id=eq.$commandId"
        $checkUrl = $checkUrl + [char]38 + 'select=id,status,executed_at,error_message'
        $commandStatus = Invoke-RestMethod -Uri $checkUrl -Method GET -Headers $headers
        
        if ($commandStatus -and $commandStatus.Count -gt 0) {
            $status = $commandStatus[0].status
            
            if ($status -ne "pending") {
                $commandProcessed = $true
                Write-Host "  ✓ Command processed! Status: $status" -ForegroundColor Green
                
                if ($commandStatus[0].executed_at) {
                    Write-Host "  Executed At: $($commandStatus[0].executed_at)" -ForegroundColor Gray
                }
                
                if ($commandStatus[0].error_message) {
                    Write-Host "  Error: $($commandStatus[0].error_message)" -ForegroundColor Yellow
                }
                
                if ($status -eq "completed") {
                    Write-Host "  ✓ SUCCESS: Command executed successfully!" -ForegroundColor Green
                } elseif ($status -eq "failed") {
                    Write-Host "  ✗ FAILED: Command execution failed" -ForegroundColor Red
                }
            } else {
                $progress = "$elapsed of $maxWait seconds"
                Write-Host "  Still pending... ($progress)" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "  Error checking status: $_" -ForegroundColor Red
    }
}

if (-not $commandProcessed) {
    Write-Host "  ✗ Timeout: Command not processed within $maxWait seconds" -ForegroundColor Red
    Write-Host "  Check if scheduled task is running:" -ForegroundColor Yellow
    Write-Host "    Get-ScheduledTask -TaskName 'VigyanShaala-MDM-CommandProcessor' | Get-ScheduledTaskInfo" -ForegroundColor White
}

# Test 3: Check if we can query pending commands
Write-Host "`nTest 3: Checking if device can query its commands..." -ForegroundColor Yellow

try {
    $queryUrl = "$SupabaseUrl/rest/v1/device_commands?device_hostname=eq.$DeviceHostname"
    $queryUrl = $queryUrl + [char]38 + 'status=eq.pending' + [char]38 + 'limit=5'
    $pendingCommands = Invoke-RestMethod -Uri $queryUrl -Method GET -Headers $headers
    
    Write-Host "  ✓ Can query commands" -ForegroundColor Green
    Write-Host "  Pending commands: $($pendingCommands.Count)" -ForegroundColor Gray
} catch {
    Write-Host "  ✗ Cannot query commands: $_" -ForegroundColor Red
    Write-Host "  This might be an RLS policy issue" -ForegroundColor Yellow
}

# Test 4: Manually trigger the command processor (if script exists)
Write-Host "`nTest 4: Manually triggering command processor..." -ForegroundColor Yellow

$commandScript = "C:\Program Files\osquery\execute-commands.ps1"
if (Test-Path $commandScript) {
    try {
        Write-Host "  Running: $commandScript" -ForegroundColor Gray
        & $commandScript -SupabaseUrl $SupabaseUrl -SupabaseKey $SupabaseKey 2>&1 | Out-Null
        
        # Check status again
        Start-Sleep -Seconds 2
        $checkUrl = "$SupabaseUrl/rest/v1/device_commands?id=eq.$commandId"
        $checkUrl = $checkUrl + [char]38 + 'select=status,executed_at'
        $finalStatus = Invoke-RestMethod -Uri $checkUrl -Method GET -Headers $headers
        
        if ($finalStatus -and $finalStatus.Count -gt 0) {
            Write-Host "  Final Status: $($finalStatus[0].status)" -ForegroundColor $(if ($finalStatus[0].status -eq "completed") { "Green" } else { "Yellow" })
        }
    } catch {
        Write-Host "  ✗ Failed to run script: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  ✗ Script not found at $commandScript" -ForegroundColor Red
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Command ID: $commandId" -ForegroundColor Gray
Write-Host "Device: $DeviceHostname" -ForegroundColor Gray
Write-Host "`nTo check command status in dashboard:" -ForegroundColor Yellow
Write-Host "  Go to Device Control tab and check command history" -ForegroundColor White
Write-Host "`nTo test from Render dashboard:" -ForegroundColor Yellow
Write-Host "  1. Go to Device Control tab" -ForegroundColor White
Write-Host "  2. Select your device ($DeviceHostname)" -ForegroundColor White
Write-Host "  3. Click 'Clear Cache' or 'Buzz Device'" -ForegroundColor White
Write-Host "  4. Wait 1-2 minutes and check command history" -ForegroundColor White
Write-Host "`n"

