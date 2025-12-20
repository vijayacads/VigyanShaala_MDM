# Issues and Fixes Summary

## Problems Faced and Solutions

### 1. **Device Enrollment RLS Violation**
**Problem:** Device registration failed with "new row violates row-level security policy"
**Root Cause:** RLS policies blocking anonymous inserts
**Solution:** Created `SECURITY DEFINER` function `enroll_device()` that bypasses RLS
**Files:** `supabase/migrations/027_fix_device_enrollment_with_security_definer.sql`, `osquery-agent/enroll-device.ps1`

### 2. **Empty Installer Package**
**Problem:** ZIP installer was empty or missing files
**Root Cause:** Path resolution issues in `create-installer-package.ps1`
**Solution:** Fixed file copying logic, added verification steps
**Files:** `osquery-agent/create-installer-package.ps1`

### 3. **WebSocket Connection Issues**
**Problem:** Connection closing every ~30 seconds, no INSERT events received
**Root Causes:**
- Realtime not enabled for `device_commands` table
- Subscription sent separately instead of in join message
- Heartbeat timeout issues
**Solutions:**
- Added `ALTER PUBLICATION supabase_realtime ADD TABLE device_commands;`
- Changed subscription to be included in `phx_join` config
- Fixed heartbeat timing
**Files:** `supabase/migrations/028_enable_realtime_for_device_commands.sql`, `osquery-agent/realtime-command-listener.ps1`

### 4. **Function Import Errors**
**Problem:** `param : The term 'param' is not recognized` when importing functions
**Root Cause:** Comments and `param()` block included in dynamic import
**Solution:** Line-by-line parsing to extract only function definitions
**Files:** `osquery-agent/realtime-command-listener.ps1`

### 5. **Buzz Command Not Working**
**Problem:** Buzz command received but no sound
**Root Cause:** `[console]::beep()` doesn't work when run as SYSTEM (no audio access)
**Solution:** Changed `Buzz-Device` to queue notification to `user_notifications` table, processed by user-session agent
**Files:** `osquery-agent/execute-commands.ps1`

### 6. **Device Connecting to Wrong Supabase Project**
**Problem:** After migrating to new Supabase, device still connecting to old project
**Root Causes:**
- Scheduled task arguments had old credentials
- System environment variables had old values
- Script defaults to env vars if parameters not provided
**Solutions:**
- Updated installer package with new credentials
- Set system environment variables (Machine scope)
- Updated scheduled task arguments
**Files:** `FIX_DEVICE_SUPABASE_URL.ps1`, `osquery-agent/install-osquery.ps1`

### 7. **Logs Not Updating**
**Problem:** Logs showing old timestamps, not updating
**Root Cause:** Scheduled task runs as SYSTEM, logs go to `C:\WINDOWS\TEMP\` not user temp
**Solution:** Check logs in SYSTEM temp folder: `C:\WINDOWS\TEMP\VigyanShaala-RealtimeListener.log`
**Files:** N/A (documentation)

### 8. **User-Notify-Agent Not Auto-Running**
**Problem:** Buzz works when manually started, but not automatically
**Root Cause:** Task configured for "AtLogOn" trigger, doesn't run if user already logged in
**Solution:** Manually start task, or log out/in to trigger
**Files:** `osquery-agent/install-osquery.ps1`

### 9. **RLS Policies Blocking Dashboard**
**Problem:** Dashboard (using anon key) getting "permission denied for table users"
**Root Cause:** RLS policies checking `auth.users` which anon key can't access
**Solution:** Modified policies to allow anon access for dashboard operations
**Files:** `FIX_ALL_UNRESTRICTED_TABLES.sql`

### 10. **Uninstall Not Deleting Program Files Folder**
**Problem:** Uninstall script not removing `C:\Program Files\osquery`
**Root Cause:** Files locked by running processes, read-only attributes
**Solution:** Enhanced script to kill processes, remove attributes, retry deletion
**Files:** `osquery-agent/uninstall-osquery.ps1`

## How It Works on New Device Installation

### Installation Process

1. **Teacher downloads installer** from dashboard
2. **Extracts ZIP** and runs `RUN-AS-ADMIN.bat`
3. **Installer (`INSTALL.ps1`)** runs with pre-configured Supabase credentials:
   - Calls `install-osquery.ps1` with correct URL and key
   - Sets system environment variables (Machine scope)
   - Creates all scheduled tasks with correct credentials in arguments
   - Copies all scripts to `C:\Program Files\osquery\`

### Scheduled Tasks Created

1. **VigyanShaala-MDM-RealtimeListener** (SYSTEM)
   - Runs at startup, continuous
   - Uses credentials from task arguments (not env vars)
   - Logs to: `C:\WINDOWS\TEMP\VigyanShaala-RealtimeListener.log`

2. **VigyanShaala-UserNotify-Agent** (USER)
   - Runs at user logon
   - Processes buzz/toast notifications
   - Logs to: `%TEMP%\VigyanShaala-UserNotify.log`

3. **Other tasks** (SYSTEM):
   - Data collection, blocklist sync, etc.

### Command Flow (Buzz Example)

1. **Dashboard** → Inserts command into `device_commands` table
2. **Realtime** → Sends INSERT event via WebSocket
3. **Realtime Listener** (SYSTEM) → Receives event, calls `Buzz-Device()`
4. **Buzz-Device()** → Queues notification to `user_notifications` table
5. **User-Notify-Agent** (USER) → Polls table, finds notification, plays beep
6. **Status Update** → Command marked as completed

### Key Points for New Installations

✅ **All credentials pre-configured** in installer package
✅ **System env vars set** during installation
✅ **Task arguments include credentials** (backup if env vars fail)
✅ **User-notify-agent auto-starts** on user logon
✅ **Realtime enabled** in Supabase (via migration)
✅ **All scripts latest versions** in installer package

### Potential Issues on New Device

1. **User-notify-agent not running:**
   - If user already logged in when installed, task won't start until logon
   - Fix: Manually start task or log out/in

2. **Realtime not enabled:**
   - If Supabase migration not run
   - Fix: Run `ALTER PUBLICATION supabase_realtime ADD TABLE device_commands;`

3. **RLS blocking operations:**
   - If policies not updated for anon access
   - Fix: Run `FIX_ALL_UNRESTRICTED_TABLES.sql`

### Verification Checklist

After installation on new device:
- [ ] Device appears in dashboard
- [ ] Realtime listener task running
- [ ] User-notify-agent task enabled (will run on logon)
- [ ] Test lock command works
- [ ] Test buzz command works (after user logs in)
- [ ] Check logs in `C:\WINDOWS\TEMP\` (SYSTEM) and `%TEMP%` (USER)


