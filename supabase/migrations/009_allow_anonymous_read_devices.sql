-- Allow anonymous users to read devices (needed for dashboard)
-- This allows the dashboard to display devices without authentication

-- Drop existing SELECT policy if it exists
DROP POLICY IF EXISTS "Teachers see devices in their location" ON devices;

-- Create policy that allows anonymous and authenticated users to read all devices
CREATE POLICY "Allow all users to read devices"
    ON devices FOR SELECT
    TO anon, authenticated
    USING (true);

-- Note: INSERT is already allowed by migration 006
-- UPDATE/DELETE remain restricted (only admins can modify)

