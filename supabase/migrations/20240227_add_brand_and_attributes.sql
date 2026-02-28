-- ============================================================
-- Aurora E-commerce Database Migration
-- Add Brand and Attributes Support to Products Table
-- ============================================================

-- Add new columns to products table
ALTER TABLE products 
ADD COLUMN brand_id TEXT,
ADD COLUMN is_local_brand BOOLEAN DEFAULT false,
ADD COLUMN attributes JSONB,
ADD COLUMN color_hex TEXT;

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_products_brand_id ON products(brand_id);
CREATE INDEX IF NOT EXISTS idx_products_is_local_brand ON products(is_local_brand);
CREATE INDEX IF NOT EXISTS idx_products_attributes ON products USING GIN(attributes);

-- Add comments for documentation
COMMENT ON COLUMN products.brand_id IS 'Brand ID for predefined brands (null for local brands)';
COMMENT ON COLUMN products.is_local_brand IS 'Flag to identify custom/local brands';
COMMENT ON COLUMN products.attributes IS 'JSONB field for dynamic product attributes (size, color, material, etc.)';
COMMENT ON COLUMN products.color_hex IS 'Hex color code for the product';

-- Create view for products with brand information (optional, for easier querying)
CREATE OR REPLACE VIEW products_with_brands AS
SELECT 
  p.*,
  CASE 
    WHEN p.is_local_brand THEN p.content->>'brand'
    ELSE b.name
  END as brand_name
FROM products p
LEFT JOIN brands b ON p.brand_id = b.id;

-- Grant permissions (adjust role names as needed)
GRANT ALL ON products TO authenticated;
GRANT ALL ON products_with_brands TO authenticated;

-- ============================================================
-- Rollback (if needed)
-- ============================================================
-- To rollback this migration, run:
-- DROP VIEW IF EXISTS products_with_brands;
-- ALTER TABLE products DROP COLUMN IF EXISTS brand_id;
-- ALTER TABLE products DROP COLUMN IF EXISTS is_local_brand;
-- ALTER TABLE products DROP COLUMN IF EXISTS attributes;
-- ALTER TABLE products DROP COLUMN IF EXISTS color_hex;
