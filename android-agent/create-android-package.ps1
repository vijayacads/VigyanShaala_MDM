# Create Android APK Package for Distribution
# This script packages the built APK into a ZIP file for download

param(
    [Parameter(Mandatory=$false)]
    [string]$ApkPath = "android-agent\android-app\app\build\outputs\apk\debug\app-debug.apk",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "dashboard\public\downloads"
)

Write-Host "Creating Android APK Package..." -ForegroundColor Cyan

# Check if APK exists
if (-not (Test-Path $ApkPath)) {
    Write-Host "ERROR: APK file not found at: $ApkPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please build the APK first using one of these methods:" -ForegroundColor Yellow
    Write-Host "1. Open android-agent/android-app/ in Android Studio and build" -ForegroundColor White
    Write-Host "2. Run: cd android-agent/android-app && gradlew assembleDebug" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "Created output directory: $OutputDir" -ForegroundColor Green
}

# APK filename
$apkFileName = "VigyanShaala-MDM-Android.apk"
$zipFileName = "VigyanShaala-MDM-Android.zip"
$apkDestPath = Join-Path $OutputDir $apkFileName
$zipDestPath = Join-Path $OutputDir $zipFileName

# Copy APK to downloads folder
Write-Host "Copying APK to downloads folder..." -ForegroundColor Cyan
Copy-Item -Path $ApkPath -Destination $apkDestPath -Force
Write-Host "APK copied to: $apkDestPath" -ForegroundColor Green

# Create ZIP package
Write-Host "Creating ZIP package..." -ForegroundColor Cyan
$tempZip = Join-Path $env:TEMP "VigyanShaala-MDM-Android-temp.zip"
if (Test-Path $tempZip) {
    Remove-Item $tempZip -Force
}

# Create ZIP with APK
Compress-Archive -Path $apkDestPath -DestinationPath $tempZip -Force
Move-Item -Path $tempZip -Destination $zipDestPath -Force

Write-Host "ZIP package created: $zipDestPath" -ForegroundColor Green
Write-Host ""
Write-Host "Package ready for download!" -ForegroundColor Green
Write-Host "APK: $apkDestPath" -ForegroundColor White
Write-Host "ZIP: $zipDestPath" -ForegroundColor White
