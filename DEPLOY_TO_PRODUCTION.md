# Deploy to Production - Brief Steps

## 1. Create Installer Package
```powershell
cd osquery-agent
.\create-installer-package.ps1 -SupabaseUrl "YOUR_SUPABASE_URL" -SupabaseAnonKey "YOUR_SUPABASE_KEY"
```

## 2. Copy to Dashboard
```powershell
# Create downloads directory if needed
New-Item -ItemType Directory -Path "dashboard\public\downloads" -Force

# Copy installer
Copy-Item "VigyanShaala-MDM-Installer.zip" "dashboard\public\downloads\" -Force
```

## 3. Deploy Edge Function
```bash
supabase functions deploy fetch-osquery-data
```

## 4. Commit & Push to Git
```powershell
cd ..
git add .
git commit -m "Complete automation: All fixes, installer package, Edge Function updates"
git push
```

## 5. Render Auto-Deploys
- Dashboard auto-deploys from git
- Installer available at: `https://your-dashboard.onrender.com/downloads/VigyanShaala-MDM-Installer.zip`

## Done!
Teachers download from Dashboard → Device Software Downloads tab.




