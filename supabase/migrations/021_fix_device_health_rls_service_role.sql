-- Migration 021: Fix RLS policies for device_health to allow service_role
-- Edge Functions use service_role key which should bypass RLS, but explicit policy helps

-- Drop and recreate INSERT policy to include service_role
DROP POLICY IF EXISTS "Devices can insert their own health" ON device_health;
CREATE POLICY "Devices can insert their own health"
ON device_health FOR INSERT
TO anon, authenticated, service_role
WITH CHECK (true);

-- Drop and recreate UPDATE policy to include service_role
DROP POLICY IF EXISTS "Devices can update their own health" ON device_health;
CREATE POLICY "Devices can update their own health"
ON device_health FOR UPDATE
TO anon, authenticated, service_role
USING (true)
WITH CHECK (true);

-- Note: service_role should bypass RLS by default, but explicit policies ensure compatibility

