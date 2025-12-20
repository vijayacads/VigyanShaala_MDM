# Next Steps Summary - Data Flow to Supabase

## ✅ Current Status

**Test Results:**
- ✅ Data generation working (device_health, battery_health, system_uptime)
- ✅ Data sending working (successful response from Supabase)
- ⚠️ Scheduled task missing (needs to be created)

## Immediate Actions Needed

### 1. Verify Data in Supabase

Run this to check if data was stored:
```powershell
cd "C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent"
.\verify-supabase-data.ps1
```

This will show:
- Battery percentage
- Storage usage
- Boot time
- Crash count
- Performance status
- Last seen timestamp

### 2. Create Scheduled Task (IMPORTANT)

The scheduled task to automatically send data every 5 minutes is missing. Create it:

```powershell
cd "C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent"
.\create-send-data-task.ps1
```

Or manually with environment variables:
```powershell
.\create-send-data-task.ps1 -SupabaseUrl $env:SUPABASE_URL -SupabaseKey $env:SUPABASE_ANON_KEY
```

### 3. Verify Scheduled Task is Running

After creating the task:
```powershell
Get-ScheduledTask -TaskName "VigyanShaala-MDM-SendOsqueryData" | Get-ScheduledTaskInfo
```

Should show:
- Next run time (within 5 minutes)
- Task is enabled

## What's Working

1. **Data Collection:**
   - `trigger-osquery-queries.ps1` successfully generates data
   - Battery data from WMI (96% detected)
   - Storage data from osquery
   - Uptime data from osquery

2. **Data Sending:**
   - `send-osquery-data.ps1` successfully sends to Supabase
   - Edge function responds with success
   - `last_seen` is being updated

3. **Data Format:**
   - All data is in correct format
   - Edge function should process it correctly

## What Needs Attention

1. **Scheduled Task:**
   - Currently missing - needs to be created
   - Without it, data only sends when manually triggered
   - Should run every 5 minutes automatically

2. **Data Verification:**
   - Need to verify data is actually in `device_health` table
   - Check if battery/storage/uptime values are stored correctly

## Complete Workflow

Once scheduled task is created:

```
Every 5 minutes:
1. Scheduled task runs send-osquery-data.ps1
2. Script reads osquery log (last 100 lines)
3. Parses "added" actions for health data
4. Sends to Supabase Edge Function
5. Edge function processes and stores in device_health table
6. Dashboard shows updated metrics
```

## Troubleshooting

**If data is not in Supabase:**

1. Check Edge Function logs in Supabase Dashboard
2. Run verify script to see what's stored
3. Manually test: `.\test-data-flow.ps1`
4. Check if device is enrolled (required for data storage)

**If scheduled task fails:**

1. Check task history: `Get-ScheduledTask -TaskName "VigyanShaala-MDM-SendOsqueryData" | Get-ScheduledTaskInfo`
2. Check if script exists: `Test-Path "C:\Program Files\osquery\send-osquery-data.ps1"`
3. Check environment variables are set for SYSTEM account
4. Run task manually to see errors

## Next Steps Checklist

- [ ] Run `verify-supabase-data.ps1` to check stored data
- [ ] Create scheduled task with `create-send-data-task.ps1`
- [ ] Verify task is running every 5 minutes
- [ ] Check Supabase dashboard for device_health data
- [ ] Monitor for 10-15 minutes to ensure automatic updates work
- [ ] Check Edge Function logs for any errors

## Success Criteria

✅ Data appears in `device_health` table  
✅ Battery percentage shows (96% in your case)  
✅ Storage percentage shows (~29% in your case)  
✅ Scheduled task runs every 5 minutes  
✅ `last_seen` updates automatically  
✅ Dashboard shows health metrics  




