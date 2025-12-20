-- Migration 022: Allow anonymous users to read device_health (needed for dashboard)
-- This allows the dashboard to display device health without authentication
-- Similar to migration 009 which allows anon read access to devices table

-- Drop existing SELECT policy if it exists
DROP POLICY IF EXISTS "Users see health for accessible devices" ON device_health;

-- Create policy that allows anonymous and authenticated users to read all device health
CREATE POLICY "Allow all users to read device health"
    ON device_health FOR SELECT
    TO anon, authenticated
    USING (true);

-- Note: This matches the policy on devices table (migration 009)
-- The dashboard uses anon key, so it needs this policy to display health data




