# Script to create installer package for teachers
# This packages everything needed for deployment

param(
    [Parameter(Mandatory=$true)]
    [string]$SupabaseUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$SupabaseAnonKey,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\VigyanShaala-MDM-Installer"
)

Write-Host "Creating installer package..." -ForegroundColor Cyan

# Get script directory and resolve paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputPath = Join-Path $scriptDir (Split-Path -Leaf $OutputPath)
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

Write-Host "Script directory: $scriptDir" -ForegroundColor Gray
Write-Host "Output path: $OutputPath" -ForegroundColor Gray

# Create output directory (ensure it's clean)
if (Test-Path $OutputPath) {
    Remove-Item $OutputPath -Recurse -Force
}
$null = New-Item -ItemType Directory -Path $OutputPath -Force
$null = New-Item -ItemType Directory -Path "$OutputPath\osquery-agent" -Force

# Verify directories were created
if (-not (Test-Path "$OutputPath\osquery-agent")) {
    throw "Failed to create output directory: $OutputPath\osquery-agent"
}

# Copy required files
$filesToCopy = @(
    "install-osquery.ps1",
    "enroll-device.ps1",
    "osquery.conf",
    "apply-website-blocklist.ps1",
    "apply-software-blocklist.ps1",
    "sync-blocklist-scheduled.ps1",
    "sync-software-blocklist-scheduled.ps1",
    "send-osquery-data.ps1",
    "trigger-osquery-queries.ps1",  # For debugging/manual testing
    "get-battery-wmi.ps1",  # WMI-based battery data collection
    "execute-commands.ps1",
    "user-notify-agent.ps1",  # User-session notification agent for buzz/toast
    "chat-interface.ps1",
    "VigyanShaala_Chat.bat",
    "uninstall-osquery.ps1"
)

$copiedCount = 0
$missingCount = 0

foreach ($file in $filesToCopy) {
    $sourcePath = Join-Path $scriptDir $file
    $destPath = Join-Path "$OutputPath\osquery-agent" $file
    
    if (Test-Path $sourcePath) {
        try {
            # For PowerShell files, preserve UTF-8 BOM encoding (needed for emojis)
            if ($file -like "*.ps1") {
                $content = Get-Content $sourcePath -Raw -Encoding UTF8
                $utf8WithBom = New-Object System.Text.UTF8Encoding $true
                [System.IO.File]::WriteAllText($destPath, $content, $utf8WithBom)
                Write-Host "Copied: $file (with UTF-8 BOM)" -ForegroundColor Green
            } else {
                Copy-Item $sourcePath $destPath -Force
                Write-Host "Copied: $file" -ForegroundColor Green
            }
            $copiedCount++
            
            # Verify file was copied
            if (-not (Test-Path $destPath)) {
                throw "File copy verification failed: $file"
            }
        } catch {
            Write-Error "Failed to copy $file : $_"
            $missingCount++
        }
    } else {
        Write-Warning "File not found: $file (expected at: $sourcePath)"
        $missingCount++
    }
}

Write-Host ""
Write-Host "Copy Summary: $copiedCount files copied, $missingCount files missing" -ForegroundColor Cyan

# Copy Logo.png if it exists (for chat interface and desktop shortcut)
$logoPath = Join-Path $scriptDir "Logo.png"
$dashboardLogoPath = Join-Path (Split-Path -Parent $scriptDir) "dashboard\public\Logo.png"
if (Test-Path $logoPath) {
    Copy-Item $logoPath "$OutputPath\osquery-agent\" -Force
    Write-Host "Copied: Logo.png" -ForegroundColor Green
} elseif (Test-Path $dashboardLogoPath) {
    Copy-Item $dashboardLogoPath "$OutputPath\osquery-agent\" -Force
    Write-Host "Copied: Logo.png (from dashboard)" -ForegroundColor Green
}

# Create configured INSTALL.bat
$installBatContent = @"
@echo off
REM VigyanShaala MDM Installer - Pre-configured
echo ========================================
echo VigyanShaala MDM - Device Installer
echo ========================================
echo.

set SUPABASE_URL=$SupabaseUrl
set SUPABASE_KEY=$SupabaseAnonKey

powershell.exe -ExecutionPolicy Bypass -Command "& '%~dp0INSTALL.ps1' -SupabaseUrl '%SUPABASE_URL%' -SupabaseKey '%SUPABASE_KEY%'"

pause
"@

Set-Content -Path "$OutputPath\INSTALL.bat" -Value $installBatContent
Write-Host "Created: INSTALL.bat (pre-configured)" -ForegroundColor Green

# Copy INSTALL.ps1
$installPs1Path = Join-Path $scriptDir "INSTALL.ps1"
if (Test-Path $installPs1Path) {
    Copy-Item $installPs1Path "$OutputPath\" -Force
    Write-Host "Copied: INSTALL.ps1" -ForegroundColor Green
} else {
    Write-Warning "INSTALL.ps1 not found at: $installPs1Path"
}

# Copy README
$readmePath = Join-Path $scriptDir "README-TEACHER.md"
if (Test-Path $readmePath) {
    Copy-Item $readmePath "$OutputPath\README.txt" -Force
    Write-Host "Copied: README.txt" -ForegroundColor Green
} else {
    Write-Warning "README-TEACHER.md not found at: $readmePath"
}

# Create a simple launcher that checks admin
$launcherContent = @"
@echo off
REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running installer with Administrator privileges...
    echo.
    call INSTALL.bat
) else (
    echo ERROR: Administrator privileges required!
    echo.
    echo Please right-click on this file and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)
"@

Set-Content -Path "$OutputPath\RUN-AS-ADMIN.bat" -Value $launcherContent
Write-Host "Created: RUN-AS-ADMIN.bat" -ForegroundColor Green

# Create UNINSTALL.bat
$uninstallBatContent = @"
@echo off
REM Uninstaller for VigyanShaala MDM osquery Agent
REM Run as Administrator

echo ========================================
echo VigyanShaala MDM - Uninstaller
echo ========================================
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running uninstaller with Administrator privileges...
    echo.
    
    REM Try to run from installed location first
    if exist "C:\Program Files\osquery\uninstall-osquery.ps1" (
        powershell.exe -ExecutionPolicy Bypass -File "C:\Program Files\osquery\uninstall-osquery.ps1" -RemoveFromSupabase
    ) else if exist "%~dp0osquery-agent\uninstall-osquery.ps1" (
        REM If not installed, try from installer package
        powershell.exe -ExecutionPolicy Bypass -File "%~dp0osquery-agent\uninstall-osquery.ps1" -RemoveFromSupabase
    ) else (
        echo ERROR: Uninstall script not found!
        echo.
        echo Please ensure the MDM agent is installed, or run this from the installer package.
        echo.
        pause
        exit /b 1
    )
) else (
    echo.
    echo ERROR: Administrator privileges required!
    echo.
    echo Please right-click on this file and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)
pause
"@

Set-Content -Path "$OutputPath\UNINSTALL.bat" -Value $uninstallBatContent
Write-Host "Created: UNINSTALL.bat" -ForegroundColor Green

# Create ZIP file
$zipPath = "$OutputPath.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Write-Host ""
Write-Host "Verifying package contents..." -ForegroundColor Cyan
$fileCount = (Get-ChildItem -Path $OutputPath -Recurse -File).Count
Write-Host "Total files in package: $fileCount" -ForegroundColor Yellow

if ($fileCount -eq 0) {
    throw "ERROR: Package is empty! No files were copied."
}

# Verify critical files exist
$criticalFiles = @(
    "$OutputPath\INSTALL.bat",
    "$OutputPath\INSTALL.ps1",
    "$OutputPath\RUN-AS-ADMIN.bat",
    "$OutputPath\osquery-agent\enroll-device.ps1",
    "$OutputPath\osquery-agent\install-osquery.ps1"
)

$missingCritical = @()
foreach ($criticalFile in $criticalFiles) {
    if (-not (Test-Path $criticalFile)) {
        $missingCritical += $criticalFile
    }
}

if ($missingCritical.Count -gt 0) {
    Write-Error "ERROR: Missing critical files:"
    $missingCritical | ForEach-Object { Write-Error "  - $_" }
    throw "Package creation failed: Critical files missing"
}

Write-Host "All critical files present!" -ForegroundColor Green
Write-Host ""
Write-Host "Creating ZIP package..." -ForegroundColor Cyan

# Remove existing ZIP if it exists
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($OutputPath, $zipPath)

# Verify ZIP was created and has content
if (-not (Test-Path $zipPath)) {
    throw "ERROR: ZIP file was not created!"
}

$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
$zipEntryCount = $zip.Entries.Count
$zip.Dispose()

if ($zipEntryCount -eq 0) {
    throw "ERROR: ZIP file is empty!"
}

Write-Host "ZIP created successfully with $zipEntryCount entries" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Package created successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Package location: $zipPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "To distribute:" -ForegroundColor Yellow
Write-Host "1. Share the ZIP file with teachers" -ForegroundColor White
Write-Host "2. Teachers extract and run RUN-AS-ADMIN.bat" -ForegroundColor White
Write-Host "3. If osquery MSI is needed, it will auto-download" -ForegroundColor White
Write-Host ""

