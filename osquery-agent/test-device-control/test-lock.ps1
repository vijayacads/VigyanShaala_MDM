# Test Lock Device Command
# WARNING: This will lock your screen!

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lock Device Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "WARNING: This will lock your screen immediately!" -ForegroundColor Red
Write-Host "Make sure you can unlock it (know your password/PIN)" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Type 'LOCK' to proceed (or anything else to cancel)"

if ($confirm -ne "LOCK") {
    Write-Host "Cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Locking device in 3 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 1
Write-Host "2..." -ForegroundColor Yellow
Start-Sleep -Seconds 1
Write-Host "1..." -ForegroundColor Yellow
Start-Sleep -Seconds 1

try {
    rundll32.exe user32.dll,LockWorkStation
    Write-Host "Lock command executed!" -ForegroundColor Green
    Write-Host "Your screen should be locked now." -ForegroundColor Gray
} catch {
    Write-Host "Failed to lock: $_" -ForegroundColor Red
}
