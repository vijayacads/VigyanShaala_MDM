-- Migration 022: Create user_notifications table for user-session notification agent
-- This table stores notifications that need to be displayed in the user's interactive session
-- (buzzer sounds, toast notifications, etc.)

-- Create user_notifications table
CREATE TABLE IF NOT EXISTS user_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_hostname TEXT NOT NULL,
    username TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('buzzer', 'toast')),
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    error_message TEXT,
    
    -- Indexes for efficient querying
    CONSTRAINT user_notifications_device_username_check CHECK (device_hostname IS NOT NULL AND username IS NOT NULL)
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_user_notifications_device_username_status 
    ON user_notifications(device_hostname, username, status);

CREATE INDEX IF NOT EXISTS idx_user_notifications_created_at 
    ON user_notifications(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_notifications_status 
    ON user_notifications(status) WHERE status = 'pending';

-- Enable RLS
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Allow anonymous service role to insert (for SYSTEM agent)
CREATE POLICY "Allow service role to insert user notifications"
    ON user_notifications
    FOR INSERT
    TO service_role
    WITH CHECK (true);

-- Allow service role to update (for user agent to mark as processed)
CREATE POLICY "Allow service role to update user notifications"
    ON user_notifications
    FOR UPDATE
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Allow service role to select (for user agent to read notifications)
CREATE POLICY "Allow service role to select user notifications"
    ON user_notifications
    FOR SELECT
    TO service_role
    USING (true);

-- Allow anon role to insert (for SYSTEM agent via anon key)
CREATE POLICY "Allow anon to insert user notifications"
    ON user_notifications
    FOR INSERT
    TO anon
    WITH CHECK (true);

-- Allow anon role to update (for user agent via anon key)
CREATE POLICY "Allow anon to update user notifications"
    ON user_notifications
    FOR UPDATE
    TO anon
    USING (true)
    WITH CHECK (true);

-- Allow anon role to select (for user agent via anon key)
CREATE POLICY "Allow anon to select user notifications"
    ON user_notifications
    FOR SELECT
    TO anon
    USING (true);

-- Add comment
COMMENT ON TABLE user_notifications IS 'Stores notifications that need to be displayed in user interactive sessions (buzzer, toast)';

