-- Migration 025: Remove any remaining anon SELECT policies
-- This ensures enumeration is completely blocked

-- =====================================================
-- Remove anon SELECT policies from devices
-- =====================================================

-- Drop any anon SELECT policies (in case migration 024 didn't remove them)
DROP POLICY IF EXISTS "Devices can read their own record" ON devices;
DROP POLICY IF EXISTS "Allow all users to read devices" ON devices;
DROP POLICY IF EXISTS "Allow anonymous read devices" ON devices;

-- Ensure only authenticated users can read devices
-- (This policy should already exist from migration 024, but ensure it's there)
DROP POLICY IF EXISTS "Authenticated users can read devices" ON devices;
CREATE POLICY "Authenticated users can read devices"
    ON devices FOR SELECT
    TO authenticated
    USING (true);

-- =====================================================
-- Remove anon SELECT policies from device_health
-- =====================================================

-- Drop any anon SELECT policies
DROP POLICY IF EXISTS "Devices can read their own health" ON device_health;
DROP POLICY IF EXISTS "Allow all users to read device health" ON device_health;
DROP POLICY IF EXISTS "Allow anonymous read device health" ON device_health;

-- Ensure only authenticated users can read device_health
-- (This policy should already exist from migration 024, but ensure it's there)
DROP POLICY IF EXISTS "Authenticated users can read device health" ON device_health;
CREATE POLICY "Authenticated users can read device health"
    ON device_health FOR SELECT
    TO authenticated
    USING (true);

-- =====================================================
-- Verify: After this migration, anon users CANNOT:
-- - SELECT from devices (enumeration blocked)
-- - SELECT from device_health (enumeration blocked)
-- 
-- But anon users CAN still:
-- - INSERT into devices (enrollment)
-- - DELETE from devices (uninstaller, by hostname)
-- - INSERT/UPDATE device_health (via edge function with service role)
-- =====================================================




