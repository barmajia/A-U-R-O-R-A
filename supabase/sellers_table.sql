-- Create sellers table
CREATE TABLE IF NOT EXISTS sellers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  location TEXT,
  currency TEXT DEFAULT 'USD',
  account_type TEXT DEFAULT 'seller',
  is_verified BOOLEAN DEFAULT FALSE,
  store_name TEXT,
  store_description TEXT,
  logo_url TEXT,
  banner_url TEXT,
  tax_number TEXT,
  commercial_registration TEXT,
  rating DECIMAL DEFAULT 0.0,
  total_sales INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_sellers_user_id ON sellers(user_id);
CREATE INDEX IF NOT EXISTS idx_sellers_email ON sellers(email);
CREATE INDEX IF NOT EXISTS idx_sellers_account_type ON sellers(account_type);
CREATE INDEX IF NOT EXISTS idx_sellers_is_verified ON sellers(is_verified);

-- Enable Row Level Security (RLS)
ALTER TABLE sellers ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Policy: Users can view their own seller profile
CREATE POLICY "Users can view own seller profile"
  ON sellers FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can update their own seller profile
CREATE POLICY "Users can update own seller profile"
  ON sellers FOR UPDATE
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own seller profile (on signup)
CREATE POLICY "Users can insert own seller profile"
  ON sellers FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Anyone can view verified seller public info
CREATE POLICY "Anyone can view verified sellers"
  ON sellers FOR SELECT
  USING (is_verified = TRUE);

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

-- Create function to create seller profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert into sellers table if account_type is 'seller'
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

-- Create trigger to auto-create seller profile on user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Grant permissions
GRANT ALL ON sellers TO authenticated;
GRANT SELECT ON sellers TO anon;
