# Debugging Edge Function - Device Health Not Storing

## Issue
Data is being sent to Supabase successfully, but `device_health` table remains empty.

## What We Know

✅ **Data Collection Working:**
- device_health: 5 entries found in log
- system_uptime: 5 entries found in log  
- battery_health: 0 entries (WMI data may be outside last 100 lines)

✅ **Data Sending Working:**
- Edge function responds with success
- `last_seen` is being updated
- No errors in send script

❌ **Data Storage Not Working:**
- `device_health` table is empty
- Edge function logs show it's running but no processing logs

## Debug Steps

### 1. Check Edge Function Logs

After the next scheduled task run (or manual send), check Supabase Dashboard:
- Edge Functions → `fetch-osquery-data` → Logs
- Look for the console.log statements I added:
  - "Processing device health data:"
  - "Device health updated:"
  - Any error messages

### 2. Verify Data Format

The edge function expects:
```typescript
payload.device_health[0].total_storage  // string (bytes)
payload.device_health[0].used_storage   // string (bytes)
payload.system_uptime[0].uptime         // string (seconds)
payload.battery_health[0].percentage    // number (0-100)
```

### 3. Check RLS Policies

The edge function uses SERVICE_ROLE_KEY, so RLS shouldn't block it, but verify:
```sql
-- Check if policies allow inserts
SELECT * FROM pg_policies WHERE tablename = 'device_health';
```

### 4. Test Direct Database Insert

Try inserting directly to verify table works:
```sql
INSERT INTO device_health (device_hostname, storage_used_percent, boot_time_avg_seconds, crash_error_count)
VALUES ('VJ_VENUGOPALAN', 29, 894120, 0)
ON CONFLICT (device_hostname) DO UPDATE SET
  storage_used_percent = EXCLUDED.storage_used_percent,
  boot_time_avg_seconds = EXCLUDED.boot_time_avg_seconds,
  updated_at = NOW();
```

### 5. Check Edge Function Code

The edge function should:
1. Check if `payload.device_health || payload.battery_health || payload.system_uptime || payload.crash_events` exists
2. Process each array
3. Upsert to `device_health` table

I've added console.log statements to debug. Check logs after next run.

## Next Steps

1. **Wait for next scheduled run** (or trigger manually)
2. **Check Edge Function logs** for the debug output
3. **Verify data format** matches what edge function expects
4. **Check for errors** in the logs

## Expected Log Output

After adding debug logging, you should see:
```
Processing device health data: {
  has_device_health: true,
  has_battery_health: false,
  has_system_uptime: true,
  has_crash_events: false
}
Device health updated: {
  device_hostname: "VJ_VENUGOPALAN",
  battery_health_percent: null,
  storage_used_percent: 29,
  boot_time_avg_seconds: 894120,
  crash_error_count: 0
}
```

If you don't see this, the condition `if (payload.device_health || ...)` is failing.

