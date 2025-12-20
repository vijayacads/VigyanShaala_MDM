-- =====================================================
-- FIX ALL UNRESTRICTED TABLES - Match Old Project
-- Based on old project image showing these as "UNRESTRICTED":
-- - device_commands
-- - geofence_alerts
-- - software_blocklist
-- - software_inventory
-- - web_activity
-- - website_blocklist
-- =====================================================

-- =====================================================
-- 1. DEVICE_COMMANDS - Allow anon INSERT/UPDATE/SELECT
-- =====================================================
DROP POLICY IF EXISTS "Users see commands for accessible devices" ON device_commands;
DROP POLICY IF EXISTS "Users can create commands for accessible devices" ON device_commands;
DROP POLICY IF EXISTS "Devices can update their own commands" ON device_commands;
DROP POLICY IF EXISTS "Allow all users to create device commands" ON device_commands;
DROP POLICY IF EXISTS "Authenticated users can read device commands" ON device_commands;

CREATE POLICY "Allow all users to create device commands"
  ON device_commands FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Allow all users to read device commands"
  ON device_commands FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Allow all users to update device commands"
  ON device_commands FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- 2. GEOFENCE_ALERTS - Allow anon SELECT
-- =====================================================
DROP POLICY IF EXISTS "Users see alerts for accessible devices" ON geofence_alerts;
DROP POLICY IF EXISTS "Allow all users to read geofence alerts" ON geofence_alerts;

CREATE POLICY "Allow all users to read geofence alerts"
    ON geofence_alerts FOR SELECT
    TO anon, authenticated
    USING (true);

-- =====================================================
-- 3. SOFTWARE_BLOCKLIST - Allow anon ALL operations
-- =====================================================
DROP POLICY IF EXISTS "Admins manage software blocklists" ON software_blocklist;
DROP POLICY IF EXISTS "Allow all users to read software blocklist" ON software_blocklist;
DROP POLICY IF EXISTS "Allow all users to manage software blocklist" ON software_blocklist;

CREATE POLICY "Allow all users to manage software blocklist"
    ON software_blocklist FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- =====================================================
-- 4. SOFTWARE_INVENTORY - Allow anon SELECT
-- =====================================================
DROP POLICY IF EXISTS "Users see software for accessible devices" ON software_inventory;
DROP POLICY IF EXISTS "Allow all users to read software inventory" ON software_inventory;

CREATE POLICY "Allow all users to read software inventory"
    ON software_inventory FOR SELECT
    TO anon, authenticated
    USING (true);

-- =====================================================
-- 5. WEB_ACTIVITY - Allow anon SELECT
-- =====================================================
DROP POLICY IF EXISTS "Users see web activity for accessible devices" ON web_activity;
DROP POLICY IF EXISTS "Allow all users to read web activity" ON web_activity;

CREATE POLICY "Allow all users to read web activity"
    ON web_activity FOR SELECT
    TO anon, authenticated
    USING (true);

-- =====================================================
-- 6. WEBSITE_BLOCKLIST - Allow anon ALL operations
-- =====================================================
DROP POLICY IF EXISTS "Admins manage website blocklists" ON website_blocklist;
DROP POLICY IF EXISTS "Allow all users to read website blocklist" ON website_blocklist;
DROP POLICY IF EXISTS "Allow all users to manage website blocklist" ON website_blocklist;

CREATE POLICY "Allow all users to manage website blocklist"
    ON website_blocklist FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- =====================================================
-- DONE!
-- =====================================================
-- All unrestricted tables now allow anon access:
-- - device_commands: INSERT/UPDATE/SELECT
-- - geofence_alerts: SELECT
-- - software_blocklist: ALL (INSERT/UPDATE/DELETE/SELECT)
-- - software_inventory: SELECT
-- - web_activity: SELECT
-- - website_blocklist: ALL (INSERT/UPDATE/DELETE/SELECT)
-- =====================================================


