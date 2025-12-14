-- Migration 026: Verify RLS is enabled and remove any remaining anon access
-- This ensures devices table is properly secured

-- =====================================================
-- 1. Verify RLS is enabled on devices table
-- =====================================================

-- Enable RLS if not already enabled
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 2. Drop ALL existing SELECT policies on devices
-- =====================================================

-- Drop all possible SELECT policies (comprehensive cleanup)
DROP POLICY IF EXISTS "Devices can read their own record" ON devices;
DROP POLICY IF EXISTS "Allow all users to read devices" ON devices;
DROP POLICY IF EXISTS "Allow anonymous read devices" ON devices;
DROP POLICY IF EXISTS "Teachers see devices in their location" ON devices;
DROP POLICY IF EXISTS "Locations are readable by all" ON devices;
DROP POLICY IF EXISTS "Authenticated users can read devices" ON devices;

-- =====================================================
-- 3. Create ONLY authenticated SELECT policy
-- =====================================================

-- Only authenticated users can read devices
CREATE POLICY "Authenticated users can read devices"
    ON devices FOR SELECT
    TO authenticated
    USING (true);

-- =====================================================
-- 4. Verify RLS is enabled on device_health table
-- =====================================================

-- Enable RLS if not already enabled
ALTER TABLE device_health ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 5. Drop ALL existing SELECT policies on device_health
-- =====================================================

-- Drop all possible SELECT policies (comprehensive cleanup)
DROP POLICY IF EXISTS "Devices can read their own health" ON device_health;
DROP POLICY IF EXISTS "Allow all users to read device health" ON device_health;
DROP POLICY IF EXISTS "Allow anonymous read device health" ON device_health;
DROP POLICY IF EXISTS "Users see health for accessible devices" ON device_health;
DROP POLICY IF EXISTS "Authenticated users can read device health" ON device_health;

-- =====================================================
-- 6. Create ONLY authenticated SELECT policy for device_health
-- =====================================================

-- Only authenticated users can read device_health
CREATE POLICY "Authenticated users can read device health"
    ON device_health FOR SELECT
    TO authenticated
    USING (true);

-- =====================================================
-- 7. Verify final state
-- =====================================================

-- Check that RLS is enabled
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'devices' 
        AND rowsecurity = true
    ) THEN
        RAISE EXCEPTION 'RLS not enabled on devices table!';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'device_health' 
        AND rowsecurity = true
    ) THEN
        RAISE EXCEPTION 'RLS not enabled on device_health table!';
    END IF;
    
    RAISE NOTICE 'RLS is enabled on both tables';
END $$;

