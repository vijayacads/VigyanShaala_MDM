-- =====================================================
-- Create Chat Messages Table
-- Migration 018: Real-time chat between support center and devices
-- =====================================================

-- Create chat_messages table
CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_hostname TEXT NOT NULL REFERENCES devices(hostname) ON DELETE CASCADE,
    sender TEXT NOT NULL CHECK (sender IN ('center', 'device')),
    message TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    read_status BOOLEAN DEFAULT false,
    sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Indexes
CREATE INDEX idx_chat_messages_device ON chat_messages(device_hostname);
CREATE INDEX idx_chat_messages_timestamp ON chat_messages(timestamp DESC);
CREATE INDEX idx_chat_messages_read ON chat_messages(read_status) WHERE read_status = false;

-- Enable RLS
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Policy: All authenticated users can read messages
CREATE POLICY "Chat messages are readable by authenticated users"
    ON chat_messages FOR SELECT
    TO authenticated
    USING (true);

-- Policy: Allow anonymous users to read/insert messages (for agents)
CREATE POLICY "Agents can read and send chat messages"
    ON chat_messages FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

-- Policy: Authenticated users can insert messages
CREATE POLICY "Authenticated users can send chat messages"
    ON chat_messages FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Function to auto-cleanup old messages (older than 10 days)
CREATE OR REPLACE FUNCTION cleanup_old_chat_messages()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM chat_messages
    WHERE timestamp < NOW() - INTERVAL '10 days';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to cleanup old messages on insert
DROP TRIGGER IF EXISTS cleanup_chat_messages_trigger ON chat_messages;
CREATE TRIGGER cleanup_chat_messages_trigger
    AFTER INSERT ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION cleanup_old_chat_messages();

-- Enable Realtime for chat_messages table
-- Note: This needs to be done in Supabase Dashboard -> Database -> Replication
-- Or via SQL: ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;

-- Add comments
COMMENT ON TABLE chat_messages IS 'Real-time chat messages between support center and devices';
COMMENT ON COLUMN chat_messages.sender IS 'center (from dashboard) or device (from agent)';
COMMENT ON COLUMN chat_messages.read_status IS 'Whether the message has been read by the recipient';
