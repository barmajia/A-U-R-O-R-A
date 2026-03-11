# Chat System Architecture - Aurora E-Commerce Platform

## Overview

The Aurora Chat System is a comprehensive real-time messaging platform that enables communication between different user roles in the e-commerce ecosystem. It supports product inquiries, deal negotiations, order support, and general communication between factories, sellers, middlemen, customers, and delivery personnel.

---

## 1. Chat System Tables

### 1.1 `conversations`

Stores chat conversation metadata and links to products/deals.

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| `id` | UUID | Unique conversation identifier | PRIMARY KEY, DEFAULT gen_random_uuid() |
| `product_id` | UUID | Linked product (optional) | FOREIGN KEY → products(id) ON DELETE SET NULL |
| `deal_id` | UUID | Linked deal (optional) | FOREIGN KEY → deals(id) ON DELETE SET NULL |
| `user_id` | UUID | Customer/user ID | FOREIGN KEY → auth.users(id) ON DELETE CASCADE |
| `seller_id` | UUID | Seller ID | FOREIGN KEY → auth.users(id) ON DELETE CASCADE |
| `conversation_type` | TEXT | Type of conversation | CHECK: 'general', 'deal_negotiation', 'order_support' |
| `last_message` | TEXT | Preview of last message | - |
| `last_message_at` | TIMESTAMPTZ | Timestamp of last message | - |
| `is_archived` | BOOLEAN | Archive status | DEFAULT false |
| `created_at` | TIMESTAMPTZ | Creation timestamp | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | Last update timestamp | DEFAULT NOW() |

**Indexes:**
- `idx_conversations_updated_at` - ORDER BY updated_at DESC
- `idx_conversations_product_id` - For product-linked conversations
- `idx_conversations_deal_id` - For deal-linked conversations
- `idx_conversations_type` - Filter by conversation type
- `idx_conversations_user_seller` - Composite (user_id, seller_id)

---

### 1.2 `conversation_participants`

Tracks users participating in each conversation with their roles.

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| `id` | UUID | Unique participant record ID | PRIMARY KEY, DEFAULT gen_random_uuid() |
| `conversation_id` | UUID | Reference to conversation | FOREIGN KEY → conversations(id) ON DELETE CASCADE |
| `user_id` | UUID | User ID | FOREIGN KEY → auth.users(id) ON DELETE CASCADE |
| `role` | user_role | User's role in conversation | ENUM: factory, seller, middleman, customer, delivery |
| `last_read_message_id` | UUID | Last read message | FOREIGN KEY → messages(id) |
| `is_muted` | BOOLEAN | Mute status | DEFAULT false |
| `joined_at` | TIMESTAMPTZ | Join timestamp | DEFAULT NOW() |
| `user_name` | TEXT | Cached user name | - |
| `avatar_url` | TEXT | Cached avatar URL | - |

**Unique Constraints:**
- `conversation_id`, `user_id` - Prevent duplicate participants

**Indexes:**
- `idx_participants_user_id` - Find conversations by user
- `idx_participants_conversation_id` - Find participants by conversation

---

### 1.3 `messages`

Stores individual messages within conversations.

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| `id` | UUID | Unique message ID | PRIMARY KEY, DEFAULT gen_random_uuid() |
| `conversation_id` | UUID | Parent conversation | FOREIGN KEY → conversations(id) ON DELETE CASCADE |
| `sender_id` | UUID | Message sender | FOREIGN KEY → auth.users(id) ON DELETE CASCADE |
| `content` | TEXT | Message text content | - |
| `message_type` | TEXT | Type of message | CHECK: 'text', 'image', 'file' |
| `message_subtype` | TEXT | Subtype for special messages | CHECK: 'text', 'deal_proposal', 'deal_counter', 'deal_accepted', 'deal_rejected', 'file', 'image' |
| `attachment_url` | TEXT | URL for attached files | - |
| `attachment_name` | TEXT | Original file name | - |
| `attachment_size` | BIGINT | File size in bytes | - |
| `is_deleted` | BOOLEAN | Soft delete flag | DEFAULT false |
| `read_at` | TIMESTAMPTZ | Read receipt timestamp | - |
| `content_tsvector` | TSVECTOR | Full-text search index | - |
| `created_at` | TIMESTAMPTZ | Message timestamp | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | Update timestamp | DEFAULT NOW() |

**Indexes:**
- `idx_messages_conversation_id` - Composite (conversation_id, created_at DESC)
- `idx_messages_sender_id` - Filter by sender
- `idx_messages_read_at` - Partial index WHERE read_at IS NULL
- `idx_messages_subtype` - Filter by message subtype
- `idx_messages_search` - GIN index on content_tsvector

---

### 1.4 `conversation_deals`

Tracks deal proposals within conversations.

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| `id` | UUID | Unique deal proposal ID | PRIMARY KEY, DEFAULT gen_random_uuid() |
| `conversation_id` | UUID | Parent conversation | FOREIGN KEY → conversations(id) ON DELETE CASCADE |
| `deal_id` | UUID | Linked deal record | FOREIGN KEY → deals(id) ON DELETE SET NULL |
| `proposer_id` | UUID | User proposing the deal | FOREIGN KEY → auth.users(id) |
| `recipient_id` | UUID | User receiving the proposal | FOREIGN KEY → auth.users(id) |
| `proposal_data` | JSONB | Deal terms and details | NOT NULL |
| `status` | TEXT | Proposal status | CHECK: 'pending', 'accepted', 'rejected', 'expired', 'cancelled' |
| `expires_at` | TIMESTAMPTZ | Expiration timestamp | - |
| `created_at` | TIMESTAMPTZ | Creation timestamp | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | Update timestamp | DEFAULT NOW() |

**Indexes:**
- `idx_conversation_deals_conversation` - Filter by conversation
- `idx_conversation_deals_proposer` - Filter by proposer
- `idx_conversation_deals_recipient` - Filter by recipient
- `idx_conversation_deals_status` - Filter by status
- `idx_conversation_deals_created_at` - ORDER BY created_at DESC

---

## 2. Chat System Functions

### 2.1 `can_start_conversation()`

Validates if a user can initiate a conversation based on roles and context.

```sql
CREATE OR REPLACE FUNCTION can_start_conversation(
  from_user_id UUID,
  to_user_id UUID,
  product_id UUID DEFAULT NULL,
  conversation_type TEXT DEFAULT 'general'
) RETURNS BOOLEAN
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `from_user_id` | UUID | User initiating the conversation |
| `to_user_id` | UUID | Intended recipient |
| `product_id` | UUID | Optional product context |
| `conversation_type` | TEXT | Type: 'general', 'deal_negotiation', 'order_support' |

**Logic Flow:**
1. **Security Check:** Verify `auth.uid() = from_user_id`
2. **Self-Chat Prevention:** Return FALSE if from_user_id = to_user_id
3. **Role-Based Validation:**
   - `deal_negotiation`: Factory ↔ Seller/Middleman only
   - `factory`: Can message sellers/middlemen
   - `seller`: Can message factory/middleman; customers only with product context
   - `middleman`: Can message anyone
   - `customer`: Can message sellers about products (if allow_chat = true)

**Returns:** `TRUE` if conversation is allowed, `FALSE` otherwise

---

### 2.2 `update_conversation_on_message()`

Trigger function that updates conversation metadata when new messages arrive.

```sql
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
```

**Trigger:**
```sql
CREATE TRIGGER trigger_update_conversation_on_message
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_on_message();
```

---

### 2.3 `update_conversation_on_deal_proposal()`

Updates conversation type and status when a deal proposal is created.

```sql
CREATE OR REPLACE FUNCTION update_conversation_on_deal_proposal()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE conversations
  SET
    conversation_type = 'deal_negotiation',
    last_message = '🤝 Deal proposal sent',
    last_message_at = NOW(),
    updated_at = NOW()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Trigger:**
```sql
CREATE TRIGGER trigger_update_conversation_on_deal_proposal
  AFTER INSERT ON conversation_deals
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_on_deal_proposal();
```

---

### 2.4 `update_conversation_timestamp()`

Auto-updates the `updated_at` field on conversation updates.

```sql
CREATE OR REPLACE FUNCTION update_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_conversation_timestamp
  BEFORE UPDATE ON conversations
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_timestamp();
```

---

### 2.5 `update_message_timestamp()`

Auto-updates the `updated_at` field on message updates.

```sql
CREATE OR REPLACE FUNCTION update_message_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_message_timestamp
  BEFORE UPDATE ON messages
  FOR EACH ROW
  EXECUTE FUNCTION update_message_timestamp();
```

---

### 2.6 `messages_tsvector_trigger()`

Maintains full-text search index on message content.

```sql
CREATE OR REPLACE FUNCTION messages_tsvector_trigger()
RETURNS TRIGGER AS $$
BEGIN
  NEW.content_tsvector := to_tsvector('english', COALESCE(NEW.content, ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_messages_tsvector
  BEFORE INSERT OR UPDATE ON messages
  FOR EACH ROW
  EXECUTE FUNCTION messages_tsvector_trigger();
```

---

### 2.7 Helper Functions

#### `get_unread_message_count()`
```sql
CREATE OR REPLACE FUNCTION get_unread_message_count(
  conv_id UUID,
  user_id UUID
) RETURNS INTEGER
```
Returns count of unread messages for a user in a conversation.

#### `is_conversation_participant()`
```sql
CREATE OR REPLACE FUNCTION is_conversation_participant(
  conv_id UUID,
  user_id UUID
) RETURNS BOOLEAN
```
Checks if a user is a participant in a conversation.

---

## 3. User Roles in Chat System

The Aurora platform supports five distinct user roles, each with specific permissions and chat capabilities.

### 3.1 Role Definitions

| Role | Description | Primary Use Cases |
|------|-------------|-------------------|
| **factory** | Product manufacturers | B2B negotiations, bulk orders, production coordination |
| **seller** | Product retailers | Customer support, deal negotiations, order management |
| **middleman** | Intermediaries/brokers | Multi-party deal facilitation, commission-based transactions |
| **customer** | End consumers | Product inquiries, order support, complaints |
| **delivery** | Delivery personnel | Delivery coordination, location updates, issue resolution |

### 3.2 Role Enum

```sql
CREATE TYPE user_role AS ENUM (
  'factory',
  'seller',
  'middleman',
  'customer',
  'delivery'
);
```

---

## 4. Role Permissions Matrix

### 4.1 Conversation Initiation Permissions

| From \ To | factory | seller | middleman | customer | delivery |
|-----------|---------|--------|-----------|----------|----------|
| **factory** | ❌ | ✅ | ✅ | ❌ | ❌ |
| **seller** | ✅ | ❌ | ✅ | ✅* | ❌ |
| **middleman** | ✅ | ✅ | ❌ | ✅ | ✅ |
| **customer** | ❌ | ✅* | ❌ | ❌ | ❌ |
| **delivery** | ❌ | ✅** | ❌ | ❌ | ❌ |

**Legend:**
- ✅ = Always allowed
- ❌ = Not allowed
- ✅* = Allowed only with product context (product.allow_chat = true)
- ✅** = Allowed only for order-related conversations

### 4.2 Conversation Type Permissions

| Role | general | deal_negotiation | order_support |
|------|---------|------------------|---------------|
| **factory** | ✅ (B2B only) | ✅ | ❌ |
| **seller** | ✅ | ✅ | ✅ |
| **middleman** | ✅ | ✅ | ✅ |
| **customer** | ❌ | ❌ | ✅ |
| **delivery** | ❌ | ❌ | ✅ |

### 4.3 Message Type Permissions

| Role | text | image | file | deal_proposal |
|------|------|-------|------|---------------|
| **factory** | ✅ | ✅ | ✅ | ✅ |
| **seller** | ✅ | ✅ | ✅ | ✅ |
| **middleman** | ✅ | ✅ | ✅ | ✅ |
| **customer** | ✅ | ✅ | ✅ | ❌ |
| **delivery** | ✅ | ✅ | ✅ | ❌ |

### 4.4 Conversation Management Permissions

| Action | factory | seller | middleman | customer | delivery |
|--------|---------|--------|-----------|----------|----------|
| View own conversations | ✅ | ✅ | ✅ | ✅ | ✅ |
| Archive conversation | ✅ | ✅ | ✅ | ✅ | ✅ |
| Delete conversation | ✅ | ✅ | ✅ | ✅ | ✅ |
| Mute conversation | ✅ | ✅ | ✅ | ✅ | ✅ |
| Send deal proposal | ✅ | ✅ | ✅ | ❌ | ❌ |
| Accept/reject deal | ✅ | ✅ | ✅ | ❌ | ❌ |

---

## 5. Role-Specific Chat Flows

### 5.1 Factory → Seller Flow

```
┌─────────────┐                    ┌─────────────┐
│   Factory   │                    │    Seller   │
└──────┬──────┘                    └──────┬──────┘
       │                                   │
       │ 1. Start deal_negotiation         │
       │──────────────────────────────────>│
       │                                   │
       │ 2. Send product specifications    │
       │──────────────────────────────────>│
       │                                   │
       │ 3. Submit deal proposal           │
       │──────────────────────────────────>│
       │                                   │
       │                          ┌────────┴────────┐
       │                          │ Review Proposal │
       │                          └────────┬────────┘
       │                                   │
       │ 4. Counter-proposal (optional)    │
       │<──────────────────────────────────│
       │                                   │
       │ 5. Accept/Reject                  │
       │<──────────────────────────────────│
       │                                   │
       │ 6. Deal created → Order flow      │
       │                                   │
```

### 5.2 Customer → Seller Flow

```
┌─────────────┐                    ┌─────────────┐
│   Customer  │                    │    Seller   │
└──────┬──────┘                    └──────┬──────┘
       │                                   │
       │ 1. Browse products                │
       │                                   │
       │ 2. Click "Contact Seller"         │
       │    (product.allow_chat = true)    │
       │──────────────────────────────────>│
       │                                   │
       │ 3. Product inquiry (general)      │
       │──────────────────────────────────>│
       │                                   │
       │ 4. Negotiate price (optional)     │
       │──────────────────────────────────>│
       │                                   │
       │ 5. Place order                    │
       │                                   │
       │ 6. Order support conversation     │
       │<──────────────────────────────────>│
       │                                   │
```

### 5.3 Middleman Multi-Party Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Factory   │     │  Middleman  │     │    Seller   │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       │ 1. Start conv     │                   │
       │<─────────────────>│                   │
       │                   │                   │
       │ 2. Negotiate      │                   │
       │<─────────────────>│                   │
       │                   │                   │
       │                   │ 3. Start conv     │
       │                   │<─────────────────>│
       │                   │                   │
       │                   │ 4. Negotiate      │
       │                   │<─────────────────>│
       │                   │                   │
       │                   │ 5. Create deals   │
       │                   │ (party_a, party_b)│
       │                   │                   │
       │ 6. Deal accepted  │                   │ 6. Deal accepted
       │<─────────────────│                   │<─────────────────
       │                   │                   │
       │                   │ 7. Commission     │
       │                   │    tracked        │
       │                   │                   │
```

### 5.4 Seller → Delivery Flow

```
┌─────────────┐                    ┌─────────────┐
│    Seller   │                    │   Delivery  │
└──────┬──────┘                    └──────┬──────┘
       │                                   │
       │ 1. Order ready for delivery       │
       │──────────────────────────────────>│
       │                                   │
       │ 2. Assign delivery                │
       │──────────────────────────────────>│
       │                                   │
       │ 3. Accept assignment              │
       │<──────────────────────────────────│
       │                                   │
       │ 4. Pickup confirmation + photo    │
       │<──────────────────────────────────│
       │                                   │
       │ 5. Location updates (real-time)   │
       │<──────────────────────────────────│
       │                                   │
       │ 6. Delivery confirmation          │
       │<──────────────────────────────────│
       │                                   │
```

---

## 6. Row Level Security (RLS) Policies

### 6.1 Conversations Table RLS

```sql
-- Enable RLS
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;

-- View: Users can only see conversations they participate in
CREATE POLICY conversations_view_own ON conversations
  FOR SELECT TO authenticated
  USING (
    id IN (
      SELECT conversation_id
      FROM conversation_participants
      WHERE user_id = auth.uid()
    )
  );

-- Insert: Allow authenticated users to create conversations
CREATE POLICY conversations_insert_own ON conversations
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- Update: Users can update conversations they participate in
CREATE POLICY conversations_update_own ON conversations
  FOR UPDATE TO authenticated
  USING (
    id IN (
      SELECT conversation_id
      FROM conversation_participants
      WHERE user_id = auth.uid()
    )
  );

-- Delete: Users can delete conversations they participate in
CREATE POLICY conversations_delete_own ON conversations
  FOR DELETE TO authenticated
  USING (
    id IN (
      SELECT conversation_id
      FROM conversation_participants
      WHERE user_id = auth.uid()
    )
  );
```

### 6.2 Conversation Participants Table RLS

```sql
-- Enable RLS
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;

-- View: Users can only see their own participation records
CREATE POLICY participants_view_own ON conversation_participants
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Insert: Users can only insert their own participation
CREATE POLICY participants_insert_own ON conversation_participants
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Update: Users can update their own participation
CREATE POLICY participants_update_own ON conversation_participants
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

-- Delete: Users can delete their own participation
CREATE POLICY participants_delete_own ON conversation_participants
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());
```

### 6.3 Messages Table RLS

```sql
-- Enable RLS
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- View: Users can only see messages in conversations they participate in
CREATE POLICY messages_view_own ON messages
  FOR SELECT TO authenticated
  USING (
    conversation_id IN (
      SELECT conversation_id
      FROM conversation_participants
      WHERE user_id = auth.uid()
    )
  );

-- Insert: Users can only send messages in their conversations
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

-- Update: Users can only update their own messages
CREATE POLICY messages_update_own ON messages
  FOR UPDATE TO authenticated
  USING (sender_id = auth.uid());

-- Delete: Users can only delete their own messages
CREATE POLICY messages_delete_own ON messages
  FOR DELETE TO authenticated
  USING (sender_id = auth.uid());
```

### 6.4 Conversation Deals Table RLS

```sql
-- Enable RLS
ALTER TABLE conversation_deals ENABLE ROW LEVEL SECURITY;

-- View: Proposer or recipient can view deal proposals
CREATE POLICY conversation_deals_view_own ON conversation_deals
  FOR SELECT TO authenticated
  USING (
    proposer_id = auth.uid() OR recipient_id = auth.uid()
  );

-- Insert: Only proposer can create deal proposals
CREATE POLICY conversation_deals_insert_own ON conversation_deals
  FOR INSERT TO authenticated
  WITH CHECK (proposer_id = auth.uid());

-- Update: Both parties can update deal status
CREATE POLICY conversation_deals_update_own ON conversation_deals
  FOR UPDATE TO authenticated
  USING (
    proposer_id = auth.uid() OR recipient_id = auth.uid()
  );
```

### 6.5 Storage Bucket RLS (Chat Attachments)

```sql
-- Private bucket for chat attachments
-- Bucket ID: 'chat-attachments'

-- Upload: Users can upload to their conversation folders
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

-- View: Users can view attachments in their conversations
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

-- Delete: Users can delete attachments in their conversations
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
```

---

## 7. Realtime Subscriptions

### 7.1 Supabase Realtime Configuration

The chat system uses Supabase Realtime for instant message delivery and presence updates.

#### Enable Realtime on Tables

```sql
-- Enable realtime for messages table
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE conversation_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE conversation_deals;
```

### 7.2 Client-Side Subscriptions (Flutter)

#### Messages Channel
```dart
// Subscribe to messages in active conversation
RealtimeChannel _messagesChannel = supabase
  .channel('messages:$conversationId')
  .onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'messages',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'conversation_id',
      value: conversationId,
    ),
  )
  .subscribe();
```

#### Typing Indicators
```dart
// Broadcast typing status via presence
RealtimeChannel _typingChannel = supabase
  .channel('typing:$conversationId')
  .onPresenceSync((data) {
    // Update typing users list
    _updateTypingUsers(data);
  })
  .subscribe();

// Send typing indicator
await _typingChannel.track({
  'user_id': currentUserId,
  'is_typing': true,
});
```

#### Conversation Updates
```dart
// Subscribe to conversation updates
RealtimeChannel _convChannel = supabase
  .channel('conversations:$conversationId')
  .onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'conversations',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'id',
      value: conversationId,
    ),
  )
  .subscribe();
```

### 7.3 Realtime Events

| Event | Table | Trigger | Payload |
|-------|-------|---------|---------|
| `message:new` | messages | INSERT | Full message record |
| `message:update` | messages | UPDATE | Changed fields (read_at, is_deleted) |
| `conversation:update` | conversations | UPDATE | last_message, last_message_at |
| `deal:proposal` | conversation_deals | INSERT | New deal proposal |
| `deal:update` | conversation_deals | UPDATE | Status change |
| `typing:status` | Presence | track/untrack | user_id, is_typing |

---

## 8. Chat System Data Flow

### 8.1 Complete Message Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CHAT SYSTEM DATA FLOW                          │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────┐                              ┌──────────────┐
│   Sender     │                              │   Receiver   │
│   (Client)   │                              │   (Client)   │
└──────┬───────┘                              └──────┬───────┘
       │                                             │
       │ 1. Compose Message                          │
       │    (text/image/file)                        │
       │                                             │
       │ 2. ChatProvider.sendTextMessage()           │
       │    /sendImageMessage()                      │
       │    /sendFileMessage()                       │
       │                                             │
       │ 3. Upload Attachment (if any)               │
       │    → storage.objects                        │
       │    → Bucket: chat-attachments               │
       │                                             │
       ▼                                             │
┌──────────────────────────────────────────────────────────────────────┐
│                         SUPABASE BACKEND                              │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ 4. INSERT into messages table                                   │ │
│  │    - conversation_id                                            │ │
│  │    - sender_id                                                  │ │
│  │    - content / attachment_url                                   │ │
│  │    - message_type / message_subtype                             │ │
│  │    - RLS Check: sender is participant                           │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                               │                                       │
│                               ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ 5. TRIGGER: update_conversation_on_message()                    │ │
│  │    - UPDATE conversations                                       │ │
│  │    - SET last_message, last_message_at, updated_at              │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                               │                                       │
│                               ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ 6. Realtime Broadcast (supabase_realtime publication)           │ │
│  │    - Event: INSERT on messages                                  │ │
│  │    - Filter: conversation_id = ?                                │ │
│  │    - Payload: Full message record                               │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                                │
                                │ 7. Realtime Event Received
                                │    (Supabase Realtime Channel)
                                ▼
                       ┌─────────────────┐
                       │ Receiver Client │
                       │                 │
                       │ ChatProvider    │
                       │ listens to      │
                       │ channel         │
                       └────────┬────────┘
                                │
                                │ 8. Update UI
                                │    - Add message to list
                                │    - Show notification
                                │    - Update unread count
                                ▼
                       ┌─────────────────┐
                       │  Message Bubble │
                       │  Appears in     │
                       │  Chat Detail    │
                       └─────────────────┘
```

### 8.2 Conversation Start Flow

```
┌──────────────┐                              ┌──────────────┐
│   Customer   │                              │    Seller    │
│   (Client)   │                              │    (Client)  │
└──────┬───────┘                              └──────┬───────┘
       │                                             │
       │ 1. Browse Product Page                      │
       │    - Check product.allow_chat = true        │
       │                                             │
       │ 2. Tap "Contact Seller"                     │
       │                                             │
       │ 3. ChatProvider.startConversation()         │
       │    - sellerId: product.seller_id            │
       │    - productId: product.id                  │
       │                                             │
       ▼                                             │
┌──────────────────────────────────────────────────────────────────────┐
│                         SUPABASE BACKEND                              │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ 4. Call can_start_conversation() function                       │ │
│  │    - Validate: from_role = customer                             │ │
│  │    - Validate: to_role = seller                                 │ │
│  │    - Validate: product_id exists                                │ │
│  │    - Validate: product.allow_chat = true                        │ │
│  │    - Returns: TRUE/FALSE                                        │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                               │                                       │
│                               ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ 5. Check existing conversation                                  │ │
│  │    SELECT id FROM conversations                                 │ │
│  │    WHERE product_id = ? AND seller_id = ? AND user_id = ?       │ │
│  │                                                                 │ │
│  │    IF EXISTS → Return existing conversation                     │ │
│  │    ELSE → Create new conversation                               │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                               │                                       │
│                               ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ 6. INSERT into conversations                                    │ │
│  │    - product_id, seller_id, user_id                             │ │
│  │    - conversation_type = 'general'                              │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                               │                                       │
│                               ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ 7. INSERT into conversation_participants (x2)                   │ │
│  │    - Customer: role = 'customer'                                │ │
│  │    - Seller: role = 'seller'                                    │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                                │
                                │ 8. Return conversation ID
                                ▼
                       ┌─────────────────┐
                       │  Navigate to    │
                       │  Chat Detail    │
                       │  Screen         │
                       └─────────────────┘
```

### 8.3 Deal Proposal Flow

```
┌──────────────┐                              ┌──────────────┐
│   Factory    │                              │    Seller    │
│   (Client)   │                              │    (Client)  │
└──────┬───────┘                              └──────┬───────┘
       │                                             │
       │ 1. Negotiate in chat                        │
       │    (multiple messages)                      │
       │                                             │
       │ 2. Open Deal Proposal Form                  │
       │    - Enter price, quantity, terms           │
       │                                             │
       │ 3. ChatProvider.sendDealProposal()          │
       │    - Via DealChatService                    │
       │                                             │
       ▼                                             │
┌──────────────────────────────────────────────────────────────────────┐
│                         SUPABASE BACKEND                              │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ 4. INSERT into deals table                                      │ │
│  │    - middleman_id (if applicable)                               │ │
│  │    - party_a_id, party_b_id                                     │ │
│  │    - commission_rate                                            │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                               │                                       │
│                               ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ 5. INSERT into conversation_deals                               │ │
│  │    - conversation_id                                            │ │
│  │    - deal_id                                                    │ │
│  │    - proposer_id, recipient_id                                  │ │
│  │    - proposal_data (JSONB)                                      │ │
│  │    - status = 'pending'                                         │ │
│  │    - expires_at                                                 │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                               │                                       │
│                               ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ 6. TRIGGER: update_conversation_on_deal_proposal()              │ │
│  │    - UPDATE conversations                                       │ │
│  │    - SET conversation_type = 'deal_negotiation'                 │ │
│  │    - SET last_message = '🤝 Deal proposal sent'                 │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                               │                                       │
│                               ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ 7. INSERT notification for recipient                            │ │
│  │    - type = 'message'                                           │ │
│  │    - title = 'New Deal Proposal'                                │ │
│  │    - metadata = {deal_id, conversation_id}                      │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                                │
                                │ 8. Realtime Event
                                ▼
                       ┌─────────────────┐
                       │  Seller receives│
                       │  notification   │
                       │  & sees proposal│
                       └────────┬────────┘
                                │
                                │ 9. Accept/Reject/Counter
                                ▼
                       ┌─────────────────┐
                       │  UPDATE         │
                       │  conversation_  │
                       │  deals.status   │
                       └─────────────────┘
```

---

## 9. Summary Table

### 9.1 Database Objects Summary

| Object Type | Name | Purpose |
|-------------|------|---------|
| **Table** | `conversations` | Store conversation metadata |
| **Table** | `conversation_participants` | Track users in conversations |
| **Table** | `messages` | Store individual messages |
| **Table** | `conversation_deals` | Track deal proposals in conversations |
| **Type** | `user_role` | ENUM: factory, seller, middleman, customer, delivery |
| **Type** | `conversation_type` | ENUM: general, deal_negotiation, order_support |
| **Function** | `can_start_conversation()` | Validate conversation initiation |
| **Function** | `update_conversation_on_message()` | Trigger: update conversation on new message |
| **Function** | `update_conversation_on_deal_proposal()` | Trigger: update conversation on deal |
| **Function** | `update_conversation_timestamp()` | Trigger: auto-update timestamp |
| **Function** | `update_message_timestamp()` | Trigger: auto-update message timestamp |
| **Function** | `messages_tsvector_trigger()` | Trigger: maintain full-text search index |
| **Function** | `get_unread_message_count()` | Helper: count unread messages |
| **Function** | `is_conversation_participant()` | Helper: check participation |
| **Storage** | `chat-attachments` | Private bucket for file uploads |
| **Index** | `idx_conversations_*` | Performance optimization (5 indexes) |
| **Index** | `idx_participants_*` | Performance optimization (2 indexes) |
| **Index** | `idx_messages_*` | Performance optimization (5 indexes) |
| **Index** | `idx_conversation_deals_*` | Performance optimization (5 indexes) |

### 9.2 RLS Policies Summary

| Table | Policy Name | Operation | Access Rule |
|-------|-------------|-----------|-------------|
| `conversations` | `conversations_view_own` | SELECT | Participants only |
| `conversations` | `conversations_insert_own` | INSERT | Authenticated users |
| `conversations` | `conversations_update_own` | UPDATE | Participants only |
| `conversations` | `conversations_delete_own` | DELETE | Participants only |
| `conversation_participants` | `participants_view_own` | SELECT | Own records only |
| `conversation_participants` | `participants_insert_own` | INSERT | Own records only |
| `conversation_participants` | `participants_update_own` | UPDATE | Own records only |
| `conversation_participants` | `participants_delete_own` | DELETE | Own records only |
| `messages` | `messages_view_own` | SELECT | Conversation participants |
| `messages` | `messages_insert_own` | INSERT | Participants, own messages |
| `messages` | `messages_update_own` | UPDATE | Own messages only |
| `messages` | `messages_delete_own` | DELETE | Own messages only |
| `conversation_deals` | `conversation_deals_view_own` | SELECT | Proposer or recipient |
| `conversation_deals` | `conversation_deals_insert_own` | INSERT | Proposer only |
| `conversation_deals` | `conversation_deals_update_own` | UPDATE | Proposer or recipient |
| `storage.objects` | Upload attachments | INSERT | Conversation participants |
| `storage.objects` | View attachments | SELECT | Conversation participants |
| `storage.objects` | Delete attachments | DELETE | Conversation participants |

### 9.3 API Methods Summary (Flutter)

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `fetchConversations()` | - | `Future<void>` | Load all user conversations |
| `startConversation()` | sellerId, productId? | `Future<String?>` | Create new conversation |
| `loadMessages()` | conversationId | `Future<void>` | Load messages with pagination |
| `sendTextMessage()` | conversationId, content | `Future<void>` | Send text message |
| `sendImageMessage()` | conversationId, imageFile, caption? | `Future<void>` | Send image with upload |
| `sendFileMessage()` | conversationId, file | `Future<void>` | Send file attachment |
| `deleteMessage()` | messageId | `Future<void>` | Soft delete message |
| `archiveConversation()` | conversationId | `Future<void>` | Archive conversation |
| `deleteConversation()` | conversationId | `Future<void>` | Delete conversation |
| `setActiveConversation()` | conversation | `Future<void>` | Subscribe to realtime |
| `sendTypingIndicator()` | conversationId, isTyping | `void` | Broadcast typing status |
| `markAsRead()` | conversationId | `Future<void>` | Mark messages as read |
| `searchMessages()` | conversationId, query | `Future<List<ChatMessage>>` | Search within conversation |

### 9.4 File Structure

```
lib/
├── models/
│   └── chat/
│       ├── conversation.dart      # ChatConversation model
│       ├── message.dart           # ChatMessage model
│       └── deal_proposal.dart     # DealProposal model
├── pages/
│   └── chat/
│       ├── chat_list.dart         # Conversation list screen
│       └── chat_detail.dart       # Message thread screen
├── services/
│   ├── chat_provider.dart         # State management
│   ├── deal_chat_service.dart     # Deal proposal logic
│   └── supabase.dart              # Supabase client + AccountType enum
└── widgets/
    └── drawer.dart                # Navigation drawer (updated)

supabase/
└── migrations/
    ├── 003_chat_system_rls.sql    # RLS policies
    └── 004_chat_system_schema.sql # Tables, indexes, triggers

Database:
├── Tables: 4 (conversations, participants, messages, deals)
├── Functions: 8 (validation, triggers, helpers)
├── Triggers: 5 (auto-updates, search index)
├── Indexes: 17 (performance optimization)
├── RLS Policies: 18 (security)
└── Storage: 1 bucket (chat-attachments)
```

### 9.5 Security Features

| Feature | Implementation |
|---------|----------------|
| **Authentication** | Supabase Auth (JWT tokens) |
| **Authorization** | Row Level Security (RLS) on all tables |
| **Participant Verification** | RLS checks `conversation_participants` before message access |
| **Sender Verification** | `sender_id = auth.uid()` enforced by RLS |
| **Role-Based Access** | `can_start_conversation()` function validates roles |
| **Private Storage** | Chat attachments bucket with participant-only access |
| **Soft Delete** | Messages marked as deleted (audit trail preserved) |
| **Input Validation** | CHECK constraints on ENUMs and status fields |
| **SQL Injection Prevention** | Parameterized queries via Supabase client |

### 9.6 Performance Optimizations

| Optimization | Description |
|--------------|-------------|
| **Composite Indexes** | `(conversation_id, created_at DESC)` for message queries |
| **Partial Indexes** | `WHERE read_at IS NULL` for unread messages |
| **Full-Text Search** | `content_tsvector` with GIN index |
| **Cached Fields** | `last_message`, `last_message_at` in conversations |
| **Auto-Update Triggers** | Maintain conversation metadata automatically |
| **Realtime Filters** | Channel subscriptions filtered by conversation_id |
| **Pagination** | Load messages in batches (LIMIT/OFFSET) |
| **Connection Pooling** | Supabase managed PostgreSQL connection pool |

---

## Appendix A: Conversation Type Definitions

```sql
-- Conversation types define the purpose and rules of a conversation
conversation_type:
  - 'general'           : Standard chat (product inquiries, general discussion)
  - 'deal_negotiation'  : B2B deal discussions with proposal capabilities
  - 'order_support'     : Post-purchase support and delivery coordination

-- Message subtypes for special message types
message_subtype:
  - 'text'              : Plain text message
  - 'deal_proposal'     : Initial deal proposal
  - 'deal_counter'      : Counter-offer to a proposal
  - 'deal_accepted'     : Acceptance notification
  - 'deal_rejected'     : Rejection notification
  - 'file'              : File attachment
  - 'image'             : Image attachment
```

## Appendix B: Status Enums

```sql
-- Deal proposal status
conversation_deals.status:
  - 'pending'    : Awaiting response
  - 'accepted'   : Deal accepted by recipient
  - 'rejected'   : Deal rejected by recipient
  - 'expired'    : Proposal expired (past expires_at)
  - 'cancelled'  : Proposal cancelled by proposer

-- Delivery assignment status (for delivery conversations)
delivery_assignments.status:
  - 'pending'    : Awaiting driver acceptance
  - 'accepted'   : Driver accepted assignment
  - 'picked_up'  : Order picked up
  - 'delivered'  : Order delivered
  - 'cancelled'  : Assignment cancelled
```

## Appendix C: Message Type Examples

```dart
// Text message
{
  "id": "uuid",
  "conversation_id": "uuid",
  "sender_id": "uuid",
  "content": "What's the price for 100 units?",
  "message_type": "text",
  "message_subtype": "text",
  "created_at": "2024-03-11T10:30:00Z"
}

// Image message
{
  "id": "uuid",
  "conversation_id": "uuid",
  "sender_id": "uuid",
  "content": "Here's the product sample",
  "message_type": "image",
  "message_subtype": "image",
  "attachment_url": "https://.../chat-attachments/conv_id/image.jpg",
  "attachment_name": "sample.jpg",
  "attachment_size": 245678,
  "created_at": "2024-03-11T10:35:00Z"
}

// Deal proposal message
{
  "id": "uuid",
  "conversation_id": "uuid",
  "sender_id": "uuid",
  "content": "I propose the following deal...",
  "message_type": "text",
  "message_subtype": "deal_proposal",
  "created_at": "2024-03-11T11:00:00Z"
}
```

---

**Document Version:** 1.0  
**Last Updated:** March 11, 2026  
**Platform:** Aurora E-Commerce  
**Database:** PostgreSQL (Supabase)  
**Client:** Flutter (Dart)
