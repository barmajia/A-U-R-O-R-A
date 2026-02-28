-- ================================================================
-- AURORA E-COMMERCE - SUPABASE DATABASE SCHEMA
-- ================================================================
-- Run this in Supabase SQL Editor to set up all tables and policies
-- ================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================================
-- SELLERS TABLE
-- ================================================================

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

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_sellers_user_id ON sellers(user_id);
CREATE INDEX IF NOT EXISTS idx_sellers_email ON sellers(email);
CREATE INDEX IF NOT EXISTS idx_sellers_account_type ON sellers(account_type);
CREATE INDEX IF NOT EXISTS idx_sellers_is_verified ON sellers(is_verified);
CREATE INDEX IF NOT EXISTS idx_sellers_last_login ON sellers(last_login);

-- Enable Row Level Security
ALTER TABLE sellers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
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

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-update updated_at
CREATE TRIGGER update_sellers_updated_at
  BEFORE UPDATE ON sellers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ================================================================
-- USERS TABLE (Optional - for additional user data)
-- ================================================================

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  email TEXT NOT NULL,
  full_name TEXT,
  phone TEXT,
  avatar_url TEXT,
  account_type TEXT DEFAULT 'user',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_user_id ON users(user_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth.uid() = user_id);

-- ================================================================
-- EDGE FUNCTIONS TRIGGER (Optional)
-- ================================================================

-- Create function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert into users table
  INSERT INTO public.users (
    user_id,
    email,
    full_name,
    phone,
    account_type
  ) VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'phone',
    COALESCE(NEW.raw_user_meta_data->>'account_type', 'user')
  );
  
  -- If seller, also create seller record
  IF NEW.raw_user_meta_data->>'account_type' = 'seller' THEN
    INSERT INTO public.sellers (
      user_id,
      email,
      full_name,
      phone,
      location,
      currency,
      account_type,
      is_verified
    ) VALUES (
      NEW.id,
      NEW.email,
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'phone',
      NEW.raw_user_meta_data->>'location',
      COALESCE(NEW.raw_user_meta_data->>'currency', 'USD'),
      'seller',
      FALSE
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to auto-create profiles on user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ================================================================
-- GRANT PERMISSIONS
-- ================================================================

GRANT ALL ON sellers TO authenticated;
GRANT SELECT ON sellers TO anon;
GRANT ALL ON users TO authenticated;
GRANT SELECT ON users TO anon;

-- ================================================================
-- VERIFICATION
-- ================================================================

-- Check if tables were created
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

-- Check if indexes were created
-- SELECT indexname FROM pg_indexes WHERE schemaname = 'public';

-- Check if policies were created
-- SELECT policyname FROM pg_policies WHERE schemaname = 'public';
