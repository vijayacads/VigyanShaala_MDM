# User Session Agent Implementation

## Overview

This document describes the new user-session agent architecture for handling buzz and toast notifications. This replaces the previous approach of creating temporary scheduled tasks from SYSTEM context.

## Architecture

### Previous Approach (Problematic)
```
SYSTEM Agent → Detect User → Create Temp Task → Run as User → Execute Buzz/Toast
```
**Issues:**
- Session 0 isolation prevents SYSTEM from reliably accessing user sessions
- Temporary task creation is fragile and timing-dependent
- Complex error handling and cleanup required

### New Approach (Implemented)
```
SYSTEM Agent → Write to user_notifications table
User Agent (runs at logon) → Poll user_notifications → Execute Buzz/Toast
```
**Benefits:**
- Clear separation of concerns
- User agent runs in correct session from start
- No session jumping required
- Easier to debug and maintain

## Components

### 1. Database Table: `user_notifications`

Created via migration `022_create_user_notifications.sql`:
- Stores notifications that need user-session execution
- Fields: `device_hostname`, `username`, `type` (buzzer/toast), `payload`, `status`
- Indexed for efficient querying by device+user+status

### 2. User Session Agent: `user-notify-agent.ps1`

**Location:** `C:\Program Files\osquery\user-notify-agent.ps1`

**Functionality:**
- Runs continuously in user's interactive session
- Polls `user_notifications` table every 5 seconds
- Processes pending notifications for current device+user
- Executes buzz (via `[console]::beep()`) or toast (via Windows Toast API)
- Marks notifications as completed/failed

**Logging:**
- Logs to `%TEMP%\VigyanShaala-UserNotify.log`
- Includes timestamps, log levels, and detailed messages

### 3. SYSTEM Agent Changes: `execute-commands.ps1`

**Modified Functions:**
- `Buzz-Device`: Now writes to `user_notifications` instead of creating temp tasks
- `Show-ToastNotification`: Now writes to `user_notifications` instead of creating temp tasks

**Behavior:**
- Detects logged-in user
- Creates notification record in database
- Returns immediately (doesn't wait for execution)

### 4. Installer Changes: `install-osquery.ps1`

**New Task:** `VigyanShaala-UserNotify-Agent`
- Trigger: At user logon
- Principal: Runs as logged-on user (or Users group)
- Action: Runs `user-notify-agent.ps1` continuously
- Settings: No time limit, runs only when user logged on

## Installation

The user-session agent is automatically installed when running `install-osquery.ps1`. The installer:
1. Copies `user-notify-agent.ps1` to installation directory
2. Creates scheduled task to run at user logon
3. Task runs in user's session automatically

## Usage

### For Administrators

**Sending Buzz Command:**
- Command is sent via dashboard or API
- SYSTEM agent writes to `user_notifications` table
- User agent picks it up within 5 seconds and plays beep

**Sending Toast Notification:**
- Broadcast message or direct toast command
- SYSTEM agent writes to `user_notifications` table
- User agent picks it up within 5 seconds and shows toast

### For Users

**Automatic:**
- Agent starts automatically when user logs on
- Runs silently in background
- No user interaction required

**Logs:**
- Check `%TEMP%\VigyanShaala-UserNotify.log` for debugging
- Logs include all notification processing events

## Troubleshooting

### Agent Not Running

1. **Check if task exists:**
   ```powershell
   Get-ScheduledTask -TaskName "VigyanShaala-UserNotify-Agent"
   ```

2. **Check task status:**
   ```powershell
   Get-ScheduledTaskInfo -TaskName "VigyanShaala-UserNotify-Agent"
   ```

3. **Check if task is enabled:**
   ```powershell
   (Get-ScheduledTask -TaskName "VigyanShaala-UserNotify-Agent").State
   ```

4. **Manually start task:**
   ```powershell
   Start-ScheduledTask -TaskName "VigyanShaala-UserNotify-Agent"
   ```

### Notifications Not Processing

1. **Check logs:**
   ```powershell
   Get-Content "$env:TEMP\VigyanShaala-UserNotify.log" -Tail 50
   ```

2. **Verify database connection:**
   - Check if `SUPABASE_URL` and `SUPABASE_KEY` environment variables are set
   - Verify network connectivity to Supabase

3. **Check notification in database:**
   ```sql
   SELECT * FROM user_notifications 
   WHERE device_hostname = 'YOUR_DEVICE' 
   AND username = 'YOUR_USERNAME' 
   AND status = 'pending'
   ORDER BY created_at DESC;
   ```

4. **Verify hostname/username matching:**
   - Device hostname must match (case-insensitive, normalized to uppercase)
   - Username must match exactly (including domain if applicable)

### Buzz Not Playing

1. **Check Windows Audio service:**
   ```powershell
   Get-Service -Name "Audiosrv"
   ```

2. **Test beep manually:**
   ```powershell
   [console]::beep(800, 500)
   ```

3. **Check if user agent is running:**
   ```powershell
   Get-Process | Where-Object { $_.ProcessName -eq "powershell" -and $_.CommandLine -like "*user-notify-agent*" }
   ```

### Toast Not Showing

1. **Check Windows notification settings:**
   - Settings → System → Notifications
   - Ensure notifications are enabled for "VigyanShaala MDM"

2. **Test toast manually:**
   - Run toast code directly in PowerShell as logged-in user
   - Verify Windows Toast API is available

3. **Check for errors in logs:**
   - Look for "Failed to show toast notification" messages

## Migration from Old Approach

If upgrading from the previous implementation:

1. **Run migration:** Apply `022_create_user_notifications.sql` to Supabase
2. **Update agent:** Install new version with `install-osquery.ps1`
3. **Verify task:** Check that `VigyanShaala-UserNotify-Agent` task exists
4. **Test:** Send a test buzz or toast command

Old temporary tasks will no longer be created, and existing ones will be cleaned up automatically.

## Future Enhancements

Potential improvements:
- Configurable poll interval (currently 5 seconds)
- Retry logic for failed notifications
- Notification priority/queuing
- Support for additional notification types
- Per-user configuration options

