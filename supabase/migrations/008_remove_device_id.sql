-- Remove device ID column completely
-- Use hostname as primary key instead

-- Step 1: Drop RLS policies that depend on device_id before modifying columns

-- Drop geofence_alerts policy
DROP POLICY IF EXISTS "Users see alerts for accessible devices" ON geofence_alerts;

-- Drop software_inventory policy  
DROP POLICY IF EXISTS "Users see software for accessible devices" ON software_inventory;

-- Drop web_activity policy
DROP POLICY IF EXISTS "Users see web activity for accessible devices" ON web_activity;

-- Step 2: Update child tables to use TEXT for device_id (will store hostname)
-- First, add temporary column for hostname in each child table

-- Geofence alerts
DO $$
BEGIN
    -- Add hostname column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'geofence_alerts' AND column_name = 'device_hostname') THEN
        ALTER TABLE geofence_alerts ADD COLUMN device_hostname TEXT;
        
        -- Migrate: copy hostname from devices table
        UPDATE geofence_alerts ga
        SET device_hostname = d.hostname
        FROM devices d
        WHERE ga.device_id::text = d.id::text;
        
        -- Drop old column and constraint
        ALTER TABLE geofence_alerts DROP CONSTRAINT IF EXISTS geofence_alerts_device_id_fkey CASCADE;
        ALTER TABLE geofence_alerts DROP COLUMN IF EXISTS device_id CASCADE;
        
        -- Rename to device_id (but now it's TEXT and holds hostname)
        ALTER TABLE geofence_alerts RENAME COLUMN device_hostname TO device_id;
        
        -- Change type to TEXT
        ALTER TABLE geofence_alerts ALTER COLUMN device_id TYPE TEXT;
    END IF;
END $$;

-- Software inventory  
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'software_inventory' AND column_name = 'device_hostname') THEN
        ALTER TABLE software_inventory ADD COLUMN device_hostname TEXT;
        
        UPDATE software_inventory si
        SET device_hostname = d.hostname
        FROM devices d
        WHERE si.device_id::text = d.id::text;
        
        ALTER TABLE software_inventory DROP CONSTRAINT IF EXISTS software_inventory_device_id_fkey CASCADE;
        ALTER TABLE software_inventory DROP COLUMN IF EXISTS device_id CASCADE;
        ALTER TABLE software_inventory RENAME COLUMN device_hostname TO device_id;
        ALTER TABLE software_inventory ALTER COLUMN device_id TYPE TEXT;
    END IF;
END $$;

-- Web activity
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'web_activity' AND column_name = 'device_hostname') THEN
        ALTER TABLE web_activity ADD COLUMN device_hostname TEXT;
        
        UPDATE web_activity wa
        SET device_hostname = d.hostname
        FROM devices d
        WHERE wa.device_id::text = d.id::text;
        
        ALTER TABLE web_activity DROP CONSTRAINT IF EXISTS web_activity_device_id_fkey CASCADE;
        ALTER TABLE web_activity DROP COLUMN IF EXISTS device_id CASCADE;
        ALTER TABLE web_activity RENAME COLUMN device_hostname TO device_id;
        ALTER TABLE web_activity ALTER COLUMN device_id TYPE TEXT;
    END IF;
END $$;

-- Step 2: Remove old primary key and sequence from devices table
ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_pkey CASCADE;
DROP SEQUENCE IF EXISTS device_id_seq CASCADE;

-- Step 3: Ensure hostname is unique and not null
UPDATE devices SET hostname = COALESCE(hostname, 'UNKNOWN_' || random()::text) WHERE hostname IS NULL;
DELETE FROM devices WHERE hostname IS NULL OR hostname = '';

-- Make hostname unique and not null
ALTER TABLE devices 
    ALTER COLUMN hostname SET NOT NULL;

-- Remove duplicates if any (keep first one)
DELETE FROM devices d1
USING devices d2
WHERE d1.hostname = d2.hostname 
  AND d1.created_at > d2.created_at;

-- Add unique constraint
ALTER TABLE devices 
    ADD CONSTRAINT devices_hostname_unique UNIQUE (hostname);

-- Step 4: Make hostname the primary key
ALTER TABLE devices ADD PRIMARY KEY (hostname);

-- Step 5: Re-add foreign key constraints using hostname
ALTER TABLE geofence_alerts 
    ADD CONSTRAINT geofence_alerts_device_id_fkey 
    FOREIGN KEY (device_id) REFERENCES devices(hostname) ON DELETE CASCADE;

ALTER TABLE software_inventory 
    ADD CONSTRAINT software_inventory_device_id_fkey 
    FOREIGN KEY (device_id) REFERENCES devices(hostname) ON DELETE CASCADE;

ALTER TABLE web_activity 
    ADD CONSTRAINT web_activity_device_id_fkey 
    FOREIGN KEY (device_id) REFERENCES devices(hostname) ON DELETE CASCADE;

-- Step 6: Rebuild indexes (they should still work, but ensure they're correct)
DROP INDEX IF EXISTS idx_geofence_alerts_device;
CREATE INDEX IF NOT EXISTS idx_geofence_alerts_device ON geofence_alerts(device_id);

DROP INDEX IF EXISTS idx_software_inventory_device;
CREATE INDEX IF NOT EXISTS idx_software_inventory_device ON software_inventory(device_id);

DROP INDEX IF EXISTS idx_web_activity_device;
CREATE INDEX IF NOT EXISTS idx_web_activity_device ON web_activity(device_id);

-- Step 7: Recreate RLS policies with updated device_id (now TEXT/hostname)

-- Geofence alerts policy (updated to use device_id as TEXT/hostname)
CREATE POLICY "Users see alerts for accessible devices"
    ON geofence_alerts FOR SELECT
    TO authenticated
    USING (
        device_id IN (
            SELECT hostname FROM devices
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

-- Software inventory policy (updated to use device_id as TEXT/hostname)
CREATE POLICY "Users see software for accessible devices"
    ON software_inventory FOR SELECT
    TO authenticated
    USING (
        device_id IN (
            SELECT hostname FROM devices
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

-- Web activity policy (updated to use device_id as TEXT/hostname)
CREATE POLICY "Users see web activity for accessible devices"
    ON web_activity FOR SELECT
    TO authenticated
    USING (
        device_id IN (
            SELECT hostname FROM devices
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

-- Step 8: Remove the old id column from devices (if it still exists)
ALTER TABLE devices DROP COLUMN IF EXISTS id CASCADE;
