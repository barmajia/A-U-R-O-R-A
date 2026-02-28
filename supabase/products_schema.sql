-- ================================================================
-- AURORA E-COMMERCE - PRODUCTS TABLE SCHEMA
-- ================================================================
-- Run this in Supabase SQL Editor to create the products table
-- https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/sql/new
-- ================================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================================
-- PRODUCTS TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asin TEXT UNIQUE,
  sku TEXT,
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  marketplace_id TEXT,
  product_type TEXT,
  status TEXT DEFAULT 'draft',
  
  -- Product Identifiers (JSONB)
  identifiers JSONB,
  
  -- Product Content
  title TEXT,
  description TEXT,
  bullet_points JSONB,
  brand TEXT,
  manufacturer TEXT,
  language TEXT DEFAULT 'en_US',
  
  -- Product Pricing
  currency TEXT DEFAULT 'USD',
  list_price DECIMAL(10,2),
  selling_price DECIMAL(10,2),
  business_price DECIMAL(10,2),
  tax_code TEXT,
  
  -- Product Inventory
  quantity INTEGER DEFAULT 0,
  fulfillment_channel TEXT, -- AFN (Amazon) or MFN (Merchant)
  availability_status TEXT,
  lead_time_to_ship TEXT,
  
  -- Product Images (JSONB)
  images JSONB,
  
  -- Product Variations (JSONB)
  variations JSONB,
  
  -- Product Compliance (JSONB)
  compliance JSONB,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  version TEXT,
  
  -- Soft Delete
  is_deleted BOOLEAN DEFAULT FALSE,
  deleted_at TIMESTAMP WITH TIME ZONE
);

-- ================================================================
-- INDEXES FOR PERFORMANCE
-- ================================================================

CREATE INDEX IF NOT EXISTS idx_products_asin ON products(asin);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
CREATE INDEX IF NOT EXISTS idx_products_seller_id ON products(seller_id);
CREATE INDEX IF NOT EXISTS idx_products_status ON products(status);
CREATE INDEX IF NOT EXISTS idx_products_brand ON products(brand);
CREATE INDEX IF NOT EXISTS idx_products_product_type ON products(product_type);
CREATE INDEX IF NOT EXISTS idx_products_created_at ON products(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_products_availability ON products(quantity, availability_status);

-- Index for JSONB fields (for searching)
CREATE INDEX IF NOT EXISTS idx_products_identifiers ON products USING GIN (identifiers);
CREATE INDEX IF NOT EXISTS idx_products_images ON products USING GIN (images);

-- ================================================================
-- ROW LEVEL SECURITY (RLS)
-- ================================================================

ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Sellers can view own products" ON products;
DROP POLICY IF EXISTS "Sellers can insert own products" ON products;
DROP POLICY IF EXISTS "Sellers can update own products" ON products;
DROP POLICY IF EXISTS "Sellers can delete own products" ON products;
DROP POLICY IF EXISTS "Anyone can view active products" ON products;

-- Policy: Sellers can view their own products
CREATE POLICY "Sellers can view own products"
  ON products FOR SELECT
  USING (auth.uid() = seller_id OR is_deleted = false);

-- Policy: Sellers can insert their own products
CREATE POLICY "Sellers can insert own products"
  ON products FOR INSERT
  WITH CHECK (auth.uid() = seller_id);

-- Policy: Sellers can update their own products
CREATE POLICY "Sellers can update own products"
  ON products FOR UPDATE
  USING (auth.uid() = seller_id);

-- Policy: Sellers can delete their own products (soft delete)
CREATE POLICY "Sellers can delete own products"
  ON products FOR DELETE
  USING (auth.uid() = seller_id);

-- Policy: Anyone can view active (non-deleted) products
CREATE POLICY "Anyone can view active products"
  ON products FOR SELECT
  USING (is_deleted = false AND status = 'active');

-- ================================================================
-- TRIGGERS
-- ================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_products_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION update_products_updated_at_column();

-- ================================================================
-- HELPER FUNCTIONS
-- ================================================================

-- Function to get seller's product count
CREATE OR REPLACE FUNCTION get_seller_product_count(seller_uuid UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM products
    WHERE seller_id = seller_uuid AND is_deleted = false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get low stock products
CREATE OR REPLACE FUNCTION get_low_stock_products(threshold INTEGER DEFAULT 10)
RETURNS TABLE (
  id UUID,
  asin TEXT,
  title TEXT,
  quantity INTEGER,
  seller_id UUID
) AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.asin, p.title, p.quantity, p.seller_id
  FROM products p
  WHERE p.quantity <= threshold 
    AND p.is_deleted = false
    AND p.seller_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- GRANT PERMISSIONS
-- ================================================================

GRANT ALL ON products TO authenticated;
GRANT SELECT ON products TO anon;

-- ================================================================
-- SAMPLE DATA (Optional - for testing)
-- ================================================================

-- Uncomment to insert a sample product
/*
INSERT INTO products (
  asin, sku, seller_id, title, description, brand,
  currency, list_price, selling_price, quantity,
  status, language
) VALUES (
  'B08TEST123',
  'TEST-SKU-001',
  auth.uid(),
  'Sample Product',
  'This is a sample product description',
  'Test Brand',
  'USD',
  29.99,
  24.99,
  100,
  'active',
  'en_US'
);
*/

-- ================================================================
-- VERIFICATION QUERIES
-- ================================================================

-- Check if table was created
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'products';

-- Check if indexes were created
-- SELECT indexname FROM pg_indexes WHERE tablename = 'products';

-- Check if policies were created
-- SELECT policyname FROM pg_policies WHERE tablename = 'products';

-- ================================================================
-- SETUP COMPLETE! ✓
-- ================================================================
