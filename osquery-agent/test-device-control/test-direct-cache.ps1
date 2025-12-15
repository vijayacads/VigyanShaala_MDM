# Direct Cache Clear Test - Clears cache immediately without queueing
# This bypasses the command queue and clears cache directly

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Direct Cache Clear Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Clearing cache now..." -ForegroundColor Yellow
Write-Host ""

try {
    # Clear temp files
    Write-Host "Clearing user temp: $env:TEMP" -ForegroundColor Gray
    $userTempCount = (Get-ChildItem "$env:TEMP" -ErrorAction SilentlyContinue | Measure-Object).Count
    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  Cleared $userTempCount items" -ForegroundColor Green
    
    # Clear browser caches
    $chromeCache = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
    if (Test-Path $chromeCache) {
        Write-Host "Clearing Chrome cache: $chromeCache" -ForegroundColor Gray
        $chromeCount = (Get-ChildItem $chromeCache -ErrorAction SilentlyContinue | Measure-Object).Count
        Remove-Item "$chromeCache\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Cleared $chromeCount items" -ForegroundColor Green
    } else {
        Write-Host "Chrome cache not found" -ForegroundColor Gray
    }
    
    $edgeCache = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
    if (Test-Path $edgeCache) {
        Write-Host "Clearing Edge cache: $edgeCache" -ForegroundColor Gray
        $edgeCount = (Get-ChildItem $edgeCache -ErrorAction SilentlyContinue | Measure-Object).Count
        Remove-Item "$edgeCache\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Cleared $edgeCount items" -ForegroundColor Green
    } else {
        Write-Host "Edge cache not found" -ForegroundColor Gray
    }
    
    # Clear Windows temp (may require admin)
    Write-Host "Clearing Windows temp: C:\Windows\Temp" -ForegroundColor Gray
    try {
        $winTempCount = (Get-ChildItem "C:\Windows\Temp" -ErrorAction SilentlyContinue | Measure-Object).Count
        Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Cleared $winTempCount items" -ForegroundColor Green
    } catch {
        Write-Host "  Failed (requires admin): $_" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Cache cleared successfully!" -ForegroundColor Green
} catch {
    Write-Host "Failed to clear cache: $_" -ForegroundColor Red
}

Write-Host ""

