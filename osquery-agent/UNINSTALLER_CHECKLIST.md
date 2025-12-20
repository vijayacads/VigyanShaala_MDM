# Uninstaller Cleanup Checklist

## What osquery does on the device:

1. **Windows Service**: Runs `osqueryd` service continuously to collect system data
2. **Data Collection**: Collects WiFi networks, installed programs, browser history, system info, device health, battery, uptime, crash events
3. **Logs Storage**: Stores logs in `C:\ProgramData\osquery\logs`
4. **Database Storage**: Stores query results in `C:\ProgramData\osquery\osquery.db`
5. **Pidfile**: Creates `C:\ProgramData\osquery\osqueryd.pidfile`

## What the installer package affects:

1. **Installation Directory**: Installs osquery and all scripts to `C:\Program Files\osquery\`
2. **Environment Variables**: Sets Machine-level variables (SUPABASE_URL, SUPABASE_ANON_KEY, FLEET_SERVER_URL)
3. **Windows Service**: Installs and starts `osqueryd` service
4. **Scheduled Tasks**: Creates 4 scheduled tasks:
   - VigyanShaala-MDM-SyncWebsiteBlocklist (every 30 min)
   - VigyanShaala-MDM-SyncSoftwareBlocklist (every hour)
   - VigyanShaala-MDM-SendOsqueryData (every 5 min)
   - VigyanShaala-MDM-CommandProcessor (every 30 seconds)
5. **Website Blocklist**: 
   - Adds entries to Windows hosts file (`C:\Windows\System32\drivers\etc\hosts`) between markers
   - Adds Chrome registry policy: `HKLM:\SOFTWARE\Policies\Google\Chrome\URLBlocklist`
   - Adds Edge registry policy: `HKLM:\SOFTWARE\Policies\Microsoft\Edge\URLBlocklist`
6. **Software Blocklist**: Monitors and uninstalls blocked software (no persistent changes, but scheduled task keeps checking)
7. **Desktop Shortcut**: Creates `VigyanShaala Chat.lnk` on user desktop
8. **MSI Installation**: Installs osquery via Windows Installer (MSI)

## What the uninstaller must remove:

1. ✅ Stop and remove osquery Windows service
2. ✅ Uninstall osquery MSI via Windows Installer
3. ✅ Remove all 4 scheduled tasks
4. ✅ Remove installation directory (`C:\Program Files\osquery\`)
5. ✅ Remove ProgramData directory (`C:\ProgramData\osquery\`)
6. ✅ Remove desktop shortcuts
7. ⚠️ Remove website blocklist from hosts file (MISSING)
8. ⚠️ Remove Chrome URLBlocklist registry policy (MISSING)
9. ⚠️ Remove Edge URLBlocklist registry policy (MISSING)
10. ⚠️ Flush DNS cache after removing hosts entries (MISSING)
11. ✅ Remove device from Supabase dashboard
12. ⚠️ Environment variables (optional - currently kept for reinstall)




