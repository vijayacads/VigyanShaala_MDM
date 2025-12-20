-- Migration 028: Enable Realtime for device_commands table
-- This allows devices to receive INSERT events via WebSocket

-- Add device_commands to Supabase Realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE device_commands;


