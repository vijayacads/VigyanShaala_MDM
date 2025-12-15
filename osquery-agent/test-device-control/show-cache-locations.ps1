# Show which cache locations get cleared

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cache Locations That Get Cleared" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$cacheLocations = @(
    @{
        Name = "User Temp Directory"
        Path = "$env:TEMP"
        Description = "User's temporary files"
        RequiresAdmin = $false
    },
    @{
        Name = "Windows Temp Directory"
        Path = "C:\Windows\Temp"
        Description = "System temporary files"
        RequiresAdmin = $true
    },
    @{
        Name = "Chrome Cache"
        Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
        Description = "Google Chrome browser cache"
        RequiresAdmin = $false
    },
    @{
        Name = "Edge Cache"
        Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
        Description = "Microsoft Edge browser cache"
        RequiresAdmin = $false
    }
)

Write-Host "The Clear Cache command clears the following locations:" -ForegroundColor Yellow
Write-Host ""

foreach ($location in $cacheLocations) {
    $exists = Test-Path $location.Path
    $status = if ($exists) { "EXISTS" } else { "NOT FOUND" }
    $color = if ($exists) { "Green" } else { "Gray" }
    
    Write-Host "1. $($location.Name)" -ForegroundColor White
    Write-Host "   Path: $($location.Path)" -ForegroundColor Gray
    Write-Host "   Status: $status" -ForegroundColor $color
    Write-Host "   Description: $($location.Description)" -ForegroundColor Gray
    if ($location.RequiresAdmin) {
        Write-Host "   ⚠ Requires Admin: Yes (may not clear if running as user)" -ForegroundColor Yellow
    } else {
        Write-Host "   ✓ Requires Admin: No" -ForegroundColor Green
    }
    
    if ($exists) {
        try {
            $itemCount = (Get-ChildItem $location.Path -ErrorAction SilentlyContinue | Measure-Object).Count
            $size = (Get-ChildItem $location.Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            $sizeMB = if ($size) { [math]::Round($size / 1MB, 2) } else { 0 }
            Write-Host "   Current: $itemCount items, $sizeMB MB" -ForegroundColor Cyan
        } catch {
            Write-Host "   Current: Unable to calculate size" -ForegroundColor Yellow
        }
    }
    Write-Host ""
}

Write-Host "Note:" -ForegroundColor Yellow
Write-Host "- User Temp: Always cleared (no admin needed)" -ForegroundColor White
Write-Host "- Windows Temp: Cleared if running as SYSTEM/Admin" -ForegroundColor White
Write-Host "- Browser Caches: Cleared if browser is not running" -ForegroundColor White
Write-Host "- Files in use may not be deleted" -ForegroundColor White
Write-Host ""

