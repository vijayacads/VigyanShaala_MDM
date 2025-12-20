# Simple Lock Test - No confirmation needed

Write-Host ""
Write-Host "Locking device in 2 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

try {
    rundll32.exe user32.dll,LockWorkStation
    Write-Host "Lock command executed!" -ForegroundColor Green
} catch {
    Write-Host "Failed: $_" -ForegroundColor Red
}




