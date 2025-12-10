-- =====================================================
-- Software Inventory Table
-- Stores installed software on each device (one row per software per device)
-- =====================================================

CREATE TABLE IF NOT EXISTS software_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id INTEGER REFERENCES devices(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    version TEXT,
    path TEXT,
    installed_at TIMESTAMPTZ,
    detected_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_software_device ON software_inventory(device_id);
CREATE INDEX idx_software_name ON software_inventory(name);
CREATE INDEX idx_software_name_version ON software_inventory(name, version);

-- =====================================================
-- Software Blocklist Table
-- Stores software that should not be installed on devices
-- =====================================================

CREATE TABLE IF NOT EXISTS software_blocklist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name_pattern TEXT NOT NULL,
    path_pattern TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_blocklist_active ON software_blocklist(is_active) 
    WHERE is_active = true;

-- =====================================================
-- Web Activity Table
-- Stores website visits/browsing history from devices
-- =====================================================

CREATE TABLE IF NOT EXISTS web_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id INTEGER REFERENCES devices(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    domain TEXT,
    category TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_web_activity_device ON web_activity(device_id);
CREATE INDEX idx_web_activity_domain ON web_activity(domain);
CREATE INDEX idx_web_activity_timestamp ON web_activity(timestamp DESC);
CREATE INDEX idx_web_activity_device_timestamp ON web_activity(device_id, timestamp DESC);

-- =====================================================
-- Website Blocklist Table
-- Stores domains/websites that should be blocked
-- =====================================================

CREATE TABLE IF NOT EXISTS website_blocklist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    domain_pattern TEXT NOT NULL,
    category TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_website_blocklist_active ON website_blocklist(is_active) 
    WHERE is_active = true;

-- =====================================================
-- Row Level Security (RLS) Policies
-- =====================================================

ALTER TABLE software_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE web_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE software_blocklist ENABLE ROW LEVEL SECURITY;
ALTER TABLE website_blocklist ENABLE ROW LEVEL SECURITY;

-- Policy: Users see software for accessible devices
CREATE POLICY "Users see software for accessible devices"
    ON software_inventory FOR SELECT
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

-- Policy: Users see web activity for accessible devices
CREATE POLICY "Users see web activity for accessible devices"
    ON web_activity FOR SELECT
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

-- Policy: Admins manage blocklists
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

-- Policy: Admins manage website blocklists
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
