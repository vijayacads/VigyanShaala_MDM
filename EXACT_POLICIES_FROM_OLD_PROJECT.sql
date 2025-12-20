-- =====================================================
-- EXACT RLS POLICIES FROM OLD PROJECT
-- Run this AFTER running COMPLETE_DATABASE_SETUP.sql
-- This will recreate the exact policies from your old project
-- =====================================================

-- =====================================================
-- 1. CHAT_MESSAGES POLICIES
-- =====================================================
DROP POLICY IF EXISTS "Agents can read and send chat messages" ON chat_messages;
DROP POLICY IF EXISTS "Authenticated users can send chat messages" ON chat_messages;
DROP POLICY IF EXISTS "Chat messages are readable by authenticated users" ON chat_messages;

CREATE POLICY "Agents can read and send chat messages"
    ON chat_messages FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Authenticated users can send chat messages"
    ON chat_messages FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Chat messages are readable by authenticated users"
    ON chat_messages FOR SELECT
    TO authenticated
    USING (true);

-- =====================================================
-- 2. DEVICE_COMMANDS POLICIES
-- =====================================================
DROP POLICY IF EXISTS "Devices can update their own commands" ON device_commands;
DROP POLICY IF EXISTS "Users can create commands for accessible devices" ON device_commands;
DROP POLICY IF EXISTS "Users see commands for accessible devices" ON device_commands;

CREATE POLICY "Devices can update their own commands"
    ON device_commands FOR UPDATE
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Users can create commands for accessible devices"
    ON device_commands FOR INSERT
    TO authenticated
    WITH CHECK (
        (EXISTS (
            SELECT 1 FROM auth.users
            WHERE users.id = auth.uid()
            AND (users.raw_user_meta_data->>'role') = ANY (ARRAY['admin', 'location_admin'])
        ))
        OR (device_hostname IN (
            SELECT devices.hostname
            FROM devices
            WHERE devices.location_id IN (
                SELECT devices_1.location_id
                FROM devices devices_1
                WHERE devices_1.assigned_teacher IS NOT NULL
            )
        ))
        OR (target_type = 'all')
    );

CREATE POLICY "Users see commands for accessible devices"
    ON device_commands FOR SELECT
    TO authenticated
    USING (
        (EXISTS (
            SELECT 1 FROM auth.users
            WHERE users.id = auth.uid()
            AND (users.raw_user_meta_data->>'role') = ANY (ARRAY['admin', 'location_admin'])
        ))
        OR (device_hostname IN (
            SELECT devices.hostname
            FROM devices
            WHERE devices.location_id IN (
                SELECT devices_1.location_id
                FROM devices devices_1
                WHERE devices_1.assigned_teacher IS NOT NULL
            )
        ))
        OR (target_type = 'all')
    );

-- =====================================================
-- 3. DEVICE_HEALTH POLICIES
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can read device health" ON device_health;
DROP POLICY IF EXISTS "Devices can insert their own health" ON device_health;
DROP POLICY IF EXISTS "Devices can update their own health" ON device_health;

CREATE POLICY "Authenticated users can read device health"
    ON device_health FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Devices can insert their own health"
    ON device_health FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

CREATE POLICY "Devices can update their own health"
    ON device_health FOR UPDATE
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- =====================================================
-- 4. DEVICES POLICIES
-- =====================================================
DROP POLICY IF EXISTS "Admins can update devices" ON devices;
DROP POLICY IF EXISTS "Allow anonymous device enrollment" ON devices;
DROP POLICY IF EXISTS "Authenticated users can read devices" ON devices;
DROP POLICY IF EXISTS "Devices can delete their own record" ON devices;

CREATE POLICY "Admins can update devices"
    ON devices FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE users.id = auth.uid()
            AND (users.raw_user_meta_data->>'role') = ANY (ARRAY['admin', 'location_admin'])
        )
    );

CREATE POLICY "Allow anonymous device enrollment"
    ON devices FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

CREATE POLICY "Authenticated users can read devices"
    ON devices FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Devices can delete their own record"
    ON devices FOR DELETE
    TO anon, authenticated
    USING (true);

-- =====================================================
-- 5. GEOFENCE_ALERTS POLICIES
-- =====================================================
DROP POLICY IF EXISTS "Users see alerts for accessible devices" ON geofence_alerts;

CREATE POLICY "Users see alerts for accessible devices"
    ON geofence_alerts FOR SELECT
    TO authenticated
    USING (
        (device_id IN (
            SELECT devices.hostname
            FROM devices
            WHERE (devices.assigned_teacher IS NOT NULL)
            OR (devices.location_id IN (
                SELECT devices_1.location_id
                FROM devices devices_1
                WHERE devices_1.assigned_teacher IS NOT NULL
            ))
        ))
        OR (EXISTS (
            SELECT 1 FROM auth.users
            WHERE users.id = auth.uid()
            AND (users.raw_user_meta_data->>'role') = ANY (ARRAY['admin', 'location_admin'])
        ))
    );

-- =====================================================
-- 6. LOCATION_WIFI_MAPPINGS POLICIES
-- =====================================================
DROP POLICY IF EXISTS "Location WiFi mappings are readable by authenticated users" ON location_wifi_mappings;
DROP POLICY IF EXISTS "Only admins can modify location WiFi mappings" ON location_wifi_mappings;

CREATE POLICY "Location WiFi mappings are readable by authenticated users"
    ON location_wifi_mappings FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Only admins can modify location WiFi mappings"
    ON location_wifi_mappings FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE users.id = auth.uid()
            AND (users.raw_user_meta_data->>'role') = 'admin'
        )
    );

-- =====================================================
-- 7. LOCATIONS POLICIES
-- =====================================================
DROP POLICY IF EXISTS "Locations are readable by anonymous users" ON locations;
DROP POLICY IF EXISTS "Locations are readable by authenticated users" ON locations;
DROP POLICY IF EXISTS "Only admins can modify locations" ON locations;

CREATE POLICY "Locations are readable by anonymous users"
    ON locations FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "Locations are readable by authenticated users"
    ON locations FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Only admins can modify locations"
    ON locations FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE users.id = auth.uid()
            AND (users.raw_user_meta_data->>'role') = 'admin'
        )
    );

-- =====================================================
-- 8. SOFTWARE_BLOCKLIST POLICIES
-- =====================================================
DROP POLICY IF EXISTS "Admins manage software blocklists" ON software_blocklist;

CREATE POLICY "Admins manage software blocklists"
    ON software_blocklist FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE users.id = auth.uid()
            AND (users.raw_user_meta_data->>'role') = ANY (ARRAY['admin', 'location_admin'])
        )
    );

-- =====================================================
-- 9. SOFTWARE_INVENTORY POLICIES
-- =====================================================
DROP POLICY IF EXISTS "Users see software for accessible devices" ON software_inventory;

CREATE POLICY "Users see software for accessible devices"
    ON software_inventory FOR SELECT
    TO authenticated
    USING (
        (device_id IN (
            SELECT devices.hostname
            FROM devices
            WHERE (devices.assigned_teacher IS NOT NULL)
            OR (devices.location_id IN (
                SELECT devices_1.location_id
                FROM devices devices_1
                WHERE devices_1.assigned_teacher IS NOT NULL
            ))
        ))
        OR (EXISTS (
            SELECT 1 FROM auth.users
            WHERE users.id = auth.uid()
            AND (users.raw_user_meta_data->>'role') = ANY (ARRAY['admin', 'location_admin'])
        ))
    );

-- =====================================================
-- 10. USER_NOTIFICATIONS POLICIES
-- =====================================================
DROP POLICY IF EXISTS "Allow anon to insert user notifications" ON user_notifications;
DROP POLICY IF EXISTS "Allow anon to select user notifications" ON user_notifications;
DROP POLICY IF EXISTS "Allow anon to update user notifications" ON user_notifications;
DROP POLICY IF EXISTS "Allow service role to insert user notifications" ON user_notifications;
DROP POLICY IF EXISTS "Allow service role to select user notifications" ON user_notifications;
DROP POLICY IF EXISTS "Allow service role to update user notifications" ON user_notifications;

CREATE POLICY "Allow anon to insert user notifications"
    ON user_notifications FOR INSERT
    TO anon
    WITH CHECK (true);

CREATE POLICY "Allow anon to select user notifications"
    ON user_notifications FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "Allow anon to update user notifications"
    ON user_notifications FOR UPDATE
    TO anon
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow service role to insert user notifications"
    ON user_notifications FOR INSERT
    TO service_role
    WITH CHECK (true);

CREATE POLICY "Allow service role to select user notifications"
    ON user_notifications FOR SELECT
    TO service_role
    USING (true);

CREATE POLICY "Allow service role to update user notifications"
    ON user_notifications FOR UPDATE
    TO service_role
    USING (true)
    WITH CHECK (true);

-- =====================================================
-- 11. WEB_ACTIVITY POLICIES
-- =====================================================
DROP POLICY IF EXISTS "Users see web activity for accessible devices" ON web_activity;

CREATE POLICY "Users see web activity for accessible devices"
    ON web_activity FOR SELECT
    TO authenticated
    USING (
        (device_id IN (
            SELECT devices.hostname
            FROM devices
            WHERE (devices.assigned_teacher IS NOT NULL)
            OR (devices.location_id IN (
                SELECT devices_1.location_id
                FROM devices devices_1
                WHERE devices_1.assigned_teacher IS NOT NULL
            ))
        ))
        OR (EXISTS (
            SELECT 1 FROM auth.users
            WHERE users.id = auth.uid()
            AND (users.raw_user_meta_data->>'role') = ANY (ARRAY['admin', 'location_admin'])
        ))
    );

-- =====================================================
-- 12. WEBSITE_BLOCKLIST POLICIES
-- =====================================================
DROP POLICY IF EXISTS "Admins manage website blocklists" ON website_blocklist;

CREATE POLICY "Admins manage website blocklists"
    ON website_blocklist FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE users.id = auth.uid()
            AND (users.raw_user_meta_data->>'role') = ANY (ARRAY['admin', 'location_admin'])
        )
    );

-- =====================================================
-- COMPLETE!
-- =====================================================
-- All policies match your old project exactly
-- =====================================================


