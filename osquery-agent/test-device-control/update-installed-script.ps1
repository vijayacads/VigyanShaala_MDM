# Update the installed execute-commands.ps1 with the fixed version
# Run as Administrator

$sourceFile = "C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent\execute-commands.ps1"
$targetFile = "C:\Program Files\osquery\execute-commands.ps1"

if (-not (Test-Path $sourceFile)) {
    Write-Host "Source file not found: $sourceFile" -ForegroundColor Red
    exit 1
}

Write-Host "Copying fixed script to installed location..." -ForegroundColor Yellow
try {
    Copy-Item $sourceFile $targetFile -Force
    Write-Host "Script updated successfully!" -ForegroundColor Green
} catch {
    Write-Host "Failed: $_" -ForegroundColor Red
    Write-Host "Make sure you're running as Administrator" -ForegroundColor Yellow
}




