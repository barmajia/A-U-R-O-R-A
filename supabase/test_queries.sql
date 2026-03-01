-- ==============================================================================
-- Aurora E-Commerce: Quick Test Queries
-- ==============================================================================
-- Copy and paste these queries one by one to test the system
-- Replace 'YOUR-SELLER-UUID' with your actual seller UUID from auth.users
-- ==============================================================================

-- ==============================================================================
-- STEP 1: GET YOUR SELLER UUID
-- ==============================================================================
-- Run this first to get your seller UUID
SELECT 
  id as seller_uuid,
  email,
  raw_user_meta_data->>'full_name' as full_name
FROM auth.users
LIMIT 5;

-- Copy one of the UUIDs above and use it in the tests below

-- ==============================================================================
-- STEP 2: VERIFY TABLES EXIST
-- ==============================================================================
SELECT 'Customers' as table_name, count(*) as row_count FROM customers
UNION ALL
SELECT 'Sales', count(*) FROM sales
UNION ALL
SELECT 'Analytics Snapshots', count(*) FROM analytics_snapshots;

-- ==============================================================================
-- STEP 3: ADD TEST CUSTOMER
-- ==============================================================================
INSERT INTO customers (
  seller_id,
  name,
  phone,
  age_range,
  email,
  notes
) VALUES (
  'YOUR-SELLER-UUID',  -- ← Replace with your UUID
  'Test Customer',
  '+1234567890',
  '30s',
  'test@example.com',
  'Test customer for testing'
);

-- Verify customer was added
SELECT * FROM customers WHERE email = 'test@example.com';

-- ==============================================================================
-- STEP 4: RECORD TEST SALE
-- ==============================================================================
INSERT INTO sales (
  seller_id,
  customer_id,
  quantity,
  unit_price,
  total_price,
  discount,
  payment_method,
  payment_status
) VALUES (
  'YOUR-SELLER-UUID',  -- ← Replace with your UUID
  (SELECT id FROM customers WHERE email = 'test@example.com'),
  2,                    -- quantity
  50.00,                -- unit price
  100.00,               -- total price
  0.00,                 -- discount
  'cash',               -- payment_method
  'completed'           -- payment_status
);

-- Verify sale was recorded
SELECT * FROM sales WHERE seller_id = 'YOUR-SELLER-UUID'
ORDER BY created_at DESC
LIMIT 1;

-- ==============================================================================
-- STEP 5: VERIFY CUSTOMER STATS AUTO-UPDATED
-- ==============================================================================
-- Customer stats should now show:
-- total_orders = 1
-- total_spent = 100.00
SELECT 
  name,
  total_orders,
  total_spent,
  last_purchase_date,
  CASE
    WHEN last_purchase_date > NOW() - INTERVAL '30 days' THEN 'Active'
    ELSE 'Churned'
  END as status
FROM customers 
WHERE email = 'test@example.com';

-- ==============================================================================
-- STEP 6: TEST ANALYTICS FUNCTIONS
-- ==============================================================================

-- 6a. Calculate analytics (returns JSON)
SELECT get_seller_kpis('YOUR-SELLER-UUID', '30d');

-- 6b. Create analytics snapshot
SELECT create_analytics_snapshot('YOUR-SELLER-UUID', '30d');

-- 6c. Verify snapshot was stored
SELECT 
  id,
  period_type,
  period_start,
  period_end,
  analytics_data->'kpis'->>'total_revenue' as total_revenue,
  analytics_data->'kpis'->>'total_sales' as total_sales,
  is_current,
  created_at
FROM analytics_snapshots
WHERE seller_id = 'YOUR-SELLER-UUID'
ORDER BY created_at DESC
LIMIT 1;

-- ==============================================================================
-- STEP 7: TEST VIEWS
-- ==============================================================================

-- 7a. Daily sales summary
SELECT * FROM daily_sales_summary
WHERE seller_id = 'YOUR-SELLER-UUID'
ORDER BY sale_day DESC
LIMIT 7;

-- 7b. Monthly sales summary
SELECT * FROM monthly_sales_summary
WHERE seller_id = 'YOUR-SELLER-UUID'
ORDER BY sale_month DESC
LIMIT 12;

-- 7c. Customer lifetime value
SELECT * FROM customer_lifetime_value
WHERE seller_id = 'YOUR-SELLER-UUID'
ORDER BY total_spent DESC
LIMIT 10;

-- 7d. Top customers
SELECT * FROM top_customers
WHERE seller_id = 'YOUR-SELLER-UUID'
LIMIT 10;

-- 7e. Product performance
SELECT * FROM product_performance
WHERE seller_id = 'YOUR-SELLER-UUID'
ORDER BY total_revenue DESC
LIMIT 10;

-- ==============================================================================
-- STEP 8: TEST HELPER FUNCTIONS
-- ==============================================================================

-- 8a. Get total revenue
SELECT get_seller_total_revenue('YOUR-SELLER-UUID') as total_revenue;

-- 8b. Get total customers
SELECT get_seller_total_customers('YOUR-SELLER-UUID') as total_customers;

-- 8c. Get sales count in date range
SELECT get_seller_sales_count(
  'YOUR-SELLER-UUID',
  NOW() - INTERVAL '30 days',
  NOW()
) as sales_last_30_days;

-- ==============================================================================
-- STEP 9: ADD MORE TEST DATA (Optional)
-- ==============================================================================

-- Add more customers
INSERT INTO customers (seller_id, name, phone, age_range, email) VALUES
  ('YOUR-SELLER-UUID', 'Alice Johnson', '+1111111111', '20s', 'alice@example.com'),
  ('YOUR-SELLER-UUID', 'Bob Smith', '+2222222222', '40s', 'bob@example.com'),
  ('YOUR-SELLER-UUID', 'Carol White', '+3333333333', '50s', 'carol@example.com');

-- Add more sales
INSERT INTO sales (seller_id, customer_id, quantity, unit_price, total_price, payment_method)
SELECT 
  'YOUR-SELLER-UUID' as seller_id,
  c.id as customer_id,
  (floor(random() * 5) + 1)::int as quantity,
  (floor(random() * 100) + 10)::numeric as unit_price,
  (floor(random() * 100) + 10)::numeric as total_price,
  (ARRAY['cash', 'card', 'transfer'])[floor(random() * 3 + 1)] as payment_method
FROM customers c
WHERE c.seller_id = 'YOUR-SELLER-UUID'
  AND c.email != 'test@example.com'
LIMIT 10;

-- ==============================================================================
-- STEP 10: VERIFY RLS (Row Level Security)
-- ==============================================================================

-- Check RLS is enabled
SELECT 
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('customers', 'sales', 'analytics_snapshots');

-- Check RLS policies
SELECT 
  tablename,
  policyname,
  cmd as permission,
  roles
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ==============================================================================
-- STEP 11: CLEANUP TEST DATA (Optional)
-- ==============================================================================
-- Run this if you want to remove test data

-- Delete test sales
DELETE FROM sales 
WHERE seller_id = 'YOUR-SELLER-UUID';

-- Delete test customers
DELETE FROM customers 
WHERE seller_id = 'YOUR-SELLER-UUID';

-- Delete analytics snapshots
DELETE FROM analytics_snapshots 
WHERE seller_id = 'YOUR-SELLER-UUID';

-- ==============================================================================
-- STEP 12: USEFUL MAINTENANCE QUERIES
-- ==============================================================================

-- Get database size
SELECT 
  pg_size_pretty(pg_total_relation_size('customers')) as customers_size,
  pg_size_pretty(pg_total_relation_size('sales')) as sales_size,
  pg_size_pretty(pg_total_relation_size('analytics_snapshots')) as analytics_size;

-- Get record counts by seller
SELECT 
  seller_id,
  (SELECT count(*) FROM customers c WHERE c.seller_id = s.seller_id) as customers,
  (SELECT count(*) FROM sales s2 WHERE s2.seller_id = s.seller_id) as sales,
  (SELECT count(*) FROM analytics_snapshots a WHERE a.seller_id = s.seller_id) as snapshots
FROM (SELECT DISTINCT seller_id FROM sales) s
ORDER BY sales DESC;

-- Find old analytics snapshots (older than 30 days)
SELECT 
  period_type,
  period_start,
  period_end,
  created_at,
  is_current
FROM analytics_snapshots
WHERE created_at < NOW() - INTERVAL '30 days'
ORDER BY created_at;

-- ==============================================================================
-- END OF TEST QUERIES
-- ==============================================================================
