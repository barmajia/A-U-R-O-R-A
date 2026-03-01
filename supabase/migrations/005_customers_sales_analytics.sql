-- ==============================================================================
-- Aurora E-Commerce: Customers, Sales & Analytics Database Schema
-- ==============================================================================
-- This script creates:
-- 1. customers table - Customer management
-- 2. sales table - Sales records
-- 3. Analytics views and triggers
-- 4. RLS policies for security
--
-- Run this in Supabase SQL Editor: https://app.supabase.com/project/_/sql
-- ==============================================================================

-- ==============================================================================
-- PART 1: CUSTOMERS TABLE
-- ==============================================================================

CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID REFERENCES auth.users(id) NOT NULL,
  
  -- Customer Info
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  
  -- Age Range
  age_range TEXT CHECK (age_range IN ('teens', '20s', '30s', '40s', '50s', '60s', '70s+')),
  
  -- Optional Fields
  email TEXT,
  notes TEXT,
  
  -- Stats (Auto-calculated)
  total_orders INTEGER DEFAULT 0,
  total_spent NUMERIC(10, 2) DEFAULT 0,
  last_purchase_date TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT valid_phone CHECK (phone ~ '^[0-9+\-\s()]+$')
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_customers_seller_id ON customers(seller_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_age_range ON customers(age_range);
CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name);
CREATE INDEX IF NOT EXISTS idx_customers_created_at ON customers(created_at DESC);

-- ==============================================================================
-- PART 2: SALES TABLE
-- ==============================================================================

CREATE TABLE IF NOT EXISTS sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID REFERENCES auth.users(id) NOT NULL,
  
  -- Links
  customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  
  -- Sale Details
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC(10, 2) NOT NULL,
  total_price NUMERIC(10, 2) NOT NULL,
  discount NUMERIC(10, 2) DEFAULT 0,
  
  -- Payment
  payment_method TEXT CHECK (payment_method IN ('cash', 'card', 'transfer', 'other')),
  payment_status TEXT CHECK (payment_status IN ('pending', 'completed', 'refunded')) DEFAULT 'completed',
  
  -- Timestamps
  sale_date TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_sales_seller_id ON sales(seller_id);
CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON sales(customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_product_id ON sales(product_id);
CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(sale_date DESC);
CREATE INDEX IF NOT EXISTS idx_sales_payment_status ON sales(payment_status);

-- ==============================================================================
-- PART 3: TRIGGERS FOR AUTO-UPDATES
-- ==============================================================================

-- Function to update customer stats on sale
CREATE OR REPLACE FUNCTION update_customer_stats_on_sale()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.customer_id IS NOT NULL THEN
    UPDATE customers
    SET 
      total_orders = total_orders + 1,
      total_spent = total_spent + NEW.total_price,
      last_purchase_date = NEW.sale_date,
      updated_at = NOW()
    WHERE id = NEW.customer_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for updating customer stats
DROP TRIGGER IF EXISTS trigger_update_customer_stats_on_sale ON sales;
CREATE TRIGGER trigger_update_customer_stats_on_sale
  AFTER INSERT ON sales
  FOR EACH ROW
  EXECUTE FUNCTION update_customer_stats_on_sale();

-- Function to update sales timestamps
CREATE OR REPLACE FUNCTION update_sales_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating sales timestamp
DROP TRIGGER IF EXISTS trigger_update_sales_timestamp ON sales;
CREATE TRIGGER trigger_update_sales_timestamp
  BEFORE UPDATE ON sales
  FOR EACH ROW
  EXECUTE FUNCTION update_sales_timestamp();

-- Function to update customers timestamps
CREATE OR REPLACE FUNCTION update_customers_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating customers timestamp
DROP TRIGGER IF EXISTS trigger_update_customers_timestamp ON customers;
CREATE TRIGGER trigger_update_customers_timestamp
  BEFORE UPDATE ON customers
  FOR EACH ROW
  EXECUTE FUNCTION update_customers_timestamp();

-- ==============================================================================
-- PART 4: ANALYTICS VIEWS
-- ==============================================================================

-- Daily sales summary view
CREATE OR REPLACE VIEW daily_sales_summary AS
SELECT 
  seller_id,
  DATE(sale_date) as sale_day,
  COUNT(*) as total_sales,
  SUM(total_price) as total_revenue,
  SUM(quantity) as total_items,
  AVG(total_price) as average_order_value
FROM sales
GROUP BY seller_id, DATE(sale_date)
ORDER BY sale_day DESC;

-- Monthly sales summary view
CREATE OR REPLACE VIEW monthly_sales_summary AS
SELECT 
  seller_id,
  DATE_TRUNC('month', sale_date) as sale_month,
  COUNT(*) as total_sales,
  SUM(total_price) as total_revenue,
  SUM(quantity) as total_items,
  AVG(total_price) as average_order_value,
  COUNT(DISTINCT customer_id) as unique_customers
FROM sales
GROUP BY seller_id, DATE_TRUNC('month', sale_date)
ORDER BY sale_month DESC;

-- Customer lifetime value view
CREATE OR REPLACE VIEW customer_lifetime_value AS
SELECT 
  c.id as customer_id,
  c.name as customer_name,
  c.phone,
  c.age_range,
  c.total_orders,
  c.total_spent,
  c.last_purchase_date,
  CASE 
    WHEN c.total_orders > 0 THEN c.total_spent / c.total_orders
    ELSE 0
  END as average_order_value,
  CASE
    WHEN c.last_purchase_date IS NULL THEN 'Never'
    WHEN c.last_purchase_date > NOW() - INTERVAL '30 days' THEN 'Active'
    WHEN c.last_purchase_date > NOW() - INTERVAL '90 days' THEN 'At Risk'
    ELSE 'Churned'
  END as customer_status
FROM customers c
ORDER BY c.total_spent DESC;

-- Top customers view
CREATE OR REPLACE VIEW top_customers AS
SELECT 
  c.id as customer_id,
  c.name as customer_name,
  c.phone,
  c.total_orders,
  c.total_spent,
  c.last_purchase_date,
  RANK() OVER (ORDER BY c.total_spent DESC) as spending_rank
FROM customers c
WHERE c.total_orders > 0
ORDER BY c.total_spent DESC
LIMIT 100;

-- Product performance view
CREATE OR REPLACE VIEW product_performance AS
SELECT 
  p.id as product_id,
  p.name as product_name,
  p.asin,
  COUNT(s.id) as times_sold,
  SUM(s.quantity) as total_quantity,
  SUM(s.total_price) as total_revenue,
  AVG(s.unit_price) as average_price
FROM products p
LEFT JOIN sales s ON s.product_id = p.id
GROUP BY p.id, p.name, p.asin
ORDER BY total_revenue DESC;

-- ==============================================================================
-- PART 5: ROW LEVEL SECURITY (RLS)
-- ==============================================================================

-- Enable RLS
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS customers_seller_own ON customers;
DROP POLICY IF EXISTS sales_seller_own ON sales;

-- Customers: Sellers can only see/manage their own customers
CREATE POLICY customers_seller_own ON customers
  FOR ALL TO authenticated
  USING (seller_id = auth.uid())
  WITH CHECK (seller_id = auth.uid());

-- Sales: Sellers can only see/manage their own sales
CREATE POLICY sales_seller_own ON sales
  FOR ALL TO authenticated
  USING (seller_id = auth.uid())
  WITH CHECK (seller_id = auth.uid());

-- ==============================================================================
-- PART 6: HELPER FUNCTIONS
-- ==============================================================================

-- Function to get seller's total revenue
CREATE OR REPLACE FUNCTION get_seller_total_revenue(seller_uuid UUID)
RETURNS NUMERIC AS $$
BEGIN
  RETURN (
    SELECT COALESCE(SUM(total_price), 0)
    FROM sales
    WHERE seller_id = seller_uuid
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get seller's total customers
CREATE OR REPLACE FUNCTION get_seller_total_customers(seller_uuid UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM customers
    WHERE seller_id = seller_uuid
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get seller's sales count in date range
CREATE OR REPLACE FUNCTION get_seller_sales_count(
  seller_uuid UUID,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ
)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM sales
    WHERE seller_id = seller_uuid
      AND sale_date BETWEEN start_date AND end_date
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- PART 7: VERIFICATION QUERIES
-- ==============================================================================

-- Verify tables were created
SELECT '✓ Tables Created' as status, table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('customers', 'sales')
ORDER BY table_name;

-- Verify indexes
SELECT '✓ Indexes Created' as status, indexname, tablename
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('customers', 'sales')
ORDER BY tablename, indexname;

-- Verify triggers
SELECT '✓ Triggers Created' as status, trigger_name, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE 'trigger_%'
ORDER BY trigger_name;

-- Verify views
SELECT '✓ Views Created' as status, viewname
FROM pg_views
WHERE schemaname = 'public'
  AND viewname IN (
    'daily_sales_summary',
    'monthly_sales_summary',
    'customer_lifetime_value',
    'top_customers',
    'product_performance'
  )
ORDER BY viewname;

-- Count RLS policies
SELECT '📊 RLS Policies' as status,
       (SELECT count(*) FROM pg_policies WHERE tablename = 'customers') as customers_policies,
       (SELECT count(*) FROM pg_policies WHERE tablename = 'sales') as sales_policies;

-- ==============================================================================
-- MIGRATION COMPLETE
-- ==============================================================================
--
-- Database Schema Created:
-- ✓ customers table - Customer management with auto-calculated stats
-- ✓ sales table - Sales records linked to customers and products
-- ✓ Triggers for auto-updating customer stats on sale
-- ✓ Analytics views (daily, monthly, customer LTV, top customers, products)
-- ✓ RLS policies for data security
-- ✓ Helper functions for KPI calculations
--
-- Next Steps:
-- 1. ✓ Run this script in Supabase SQL Editor
-- 2. ✓ Implement Flutter models (Customer, Sale)
-- 3. ✓ Add methods to SupabaseProvider
-- 4. ✓ Create Customers UI
-- 5. ✓ Create Sales UI
-- 6. ✓ Create Analytics Dashboard
--
-- Testing:
-- - Add a customer via Flutter app
-- - Record a sale linked to that customer
-- - Verify customer stats auto-update (total_orders, total_spent)
-- - Check analytics views show correct data
-- - Verify RLS prevents access to other sellers' data
--
-- ==============================================================================
