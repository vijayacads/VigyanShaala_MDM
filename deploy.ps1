# deploy.ps1 - Complete deployment script
param(
    [Parameter(Mandatory=$true)]
    [string]$SupabaseUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$SupabaseAnonKey
)

Write-Host "=== Deploying to Production ===" -ForegroundColor Cyan

# Step 1: Create installer package
Write-Host "`n1. Creating installer package..." -ForegroundColor Yellow
Set-Location "osquery-agent"
.\create-installer-package.ps1 -SupabaseUrl $SupabaseUrl -SupabaseAnonKey $SupabaseAnonKey
Set-Location ..

# Step 2: Copy to dashboard
Write-Host "`n2. Copying installer to dashboard..." -ForegroundColor Yellow
if (-not (Test-Path "dashboard\public\downloads")) {
    New-Item -ItemType Directory -Path "dashboard\public\downloads" -Force | Out-Null
}
Copy-Item "osquery-agent\VigyanShaala-MDM-Installer.zip" "dashboard\public\downloads\" -Force
Write-Host "  [OK] Installer copied to dashboard/public/downloads/" -ForegroundColor Green

# Step 3: Git status
Write-Host "`n3. Git status:" -ForegroundColor Yellow
git status --short

Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Deploy Edge Function:" -ForegroundColor White
Write-Host "   supabase functions deploy fetch-osquery-data" -ForegroundColor Gray
Write-Host "`n2. Commit and push:" -ForegroundColor White
Write-Host "   git add ." -ForegroundColor Gray
Write-Host "   git commit -m 'Deploy: Complete automation with installer package'" -ForegroundColor Gray
Write-Host "   git push" -ForegroundColor Gray
Write-Host "`n3. Render will auto-deploy dashboard" -ForegroundColor White
Write-Host "`n4. Installer available at:" -ForegroundColor White
Write-Host "   https://your-dashboard.onrender.com/downloads/VigyanShaala-MDM-Installer.zip" -ForegroundColor Gray




