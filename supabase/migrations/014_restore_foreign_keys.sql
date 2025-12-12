-- =====================================================
-- Restore Foreign Key Relationships
-- This ensures foreign keys exist for PostgREST to recognize relationships
-- =====================================================

-- Drop existing foreign keys if they exist (to avoid conflicts)
ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_location_id_fkey CASCADE;
ALTER TABLE geofence_alerts DROP CONSTRAINT IF EXISTS geofence_alerts_location_id_fkey CASCADE;

-- Recreate foreign key: devices.location_id -> locations.id
ALTER TABLE devices 
    ADD CONSTRAINT devices_location_id_fkey 
    FOREIGN KEY (location_id) 
    REFERENCES locations(id) 
    ON DELETE SET NULL;

-- Recreate foreign key: geofence_alerts.location_id -> locations.id
ALTER TABLE geofence_alerts 
    ADD CONSTRAINT geofence_alerts_location_id_fkey 
    FOREIGN KEY (location_id) 
    REFERENCES locations(id) 
    ON DELETE CASCADE;

-- Verify foreign keys exist
DO $$
DECLARE
    fk_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO fk_count
    FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY'
    AND (constraint_name = 'devices_location_id_fkey' 
         OR constraint_name = 'geofence_alerts_location_id_fkey');
    
    RAISE NOTICE 'Foreign keys found: %', fk_count;
    
    IF fk_count < 2 THEN
        RAISE EXCEPTION 'Not all foreign keys were created successfully';
    END IF;
END $$;

-- Note: PostgREST schema cache should refresh automatically
-- If it doesn't, you may need to:
-- 1. Go to Supabase Dashboard -> Settings -> API
-- 2. Click "Reload schema" or wait a few minutes for auto-refresh
-- 3. Or restart the Supabase project

