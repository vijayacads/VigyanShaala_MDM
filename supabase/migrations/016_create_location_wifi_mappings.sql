-- =====================================================
-- Create Location WiFi Mappings Table
-- Migration 016: Optional table for mapping WiFi SSIDs to locations
-- =====================================================

-- Create location_wifi_mappings table (optional, for future use)
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_location_wifi_mappings_location ON location_wifi_mappings(location_id);
CREATE INDEX IF NOT EXISTS idx_location_wifi_mappings_ssid ON location_wifi_mappings(wifi_ssid);
CREATE INDEX IF NOT EXISTS idx_location_wifi_mappings_active ON location_wifi_mappings(is_active) WHERE is_active = true;

-- Enable RLS
ALTER TABLE location_wifi_mappings ENABLE ROW LEVEL SECURITY;

-- Policy: All authenticated users can read mappings
CREATE POLICY "Location WiFi mappings are readable by authenticated users"
    ON location_wifi_mappings FOR SELECT
    TO authenticated
    USING (true);

-- Policy: Only admins can modify mappings
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

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_location_wifi_mappings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_location_wifi_mappings_updated_at_trigger ON location_wifi_mappings;
CREATE TRIGGER update_location_wifi_mappings_updated_at_trigger
    BEFORE UPDATE ON location_wifi_mappings
    FOR EACH ROW
    EXECUTE FUNCTION update_location_wifi_mappings_updated_at();

-- Add comments
COMMENT ON TABLE location_wifi_mappings IS 'Maps WiFi SSIDs to locations for automatic location assignment';
COMMENT ON COLUMN location_wifi_mappings.signal_strength_threshold IS 'Minimum signal strength percentage required for location match';




