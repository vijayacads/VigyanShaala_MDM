-- Fix device sequence to prevent duplicate key errors
-- This resets the sequence to use the next available ID

-- Get the maximum ID from devices table
-- Then set the sequence to start after that

DO $$
DECLARE
    max_id INTEGER;
BEGIN
    -- Get the maximum device ID, or default to 100000 if no devices exist
    SELECT COALESCE(MAX(id), 100000) INTO max_id FROM devices;
    
    -- Set sequence to start at max_id + 1
    -- Ensure it's at least 100001 (sequence minimum)
    IF max_id < 100000 THEN
        max_id := 100000;
    END IF;
    
    -- Reset sequence to start at next available ID
    EXECUTE format('SELECT setval(''device_id_seq'', %s, false)', max_id);
    
    RAISE NOTICE 'Device sequence reset to start at: %', max_id + 1;
END $$;

-- Verify the sequence
SELECT setval('device_id_seq', (SELECT COALESCE(MAX(id), 100000) FROM devices), false);




