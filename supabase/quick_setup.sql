-- ================================================================
-- QUICK SETUP SCRIPT - Run this in Supabase SQL Editor
-- ================================================================
-- This will set up your database schema in one click
-- Copy all content below and paste in: 
-- https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/sql/new
-- ================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create sellers table if not exists
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

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_sellers_user_id ON sellers(user_id);
CREATE INDEX IF NOT EXISTS idx_sellers_email ON sellers(email);
CREATE INDEX IF NOT EXISTS idx_sellers_account_type ON sellers(account_type);
CREATE INDEX IF NOT EXISTS idx_sellers_is_verified ON sellers(is_verified);
CREATE INDEX IF NOT EXISTS idx_sellers_last_login ON sellers(last_login);

-- Enable RLS
ALTER TABLE sellers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own seller profile" ON sellers;
DROP POLICY IF EXISTS "Users can update own seller profile" ON sellers;
DROP POLICY IF EXISTS "Users can insert own seller profile" ON sellers;
DROP POLICY IF EXISTS "Anyone can view verified sellers" ON sellers;

-- Create policies
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

-- Update trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_sellers_updated_at
  BEFORE UPDATE ON sellers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions
GRANT ALL ON sellers TO authenticated;
GRANT SELECT ON sellers TO anon;

-- ================================================================
-- VERIFICATION QUERIES
-- ================================================================
-- Run these to verify setup:

-- Check table exists
-- SELECT table_name FROM information_schema.tables 
-- WHERE table_schema = 'public' AND table_name = 'sellers';

-- Check policies
-- SELECT policyname FROM pg_policies WHERE tablename = 'sellers';

-- Check indexes
-- SELECT indexname FROM pg_indexes WHERE tablename = 'sellers';

-- ================================================================
-- SETUP COMPLETE! ✓
-- ================================================================
