-- Update default radius_meters to 1000 meters
-- Also update any existing locations with NULL or 0 radius to 1000

-- Change default value for new locations
ALTER TABLE locations 
  ALTER COLUMN radius_meters SET DEFAULT 1000;

-- Update existing locations that have NULL, 0, or very small radius
UPDATE locations 
SET radius_meters = 1000 
WHERE radius_meters IS NULL 
   OR radius_meters = 0 
   OR radius_meters < 100;

-- Ensure NOT NULL constraint (should already exist, but making sure)
ALTER TABLE locations 
  ALTER COLUMN radius_meters SET NOT NULL;



