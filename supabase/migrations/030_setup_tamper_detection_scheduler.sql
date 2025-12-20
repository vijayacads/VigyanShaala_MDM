-- Migration 030: Setup Tamper Detection Scheduler
-- Uses pg_cron (internal to Supabase) to automatically check for offline devices

-- Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Note: pg_net extension is needed for HTTP calls (Edge Function approach)
-- It's usually available in Supabase, but if not, use the direct database function approach instead
-- CREATE EXTENSION IF NOT EXISTS pg_net;

-- Function to call the Edge Function
-- This function will be called by pg_cron
CREATE OR REPLACE FUNCTION call_tamper_detection_edge_function()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  supabase_url TEXT;
  service_role_key TEXT;
  response_status INT;
  response_body TEXT;
BEGIN
  -- Get Supabase URL and service role key from environment
  -- These are available in Supabase as environment variables
  -- For Supabase, we'll use the current_setting to get from vault or use direct values
  -- Note: In production, store these in Supabase Vault for security
  
  -- Get from Supabase settings (you'll need to set these in Supabase Dashboard > Settings > Vault)
  -- For now, we'll construct the URL from current database
  supabase_url := current_setting('app.settings.supabase_url', true);
  service_role_key := current_setting('app.settings.service_role_key', true);
  
  -- If not set in vault, use a placeholder (you must set these in Supabase Vault)
  IF supabase_url IS NULL OR supabase_url = '' THEN
    RAISE WARNING 'Supabase URL not configured in vault. Please set app.settings.supabase_url';
    RETURN;
  END IF;
  
  IF service_role_key IS NULL OR service_role_key = '' THEN
    RAISE WARNING 'Service role key not configured in vault. Please set app.settings.service_role_key';
    RETURN;
  END IF;
  
  -- Call the Edge Function via HTTP POST using pg_net
  -- Note: This requires pg_net extension to be enabled
  SELECT status, content INTO response_status, response_body
  FROM net.http_post(
    url := supabase_url || '/functions/v1/check-tamper-detection',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_role_key
    ),
    body := '{}'::jsonb
  );
  
  -- Log the result
  IF response_status = 200 THEN
    RAISE NOTICE 'Tamper detection check completed successfully: %', response_body;
  ELSE
    RAISE WARNING 'Tamper detection check failed with status %: %', response_status, response_body;
  END IF;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error calling tamper detection Edge Function: %', SQLERRM;
END;
$$;

-- Alternative: Direct database function approach (no Edge Function needed)
-- This calls detect_offline_devices() directly and creates tamper_events
CREATE OR REPLACE FUNCTION run_tamper_detection_check()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  offline_device RECORD;
  events_created INT := 0;
BEGIN
  -- Call detect_offline_devices() function
  FOR offline_device IN 
    SELECT * FROM detect_offline_devices()
  LOOP
    -- Insert tamper event if not already exists (check for unresolved event in last hour)
    INSERT INTO tamper_events (
      device_hostname,
      event_type,
      severity,
      last_seen_before,
      details
    )
    SELECT 
      offline_device.device_hostname,
      'offline',
      offline_device.severity,
      offline_device.last_seen,
      jsonb_build_object(
        'minutes_offline', offline_device.minutes_offline,
        'detected_at', NOW()
      )
    WHERE NOT EXISTS (
      SELECT 1 FROM tamper_events te
      WHERE te.device_hostname = offline_device.device_hostname
        AND te.event_type = 'offline'
        AND te.resolved_at IS NULL
        AND te.detected_at > NOW() - INTERVAL '1 hour'
    );
    
    -- Count if we actually inserted
    IF FOUND THEN
      events_created := events_created + 1;
    END IF;
  END LOOP;
  
  IF events_created > 0 THEN
    RAISE NOTICE 'Created % tamper event(s) for offline devices', events_created;
  END IF;
END;
$$;

-- Schedule the check to run every 10 minutes using pg_cron
-- Using the direct database function (recommended - no Edge Function needed)
SELECT cron.schedule(
  'tamper-detection-check',
  '*/10 * * * *',  -- Every 10 minutes
  $$SELECT run_tamper_detection_check()$$
);

-- If you prefer to use the Edge Function approach instead, uncomment this:
-- SELECT cron.schedule(
--   'tamper-detection-edge-function',
--   '*/10 * * * *',  -- Every 10 minutes
--   $$SELECT call_tamper_detection_edge_function()$$
-- );

COMMENT ON FUNCTION run_tamper_detection_check IS 'Runs tamper detection check and creates events for offline devices';
COMMENT ON FUNCTION call_tamper_detection_edge_function IS 'Calls the Edge Function for tamper detection (requires http extension and vault config)';
