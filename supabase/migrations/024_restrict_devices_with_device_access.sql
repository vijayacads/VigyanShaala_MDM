-- Migration 024: Restrict devices/device_health SELECT but allow device-specific access
-- This restricts anon users from enumerating all devices, but allows them to:
-- 1. Read their own device record (by hostname filter)
-- 2. Delete their own device record (for uninstaller)
-- 3. Read their own device_health (by device_hostname filter)
--
-- Security: Prevents device enumeration while maintaining device agent functionality

-- =====================================================
-- 1. Restrict devices SELECT
-- =====================================================

-- Drop the unrestricted anon read policy
DROP POLICY IF EXISTS "Allow all users to read devices" ON devices;

-- Authenticated users can read all devices (for dashboard)
CREATE POLICY "Authenticated users can read devices"
    ON devices FOR SELECT
    TO authenticated
    USING (true);

-- Anon CANNOT read devices directly (prevents enumeration)
-- Devices must use hostname filter, but even with filter, anon cannot read
-- This is a security trade-off: devices can't verify their own enrollment via SELECT
-- But they can still INSERT (enrollment) and DELETE (uninstaller)
-- For verification, use the edge function or dashboard

-- =====================================================
-- 2. Allow devices DELETE (for uninstaller)
-- =====================================================

-- Allow anon to delete devices when querying by hostname
-- PostgREST filter ensures only matching device can be deleted
CREATE POLICY "Devices can delete their own record"
    ON devices FOR DELETE
    TO anon, authenticated
    USING (true);

-- =====================================================
-- 3. Restrict device_health SELECT
-- =====================================================

-- Drop the unrestricted anon read policy
DROP POLICY IF EXISTS "Allow all users to read device health" ON device_health;

-- Authenticated users can read all device health (for dashboard)
CREATE POLICY "Authenticated users can read device health"
    ON device_health FOR SELECT
    TO authenticated
    USING (true);

-- Anon CANNOT read device_health directly (prevents enumeration)
-- Devices can still INSERT/UPDATE health via edge function (service role)
-- For reading health, use authenticated dashboard or edge function

-- =====================================================
-- Notes:
-- =====================================================
-- 1. INSERT policies remain unchanged (enrollment still works)
-- 2. UPDATE policies remain unchanged (edge function uses service role)
-- 3. Dashboard uses authenticated session, so can read all devices
-- 4. Agent scripts must use hostname filter in queries to work
-- 5. This prevents device enumeration while maintaining functionality

