-- =====================================================
-- FIX: Blocklist tables RLS for anon access
-- Problem: Policies check auth.users which anon can't access
-- Solution: Allow anon INSERT/UPDATE/DELETE for blocklists
-- =====================================================

-- Fix software_blocklist: Allow anon to manage (for dashboard)
DROP POLICY IF EXISTS "Admins manage software blocklists" ON software_blocklist;

-- Allow SELECT (read)
CREATE POLICY "Allow all users to read software blocklist"
    ON software_blocklist FOR SELECT
    TO anon, authenticated
    USING (true);

-- Allow INSERT/UPDATE/DELETE (manage)
CREATE POLICY "Allow all users to manage software blocklist"
    ON software_blocklist FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- Fix website_blocklist: Allow anon to manage (for dashboard)
DROP POLICY IF EXISTS "Admins manage website blocklists" ON website_blocklist;

-- Allow SELECT (read)
CREATE POLICY "Allow all users to read website blocklist"
    ON website_blocklist FOR SELECT
    TO anon, authenticated
    USING (true);

-- Allow INSERT/UPDATE/DELETE (manage)
CREATE POLICY "Allow all users to manage website blocklist"
    ON website_blocklist FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- =====================================================
-- DONE!
-- =====================================================
-- Now anon users (dashboard) can:
-- - INSERT into software_blocklist (add blocked software)
-- - UPDATE software_blocklist (modify entries)
-- - DELETE from software_blocklist (remove entries)
-- - Same for website_blocklist
-- =====================================================

