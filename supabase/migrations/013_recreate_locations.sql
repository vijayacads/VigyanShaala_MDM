-- =====================================================
-- Recreate Locations Table (if accidentally deleted)
-- This migration recreates the locations table with all
-- necessary indexes, RLS policies, and default data
-- =====================================================

-- Drop table if exists (to allow re-running)
DROP TABLE IF EXISTS locations CASCADE;

-- Create locations table
CREATE TABLE locations (
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

-- Policy: Allow anonymous users to read locations (for device enrollment)
CREATE POLICY "Locations are readable by anonymous users"
    ON locations FOR SELECT
    TO anon
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

-- Function to update updated_at timestamp (if not exists)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at
DROP TRIGGER IF EXISTS update_locations_updated_at ON locations;
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

-- Verify the table was created
DO $$
BEGIN
    RAISE NOTICE 'Locations table recreated successfully';
    RAISE NOTICE 'Total locations: %', (SELECT COUNT(*) FROM locations);
END $$;

