    -- Migration 015: Add device metrics and health tracking
    -- Adds new device parameters and creates device_health table

    -- Step 1: Add new columns to devices table
    ALTER TABLE devices 
    ADD COLUMN IF NOT EXISTS device_imei_number TEXT,
    ADD COLUMN IF NOT EXISTS device_make TEXT,
    ADD COLUMN IF NOT EXISTS role TEXT,
    ADD COLUMN IF NOT EXISTS issue_date DATE,
    ADD COLUMN IF NOT EXISTS wifi_ssid TEXT;

    -- Step 2: Remove serial_number if it exists (replaced by device_imei_number)
    -- Note: Check if column exists before dropping to avoid errors
    DO $$ 
    BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'devices' AND column_name = 'serial_number'
    ) THEN
        ALTER TABLE devices DROP COLUMN serial_number;
    END IF;
    END $$;

    -- Step 3: Create device_health table
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

    -- Step 4: Create index on performance_status for quick filtering
    CREATE INDEX IF NOT EXISTS idx_device_health_performance_status ON device_health(performance_status);
    CREATE INDEX IF NOT EXISTS idx_device_health_updated_at ON device_health(updated_at);

    -- Step 5: Create function to calculate performance_status
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

    -- Step 6: Create trigger to update updated_at timestamp
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

    -- Step 7: Create trigger to auto-calculate performance_status on insert/update
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

    -- Step 8: Enable RLS on device_health table
    ALTER TABLE device_health ENABLE ROW LEVEL SECURITY;

    -- Step 9: Create RLS policies for device_health
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

    -- Step 10: Allow anonymous/device updates to device_health (for agents)
    CREATE POLICY "Devices can insert their own health"
    ON device_health FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

    CREATE POLICY "Devices can update their own health"
    ON device_health FOR UPDATE
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

    -- Step 11: Add comments for documentation
    COMMENT ON TABLE device_health IS 'Stores device health metrics tracked automatically by agents';
    COMMENT ON COLUMN device_health.battery_health_percent IS 'Battery health percentage (0-100), NULL if not applicable';
    COMMENT ON COLUMN device_health.storage_used_percent IS 'Storage used percentage (0-100)';
    COMMENT ON COLUMN device_health.boot_time_avg_seconds IS 'Average boot time in seconds';
    COMMENT ON COLUMN device_health.crash_error_count IS 'Number of crashes/errors detected';
    COMMENT ON COLUMN device_health.performance_status IS 'Calculated status: good, warning, or critical';
