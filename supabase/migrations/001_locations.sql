-- =====================================================
-- Locations Table
-- Stores school locations with geofence boundaries
-- =====================================================

CREATE TABLE IF NOT EXISTS locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    radius_meters INTEGER NOT NULL DEFAULT 500,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_locations_coords ON locations(latitude, longitude);
CREATE INDEX idx_locations_active ON locations(is_active) WHERE is_active = true;

-- Enable RLS
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;

-- Policy: All authenticated users can read locations
CREATE POLICY "Locations are readable by authenticated users"
    ON locations FOR SELECT
    TO authenticated
    USING (true);

-- Policy: Only admins can modify locations
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

-- Seed 5 locations
INSERT INTO locations (name, address, latitude, longitude, radius_meters) VALUES
('Pune School 1', 'Pune, Maharashtra', 18.5204, 73.8567, 500),
('Mumbai School 1', 'Mumbai, Maharashtra', 19.0760, 72.8777, 500),
('Delhi School 1', 'New Delhi', 28.6139, 77.2090, 500),
('Bangalore School 1', 'Bangalore, Karnataka', 12.9716, 77.5946, 500),
('Hyderabad School 1', 'Hyderabad, Telangana', 17.3850, 78.4867, 500)
ON CONFLICT DO NOTHING;
