# Aurora Multi-Role System Implementation

## Overview

This document describes the comprehensive multi-role system implemented in the Aurora e-commerce platform. The system supports five distinct user roles with specific capabilities and data models.

## User Roles

| Role | Description | Key Capabilities |
|------|-------------|------------------|
| `user` | General user | Basic browsing, purchasing |
| `seller` | Merchant/Seller | Product management, sales, customer management |
| `factory` | Manufacturer | Wholesale pricing, factory discovery, bulk orders |
| `middleman` | Commission Agent | Deal facilitation, party connections |
| `customer` | B2B Buyer | Customer management, order history |

## Files Modified/Created

### New Models

#### `lib/models/middleman_profile.dart`
Represents a middleman/commission agent profile:
- `userId`, `fullName`, `email`, `phone`
- `companyName`, `businessLicense`
- `commissionRate`, `specialization`
- `latitude`, `longitude` (for location-based matching)
- `totalDeals`, `totalCommissionEarned`, `averageRating`

#### `lib/models/deal.dart`
Represents a business deal facilitated by a middleman:
- `Deal` - Full deal model with all details
- `DealSummary` - Lightweight model for listings
- Status: `active`, `completed`, `cancelled`, `pending`

### Updated Files

#### `lib/services/supabase.dart`

**New Configuration Constants:**

```dart
// Table Names
static const String tableFactoryProfiles = 'factory_profiles';
static const String tableMiddlemanProfiles = 'middleman_profiles';
static const String tableDeals = 'deals';
static const String tableConversations = 'conversations';
static const String tableMessages = 'messages';
static const String tableFactoryConnections = 'factory_connections';
static const String tableFactoryRatings = 'factory_ratings';

// Edge Functions
static const String functionCreateDeal = 'create-deal';
static const String functionGetOrCreateConversation = 'get-or-create-conversation';

// Cache Keys
static const String cacheFactoryProfile = 'cache_factory_profile';
static const String cacheMiddlemanProfile = 'cache_middleman_profile';
static const String cacheCustomerProfile = 'cache_customer_profile';
static const String cacheDeals = 'cache_deals';
```

**Updated AccountType Enum:**
```dart
enum AccountType { 
  user,      // General user
  seller,    // Seller/merchant
  factory,   // Factory/manufacturer
  middleman, // Middleman/commission agent
  customer   // Customer (B2B buyer)
}
```

## New Methods in SupabaseProvider

### Authentication

#### `signup()` - Enhanced
Now supports all roles with role-specific parameters:
```dart
Future<AuthResult> signup({
  required String fullName,
  required AccountType accountType,
  required String phone,
  required String location,
  required String currency,
  required String email,
  required String password,
  String? language,
  // Factory-specific
  String? companyName,
  String? businessLicense,
  double? latitude,
  double? longitude,
  // Middleman-specific
  double? commissionRate,
  String? specialization,
})
```

#### `login()` - Enhanced
Automatically loads role-specific profile after authentication.

### Profile Management

#### Factory Profiles
```dart
Future<MiddlemanProfile?> getCurrentFactoryProfile()
Future<AuthResult> updateFactoryProfile({...})
```

#### Middleman Profiles
```dart
Future<MiddlemanProfile?> getCurrentMiddlemanProfile()
Future<AuthResult> updateMiddlemanProfile({...})
```

#### Customer Profiles
```dart
Future<Customer?> getCurrentCustomerProfile()
Future<AuthResult> updateCustomerProfile({...})
```

### Chat System

```dart
Future<String> getOrCreateConversation({
  required String otherUserId,
  String? productId,
})

Future<AuthResult> sendMessage({
  required String conversationId,
  required String content,
  String messageType = 'text',
  String? attachmentUrl,
})

Future<List<Map<String, dynamic>>> getMessages({
  required String conversationId,
  int limit = 50,
})

Future<List<Map<String, dynamic>>> getConversations()

Stream<List<Map<String, dynamic>>> getMessagesStream(String conversationId)

Future<AuthResult> markMessagesAsRead({required String conversationId})
```

### Deal Management (Middlemen)

```dart
Future<AuthResult> createDeal({
  required String partyAId,
  required String partyBId,
  String? productId,
  required double commissionRate,
  String? terms,
})

Future<List<Deal>> getMyDeals({String? status})
Future<List<Deal>> getDealsAsParty()
Future<AuthResult> updateDealStatus({
  required String dealId,
  required String status,
})
Future<Deal?> getDealById(String dealId)
```

### Location Management

```dart
Future<AuthResult> updateLocation({
  required double latitude,
  required double longitude,
})
```

Supports sellers, factories, and middlemen.

### Role Check Helpers

```dart
bool get isSeller
bool get isFactory
bool get isMiddleman
bool get isCustomer
bool get canSell           // seller OR factory
bool get canCreateDeals    // middleman only
bool get canManageFactoryConnections  // seller OR factory
```

### Internal Helper Methods

```dart
Future<void> _createFactoryRecord({...})
Future<void> _createMiddlemanRecord({...})
Future<void> _createCustomerRecord({...})
bool _isSellerOrFactory()
AuthResult _validateRole(AccountType requiredRole)
```

## Database Schema Requirements

### New Tables

#### `middleman_profiles`
```sql
CREATE TABLE middleman_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) UNIQUE,
  full_name TEXT,
  email TEXT,
  phone TEXT,
  location TEXT,
  company_name TEXT,
  commission_rate DECIMAL DEFAULT 0,
  specialization TEXT,
  latitude DECIMAL,
  longitude DECIMAL,
  is_verified BOOLEAN DEFAULT FALSE,
  total_deals INTEGER DEFAULT 0,
  total_commission_earned DECIMAL DEFAULT 0,
  average_rating DECIMAL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### `deals`
```sql
CREATE TABLE deals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  middleman_id UUID REFERENCES auth.users(id),
  party_a_id UUID REFERENCES auth.users(id),
  party_b_id UUID REFERENCES auth.users(id),
  product_id UUID REFERENCES products(id),
  commission_rate DECIMAL,
  commission_amount DECIMAL,
  status TEXT CHECK (status IN ('active', 'completed', 'cancelled', 'pending')),
  terms TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);
```

#### `conversations`
```sql
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  participant_a UUID REFERENCES auth.users(id),
  participant_b UUID REFERENCES auth.users(id),
  product_id UUID REFERENCES products(id),
  last_message TEXT,
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### `messages`
```sql
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID REFERENCES conversations(id),
  sender_id UUID REFERENCES auth.users(id),
  content TEXT,
  message_type TEXT DEFAULT 'text',
  attachment_url TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Usage Examples

### Register as Factory
```dart
final result = await supabaseProvider.signup(
  fullName: 'John Factory',
  accountType: AccountType.factory,
  email: 'john@factory.com',
  password: 'securePassword123',
  phone: '+1234567890',
  location: 'New York, USA',
  currency: 'USD',
  companyName: 'John\'s Manufacturing',
  latitude: 40.7128,
  longitude: -74.0060,
);
```

### Register as Middleman
```dart
final result = await supabaseProvider.signup(
  fullName: 'Jane Middleman',
  accountType: AccountType.middleman,
  email: 'jane@middleman.com',
  password: 'securePassword123',
  phone: '+1234567890',
  location: 'Chicago, USA',
  currency: 'USD',
  commissionRate: 5.0, // 5%
  specialization: 'Electronics',
);
```

### Create a Deal (Middleman)
```dart
final deal = await supabaseProvider.createDeal(
  partyAId: 'seller-uuid',
  partyBId: 'factory-uuid',
  productId: 'product-uuid',
  commissionRate: 5.0,
  terms: 'Payment within 30 days',
);
```

### Send a Message
```dart
// Get or create conversation
final conversationId = await supabaseProvider.getOrCreateConversation(
  otherUserId: 'other-user-uuid',
  productId: 'product-uuid',
);

// Send message
await supabaseProvider.sendMessage(
  conversationId: conversationId,
  content: 'Hello, I\'m interested in your product',
  messageType: 'text',
);
```

### Check User Role
```dart
if (supabaseProvider.isSeller) {
  // Show seller dashboard
} else if (supabaseProvider.isFactory) {
  // Show factory dashboard
} else if (supabaseProvider.isMiddleman) {
  // Show middleman dashboard
}
```

### Update Location
```dart
await supabaseProvider.updateLocation(
  latitude: 40.7128,
  longitude: -74.0060,
);
```

## Edge Functions Required

The following edge functions must be deployed:

1. **`create-deal`** - Creates deals with validation
2. **`get-or-create-conversation`** - Manages chat conversations
3. **`process-signup`** - Enhanced to handle all roles
4. **`process-login`** - Enhanced to load role-specific data

## Security Considerations

### Row Level Security (RLS)

All new tables should have RLS policies:

```sql
-- Middleman profiles
CREATE POLICY "Users can view own profile"
ON middleman_profiles FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
ON middleman_profiles FOR UPDATE
USING (auth.uid() = user_id);

-- Deals
CREATE POLICY "Middlemen can view own deals"
ON deals FOR SELECT
USING (auth.uid() = middleman_id);

CREATE POLICY "Parties can view their deals"
ON deals FOR SELECT
USING (auth.uid() = party_a_id OR auth.uid() = party_b_id);

-- Conversations
CREATE POLICY "Participants can view conversation"
ON conversations FOR SELECT
USING (auth.uid() = participant_a OR auth.uid() = participant_b);

-- Messages
CREATE POLICY "Participants can view messages"
ON messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM conversations
    WHERE conversations.id = messages.conversation_id
    AND (conversations.participant_a = auth.uid() 
         OR conversations.participant_b = auth.uid())
  )
);
```

## Testing Checklist

- [ ] Register as factory account
- [ ] Register as middleman account
- [ ] Register as customer account
- [ ] Login with each role and verify profile loads
- [ ] Create deal as middleman
- [ ] View deals as middleman
- [ ] View deals as party A/B
- [ ] Update deal status
- [ ] Create conversation
- [ ] Send message
- [ ] Receive message (realtime)
- [ ] Mark messages as read
- [ ] Update location for each role
- [ ] Role check helpers return correct values

## Migration Guide

### For Existing Users

Existing users with `account_type = 'user'` or `account_type = 'seller'` will continue to work without changes.

To upgrade existing sellers to factories:

```sql
UPDATE sellers 
SET account_type = 'factory',
    company_name = 'Your Company Name',
    latitude = 40.7128,
    longitude = -74.0060
WHERE user_id = 'YOUR-USER-UUID';
```

## Next Steps

1. **Deploy Edge Functions** - Create and deploy all required edge functions
2. **Run Database Migrations** - Execute SQL to create new tables
3. **Update UI** - Create screens for each role's dashboard
4. **Add Role-Based Navigation** - Show/hide features based on role
5. **Implement Real-time Chat UI** - Build chat interface
6. **Create Middleman Dashboard** - Deal management interface
7. **Add Factory Settings** - Factory configuration screen
8. **Test End-to-End** - Complete testing with all roles

## Support

For questions or issues, refer to the main README.md or contact the development team.
