-- =====================================================
-- Cleanup: Drop existing tables if they exist
-- Run this FIRST if you want to start fresh
-- =====================================================

-- WARNING: This will delete all existing data!
-- Only run this if you want to reset everything

-- Drop dependent tables first (due to foreign keys)
DROP TABLE IF EXISTS web_activity CASCADE;
DROP TABLE IF EXISTS software_inventory CASCADE;
DROP TABLE IF EXISTS geofence_alerts CASCADE;
DROP TABLE IF EXISTS website_blocklist CASCADE;
DROP TABLE IF EXISTS software_blocklist CASCADE;
DROP TABLE IF EXISTS devices CASCADE;
DROP TABLE IF EXISTS locations CASCADE;

-- Drop sequences
DROP SEQUENCE IF EXISTS device_id_seq CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
