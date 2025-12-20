# Test User Session Agent - Process pending notifications directly
# This runs the user-notify-agent once to process any pending notifications

$SupabaseUrl = "https://ujmcjezpmyvpiasfrwhm.supabase.co"
$SupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqbWNqZXpwbXl2cGlhc2Zyd2htIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzOTQ2NzQsImV4cCI6MjA4MDk3MDY3NH0.LNeLEQs2K1AXyTG2vlCHyfRLpavFBSGgqjtwLoXdyMQ"
$DeviceHostname = $env:COMPUTERNAME.Trim().ToUpper()

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "User Session Agent Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$sourceScript = "C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent\user-notify-agent.ps1"
$installedScript = "C:\Program Files\osquery\user-notify-agent.ps1"

$agentScript = $null
if (Test-Path $sourceScript) {
    $agentScript = $sourceScript
    Write-Host "Using source file" -ForegroundColor Gray
} elseif (Test-Path $installedScript) {
    $agentScript = $installedScript
    Write-Host "Using installed file" -ForegroundColor Gray
} else {
    Write-Host "User-notify-agent.ps1 not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Running user session agent to process pending notifications..." -ForegroundColor Yellow
Write-Host "This will check for pending buzz/toast notifications and execute them" -ForegroundColor Gray
Write-Host ""

# Run agent once (it will poll once and exit if we modify it, or we can just run it and let it process)
# Actually, the agent runs in a loop. Let's create a one-time version
powershell.exe -ExecutionPolicy Bypass -Command "& '$agentScript' -SupabaseUrl '$SupabaseUrl' -SupabaseKey '$SupabaseKey' -PollInterval 2" -NoExit

Write-Host ""
Write-Host "Agent started. It will poll every 2 seconds." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""




