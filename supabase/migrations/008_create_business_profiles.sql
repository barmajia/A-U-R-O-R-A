-- Migration: 008_create_business_profiles.sql
-- Created: 2026-03-14
-- Purpose: Create business_profiles table for nearby chat and factory discovery
-- Status: PENDING DEPLOYMENT

-- ============================================================================
-- BUSINESS PROFILES TABLE
-- ============================================================================

-- Drop existing table if it exists (for clean deployment)
DROP TABLE IF EXISTS public.business_profiles CASCADE;

CREATE TABLE public.business_profiles (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- User reference (links to auth.users)
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Business information
    business_name TEXT NOT NULL,
    business_type TEXT NOT NULL CHECK (business_type IN ('seller', 'factory', 'distributor', 'wholesaler')),
    business_description TEXT,
    
    -- Business location
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    address TEXT,
    city TEXT,
    country TEXT DEFAULT 'Egypt',
    postal_code TEXT,
    
    -- Contact information
    phone TEXT,
    email TEXT,
    website TEXT,
    
    -- Business hours (JSON format for flexibility)
    business_hours JSONB DEFAULT '{"monday": {"open": "09:00", "close": "17:00"}, "tuesday": {"open": "09:00", "close": "17:00"}, "wednesday": {"open": "09:00", "close": "17:00"}, "thursday": {"open": "09:00", "close": "17:00"}, "friday": {"open": "09:00", "close": "17:00"}, "saturday": {"open": "09:00", "close": "17:00"}, "sunday": null}'::jsonb,
    
    -- Verification and ratings
    is_verified BOOLEAN DEFAULT FALSE,
    verification_documents TEXT[], -- Array of document URLs
    rating DECIMAL(3, 2) DEFAULT 0.00 CHECK (rating >= 0 AND rating <= 5),
    total_reviews INTEGER DEFAULT 0,
    
    -- Capabilities (for factories)
    capabilities TEXT[], -- e.g., ['metalworking', 'assembly', 'packaging']
    minimum_order_quantity INTEGER DEFAULT 1,
    production_capacity TEXT, -- e.g., "1000 units/month"
    
    -- Social proof
    total_products INTEGER DEFAULT 0,
    total_sales INTEGER DEFAULT 0,
    years_in_business INTEGER,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_online BOOLEAN DEFAULT FALSE,
    last_seen_at TIMESTAMPTZ,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT unique_user_business_profile UNIQUE (user_id),
    CONSTRAINT valid_rating CHECK (rating >= 0 AND rating <= 5)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Index for location-based queries (nearby businesses)
CREATE INDEX idx_business_profiles_location ON public.business_profiles USING GIST (latitude, longitude);

-- Index for business type filtering
CREATE INDEX idx_business_profiles_type ON public.business_profiles(business_type);

-- Index for active businesses
CREATE INDEX idx_business_profiles_active ON public.business_profiles(is_active);

-- Index for verified businesses
CREATE INDEX idx_business_profiles_verified ON public.business_profiles(is_verified);

-- Index for online status
CREATE INDEX idx_business_profiles_online ON public.business_profiles(is_online);

-- Index for user_id lookups
CREATE INDEX idx_business_profiles_user_id ON public.business_profiles(user_id);

-- Composite index for nearby active businesses
CREATE INDEX idx_business_profiles_nearby_active ON public.business_profiles(is_active, latitude, longitude);

-- ============================================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_business_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER update_business_profiles_timestamp
    BEFORE UPDATE ON public.business_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_business_profiles_updated_at();

-- Function to update business profile location from user location
CREATE OR REPLACE FUNCTION public.update_business_profile_location()
RETURNS TRIGGER AS $$
BEGIN
    -- Update business profile when seller profile location changes
    UPDATE public.business_profiles
    SET 
        latitude = NEW.latitude,
        longitude = NEW.longitude,
        updated_at = NOW()
    WHERE user_id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS
ALTER TABLE public.business_profiles ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

-- Policy: Anyone can read active business profiles
CREATE POLICY "Anyone can read active business profiles"
    ON public.business_profiles
    FOR SELECT
    USING (is_active = TRUE);

-- Policy: Users can read their own profile
CREATE POLICY "Users can read own profile"
    ON public.business_profiles
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can insert their own profile
CREATE POLICY "Users can insert own profile"
    ON public.business_profiles
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON public.business_profiles
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own profile
CREATE POLICY "Users can delete own profile"
    ON public.business_profiles
    FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE public.business_profiles IS 'Business profiles for sellers, factories, and distributors with location-based discovery';
COMMENT ON COLUMN public.business_profiles.business_type IS 'Type of business: seller, factory, distributor, or wholesaler';
COMMENT ON COLUMN public.business_profiles.capabilities IS 'Array of manufacturing or service capabilities (for factories)';
COMMENT ON COLUMN public.business_profiles.business_hours IS 'JSON object defining operating hours for each day of the week';
COMMENT ON COLUMN public.business_profiles.is_online IS 'Real-time online status for chat availability';

-- ============================================================================
-- SEED DATA (OPTIONAL - FOR TESTING)
-- ============================================================================

-- Uncomment to insert test data
-- INSERT INTO public.business_profiles (user_id, business_name, business_type, business_description, latitude, longitude, city, country)
-- VALUES 
--     ('00000000-0000-0000-0000-000000000001', 'Cairo Electronics', 'seller', 'Electronics and gadgets retailer', 30.0444, 31.2357, 'Cairo', 'Egypt'),
--     ('00000000-0000-0000-0000-000000000002', 'Alexandria Manufacturing', 'factory', 'Metal fabrication and assembly', 31.2001, 29.9187, 'Alexandria', 'Egypt');

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
