-- ==============================================================================
-- Aurora E-Commerce: Complete Customers, Sales & Analytics System
-- ==============================================================================
-- CLEAN INSTALLATION - Drops and recreates everything
-- Run this in Supabase SQL Editor: https://app.supabase.com/project/_/sql
-- ==============================================================================

-- ==============================================================================
-- PART 0: DROP EXISTING OBJECTS (Clean Slate)
-- ==============================================================================

-- Drop views
DROP VIEW IF EXISTS seller_analytics CASCADE;
DROP VIEW IF EXISTS daily_sales_summary CASCADE;
DROP VIEW IF EXISTS monthly_sales_summary CASCADE;
DROP VIEW IF EXISTS customer_lifetime_value CASCADE;
DROP VIEW IF EXISTS top_customers CASCADE;
DROP VIEW IF EXISTS product_performance CASCADE;

-- Drop triggers
DROP TRIGGER IF EXISTS trigger_update_customer_stats_on_sale ON sales;
DROP TRIGGER IF EXISTS trigger_update_sales_timestamp ON sales;
DROP TRIGGER IF EXISTS trigger_update_customers_timestamp ON customers;

-- Drop functions
DROP FUNCTION IF EXISTS update_customer_stats_on_sale() CASCADE;
DROP FUNCTION IF EXISTS update_sales_timestamp() CASCADE;
DROP FUNCTION IF EXISTS update_customers_timestamp() CASCADE;
DROP FUNCTION IF EXISTS get_seller_total_revenue(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_seller_total_customers(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_seller_sales_count(UUID, TIMESTAMPTZ, TIMESTAMPTZ) CASCADE;
DROP FUNCTION IF EXISTS calculate_seller_analytics(UUID, TEXT, DATE, DATE) CASCADE;
DROP FUNCTION IF EXISTS create_analytics_snapshot(UUID, TEXT, DATE, DATE) CASCADE;
DROP FUNCTION IF EXISTS get_seller_kpis(UUID, TEXT) CASCADE;

-- Drop tables (in reverse dependency order)
DROP TABLE IF EXISTS analytics_snapshots CASCADE;
DROP TABLE IF EXISTS sales CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- ==============================================================================
-- PART 1: CREATE TABLES
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1.1 CUSTOMERS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  
  -- Customer Information
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  age_range TEXT CHECK (age_range IN ('teens', '20s', '30s', '40s', '50s', '60s', '70s+')),
  notes TEXT,
  
  -- Auto-calculated Statistics
  total_orders INTEGER DEFAULT 0,
  total_spent NUMERIC(12, 2) DEFAULT 0.00,
  last_purchase_date TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT valid_phone CHECK (phone ~ '^[0-9+\-\s()]+$'),
  CONSTRAINT valid_email CHECK (email IS NULL OR email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- ------------------------------------------------------------------------------
-- 1.2 SALES TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,

  -- Links (optional for walk-in/general sales)
  customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,

  -- Sale Details
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC(10, 2) NOT NULL,
  total_price NUMERIC(10, 2) NOT NULL,
  discount NUMERIC(10, 2) DEFAULT 0.00,

  -- Timestamps
  sale_date TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  CONSTRAINT valid_quantity CHECK (quantity > 0),
  CONSTRAINT valid_unit_price CHECK (unit_price >= 0),
  CONSTRAINT valid_total_price CHECK (total_price >= 0),
  CONSTRAINT valid_discount CHECK (discount >= 0 AND discount <= total_price)
);

-- ------------------------------------------------------------------------------
-- 1.3 ANALYTICS SNAPSHOTS TABLE (JSON Storage)
-- ------------------------------------------------------------------------------
CREATE TABLE analytics_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  
  -- Period Information
  period_type TEXT CHECK (period_type IN ('daily', 'weekly', 'monthly', 'yearly', 'custom')) NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  
  -- Complete Analytics JSON
  analytics_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  
  -- Metadata
  is_current BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Unique constraint (one snapshot per period per seller)
  CONSTRAINT unique_seller_period UNIQUE (seller_id, period_type, period_start, period_end)
);

-- ==============================================================================
-- PART 2: CREATE INDEXES FOR PERFORMANCE
-- ==============================================================================

-- Customers indexes
CREATE INDEX idx_customers_seller_id ON customers(seller_id);
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_name ON customers(name);
CREATE INDEX idx_customers_age_range ON customers(age_range);
CREATE INDEX idx_customers_created_at ON customers(created_at DESC);
CREATE INDEX idx_customers_total_spent ON customers(total_spent DESC);

-- Sales indexes
CREATE INDEX idx_sales_seller_id ON sales(seller_id);
CREATE INDEX idx_sales_customer_id ON sales(customer_id);
CREATE INDEX idx_sales_product_id ON sales(product_id);
CREATE INDEX idx_sales_date ON sales(sale_date DESC);
CREATE INDEX idx_sales_seller_date ON sales(seller_id, sale_date DESC);

-- Analytics snapshots indexes
CREATE INDEX idx_analytics_seller_id ON analytics_snapshots(seller_id);
CREATE INDEX idx_analytics_period_type ON analytics_snapshots(period_type);
CREATE INDEX idx_analytics_period_start ON analytics_snapshots(period_start DESC);
CREATE INDEX idx_analytics_is_current ON analytics_snapshots(is_current) WHERE is_current = true;

-- ==============================================================================
-- PART 3: CREATE TRIGGERS FOR AUTO-UPDATES
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 3.1 Update customer stats when sale is recorded
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_customer_stats_on_sale()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update if customer_id is provided
  IF NEW.customer_id IS NOT NULL THEN
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

CREATE TRIGGER trigger_update_customer_stats_on_sale
  AFTER INSERT ON sales
  FOR EACH ROW
  EXECUTE FUNCTION update_customer_stats_on_sale();

-- ------------------------------------------------------------------------------
-- 3.2 Update timestamps on sales
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_sales_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_sales_timestamp
  BEFORE UPDATE ON sales
  FOR EACH ROW
  EXECUTE FUNCTION update_sales_timestamp();

-- ------------------------------------------------------------------------------
-- 3.3 Update timestamps on customers
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_customers_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_customers_timestamp
  BEFORE UPDATE ON customers
  FOR EACH ROW
  EXECUTE FUNCTION update_customers_timestamp();

-- ==============================================================================
-- PART 4: CREATE ANALYTICS FUNCTIONS
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 4.1 Calculate complete seller analytics (returns JSON)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_seller_analytics(
  p_seller_id UUID,
  p_period_type TEXT DEFAULT '30d',
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_start_date DATE;
  v_end_date DATE;
  v_days INTEGER;
  v_result JSONB;
BEGIN
  -- Calculate date range based on period type
  IF p_start_date IS NOT NULL AND p_end_date IS NOT NULL THEN
    v_start_date := p_start_date;
    v_end_date := p_end_date;
    v_days := (p_end_date - p_start_date) + 1;
  ELSE
    -- Parse period type (e.g., '7d', '30d', '90d', '1y')
    IF p_period_type LIKE '%y' THEN
      v_days := (SUBSTRING(p_period_type FROM '(\d+)')::INTEGER) * 365;
    ELSIF p_period_type LIKE '%d' THEN
      v_days := SUBSTRING(p_period_type FROM '(\d+)')::INTEGER;
    ELSE
      v_days := 30; -- Default to 30 days
    END IF;
    
    v_end_date := CURRENT_DATE;
    v_start_date := v_end_date - (v_days - 1);
  END IF;
  
  -- Calculate all analytics
  WITH sales_data AS (
    SELECT 
      COUNT(*) as total_sales,
      COALESCE(SUM(total_price), 0) as total_revenue,
      COALESCE(SUM(quantity), 0) as total_items_sold,
      COALESCE(AVG(total_price), 0) as average_order_value,
      COUNT(DISTINCT customer_id) as unique_customers
    FROM sales
    WHERE seller_id = p_seller_id
      AND sale_date >= v_start_date
      AND sale_date <= v_end_date
  ),
  customer_data AS (
    SELECT COUNT(*) as total_customers
    FROM customers
    WHERE seller_id = p_seller_id
  ),
  top_products AS (
    SELECT
      COALESCE(p.title, s.product_id::TEXT) as product_name,
      s.product_id,
      COUNT(*) as times_sold,
      SUM(s.quantity) as units_sold,
      SUM(s.total_price) as revenue
    FROM sales s
    LEFT JOIN products p ON p.id = s.product_id
    WHERE s.seller_id = p_seller_id
      AND s.sale_date >= v_start_date
      AND s.sale_date <= v_end_date
    GROUP BY s.product_id, p.title
    ORDER BY revenue DESC
    LIMIT 5
  ),
  top_customers AS (
    SELECT 
      c.id,
      c.name,
      c.phone,
      COUNT(s.id) as orders_in_period,
      SUM(s.total_price) as spent_in_period
    FROM customers c
    LEFT JOIN sales s ON s.customer_id = c.id
      AND s.sale_date >= v_start_date
      AND s.sale_date <= v_end_date
    WHERE c.seller_id = p_seller_id
    GROUP BY c.id, c.name, c.phone
    ORDER BY spent_in_period DESC NULLS LAST
    LIMIT 5
  ),
  daily_breakdown AS (
    SELECT
      DATE(sale_date) as date,
      COUNT(*) as sales,
      SUM(total_price) as revenue
    FROM sales
    WHERE seller_id = p_seller_id
      AND sale_date >= v_start_date
      AND sale_date <= v_end_date
    GROUP BY DATE(sale_date)
    ORDER BY date
  )
  SELECT jsonb_build_object(
    'seller_id', p_seller_id,
    'period', p_period_type,
    'period_days', v_days,
    'start_date', v_start_date,
    'end_date', v_end_date,
    'generated_at', NOW(),
    'kpis', jsonb_build_object(
      'total_revenue', COALESCE(sd.total_revenue, 0),
      'total_sales', COALESCE(sd.total_sales, 0),
      'total_items_sold', COALESCE(sd.total_items_sold, 0),
      'total_customers', COALESCE(cd.total_customers, 0),
      'unique_customers_in_period', COALESCE(sd.unique_customers, 0),
      'average_order_value', COALESCE(sd.average_order_value, 0),
      'conversion_rate', CASE
        WHEN cd.total_customers > 0
        THEN ROUND((sd.unique_customers::NUMERIC / cd.total_customers::NUMERIC) * 100, 2)
        ELSE 0
      END
    ),
    'top_products', COALESCE(
      (SELECT jsonb_agg(
        jsonb_build_object(
          'id', tp.product_id,
          'name', tp.product_name,
          'times_sold', tp.times_sold,
          'units_sold', tp.units_sold,
          'revenue', tp.revenue
        )
      ) FROM top_products tp),
      '[]'::jsonb
    ),
    'top_customers', COALESCE(
      (SELECT jsonb_agg(
        jsonb_build_object(
          'id', tc.id,
          'name', tc.name,
          'phone', tc.phone,
          'orders_in_period', tc.orders_in_period,
          'spent_in_period', tc.spent_in_period
        )
      ) FROM top_customers tc),
      '[]'::jsonb
    ),
    'daily_breakdown', COALESCE(
      (SELECT jsonb_agg(
        jsonb_build_object(
          'date', db.date,
          'sales', db.sales,
          'revenue', db.revenue
        )
      ) FROM daily_breakdown db),
      '[]'::jsonb
    )
  ) INTO v_result
  FROM sales_data sd, customer_data cd;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------------------------
-- 4.2 Create analytics snapshot (store in table)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_analytics_snapshot(
  p_seller_id UUID,
  p_period_type TEXT DEFAULT '30d',
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_snapshot_id UUID;
  v_analytics_data JSONB;
  v_period_start DATE;
  v_period_end DATE;
BEGIN
  -- Calculate date range
  IF p_start_date IS NOT NULL AND p_end_date IS NOT NULL THEN
    v_period_start := p_start_date;
    v_period_end := p_end_date;
  ELSE
    IF p_period_type LIKE '%y' THEN
      v_period_end := CURRENT_DATE;
      v_period_start := v_period_end - ((SUBSTRING(p_period_type FROM '(\d+)')::INTEGER) * 365 - 1);
    ELSIF p_period_type LIKE '%d' THEN
      v_period_end := CURRENT_DATE;
      v_period_start := v_period_end - (SUBSTRING(p_period_type FROM '(\d+)')::INTEGER - 1);
    ELSE
      v_period_end := CURRENT_DATE;
      v_period_start := v_period_end - 29;
    END IF;
  END IF;
  
  -- Calculate analytics
  v_analytics_data := calculate_seller_analytics(p_seller_id, p_period_type, p_start_date, p_end_date);
  
  -- Mark existing snapshots for this period as not current
  UPDATE analytics_snapshots
  SET is_current = false
  WHERE seller_id = p_seller_id
    AND period_type = p_period_type
    AND period_start = v_period_start
    AND period_end = v_period_end;
  
  -- Insert new snapshot
  INSERT INTO analytics_snapshots (
    seller_id,
    period_type,
    period_start,
    period_end,
    analytics_data,
    is_current
  ) VALUES (
    p_seller_id,
    p_period_type,
    v_period_start,
    v_period_end,
    v_analytics_data,
    true
  )
  ON CONFLICT (seller_id, period_type, period_start, period_end) 
  DO UPDATE SET
    analytics_data = EXCLUDED.analytics_data,
    is_current = true,
    updated_at = NOW()
  RETURNING id INTO v_snapshot_id;
  
  RETURN v_snapshot_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------------------------
-- 4.3 Get seller KPIs (from snapshot or calculate)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_seller_kpis(
  p_seller_id UUID,
  p_period TEXT DEFAULT '30d'
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
  v_snapshot RECORD;
BEGIN
  -- Try to get existing snapshot (less than 1 hour old)
  SELECT * INTO v_snapshot
  FROM analytics_snapshots
  WHERE seller_id = p_seller_id
    AND period_type = p_period
    AND is_current = true
    AND created_at > NOW() - INTERVAL '1 hour'
  ORDER BY created_at DESC
  LIMIT 1;
  
  IF v_snapshot.id IS NOT NULL THEN
    -- Return cached snapshot
    v_result := v_snapshot.analytics_data;
  ELSE
    -- Calculate fresh analytics
    v_result := calculate_seller_analytics(p_seller_id, p_period);
    
    -- Create new snapshot
    PERFORM create_analytics_snapshot(p_seller_id, p_period);
  END IF;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- PART 5: CREATE HELPER FUNCTIONS
-- ==============================================================================

-- Get seller's total revenue (all time)
CREATE OR REPLACE FUNCTION get_seller_total_revenue(p_seller_id UUID)
RETURNS NUMERIC AS $$
BEGIN
  RETURN COALESCE((
    SELECT SUM(total_price)
    FROM sales
    WHERE seller_id = p_seller_id
  ), 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get seller's total customers
CREATE OR REPLACE FUNCTION get_seller_total_customers(p_seller_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN COALESCE((
    SELECT COUNT(*)
    FROM customers
    WHERE seller_id = p_seller_id
  ), 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get seller's sales count in date range
CREATE OR REPLACE FUNCTION get_seller_sales_count(
  p_seller_id UUID,
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ
)
RETURNS INTEGER AS $$
BEGIN
  RETURN COALESCE((
    SELECT COUNT(*)
    FROM sales
    WHERE seller_id = p_seller_id
      AND sale_date BETWEEN p_start_date AND p_end_date
  ), 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- PART 6: CREATE ANALYTICS VIEWS
-- ==============================================================================

-- Daily sales summary
CREATE OR REPLACE VIEW daily_sales_summary AS
SELECT
  seller_id,
  DATE(sale_date) as sale_day,
  COUNT(*) as total_sales,
  SUM(total_price) as total_revenue,
  SUM(quantity) as total_items,
  AVG(total_price) as average_order_value,
  COUNT(DISTINCT customer_id) as unique_customers
FROM sales
GROUP BY seller_id, DATE(sale_date);

-- Monthly sales summary
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
GROUP BY seller_id, DATE_TRUNC('month', sale_date);

-- Customer lifetime value
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
    WHEN c.last_purchase_date IS NULL THEN 'New'
    WHEN c.last_purchase_date > NOW() - INTERVAL '30 days' THEN 'Active'
    WHEN c.last_purchase_date > NOW() - INTERVAL '90 days' THEN 'At Risk'
    ELSE 'Churned'
  END as customer_status
FROM customers c;

-- Top customers
CREATE OR REPLACE VIEW top_customers AS
SELECT 
  c.id as customer_id,
  c.name as customer_name,
  c.phone,
  c.total_orders,
  c.total_spent,
  c.last_purchase_date,
  RANK() OVER (ORDER BY c.total_spent DESC NULLS LAST) as spending_rank
FROM customers c
WHERE c.total_orders > 0;

-- Product performance
CREATE OR REPLACE VIEW product_performance AS
SELECT
  p.id as product_id,
  COALESCE(p.title, p.asin) as product_name,
  p.asin,
  COUNT(s.id) as times_sold,
  COALESCE(SUM(s.quantity), 0) as total_quantity,
  COALESCE(SUM(s.total_price), 0) as total_revenue,
  COALESCE(AVG(s.unit_price), 0) as average_price
FROM products p
LEFT JOIN sales s ON s.product_id = p.id
GROUP BY p.id, p.title, p.asin;

-- ==============================================================================
-- PART 7: ROW LEVEL SECURITY (RLS)
-- ==============================================================================

-- Enable RLS
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_snapshots ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS customers_seller_own ON customers;
DROP POLICY IF EXISTS sales_seller_own ON sales;
DROP POLICY IF EXISTS analytics_seller_own ON analytics_snapshots;

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

-- Analytics: Sellers can only see their own analytics
CREATE POLICY analytics_seller_own ON analytics_snapshots
  FOR ALL TO authenticated
  USING (seller_id = auth.uid())
  WITH CHECK (seller_id = auth.uid());

-- ==============================================================================
-- PART 8: VERIFICATION QUERIES
-- ==============================================================================

-- Verify tables were created
SELECT '✓ Tables Created' as status, table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('customers', 'sales', 'analytics_snapshots')
ORDER BY table_name;

-- Verify indexes
SELECT '✓ Indexes Created' as status, COUNT(*) as total_indexes
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('customers', 'sales', 'analytics_snapshots');

-- Verify triggers
SELECT '✓ Triggers Created' as status, trigger_name
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE 'trigger_%';

-- Verify functions
SELECT '✓ Functions Created' as status, routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'update_customer_stats_on_sale',
    'update_sales_timestamp',
    'update_customers_timestamp',
    'calculate_seller_analytics',
    'create_analytics_snapshot',
    'get_seller_kpis',
    'get_seller_total_revenue',
    'get_seller_total_customers',
    'get_seller_sales_count'
  );

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
  );

-- Count RLS policies
SELECT '📊 RLS Policies' as status,
       (SELECT count(*) FROM pg_policies WHERE tablename = 'customers') as customers_policies,
       (SELECT count(*) FROM pg_policies WHERE tablename = 'sales') as sales_policies,
       (SELECT count(*) FROM pg_policies WHERE tablename = 'analytics_snapshots') as analytics_policies;

-- ==============================================================================
-- MIGRATION COMPLETE
-- ==============================================================================
--
-- ✅ Database Schema Created Successfully!
--
-- Tables:
-- ✓ customers - Customer management with auto-calculated stats
-- ✓ sales - Sales records linked to customers and products
-- ✓ analytics_snapshots - Pre-calculated analytics stored as JSON
--
-- Features:
-- ✓ Auto-update customer stats on sale (trigger)
-- ✓ Auto-update timestamps (triggers)
-- ✓ Calculate complete analytics (function)
-- ✓ Create analytics snapshots (function)
-- ✓ Get KPIs with caching (function)
-- ✓ Analytics views for reporting
-- ✓ RLS policies for data security
-- ✓ Helper functions for common queries
--
-- Next Steps:
-- 1. ✓ Verify all objects created (check output above)
-- 2. ✓ Test in Flutter app:
--    - Add a customer
--    - Record a sale
--    - View analytics dashboard
-- 3. ✓ Verify customer stats auto-update
-- 4. ✓ Verify analytics JSON is created
--
-- Testing SQL:
-- -- Test analytics calculation
-- SELECT calculate_seller_analytics('YOUR-SELLER-UUID', '30d');
--
-- -- Test snapshot creation
-- SELECT create_analytics_snapshot('YOUR-SELLER-UUID', '30d');
--
-- -- Test KPI retrieval
-- SELECT get_seller_kpis('YOUR-SELLER-UUID', '30d');
--
-- ==============================================================================
