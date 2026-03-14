-- Migration: Add qr_data column to products table
-- Created: 2026-03-14
-- Purpose: Add QR code data storage for product QR codes

-- Add qr_data column if it doesn't exist
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS qr_data TEXT;

-- Add comment for documentation
COMMENT ON COLUMN products.qr_data IS 'JSON-encoded QR code data containing ASIN, SKU, seller_id, URL, and product details';

-- Create index for faster lookups (optional, can be removed if not needed)
CREATE INDEX IF NOT EXISTS idx_products_qr_data ON products(qr_data) WHERE qr_data IS NOT NULL;
