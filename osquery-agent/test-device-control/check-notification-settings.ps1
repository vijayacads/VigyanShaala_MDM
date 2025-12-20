# Check Windows Notification Settings

Write-Host ""
Write-Host "Checking Windows Notification Settings..." -ForegroundColor Cyan
Write-Host ""

# Check Focus Assist
Write-Host "Focus Assist Status:" -ForegroundColor Yellow
try {
    $focusAssist = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\*windows.data.notifications.quiethours\Current" -ErrorAction SilentlyContinue
    if ($focusAssist) {
        Write-Host "  Focus Assist may be enabled" -ForegroundColor Yellow
    } else {
        Write-Host "  Focus Assist: Not blocking (or using default)" -ForegroundColor Green
    }
} catch {
    Write-Host "  Could not check Focus Assist" -ForegroundColor Gray
}

# Check notification settings via registry
Write-Host ""
Write-Host "Notification Settings:" -ForegroundColor Yellow
$notifPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
if (Test-Path $notifPath) {
    $settings = Get-ItemProperty $notifPath -ErrorAction SilentlyContinue
    Write-Host "  Notification settings found in registry" -ForegroundColor Gray
} else {
    Write-Host "  Using default notification settings" -ForegroundColor Gray
}

Write-Host ""
Write-Host "To enable toast notifications:" -ForegroundColor Yellow
Write-Host "  1. Open Windows Settings (Win+I)" -ForegroundColor White
Write-Host "  2. Go to System > Notifications & actions" -ForegroundColor White
Write-Host "  3. Make sure 'Get notifications from apps and other senders' is ON" -ForegroundColor White
Write-Host "  4. Check Focus Assist settings (may be blocking notifications)" -ForegroundColor White
Write-Host ""

# Try to show a simple notification to test
Write-Host "Testing simple notification..." -ForegroundColor Yellow
try {
    Add-Type -AssemblyName System.Windows.Forms
    $result = [System.Windows.Forms.MessageBox]::Show(
        "If you see this, notifications work. Toast notifications may be disabled in Windows Settings.",
        "Notification Test",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
}

Write-Host ""




