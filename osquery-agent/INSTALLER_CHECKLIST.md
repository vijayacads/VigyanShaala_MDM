# Installer Package Checklist

## Files Included in Installer

### Core Installation Files
- ✅ `install-osquery.ps1` - Main installation script (includes all fixes)
- ✅ `osquery.conf` - osquery configuration (with correct queries)
- ✅ `enroll-device.ps1` - Device enrollment script

### Data Collection & Sending
- ✅ `send-osquery-data.ps1` - Sends data to Supabase (with debug output, 200 line reading)
- ✅ `trigger-osquery-queries.ps1` - Manual trigger script (for debugging)

### Blocklist Management
- ✅ `apply-website-blocklist.ps1` - Website blocklist application
- ✅ `apply-software-blocklist.ps1` - Software blocklist application
- ✅ `sync-blocklist-scheduled.ps1` - Scheduled website blocklist sync
- ✅ `sync-software-blocklist-scheduled.ps1` - Scheduled software blocklist sync

### Command Execution
- ✅ `execute-commands.ps1` - Executes commands from Supabase

### Utilities
- ✅ `chat-interface.ps1` - Chat interface script
- ✅ `VigyanShaala_Chat.bat` - Chat launcher
- ✅ `uninstall-osquery.ps1` - Complete uninstaller (with all cleanup)

## Installation Features (All Automated)

### ✅ Service Configuration
- osqueryd service auto-starts
- Runs as SYSTEM account
- Log directory created automatically

### ✅ Scheduled Tasks (All Automated)
- `VigyanShaala-MDM-SendOsqueryData` - Sends data every 5 minutes
- `VigyanShaala-MDM-SyncWebsiteBlocklist` - Syncs website blocklist hourly
- `VigyanShaala-MDM-SyncSoftwareBlocklist` - Syncs software blocklist hourly
- `VigyanShaala-MDM-CommandProcessor` - Processes commands every 5 minutes

All tasks:
- Run as SYSTEM account (regardless of logged-in user)
- Enabled automatically
- Configured with correct triggers and intervals

### ✅ Data Collection
- Device health (storage, uptime, crashes)
- Battery health (WMI fallback for osquery < 5.12.1)
- System info (heartbeat)
- WiFi networks (location tracking)
- Installed programs
- Browser history

### ✅ Configuration
- Environment variables set automatically
- osquery.conf copied to correct location
- All scripts copied to installation directory

## What's Fixed (No Manual Steps Needed)

1. ✅ Log directory creation
2. ✅ Service auto-start
3. ✅ Scheduled task configuration (SYSTEM account, enabled)
4. ✅ Script copying (send-osquery-data.ps1 included)
5. ✅ Correct osquery queries (device_health, system_uptime)
6. ✅ Battery data collection (WMI fallback)
7. ✅ Data sending (200 line reading, debug output)
8. ✅ Complete uninstaller

## Pre-Deployment Checklist

Before creating the installer package:

- [ ] Run `sync-installer-package.ps1` to sync all files
- [ ] Verify all files are in `VigyanShaala-MDM-Installer\osquery-agent\`
- [ ] Test `create-installer-package.ps1` with test credentials
- [ ] Verify Edge Function is deployed with latest code
- [ ] Verify database migrations are applied
- [ ] Test installer on clean Windows system

## Creating the Installer Package

```powershell
cd "C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent"

# Step 1: Sync all files
.\sync-installer-package.ps1

# Step 2: Create installer package
.\create-installer-package.ps1 -SupabaseUrl "https://xxx.supabase.co" -SupabaseAnonKey "xxx"
```

## Post-Installation Verification

After installation, verify:
1. osqueryd service is running
2. Scheduled tasks are enabled and running
3. Data appears in Supabase dashboard
4. Device health metrics are updating

## Notes

- Battery data will be `null` until osquery is upgraded to 5.12.1+ (or 5.20.0)
- All other data collection works immediately
- No manual configuration needed after installation




