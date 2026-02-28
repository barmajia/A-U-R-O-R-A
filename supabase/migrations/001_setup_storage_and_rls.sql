-- ==============================================================================
-- Aurora E-Commerce: Supabase Database Migration
-- ==============================================================================
-- This script sets up:
-- 1. Storage bucket for product images
-- 2. Row Level Security (RLS) policies
-- 3. Proper permissions for authenticated users
--
-- Run this in Supabase SQL Editor: https://app.supabase.com/project/_/sql
-- ==============================================================================

-- ==============================================================================
-- PART 1: STORAGE BUCKET
-- ==============================================================================

-- Create product-images bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  true,  -- Public bucket (images accessible via URL)
  52428800,  -- 50MB file size limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- PART 2: ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can manage own product images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view all product images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload images" ON storage.objects;

-- Policy 1: Users can manage (upload/delete) their own product images
-- Images are stored in folders named by seller_id
CREATE POLICY "Users can manage own product images"
ON storage.objects FOR ALL TO authenticated
USING (
  bucket_id = 'product-images' 
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'product-images' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 2: Anyone can view product images (public read access)
CREATE POLICY "Users can view all product images"
ON storage.objects FOR SELECT TO authenticated, anon
USING (bucket_id = 'product-images');

-- ==============================================================================
-- PART 3: PRODUCTS TABLE RLS
-- ==============================================================================

-- Enable RLS on products table
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can create own products" ON products;
DROP POLICY IF EXISTS "Users can update own products" ON products;
DROP POLICY IF EXISTS "Users can delete own products" ON products;
DROP POLICY IF EXISTS "Users can view own products" ON products;
DROP POLICY IF EXISTS "Public can view active products" ON products;

-- Policy 1: Sellers can create their own products
CREATE POLICY "Users can create own products"
ON products FOR INSERT TO authenticated
WITH CHECK (seller_id = auth.uid()::text);

-- Policy 2: Sellers can update their own products
CREATE POLICY "Users can update own products"
ON products FOR UPDATE TO authenticated
USING (seller_id = auth.uid()::text)
WITH CHECK (seller_id = auth.uid()::text);

-- Policy 3: Sellers can delete their own products
CREATE POLICY "Users can delete own products"
ON products FOR DELETE TO authenticated
USING (seller_id = auth.uid()::text);

-- Policy 4: Sellers can view their own products
CREATE POLICY "Users can view own products"
ON products FOR SELECT TO authenticated
USING (seller_id = auth.uid()::text);

-- Policy 5: Public can view active products (for marketplace browsing)
CREATE POLICY "Public can view active products"
ON products FOR SELECT TO anon, authenticated
USING (status = 'active');

-- ==============================================================================
-- PART 4: ADDITIONAL HELPER FUNCTIONS
-- ==============================================================================

-- Function to get current seller ID
CREATE OR REPLACE FUNCTION get_current_seller_id()
RETURNS TEXT AS $$
BEGIN
  RETURN auth.uid()::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is seller
CREATE OR REPLACE FUNCTION is_seller()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM sellers
    WHERE sellers.user_id = auth.uid()::text
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- PART 5: INDEXES FOR PERFORMANCE
-- ==============================================================================

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_products_seller_id ON products(seller_id);
CREATE INDEX IF NOT EXISTS idx_products_status ON products(status);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_subcategory ON products(subcategory);
CREATE INDEX IF NOT EXISTS idx_products_created_at ON products(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_products_asin ON products(asin);

-- Index for storage objects by seller
CREATE INDEX IF NOT EXISTS idx_storage_bucket_folder 
ON storage.objects(bucket_id, (storage.foldername(name)));

-- ==============================================================================
-- PART 6: VERIFICATION
-- ==============================================================================

-- Verify bucket was created
SELECT 'Storage Bucket Created' as status, id, name, public 
FROM storage.buckets 
WHERE id = 'product-images';

-- Verify RLS policies
SELECT 'RLS Policies on storage.objects' as status, policyname 
FROM pg_policies 
WHERE tablename = 'objects' AND schemaname = 'storage';

SELECT 'RLS Policies on products' as status, policyname 
FROM pg_policies 
WHERE tablename = 'products';

-- ==============================================================================
-- MIGRATION COMPLETE
-- ==============================================================================
-- 
-- Next Steps:
-- 1. Verify bucket exists in Supabase Dashboard → Storage
-- 2. Deploy Edge Functions using: .\deploy-functions.bat
-- 3. Test product creation with image upload
-- 4. Monitor logs for any errors
--
-- ==============================================================================
