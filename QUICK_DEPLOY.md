# Quick Deploy to Production

## One Command Deploy

```powershell
.\deploy.ps1 -SupabaseUrl "https://xxx.supabase.co" -SupabaseAnonKey "xxx"
```

## Manual Steps

### 1. Create Installer & Copy to Dashboard
```powershell
cd osquery-agent
.\create-installer-package.ps1 -SupabaseUrl "YOUR_URL" -SupabaseAnonKey "YOUR_KEY"
cd ..
Copy-Item "osquery-agent\VigyanShaala-MDM-Installer.zip" "dashboard\public\downloads\" -Force
```

### 2. Deploy Edge Function
```bash
supabase functions deploy fetch-osquery-data
```

### 3. Git Commit & Push
```powershell
git add .
git commit -m "Deploy: Complete automation with installer package"
git push
```

### 4. Render Auto-Deploys
- Dashboard auto-deploys from git
- Installer available at: `/downloads/VigyanShaala-MDM-Installer.zip`

## Done!
Teachers download from Dashboard → Device Software Downloads.




