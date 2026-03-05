-- ================================================================
-- AURORA E-COMMERCE - COMPLETE SUPABASE SETUP
-- ================================================================
-- Project: ofovfxsfazlwvcakpuer
-- Run this in Supabase SQL Editor: 
-- https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/sql/new
-- ================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================================
-- PART 1: STORAGE BUCKET FOR PRODUCT IMAGES
-- ================================================================

-- Create product-images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images', 
  'product-images', 
  true, 
  10485760, -- 10MB file size limit
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Anyone can view product images" ON storage.objects;
DROP POLICY IF EXISTS "Sellers can upload their own images" ON storage.objects;
DROP POLICY IF EXISTS "Sellers can update their own images" ON storage.objects;
DROP POLICY IF EXISTS "Sellers can delete their own images" ON storage.objects;

-- Policy: Anyone can view images (public read)
CREATE POLICY "Anyone can view product images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'product-images');

-- Policy: Authenticated users can upload images
CREATE POLICY "Sellers can upload their own images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'product-images' 
    AND auth.role() = 'authenticated'
  );

-- Policy: Sellers can update their own images (based on path)
CREATE POLICY "Sellers can update their own images"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'product-images' 
    AND auth.role() = 'authenticated'
  );

-- Policy: Sellers can delete their own images (based on path)
CREATE POLICY "Sellers can delete their own images"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'product-images' 
    AND auth.role() = 'authenticated'
  );

-- ================================================================
-- PART 2: CORE TABLES
-- ================================================================

-- --------------------------------------------------------------
-- SELLERS TABLE
-- --------------------------------------------------------------

CREATE TABLE IF NOT EXISTS sellers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  firstname TEXT,
  secoundname TEXT,
  thirdname TEXT,
  forthname TEXT,
  phone TEXT NOT NULL,
  location TEXT,
  currency TEXT DEFAULT 'USD',
  account_type TEXT DEFAULT 'seller',
  store_name TEXT,
  store_description TEXT,
  logo_url TEXT,
  banner_url TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  is_deleted BOOLEAN DEFAULT FALSE,
  last_login TIMESTAMP WITH TIME ZONE,
  rating DECIMAL DEFAULT 0.0,
  total_sales INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deleted_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for sellers
CREATE INDEX IF NOT EXISTS idx_sellers_user_id ON sellers(user_id);
CREATE INDEX IF NOT EXISTS idx_sellers_email ON sellers(email);
CREATE INDEX IF NOT EXISTS idx_sellers_account_type ON sellers(account_type);
CREATE INDEX IF NOT EXISTS idx_sellers_is_verified ON sellers(is_verified);
CREATE INDEX IF NOT EXISTS idx_sellers_last_login ON sellers(last_login);

-- RLS for sellers
ALTER TABLE sellers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own seller profile" ON sellers;
DROP POLICY IF EXISTS "Users can update own seller profile" ON sellers;
DROP POLICY IF EXISTS "Users can insert own seller profile" ON sellers;
DROP POLICY IF EXISTS "Anyone can view verified sellers" ON sellers;

CREATE POLICY "Users can view own seller profile"
  ON sellers FOR SELECT
  USING (auth.uid() = user_id OR is_verified = true);

CREATE POLICY "Users can update own seller profile"
  ON sellers FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own seller profile"
  ON sellers FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Anyone can view verified sellers"
  ON sellers FOR SELECT
  USING (is_verified = true);

-- --------------------------------------------------------------
-- PRODUCTS TABLE (Enhanced with category, subcategory, attributes)
-- --------------------------------------------------------------

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
  
  -- NEW: Category & Subcategory
  category TEXT,
  subcategory TEXT,
  
  -- NEW: Brand reference
  brand_id UUID REFERENCES brands(id),
  is_local_brand BOOLEAN DEFAULT FALSE,
  
  -- Product Pricing
  currency TEXT DEFAULT 'USD',
  list_price DECIMAL(10,2),
  selling_price DECIMAL(10,2),
  business_price DECIMAL(10,2),
  tax_code TEXT,
  
  -- Product Inventory
  quantity INTEGER DEFAULT 0,
  fulfillment_channel TEXT,
  availability_status TEXT,
  lead_time_to_ship TEXT,
  
  -- Product Images (JSONB)
  images JSONB,
  
  -- NEW: Product Attributes (JSONB) - for dynamic fields
  attributes JSONB DEFAULT '{}',
  
  -- NEW: Color hex code (for Fashion & Apparel)
  color_hex TEXT,
  
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

-- Indexes for products
CREATE INDEX IF NOT EXISTS idx_products_asin ON products(asin);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
CREATE INDEX IF NOT EXISTS idx_products_seller_id ON products(seller_id);
CREATE INDEX IF NOT EXISTS idx_products_status ON products(status);
CREATE INDEX IF NOT EXISTS idx_products_brand ON products(brand);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_subcategory ON products(subcategory);
CREATE INDEX IF NOT EXISTS idx_products_product_type ON products(product_type);
CREATE INDEX IF NOT EXISTS idx_products_created_at ON products(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_products_availability ON products(quantity, availability_status);
CREATE INDEX IF NOT EXISTS idx_products_attributes ON products USING GIN (attributes);
CREATE INDEX IF NOT EXISTS idx_products_identifiers ON products USING GIN (identifiers);
CREATE INDEX IF NOT EXISTS idx_products_images ON products USING GIN (images);

-- RLS for products
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Sellers can view own products" ON products;
DROP POLICY IF EXISTS "Sellers can insert own products" ON products;
DROP POLICY IF EXISTS "Sellers can update own products" ON products;
DROP POLICY IF EXISTS "Sellers can delete own products" ON products;
DROP POLICY IF EXISTS "Anyone can view active products" ON products;

-- Sellers can view their own products
CREATE POLICY "Sellers can view own products"
  ON products FOR SELECT
  USING (auth.uid() = seller_id OR (is_deleted = false AND status = 'active'));

-- Sellers can insert their own products
CREATE POLICY "Sellers can insert own products"
  ON products FOR INSERT
  WITH CHECK (auth.uid() = seller_id);

-- Sellers can update their own products
CREATE POLICY "Sellers can update own products"
  ON products FOR UPDATE
  USING (auth.uid() = seller_id);

-- Sellers can delete their own products
CREATE POLICY "Sellers can delete own products"
  ON products FOR DELETE
  USING (auth.uid() = seller_id);

-- Anyone can view active (non-deleted) products
CREATE POLICY "Anyone can view active products"
  ON products FOR SELECT
  USING (is_deleted = false AND status = 'active');

-- --------------------------------------------------------------
-- CATEGORIES TABLE
-- --------------------------------------------------------------

CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  icon_url TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name);
CREATE INDEX IF NOT EXISTS idx_categories_is_active ON categories(is_active);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view categories" ON categories;
DROP POLICY IF EXISTS "Admins can manage categories" ON categories;

CREATE POLICY "Anyone can view categories"
  ON categories FOR SELECT
  USING (is_active = TRUE);

CREATE POLICY "Admins can manage categories"
  ON categories FOR ALL
  USING (auth.jwt()->>'role' = 'admin');

-- --------------------------------------------------------------
-- SUBCATEGORIES TABLE
-- --------------------------------------------------------------

CREATE TABLE IF NOT EXISTS subcategories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  icon_url TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INTEGER DEFAULT 0,
  
  -- NEW: Attribute schema (JSONB) - defines required/optional attributes
  attribute_schema JSONB DEFAULT '{}',
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_subcategories_name ON subcategories(name);
CREATE INDEX IF NOT EXISTS idx_subcategories_category_id ON subcategories(category_id);
CREATE INDEX IF NOT EXISTS idx_subcategories_is_active ON subcategories(is_active);

ALTER TABLE subcategories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view subcategories" ON subcategories;
DROP POLICY IF EXISTS "Admins can manage subcategories" ON subcategories;

CREATE POLICY "Anyone can view subcategories"
  ON subcategories FOR SELECT
  USING (is_active = TRUE);

CREATE POLICY "Admins can manage subcategories"
  ON subcategories FOR ALL
  USING (auth.jwt()->>'role' = 'admin');

-- --------------------------------------------------------------
-- BRANDS TABLE
-- --------------------------------------------------------------

CREATE TABLE IF NOT EXISTS brands (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  logo_url TEXT,
  website_url TEXT,
  country TEXT,
  category TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_brands_name ON brands(name);
CREATE INDEX IF NOT EXISTS idx_brands_category ON brands(category);
CREATE INDEX IF NOT EXISTS idx_brands_is_verified ON brands(is_verified);
CREATE INDEX IF NOT EXISTS idx_brands_is_active ON brands(is_active);

-- Unique constraint on brand name + category
CREATE UNIQUE INDEX IF NOT EXISTS idx_brands_name_category_unique 
  ON brands(LOWER(name), LOWER(category));

ALTER TABLE brands ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view active brands" ON brands;
DROP POLICY IF EXISTS "Admins can manage brands" ON brands;

CREATE POLICY "Anyone can view active brands"
  ON brands FOR SELECT
  USING (is_active = TRUE);

CREATE POLICY "Admins can manage brands"
  ON brands FOR ALL
  USING (auth.jwt()->>'role' = 'admin');

-- --------------------------------------------------------------
-- CUSTOMERS TABLE
-- --------------------------------------------------------------

CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  age_range TEXT,
  email TEXT,
  notes TEXT,
  total_orders INTEGER DEFAULT 0,
  total_spent DECIMAL(10,2) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_customers_seller_id ON customers(seller_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email);

ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Sellers can view own customers" ON customers;
DROP POLICY IF EXISTS "Sellers can manage own customers" ON customers;

CREATE POLICY "Sellers can view own customers"
  ON customers FOR SELECT
  USING (auth.uid() = seller_id);

CREATE POLICY "Sellers can manage own customers"
  ON customers FOR ALL
  USING (auth.uid() = seller_id);

-- ================================================================
-- PART 3: TRIGGERS & FUNCTIONS
-- ================================================================

-- Trigger function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at
DROP TRIGGER IF EXISTS update_sellers_updated_at ON sellers;
CREATE TRIGGER update_sellers_updated_at
  BEFORE UPDATE ON sellers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_products_updated_at ON products;
CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_categories_updated_at ON categories;
CREATE TRIGGER update_categories_updated_at
  BEFORE UPDATE ON categories
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_subcategories_updated_at ON subcategories;
CREATE TRIGGER update_subcategories_updated_at
  BEFORE UPDATE ON subcategories
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_brands_updated_at ON brands;
CREATE TRIGGER update_brands_updated_at
  BEFORE UPDATE ON brands
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ================================================================
-- PART 4: HELPER FUNCTIONS
-- ================================================================

-- Get seller product count
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

-- Get low stock products
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

-- Get product rating
CREATE OR REPLACE FUNCTION get_product_rating(product_asin TEXT)
RETURNS TABLE (
  average_rating DECIMAL,
  total_reviews INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(AVG(rating), 0)::DECIMAL as average_rating,
    COUNT(*)::INTEGER as total_reviews
  FROM reviews
  WHERE asin = product_asin;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- PART 5: SEED DATA (Optional)
-- ================================================================

-- Insert default categories
INSERT INTO categories (name, description, sort_order) VALUES
  ('Fashion & Apparel', 'Clothing, shoes, and accessories', 1),
  ('Electronics', 'Phones, laptops, and gadgets', 2),
  ('Lighting & Electrical', 'Light bulbs, lamps, and wiring', 3),
  ('Home & Living', 'Furniture and home decor', 4),
  ('Beauty & Personal Care', 'Skincare, makeup, and fragrance', 5),
  ('Sports & Outdoors', 'Gym equipment and outdoor gear', 6)
ON CONFLICT (name) DO NOTHING;

-- Insert subcategories with attribute schemas
-- Fashion & Apparel > T-Shirts
INSERT INTO subcategories (category_id, name, attribute_schema) 
SELECT 
  c.id,
  'T-Shirts',
  '{
    "required": ["size", "material"],
    "optional": ["fit", "color"],
    "fields": {
      "size": {"type": "dropdown", "options": ["S", "M", "L", "XL", "XXL"]},
      "material": {"type": "text"},
      "fit": {"type": "dropdown", "options": ["Slim", "Regular", "Oversize"]},
      "color": {"type": "text"}
    }
  }'::jsonb
FROM categories c 
WHERE c.name = 'Fashion & Apparel'
ON CONFLICT DO NOTHING;

-- Electronics > Smartphones
INSERT INTO subcategories (category_id, name, attribute_schema) 
SELECT 
  c.id,
  'Smartphones',
  '{
    "required": ["storage", "ram"],
    "optional": ["color", "condition_details"],
    "fields": {
      "storage": {"type": "dropdown", "options": ["64", "128", "256", "512", "1024"]},
      "ram": {"type": "dropdown", "options": ["4", "6", "8", "12", "16"]},
      "color": {"type": "text"},
      "condition_details": {"type": "text"}
    }
  }'::jsonb
FROM categories c 
WHERE c.name = 'Electronics'
ON CONFLICT DO NOTHING;

-- Insert sample brands
INSERT INTO brands (name, category, is_verified, is_active) VALUES
  ('Apple', 'Electronics', true, true),
  ('Samsung', 'Electronics', true, true),
  ('Nike', 'Fashion & Apparel', true, true),
  ('Adidas', 'Fashion & Apparel', true, true),
  ('Sony', 'Electronics', true, true),
  ('Philips', 'Lighting & Electrical', true, true)
ON CONFLICT ON CONSTRAINT idx_brands_name_category_unique DO NOTHING;

-- ================================================================
-- PART 6: VERIFICATION QUERIES
-- ================================================================

-- Run these to verify setup:

-- Check tables
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

-- Check storage bucket
-- SELECT id, name, public FROM storage.buckets;

-- Check RLS policies
-- SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public';

-- Check indexes
-- SELECT indexname, tablename FROM pg_indexes WHERE schemaname = 'public';

-- ================================================================
-- SETUP COMPLETE! ✓
-- ================================================================
-- Next steps:
-- 1. Deploy Edge Functions: cd supabase && supabase functions deploy
-- 2. Set environment secrets: supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_key
-- 3. Test in Flutter app
-- ================================================================
