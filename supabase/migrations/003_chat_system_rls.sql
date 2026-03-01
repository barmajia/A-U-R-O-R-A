-- ==============================================================================
-- Aurora E-Commerce: Chat System Row Level Security (RLS)
-- ==============================================================================
-- This script sets up RLS policies for the chat messaging system:
-- 1. conversations table RLS
-- 2. conversation_participants table RLS
-- 3. messages table RLS
--
-- Prerequisites: Chat system tables must exist before running this script
-- Run this in Supabase SQL Editor: https://app.supabase.com/project/_/sql
-- ==============================================================================

-- ==============================================================================
-- PART 1: ENABLE ROW LEVEL SECURITY
-- ==============================================================================

-- Enable RLS on all chat-related tables
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- PART 2: CONVERSATIONS RLS POLICIES
-- ==============================================================================

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS conversations_view_own ON conversations;
DROP POLICY IF EXISTS conversations_insert_own ON conversations;
DROP POLICY IF EXISTS conversations_update_own ON conversations;
DROP POLICY IF EXISTS conversations_delete_own ON conversations;

-- Policy 1: Users can only see conversations they participate in
CREATE POLICY conversations_view_own ON conversations
  FOR SELECT TO authenticated
  USING (
    id IN (
      SELECT conversation_id 
      FROM conversation_participants 
      WHERE user_id = auth.uid()
    )
  );

-- Policy 2: Allow authenticated users to create conversations
-- (participants table enforces actual access control)
CREATE POLICY conversations_insert_own ON conversations
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- Policy 3: Users can update conversations they participate in
-- (e.g., to update last_message, is_archived)
CREATE POLICY conversations_update_own ON conversations
  FOR UPDATE TO authenticated
  USING (
    id IN (
      SELECT conversation_id 
      FROM conversation_participants 
      WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    id IN (
      SELECT conversation_id 
      FROM conversation_participants 
      WHERE user_id = auth.uid()
    )
  );

-- Policy 4: Users can delete conversations they participate in
CREATE POLICY conversations_delete_own ON conversations
  FOR DELETE TO authenticated
  USING (
    id IN (
      SELECT conversation_id 
      FROM conversation_participants 
      WHERE user_id = auth.uid()
    )
  );

-- ==============================================================================
-- PART 3: CONVERSATION PARTICIPANTS RLS POLICIES
-- ==============================================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS participants_view_own ON conversation_participants;
DROP POLICY IF EXISTS participants_insert_own ON conversation_participants;
DROP POLICY IF EXISTS participants_update_own ON conversation_participants;
DROP POLICY IF EXISTS participants_delete_own ON conversation_participants;

-- Policy 1: Users can only see their own participation records
CREATE POLICY participants_view_own ON conversation_participants
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Policy 2: Users can only insert their own participation records
CREATE POLICY participants_insert_own ON conversation_participants
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Policy 3: Users can update their own participation records
-- (e.g., to update last_read_message_id, is_muted)
CREATE POLICY participants_update_own ON conversation_participants
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policy 4: Users can delete their own participation records
CREATE POLICY participants_delete_own ON conversation_participants
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ==============================================================================
-- PART 4: MESSAGES RLS POLICIES
-- ==============================================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS messages_view_own ON messages;
DROP POLICY IF EXISTS messages_insert_own ON messages;
DROP POLICY IF EXISTS messages_update_own ON messages;
DROP POLICY IF EXISTS messages_delete_own ON messages;

-- Policy 1: Users can only see messages in conversations they participate in
CREATE POLICY messages_view_own ON messages
  FOR SELECT TO authenticated
  USING (
    conversation_id IN (
      SELECT conversation_id 
      FROM conversation_participants 
      WHERE user_id = auth.uid()
    )
  );

-- Policy 2: Users can only send messages in conversations they participate in
CREATE POLICY messages_insert_own ON messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND conversation_id IN (
      SELECT conversation_id 
      FROM conversation_participants 
      WHERE user_id = auth.uid()
    )
  );

-- Policy 3: Users can only update their own messages
-- (e.g., to mark as read, update content, or soft-delete)
CREATE POLICY messages_update_own ON messages
  FOR UPDATE TO authenticated
  USING (sender_id = auth.uid())
  WITH CHECK (sender_id = auth.uid());

-- Policy 4: Users can only delete their own messages
CREATE POLICY messages_delete_own ON messages
  FOR DELETE TO authenticated
  USING (sender_id = auth.uid());

-- ==============================================================================
-- PART 5: ADDITIONAL SECURITY POLICIES (OPTIONAL BUT RECOMMENDED)
-- ==============================================================================

-- Policy 5: Allow service role to bypass RLS (for Edge Functions, triggers)
-- This is automatically handled by Supabase, but documented here for clarity
-- Service role key automatically bypasses all RLS policies

-- ==============================================================================
-- PART 6: VERIFICATION QUERIES
-- ==============================================================================

-- Verify RLS is enabled on all tables
SELECT '✓ RLS Enabled Tables' as status, relname as table_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relname IN ('conversations', 'conversation_participants', 'messages')
  AND n.nspname = 'public'
  AND c.relrowsecurity = true;

-- Verify all RLS policies were created
SELECT '✓ Conversations Policies' as status, policyname
FROM pg_policies
WHERE tablename = 'conversations' AND schemaname = 'public'
ORDER BY policyname;

SELECT '✓ Participants Policies' as status, policyname
FROM pg_policies
WHERE tablename = 'conversation_participants' AND schemaname = 'public'
ORDER BY policyname;

SELECT '✓ Messages Policies' as status, policyname
FROM pg_policies
WHERE tablename = 'messages' AND schemaname = 'public'
ORDER BY policyname;

-- Summary count of policies
SELECT '📊 Policy Summary' as status,
       (SELECT count(*) FROM pg_policies WHERE tablename = 'conversations') as conversations_policies,
       (SELECT count(*) FROM pg_policies WHERE tablename = 'conversation_participants') as participants_policies,
       (SELECT count(*) FROM pg_policies WHERE tablename = 'messages') as messages_policies;

-- ==============================================================================
-- MIGRATION COMPLETE
-- ==============================================================================
--
-- Chat System RLS Security Summary:
-- ✓ Users can only see conversations they participate in
-- ✓ Users can only see their own participation records
-- ✓ Users can only see messages in conversations they participate in
-- ✓ Users can only send/update/delete their own messages
-- ✓ Service role can bypass RLS for Edge Functions and triggers
--
-- Next Steps:
-- 1. ✓ Verify all policies created successfully in output above
-- 2. ✓ Test chat functionality with different user accounts
-- 3. ✓ Verify users cannot access other users' conversations
-- 4. ✓ Deploy Edge Functions for push notifications (if needed)
--
-- Testing RLS:
-- - Use Supabase Dashboard → Authentication to create test users
-- - Use Supabase Dashboard → Table Editor to verify access control
-- - Or use the Flutter app to test real-world scenarios
--
-- ==============================================================================
