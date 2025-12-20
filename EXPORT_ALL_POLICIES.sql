-- =====================================================
-- EXPORT ALL RLS POLICIES FROM OLD PROJECT
-- Run this in your OLD Supabase project SQL Editor
-- Copy the results and share them
-- =====================================================

-- Query 1: List all tables with RLS status
SELECT 
    schemaname,
    tablename,
    rowsecurity as "RLS Enabled",
    CASE 
        WHEN rowsecurity THEN 'Yes'
        ELSE 'No'
    END as "RLS Status"
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- Query 2: List ALL RLS policies with full details
SELECT 
    schemaname,
    tablename,
    policyname as "Policy Name",
    permissive,
    roles,
    cmd as "Command",
    qual as "USING Expression",
    with_check as "WITH CHECK Expression"
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Query 3: Get policy definitions in readable format (for easy copy-paste)
SELECT 
    'Table: ' || tablename || E'\n' ||
    'Policy: ' || policyname || E'\n' ||
    'Command: ' || cmd || E'\n' ||
    'Roles: ' || array_to_string(roles, ', ') || E'\n' ||
    CASE 
        WHEN qual IS NOT NULL THEN 'USING: ' || qual || E'\n'
        ELSE ''
    END ||
    CASE 
        WHEN with_check IS NOT NULL THEN 'WITH CHECK: ' || with_check || E'\n'
        ELSE ''
    END ||
    '---' as "Policy Details"
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Query 4: Count policies per table
SELECT 
    tablename,
    COUNT(*) as "Policy Count",
    STRING_AGG(policyname, ', ' ORDER BY policyname) as "Policy Names"
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

-- Query 5: Check which tables have NO policies (but RLS enabled)
SELECT 
    t.tablename,
    'RLS enabled but NO policies!' as "Warning"
FROM pg_tables t
WHERE t.schemaname = 'public'
AND t.rowsecurity = true
AND NOT EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname = 'public'
    AND p.tablename = t.tablename
)
ORDER BY t.tablename;


