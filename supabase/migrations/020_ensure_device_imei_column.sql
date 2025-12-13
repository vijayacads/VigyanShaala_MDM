-- Migration 020: Ensure device_imei_number column exists
-- This migration ensures the device_imei_number column exists in the devices table
-- and refreshes the schema for PostgREST

-- Step 1: Add device_imei_number column if it doesn't exist
ALTER TABLE devices 
ADD COLUMN IF NOT EXISTS device_imei_number TEXT;

-- Step 2: Add other columns from migration 015 if they don't exist
ALTER TABLE devices 
ADD COLUMN IF NOT EXISTS device_make TEXT,
ADD COLUMN IF NOT EXISTS role TEXT,
ADD COLUMN IF NOT EXISTS issue_date DATE,
ADD COLUMN IF NOT EXISTS wifi_ssid TEXT;

-- Step 3: Remove serial_number if it exists (replaced by device_imei_number)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'devices' AND column_name = 'serial_number'
    ) THEN
        ALTER TABLE devices DROP COLUMN serial_number;
    END IF;
END $$;

-- Step 4: Verify the column exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'devices' AND column_name = 'device_imei_number'
    ) THEN
        RAISE EXCEPTION 'device_imei_number column was not created successfully';
    ELSE
        RAISE NOTICE 'device_imei_number column exists successfully';
    END IF;
END $$;

-- Note: After running this migration, you need to refresh PostgREST schema cache:
-- 1. Go to Supabase Dashboard -> Settings -> API
-- 2. Click "Reload schema" button
-- 3. Or wait 1-2 minutes for automatic refresh
-- 4. Or restart your Supabase project

