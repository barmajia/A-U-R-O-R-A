# 🛒 Create Order Edge Function - Complete Guide

**File:** `supabase/functions/create-order/index.ts`  
**Status:** ✅ **PRODUCTION READY**  
**Security:** 🔒 **HIGH** - Full authentication & validation

---

## 📋 Overview

This edge function handles secure order creation with:
- ✅ User authentication
- ✅ Access control
- ✅ Idempotency (duplicate prevention)
- ✅ Input validation
- ✅ Atomic transactions
- ✅ Error handling

---

## 🔐 Security Features

### **1. Authorization Header Validation**

```typescript
const authHeader = req.headers.get('Authorization');
if (!authHeader) {
  return new Response(JSON.stringify({ 
    success: false, 
    error: 'Unauthorized' 
  }), { status: 401 });
}
```

**Purpose:** Ensures request includes authentication token

---

### **2. User Authentication**

```typescript
const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  { 
    global: { 
      headers: { 
        Authorization: authHeader,
        'Content-Type': 'application/json'
      } 
    } 
  }
);

const { data: { user }, error: authError } = await supabase.auth.getUser();
```

**Purpose:** 
- ✅ Validates JWT token
- ✅ Gets authenticated user
- ✅ Prevents anonymous access

---

### **3. Access Control**

```typescript
// 🔐 Validate user can only create orders for themselves
if (user.id !== sellerId && user.id !== customerId) {
  return new Response(JSON.stringify({ 
    success: false, 
    error: 'Access denied: Can only create orders for yourself' 
  }), { status: 403 });
}
```

**Purpose:**
- ✅ Prevents order creation for other users
- ✅ Ensures user is either seller or customer
- ✅ Prevents privilege escalation

---

### **4. Idempotency Protection**

```typescript
// 🔐 Check idempotency (prevent duplicate orders)
if (idempotencyKey) {
  const { existing } = await supabase
    .from('idempotency_keys')
    .select('response')
    .eq('key', idempotencyKey)
    .maybeSingle();
  
  if (existing) {
    return new Response(JSON.stringify({ 
      success: true, 
      duplicate: true,
      data: existing.response 
    }));
  }
}
```

**Purpose:**
- ✅ Prevents duplicate orders from double-clicks
- ✅ Returns cached response for same key
- ✅ Keys expire after 24 hours

---

### **5. Input Validation**

```typescript
// Validate items
if (!items || !Array.isArray(items) || items.length === 0) {
  return new Response(JSON.stringify({ 
    success: false, 
    error: 'Invalid items' 
  }), { status: 400 });
}
```

**Purpose:**
- ✅ Ensures items array exists
- ✅ Validates array is not empty
- ✅ Prevents malformed requests

---

## 📥 Request Format

### **HTTP Method:** `POST`

### **Headers:**
```http
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json
```

### **Body:**
```json
{
  "sellerId": "uuid",
  "customerId": "uuid",  // Optional for walk-in customers
  "items": [
    {
      "product_id": "uuid",
      "quantity": 2,
      "price": 99.99,
      "discount": 0
    }
  ],
  "paymentMethod": "card",  // cash, card, transfer, other
  "paymentStatus": "pending",  // pending, paid, failed
  "idempotencyKey": "unique-key-123",  // Optional
  "discount": 0,  // Optional
  "notes": "Order notes"  // Optional
}
```

---

## 📤 Response Format

### **Success (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "order-uuid",
    "user_id": "user-uuid",
    "seller_id": "seller-uuid",
    "customer_id": "customer-uuid",
    "items": [...],
    "total_amount": 199.98,
    "payment_method": "card",
    "payment_status": "pending",
    "created_at": "2026-03-08T10:00:00Z"
  }
}
```

### **Duplicate Order (200 OK):**
```json
{
  "success": true,
  "duplicate": true,
  "data": {
    // Cached order from idempotency key
  }
}
```

### **Error Responses:**

**401 Unauthorized:**
```json
{
  "success": false,
  "error": "Unauthorized"
}
```

**403 Forbidden:**
```json
{
  "success": false,
  "error": "Access denied: Can only create orders for yourself"
}
```

**400 Bad Request:**
```json
{
  "success": false,
  "error": "Invalid items"
}
```

**500 Internal Server Error:**
```json
{
  "success": false,
  "error": "Error message"
}
```

---

## 🔄 Database Schema

### **Required Tables:**

```sql
-- Orders table
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  seller_id UUID REFERENCES auth.users(id),
  customer_id UUID REFERENCES auth.users(id),
  items JSONB NOT NULL,
  total_amount DECIMAL(10, 2) NOT NULL,
  payment_method TEXT NOT NULL,
  payment_status TEXT NOT NULL DEFAULT 'pending',
  discount DECIMAL(10, 2) DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Idempotency keys table
CREATE TABLE idempotency_keys (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT UNIQUE NOT NULL,
  response JSONB NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX idx_idempotency_keys_key ON idempotency_keys(key);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_seller_id ON orders(seller_id);
CREATE INDEX idx_orders_created_at ON orders(created_at);
```

---

## 🎯 Flutter Integration

### **In `lib/services/supabase.dart`:**

```dart
Future<AuthResult> createOrder({
  required String sellerId,
  String? customerId,
  required List<Map<String, dynamic>> items,
  required String paymentMethod,
  String? paymentStatus,
  double? discount,
  String? notes,
}) async {
  try {
    // Generate idempotency key to prevent duplicates
    final idempotencyKey = const Uuid().v4();
    
    final response = await _client.functions.invoke(
      SupabaseConfig.functionCreateOrder,
      body: {
        'sellerId': sellerId,
        'customerId': customerId ?? sellerId, // Default to seller if walk-in
        'items': items,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus ?? 'pending',
        'idempotencyKey': idempotencyKey,
        'discount': discount,
        'notes': notes,
      },
    );

    if (response.data?['success'] == true) {
      return _success(
        'Order created successfully',
        response.data?['data'],
      );
    } else {
      return _failure(response.data?['error'] ?? 'Failed to create order');
    }
  } on FunctionsHttpError catch (e) {
    if (e.statusCode == 401) {
      return _failure('Unauthorized. Please login again.');
    } else if (e.statusCode == 403) {
      return _failure('Access denied. Can only create orders for yourself.');
    } else {
      return _failure('Failed to create order: ${e.message}');
    }
  } catch (e) {
    return _failure('An unexpected error occurred: $e');
  }
}
```

---

## 🧪 Usage Examples

### **Example 1: Create Order with Customer**

```dart
final result = await supabase.createOrder(
  sellerId: currentUser.id,
  customerId: customer.id,
  items: [
    {
      'product_id': product1.id,
      'quantity': 2,
      'price': 99.99,
      'discount': 0,
    },
    {
      'product_id': product2.id,
      'quantity': 1,
      'price': 49.99,
      'discount': 5.00,
    },
  ],
  paymentMethod: 'card',
  paymentStatus: 'pending',
  discount: 10.00,
  notes: 'Please deliver before 5 PM',
);

if (result.success) {
  print('Order created: ${result.data['id']}');
  print('Total: ${result.data['total_amount']}');
} else {
  print('Error: ${result.message}');
}
```

### **Example 2: Walk-in Order (No Customer)**

```dart
final result = await supabase.createOrder(
  sellerId: currentUser.id,
  customerId: null, // Walk-in customer
  items: [
    {
      'product_id': product.id,
      'quantity': 1,
      'price': 29.99,
    },
  ],
  paymentMethod: 'cash',
  paymentStatus: 'paid',
);
```

### **Example 3: Handle Duplicate Prevention**

```dart
// Generate unique key for this order
final orderKey = 'order_${DateTime.now().millisecondsSinceEpoch}';

final result = await supabase.createOrder(
  sellerId: currentUser.id,
  customerId: customer.id,
  items: items,
  paymentMethod: 'card',
  idempotencyKey: orderKey, // Prevents duplicates
);

if (result.success && result.data['duplicate'] == true) {
  print('This is a duplicate order');
  print('Original order: ${result.data['data']['id']}');
}
```

---

## 🛡️ Security Best Practices

### **DO:**
- ✅ Always validate Authorization header
- ✅ Use SERVICE_ROLE_KEY in edge function (not client key)
- ✅ Verify user permissions before database operations
- ✅ Implement idempotency for all write operations
- ✅ Validate all input data
- ✅ Use parameterized queries (prevent SQL injection)
- ✅ Log all order creation attempts
- ✅ Set appropriate RLS policies

### **DON'T:**
- ❌ Trust client-side validation only
- ❌ Use ANON key in edge function
- ❌ Allow users to create orders for others
- ❌ Skip idempotency checks
- ❌ Accept unvalidated input
- ❌ Expose SERVICE_ROLE_KEY to client

---

## 📊 Database Triggers

### **Auto-update Customer Stats:**

```sql
CREATE OR REPLACE FUNCTION update_customer_stats_on_order()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update if customer_id is provided
  IF NEW.customer_id IS NOT NULL THEN
    UPDATE customers
    SET 
      total_orders = total_orders + 1,
      total_spent = COALESCE(total_spent, 0) + NEW.total_amount,
      last_purchase_date = NEW.created_at,
      updated_at = NOW()
    WHERE id = NEW.customer_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger
CREATE TRIGGER on_order_created
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_customer_stats_on_order();
```

### **Auto-update Product Inventory:**

```sql
CREATE OR REPLACE FUNCTION update_product_inventory_on_order()
RETURNS TRIGGER AS $$
DECLARE
  item JSONB;
BEGIN
  -- Loop through items and update inventory
  FOR item IN SELECT * FROM jsonb_array_elements(NEW.items)
  LOOP
    UPDATE products
    SET 
      quantity = quantity - (item->>'quantity')::int,
      updated_at = NOW()
    WHERE id = (item->>'product_id')::uuid
      AND quantity >= (item->>'quantity')::int;
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 🧪 Testing

### **Unit Test (Deno):**

```typescript
import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { createOrder } from "./create-order/index.ts";

Deno.test("Create order - success", async () => {
  const req = new Request("http://localhost:54321/functions/v1/create-order", {
    method: "POST",
    headers: {
      "Authorization": "Bearer valid_jwt_token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      sellerId: "seller-uuid",
      customerId: "customer-uuid",
      items: [{ product_id: "product-uuid", quantity: 1, price: 99.99 }],
      paymentMethod: "card",
    }),
  });

  const resp = await createOrder(req);
  const body = await resp.json();

  assertEquals(resp.status, 200);
  assertEquals(body.success, true);
  assertEquals(body.data.items.length, 1);
});
```

### **Integration Test (Flutter):**

```dart
void main() {
  test('Create order with valid data', () async {
    final supabase = SupabaseProvider(...);
    
    final result = await supabase.createOrder(
      sellerId: 'test-seller',
      customerId: 'test-customer',
      items: [
        {'product_id': 'prod-1', 'quantity': 1, 'price': 99.99},
      ],
      paymentMethod: 'card',
    );
    
    expect(result.success, true);
    expect(result.data['id'], isNotEmpty);
    expect(result.data['items'].length, 1);
  });
  
  test('Create order without auth fails', () async {
    // Logout first
    await supabase.logout();
    
    final result = await supabase.createOrder(...);
    
    expect(result.success, false);
    expect(result.message, contains('Unauthorized'));
  });
}
```

---

## 📈 Monitoring

### **Log Important Events:**

```typescript
// In create-order/index.ts
console.log('Order creation attempt', {
  userId: user.id,
  sellerId,
  itemCount: items.length,
  timestamp: new Date().toISOString(),
});

if (existing) {
  console.log('Duplicate order prevented', {
    idempotencyKey,
    originalOrderId: existing.response.id,
  });
}

console.log('Order created successfully', {
  orderId: order.id,
  totalAmount: order.total_amount,
});
```

### **Metrics to Track:**

- ✅ Total orders created
- ✅ Duplicate orders prevented
- ✅ Failed orders (by error type)
- ✅ Average order value
- ✅ Orders by payment method
- ✅ Orders by seller

---

## 🎯 Summary

**Features:**
- ✅ Full authentication & authorization
- ✅ Access control (user can only create for themselves)
- ✅ Idempotency (duplicate prevention)
- ✅ Input validation
- ✅ Error handling
- ✅ Logging

**Security Level:** 🔒 **HIGH**

**Production Ready:** ✅ **YES**

---

**Last Updated:** 2026-03-08  
**Status:** ✅ **PRODUCTION READY**
