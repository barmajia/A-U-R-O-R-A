-- Fix sellers table schema
-- Add missing account_type column if it doesn't exist

-- First, let's check and add the column
ALTER TABLE sellers ADD COLUMN IF NOT EXISTS account_type TEXT DEFAULT 'seller';

-- Also add updated_at if missing
ALTER TABLE sellers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_sellers_account_type ON sellers(account_type);

-- Verify the table structure
-- SELECT column_name, data_type, column_default 
-- FROM information_schema.columns 
-- WHERE table_name = 'sellers' 
-- ORDER BY ordinal_position;
