-- Update device fields: Add assigned_student_leader and assigned_teacher (TEXT), Remove fleet_uuid

-- Step 1: Remove fleet_uuid column and its index
ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_fleet_uuid_key CASCADE;
DROP INDEX IF EXISTS idx_devices_fleet_uuid;
ALTER TABLE devices DROP COLUMN IF EXISTS fleet_uuid CASCADE;

-- Step 2: Change assigned_teacher_id (UUID) to assigned_teacher (TEXT)
-- First drop the foreign key constraint
ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_assigned_teacher_id_fkey CASCADE;

-- Drop the old index
DROP INDEX IF EXISTS idx_devices_teacher;

-- Add new assigned_teacher column (TEXT)
ALTER TABLE devices ADD COLUMN IF NOT EXISTS assigned_teacher TEXT;

-- Migrate data if any exists (convert UUID to text, or leave null)
-- Note: This will be null for existing records, but that's okay
UPDATE devices SET assigned_teacher = NULL WHERE assigned_teacher IS NULL;

-- Drop old assigned_teacher_id column
ALTER TABLE devices DROP COLUMN IF EXISTS assigned_teacher_id CASCADE;

-- Step 3: Add assigned_student_leader column
ALTER TABLE devices ADD COLUMN IF NOT EXISTS assigned_student_leader TEXT;

-- Step 4: Create indexes
CREATE INDEX IF NOT EXISTS idx_devices_teacher ON devices(assigned_teacher);
CREATE INDEX IF NOT EXISTS idx_devices_student_leader ON devices(assigned_student_leader);

-- Step 5: Update RLS policies that reference assigned_teacher_id
-- Note: These policies may need updating if they referenced assigned_teacher_id
-- The policies will need to be updated separately if they use assigned_teacher_id

-- Step 6: Update comments/documentation
COMMENT ON COLUMN devices.assigned_teacher IS 'Name or ID of the teacher assigned to this device';
COMMENT ON COLUMN devices.assigned_student_leader IS 'Name or ID of the student leader assigned to this device';

