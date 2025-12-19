# Production Deployment - WebSocket Rewrite

## Overview
This guide covers deploying the rewritten WebSocket implementation to production via Render.

## What Changed
- ✅ `realtime-command-listener.ps1` - Complete rewrite (protocol-correct, simple, robust)
- ✅ `test-realtime-subscription.ps1` - Updated to match new protocol
- ✅ `create-installer-package.ps1` - Fixed duplicate code

## Production Deployment Steps

### 1. Verify Files Are Committed
The rewritten files should already be in Git:
```powershell
git status
# Should show:
# - osquery-agent/realtime-command-listener.ps1 (modified)
# - osquery-agent/test-realtime-subscription.ps1 (modified)
# - osquery-agent/create-installer-package.ps1 (modified)
```

### 2. Create New Installer Package
Run the package creation script with your production Supabase credentials:

```powershell
cd osquery-agent
.\create-installer-package.ps1 -SupabaseUrl "https://YOUR_PROJECT.supabase.co" -SupabaseAnonKey "YOUR_ANON_KEY"
```

This will:
- Copy all files including the new `realtime-command-listener.ps1`
- Create `VigyanShaala-MDM-Installer.zip` with pre-configured credentials
- Verify all critical files are included

### 3. Copy Package to Dashboard
```powershell
# From repo root
if (-not (Test-Path "dashboard\public\downloads")) {
    New-Item -ItemType Directory -Path "dashboard\public\downloads" -Force
}
Copy-Item "osquery-agent\VigyanShaala-MDM-Installer.zip" "dashboard\public\downloads\" -Force
```

### 4. Commit and Push to Git
```powershell
git add .
git commit -m "Deploy: WebSocket rewrite - protocol-correct implementation"
git push
```

### 5. Render Auto-Deploys
- Render automatically detects the push
- Builds the dashboard
- Serves the new installer package at:
  `https://your-dashboard.onrender.com/downloads/VigyanShaala-MDM-Installer.zip`

## Verification Checklist

After deployment, verify:

- [ ] Installer package includes `realtime-command-listener.ps1` (new version)
- [ ] Installer package has correct Supabase credentials in `INSTALL.bat`
- [ ] Dashboard serves installer at `/downloads/VigyanShaala-MDM-Installer.zip`
- [ ] New devices install with updated WebSocket listener
- [ ] Existing devices can be updated (reinstall or update script)

## What's in the New Installer Package

The package includes:
- ✅ **realtime-command-listener.ps1** (rewritten - protocol-correct)
- ✅ **test-realtime-subscription.ps1** (updated - matches protocol)
- ✅ **execute-commands.ps1** (unchanged - business logic)
- ✅ **install-osquery.ps1** (creates scheduled task with credentials)
- ✅ All other agent scripts

## Key Improvements in New Version

1. **Protocol Correct**: Uses `phx_join` with `postgres_changes` in config
2. **Event Handling**: Checks `event = "postgres_changes"` then `payload.data.type = "INSERT"`
3. **Raw Logging**: Always logs raw frames at DEBUG level
4. **Simple Loop**: Fixed 60s timeout, no dynamic complexity
5. **Separation**: Clear transport/protocol/business logic separation

## Troubleshooting

**If installer doesn't include new files:**
- Check `create-installer-package.ps1` line 50 includes `realtime-command-listener.ps1`
- Verify file exists in `osquery-agent/` directory
- Re-run package creation script

**If Render doesn't serve new package:**
- Check `dashboard/public/downloads/` has the ZIP file
- Verify Git commit includes the ZIP file
- Check Render build logs for errors

**If devices don't receive commands:**
- Check Supabase Realtime is enabled for `device_commands` table
- Verify migration `028_enable_realtime_for_device_commands.sql` is applied
- Check device logs: `C:\WINDOWS\TEMP\VigyanShaala-RealtimeListener.log`
- Look for `RAW WS:` debug logs to see what events are received

## Notes

- The installer package is **pre-configured** with Supabase credentials
- Teachers download from dashboard and run `RUN-AS-ADMIN.bat`
- No manual configuration needed on device side
- All credentials come from installer package → scheduled task arguments

