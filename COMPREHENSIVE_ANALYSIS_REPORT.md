# 🎯 Aurora Project - Comprehensive Analysis Report

**Date:** March 31, 2026  
**Status:** Complete Analysis → Ready for Refactoring

---

## 📋 Executive Summary

Aurora is a **seller-only e-commerce platform** with offline-first architecture. The project currently uses Supabase Edge Functions that need to be **eliminated** in favor of direct SQL queries executed from the Flutter app with offline-first support.

**Key Transformation:**

- ❌ Remove 14+ Edge Functions
- ✅ Use direct SQL queries + local SQLite storage
- ✅ Add offline-first sync mechanism
- ✅ Verify seller on login
- ✅ Update notification & chat systems

---

## 1. DATA MODEL ANALYSIS

### 1.1 Product-Seller Relationship

```
┌─────────────────────────────────────────────────┐
│            AUTH.USERS (Supabase Auth)          │
│              ├─ id (UUID)                       │
│              ├─ email                           │
│              ├─ metadata (account_type, etc)    │
└────┬──────────────────────────┬────────────────┘
     │                          │
     ▼                          ▼
┌──────────────────┐    ┌─────────────────────┐
│   SELLERS        │    │   PRODUCTS          │
│                  │    │                     │
│ • user_id (FK)  │    │ • id (UUID)         │
│ • email         │    │ • seller_id (FK) ───┼──→ auth.users
│ • full_name     │    │ • asin/sku          │
│ • phone         │    │ • title             │
│ • location      │    │ • price             │
│ • currency      │    │ • quantity          │
│ • is_verified   │    │ • status            │
│ • account_type  │    │ • allow_chat        │
│ • is_factory    │    │ • images (JSONB)    │
│ • latitude      │    │ • attributes        │
│ • longitude     │    └─────────────────────┘
└──────────────────┘
```

**Key Constraint:** `products.seller_id REFERENCES auth.users(id)`

### 1.2 Local Database Storage

**SellerDB** (`lib/backend/sellerdb.dart`):

```sql
CREATE TABLE sellers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT UNIQUE,           -- Links to auth.users.id
  firstname TEXT,
  secondname TEXT,
  thirdname TEXT,
  fourthname TEXT,
  full_name TEXT,
  email TEXT UNIQUE,
  location TEXT,
  phone TEXT,
  currency TEXT DEFAULT 'USD',
  account_type TEXT DEFAULT 'seller',
  is_verified INTEGER DEFAULT 0,
  latitude REAL,
  longitude REAL,
  created_at TEXT,
  updated_at TEXT
);
```

**ProductsDB** (`lib/backend/products_db.dart`):

```sql
CREATE TABLE products (
  id TEXT PRIMARY KEY,
  asin TEXT UNIQUE,
  seller_id TEXT,                -- Links to sellers.user_id
  title TEXT,
  description TEXT,
  brand TEXT,
  price REAL,
  quantity INTEGER,
  status TEXT,
  images JSONB,
  attributes JSONB,
  is_synced INTEGER,
  synced_at TEXT,
  created_at TEXT,
  updated_at TEXT
);
```

**⚠️ Issue:** No explicit FK constraint in SQLite (offline storage), relies on manual sync logic

---

## 2. CURRENT EDGE FUNCTIONS (TO BE REMOVED)

### 2.1 Existing Functions in `supabase/functions/`

| Function                     | Purpose                           | Current Status |
| ---------------------------- | --------------------------------- | -------------- |
| `process-signup`             | Create seller profile on signup   | ⚠️ Deployed    |
| `process-login`              | Verify seller & update last_login | ⚠️ Deployed    |
| `create-product`             | Insert product                    | ❌ Local only  |
| `update-product`             | Modify product                    | ❌ Local only  |
| `delete-product`             | Remove product                    | ❌ Local only  |
| `search-products`            | Full-text search                  | ❌ Local only  |
| `manage-product`             | Generic CRUD                      | ❌ Local only  |
| `upload-image`               | Store image in storage bucket     | ❌ Local only  |
| `delete-image`               | Remove image from storage         | ❌ Local only  |
| `get-image-url`              | Get signed URL for image          | ❌ Local only  |
| `find-nearby-factories`      | Geospatial search                 | ❌ Local only  |
| `rate-factory`               | Submit factory ratings            | ❌ Local only  |
| `create-order`               | Create order                      | ❌ Local only  |
| `get-or-create-conversation` | Chat initialization               | ❌ Local only  |

**Total:** 14 functions to eliminate

### 2.2 Where Edge Functions Are Called

**Flutter Code References:**

- `lib/services/supabase.dart` - `callEdgeFunction()` method
- Various product CRUD operations invoke edge functions
- Chat system may use edge functions

---

## 3. NOTIFICATION SYSTEM ANALYSIS

### 3.1 Notifications Table Schema

**File:** `supabase/migrations/009_create_notifications_table.sql`

```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT CHECK (type IN (
    'order',      -- Order-related
    'message',    -- New chat message
    'deal',       -- Deal proposal
    'product',    -- Price drop, restock
    'system',     -- Announcements
    'payment',    -- Payment confirmations
    'shipping',   -- Shipping updates
    'review'      -- Review notifications
  )),
  priority TEXT CHECK (priority IN ('low', 'medium', 'high')),
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMPTZ,
  reference_type TEXT,  -- 'order', 'product', 'conversation'
  reference_id UUID,
  action_url TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 3.2 Current Implementation

**Service:** `lib/services/notification_service.dart`

- Handles real-time notifications
- Fetches unread count
- Polling + stream subscriptions
- Caching mechanism

**⚠️ Status:** Partially implemented, needs integration

### 3.3 Actions Required

1. ✅ Table already exists in `atall.sql`
2. ⚠️ Create `notifications.sql` file with complete schema including:
   - RLS policies for sellers/customers
   - Triggers for auto-notification creation
   - Indexes for performance
   - Helper functions

---

## 4. CHAT SYSTEM ANALYSIS

### 4.1 Chat Database Structure

**Tables:**

- `conversations` - Chat threads with optional product link
- `conversation_participants` - Users in each conversation
- `messages` - Individual messages (text/image/file)
- `chat-attachments` - Storage bucket for files

**Status:** ✅ Complete implementation in `supabase/migrations/004_chat_system_schema.sql`

### 4.2 RLS Policies

**File:** `supabase/migrations/003_chat_system_rls.sql`

**Security Model:**

- Users can only view conversations they participate in
- Users can only send messages in their conversations
- Users can only update/delete their own messages
- Storage bucket access restricted to participants

### 4.3 Current Implementation

**Service:** `lib/services/chat_provider.dart`

- Fetch conversations with pagination
- Send text/image/file messages
- Real-time message subscriptions
- Typing indicators
- Read receipts
- Archive/delete conversations

**UI:** `lib/pages/chat/`

- Chat list with tabs (Messages/Archived)
- Message thread with bubbles
- Attachment picker

**Status:** ✅ Production ready

---

## 5. LOGIN & SELLER VERIFICATION FLOW

### 5.1 Current Implementation

**File:** `lib/pages/singup/login.dart`

```dart
_handleLogin() async {
  // 1. Call Supabase Auth login
  final response = await supabase.login(
    email: email,
    password: password,
  );

  // 2. System currently doesn't verify seller account type
  // ⚠️ BUG: Any user can login (no seller check)

  // 3. (Optional) Call process-login edge function
  // - Updates last_login timestamp
  // - Returns seller data
}
```

### 5.2 Issues

| Issue                             | Impact                                   | Severity  |
| --------------------------------- | ---------------------------------------- | --------- |
| No account_type check             | Non-sellers might access seller features | 🔴 High   |
| Edge function optional            | Login verification skipped sometimes     | 🟡 Medium |
| No error handling for non-sellers | Fails silently                           | 🔴 High   |
| Local DB not updated on login     | Offline sync broken                      | 🔴 High   |

### 5.3 Required Changes

```dart
// NEW LOGIN FLOW
_handleSellerLogin() async {
  // 1. Authenticate with Supabase
  final authResult = await supabase.login(
    email: email,
    password: password,
  );

  if (!authResult.success) return showError(authResult.message);

  // 2. ✅ VERIFY SELLER ACCOUNT
  final isSeller = await verifySellerAccount(authResult.data['user'].id);

  if (!isSeller) {
    await supabase.logout();
    return showError('This app is for sellers only');
  }

  // 3. ✅ LOAD SELLER PROFILE TO LOCAL DB
  final seller = await supabase.getSellerProfile();
  await sellerDb.addSeller(seller);

  // 4. ✅ SYNC PRODUCTS TO LOCAL DB
  await syncProductsOffline();

  // 5. Navigate to home
  goToHome();
}
```

---

## 6. OFFLINE-FIRST ARCHITECTURE

### 6.1 Current State

**Local Storage:** SQLite with SellerDB & ProductsDB
**Sync Status:** `is_synced` flag on products
**Offline Capability:** Partial (products only)

### 6.2 Required Offline Support

| Entity         | Status | Required |
| -------------- | ------ | -------- |
| Seller Profile | Local  | ✅       |
| Products       | Local  | ✅       |
| Orders         | Local  | ⚠️       |
| Messages       | Local  | ⚠️       |
| Notifications  | Local  | ⚠️       |
| Conversations  | Local  | ⚠️       |
| Sync Queue     | Local  | ✅       |

### 6.3 Offline Sync Strategy

```
ONLINE MODE:
1. Fetch from Supabase
2. Cache to SQLite
3. Display from cache

OFFLINE MODE:
1. Display from SQLite cache
2. Queue changes locally
3. Add to sync queue

RECONNECTION:
1. Detect network
2. Process sync queue (FIFO order)
3. Handle conflicts
4. Fetch latest from server
5. Update cache
```

---

## 7. TESTING REQUIREMENTS

### 7.1 Unit Tests

```
✅ Product model serialization
✅ Seller model with location fields
✅ Chat message model
✅ Seller DB CRUD operations
✅ Product DB CRUD operations
✅ Auth provider login flow
✅ Notification model
```

### 7.2 Integration Tests

```
⚠️ Seller signup → seller creation in DB
⚠️ Seller login → profile loaded to local DB
⚠️ Product creation → synced to Supabase
⚠️ Chat initiation → conversation created
⚠️ Message sending → real-time delivery
⚠️ Offline product creation → queued & synced
```

### 7.3 E2E Tests

```
⚠️ Complete seller signup flow
⚠️ Product listing & management
⚠️ Chat conversation flow
⚠️ Offline mode (disable network, perform actions, reconnect)
⚠️ Real-time notifications
```

---

## 8. SQL RECOMMENDATIONS FROM atall.sql

### 8.1 Key Queries to Implement

**Get Seller Profile:**

```sql
SELECT * FROM sellers
WHERE user_id = $1 AND is_verified = true
LIMIT 1;
```

**Get Seller Products:**

```sql
SELECT * FROM products
WHERE seller_id = $1 AND status = 'active'
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;
```

**Get Conversation with New Messages:**

```sql
SELECT c.*,
  COUNT(CASE WHEN m.read_at IS NULL THEN 1 END) as unread_count
FROM conversations c
LEFT JOIN messages m ON c.id = m.conversation_id
WHERE c.id IN (
  SELECT conversation_id FROM conversation_participants
  WHERE user_id = $1
)
GROUP BY c.id
ORDER BY c.updated_at DESC;
```

**Get Unread Notifications:**

```sql
SELECT * FROM notifications
WHERE user_id = $1 AND is_read = false
ORDER BY created_at DESC;
```

### 8.2 Database Indexes (from atall.sql)

```sql
-- Already exist, verify deployment:
CREATE INDEX idx_products_seller_id ON products(seller_id);
CREATE INDEX idx_sellers_user_id ON sellers(user_id);
CREATE INDEX idx_sellers_email ON sellers(email);
CREATE INDEX idx_sellers_account_type ON sellers(account_type);
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_conversations_updated_at ON conversations(updated_at DESC);
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
```

---

## 9. FILES STRUCTURE SUMMARY

### 9.1 Database Files

```
supabase/
├── migrations/
│   ├── 001_setup_storage_and_rls.sql
│   ├── 003_chat_system_rls.sql
│   ├── 004_chat_system_schema.sql
│   └── 009_create_notifications_table.sql
├── complete_setup.sql
├── database_schema.sql
└── [14+ Edge Functions to DELETE]

Root:
├── atall.sql              ✅ Master schema (PRIMARY SOURCE)
├── jo.sql                 (Old backup)
└── notifications.sql      ⚠️ NEEDS CREATION
```

### 9.2 Flutter Files

```
lib/
├── models/
│   ├── aurora_product.dart
│   ├── seller.dart
│   └── chat/
│       ├── conversation.dart
│       └── message.dart
│
├── backend/
│   ├── sellerdb.dart
│   └── products_db.dart
│
├── services/
│   ├── supabase.dart        (Remove edge function calls)
│   ├── auth_provider.dart   (Update login flow)
│   ├── chat_provider.dart   (Verify working)
│   ├── notification_service.dart
│   └── queue_service.dart   (Offline sync)
│
└── pages/
    └── singup/
        └── login.dart       (Update to verify seller)
```

---

## 10. REFACTORING ROADMAP

### Phase 1: Analysis & Planning ✅ COMPLETE

- [x] Analyze product-seller relationship
- [x] Map edge functions to SQL
- [x] Review chat system
- [x] Review notifications
- [x] Create comprehensive report

### Phase 2: Database & Notifications (Next)

- [ ] Create `notifications.sql` with complete schema
- [ ] Add RLS policies for notifications
- [ ] Create notification triggers in atall.sql
- [ ] Add notification indexes

### Phase 3: Remove Edge Functions

- [ ] Remove all 14 edge functions from `supabase/functions/`
- [ ] Update Flutter to use direct SQL queries
- [ ] Implement client-side SQL execution
- [ ] Add error handling for direct queries

### Phase 4: Update Login Flow

- [ ] Add seller verification check
- [ ] Load seller profile to local DB on login
- [ ] Initialize sync queue
- [ ] Add account_type validation

### Phase 5: Offline-First Implementation

- [ ] Create sync queue table in local DB
- [ ] Implement queue processor
- [ ] Add conflict resolution logic
- [ ] Add network state detection

### Phase 6: Testing

- [ ] Update unit tests
- [ ] Add integration tests
- [ ] Add E2E tests
- [ ] Test offline mode thoroughly

### Phase 7: Documentation

- [ ] Update README with new architecture
- [ ] Create offline-first guide
- [ ] Document SQL queries
- [ ] Create testing guide

---

## 11. KEY METRICS

| Metric               | Value                                     | Note                                                             |
| -------------------- | ----------------------------------------- | ---------------------------------------------------------------- |
| Total Edge Functions | 14                                        | To be eliminated                                                 |
| Local DB Tables      | 2 (Seller, Product)                       | Core tables                                                      |
| Chat Tables          | 3 (Conversations, Participants, Messages) | Complete                                                         |
| Notification Types   | 8                                         | order, message, deal, product, system, payment, shipping, review |
| SQL Indexes          | 10+                                       | Already created in atall.sql                                     |
| RLS Policies         | 18+                                       | Existing chat + new notification policies needed                 |
| Unit Tests           | 69                                        | Existing (need updates)                                          |
| Lines of Code        | ~5,000                                    | Flutter + SQL + Documentation                                    |

---

## 12. RISKS & MITIGATIONS

| Risk                     | Likelihood | Impact   | Mitigation                                     |
| ------------------------ | ---------- | -------- | ---------------------------------------------- |
| Seller verification bug  | Medium     | High     | Add unit tests, manually verify login          |
| Offline sync conflicts   | High       | High     | Implement conflict resolution rules            |
| Network status detection | Low        | Medium   | Use connectivity plugin + manual checks        |
| Chat real-time issues    | Low        | Medium   | Keep Realtime subscriptions, test thoroughly   |
| Notification miss        | Medium     | High     | Implement polling + push notifications         |
| SQL injection            | Low        | Critical | Use parameterized queries (Supabase does this) |

---

## 13. NEXT STEPS

1. **Create notifications.sql** with RLS policies and triggers
2. **Update login flow** with seller verification
3. **Remove edge functions** from flutter code
4. **Implement offline sync queue**
5. **Create comprehensive test suite**
6. **Update documentation**

---

**Status:** Ready for Phase 2 implementation  
**Assigned:** Next steps documented above  
**Priority:** High - Core architecture changes
