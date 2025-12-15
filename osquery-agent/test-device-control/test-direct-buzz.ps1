# Direct Buzz Test - Plays sound immediately without queueing
# This bypasses the user-session agent and plays sound directly

param(
    [int]$Duration = 5
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Direct Buzz Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Duration: $Duration seconds" -ForegroundColor Yellow
Write-Host "Playing buzzer sound now..." -ForegroundColor Yellow
Write-Host ""

try {
    $endTime = (Get-Date).AddSeconds($Duration)
    $beepCount = 0
    while ((Get-Date) -lt $endTime) {
        [console]::beep(800, 500)
        Start-Sleep -Milliseconds 500
        $beepCount++
    }
    Write-Host "Buzzer played for $Duration seconds ($beepCount beeps)" -ForegroundColor Green
} catch {
    Write-Host "Failed to play buzzer: $_" -ForegroundColor Red
}

Write-Host ""

