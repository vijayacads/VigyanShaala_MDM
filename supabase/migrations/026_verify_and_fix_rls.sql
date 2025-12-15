-- Migration 026: Verify RLS is enabled and ensure proper policies exist
-- This ensures devices table is properly secured while maintaining functionality
--
-- Policy Summary (matches what was working before 025/026):
-- - SELECT: Only authenticated users (prevents enumeration)
-- - INSERT: anon + authenticated (required for PowerShell installer enrollment)
-- - UPDATE: Only authenticated admins (from migration 002, not changed here)
-- - DELETE: anon + authenticated (required for uninstaller, uses hostname filter)

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
-- 7. Ensure INSERT policy exists for device enrollment
-- =====================================================

-- Drop any existing INSERT policies to avoid conflicts
DROP POLICY IF EXISTS "Teachers can enroll devices" ON devices;
DROP POLICY IF EXISTS "Allow anonymous device enrollment" ON devices;

-- Create policy that allows anonymous inserts (for installer scripts)
-- This is required for PowerShell installer to register devices
CREATE POLICY "Allow anonymous device enrollment"
    ON devices FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

-- =====================================================
-- 8. Ensure DELETE policy exists for device uninstaller
-- =====================================================

-- Drop any existing DELETE policies to avoid conflicts
DROP POLICY IF EXISTS "Devices can delete their own record" ON devices;

-- Allow anon to delete devices (for uninstaller)
-- SECURITY NOTE: This allows any anon user to delete any device if they know the hostname.
-- This is a known trade-off for uninstaller functionality. The uninstaller uses
-- ?hostname=eq.$hostname filter, so devices can only delete themselves in practice.
-- However, if hostnames are predictable, this could be exploited.
-- Consider using a device-specific token or edge function for production.
CREATE POLICY "Devices can delete their own record"
    ON devices FOR DELETE
    TO anon, authenticated
    USING (true);

-- =====================================================
-- 9. Note: UPDATE policy remains unchanged
-- =====================================================
-- The UPDATE policy "Admins can update devices" from migration 002 remains in effect.
-- Only authenticated users with admin/location_admin role can update devices.
-- This migration does not modify UPDATE policies.

-- =====================================================
-- 10. Verify final state
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

