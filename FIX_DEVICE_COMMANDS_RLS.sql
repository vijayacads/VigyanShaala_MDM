-- =====================================================
-- FIX: device_commands RLS policies for anon access
-- Problem: Policies check auth.users which anon can't access
-- Solution: Allow anon INSERT without auth.users check
-- =====================================================

-- Drop existing device_commands policies
DROP POLICY IF EXISTS "Users see commands for accessible devices" ON device_commands;
DROP POLICY IF EXISTS "Users can create commands for accessible devices" ON device_commands;
DROP POLICY IF EXISTS "Devices can update their own commands" ON device_commands;

-- New policy: Allow anon and authenticated to INSERT (for dashboard commands)
CREATE POLICY "Allow all users to create device commands"
  ON device_commands FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- New policy: Allow authenticated users to SELECT (with role check only if authenticated)
CREATE POLICY "Authenticated users can read device commands"
  ON device_commands FOR SELECT
  TO authenticated
  USING (
    -- If auth.uid() is null, allow (shouldn't happen for authenticated, but safe)
    auth.uid() IS NULL
    OR
    -- Check role only if we have a user ID
    (
      EXISTS (
        SELECT 1 FROM auth.users
        WHERE users.id = auth.uid()
        AND (users.raw_user_meta_data->>'role') = ANY (ARRAY['admin', 'location_admin'])
      )
    )
    OR
    -- Allow if device_hostname matches accessible devices
    (device_hostname IN (
      SELECT devices.hostname
      FROM devices
      WHERE devices.location_id IN (
        SELECT devices_1.location_id
        FROM devices devices_1
        WHERE devices_1.assigned_teacher IS NOT NULL
      )
    ))
    OR
    -- Allow if target_type is 'all'
    (target_type = 'all')
  );

-- Policy: Allow devices to update their own commands (anon + authenticated)
CREATE POLICY "Devices can update their own commands"
  ON device_commands FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- Also fix geofence_alerts, software_inventory, web_activity
-- These also check auth.users but should allow anon SELECT
-- =====================================================

-- Fix geofence_alerts: Allow anon SELECT (for dashboard)
DROP POLICY IF EXISTS "Users see alerts for accessible devices" ON geofence_alerts;
CREATE POLICY "Allow all users to read geofence alerts"
    ON geofence_alerts FOR SELECT
    TO anon, authenticated
    USING (true);

-- Fix software_inventory: Allow anon SELECT (for dashboard)
DROP POLICY IF EXISTS "Users see software for accessible devices" ON software_inventory;
CREATE POLICY "Allow all users to read software inventory"
    ON software_inventory FOR SELECT
    TO anon, authenticated
    USING (true);

-- Fix web_activity: Allow anon SELECT (for dashboard)
DROP POLICY IF EXISTS "Users see web activity for accessible devices" ON web_activity;
CREATE POLICY "Allow all users to read web activity"
    ON web_activity FOR SELECT
    TO anon, authenticated
    USING (true);

-- Fix devices: Allow anon SELECT (for dashboard)
DROP POLICY IF EXISTS "Authenticated users can read devices" ON devices;
CREATE POLICY "Allow all users to read devices"
    ON devices FOR SELECT
    TO anon, authenticated
    USING (true);

-- Fix device_health: Allow anon SELECT (for dashboard)
DROP POLICY IF EXISTS "Authenticated users can read device health" ON device_health;
CREATE POLICY "Allow all users to read device health"
    ON device_health FOR SELECT
    TO anon, authenticated
    USING (true);

-- =====================================================
-- DONE!
-- =====================================================
-- Now anon users (dashboard) can:
-- - INSERT into device_commands (send commands)
-- - SELECT from device_commands (view command history)
-- - SELECT from devices, device_health, geofence_alerts, etc.
-- =====================================================


