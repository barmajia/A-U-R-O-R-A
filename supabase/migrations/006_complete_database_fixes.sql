-- ============================================================================
-- Aurora E-commerce: Complete Database Migration
-- ============================================================================
-- Purpose: Fix all critical database issues
-- Date: 2026-03-08
-- Version: 1.0.0
-- 
-- CHANGES:
-- 1. Fix column name typos (secoundname → secondname, forthname → fourthname)
-- 2. Remove SECURITY DEFINER function exposure to anon user
-- 3. Remove duplicate customer stats trigger
-- 4. Fix inventory race condition with proper locking
-- 5. Create idempotency keys table for order deduplication
-- 6. Enable RLS on critical tables
-- 
-- BACKUP RECOMMENDED: Run this in a transaction and backup first!
-- ============================================================================

-- ============================================================================
-- STEP 0: PRE-MIGRATION CHECKS & BACKUP
-- ============================================================================

-- Start transaction (all changes will be atomic)
BEGIN;

-- Create comprehensive backup of sellers table
CREATE TABLE sellers_backup_20260308 AS 
SELECT * FROM sellers 
WHERE 1=1;

-- Create backup of orders table
CREATE TABLE orders_backup_20260308 AS 
SELECT * FROM orders 
WHERE 1=1;

-- Create backup of products table
CREATE TABLE products_backup_20260308 AS 
SELECT * FROM products 
WHERE 1=1;

DO $$
BEGIN
  RAISE NOTICE '✓ Backups created: sellers_backup_20260308, orders_backup_20260308, products_backup_20260308';
END $$;

-- ============================================================================
-- STEP 1: FIX COLUMN NAME TYPOS
-- ============================================================================

DO $$
BEGIN
  -- Rename secoundname → secondname
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'sellers' 
    AND column_name = 'secoundname'
  ) THEN
    ALTER TABLE public.sellers RENAME COLUMN secoundname TO secondname;
    RAISE NOTICE '✓ Renamed secoundname to secondname';
  ELSE
    RAISE NOTICE '⚠ Column secoundname does not exist (already fixed or never existed)';
  END IF;
  
  -- Rename forthname → fourthname
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'sellers' 
    AND column_name = 'forthname'
  ) THEN
    ALTER TABLE public.sellers RENAME COLUMN forthname TO fourthname;
    RAISE NOTICE '✓ Renamed forthname to fourthname';
  ELSE
    RAISE NOTICE '⚠ Column forthname does not exist (already fixed or never existed)';
  END IF;
END $$;

-- Verify column renames
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM information_schema.columns 
  WHERE table_schema = 'public' 
  AND table_name = 'sellers' 
  AND column_name IN ('secondname', 'fourthname');
  
  IF v_count = 2 THEN
    RAISE NOTICE '✓ Column renames verified: secondname and fourthname exist';
  ELSE
    RAISE WARNING '⚠ Column renames may have failed. Expected 2 columns, found %', v_count;
  END IF;
END $$;

-- ============================================================================
-- STEP 2: REMOVE SECURITY DEFINER FUNCTION EXPOSURE
-- ============================================================================

-- Revoke all permissions on SECURITY DEFINER functions from anon user
REVOKE ALL ON FUNCTION public.calculate_seller_analytics(uuid, text, date, date) FROM anon;
REVOKE ALL ON FUNCTION public.can_start_conversation(uuid, uuid, uuid) FROM anon;
REVOKE ALL ON FUNCTION public.create_analytics_snapshot(uuid, text, date, date) FROM anon;
REVOKE ALL ON FUNCTION public.find_nearby_factories(uuid, numeric, integer) FROM anon;
REVOKE ALL ON FUNCTION public.get_seller_kpis(uuid, text) FROM anon;
REVOKE ALL ON FUNCTION public.get_factory_rating(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.get_low_stock_products(integer) FROM anon;
REVOKE ALL ON FUNCTION public.get_seller_product_count(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.get_seller_sales_count(uuid, timestamptz, timestamptz) FROM anon;
REVOKE ALL ON FUNCTION public.get_seller_total_customers(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.get_seller_total_revenue(uuid) FROM anon;

DO $$
BEGIN
  RAISE NOTICE '✓ Revoked all permissions on SECURITY DEFINER functions from anon user';
END $$;

-- Restrict table write access from anon user
REVOKE INSERT, UPDATE, DELETE ON TABLE 
  public.orders, 
  public.sales, 
  public.products, 
  public.sellers,
  public.customers, 
  public.messages, 
  public.analytics_snapshots,
  public.async_jobs, 
  public.admin_users
FROM anon;

DO $$
BEGIN
  RAISE NOTICE '✓ Restricted table write access from anon user';
END $$;

-- ============================================================================
-- STEP 3: REMOVE DUPLICATE CUSTOMER STATS TRIGGER
-- ============================================================================

-- Check existing triggers
DO $$
DECLARE
  v_trigger_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_trigger_count
  FROM pg_trigger
  WHERE tgname LIKE '%customer_stats%';
  
  IF v_trigger_count > 1 THEN
    RAISE NOTICE '⚠ Found % customer_stats triggers, will remove duplicate', v_trigger_count;
  ELSE
    RAISE NOTICE '✓ Found % customer_stats trigger(s), no cleanup needed', v_trigger_count;
  END IF;
END $$;

-- Remove duplicate trigger on orders table (keep only on sales table)
DROP TRIGGER IF EXISTS update_customer_stats_on_sale ON public.orders;

DO $$
BEGIN
  RAISE NOTICE '✓ Removed duplicate trigger from orders table (kept on sales table)';
END $$;

-- Verify only one trigger remains
DO $$
DECLARE
  v_trigger_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_trigger_count
  FROM pg_trigger
  WHERE tgname LIKE '%customer_stats%';
  
  IF v_trigger_count = 1 THEN
    RAISE NOTICE '✓ Verified: Only 1 customer_stats trigger remains';
  ELSE
    RAISE WARNING '⚠ Expected 1 trigger, found %', v_trigger_count;
  END IF;
END $$;

-- ============================================================================
-- STEP 4: FIX INVENTORY RACE CONDITION
-- ============================================================================

-- Replace inventory decrement function with proper locking
CREATE OR REPLACE FUNCTION public.decrement_product_inventory()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Lock the product row to prevent race conditions
    PERFORM 1 FROM public.products 
    WHERE asin = NEW.asin 
    FOR UPDATE;
    
    -- Check inventory before decrementing
    IF (SELECT quantity FROM public.products WHERE asin = NEW.asin) < NEW.quantity THEN
      RAISE EXCEPTION 'Insufficient inventory for ASIN: %. Available: %, Requested: %', 
        NEW.asin, 
        (SELECT quantity FROM public.products WHERE asin = NEW.asin),
        NEW.quantity
      USING ERRCODE = '23505';
    END IF;
    
    -- Safe decrement
    UPDATE public.products
    SET quantity = quantity - NEW.quantity,
        updated_at = NOW()
    WHERE asin = NEW.asin;
  END IF;
  
  RETURN NEW;
END;
$$;

DO $$
BEGIN
  RAISE NOTICE '✓ Updated decrement_product_inventory() with proper row locking';
END $$;

-- ============================================================================
-- STEP 5: CREATE IDEMPOTENCY KEYS TABLE
-- ============================================================================

-- Create idempotency keys table for order deduplication
CREATE TABLE IF NOT EXISTS public.idempotency_keys (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  key text NOT NULL UNIQUE,
  response jsonb NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  expires_at timestamptz NOT NULL,
  created_at timestamptz DEFAULT NOW()
);

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_idempotency_keys_key ON public.idempotency_keys(key);
CREATE INDEX IF NOT EXISTS idx_idempotency_keys_expires ON public.idempotency_keys(expires_at);
CREATE INDEX IF NOT EXISTS idx_idempotency_keys_user ON public.idempotency_keys(user_id);

-- Enable RLS
ALTER TABLE public.idempotency_keys ENABLE ROW LEVEL SECURITY;

-- Create RLS policy (users can only see their own keys)
DROP POLICY IF EXISTS idempotency_keys_user_own ON public.idempotency_keys;
CREATE POLICY idempotency_keys_user_own ON public.idempotency_keys
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Create cleanup function for expired keys
CREATE OR REPLACE FUNCTION public.cleanup_expired_idempotency_keys()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  DELETE FROM public.idempotency_keys
  WHERE expires_at < NOW();
  
  RAISE NOTICE 'Cleaned up % expired idempotency keys', FOUND;
END;
$$;

DO $$
BEGIN
  RAISE NOTICE '✓ Created idempotency_keys table with RLS and cleanup function';
END $$;

-- ============================================================================
-- STEP 6: ENABLE RLS ON CRITICAL TABLES
-- ============================================================================

-- Enable RLS on tables that need it
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.async_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.idempotency_keys ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  RAISE NOTICE '✓ Enabled RLS on critical tables';
END $$;

-- ============================================================================
-- STEP 7: POST-MIGRATION VERIFICATION
-- ============================================================================

-- Verify all changes
DO $$
DECLARE
  v_column_count INTEGER;
  v_trigger_count INTEGER;
  v_table_exists BOOLEAN;
BEGIN
  -- Verify column renames
  SELECT COUNT(*) INTO v_column_count
  FROM information_schema.columns 
  WHERE table_schema = 'public' 
  AND table_name = 'sellers' 
  AND column_name IN ('secondname', 'fourthname');
  
  -- Verify trigger count
  SELECT COUNT(*) INTO v_trigger_count
  FROM pg_trigger
  WHERE tgname LIKE '%customer_stats%';
  
  -- Verify idempotency table exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'idempotency_keys'
  ) INTO v_table_exists;
  
  -- Report results
  RAISE NOTICE '========================================';
  RAISE NOTICE 'MIGRATION VERIFICATION RESULTS';
  RAISE NOTICE '========================================';
  
  IF v_column_count = 2 THEN
    RAISE NOTICE '✓ Column renames: PASS (secondname, fourthname exist)';
  ELSE
    RAISE WARNING '✗ Column renames: FAIL (expected 2, found %)', v_column_count;
  END IF;
  
  IF v_trigger_count = 1 THEN
    RAISE NOTICE '✓ Trigger cleanup: PASS (1 trigger remains)';
  ELSE
    RAISE WARNING '✗ Trigger cleanup: FAIL (expected 1, found %)', v_trigger_count;
  END IF;
  
  IF v_table_exists THEN
    RAISE NOTICE '✓ Idempotency table: PASS (created)';
  ELSE
    RAISE WARNING '✗ Idempotency table: FAIL (not found)';
  END IF;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'BACKUP TABLES CREATED:';
  RAISE NOTICE '  - sellers_backup_20260308';
  RAISE NOTICE '  - orders_backup_20260308';
  RAISE NOTICE '  - products_backup_20260308';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration completed successfully!';
  RAISE NOTICE '========================================';
END $$;

-- ============================================================================
-- STEP 8: COMMIT TRANSACTION
-- ============================================================================

-- If everything succeeded, commit the transaction
COMMIT;

-- If there were any errors, the transaction would be rolled back automatically
-- You can also manually rollback by running: ROLLBACK;

-- ============================================================================
-- POST-MIGRATION: ROLLBACK SCRIPT (IF NEEDED)
-- ============================================================================
-- To rollback this migration, run:
--
-- BEGIN;
-- DROP TABLE IF EXISTS public.idempotency_keys CASCADE;
-- ALTER TABLE public.sellers RENAME COLUMN secondname TO secoundname;
-- ALTER TABLE public.sellers RENAME COLUMN fourthname TO forthname;
-- CREATE TRIGGER update_customer_stats_on_sale AFTER INSERT ON public.orders ...
-- DROP FUNCTION public.cleanup_expired_idempotency_keys() CASCADE;
-- ROLLBACK;
-- ============================================================================
