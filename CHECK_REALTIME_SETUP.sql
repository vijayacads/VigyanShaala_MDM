-- ============================================
-- CHECK SUPABASE REALTIME SETUP
-- ============================================
-- Run this in Supabase SQL Editor to verify Realtime is configured correctly

-- 1. Check if device_commands table is in Realtime publication
SELECT 
    schemaname,
    tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
    AND tablename = 'device_commands';

-- Expected: Should return 1 row with tablename = 'device_commands'

-- 2. Check if Realtime is enabled for device_commands
SELECT 
    schemaname,
    tablename,
    pubname
FROM pg_publication_tables
WHERE tablename = 'device_commands';

-- Expected: Should show 'supabase_realtime' in pubname

-- 3. Check table structure (verify columns exist)
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'device_commands'
ORDER BY ordinal_position;

-- 4. Check if RLS is enabled (should be true)
SELECT 
    tablename,
    rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename = 'device_commands';

-- Expected: rowsecurity = true

-- 5. Check RLS policies for device_commands
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'device_commands'
ORDER BY policyname;

-- 6. Check recent device_commands (verify data exists)
SELECT 
    id,
    device_hostname,
    command_type,
    status,
    created_at,
    executed_at
FROM device_commands
ORDER BY created_at DESC
LIMIT 10;

-- 7. Check if Realtime extension is installed
SELECT 
    extname,
    extversion
FROM pg_extension
WHERE extname = 'pg_cron' OR extname LIKE '%realtime%';

-- 8. Check publication status
SELECT 
    pubname,
    puballtables,
    pubinsert,
    pubupdate,
    pubdelete,
    pubtruncate
FROM pg_publication
WHERE pubname = 'supabase_realtime';

-- Expected: pubinsert = true (for INSERT events)

-- ============================================
-- FIX IF MISSING
-- ============================================
-- If device_commands is NOT in the publication, run:
-- ALTER PUBLICATION supabase_realtime ADD TABLE device_commands;


