# 🗄️ Complete SQL Implementation Guide

## 📋 Overview

This is a **CLEAN INSTALLATION** SQL script that:
1. **Drops** all existing tables, functions, triggers, and views
2. **Recreates** everything from scratch with proper relationships
3. **Implements** complete analytics system with JSON storage

---

## 🚀 How to Deploy

### Step 1: Open Supabase SQL Editor
1. Go to https://app.supabase.com
2. Select your project
3. Navigate to **SQL Editor** (left sidebar)

### Step 2: Run the Migration
1. Copy the entire content of `005_customers_sales_analytics_complete.sql`
2. Paste into SQL Editor
3. Click **Run** (or Ctrl+Enter / Cmd+Enter)

### Step 3: Verify Installation
Check the output - you should see:
```
✓ Tables Created
✓ Indexes Created  
✓ Triggers Created
✓ Functions Created
✓ Views Created
📊 RLS Policies
```

---

## 📊 Database Schema

### Tables Created

#### 1. `customers` Table
```
Purpose: Store customer information with auto-calculated stats
Fields:
  - id (UUID, PK)
  - seller_id (UUID, FK → auth.users)
  - name, phone, email, age_range, notes
  - total_orders, total_spent, last_purchase_date (auto-updated)
  - created_at, updated_at
```

#### 2. `sales` Table
```
Purpose: Record sales transactions
Fields:
  - id (UUID, PK)
  - seller_id (UUID, FK → auth.users)
  - customer_id (UUID, FK → customers, nullable)
  - product_id (UUID, FK → products, nullable)
  - quantity, unit_price, total_price, discount
  - payment_method, payment_status
  - sale_date, created_at, updated_at
```

#### 3. `analytics_snapshots` Table
```
Purpose: Store pre-calculated analytics as JSON for fast dashboard loading
Fields:
  - id (UUID, PK)
  - seller_id (UUID, FK → auth.users)
  - period_type (daily/weekly/monthly/yearly/custom)
  - period_start, period_end
  - analytics_data (JSONB) - Complete analytics snapshot
  - is_current, created_at, updated_at
```

---

## 🔧 Functions Created

### 1. `calculate_seller_analytics(seller_id, period_type, start_date, end_date)`
**Returns:** `JSONB` - Complete analytics object

**Usage:**
```sql
-- Get analytics for last 30 days
SELECT calculate_seller_analytics('YOUR-SELLER-UUID', '30d');

-- Get analytics for last 7 days
SELECT calculate_seller_analytics('YOUR-SELLER-UUID', '7d');

-- Get analytics for custom date range
SELECT calculate_seller_analytics(
  'YOUR-SELLER-UUID', 
  'custom', 
  '2024-01-01', 
  '2024-01-31'
);
```

**Returns JSON Structure:**
```json
{
  "seller_id": "uuid",
  "period": "30d",
  "period_days": 30,
  "start_date": "2024-01-01",
  "end_date": "2024-01-30",
  "generated_at": "2024-01-30T10:30:00Z",
  "kpis": {
    "total_revenue": 15420.50,
    "total_sales": 156,
    "total_items_sold": 423,
    "total_customers": 89,
    "unique_customers_in_period": 45,
    "average_order_value": 98.85,
    "conversion_rate": 50.56
  },
  "top_products": [...],
  "top_customers": [...],
  "sales_by_payment_method": {...},
  "daily_breakdown": [...]
}
```

---

### 2. `create_analytics_snapshot(seller_id, period_type, start_date, end_date)`
**Returns:** `UUID` - ID of created snapshot

**Usage:**
```sql
-- Create snapshot for last 30 days
SELECT create_analytics_snapshot('YOUR-SELLER-UUID', '30d');

-- Create snapshot for custom range
SELECT create_analytics_snapshot(
  'YOUR-SELLER-UUID', 
  'custom', 
  '2024-01-01', 
  '2024-01-31'
);
```

**What it does:**
- Calculates analytics using `calculate_seller_analytics()`
- Stores result in `analytics_snapshots` table
- Marks previous snapshots for same period as `is_current = false`
- Returns snapshot ID

---

### 3. `get_seller_kpis(seller_id, period)`
**Returns:** `JSONB` - KPIs from cache or freshly calculated

**Usage:**
```sql
-- Get KPIs (uses cache if < 1 hour old)
SELECT get_seller_kpis('YOUR-SELLER-UUID', '30d');
```

**What it does:**
- Checks for existing snapshot (< 1 hour old)
- Returns cached data if available
- Calculates fresh analytics if no cache exists
- Creates new snapshot automatically

---

### 4. `update_customer_stats_on_sale()` (Trigger Function)
**Fires:** AFTER INSERT on `sales`

**What it does:**
- Updates `total_orders` (+1)
- Updates `total_spent` (+sale total)
- Updates `last_purchase_date`
- Updates `updated_at`

**Automatic - no manual call needed!**

---

### 5. Helper Functions
```sql
-- Get seller's total revenue (all time)
SELECT get_seller_total_revenue('YOUR-SELLER-UUID');

-- Get seller's total customers count
SELECT get_seller_total_customers('YOUR-SELLER-UUID');

-- Get sales count in date range
SELECT get_seller_sales_count(
  'YOUR-SELLER-UUID',
  '2024-01-01 00:00:00',
  '2024-01-31 23:59:59'
);
```

---

## 📈 Views Created

### 1. `daily_sales_summary`
```sql
-- Usage
SELECT * FROM daily_sales_summary
WHERE seller_id = 'YOUR-SELLER-UUID'
ORDER BY sale_day DESC;
```

### 2. `monthly_sales_summary`
```sql
-- Usage
SELECT * FROM monthly_sales_summary
WHERE seller_id = 'YOUR-SELLER-UUID'
ORDER BY sale_month DESC;
```

### 3. `customer_lifetime_value`
```sql
-- Usage
SELECT * FROM customer_lifetime_value
WHERE seller_id = 'YOUR-SELLER-UUID'
ORDER BY total_spent DESC;
```

### 4. `top_customers`
```sql
-- Usage
SELECT * FROM top_customers
WHERE seller_id = 'YOUR-SELLER-UUID'
LIMIT 10;
```

### 5. `product_performance`
```sql
-- Usage
SELECT * FROM product_performance
WHERE seller_id = 'YOUR-SELLER-UUID'
ORDER BY total_revenue DESC;
```

---

## 🔐 Security (RLS Policies)

All tables have **Row Level Security** enabled:

```sql
-- Customers: Only seller can access their customers
WHERE seller_id = auth.uid()

-- Sales: Only seller can access their sales
WHERE seller_id = auth.uid()

-- Analytics: Only seller can access their analytics
WHERE seller_id = auth.uid()
```

**What this means:**
- Sellers can ONLY see their own data
- No seller can access another seller's customers, sales, or analytics
- Service role (Edge Functions) can bypass RLS for calculations

---

## 🧪 Testing the Implementation

### Test 1: Add a Customer
```sql
-- Insert test customer
INSERT INTO customers (seller_id, name, phone, age_range, email)
VALUES (
  'YOUR-SELLER-UUID',
  'John Doe',
  '+1234567890',
  '30s',
  'john@example.com'
);

-- Verify
SELECT * FROM customers WHERE email = 'john@example.com';
```

### Test 2: Record a Sale
```sql
-- Insert test sale
INSERT INTO sales (
  seller_id,
  customer_id,
  quantity,
  unit_price,
  total_price,
  payment_method
)
VALUES (
  'YOUR-SELLER-UUID',
  (SELECT id FROM customers WHERE email = 'john@example.com'),
  2,
  50.00,
  100.00,
  'cash'
);

-- Verify customer stats updated
SELECT 
  name,
  total_orders,
  total_spent,
  last_purchase_date
FROM customers 
WHERE email = 'john@example.com';
-- Should show: total_orders=1, total_spent=100.00
```

### Test 3: Calculate Analytics
```sql
-- Get analytics JSON
SELECT get_seller_kpis('YOUR-SELLER-UUID', '30d');

-- Create snapshot
SELECT create_analytics_snapshot('YOUR-SELLER-UUID', '30d');

-- Verify snapshot stored
SELECT 
  period_type,
  period_start,
  period_end,
  analytics_data->'kpis'->>'total_revenue' as revenue
FROM analytics_snapshots
WHERE seller_id = 'YOUR-SELLER-UUID'
ORDER BY created_at DESC
LIMIT 1;
```

### Test 4: Verify Views
```sql
-- Check daily summary
SELECT * FROM daily_sales_summary
WHERE seller_id = 'YOUR-SELLER-UUID';

-- Check customer LTV
SELECT * FROM customer_lifetime_value
WHERE seller_id = 'YOUR-SELLER-UUID';

-- Check product performance
SELECT * FROM product_performance
WHERE seller_id = 'YOUR-SELLER-UUID';
```

---

## 📱 Flutter Integration

### How Flutter Uses This

#### 1. Add Customer
```dart
await supabase.from('customers').insert({
  'seller_id': currentUser.id,
  'name': 'John Doe',
  'phone': '+1234567890',
  // ...
});
// Trigger automatically updates customer stats on future sales
```

#### 2. Record Sale
```dart
await supabase.from('sales').insert({
  'seller_id': currentUser.id,
  'customer_id': customerId,
  'quantity': 2,
  'unit_price': 50.00,
  'total_price': 100.00,
  // ...
});
// Trigger automatically:
// 1. Updates customer stats
// 2. Analytics snapshot can be created
```

#### 3. Get Analytics
```dart
// Option 1: Use RPC function (recommended)
final result = await supabase.rpc('get_seller_kpis', params: {
  'p_seller_id': currentUser.id,
  'p_period': '30d'
});

// Option 2: Query analytics_snapshots table
final result = await supabase
  .from('analytics_snapshots')
  .select('analytics_data')
  .eq('seller_id', currentUser.id)
  .eq('period_type', '30d')
  .eq('is_current', true)
  .single();
```

---

## 🔍 Troubleshooting

### Issue: "Function does not exist"
**Solution:** Re-run the SQL migration script

### Issue: "Permission denied"
**Solution:** Verify RLS policies are created correctly
```sql
SELECT * FROM pg_policies WHERE tablename = 'customers';
```

### Issue: "Customer stats not updating"
**Solution:** Verify trigger exists
```sql
SELECT * FROM information_schema.triggers 
WHERE trigger_name = 'trigger_update_customer_stats_on_sale';
```

### Issue: "Analytics snapshot not created"
**Solution:** Manually create snapshot
```sql
SELECT create_analytics_snapshot('YOUR-SELLER-UUID', '30d');
```

---

## 📝 Summary

| Component | Count | Purpose |
|-----------|-------|---------|
| Tables | 3 | customers, sales, analytics_snapshots |
| Indexes | 17 | Performance optimization |
| Triggers | 3 | Auto-update stats & timestamps |
| Functions | 9 | Analytics calculation & helpers |
| Views | 5 | Pre-built queries for reporting |
| RLS Policies | 3 | Data security |

---

## ✅ Deployment Checklist

- [ ] Run SQL migration in Supabase
- [ ] Verify all tables created
- [ ] Verify all functions created
- [ ] Verify all triggers created
- [ ] Verify RLS policies enabled
- [ ] Test adding a customer
- [ ] Test recording a sale
- [ ] Verify customer stats auto-update
- [ ] Test getting analytics
- [ ] Test Flutter app integration

---

**🎉 System Ready!** Your complete Customers → Sales → Analytics system is now deployed.
