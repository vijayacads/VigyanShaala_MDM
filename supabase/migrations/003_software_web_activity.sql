-- Software inventory table
CREATE TABLE IF NOT EXISTS software_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID REFERENCES devices(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    version TEXT,
    path TEXT,
    installed_at TIMESTAMPTZ,
    detected_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_software_device ON software_inventory(device_id);
CREATE INDEX idx_software_name ON software_inventory(name);

-- Software blocklist
CREATE TABLE IF NOT EXISTS software_blocklist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name_pattern TEXT NOT NULL,
    path_pattern TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_blocklist_active ON software_blocklist(is_active) WHERE is_active = true;

-- Web activity table
CREATE TABLE IF NOT EXISTS web_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID REFERENCES devices(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    domain TEXT,
    category TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_web_activity_device ON web_activity(device_id);
CREATE INDEX idx_web_activity_domain ON web_activity(domain);
CREATE INDEX idx_web_activity_timestamp ON web_activity(timestamp DESC);

-- Website blocklist
CREATE TABLE IF NOT EXISTS website_blocklist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    domain_pattern TEXT NOT NULL,
    category TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_website_blocklist_active ON website_blocklist(is_active) WHERE is_active = true;

-- RLS for software and web activity
ALTER TABLE software_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE web_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE software_blocklist ENABLE ROW LEVEL SECURITY;
ALTER TABLE website_blocklist ENABLE ROW LEVEL SECURITY;

-- Policies follow same pattern as devices (location-based access)
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

CREATE POLICY "Admins manage blocklists"
    ON software_blocklist FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'location_admin')
        )
    );

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

