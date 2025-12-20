-- Add new fields to devices table
-- Run this migration to add the new fields

ALTER TABLE devices 
ADD COLUMN IF NOT EXISTS device_inventory_code TEXT,
ADD COLUMN IF NOT EXISTS host_location TEXT,
ADD COLUMN IF NOT EXISTS city_town_village TEXT,
ADD COLUMN IF NOT EXISTS laptop_model TEXT;

-- Create index on inventory code for faster lookups
CREATE INDEX IF NOT EXISTS idx_devices_inventory_code ON devices(device_inventory_code);

-- Update existing devices with placeholder values (optional)
-- UPDATE devices SET device_inventory_code = 'INV-' || LPAD(id::TEXT, 6, '0') WHERE device_inventory_code IS NULL;



