-- Fix RLS to allow unauthenticated reads for demo/testing
-- Run this in Supabase SQL Editor

-- Option 1: Disable RLS completely (for testing)
ALTER TABLE devices DISABLE ROW LEVEL SECURITY;
ALTER TABLE locations DISABLE ROW LEVEL SECURITY;
ALTER TABLE software_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE web_activity DISABLE ROW LEVEL SECURITY;
ALTER TABLE geofence_alerts DISABLE ROW LEVEL SECURITY;
ALTER TABLE website_blocklist DISABLE ROW LEVEL SECURITY;
ALTER TABLE software_blocklist DISABLE ROW LEVEL SECURITY;

-- Option 2: Add policies that allow anonymous reads (alternative)
-- Uncomment if you want to keep RLS enabled but allow reads

-- DROP POLICY IF EXISTS "Allow anonymous read devices" ON devices;
-- CREATE POLICY "Allow anonymous read devices"
--     ON devices FOR SELECT
--     TO anon, authenticated
--     USING (true);

-- DROP POLICY IF EXISTS "Allow anonymous read locations" ON locations;
-- CREATE POLICY "Allow anonymous read locations"
--     ON locations FOR SELECT
--     TO anon, authenticated
--     USING (true);

-- DROP POLICY IF EXISTS "Allow anonymous read software" ON software_inventory;
-- CREATE POLICY "Allow anonymous read software"
--     ON software_inventory FOR SELECT
--     TO anon, authenticated
--     USING (true);

-- DROP POLICY IF EXISTS "Allow anonymous read web activity" ON web_activity;
-- CREATE POLICY "Allow anonymous read web activity"
--     ON web_activity FOR SELECT
--     TO anon, authenticated
--     USING (true);

-- DROP POLICY IF EXISTS "Allow anonymous read alerts" ON geofence_alerts;
-- CREATE POLICY "Allow anonymous read alerts"
--     ON geofence_alerts FOR SELECT
--     TO anon, authenticated
--     USING (true);

-- DROP POLICY IF EXISTS "Allow anonymous read blocklists" ON website_blocklist;
-- CREATE POLICY "Allow anonymous read blocklists"
--     ON website_blocklist FOR SELECT
--     TO anon, authenticated
--     USING (true);

-- DROP POLICY IF EXISTS "Allow anonymous read software blocklist" ON software_blocklist;
-- CREATE POLICY "Allow anonymous read software blocklist"
--     ON software_blocklist FOR SELECT
--     TO anon, authenticated
--     USING (true);



