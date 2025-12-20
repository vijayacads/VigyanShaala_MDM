# Data Flow to Supabase - Next Steps

## Current Status

✅ **Completed:**
- `trigger-osquery-queries.ps1` - Manually triggers queries and writes to log
- `send-osquery-data.ps1` - Reads log and sends to Supabase (with debug output)
- `fetch-osquery-data` edge function - Receives and processes data
- Scheduled task `VigyanShaala-MDM-SendOsqueryData` - Runs every 5 minutes
- Battery data collection (osquery primary, WMI fallback)

## Data Flow

```
1. osqueryd service (or trigger script)
   ↓
2. Writes to: C:\ProgramData\osquery\logs\osqueryd.results.log
   ↓
3. send-osquery-data.ps1 (runs every 5 min via scheduled task)
   ↓
4. Reads log, parses JSON, builds payload
   ↓
5. Sends POST to: {SUPABASE_URL}/functions/v1/fetch-osquery-data
   ↓
6. Edge function processes data:
   - device_health → device_health table
   - battery_health → device_health.battery_health_percent
   - system_uptime → device_health.boot_time_avg_seconds
   - crash_events → device_health.crash_error_count
   ↓
7. Supabase database updated
```

## Next Steps to Verify

### 1. Test the Complete Flow

Run the test script:
```powershell
cd "C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent"
.\test-data-flow.ps1
```

This will:
- Check all scripts exist
- Verify environment variables
- Run trigger script to generate data
- Send data to Supabase
- Show what was sent

### 2. Verify Scheduled Task is Running

```powershell
# Check task status
Get-ScheduledTask -TaskName "VigyanShaala-MDM-SendOsqueryData" | Get-ScheduledTaskInfo

# Check last run time
Get-ScheduledTask -TaskName "VigyanShaala-MDM-SendOsqueryData" | Get-ScheduledTaskInfo | Select-Object LastRunTime, LastTaskResult

# View task history (if available)
Get-WinEvent -LogName "Microsoft-Windows-TaskScheduler/Operational" | Where-Object {$_.Message -like "*VigyanShaala-MDM-SendOsqueryData*"} | Select-Object -First 5
```

### 3. Check Supabase Dashboard

1. **Check device_health table:**
   ```sql
   SELECT * FROM device_health WHERE device_hostname = 'YOUR_HOSTNAME';
   ```

2. **Check Edge Function logs:**
   - Go to Supabase Dashboard → Edge Functions → fetch-osquery-data → Logs
   - Look for any errors or warnings

3. **Verify data is being received:**
   - Check `last_seen` timestamp in `devices` table
   - Should update every 5 minutes when task runs

### 4. Manual Testing

If scheduled task isn't working, test manually:

```powershell
# Step 1: Generate data
cd "C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent"
.\trigger-osquery-queries.ps1

# Step 2: Send data
cd "C:\Program Files\osquery"
.\send-osquery-data.ps1
```

The send script will show:
- Summary of collected data
- Detailed device_health, battery_health, system_uptime data
- Full payload being sent
- Response from Supabase

### 5. Troubleshooting

**If data is not appearing in Supabase:**

1. **Check send script output:**
   - Does it show data was collected?
   - Does it show "Data sent successfully"?
   - Any error messages?

2. **Check Edge Function logs:**
   - Are requests being received?
   - Any errors in processing?
   - Check for "Device not found" errors (device must be enrolled first)

3. **Check log file:**
   ```powershell
   Get-Content "C:\ProgramData\osquery\logs\osqueryd.results.log" -Tail 20 | Select-String "device_health|battery_health|system_uptime"
   ```

4. **Verify environment variables:**
   ```powershell
   $env:SUPABASE_URL
   $env:SUPABASE_ANON_KEY
   ```

5. **Test Edge Function directly:**
   ```powershell
   $body = @{
       hostname = $env:COMPUTERNAME
       device_health = @(@{total_storage = "1000000000"; used_storage = "500000000"})
       battery_health = @(@{percentage = 94})
       system_uptime = @(@{uptime = 3600})
   } | ConvertTo-Json -Depth 10
   
   Invoke-RestMethod -Uri "$env:SUPABASE_URL/functions/v1/fetch-osquery-data" `
       -Method POST `
       -Headers @{
           "apikey" = $env:SUPABASE_ANON_KEY
           "Content-Type" = "application/json"
           "Authorization" = "Bearer $env:SUPABASE_ANON_KEY"
       } `
       -Body $body
   ```

## Expected Data Format

The edge function expects:
- `battery_health[0].percentage` - Integer (0-100)
- `device_health[0].total_storage` - String (bytes as number)
- `device_health[0].used_storage` - String (bytes as number)
- `system_uptime[0].uptime` - Integer (seconds)
- `crash_events[0].crash_count` - Integer

## Performance Status Calculation

The `performance_status` is automatically calculated by a database trigger:
- **critical**: storage >= 90%, battery < 10%, crashes > 5
- **warning**: storage 80-89%, battery 10-20%, crashes 1-5
- **good**: everything else

## Automation

The system should work automatically:
- osqueryd service runs scheduled queries
- Scheduled task sends data every 5 minutes
- Edge function processes and stores data
- Dashboard shows updated health metrics

If manual intervention is needed, use the test script or manual commands above.




