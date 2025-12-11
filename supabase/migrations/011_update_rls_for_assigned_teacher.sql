-- Update RLS policies to use assigned_teacher (TEXT) instead of assigned_teacher_id (UUID)
-- This is needed after migration 010 changes assigned_teacher_id to assigned_teacher

-- Note: These policies will need manual review since assigned_teacher is now TEXT, not a UUID
-- For now, we'll update policies to check if assigned_teacher matches current user's email or name
-- Admin may need to adjust this based on how teacher identification works

-- Update geofence_alerts policy
DROP POLICY IF EXISTS "Users see alerts for accessible devices" ON geofence_alerts;
CREATE POLICY "Users see alerts for accessible devices"
    ON geofence_alerts FOR SELECT
    TO authenticated
    USING (
        device_id IN (
            SELECT hostname FROM devices
            WHERE assigned_teacher IS NOT NULL
            OR location_id IN (
                SELECT location_id FROM devices WHERE assigned_teacher IS NOT NULL
            )
        )
        OR
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'location_admin')
        )
    );

-- Update software_inventory policy
DROP POLICY IF EXISTS "Users see software for accessible devices" ON software_inventory;
CREATE POLICY "Users see software for accessible devices"
    ON software_inventory FOR SELECT
    TO authenticated
    USING (
        device_id IN (
            SELECT hostname FROM devices
            WHERE assigned_teacher IS NOT NULL
            OR location_id IN (
                SELECT location_id FROM devices WHERE assigned_teacher IS NOT NULL
            )
        )
        OR
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'location_admin')
        )
    );

-- Update web_activity policy
DROP POLICY IF EXISTS "Users see web activity for accessible devices" ON web_activity;
CREATE POLICY "Users see web activity for accessible devices"
    ON web_activity FOR SELECT
    TO authenticated
    USING (
        device_id IN (
            SELECT hostname FROM devices
            WHERE assigned_teacher IS NOT NULL
            OR location_id IN (
                SELECT location_id FROM devices WHERE assigned_teacher IS NOT NULL
            )
        )
        OR
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'location_admin')
        )
    );

-- Note: Device SELECT policy may also need updating if it references assigned_teacher_id
-- Check migration 006 and 009 for device policies

