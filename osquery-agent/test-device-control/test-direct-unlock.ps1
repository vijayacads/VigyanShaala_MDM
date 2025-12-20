# Direct Unlock Test - Unlocks screen immediately
# Note: This only works if screen is already locked and user is authenticated

Write-Host ""
Write-Host "Unlocking device..." -ForegroundColor Yellow

try {
    # Unlock command (only works if already locked and authenticated)
    rundll32.exe user32.dll,LockWorkStation
    Start-Sleep -Milliseconds 100
    # Send Enter key to unlock (if password was already entered)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    Write-Host "Unlock command executed" -ForegroundColor Green
} catch {
    Write-Host "Failed: $_" -ForegroundColor Red
}




