-- ============================================
-- ENABLE REALTIME FOR device_commands TABLE
-- ============================================
-- Run this in Supabase SQL Editor to enable Realtime
-- This is REQUIRED for devices to receive commands via WebSocket

-- Check current status
SELECT 
    tablename,
    pubname
FROM pg_publication_tables
WHERE tablename = 'device_commands';

-- Enable Realtime (if not already enabled)
ALTER PUBLICATION supabase_realtime ADD TABLE device_commands;

-- Verify it's enabled
SELECT 
    tablename,
    pubname
FROM pg_publication_tables
WHERE tablename = 'device_commands';

-- Expected result: Should show 1 row with pubname = 'supabase_realtime'


