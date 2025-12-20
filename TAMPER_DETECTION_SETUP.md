# Tamper Detection Setup Guide

## Step 2: Deploy Edge Function (Optional)

The Edge Function is already created. To deploy it:

### Option A: Using Supabase CLI (Recommended)

```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Deploy the function
supabase functions deploy check-tamper-detection
```

### Option B: Using Supabase Dashboard

1. Go to your Supabase Dashboard
2. Navigate to **Edge Functions**
3. Click **Create Function**
4. Name it: `check-tamper-detection`
5. Copy the code from `supabase/functions/check-tamper-detection/index.ts`
6. Click **Deploy**

---

## Step 3: Setup Internal Scheduler (pg_cron)

**No external cron needed!** We use Supabase's built-in `pg_cron` extension.

### Quick Setup (Recommended - Direct Database Function)

1. **Run Migration 030** in Supabase SQL Editor:
   - File: `supabase/migrations/030_setup_tamper_detection_scheduler.sql`
   - This creates a scheduled job that runs every 10 minutes

2. **Verify it's running:**
   ```sql
   -- Check scheduled jobs
   SELECT * FROM cron.job;
   
   -- Check job run history
   SELECT * FROM cron.job_run_details 
   WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'tamper-detection-check')
   ORDER BY start_time DESC 
   LIMIT 10;
   ```

### Alternative: Using Edge Function (If you deployed it)

If you want to use the Edge Function instead:

1. **Set up Supabase Vault** (for secure storage):
   - Go to **Settings > Vault** in Supabase Dashboard
   - Add secrets:
     - Key: `supabase_url` → Value: `https://your-project.supabase.co`
     - Key: `service_role_key` → Value: Your service role key

2. **Update the migration** to use Edge Function:
   ```sql
   -- Uncomment the Edge Function scheduler in migration 030
   SELECT cron.schedule(
     'tamper-detection-edge-function',
     '*/10 * * * *',
     $$SELECT call_tamper_detection_edge_function()$$
   );
   ```

### Recommended Approach

**Use the direct database function** (`run_tamper_detection_check()`) - it's:
- ✅ Simpler (no Edge Function needed)
- ✅ Faster (no HTTP overhead)
- ✅ More reliable (runs directly in database)
- ✅ No vault configuration needed

---

## Verify It's Working

### Check Scheduled Jobs

```sql
SELECT 
  jobid,
  jobname,
  schedule,
  command,
  nodename,
  nodeport,
  database,
  username,
  active
FROM cron.job
WHERE jobname LIKE '%tamper%';
```

### Check Recent Runs

```sql
SELECT 
  jobid,
  runid,
  job_pid,
  database,
  username,
  command,
  status,
  return_message,
  start_time,
  end_time
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'tamper-detection-check')
ORDER BY start_time DESC
LIMIT 5;
```

### Check Tamper Events

```sql
SELECT 
  device_hostname,
  event_type,
  severity,
  detected_at,
  details->>'minutes_offline' as minutes_offline
FROM tamper_events
WHERE resolved_at IS NULL
ORDER BY detected_at DESC
LIMIT 10;
```

---

## Troubleshooting

### pg_cron not available?

If you get an error about pg_cron:
1. Check if extension is enabled: `SELECT * FROM pg_extension WHERE extname = 'pg_cron';`
2. If not, enable it: `CREATE EXTENSION IF NOT EXISTS pg_cron;`
3. Note: Some Supabase plans may require enabling this extension

### Job not running?

1. Check if job is active:
   ```sql
   SELECT active FROM cron.job WHERE jobname = 'tamper-detection-check';
   ```

2. Check for errors in job runs:
   ```sql
   SELECT return_message, status 
   FROM cron.job_run_details 
   WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'tamper-detection-check')
   AND status = 'failed'
   ORDER BY start_time DESC;
   ```

3. Manually test the function:
   ```sql
   SELECT run_tamper_detection_check();
   ```

### Adjust Schedule

To change the schedule (e.g., every 5 minutes instead of 10):

```sql
-- Remove old schedule
SELECT cron.unschedule('tamper-detection-check');

-- Add new schedule (every 5 minutes)
SELECT cron.schedule(
  'tamper-detection-check',
  '*/5 * * * *',  -- Every 5 minutes
  $$SELECT run_tamper_detection_check()$$
);
```

---

## Summary

✅ **Step 2 (Optional):** Deploy Edge Function if you want HTTP-based approach  
✅ **Step 3 (Required):** Run migration 030 to set up pg_cron scheduler

**Recommended:** Skip Edge Function, use direct database function with pg_cron - it's simpler and faster!
