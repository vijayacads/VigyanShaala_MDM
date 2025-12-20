# Debug Realtime Issue: Commands Not Being Received

## Problem
Commands are inserted into `device_commands` table but remain `pending` - device is not receiving them.

## Step 1: Check Realtime is Enabled in Supabase

Run `CHECK_REALTIME_SETUP.sql` in Supabase SQL Editor:

```sql
-- Check if device_commands is in Realtime publication
SELECT tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
    AND tablename = 'device_commands';
```

**Expected:** Should return 1 row with `tablename = 'device_commands'`

**If missing:** Run this to enable:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE device_commands;
```

## Step 2: Check Device Logs

On the device, run:
```powershell
# Check if listener is running
Get-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener" | Select-Object State

# Check recent logs for INSERT events
Get-Content "$env:TEMP\VigyanShaala-RealtimeListener.log" -Tail 50 | Select-String "INSERT|postgres_changes|Processing INSERT|RAW WS"

# Check connection status
Get-Content "$env:TEMP\VigyanShaala-RealtimeListener.log" -Tail 20 | Select-String "Connecting to|WebSocket connected|Subscription confirmed"
```

## Step 3: Run Test Script

On the device:
```powershell
cd "C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent"
.\test-realtime-receive.ps1
```

This will:
- Check if listener task is running
- Check logs for INSERT events
- Check pending commands in database
- Provide summary

## Step 4: Manual Test - Insert Command and Watch Logs

1. **In one PowerShell window (on device):**
```powershell
Get-Content "$env:TEMP\VigyanShaala-RealtimeListener.log" -Wait -Tail 10
```

2. **In another window, insert a test command:**
```powershell
$SupabaseUrl = "https://thqinhphunrflwlshdmx.supabase.co"
$SupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRocWluaHBodW5yZmx3bHNoZG14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4Njk2ODcsImV4cCI6MjA4MTQ0NTY4N30.nVTHifwIDIozcqerE-X7zmebO6Pag8Ji-N3d4jetaQM"
$headers = @{
    "apikey" = $SupabaseKey
    "Authorization" = "Bearer $SupabaseKey"
    "Content-Type" = "application/json"
}
$body = @{
    device_hostname = $env:COMPUTERNAME
    command_type = "buzz"
    duration = 3
    status = "pending"
} | ConvertTo-Json
$response = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/device_commands" -Method POST -Headers $headers -Body $body
Write-Host "Command inserted: $($response.id)" -ForegroundColor Green
```

3. **Watch the log window** - you should see:
   - `RAW WS: [JSON with postgres_changes event]`
   - `postgres_changes: type=INSERT table=device_commands`
   - `Processing INSERT command: buzz`

## Step 5: Check Event Structure

If events are received but not processed, check the RAW WS log. The structure should be:
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

## Common Issues

### Issue 1: Realtime Not Enabled
**Symptom:** No INSERT events in logs, but commands exist in DB
**Fix:** Run `ALTER PUBLICATION supabase_realtime ADD TABLE device_commands;`

### Issue 2: Device Not Connected
**Symptom:** Logs show "Connection closed" repeatedly
**Fix:** 
- Check Supabase URL/key in system environment variables
- Restart listener task: `Stop-ScheduledTask` then `Start-ScheduledTask`

### Issue 3: Event Structure Mismatch
**Symptom:** RAW WS logs show events but not processed
**Fix:** Check `Process-WebSocketMessage` function - may need to adjust parsing

### Issue 4: Wrong Supabase Project
**Symptom:** Logs show old Supabase URL
**Fix:** Update system environment variables and restart task

## Quick Fix Commands

```powershell
# 1. Check Realtime enabled (run in Supabase SQL Editor)
SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'device_commands';

# 2. Enable if missing
ALTER PUBLICATION supabase_realtime ADD TABLE device_commands;

# 3. On device - restart listener
Stop-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener"
Start-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener"

# 4. Watch logs
Get-Content "$env:TEMP\VigyanShaala-RealtimeListener.log" -Wait -Tail 10
```


