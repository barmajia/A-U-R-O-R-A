-- ============================================
-- Fix Missing qr_data Column
-- Run this in Supabase SQL Editor
-- ============================================

-- Add qr_data column to products table
ALTER TABLE products
ADD COLUMN IF NOT EXISTS qr_data TEXT;

-- Add description
COMMENT ON COLUMN products.qr_data IS 'JSON-encoded QR code data containing ASIN, SKU, seller_id, URL, and product details';

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_products_qr_data ON products(qr_data) WHERE qr_data IS NOT NULL;

-- Verify the column was added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'products' AND column_name = 'qr_data';
