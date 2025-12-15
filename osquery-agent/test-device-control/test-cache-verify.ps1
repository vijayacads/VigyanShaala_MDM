# Test Clear Cache and Verify it Works
# Creates test files, runs clear cache, then checks if they're deleted

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cache Clear Verification Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create test files in cache locations
Write-Host "Step 1: Creating test files in cache locations..." -ForegroundColor Yellow

$testFiles = @()
$testDirs = @(
    "$env:TEMP",
    "C:\Windows\Temp"
)

foreach ($dir in $testDirs) {
    if (Test-Path $dir) {
        $testFile = Join-Path $dir "MDM_TEST_CACHE_$(Get-Random).txt"
        try {
            "Test cache file created at $(Get-Date)" | Out-File $testFile -Force
            $testFiles += $testFile
            Write-Host "  Created: $testFile" -ForegroundColor Gray
        } catch {
            Write-Host "  Failed to create in $dir : $_" -ForegroundColor Red
        }
    }
}

Write-Host "  Created $($testFiles.Count) test files" -ForegroundColor Green

# Step 2: Verify files exist
Write-Host ""
Write-Host "Step 2: Verifying test files exist..." -ForegroundColor Yellow
$existingFiles = $testFiles | Where-Object { Test-Path $_ }
Write-Host "  Found $($existingFiles.Count) test files" -ForegroundColor $(if ($existingFiles.Count -eq $testFiles.Count) { "Green" } else { "Yellow" })

# Step 3: Run clear cache command
Write-Host ""
Write-Host "Step 3: Running clear cache command..." -ForegroundColor Yellow
.\test-cache.ps1

# Step 4: Wait a moment
Start-Sleep -Seconds 3

# Step 5: Check if files were deleted
Write-Host ""
Write-Host "Step 4: Checking if cache was cleared..." -ForegroundColor Yellow
$remainingFiles = $testFiles | Where-Object { Test-Path $_ }

if ($remainingFiles.Count -eq 0) {
    Write-Host "  SUCCESS! All test files were deleted" -ForegroundColor Green
    Write-Host "  Cache clear is working correctly" -ForegroundColor Green
} else {
    Write-Host "  WARNING: $($remainingFiles.Count) test files still exist:" -ForegroundColor Yellow
    foreach ($file in $remainingFiles) {
        Write-Host "    - $file" -ForegroundColor Gray
    }
    Write-Host "  Note: Some cache locations may require admin privileges" -ForegroundColor Gray
}

# Step 6: Check actual cache locations
Write-Host ""
Write-Host "Step 5: Checking actual cache locations..." -ForegroundColor Yellow

$cacheLocations = @(
    @{ Path = "$env:TEMP"; Name = "User Temp" },
    @{ Path = "C:\Windows\Temp"; Name = "Windows Temp" },
    @{ Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"; Name = "Chrome Cache" },
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"; Name = "Edge Cache" }
)

foreach ($location in $cacheLocations) {
    if (Test-Path $location.Path) {
        $itemCount = (Get-ChildItem $location.Path -ErrorAction SilentlyContinue | Measure-Object).Count
        $size = (Get-ChildItem $location.Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $sizeMB = if ($size) { [math]::Round($size / 1MB, 2) } else { 0 }
        Write-Host "  $($location.Name): $itemCount items, $sizeMB MB" -ForegroundColor Gray
    } else {
        Write-Host "  $($location.Name): Not found" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

