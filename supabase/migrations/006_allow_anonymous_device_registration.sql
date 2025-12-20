-- Allow anonymous device registration for installer scripts
-- This allows teachers to register devices using the installer without being logged in

-- Drop existing insert policy
DROP POLICY IF EXISTS "Teachers can enroll devices" ON devices;

-- Create new policy that allows anonymous inserts (for installer scripts)
-- Uses anon key which is safe for public use with RLS
CREATE POLICY "Allow anonymous device enrollment"
    ON devices FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

-- Also allow anonymous reads of locations (needed for dropdown in installer)
DROP POLICY IF EXISTS "Locations are readable by authenticated users" ON locations;

CREATE POLICY "Locations are readable by all"
    ON locations FOR SELECT
    TO anon, authenticated
    USING (is_active = true);

-- Note: For production, you may want to add additional validation
-- such as rate limiting or API key validation in Supabase Edge Functions




