# WebSocket Realtime Listener - Debug Summary

## Problem Statement

The Supabase Realtime WebSocket listener (`realtime-command-listener.ps1`) is **NOT receiving INSERT events** from the `device_commands` table, even though:
- The test script (`test-realtime-subscription.ps1`) **DOES receive events** when subscribing without a filter
- Commands are being inserted into the database successfully
- The WebSocket connection is established successfully
- The subscription is confirmed with `phx_reply` status=ok

## What Works

### Test Script (`test-realtime-subscription.ps1`)
- **Subscribes WITHOUT filter** to all `device_commands` INSERT events
- **Successfully receives** INSERT events when commands are inserted
- Shows events like: `[18:46:10] Event: INSERT, Topic: realtime:public:device_commands`
- Connection works, channel join works, subscription works

### Database
- Commands are being inserted into `device_commands` table successfully
- Realtime is enabled for `device_commands` table (migration `028_enable_realtime_for_device_commands.sql`)
- Table structure is correct

### WebSocket Connection
- Main listener successfully connects to Supabase Realtime
- Channel join is successful (`phx_reply` with status=ok)
- Subscription message is sent
- Heartbeats are working

## What Doesn't Work

### Main Listener (`realtime-command-listener.ps1`)
- **Does NOT receive INSERT events** when commands are inserted
- Connection is established, subscription confirmed, but no `postgres_changes` or INSERT events received
- Logs show: connection successful, subscription confirmed, but then silence

## Current Code State

### Subscription (in `realtime-command-listener.ps1`)
```powershell
$subscribeMessage = @{
    topic = "realtime:public:device_commands"
    event = "postgres_changes"
    payload = @{
        type = "postgres_changes"
        event = "INSERT"
        schema = "public"
        table = "device_commands"
        # No filter - will receive all INSERT events, filter in Process-CommandFromRealtime
    }
    ref = $subscribeRef
}
```

**Note:** Filter was removed because test script works without filter.

### Event Handler
```powershell
if ($message.event -eq "INSERT" -and $message.payload) {
    # Log payload structure for debugging
    $payloadKeys = $message.payload.PSObject.Properties.Name -join ', '
    Write-Log "Received INSERT event - Payload keys: $payloadKeys" "INFO"
    
    # Extract new record from payload
    $newRecord = if ($message.payload.new) { 
        $message.payload.new 
    } elseif ($message.payload.record) {
        $message.payload.record
    } else { 
        $message.payload 
    }
    
    if ($newRecord -and $newRecord.command_type) {
        Write-Log "Processing INSERT event for command: $($newRecord.command_type) (ID: $($newRecord.id))" "INFO"
        Process-CommandFromRealtime -commandData $newRecord
    }
}
```

## What We've Tried

1. ✅ **Removed filter from subscription** - Test script works without filter, so we removed it
2. ✅ **Fixed event name check** - Changed from `postgres_changes` to `INSERT` (test script shows event name is "INSERT")
3. ✅ **Enabled Realtime for table** - Migration `028_enable_realtime_for_device_commands.sql` executed
4. ✅ **Verified connection** - WebSocket connects, channel joins, subscription confirmed
5. ✅ **Added detailed logging** - But no INSERT events are being logged

## Key Differences: Test Script vs Main Listener

### Test Script (WORKS)
- Simple WebSocket connection
- Subscribes to ALL events (no filter)
- Uses basic receive loop with 30s timeout
- **Receives INSERT events successfully**

### Main Listener (DOESN'T WORK)
- More complex with heartbeat management
- Dynamic receive timeout (5-25 seconds)
- Reconnection logic
- **Does NOT receive INSERT events**

## Potential Issues

1. **Heartbeat/Timeout Interference**
   - Main listener uses dynamic timeouts (5-25 seconds)
   - Test script uses fixed 30s timeout
   - Could heartbeat or timeout logic be interfering with event reception?

2. **Message Processing**
   - Main listener has complex message processing with multiple checks
   - Could messages be getting dropped or not processed correctly?

3. **Subscription Confirmation**
   - Both show `phx_reply` with status=ok
   - But maybe the subscription isn't actually active in the main listener?

4. **Payload Structure**
   - Test script doesn't show payload structure
   - Main listener expects `payload.new` or `payload.record` or `payload`
   - Could payload structure be different than expected?

5. **Multiple Subscriptions**
   - Main listener might be creating multiple subscriptions?
   - Or subscription might be getting overwritten?

## Logs from Main Listener

```
[2025-12-15 18:04:11] [INFO] Realtime Command Listener starting
[2025-12-15 18:04:11] [INFO] Device: VJ_VENUGOPALAN
[2025-12-15 18:04:11] [INFO] Realtime WebSocket URL: wss://ujmcjezpmyvpiasfrwhm.supabase.co/realtime/v1/websocket
[2025-12-15 18:04:11] [INFO] Functions imported successfully from execute-commands.ps1
[2025-12-15 18:04:11] [INFO] Connecting to Supabase Realtime...
[2025-12-15 18:04:11] [INFO] WebSocket connected successfully
[2025-12-15 18:04:11] [INFO] Sent channel join message
[2025-12-15 18:04:11] [INFO] Subscribed to device_commands INSERT events for device: VJ_VENUGOPALAN
[2025-12-15 18:04:11] [INFO] Connection established. Listening for commands...
[2025-12-15 18:04:11] [INFO] Subscription confirmed (ref: 1)
[2025-12-15 18:04:36] [INFO] Heartbeat sent
[2025-12-15 18:04:36] [WARN] WebSocket connection closed True
```

**Note:** No INSERT events are logged, even when commands are inserted.

## Logs from Test Script (WORKS)

```
[18:46:04] Event: phx_reply, Topic: realtime:public:device_commands
  -> Reply: status=ok
[18:46:04] Event: system, Topic: realtime:public:device_commands
[18:46:04] Event: presence_state, Topic: realtime:public:device_commands
[18:46:10] Event: INSERT, Topic: realtime:public:device_commands
[18:46:21] Event: INSERT, Topic: realtime:public:device_commands
```

**Note:** INSERT events are received successfully.

## Questions to Investigate

1. Why does the test script receive INSERT events but the main listener doesn't?
2. Is the subscription actually active in the main listener, even though `phx_reply` shows status=ok?
3. Are INSERT events being sent by Supabase but not reaching the main listener's receive loop?
4. Is the dynamic timeout/heartbeat logic interfering with event reception?
5. Should we log ALL received messages (including system/presence) to see what's different?

## Files to Review

- `osquery-agent/realtime-command-listener.ps1` - Main listener (not working)
- `osquery-agent/test-realtime-subscription.ps1` - Test script (working)
- `supabase/migrations/028_enable_realtime_for_device_commands.sql` - Realtime enabled

## Environment

- **Supabase URL:** `https://ujmcjezpmyvpiasfrwhm.supabase.co`
- **Device Hostname:** `VJ_VENUGOPALAN`
- **Table:** `device_commands`
- **Event Type:** INSERT
- **PowerShell Version:** Windows PowerShell (not PowerShell Core)

## Next Steps to Debug

1. Add logging to show ALL received messages (not just INSERT events)
2. Compare exact subscription message between test script and main listener
3. Check if messages are being received but not processed
4. Simplify main listener to match test script's simple approach
5. Check Supabase Realtime logs/dashboard for subscription status


