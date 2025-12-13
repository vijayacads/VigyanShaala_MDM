# Uninstaller Safety Verification

## What the Uninstaller Removes (ONLY MDM Components)

### ✅ 1. Hosts File - SAFE
**What we add:**
- Lines between `# VigyanShaala-MDM Blocklist Start` and `# VigyanShaala-MDM Blocklist End`
- Only our marked section

**What we remove:**
- ONLY the section between our markers
- All other hosts file entries (Windows default, other software) are preserved

**Verification:**
- Uses exact marker matching: `# VigyanShaala-MDM Blocklist Start` and `# VigyanShaala-MDM Blocklist End`
- Only removes lines between these markers
- Preserves all other content

### ✅ 2. Registry Policies - SAFE
**What we add:**
- `HKLM:\SOFTWARE\Policies\Google\Chrome\URLBlocklist` (only if we created it)
- `HKLM:\SOFTWARE\Policies\Microsoft\Edge\URLBlocklist` (only if we created it)
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer\DisableUserInstalls` (only if prevent-uninstall.ps1 was run)
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer\DisableMSI` (only if prevent-uninstall.ps1 was run)

**What we remove:**
- ONLY the specific values we added (URLBlocklist, DisableUserInstalls, DisableMSI)
- Does NOT delete the entire registry keys
- Does NOT affect other policies in those keys

**Verification:**
- Uses `Remove-ItemProperty` (removes only the property, not the key)
- Checks if property exists before removing
- Other software's policies in the same keys are preserved

### ✅ 3. Scheduled Tasks - SAFE
**What we add:**
- `VigyanShaala-MDM-SyncWebsiteBlocklist`
- `VigyanShaala-MDM-SyncSoftwareBlocklist`
- `VigyanShaala-MDM-SendOsqueryData`
- `VigyanShaala-MDM-CommandProcessor`

**What we remove:**
- ONLY these 4 specific tasks (all prefixed with "VigyanShaala-MDM-")
- All other Windows scheduled tasks are untouched

**Verification:**
- Uses exact task name matching
- Only removes tasks we created

### ✅ 4. Software Blocklist - SAFE
**What we do:**
- Software blocklist does NOT install anything
- It only MONITORS and UNINSTALLS software that matches patterns
- No persistent changes to the system

**What we remove:**
- The scheduled task that monitors for blocked software
- Once the task is removed, monitoring stops
- No cleanup needed because nothing was installed

**Verification:**
- Software blocklist script only removes software, doesn't install anything
- Removing the scheduled task stops all monitoring
- No registry entries or files to clean up

### ✅ 5. Files and Directories - SAFE
**What we add:**
- `C:\Program Files\osquery\` (entire directory)
- `C:\ProgramData\osquery\` (entire directory)
- Desktop shortcuts: `VigyanShaala Chat.lnk`

**What we remove:**
- ONLY these directories we created
- ONLY our desktop shortcuts
- Does NOT affect other programs or files

**Verification:**
- Uses exact path matching
- Only removes directories we installed
- Desktop shortcuts have our specific name

### ✅ 6. Environment Variables - SAFE
**What we add:**
- `SUPABASE_URL` (Machine-level)
- `SUPABASE_ANON_KEY` (Machine-level)
- `FLEET_SERVER_URL` (Machine-level, optional)

**What we remove:**
- ONLY these 3 specific variables
- All other environment variables are preserved

**Verification:**
- Uses exact variable name matching
- Only removes variables we set

### ✅ 7. Windows Service - SAFE
**What we add:**
- `osqueryd` service

**What we remove:**
- ONLY the osqueryd service
- All other Windows services are untouched

**Verification:**
- Uses exact service name matching
- Only removes service we installed

## Summary

**The uninstaller is SAFE and only removes:**
1. ✅ Hosts file entries between our markers (preserves all other entries)
2. ✅ Registry properties we added (preserves other policies in same keys)
3. ✅ Scheduled tasks with "VigyanShaala-MDM-" prefix (preserves all other tasks)
4. ✅ Files/directories we installed (preserves all other files)
5. ✅ Environment variables we set (preserves all other variables)
6. ✅ Windows service we installed (preserves all other services)

**The uninstaller does NOT:**
- ❌ Delete any files not created by our installer
- ❌ Remove registry keys (only removes properties we added)
- ❌ Affect other software or Windows components
- ❌ Delete user data or personal files
- ❌ Modify system files except hosts file (and only our section)

## Software Blocklist Cleanup

**Important:** The software blocklist feature does NOT install anything. It only:
- Monitors for blocked software via scheduled task
- Uninstalls software that matches blocklist patterns

**Cleanup:**
- Removing the scheduled task (`VigyanShaala-MDM-SyncSoftwareBlocklist`) stops all monitoring
- No additional cleanup needed because nothing was installed
- Software that was uninstalled by the blocklist will NOT be reinstalled (this is expected behavior)

