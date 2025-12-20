# Test script to verify device is receiving Realtime events
# Run this on the device to check if INSERT events are being received

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_ANON_KEY
)

if (-not $SupabaseUrl -or -not $SupabaseKey) {
    Write-Host "Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set" -ForegroundColor Red
    exit 1
}

Write-Host "=== REALTIME RECEIVE TEST ===" -ForegroundColor Cyan
Write-Host "Device: $env:COMPUTERNAME" -ForegroundColor Yellow
Write-Host "Supabase: $SupabaseUrl" -ForegroundColor Yellow
Write-Host ""

# Check if listener is running
Write-Host "1. Checking if listener task is running..." -ForegroundColor White
$task = Get-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener" -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "   Task State: $($task.State)" -ForegroundColor $(if ($task.State -eq "Running") { "Green" } else { "Yellow" })
    $taskInfo = Get-ScheduledTaskInfo -TaskName "VigyanShaala-MDM-RealtimeListener"
    Write-Host "   Last Run: $($taskInfo.LastRunTime)" -ForegroundColor Gray
    Write-Host "   Last Result: $($taskInfo.LastTaskResult)" -ForegroundColor Gray
} else {
    Write-Host "   Task not found!" -ForegroundColor Red
}
Write-Host ""

# Check recent logs for connection
Write-Host "2. Checking connection status in logs..." -ForegroundColor White
$logFile = "$env:TEMP\VigyanShaala-RealtimeListener.log"
if (Test-Path $logFile) {
    $recentLogs = Get-Content $logFile -Tail 30
    $connectionLogs = $recentLogs | Select-String "Connecting to|WebSocket connected|Subscription confirmed"
    if ($connectionLogs) {
        Write-Host "   Recent connection logs:" -ForegroundColor Gray
        $connectionLogs | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    } else {
        Write-Host "   No connection logs found" -ForegroundColor Yellow
    }
    
    # Check for INSERT events
    $insertLogs = $recentLogs | Select-String "INSERT|postgres_changes|Processing INSERT"
    if ($insertLogs) {
        Write-Host "   INSERT events found:" -ForegroundColor Green
        $insertLogs | ForEach-Object { Write-Host "   $_" -ForegroundColor Green }
    } else {
        Write-Host "   No INSERT events in logs" -ForegroundColor Yellow
    }
} else {
    Write-Host "   Log file not found: $logFile" -ForegroundColor Red
}
Write-Host ""

# Check pending commands in database
Write-Host "3. Checking pending commands in database..." -ForegroundColor White
try {
    $headers = @{
        "apikey" = $SupabaseKey
        "Authorization" = "Bearer $SupabaseKey"
    }
    $deviceHostname = $env:COMPUTERNAME
    $pendingUrl = "$SupabaseUrl/rest/v1/device_commands?device_hostname=eq.$deviceHostname&status=eq.pending&order=created_at.desc&limit=5"
    $pendingCommands = Invoke-RestMethod -Uri $pendingUrl -Method GET -Headers $headers -ErrorAction Stop
    
    if ($pendingCommands.Count -gt 0) {
        Write-Host "   Found $($pendingCommands.Count) pending command(s):" -ForegroundColor Yellow
        $pendingCommands | ForEach-Object {
            Write-Host "   - $($_.command_type) (ID: $($_.id), Created: $($_.created_at))" -ForegroundColor Gray
        }
        Write-Host "   These should trigger INSERT events!" -ForegroundColor Yellow
    } else {
        Write-Host "   No pending commands found" -ForegroundColor Gray
    }
} catch {
    Write-Host "   Error checking commands: $_" -ForegroundColor Red
}
Write-Host ""

# Check if Realtime is enabled (requires SQL query - manual check)
Write-Host "4. Realtime Configuration Check:" -ForegroundColor White
Write-Host "   Run this SQL in Supabase SQL Editor:" -ForegroundColor Yellow
Write-Host "   SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'device_commands';" -ForegroundColor Gray
Write-Host "   Expected: Should return 1 row" -ForegroundColor Gray
Write-Host ""

# Summary
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "If INSERT events are NOT in logs but commands exist in DB:" -ForegroundColor White
Write-Host "  → Realtime may not be enabled for device_commands table" -ForegroundColor Yellow
Write-Host "  → Run CHECK_REALTIME_SETUP.sql in Supabase SQL Editor" -ForegroundColor Yellow
Write-Host ""
Write-Host "If task is not running:" -ForegroundColor White
Write-Host "  → Start-ScheduledTask -TaskName 'VigyanShaala-MDM-RealtimeListener'" -ForegroundColor Yellow
Write-Host ""


