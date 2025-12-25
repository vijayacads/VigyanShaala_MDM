# Quick Tamper Detection Test - Run directly on device
# Copy and paste these commands into PowerShell (as Administrator)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Quick Tamper Detection Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check current status
Write-Host "1. CHECKING CURRENT STATUS..." -ForegroundColor Yellow
Write-Host ""

# Check scheduled tasks
Write-Host "Scheduled Tasks:" -ForegroundColor Cyan
Get-ScheduledTask -TaskName "VigyanShaala-MDM-*" | ForEach-Object {
    $info = Get-ScheduledTaskInfo -TaskName $_.TaskName
    $status = if ($_.State -eq "Running") { "✓ RUNNING" } else { "✗ $($_.State)" }
    $color = if ($_.State -eq "Running") { "Green" } else { "Red" }
    Write-Host "  $($_.TaskName): " -NoNewline
    Write-Host $status -ForegroundColor $color
}

Write-Host ""
Write-Host "Service:" -ForegroundColor Cyan
$service = Get-Service -Name "osqueryd" -ErrorAction SilentlyContinue
if ($service) {
    $status = if ($service.Status -eq "Running") { "✓ RUNNING" } else { "✗ $($service.Status)" }
    $color = if ($service.Status -eq "Running") { "Green" } else { "Red" }
    Write-Host "  osqueryd: " -NoNewline
    Write-Host $status -ForegroundColor $color
} else {
    Write-Host "  ✗ osqueryd service not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TEST OPTIONS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "To test tamper detection, run ONE of these:" -ForegroundColor White
Write-Host ""
Write-Host "TEST 1 - Stop Scheduled Task:" -ForegroundColor Cyan
Write-Host "  Stop-ScheduledTask -TaskName 'VigyanShaala-MDM-SendOsqueryData'" -ForegroundColor White
Write-Host "  # Wait 10-15 minutes, then check dashboard" -ForegroundColor Gray
Write-Host ""
Write-Host "TEST 2 - Stop Service:" -ForegroundColor Cyan
Write-Host "  Stop-Service osqueryd" -ForegroundColor White
Write-Host "  # Wait 10-15 minutes, then check dashboard" -ForegroundColor Gray
Write-Host ""
Write-Host "TEST 3 - Block Network:" -ForegroundColor Cyan
Write-Host "  New-NetFirewallRule -DisplayName 'MDM-Test-Block' -Direction Outbound -RemoteAddress 'thqinhphunrflwlshdmx.supabase.co' -Action Block" -ForegroundColor White
Write-Host "  # Wait 10-15 minutes, then check dashboard" -ForegroundColor Gray
Write-Host ""
Write-Host "TO RESTORE:" -ForegroundColor Yellow
Write-Host "  Start-ScheduledTask -TaskName 'VigyanShaala-MDM-SendOsqueryData'" -ForegroundColor White
Write-Host "  Start-Service osqueryd" -ForegroundColor White
Write-Host "  Remove-NetFirewallRule -DisplayName 'MDM-Test-Block' -ErrorAction SilentlyContinue" -ForegroundColor White
Write-Host ""

