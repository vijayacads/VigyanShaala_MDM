# Clean Slate Fresh Start Guide - VigyanShaala MDM

## Overview
This document provides a complete guide for starting fresh with the MDM system, including uninstalling all components, removing scheduled tasks, and rewriting the WebSocket implementation from scratch.

---

## Part 1: Complete Uninstallation

### Step 1: Uninstall All MDM Components

Run the uninstall script as Administrator:

```powershell
# Navigate to the project directory
cd "C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent"

# Run uninstall script
.\uninstall-osquery.ps1
```

### Step 2: Manually Remove All Scheduled Tasks

Even if the uninstall script removes tasks, verify and remove manually:

```powershell
# List all VigyanShaala MDM tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like "*VigyanShaala*" } | Format-Table TaskName, State

# Remove ALL scheduled tasks (comprehensive list)
Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-UserNotify-Agent" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "VigyanShaala-UserNotify-Agent" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-SendOsqueryData" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-CollectBatteryData" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-SyncWebsiteBlocklist" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-SyncSoftwareBlocklist" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-CommandProcessor" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-HealthCheck" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-OsqueryData" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-SoftwareInventory" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-WebActivity" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-GeofenceCheck" -Confirm:$false -ErrorAction SilentlyContinue

# Remove all tasks matching pattern (catch-all)
Get-ScheduledTask | Where-Object { $_.TaskName -like "*VigyanShaala*" } | ForEach-Object {
    Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false -ErrorAction SilentlyContinue
}

# Verify all removed
Get-ScheduledTask | Where-Object { $_.TaskName -like "*VigyanShaala*" }
```

### Step 3: Remove Installation Directory

```powershell
# Stop any running processes first
Get-Process | Where-Object { $_.Path -like "*osquery*" } | Stop-Process -Force -ErrorAction SilentlyContinue

# Remove installation directory
Remove-Item "C:\Program Files\osquery" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\ProgramData\osquery" -Recurse -Force -ErrorAction SilentlyContinue
```

### Step 4: Remove Environment Variables

```powershell
# Remove system environment variables
[Environment]::SetEnvironmentVariable("SUPABASE_URL", $null, "Machine")
[Environment]::SetEnvironmentVariable("SUPABASE_ANON_KEY", $null, "Machine")

# Verify removal
[Environment]::GetEnvironmentVariable("SUPABASE_URL", "Machine")
[Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY", "Machine")
```

### Step 5: Remove Registry Entries

```powershell
# Remove osquery registry entries
Remove-Item "HKLM:\SOFTWARE\osquery" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "HKLM:\SYSTEM\CurrentControlSet\Services\osqueryd" -Recurse -Force -ErrorAction SilentlyContinue
```

### Step 6: Remove Log Files

```powershell
# Remove log files
Remove-Item "$env:TEMP\VigyanShaala-*.log" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\WINDOWS\TEMP\VigyanShaala-*.log" -Force -ErrorAction SilentlyContinue
```

### Step 7: Verify Complete Removal

```powershell
# Check for any remaining traces
Get-ScheduledTask | Where-Object { $_.TaskName -like "*VigyanShaala*" }
Get-Process | Where-Object { $_.Path -like "*osquery*" }
Test-Path "C:\Program Files\osquery"
Test-Path "C:\ProgramData\osquery"
```

---

## Part 2: WebSocket Implementation - Fresh Rewrite

### Current Issues with WebSocket Implementation

The current `realtime-command-listener.ps1` has several issues:

1. **Complex function import logic** - Dynamically importing functions from `execute-commands.ps1` causes parsing errors
2. **Heartbeat timing issues** - Connection closes despite heartbeats
3. **Event handling complexity** - Multiple attempts to handle `postgres_changes` events
4. **Subscription registration** - Inconsistent subscription method (in `phx_join` vs separate message)
5. **Error handling** - Script exits on errors instead of reconnecting
6. **Credential management** - Confusion between scheduled task arguments and environment variables

### Recommended Fresh Approach

#### Architecture Decision: Separate Command Execution

**Key Learning:** All device controls (lock, unlock, buzz, clear_cache) must run in the **user's interactive session**, not as SYSTEM.

**Solution:** Queue all commands to `user_notifications` table, and have a separate `user-notify-agent.ps1` running in the user session poll and execute them.

#### WebSocket Listener Responsibilities

The `realtime-command-listener.ps1` should:
1. **Only listen** for `device_commands` INSERT events
2. **Only queue** commands to `user_notifications` table
3. **Never execute** commands directly (except broadcast messages)
4. **Keep it simple** - no complex function imports

#### Recommended Structure

```powershell
# realtime-command-listener.ps1 (Fresh Implementation)

# 1. Simple WebSocket connection
# 2. Simple subscription to device_commands INSERT events
# 3. Simple queue to user_notifications table
# 4. Robust reconnection logic
# 5. Clear logging

# NO function imports from execute-commands.ps1
# NO command execution logic
# NO complex parsing
```

### WebSocket Protocol Reference

**Supabase Realtime uses Phoenix Channels over WebSocket:**

1. **Connection URL:**
   ```
   wss://{project-ref}.supabase.co/realtime/v1/websocket?apikey={anon-key}&vsn=1.0.0
   ```

2. **Message Format:**
   ```json
   {
     "topic": "realtime:public:device_commands",
     "event": "phx_join",
     "payload": { ... },
     "ref": 1
   }
   ```

3. **Required Messages:**
   - `phx_join` - Join channel (with postgres_changes subscription in config)
   - `access_token` - Authenticate with anon key
   - `heartbeat` - Keep connection alive (every 30 seconds)

4. **Event Types:**
   - `phx_reply` - Acknowledgment
   - `postgres_changes` - Database change event
   - `system` - System messages
   - `presence_state` - Presence updates

5. **postgres_changes Event Structure:**
   ```json
   {
     "event": "postgres_changes",
     "payload": {
       "data": {
         "type": "INSERT",
         "table": "device_commands",
         "record": { ... }
       }
     }
   }
   ```

### Key Lessons Learned

1. **SECURITY DEFINER Functions:** Use PostgreSQL functions with `SECURITY DEFINER` for device enrollment to bypass RLS issues
2. **User Session Commands:** All UI/audio commands (lock, buzz, cache) must run in user session, not SYSTEM
3. **Queue Pattern:** Queue commands to `user_notifications` table, poll from user session
4. **Simple WebSocket:** Keep WebSocket listener simple - only listen and queue
5. **Robust Reconnection:** Always reconnect on errors, never exit
6. **Clear Logging:** Log all WebSocket messages for debugging
7. **Environment Variables:** Use system environment variables for credentials, pass as task arguments as backup

---

## Part 3: Handoff Guide for Next Agent

### Context Summary

This MDM system manages Windows devices using:
- **Supabase** for database and real-time WebSocket communication
- **osquery** for device data collection
- **PowerShell scripts** for agent functionality
- **Scheduled Tasks** for background execution

### Current Architecture

1. **Device Enrollment:** `enroll-device.ps1` calls `public.enroll_device()` PostgreSQL function
2. **Command Delivery:** Dashboard → `device_commands` table → Realtime WebSocket → `realtime-command-listener.ps1` → `user_notifications` table
3. **Command Execution:** `user-notify-agent.ps1` polls `user_notifications` and executes in user session
4. **Data Collection:** Multiple scheduled tasks collect osquery data, health checks, software inventory, web activity

### Critical Files to Review

1. **`osquery-agent/realtime-command-listener.ps1`** - Current WebSocket implementation (has issues)
2. **`osquery-agent/execute-commands.ps1`** - Command execution functions (should be simplified)
3. **`osquery-agent/user-notify-agent.ps1`** - User session command executor (works well)
4. **`osquery-agent/install-osquery.ps1`** - Main installer script
5. **`osquery-agent/uninstall-osquery.ps1`** - Uninstaller script

### Git History to Review

**Important:** Review the git history for `realtime-command-listener.ps1` to understand:
- All the iterations and fixes attempted
- Why certain approaches didn't work
- What was learned from each attempt

Key commits to review:
- Initial WebSocket implementation
- Function import fixes
- Heartbeat timing adjustments
- Subscription method changes
- Event handling logic changes

### Database Schema

**Critical Tables:**
- `devices` - Device registry (primary key: `hostname`)
- `device_commands` - Commands to execute (INSERT triggers Realtime event)
- `user_notifications` - Queue for user-session commands
- `device_health` - Health check data
- `software_inventory` - Installed software
- `web_activity` - Browser activity
- `geofence_alerts` - Location violations

**Critical Functions:**
- `public.enroll_device()` - SECURITY DEFINER function for device enrollment

**Critical Policies:**
- `device_commands` - Allow anon INSERT (for dashboard)
- `user_notifications` - Allow anon INSERT/SELECT (for agents)
- All tables need proper RLS for dashboard (anon key) access

### Supabase Configuration

**Realtime Setup:**
```sql
-- Enable Realtime for device_commands table
ALTER PUBLICATION supabase_realtime ADD TABLE device_commands;
```

**Verify Realtime:**
```sql
SELECT tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
AND tablename = 'device_commands';
```

### Current Project Details

- **Project ID:** `thqinhphunrflwlshdmx`
- **URL:** `https://thqinhphunrflwlshdmx.supabase.co`
- **Anon Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRocWluaHBodW5yZmx3bHNoZG14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4Njk2ODcsImV4cCI6MjA4MTQ0NTY4N30.nVTHifwIDIozcqerE-X7zmebO6Pag8Ji-N3d4jetaQM`

### Known Issues

1. **WebSocket Connection:** Closes frequently, needs robust reconnection
2. **Event Handling:** Complex logic for parsing `postgres_changes` events
3. **Function Import:** Dynamic import from `execute-commands.ps1` causes parsing errors
4. **Command Execution:** Some commands marked "completed" but don't execute (fixed by queuing to user session)

### Recommended Fresh Implementation Steps

1. **Start Simple:**
   - Create minimal WebSocket connection
   - Subscribe to `device_commands` INSERT events only
   - Log all received messages

2. **Add Queue Logic:**
   - On INSERT event, queue to `user_notifications` table
   - No command execution in WebSocket listener

3. **Add Reconnection:**
   - Catch all errors
   - Always reconnect
   - Exponential backoff

4. **Test Incrementally:**
   - Test connection
   - Test subscription
   - Test event reception
   - Test queue insertion

5. **Keep It Simple:**
   - No complex parsing
   - No function imports
   - Clear, readable code

### Testing Checklist

- [ ] WebSocket connects successfully
- [ ] Subscription confirmed (phx_reply with postgres_changes)
- [ ] INSERT events received when command created in dashboard
- [ ] Commands queued to `user_notifications` table
- [ ] `user-notify-agent.ps1` picks up and executes commands
- [ ] Reconnection works on connection loss
- [ ] Heartbeats keep connection alive
- [ ] All command types work (lock, unlock, buzz, clear_cache)

### Resources

- **Supabase Realtime Docs:** https://supabase.com/docs/guides/realtime
- **Phoenix Channels:** https://hexdocs.pm/phoenix/channels.html
- **PowerShell WebSocket:** Use `System.Net.WebSockets.ClientWebSocket`

### Next Steps After Clean Slate

1. Complete uninstallation (Part 1)
2. Review git history for `realtime-command-listener.ps1`
3. Design fresh WebSocket implementation (simple, robust)
4. Implement incrementally with testing
5. Integrate with existing `user-notify-agent.ps1`
6. Test all command types
7. Update installer with new implementation

---

## Part 4: Quick Reference Commands

### Complete Uninstall (One-Liner)

```powershell
# Run as Administrator
cd "C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent"; .\uninstall-osquery.ps1; Get-ScheduledTask | Where-Object { $_.TaskName -like "*VigyanShaala*" } | ForEach-Object { Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false -ErrorAction SilentlyContinue }; Remove-Item "C:\Program Files\osquery" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item "C:\ProgramData\osquery" -Recurse -Force -ErrorAction SilentlyContinue; [Environment]::SetEnvironmentVariable("SUPABASE_URL", $null, "Machine"); [Environment]::SetEnvironmentVariable("SUPABASE_ANON_KEY", $null, "Machine")
```

### Verify Clean State

```powershell
# Check scheduled tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like "*VigyanShaala*" }

# Check processes
Get-Process | Where-Object { $_.Path -like "*osquery*" }

# Check directories
Test-Path "C:\Program Files\osquery"
Test-Path "C:\ProgramData\osquery"

# Check environment variables
[Environment]::GetEnvironmentVariable("SUPABASE_URL", "Machine")
[Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY", "Machine")
```

---

## Notes for Next Agent

- **Read git history** for `realtime-command-listener.ps1` to understand all attempted fixes
- **Keep WebSocket listener simple** - only listen and queue, no execution
- **All commands must queue** to `user_notifications` for user-session execution
- **Test incrementally** - don't try to fix everything at once
- **Use clear logging** - log all WebSocket messages for debugging
- **Robust reconnection** - always reconnect on errors, never exit

Good luck with the fresh implementation! 🚀

