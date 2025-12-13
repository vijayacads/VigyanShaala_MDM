# test-data-flow.ps1
# Tests the complete data flow from osquery to Supabase

Write-Host "=== Testing Data Flow to Supabase ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if scripts exist
Write-Host "Step 1: Checking scripts..." -ForegroundColor Yellow
$triggerScript = "C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent\trigger-osquery-queries.ps1"
$sendScript = "C:\Program Files\osquery\send-osquery-data.ps1"

if (-not (Test-Path $triggerScript)) {
    Write-Host "  [ERROR] trigger-osquery-queries.ps1 not found at: $triggerScript" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $sendScript)) {
    Write-Host "  [ERROR] send-osquery-data.ps1 not found at: $sendScript" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Scripts found" -ForegroundColor Green

# Step 2: Check environment variables
Write-Host "`nStep 2: Checking environment variables..." -ForegroundColor Yellow
$supabaseUrl = $env:SUPABASE_URL
$supabaseKey = $env:SUPABASE_ANON_KEY

if (-not $supabaseUrl) {
    Write-Host "  [WARN] SUPABASE_URL not set" -ForegroundColor Yellow
} else {
    Write-Host "  [OK] SUPABASE_URL: $($supabaseUrl.Substring(0, [Math]::Min(30, $supabaseUrl.Length)))..." -ForegroundColor Green
}

if (-not $supabaseKey) {
    Write-Host "  [WARN] SUPABASE_ANON_KEY not set" -ForegroundColor Yellow
} else {
    Write-Host "  [OK] SUPABASE_ANON_KEY: Set (hidden)" -ForegroundColor Green
}

# Step 3: Check log file
Write-Host "`nStep 3: Checking osquery log..." -ForegroundColor Yellow
$logPath = "C:\ProgramData\osquery\logs\osqueryd.results.log"
if (Test-Path $logPath) {
    $logSize = (Get-Item $logPath).Length
    Write-Host "  [OK] Log file exists ($logSize bytes)" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Log file not found: $logPath" -ForegroundColor Yellow
}

# Step 4: Run trigger script
Write-Host "`nStep 4: Running trigger script to generate data..." -ForegroundColor Yellow
Set-Location "C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent"
& $triggerScript

# Step 5: Check what data was generated
Write-Host "`nStep 5: Checking generated data..." -ForegroundColor Yellow
if (Test-Path $logPath) {
    $recentEntries = Get-Content $logPath -Tail 10 | Where-Object { $_ -match "device_health|battery_health|system_uptime" }
    if ($recentEntries) {
        Write-Host "  [OK] Found recent health data entries" -ForegroundColor Green
        $recentEntries | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    } else {
        Write-Host "  [WARN] No recent health data found in log" -ForegroundColor Yellow
    }
}

# Step 6: Run send script
Write-Host "`nStep 6: Sending data to Supabase..." -ForegroundColor Yellow
Set-Location "C:\Program Files\osquery"
& $sendScript

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Check Supabase dashboard for device_health data" -ForegroundColor White
Write-Host "  2. Check Supabase Edge Function logs for any errors" -ForegroundColor White
Write-Host "  3. Verify scheduled task is running: Get-ScheduledTask -TaskName 'VigyanShaala-MDM-SendOsqueryData'" -ForegroundColor White

