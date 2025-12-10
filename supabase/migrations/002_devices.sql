-- =====================================================
-- Devices Table
-- Stores device information with 6-digit device ID
-- Device IDs: 100000-999999 (using sequence)
-- =====================================================

-- Create sequence for 6-digit device IDs (starts at 100001)
CREATE SEQUENCE IF NOT EXISTS device_id_seq
    START WITH 100001
    INCREMENT BY 1
    MINVALUE 100001
    MAXVALUE 999999
    NO CYCLE;

CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY DEFAULT nextval('device_id_seq'),
    hostname TEXT NOT NULL,
    device_inventory_code TEXT,
    serial_number TEXT,
    fleet_uuid TEXT UNIQUE,
    location_id UUID REFERENCES locations(id) ON DELETE SET NULL,
    host_location TEXT,  -- College, Lab, etc.
    city_town_village TEXT,
    laptop_model TEXT,
    assigned_teacher_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
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

-- Indexes for performance
CREATE INDEX idx_devices_location ON devices(location_id);
CREATE INDEX idx_devices_teacher ON devices(assigned_teacher_id);
CREATE INDEX idx_devices_fleet_uuid ON devices(fleet_uuid);
CREATE INDEX idx_devices_compliance ON devices(compliance_status);
CREATE INDEX idx_devices_last_seen ON devices(last_seen);
CREATE INDEX idx_devices_hostname ON devices(hostname);

-- Enable RLS
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

-- Policy: Teachers can see devices in their assigned location
CREATE POLICY "Teachers see devices in their location"
    ON devices FOR SELECT
    TO authenticated
    USING (
        location_id IN (
            SELECT location_id FROM devices
            WHERE assigned_teacher_id = auth.uid()
        )
        OR
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'location_admin')
        )
    );

-- Policy: Teachers can insert devices (during enrollment)
CREATE POLICY "Teachers can enroll devices"
    ON devices FOR INSERT
    TO authenticated
    WITH CHECK (
        assigned_teacher_id = auth.uid()
        OR
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'location_admin')
        )
    );

-- Policy: Only admins and location admins can update devices
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

-- Update trigger
CREATE TRIGGER update_devices_updated_at
    BEFORE UPDATE ON devices
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- Geofence Alerts Table
-- Stores alerts when devices leave their assigned location boundaries
-- =====================================================

CREATE TABLE IF NOT EXISTS geofence_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id INTEGER REFERENCES devices(id) ON DELETE CASCADE,
    location_id UUID REFERENCES locations(id) ON DELETE CASCADE,
    violation_type TEXT DEFAULT 'outside_bounds',
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    distance_meters INTEGER,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_geofence_alerts_device ON geofence_alerts(device_id);
CREATE INDEX idx_geofence_alerts_location ON geofence_alerts(location_id);
CREATE INDEX idx_geofence_alerts_unresolved ON geofence_alerts(resolved_at) 
    WHERE resolved_at IS NULL;

ALTER TABLE geofence_alerts ENABLE ROW LEVEL SECURITY;

-- Policy: Users see alerts for devices they can access
CREATE POLICY "Users see alerts for accessible devices"
    ON geofence_alerts FOR SELECT
    TO authenticated
    USING (
        device_id IN (
            SELECT id FROM devices
            WHERE assigned_teacher_id = auth.uid()
            OR location_id IN (
                SELECT location_id FROM devices WHERE assigned_teacher_id = auth.uid()
            )
        )
        OR
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'location_admin')
        )
    );
