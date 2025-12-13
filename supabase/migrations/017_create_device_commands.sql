-- Migration 017: Create device_commands table for remote device control and messaging
-- Handles commands (lock, unlock, clear_cache, buzz) and broadcast messages

CREATE TABLE IF NOT EXISTS device_commands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_hostname TEXT REFERENCES devices(hostname) ON DELETE CASCADE,
  command_type TEXT NOT NULL CHECK (command_type IN ('lock', 'unlock', 'clear_cache', 'buzz', 'broadcast_message')),
  message TEXT,
  target_type TEXT CHECK (target_type IN ('single', 'location', 'all')),
  target_location_id UUID REFERENCES locations(id) ON DELETE CASCADE,
  duration INTEGER, -- For buzz command in seconds
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'dismissed', 'expired')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  executed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ, -- For broadcast messages
  error_message TEXT,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Indexes for performance
CREATE INDEX idx_device_commands_device_hostname ON device_commands(device_hostname);
CREATE INDEX idx_device_commands_status ON device_commands(status);
CREATE INDEX idx_device_commands_command_type ON device_commands(command_type);
CREATE INDEX idx_device_commands_pending ON device_commands(device_hostname, status) WHERE status = 'pending';
CREATE INDEX idx_device_commands_target_location ON device_commands(target_location_id) WHERE target_location_id IS NOT NULL;
CREATE INDEX idx_device_commands_expires_at ON device_commands(expires_at) WHERE expires_at IS NOT NULL;

-- Enable RLS
ALTER TABLE device_commands ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see commands for their accessible devices
CREATE POLICY "Users see commands for accessible devices"
  ON device_commands FOR SELECT
  TO authenticated
  USING (
    -- Allow admins to see all commands
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'location_admin')
    )
    -- Allow users to see commands for devices in their accessible locations
    OR device_hostname IN (
      SELECT hostname FROM devices
      WHERE location_id IN (
        SELECT location_id FROM devices
        WHERE assigned_teacher IS NOT NULL
      )
    )
    OR target_type = 'all'
  );

-- Policy: Users can create commands for their accessible devices
CREATE POLICY "Users can create commands for accessible devices"
  ON device_commands FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Allow admins to create commands for any device
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'location_admin')
    )
    -- Allow users to create commands for devices in their accessible locations
    OR device_hostname IN (
      SELECT hostname FROM devices
      WHERE location_id IN (
        SELECT location_id FROM devices
        WHERE assigned_teacher IS NOT NULL
      )
    )
    OR target_type = 'all'
  );

-- Policy: Allow anonymous/device updates (for agents to update command status)
CREATE POLICY "Devices can update their own commands"
  ON device_commands FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Add comments
COMMENT ON TABLE device_commands IS 'Stores device commands and broadcast messages sent from dashboard to devices';
COMMENT ON COLUMN device_commands.command_type IS 'Type of command: lock, unlock, clear_cache, buzz, or broadcast_message';
COMMENT ON COLUMN device_commands.target_type IS 'For broadcast messages: single device, location, or all devices';
COMMENT ON COLUMN device_commands.duration IS 'Duration in seconds (for buzz command)';
COMMENT ON COLUMN device_commands.status IS 'Command status: pending, completed, failed, dismissed (for messages), or expired';
