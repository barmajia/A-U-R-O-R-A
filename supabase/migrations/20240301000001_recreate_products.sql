-- ================================================================
-- AURORA E-COMMERCE - PRODUCTS TABLE WITH CATEGORIES & SUBCATEGORIES
-- ================================================================
-- Complete schema with categories, subcategories, and attribute validation
-- ================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================================
-- CATEGORIES TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  icon TEXT,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_categories_slug ON categories(slug);
CREATE INDEX idx_categories_active ON categories(is_active);

-- ================================================================
-- SUBCATEGORIES TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS subcategories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  icon TEXT,
  description TEXT,
  attribute_schema JSONB, -- Schema for validating attributes
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(category_id, name)
);

CREATE INDEX idx_subcategories_category ON subcategories(category_id);
CREATE INDEX idx_subcategories_slug ON subcategories(slug);

-- ================================================================
-- PRODUCTS TABLE (Enhanced)
-- ================================================================

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asin TEXT NOT NULL UNIQUE,
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  
  -- Basic Information
  title TEXT NOT NULL,
  description TEXT,
  brand TEXT NOT NULL,
  
  -- Categorization
  category TEXT NOT NULL,
  subcategory TEXT NOT NULL,
  
  -- Pricing
  price DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'USD',
  
  -- Inventory
  quantity INTEGER DEFAULT 0,
  
  -- Status
  status TEXT DEFAULT 'draft', -- draft, active, inactive, archived
  
  -- Brand Information
  brand_id UUID,
  is_local_brand BOOLEAN DEFAULT false,
  
  -- Attributes (JSONB for dynamic fields)
  attributes JSONB DEFAULT '{}',
  
  -- Images (JSONB array)
  images JSONB DEFAULT '[]',
  
  -- Color hex code (for fashion/apparel)
  color_hex TEXT,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Full-text search vector
  search_vector tsvector GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(brand, '')), 'C') ||
    setweight(to_tsvector('english', coalesce(category, '')), 'D') ||
    setweight(to_tsvector('english', coalesce(subcategory, '')), 'D')
  ) STORED
);

-- Indexes for performance
CREATE INDEX idx_products_asin ON products(asin);
CREATE INDEX idx_products_seller_id ON products(seller_id);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_subcategory ON products(subcategory);
CREATE INDEX idx_products_brand ON products(brand);
CREATE INDEX idx_products_status ON products(status);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_created_at ON products(created_at DESC);
CREATE INDEX idx_products_search_vector ON products USING GIN(search_vector);
CREATE INDEX idx_products_attributes ON products USING GIN(attributes);

-- ================================================================
-- BRANDS TABLE (Predefined Brands)
-- ================================================================

CREATE TABLE IF NOT EXISTS brands (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  logo_url TEXT,
  description TEXT,
  website TEXT,
  categories TEXT[], -- Array of category names
  is_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_brands_name ON brands(name);
CREATE INDEX idx_brands_slug ON brands(slug);

-- ================================================================
-- ROW LEVEL SECURITY (RLS)
-- ================================================================

-- Enable RLS
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE subcategories ENABLE ROW LEVEL SECURITY;
ALTER TABLE brands ENABLE ROW LEVEL SECURITY;

-- Products Policies
CREATE POLICY "Anyone can view active products"
  ON products FOR SELECT
  USING (status = 'active');

CREATE POLICY "Sellers can insert own products"
  ON products FOR INSERT
  WITH CHECK (auth.uid() = seller_id);

CREATE POLICY "Sellers can update own products"
  ON products FOR UPDATE
  USING (auth.uid() = seller_id);

CREATE POLICY "Sellers can delete own products"
  ON products FOR DELETE
  USING (auth.uid() = seller_id);

-- Categories Policies
CREATE POLICY "Anyone can view active categories"
  ON categories FOR SELECT
  USING (is_active = true);

-- Subcategories Policies
CREATE POLICY "Anyone can view active subcategories"
  ON subcategories FOR SELECT
  USING (is_active = true);

-- Brands Policies
CREATE POLICY "Anyone can view brands"
  ON brands FOR SELECT
  USING (true);

-- ================================================================
-- FUNCTIONS & TRIGGERS
-- ================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_categories_updated_at
  BEFORE UPDATE ON categories
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subcategories_updated_at
  BEFORE UPDATE ON subcategories
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Function to get product by ASIN
CREATE OR REPLACE FUNCTION get_product_by_asin(product_asin TEXT)
RETURNS TABLE (
  id UUID,
  asin TEXT,
  title TEXT,
  description TEXT,
  brand TEXT,
  price DECIMAL,
  quantity INTEGER,
  status TEXT,
  category TEXT,
  subcategory TEXT,
  attributes JSONB,
  images JSONB,
  seller_id UUID,
  created_at TIMESTAMP
) AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.asin, p.title, p.description, p.brand, p.price, 
         p.quantity, p.status, p.category, p.subcategory, 
         p.attributes, p.images, p.seller_id, p.created_at
  FROM products p
  WHERE p.asin = product_asin AND p.status = 'active';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search products
CREATE OR REPLACE FUNCTION search_products(
  search_query TEXT,
  search_category TEXT DEFAULT NULL,
  search_brand TEXT DEFAULT NULL,
  min_price DECIMAL DEFAULT NULL,
  max_price DECIMAL DEFAULT NULL,
  result_limit INTEGER DEFAULT 100,
  result_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  asin TEXT,
  title TEXT,
  price DECIMAL,
  brand TEXT,
  category TEXT,
  subcategory TEXT,
  images JSONB,
  rating DECIMAL,
  created_at TIMESTAMP
) AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.asin, p.title, p.price, p.brand, p.category, 
         p.subcategory, p.images, 
         COALESCE(p.average_rating, 0) as rating,
         p.created_at
  FROM products p
  WHERE p.status = 'active'
    AND (search_query IS NULL OR p.search_vector @@ plainto_tsquery('english', search_query))
    AND (search_category IS NULL OR p.category = search_category)
    AND (search_brand IS NULL OR p.brand = search_brand)
    AND (min_price IS NULL OR p.price >= min_price)
    AND (max_price IS NULL OR p.price <= max_price)
  ORDER BY p.created_at DESC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- SAMPLE DATA
-- ================================================================

-- Insert sample categories
INSERT INTO categories (name, slug, icon, description, sort_order) VALUES
  ('Fashion & Apparel', 'fashion-apparel', '👕', 'Clothing, shoes, and accessories', 1),
  ('Electronics', 'electronics', '💻', 'Phones, laptops, and gadgets', 2),
  ('Home & Living', 'home-living', '🏠', 'Furniture and home decor', 3),
  ('Beauty & Personal Care', 'beauty-care', '💄', 'Skincare, makeup, and fragrance', 4),
  ('Sports & Outdoors', 'sports-outdoors', '⚽', 'Sports equipment and outdoor gear', 5)
ON CONFLICT (slug) DO NOTHING;

-- ================================================================
-- GRANT PERMISSIONS
-- ================================================================

GRANT ALL ON products TO authenticated;
GRANT SELECT ON products TO anon;

GRANT ALL ON categories TO authenticated;
GRANT SELECT ON categories TO anon;

GRANT ALL ON subcategories TO authenticated;
GRANT SELECT ON subcategories TO anon;

GRANT ALL ON brands TO authenticated;
GRANT SELECT ON brands TO anon;

-- ================================================================
-- SETUP COMPLETE! ✓
-- ================================================================
