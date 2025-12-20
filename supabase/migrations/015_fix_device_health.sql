-- Fix migration 015: Create device_health table if it doesn't exist
-- This handles the case where migration 015 failed silently

-- Step 1: Create device_health table (only if it doesn't exist)
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

-- Step 2: Create indexes (if not exist)
CREATE INDEX IF NOT EXISTS idx_device_health_performance_status ON device_health(performance_status);
CREATE INDEX IF NOT EXISTS idx_device_health_updated_at ON device_health(updated_at);

-- Step 3: Create function to calculate performance_status (if not exists)
CREATE OR REPLACE FUNCTION calculate_performance_status(
    p_storage_used_percent INTEGER,
    p_battery_health_percent INTEGER,
    p_crash_error_count INTEGER
) RETURNS TEXT AS $$
BEGIN
    -- Critical conditions
    IF (p_storage_used_percent >= 90) OR 
        (p_battery_health_percent IS NOT NULL AND p_battery_health_percent < 10) OR 
        (p_crash_error_count > 5) THEN
        RETURN 'critical';
    END IF;
    
    -- Warning conditions
    IF (p_storage_used_percent >= 80 AND p_storage_used_percent < 90) OR
        (p_battery_health_percent IS NOT NULL AND p_battery_health_percent >= 10 AND p_battery_health_percent <= 20) OR
        (p_crash_error_count >= 1 AND p_crash_error_count <= 5) THEN
        RETURN 'warning';
    END IF;
    
    -- Good conditions (default)
    RETURN 'good';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Step 4: Create trigger function for updated_at (if not exists)
CREATE OR REPLACE FUNCTION update_device_health_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Create trigger (drop and recreate to avoid duplicates)
DROP TRIGGER IF EXISTS update_device_health_updated_at ON device_health;
CREATE TRIGGER update_device_health_updated_at
BEFORE UPDATE ON device_health
FOR EACH ROW
EXECUTE FUNCTION update_device_health_updated_at();

-- Step 6: Create trigger function for auto-calculating performance_status
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

-- Step 7: Create trigger (drop and recreate to avoid duplicates)
DROP TRIGGER IF EXISTS auto_calculate_performance_status_trigger ON device_health;
CREATE TRIGGER auto_calculate_performance_status_trigger
BEFORE INSERT OR UPDATE ON device_health
FOR EACH ROW
EXECUTE FUNCTION auto_calculate_performance_status();

-- Step 8: Enable RLS
ALTER TABLE device_health ENABLE ROW LEVEL SECURITY;

-- Step 9: Drop existing policy if it exists (to recreate with correct column)
DROP POLICY IF EXISTS "Users see health for accessible devices" ON device_health;

-- Step 10: Create RLS policy with correct column reference
CREATE POLICY "Users see health for accessible devices"
ON device_health FOR SELECT
TO authenticated
USING (
    -- Allow admins to see all device health
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'location_admin')
    )
    -- Allow users to see health for devices in their accessible locations
    OR device_hostname IN (
        SELECT hostname FROM devices
        WHERE location_id IN (
            SELECT location_id FROM devices
            WHERE assigned_teacher IS NOT NULL
        )
    )
);

-- Step 11: Drop and recreate device update policies (to avoid duplicates)
DROP POLICY IF EXISTS "Devices can update their own health" ON device_health;

CREATE POLICY "Devices can update their own health"
ON device_health FOR INSERT
TO anon, authenticated
WITH CHECK (true);

CREATE POLICY "Devices can update their own health"
ON device_health FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- Step 12: Add comments
COMMENT ON TABLE device_health IS 'Stores device health metrics tracked automatically by agents';
COMMENT ON COLUMN device_health.battery_health_percent IS 'Battery health percentage (0-100), NULL if not applicable';
COMMENT ON COLUMN device_health.storage_used_percent IS 'Storage used percentage (0-100)';
COMMENT ON COLUMN device_health.boot_time_avg_seconds IS 'Average boot time in seconds';
COMMENT ON COLUMN device_health.crash_error_count IS 'Number of crashes/errors detected';
COMMENT ON COLUMN device_health.performance_status IS 'Calculated status: good, warning, or critical';




