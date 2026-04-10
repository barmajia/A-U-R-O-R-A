-- ============================================================================
-- FACTORY SUPPORT MIGRATION: Add factory account type support to sellers table
-- ============================================================================
-- This migration adds proper support for factory accounts in the sellers table
-- Version: 1.0.0
-- Date: 2026-03-17
-- ============================================================================

-- Step 1: Ensure sellers table has all factory-related columns
-- (Most should already exist from factory_discovery_system migration)

-- Add is_factory column if it doesn't exist
ALTER TABLE sellers
ADD COLUMN IF NOT EXISTS is_factory BOOLEAN DEFAULT false;

-- Add factory-specific columns if they don't exist
ALTER TABLE sellers
ADD COLUMN IF NOT EXISTS factory_license_url TEXT,
ADD COLUMN IF NOT EXISTS min_order_quantity INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS wholesale_discount NUMERIC(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS accepts_returns BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS production_capacity TEXT,
ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

-- Add location coordinates if they don't exist
ALTER TABLE sellers
ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8),
ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8);

-- Step 2: Create index for factory queries
CREATE INDEX IF NOT EXISTS idx_sellers_is_factory ON sellers(is_factory) 
  WHERE is_factory = true;

CREATE INDEX IF NOT EXISTS idx_sellers_location ON sellers(latitude, longitude)
  WHERE is_factory = true;

-- Step 3: Update RLS policies to support factories
-- Drop old policies if they exist
DROP POLICY IF EXISTS "Users can view own seller profile" ON sellers;
DROP POLICY IF EXISTS "Users can update own seller profile" ON sellers;
DROP POLICY IF EXISTS "Users can insert own seller profile" ON sellers;
DROP POLICY IF EXISTS "Anyone can view verified sellers" ON sellers;

-- Recreate policies that work for both sellers and factories
CREATE POLICY "Users can view own profile"
  ON sellers FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
  ON sellers FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
  ON sellers FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Anyone can view verified sellers and factories"
  ON sellers FOR SELECT
  USING (is_verified = TRUE OR is_factory = TRUE);

-- Step 4: Update handle_new_user function to support factories
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Get account_type from metadata
  DECLARE
    v_account_type TEXT;
  BEGIN
    v_account_type := NEW.raw_user_meta_data->>'account_type';
  END;

  -- Insert into sellers table for seller or factory accounts
  IF v_account_type IN ('seller', 'factory') THEN
    INSERT INTO public.sellers (
      user_id,
      email,
      full_name,
      phone,
      location,
      currency,
      account_type,
      is_verified,
      is_factory,
      created_at,
      updated_at
    ) VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
      NEW.raw_user_meta_data->>'phone',
      NEW.raw_user_meta_data->>'location',
      COALESCE(NEW.raw_user_meta_data->>'currency', 'USD'),
      v_account_type,
      FALSE,
      (v_account_type = 'factory'), -- Set is_factory based on account_type
      NOW(),
      NOW()
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Create factory_connections table if it doesn't exist
CREATE TABLE IF NOT EXISTS factory_connections (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  factory_id UUID REFERENCES sellers(user_id) ON DELETE CASCADE,
  seller_id UUID REFERENCES sellers(user_id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'blocked')),
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  rejected_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(factory_id, seller_id)
);

-- Step 6: Create factory_ratings table if it doesn't exist
CREATE TABLE IF NOT EXISTS factory_ratings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  factory_id UUID REFERENCES sellers(user_id) ON DELETE CASCADE,
  seller_id UUID REFERENCES sellers(user_id) ON DELETE CASCADE,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  review TEXT,
  delivery_rating INTEGER CHECK (delivery_rating >= 1 AND delivery_rating <= 5),
  quality_rating INTEGER CHECK (quality_rating >= 1 AND quality_rating <= 5),
  communication_rating INTEGER CHECK (communication_rating >= 1 AND communication_rating <= 5),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(factory_id, seller_id)
);

-- Step 7: Enable RLS on factory tables
ALTER TABLE factory_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE factory_ratings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "sellers_view_own_factory_connections" ON factory_connections;
DROP POLICY IF EXISTS "sellers_create_factory_connections" ON factory_connections;
DROP POLICY IF EXISTS "factories_update_own_connections" ON factory_connections;
DROP POLICY IF EXISTS "anyone_view_factory_ratings" ON factory_ratings;
DROP POLICY IF EXISTS "sellers_create_factory_ratings" ON factory_ratings;

-- Create policies for factory_connections
CREATE POLICY "Users can view own factory connections"
  ON factory_connections FOR SELECT
  TO authenticated
  USING (seller_id = auth.uid() OR factory_id = auth.uid());

CREATE POLICY "Users can create factory connection requests"
  ON factory_connections FOR INSERT
  TO authenticated
  WITH CHECK (seller_id = auth.uid());

CREATE POLICY "Factories can update own connections"
  ON factory_connections FOR UPDATE
  TO authenticated
  USING (factory_id = auth.uid())
  WITH CHECK (factory_id = auth.uid());

-- Create policies for factory_ratings
CREATE POLICY "Anyone can view factory ratings"
  ON factory_ratings FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Sellers can create factory ratings"
  ON factory_ratings FOR INSERT
  TO authenticated
  WITH CHECK (seller_id = auth.uid());

-- Step 8: Create trigger for updating timestamps
CREATE OR REPLACE FUNCTION update_sellers_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_sellers_updated_at ON sellers;

CREATE TRIGGER update_sellers_updated_at
  BEFORE UPDATE ON sellers
  FOR EACH ROW
  EXECUTE FUNCTION update_sellers_timestamp();

-- Step 9: Grant permissions
GRANT ALL ON TABLE sellers TO authenticated;
GRANT SELECT ON TABLE sellers TO anon;
GRANT ALL ON TABLE factory_connections TO authenticated;
GRANT ALL ON TABLE factory_ratings TO authenticated;
GRANT ALL ON FUNCTION public.handle_new_user() TO authenticated;

-- Step 10: Verification query
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'sellers' 
  AND column_name IN (
    'user_id', 'is_factory', 'factory_license_url', 
    'min_order_quantity', 'wholesale_discount', 'production_capacity',
    'latitude', 'longitude'
  )
ORDER BY column_name;

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
