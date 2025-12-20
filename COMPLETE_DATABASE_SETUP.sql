-- =====================================================
-- COMPLETE DATABASE SETUP FOR VIGYANSHAALA MDM
-- Project: thqinhphunrflwlshdmx
-- URL: https://thqinhphunrflwlshdmx.supabase.co
-- =====================================================
-- Run this entire file in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- PART 1: BASE TABLES
-- =====================================================

-- 1.1 Locations Table
CREATE TABLE IF NOT EXISTS locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    radius_meters INTEGER NOT NULL DEFAULT 1000,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_locations_coords ON locations(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_locations_active ON locations(is_active) WHERE is_active = true;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_locations_updated_at
    BEFORE UPDATE ON locations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Seed default locations
INSERT INTO locations (name, address, latitude, longitude, radius_meters) VALUES
('Pune School 1', 'Pune, Maharashtra', 18.5204, 73.8567, 1000),
('Mumbai School 1', 'Mumbai, Maharashtra', 19.0760, 72.8777, 1000),
('Delhi School 1', 'New Delhi', 28.6139, 77.2090, 1000),
('Bangalore School 1', 'Bangalore, Karnataka', 12.9716, 77.5946, 1000),
('Hyderabad School 1', 'Hyderabad, Telangana', 17.3850, 78.4867, 1000)
ON CONFLICT DO NOTHING;

-- 1.2 Devices Table (with hostname as PK)
CREATE TABLE IF NOT EXISTS devices (
    hostname TEXT PRIMARY KEY,
    device_inventory_code TEXT,
    device_imei_number TEXT,
    device_make TEXT,
    host_location TEXT,
    city_town_village TEXT,
    laptop_model TEXT,
    location_id UUID REFERENCES locations(id) ON DELETE SET NULL,
    assigned_teacher TEXT,
    assigned_student_leader TEXT,
    role TEXT,
    issue_date DATE,
    wifi_ssid TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    os_version TEXT,
    compliance_status TEXT DEFAULT 'unknown' 
        CHECK (compliance_status IN ('compliant', 'non_compliant', 'unknown')),
    last_seen TIMESTAMPTZ,
    enrollment_date TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_devices_location ON devices(location_id);
CREATE INDEX IF NOT EXISTS idx_devices_teacher ON devices(assigned_teacher);
CREATE INDEX IF NOT EXISTS idx_devices_student_leader ON devices(assigned_student_leader);
CREATE INDEX IF NOT EXISTS idx_devices_compliance ON devices(compliance_status);
CREATE INDEX IF NOT EXISTS idx_devices_last_seen ON devices(last_seen);
CREATE INDEX IF NOT EXISTS idx_devices_hostname ON devices(hostname);
CREATE INDEX IF NOT EXISTS idx_devices_inventory_code ON devices(device_inventory_code);

CREATE TRIGGER update_devices_updated_at
    BEFORE UPDATE ON devices
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 1.3 Geofence Alerts Table
CREATE TABLE IF NOT EXISTS geofence_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT REFERENCES devices(hostname) ON DELETE CASCADE,
    location_id UUID REFERENCES locations(id) ON DELETE CASCADE,
    violation_type TEXT DEFAULT 'outside_bounds',
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    distance_meters INTEGER,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_geofence_alerts_device ON geofence_alerts(device_id);
CREATE INDEX IF NOT EXISTS idx_geofence_alerts_location ON geofence_alerts(location_id);
CREATE INDEX IF NOT EXISTS idx_geofence_alerts_unresolved ON geofence_alerts(resolved_at) 
    WHERE resolved_at IS NULL;

-- 1.4 Software Inventory Table
CREATE TABLE IF NOT EXISTS software_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT REFERENCES devices(hostname) ON DELETE CASCADE,
    name TEXT NOT NULL,
    version TEXT,
    path TEXT,
    installed_at TIMESTAMPTZ,
    detected_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_software_device ON software_inventory(device_id);
CREATE INDEX IF NOT EXISTS idx_software_name ON software_inventory(name);
CREATE INDEX IF NOT EXISTS idx_software_name_version ON software_inventory(name, version);

-- 1.5 Software Blocklist Table
CREATE TABLE IF NOT EXISTS software_blocklist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name_pattern TEXT NOT NULL,
    path_pattern TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_blocklist_active ON software_blocklist(is_active) 
    WHERE is_active = true;

-- 1.6 Web Activity Table
CREATE TABLE IF NOT EXISTS web_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT REFERENCES devices(hostname) ON DELETE CASCADE,
    url TEXT NOT NULL,
    domain TEXT,
    category TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_web_activity_device ON web_activity(device_id);
CREATE INDEX IF NOT EXISTS idx_web_activity_domain ON web_activity(domain);
CREATE INDEX IF NOT EXISTS idx_web_activity_timestamp ON web_activity(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_web_activity_device_timestamp ON web_activity(device_id, timestamp DESC);

-- 1.7 Website Blocklist Table
CREATE TABLE IF NOT EXISTS website_blocklist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    domain_pattern TEXT NOT NULL,
    category TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_website_blocklist_active ON website_blocklist(is_active) 
    WHERE is_active = true;

-- 1.8 Device Health Table
CREATE TABLE IF NOT EXISTS device_health (
    device_hostname TEXT PRIMARY KEY REFERENCES devices(hostname) ON DELETE CASCADE,
    battery_health_percent INTEGER CHECK (battery_health_percent >= 0 AND battery_health_percent <= 100),
    storage_used_percent INTEGER CHECK (storage_used_percent >= 0 AND storage_used_percent <= 100),
    boot_time_avg_seconds INTEGER,
    crash_error_count INTEGER DEFAULT 0,
    performance_status TEXT CHECK (performance_status IN ('good', 'warning', 'critical')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_health_performance_status ON device_health(performance_status);
CREATE INDEX IF NOT EXISTS idx_device_health_updated_at ON device_health(updated_at);

-- Device Health Functions
CREATE OR REPLACE FUNCTION calculate_performance_status(
    p_storage_used_percent INTEGER,
    p_battery_health_percent INTEGER,
    p_crash_error_count INTEGER
) RETURNS TEXT AS $$
BEGIN
    IF (p_storage_used_percent >= 90) OR 
        (p_battery_health_percent IS NOT NULL AND p_battery_health_percent < 10) OR 
        (p_crash_error_count > 5) THEN
        RETURN 'critical';
    END IF;
    
    IF (p_storage_used_percent >= 80 AND p_storage_used_percent < 90) OR
        (p_battery_health_percent IS NOT NULL AND p_battery_health_percent >= 10 AND p_battery_health_percent <= 20) OR
        (p_crash_error_count >= 1 AND p_crash_error_count <= 5) THEN
        RETURN 'warning';
    END IF;
    
    RETURN 'good';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION update_device_health_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_device_health_updated_at
BEFORE UPDATE ON device_health
FOR EACH ROW
EXECUTE FUNCTION update_device_health_updated_at();

CREATE OR REPLACE FUNCTION auto_calculate_performance_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.performance_status = calculate_performance_status(
        NEW.storage_used_percent,
        NEW.battery_health_percent,
        NEW.crash_error_count
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER auto_calculate_performance_status_trigger
BEFORE INSERT OR UPDATE ON device_health
FOR EACH ROW
EXECUTE FUNCTION auto_calculate_performance_status();

-- 1.9 Location WiFi Mappings Table
CREATE TABLE IF NOT EXISTS location_wifi_mappings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
    wifi_ssid TEXT NOT NULL,
    signal_strength_threshold INTEGER DEFAULT 50,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(location_id, wifi_ssid)
);

CREATE INDEX IF NOT EXISTS idx_location_wifi_mappings_location ON location_wifi_mappings(location_id);
CREATE INDEX IF NOT EXISTS idx_location_wifi_mappings_ssid ON location_wifi_mappings(wifi_ssid);
CREATE INDEX IF NOT EXISTS idx_location_wifi_mappings_active ON location_wifi_mappings(is_active) WHERE is_active = true;

CREATE OR REPLACE FUNCTION update_location_wifi_mappings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_location_wifi_mappings_updated_at_trigger
    BEFORE UPDATE ON location_wifi_mappings
    FOR EACH ROW
    EXECUTE FUNCTION update_location_wifi_mappings_updated_at();

-- 1.10 Device Commands Table
CREATE TABLE IF NOT EXISTS device_commands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_hostname TEXT REFERENCES devices(hostname) ON DELETE CASCADE,
  command_type TEXT NOT NULL CHECK (command_type IN ('lock', 'unlock', 'clear_cache', 'buzz', 'broadcast_message')),
  message TEXT,
  target_type TEXT CHECK (target_type IN ('single', 'location', 'all')),
  target_location_id UUID REFERENCES locations(id) ON DELETE CASCADE,
  duration INTEGER,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'dismissed', 'expired')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  executed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  error_message TEXT,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_device_commands_device_hostname ON device_commands(device_hostname);
CREATE INDEX IF NOT EXISTS idx_device_commands_status ON device_commands(status);
CREATE INDEX IF NOT EXISTS idx_device_commands_command_type ON device_commands(command_type);
CREATE INDEX IF NOT EXISTS idx_device_commands_pending ON device_commands(device_hostname, status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_device_commands_target_location ON device_commands(target_location_id) WHERE target_location_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_device_commands_expires_at ON device_commands(expires_at) WHERE expires_at IS NOT NULL;

-- 1.11 Chat Messages Table
CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_hostname TEXT NOT NULL REFERENCES devices(hostname) ON DELETE CASCADE,
    sender TEXT NOT NULL CHECK (sender IN ('center', 'device')),
    message TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    read_status BOOLEAN DEFAULT false,
    sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_device ON chat_messages(device_hostname);
CREATE INDEX IF NOT EXISTS idx_chat_messages_timestamp ON chat_messages(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_read ON chat_messages(read_status) WHERE read_status = false;

CREATE OR REPLACE FUNCTION cleanup_old_chat_messages()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM chat_messages
    WHERE timestamp < NOW() - INTERVAL '10 days';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cleanup_chat_messages_trigger
    AFTER INSERT ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION cleanup_old_chat_messages();

-- 1.12 User Notifications Table
CREATE TABLE IF NOT EXISTS user_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_hostname TEXT NOT NULL,
    username TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('buzzer', 'toast')),
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    error_message TEXT,
    CONSTRAINT user_notifications_device_username_check CHECK (device_hostname IS NOT NULL AND username IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_user_notifications_device_username_status 
    ON user_notifications(device_hostname, username, status);
CREATE INDEX IF NOT EXISTS idx_user_notifications_created_at 
    ON user_notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_notifications_status 
    ON user_notifications(status) WHERE status = 'pending';

-- =====================================================
-- PART 2: ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- 2.1 Enable RLS on all tables
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE geofence_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE software_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE web_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE software_blocklist ENABLE ROW LEVEL SECURITY;
ALTER TABLE website_blocklist ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_health ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_wifi_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

-- 2.2 Locations Policies
DROP POLICY IF EXISTS "Locations are readable by authenticated users" ON locations;
DROP POLICY IF EXISTS "Locations are readable by anonymous users" ON locations;
DROP POLICY IF EXISTS "Locations are readable by all" ON locations;
DROP POLICY IF EXISTS "Only admins can modify locations" ON locations;

CREATE POLICY "Locations are readable by authenticated users"
    ON locations FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Locations are readable by anonymous users"
    ON locations FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "Only admins can modify locations"
    ON locations FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' = 'admin'
        )
    );

-- 2.3 Devices Policies (Exact match from old project)
DROP POLICY IF EXISTS "Teachers see devices in their location" ON devices;
DROP POLICY IF EXISTS "Teachers can enroll devices" ON devices;
DROP POLICY IF EXISTS "Allow anonymous device enrollment" ON devices;
DROP POLICY IF EXISTS "Admins can update devices" ON devices;
DROP POLICY IF EXISTS "Devices can delete their own record" ON devices;
DROP POLICY IF EXISTS "Allow all users to read devices" ON devices;
DROP POLICY IF EXISTS "Authenticated users can read devices" ON devices;

CREATE POLICY "Authenticated users can read devices"
    ON devices FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Allow anonymous device enrollment"
    ON devices FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

CREATE POLICY "Admins can update devices"
    ON devices FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'location_admin')
        )
    );

CREATE POLICY "Devices can delete their own record"
    ON devices FOR DELETE
    TO anon, authenticated
    USING (true);

-- 2.4 Geofence Alerts Policies (Exact match from old project)
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

-- 2.5 Software Inventory Policies (Exact match from old project)
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

-- 2.6 Web Activity Policies (Exact match from old project)
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

-- 2.7 Software Blocklist Policies
DROP POLICY IF EXISTS "Admins manage software blocklists" ON software_blocklist;

CREATE POLICY "Admins manage software blocklists"
    ON software_blocklist FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'location_admin')
        )
    );

-- 2.8 Website Blocklist Policies
DROP POLICY IF EXISTS "Admins manage website blocklists" ON website_blocklist;

CREATE POLICY "Admins manage website blocklists"
    ON website_blocklist FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'location_admin')
        )
    );

-- 2.9 Device Health Policies (Exact match from old project)
DROP POLICY IF EXISTS "Users see health for accessible devices" ON device_health;
DROP POLICY IF EXISTS "Devices can insert their own health" ON device_health;
DROP POLICY IF EXISTS "Devices can update their own health" ON device_health;
DROP POLICY IF EXISTS "Allow all users to read device health" ON device_health;
DROP POLICY IF EXISTS "Authenticated users can read device health" ON device_health;

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

-- 2.10 Location WiFi Mappings Policies
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
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' = 'admin'
        )
    );

-- 2.11 Device Commands Policies (Exact match from old project)
DROP POLICY IF EXISTS "Users see commands for accessible devices" ON device_commands;
DROP POLICY IF EXISTS "Users can create commands for accessible devices" ON device_commands;
DROP POLICY IF EXISTS "Devices can update their own commands" ON device_commands;

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

CREATE POLICY "Devices can update their own commands"
  ON device_commands FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- 2.12 Chat Messages Policies
DROP POLICY IF EXISTS "Chat messages are readable by authenticated users" ON chat_messages;
DROP POLICY IF EXISTS "Agents can read and send chat messages" ON chat_messages;
DROP POLICY IF EXISTS "Authenticated users can send chat messages" ON chat_messages;

CREATE POLICY "Chat messages are readable by authenticated users"
    ON chat_messages FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Agents can read and send chat messages"
    ON chat_messages FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Authenticated users can send chat messages"
    ON chat_messages FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- 2.13 User Notifications Policies
DROP POLICY IF EXISTS "Allow service role to insert user notifications" ON user_notifications;
DROP POLICY IF EXISTS "Allow service role to update user notifications" ON user_notifications;
DROP POLICY IF EXISTS "Allow service role to select user notifications" ON user_notifications;
DROP POLICY IF EXISTS "Allow anon to insert user notifications" ON user_notifications;
DROP POLICY IF EXISTS "Allow anon to update user notifications" ON user_notifications;
DROP POLICY IF EXISTS "Allow anon to select user notifications" ON user_notifications;

CREATE POLICY "Allow service role to insert user notifications"
    ON user_notifications
    FOR INSERT
    TO service_role
    WITH CHECK (true);

CREATE POLICY "Allow service role to update user notifications"
    ON user_notifications
    FOR UPDATE
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow service role to select user notifications"
    ON user_notifications
    FOR SELECT
    TO service_role
    USING (true);

CREATE POLICY "Allow anon to insert user notifications"
    ON user_notifications
    FOR INSERT
    TO anon
    WITH CHECK (true);

CREATE POLICY "Allow anon to update user notifications"
    ON user_notifications
    FOR UPDATE
    TO anon
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow anon to select user notifications"
    ON user_notifications
    FOR SELECT
    TO anon
    USING (true);

-- =====================================================
-- PART 3: FUNCTIONS
-- =====================================================

-- 3.1 Device Enrollment Function (SECURITY DEFINER - bypasses RLS)
CREATE OR REPLACE FUNCTION public.enroll_device(
    p_hostname TEXT,
    p_device_inventory_code TEXT DEFAULT NULL,
    p_device_imei_number TEXT DEFAULT NULL,
    p_device_make TEXT DEFAULT NULL,
    p_host_location TEXT DEFAULT NULL,
    p_city_town_village TEXT DEFAULT NULL,
    p_laptop_model TEXT DEFAULT NULL,
    p_latitude DECIMAL(10, 8) DEFAULT NULL,
    p_longitude DECIMAL(11, 8) DEFAULT NULL,
    p_os_version TEXT DEFAULT NULL,
    p_assigned_teacher TEXT DEFAULT NULL,
    p_assigned_student_leader TEXT DEFAULT NULL,
    p_role TEXT DEFAULT NULL,
    p_issue_date DATE DEFAULT NULL,
    p_wifi_ssid TEXT DEFAULT NULL,
    p_compliance_status TEXT DEFAULT 'unknown',
    p_last_seen TIMESTAMPTZ DEFAULT NOW(),
    p_location_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result JSONB;
BEGIN
    INSERT INTO devices (
        hostname,
        device_inventory_code,
        device_imei_number,
        device_make,
        host_location,
        city_town_village,
        laptop_model,
        latitude,
        longitude,
        os_version,
        assigned_teacher,
        assigned_student_leader,
        role,
        issue_date,
        wifi_ssid,
        compliance_status,
        last_seen,
        location_id
    ) VALUES (
        p_hostname,
        p_device_inventory_code,
        p_device_imei_number,
        p_device_make,
        p_host_location,
        p_city_town_village,
        p_laptop_model,
        p_latitude,
        p_longitude,
        p_os_version,
        p_assigned_teacher,
        p_assigned_student_leader,
        p_role,
        p_issue_date,
        p_wifi_ssid,
        p_compliance_status,
        p_last_seen,
        p_location_id
    )
    ON CONFLICT (hostname) DO UPDATE SET
        device_inventory_code = EXCLUDED.device_inventory_code,
        device_imei_number = EXCLUDED.device_imei_number,
        device_make = EXCLUDED.device_make,
        host_location = EXCLUDED.host_location,
        city_town_village = EXCLUDED.city_town_village,
        laptop_model = EXCLUDED.laptop_model,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        os_version = EXCLUDED.os_version,
        assigned_teacher = EXCLUDED.assigned_teacher,
        assigned_student_leader = EXCLUDED.assigned_student_leader,
        role = EXCLUDED.role,
        issue_date = EXCLUDED.issue_date,
        wifi_ssid = EXCLUDED.wifi_ssid,
        compliance_status = EXCLUDED.compliance_status,
        last_seen = EXCLUDED.last_seen,
        location_id = EXCLUDED.location_id,
        updated_at = NOW();
    
    SELECT to_jsonb(d.*) INTO v_result
    FROM devices d
    WHERE d.hostname = p_hostname;
    
    RETURN v_result;
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Invalid location_id provided';
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Enrollment failed: %', SQLERRM;
END;
$$;

GRANT EXECUTE ON FUNCTION public.enroll_device TO anon, authenticated;

-- =====================================================
-- PART 4: REALTIME
-- =====================================================

-- 4.1 Enable Realtime for device_commands table
ALTER PUBLICATION supabase_realtime ADD TABLE device_commands;

-- =====================================================
-- PART 5: VERIFICATION
-- =====================================================

-- Verify tables exist
DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name IN (
        'locations', 'devices', 'geofence_alerts', 'software_inventory',
        'web_activity', 'device_health', 'device_commands', 'chat_messages',
        'user_notifications', 'location_wifi_mappings'
    );
    
    IF table_count < 10 THEN
        RAISE EXCEPTION 'Not all tables were created. Found: %', table_count;
    ELSE
        RAISE NOTICE 'All tables created successfully. Total: %', table_count;
    END IF;
END $$;

-- Verify RLS is enabled
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
    
    RAISE NOTICE 'RLS is enabled on all tables';
END $$;

-- Verify enroll_device function exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_schema = 'public' 
        AND routine_name = 'enroll_device'
    ) THEN
        RAISE EXCEPTION 'enroll_device function not found!';
    ELSE
        RAISE NOTICE 'enroll_device function created successfully';
    END IF;
END $$;

-- Verify Realtime is enabled
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'device_commands'
    ) THEN
        RAISE EXCEPTION 'Realtime not enabled for device_commands!';
    ELSE
        RAISE NOTICE 'Realtime enabled for device_commands';
    END IF;
END $$;

-- =====================================================
-- COMPLETE!
-- =====================================================
-- All tables, policies, functions, and Realtime are set up.
-- Next steps:
-- 1. Create admin user via Dashboard > Authentication > Users
-- 2. Update dashboard .env with new Supabase URL and anon key
-- 3. Update installer scripts with new Supabase URL and anon key
-- =====================================================

