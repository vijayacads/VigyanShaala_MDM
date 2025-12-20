-- Migration 029: Create Tamper Detection System
-- Tracks when devices go offline (possible MDM bypass)

-- Create tamper_events table
CREATE TABLE IF NOT EXISTS tamper_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_hostname TEXT NOT NULL REFERENCES devices(hostname) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- 'offline', 'task_stopped', 'service_stopped', 'network_blocked'
  severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  detected_at TIMESTAMPTZ DEFAULT NOW(),
  last_seen_before TIMESTAMPTZ,
  details JSONB,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES auth.users(id),
  notes TEXT
);

CREATE INDEX idx_tamper_events_device ON tamper_events(device_hostname);
CREATE INDEX idx_tamper_events_unresolved ON tamper_events(resolved_at) WHERE resolved_at IS NULL;
CREATE INDEX idx_tamper_events_detected ON tamper_events(detected_at DESC);
CREATE INDEX idx_tamper_events_severity ON tamper_events(severity) WHERE resolved_at IS NULL;

-- Enable RLS
ALTER TABLE tamper_events ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Authenticated users can read tamper events"
  ON tamper_events FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can modify tamper events"
  ON tamper_events FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE users.id = auth.uid()
      AND (users.raw_user_meta_data->>'role') = ANY (ARRAY['admin', 'location_admin'])
    )
  );

-- Function to detect offline devices (possible bypass)
CREATE OR REPLACE FUNCTION detect_offline_devices()
RETURNS TABLE (
  device_hostname TEXT,
  last_seen TIMESTAMPTZ,
  minutes_offline NUMERIC,
  severity TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.hostname,
    d.last_seen,
    EXTRACT(EPOCH FROM (NOW() - d.last_seen)) / 60 as minutes_offline,
    CASE
      WHEN NOW() - d.last_seen > INTERVAL '60 minutes' THEN 'critical'
      WHEN NOW() - d.last_seen > INTERVAL '30 minutes' THEN 'high'
      WHEN NOW() - d.last_seen > INTERVAL '15 minutes' THEN 'medium'
      ELSE 'low'
    END as severity
  FROM devices d
  WHERE d.last_seen < NOW() - INTERVAL '10 minutes'  -- Offline for more than 10 minutes
    AND d.last_seen IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM tamper_events te
      WHERE te.device_hostname = d.hostname
        AND te.event_type = 'offline'
        AND te.resolved_at IS NULL
        AND te.detected_at > NOW() - INTERVAL '1 hour'  -- Don't duplicate recent alerts
    )
  ORDER BY d.last_seen ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE tamper_events IS 'Tracks MDM bypass attempts and device tampering events';
COMMENT ON FUNCTION detect_offline_devices IS 'Detects devices that have gone offline (possible MDM bypass)';
