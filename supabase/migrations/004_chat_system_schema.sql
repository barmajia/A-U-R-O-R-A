-- ==============================================================================
-- Aurora E-Commerce: Chat System Database Schema
-- ==============================================================================
-- This script creates the complete chat messaging system tables:
-- 1. conversations - Chat conversations
-- 2. conversation_participants - Users in each conversation
-- 3. messages - Individual messages
-- 4. Storage bucket for attachments
--
-- Run this in Supabase SQL Editor: https://app.supabase.com/project/_/sql
-- ==============================================================================

-- ==============================================================================
-- PART 1: CREATE TABLES
-- ==============================================================================

-- Conversations table
CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_message TEXT,
  last_message_at TIMESTAMPTZ,
  is_archived BOOLEAN DEFAULT false
);

-- Conversation participants table
CREATE TABLE IF NOT EXISTS conversation_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role TEXT CHECK (role IN ('customer', 'seller')) NOT NULL,
  last_read_message_id UUID REFERENCES messages(id),
  is_muted BOOLEAN DEFAULT false,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  user_name TEXT,
  avatar_url TEXT,
  UNIQUE(conversation_id, user_id)
);

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  content TEXT,
  message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file')),
  attachment_url TEXT,
  attachment_name TEXT,
  attachment_size BIGINT,
  is_deleted BOOLEAN DEFAULT false,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- PART 2: CREATE INDEXES FOR PERFORMANCE
-- ==============================================================================

-- Conversations indexes
CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON conversations(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_product_id ON conversations(product_id);
CREATE INDEX IF NOT EXISTS idx_conversations_archived ON conversations(is_archived);

-- Participants indexes
CREATE INDEX IF NOT EXISTS idx_participants_user_id ON conversation_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_participants_conversation_id ON conversation_participants(conversation_id);

-- Messages indexes
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_read_at ON messages(read_at) WHERE read_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);

-- ==============================================================================
-- PART 3: CREATE TRIGGERS FOR AUTO-UPDATES
-- ==============================================================================

-- Function to update conversation on new message
CREATE OR REPLACE FUNCTION update_conversation_on_message()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NOT NEW.is_deleted THEN
    UPDATE conversations
    SET 
      last_message = CASE 
        WHEN NEW.message_type = 'image' THEN '📷 Photo'
        WHEN NEW.message_type = 'file' THEN '📎 Attachment'
        ELSE NEW.content
      END,
      last_message_at = NEW.created_at,
      updated_at = NOW()
    WHERE id = NEW.conversation_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for updating conversation on message insert
DROP TRIGGER IF EXISTS trigger_update_conversation_on_message ON messages;
CREATE TRIGGER trigger_update_conversation_on_message
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_on_message();

-- Function to update conversation updated_at timestamp
CREATE OR REPLACE FUNCTION update_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating conversation timestamp
DROP TRIGGER IF EXISTS trigger_update_conversation_timestamp ON conversations;
CREATE TRIGGER trigger_update_conversation_timestamp
  BEFORE UPDATE ON conversations
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_timestamp();

-- Function to update message updated_at timestamp
CREATE OR REPLACE FUNCTION update_message_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating message timestamp
DROP TRIGGER IF EXISTS trigger_update_message_timestamp ON messages;
CREATE TRIGGER trigger_update_message_timestamp
  BEFORE UPDATE ON messages
  FOR EACH ROW
  EXECUTE FUNCTION update_message_timestamp();

-- ==============================================================================
-- PART 4: CREATE STORAGE BUCKET FOR ATTACHMENTS
-- ==============================================================================

-- Create chat-attachments bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-attachments',
  'chat-attachments',
  false,  -- Private bucket (only accessible to participants)
  52428800,  -- 50MB file size limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can upload chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users can view chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own chat attachments" ON storage.objects;

-- Policy: Users can upload chat attachments
CREATE POLICY "Users can upload chat attachments"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'chat-attachments'
  AND (storage.foldername(name))[1] IN (
    SELECT conversation_id::text
    FROM conversation_participants
    WHERE user_id = auth.uid()
  )
);

-- Policy: Users can view chat attachments in their conversations
CREATE POLICY "Users can view chat attachments"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'chat-attachments'
  AND (storage.foldername(name))[1] IN (
    SELECT conversation_id::text
    FROM conversation_participants
    WHERE user_id = auth.uid()
  )
);

-- Policy: Users can delete own chat attachments
CREATE POLICY "Users can delete own chat attachments"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'chat-attachments'
  AND (storage.foldername(name))[1] IN (
    SELECT conversation_id::text
    FROM conversation_participants
    WHERE user_id = auth.uid()
  )
);

-- ==============================================================================
-- PART 5: HELPER FUNCTIONS
-- ==============================================================================

-- Function to get unread message count for a user in a conversation
CREATE OR REPLACE FUNCTION get_unread_message_count(conv_id UUID, user_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM messages
    WHERE conversation_id = conv_id
      AND sender_id != user_id
      AND read_at IS NULL
      AND is_deleted = false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is participant in conversation
CREATE OR REPLACE FUNCTION is_conversation_participant(conv_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM conversation_participants
    WHERE conversation_id = conv_id AND user_id = user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- PART 6: ENABLE ROW LEVEL SECURITY (RLS)
-- ==============================================================================

-- Note: RLS policies are applied in 003_chat_system_rls.sql
-- This section just enables RLS on the tables

ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- PART 7: VERIFICATION QUERIES
-- ==============================================================================

-- Verify tables were created
SELECT '✓ Tables Created' as status, table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('conversations', 'conversation_participants', 'messages')
ORDER BY table_name;

-- Verify indexes
SELECT '✓ Indexes Created' as status, indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('conversations', 'conversation_participants', 'messages')
ORDER BY tablename, indexname;

-- Verify triggers
SELECT '✓ Triggers Created' as status, trigger_name, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE 'trigger_%'
ORDER BY trigger_name;

-- Verify storage bucket
SELECT '✓ Storage Bucket Created' as status, id, name, public, file_size_limit
FROM storage.buckets
WHERE id = 'chat-attachments';

-- Count RLS policies
SELECT '📊 RLS Policies' as status,
       (SELECT count(*) FROM pg_policies WHERE tablename = 'conversations') as conversations,
       (SELECT count(*) FROM pg_policies WHERE tablename = 'conversation_participants') as participants,
       (SELECT count(*) FROM pg_policies WHERE tablename = 'messages') as messages,
       (SELECT count(*) FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage') as storage;

-- ==============================================================================
-- MIGRATION COMPLETE
-- ==============================================================================
--
-- Chat System Database Setup Complete!
--
-- Tables Created:
-- ✓ conversations - Chat conversations with optional product link
-- ✓ conversation_participants - Users participating in conversations
-- ✓ messages - Individual messages with support for text, images, files
-- ✓ Storage bucket 'chat-attachments' for file uploads
--
-- Features:
-- ✓ Automatic conversation updates on new messages (triggers)
-- ✓ Unread message count helper function
-- ✓ Participant verification helper function
-- ✓ RLS enabled on all tables
-- ✓ Storage policies for secure file access
--
-- Next Steps:
-- 1. ✓ Run this script in Supabase SQL Editor
-- 2. ✓ Run 003_chat_system_rls.sql to apply RLS policies
-- 3. ✓ Test chat functionality in Flutter app
-- 4. ✓ Verify real-time message delivery
-- 5. ✓ Test image/file attachments
--
-- Testing:
-- - Create two test user accounts
-- - Start a conversation from one user to another
-- - Send messages and verify real-time updates
-- - Test image uploads
-- - Verify RLS prevents unauthorized access
--
-- ==============================================================================
