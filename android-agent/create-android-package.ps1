# Create Android Installer Package
# Packages the Android MDM installer files into a distributable ZIP

$packageDir = "VigyanShaala-MDM-Android"
$zipFile = "VigyanShaala-MDM-Android.zip"

# Clean up old package
if (Test-Path $zipFile) {
    Remove-Item $zipFile -Force
}

# Create package directory structure
$packagePath = Join-Path "android-agent" $packageDir
if (-not (Test-Path $packagePath)) {
    New-Item -ItemType Directory -Path $packagePath -Force | Out-Null
}

# Copy Android files
$filesToCopy = @(
    "README.md",
    "INSTALL_ANDROID.md"
)

foreach ($file in $filesToCopy) {
    $source = Join-Path "android-agent" $file
    if (Test-Path $source) {
        Copy-Item $source (Join-Path $packagePath $file) -Force
    }
}

# Create placeholder APK info file (actual APK would be built separately)
$apkInfo = @"
# VigyanShaala MDM Android App

## APK Information
- File: VigyanShaala-MDM-Android.apk
- Version: 1.0.0
- Minimum Android: 8.0 (API 26)
- Package: com.vigyanshaala.mdm

## Features
- Device enrollment
- Website blocking (via Private DNS/VPN)
- App blocking (via Device Admin)
- Automatic policy sync

## Installation
Install the APK file on Android devices.
The app will guide users through enrollment.

Note: This is a placeholder. The actual APK needs to be built using Android Studio.
"@

$apkInfo | Out-File (Join-Path $packagePath "APK_INFO.txt") -Encoding UTF8

# Create ZIP package
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    (Resolve-Path "android-agent\$packageDir"),
    (Join-Path (Get-Location) "android-agent\$zipFile")
)

Write-Host "Android package created: android-agent\$zipFile" -ForegroundColor Green

