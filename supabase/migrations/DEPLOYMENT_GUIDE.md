# 🚀 Database Migration Deployment Guide

**Migration:** `006_complete_database_fixes.sql`  
**Date:** 2026-03-08  
**Priority:** 🔴 **CRITICAL**  
**Estimated Time:** 30-60 minutes

---

## 📋 What This Migration Does

### **Fixes:**
1. ✅ **Column name typos** - `secoundname` → `secondname`, `forthname` → `fourthname`
2. ✅ **Security exposure** - Revokes anon access to SECURITY DEFINER functions
3. ✅ **Duplicate trigger** - Removes duplicate customer stats trigger
4. ✅ **Inventory race condition** - Adds proper row locking
5. ✅ **Order deduplication** - Creates idempotency keys table
6. ✅ **RLS enforcement** - Enables Row Level Security on critical tables

### **Safety Features:**
- ✅ **Automatic backups** - Creates backup tables before changes
- ✅ **Transaction-based** - All changes atomic (all or nothing)
- ✅ **Verification checks** - Validates each step
- ✅ **Rollback script** - Included in migration file

---

## 🎯 Pre-Deployment Checklist

### **Required:**
- [ ] **Backup database** (manual backup recommended)
- [ ] **Test in staging** (if available)
- [ ] **Notify team** (downtime expected: 5-10 minutes)
- [ ] **Schedule maintenance window** (off-peak hours)
- [ ] **Have rollback plan ready**

### **Recommended:**
- [ ] **Monitor active connections** (should be low)
- [ ] **Check disk space** (backups will use ~2x table size)
- [ ] **Review migration script** (understand all changes)

---

## 🚀 Deployment Steps

### **Step 1: Access Supabase Dashboard**

1. Go to: https://supabase.com/dashboard
2. Select your project: `ofovfxsfazlwvcakpuer`
3. Click **SQL Editor** (left sidebar)

### **Step 2: Create Manual Backup (RECOMMENDED)**

```sql
-- Create full database backup
CREATE TABLE backup_sellers_20260308 AS SELECT * FROM sellers;
CREATE TABLE backup_orders_20260308 AS SELECT * FROM orders;
CREATE TABLE backup_products_20260308 AS SELECT * FROM products;

-- Verify backups
SELECT 'sellers' as table_name, COUNT(*) as rows FROM backup_sellers_20260308
UNION ALL
SELECT 'orders', COUNT(*) FROM backup_orders_20260308
UNION ALL
SELECT 'products', COUNT(*) FROM backup_products_20260308;
```

### **Step 3: Run Migration**

1. **Open migration file:**
   - File: `supabase/migrations/006_complete_database_fixes.sql`
   - Copy entire content

2. **Paste into SQL Editor:**
   - Paste the entire SQL script
   - Click **Run** (or Ctrl+Enter / Cmd+Enter)

3. **Monitor execution:**
   - Watch for green checkmarks (✓)
   - Look for any WARNING messages
   - Execution time: ~30-60 seconds

### **Step 4: Verify Migration**

The migration will automatically verify itself. You should see:

```
========================================
MIGRATION VERIFICATION RESULTS
========================================
✓ Column renames: PASS (secondname, fourthname exist)
✓ Trigger cleanup: PASS (1 trigger remains)
✓ Idempotency table: PASS (created)
========================================
BACKUP TABLES CREATED:
  - sellers_backup_20260308
  - orders_backup_20260308
  - products_backup_20260308
========================================
Migration completed successfully!
========================================
```

### **Step 5: Post-Migration Verification**

Run these queries to verify everything works:

```sql
-- 1. Verify column renames
SELECT column_name 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'sellers' 
AND column_name IN ('secondname', 'fourthname');
-- Expected: 2 rows (secondname, fourthname)

-- 2. Verify trigger cleanup
SELECT tgname, tgrelid::regclass as table_name
FROM pg_trigger
WHERE tgname LIKE '%customer_stats%';
-- Expected: 1 row (trigger on sales table only)

-- 3. Verify idempotency table
SELECT COUNT(*) as row_count FROM idempotency_keys;
-- Expected: 0 rows (empty table, but exists)

-- 4. Verify RLS enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('idempotency_keys', 'admin_users', 'analytics');
-- Expected: All show 'true'

-- 5. Verify function security
SELECT proname, prosecdef
FROM pg_proc
WHERE proname IN ('calculate_seller_analytics', 'get_seller_kpis');
-- Expected: prosecdef = true (SECURITY DEFINER)
```

---

## ⚠️ Rollback Procedure

If something goes wrong, here's how to rollback:

### **Option 1: Automatic Rollback**

If the migration fails mid-way, the transaction will automatically rollback:

```sql
-- If you see an error, run:
ROLLBACK;
```

### **Option 2: Manual Rollback**

```sql
BEGIN;

-- Drop new table
DROP TABLE IF EXISTS public.idempotency_keys CASCADE;

-- Rename columns back
ALTER TABLE public.sellers RENAME COLUMN secondname TO secoundname;
ALTER TABLE public.sellers RENAME COLUMN fourthname TO forthname;

-- Recreate duplicate trigger (if needed)
-- (Get original trigger definition from pg_trigger)

-- Drop cleanup function
DROP FUNCTION IF EXISTS public.cleanup_expired_idempotency_keys() CASCADE;

-- Restore from backups (if needed)
-- TRUNCATE public.sellers CASCADE;
-- INSERT INTO public.sellers SELECT * FROM sellers_backup_20260308;

ROLLBACK;
```

### **Option 3: Restore from Backup**

```sql
-- Restore sellers table
TRUNCATE public.sellers CASCADE;
INSERT INTO public.sellers SELECT * FROM sellers_backup_20260308;

-- Restore orders table
TRUNCATE public.orders CASCADE;
INSERT INTO public.orders SELECT * FROM orders_backup_20260308;

-- Restore products table
TRUNCATE public.products CASCADE;
INSERT INTO public.products SELECT * FROM products_backup_20260308;
```

---

## 🧪 Testing After Migration

### **Test 1: Seller Signup**

```dart
// In Flutter app
final result = await supabase.signup(
  fullName: 'John Michael Doe Smith',
  accountType: AccountType.seller,
  email: 'test@example.com',
  password: 'SecurePass123!',
  phone: '+1234567890',
  location: 'New York',
  currency: 'USD',
);

// Verify name parsing works
final profile = await supabase.getCurrentSellerProfile();
print(profile['secondname']); // Should print 'Michael'
print(profile['fourthname']); // Should print 'Smith'
```

### **Test 2: Create Order**

```dart
// Test order creation with idempotency
final result = await supabase.createOrder(
  sellerId: currentUser.id,
  items: [
    {'product_id': 'xxx', 'quantity': 1, 'price': 99.99},
  ],
  paymentMethod: 'card',
  idempotencyKey: 'test_order_123',
);

// Try to create duplicate
final result2 = await supabase.createOrder(
  sellerId: currentUser.id,
  items: [
    {'product_id': 'xxx', 'quantity': 1, 'price': 99.99},
  ],
  paymentMethod: 'card',
  idempotencyKey: 'test_order_123', // Same key
);

// Should return duplicate flag
print(result2.data['duplicate']); // Should print true
```

### **Test 3: Inventory Locking**

```dart
// Try to create multiple orders for same product simultaneously
// Should fail if inventory is insufficient
```

---

## 📊 Monitoring

### **During Migration:**

Watch these in Supabase Dashboard:
- **Database → Logs** - Real-time query logs
- **Database → Connections** - Active connections
- **Logs → Function logs** - Edge function activity

### **After Migration:**

Monitor for 24 hours:
- **Error rate** - Should not increase
- **Function errors** - Check for new errors
- **Query performance** - Should not degrade
- **User reports** - Watch for complaints

---

## 🎯 Success Criteria

Migration is successful when:

- [x] ✅ No errors in migration output
- [x] ✅ Verification shows all PASS
- [x] ✅ Backup tables created
- [x] ✅ Seller signup works (test with new account)
- [x] ✅ Order creation works (test with small order)
- [x] ✅ No increase in error rate
- [x] ✅ Flutter app still connects
- [x] ✅ All features still work

---

## 📞 Troubleshooting

### **Error: "Column already exists"**

**Cause:** Column already renamed

**Solution:**
```sql
-- Check current columns
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'sellers' AND column_name IN ('secondname', 'fourthname');

-- If columns exist, skip rename step
-- Continue with rest of migration
```

### **Error: "Permission denied"**

**Cause:** Insufficient privileges

**Solution:**
- Make sure you're using service_role key
- Check you're logged in as project owner

### **Error: "Deadlock detected"**

**Cause:** Active connections blocking changes

**Solution:**
```sql
-- Kill active connections
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = current_database() 
AND pid <> pg_backend_pid();

-- Retry migration
```

### **Migration hangs**

**Cause:** Large tables or locks

**Solution:**
1. Wait 5-10 minutes
2. Check for locks: `SELECT * FROM pg_locks;`
3. If still stuck, rollback and retry in maintenance window

---

## 🎉 Post-Migration Cleanup

After 7 days (once you're confident migration succeeded):

```sql
-- Drop backup tables (free up space)
DROP TABLE IF EXISTS sellers_backup_20260308;
DROP TABLE IF EXISTS orders_backup_20260308;
DROP TABLE IF EXISTS products_backup_20260308;

-- Verify disk space freed
SELECT pg_size_pretty(pg_database_size(current_database()));
```

---

## 📄 Migration File Location

**File:** `supabase/migrations/006_complete_database_fixes.sql`

**Backup Location:** Keep a copy of this file in:
- Git repository
- Local backup folder
- Cloud storage (Google Drive, Dropbox)

---

## ✅ Final Checklist

After migration:

- [ ] Verify all tests pass
- [ ] Monitor error rate for 24 hours
- [ ] Test all critical features (signup, login, orders, products)
- [ ] Update team that migration completed
- [ ] Document any issues encountered
- [ ] Schedule cleanup (drop backups after 7 days)

---

**Migration Status:** ⏳ **READY TO DEPLOY**  
**Risk Level:** 🟡 **MEDIUM** (backups included)  
**Downtime:** ⏱️ **5-10 minutes**  

**Good luck! 🚀**
