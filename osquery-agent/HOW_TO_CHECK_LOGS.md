# How to Check Edge Function Logs

## Where to Find Logs

1. **Go to Supabase Dashboard:**
   - Navigate to your Supabase project
   - Click on **Edge Functions** in the left sidebar
   - Click on **fetch-osquery-data**
   - Click on **Logs** tab

2. **What to Look For:**
   - Look for the most recent log entries (sorted by timestamp, newest first)
   - Each log entry shows:
     - `event_message`: The actual log output
     - `timestamp`: When it occurred
     - `execution_id`: Unique ID for each function invocation

## Current Log Output (Before Update)

You should see logs like:
```
"Edge function invoked"
"Looking up device: VJ_VENUGOPALAN"
"Payload received: {...}"
"Processing device health data: {...}"
"Attempting to upsert device_health: {...}"
"Device health upserted successfully: {...}"
```

## After Deploying Updated Code

After deploying the updated Edge Function, you'll see additional logs:
```
"Device health upserted successfully: {
  ...
  returned_count: 1  <-- NEW
}"
```

Or if verification is needed:
```
"WARNING: Upsert returned no data. Verifying with separate query..."
"Verification successful - data exists: {...}"  <-- NEW
```

## How to Trigger a New Request

To see the updated logs, you need to:

1. **Deploy the updated Edge Function first:**
   ```bash
   supabase functions deploy fetch-osquery-data
   ```

2. **Then trigger a new request:**
   ```powershell
   cd "C:\Program Files\osquery"
   .\send-osquery-data.ps1
   ```

3. **Check logs immediately after** (logs appear within seconds)

## Filtering Logs

In the Supabase Dashboard logs view:
- Use the search/filter box to find specific log messages
- Look for `returned_count` or `verification` to find the new logs
- Check the timestamp to ensure you're looking at the most recent execution

## Troubleshooting

**If you don't see the new logs:**
1. Make sure you deployed the updated Edge Function
2. Make sure you triggered a new request AFTER deployment
3. Check the execution_id - each request has a unique ID
4. Look for the most recent timestamp

**To see all logs for a specific execution:**
- Note the `execution_id` from one log entry
- Filter/search for that execution_id to see all logs from that request

