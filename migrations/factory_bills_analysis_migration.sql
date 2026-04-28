-- ================================================================
-- Factory Bills & Analysis Storage Migration
-- ================================================================
-- This migration creates:
-- 1. Bills table for factory-seller transactions
-- 2. Storage buckets for bills and analysis JSON files
-- 3. RLS policies for security
-- ================================================================

-- ================================================================
-- 1. Create Bills Table
-- ================================================================

CREATE TABLE IF NOT EXISTS bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    factory_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL,
    customer_name TEXT NOT NULL,
    
    -- Bill items as JSON array
    items JSONB NOT NULL DEFAULT '[]',
    
    -- Financial fields
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    tax DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    discount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    
    -- Payment information
    payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('paid', 'pending', 'partial')),
    payment_method TEXT NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash', 'card', 'transfer')),
    
    -- Additional metadata
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
    items_count INTEGER NOT NULL DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_bills_factory_id ON bills(factory_id);
CREATE INDEX IF NOT EXISTS idx_bills_seller_id ON bills(seller_id);
CREATE INDEX IF NOT EXISTS idx_bills_customer_id ON bills(customer_id);
CREATE INDEX IF NOT EXISTS idx_bills_created_at ON bills(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bills_payment_status ON bills(payment_status);
CREATE INDEX IF NOT EXISTS idx_bills_status ON bills(status);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_bills_factory_created ON bills(factory_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bills_seller_created ON bills(seller_id, created_at DESC);

-- ================================================================
-- 2. Create Storage Buckets
-- ================================================================

-- Note: Bucket creation typically requires admin privileges
-- These commands may need to be run via Supabase Dashboard or API

-- Insert bucket records if they don't exist
INSERT INTO storage.buckets (id, name, public, allowed_mime_types, file_size_limit)
VALUES 
    ('factory-bills', 'factory-bills', true, ARRAY['application/json'], 10485760),
    ('factory-analysis', 'factory-analysis', true, ARRAY['application/json'], 10485760)
ON CONFLICT (id) DO NOTHING;

-- ================================================================
-- 3. Row Level Security (RLS) Policies
-- ================================================================

-- Enable RLS on bills table
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;

-- Policy: Factories can view their own bills
CREATE POLICY "Factories can view their bills"
    ON bills
    FOR SELECT
    USING (
        factory_id = auth.uid() 
        OR EXISTS (
            SELECT 1 FROM sellers 
            WHERE sellers.user_id = auth.uid() 
            AND sellers.is_factory = true
        )
    );

-- Policy: Factories can insert bills
CREATE POLICY "Factories can insert bills"
    ON bills
    FOR INSERT
    WITH CHECK (
        factory_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM sellers 
            WHERE sellers.user_id = auth.uid() 
            AND sellers.is_factory = true
        )
    );

-- Policy: Factories can update their own bills
CREATE POLICY "Factories can update their bills"
    ON bills
    FOR UPDATE
    USING (
        factory_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM sellers 
            WHERE sellers.user_id = auth.uid() 
            AND sellers.is_factory = true
        )
    );

-- Policy: Sellers can view bills where they are the customer
CREATE POLICY "Sellers can view their bills"
    ON bills
    FOR SELECT
    USING (
        seller_id = auth.uid()
        OR customer_id = auth.uid()
    );

-- ================================================================
-- 4. Storage Bucket Policies
-- ================================================================

-- Factory Bills Bucket Policies
DO $$
BEGIN
    -- Enable public read access to factory-bills bucket
    IF NOT EXISTS (
        SELECT 1 FROM storage.policies 
        WHERE object_name = 'factory-bills' 
        AND operation = 'SELECT'
    ) THEN
        CREATE POLICY "Public Access to Factory Bills"
            ON storage.objects FOR SELECT
            USING (bucket_id = 'factory-bills');
    END IF;

    -- Allow authenticated users to upload to their factory folder
    IF NOT EXISTS (
        SELECT 1 FROM storage.policies 
        WHERE object_name = 'factory-bills' 
        AND operation = 'INSERT'
    ) THEN
        CREATE POLICY "Factory Users Can Upload Bills"
            ON storage.objects FOR INSERT
            WITH CHECK (
                bucket_id = 'factory-bills'
                AND auth.uid()::text = (storage.foldername(name))[1]
            );
    END IF;

    -- Allow users to delete their own files
    IF NOT EXISTS (
        SELECT 1 FROM storage.policies 
        WHERE object_name = 'factory-bills' 
        AND operation = 'DELETE'
    ) THEN
        CREATE POLICY "Factory Users Can Delete Their Bills"
            ON storage.objects FOR DELETE
            USING (
                bucket_id = 'factory-bills'
                AND auth.uid()::text = (storage.foldername(name))[1]
            );
    END IF;
END $$;

-- Factory Analysis Bucket Policies
DO $$
BEGIN
    -- Enable public read access to factory-analysis bucket
    IF NOT EXISTS (
        SELECT 1 FROM storage.policies 
        WHERE object_name = 'factory-analysis' 
        AND operation = 'SELECT'
    ) THEN
        CREATE POLICY "Public Access to Factory Analysis"
            ON storage.objects FOR SELECT
            USING (bucket_id = 'factory-analysis');
    END IF;

    -- Allow authenticated users to upload to their factory folder
    IF NOT EXISTS (
        SELECT 1 FROM storage.policies 
        WHERE object_name = 'factory-analysis' 
        AND operation = 'INSERT'
    ) THEN
        CREATE POLICY "Factory Users Can Upload Analysis"
            ON storage.objects FOR INSERT
            WITH CHECK (
                bucket_id = 'factory-analysis'
                AND auth.uid()::text = (storage.foldername(name))[1]
            );
    END IF;

    -- Allow users to delete their own files
    IF NOT EXISTS (
        SELECT 1 FROM storage.policies 
        WHERE object_name = 'factory-analysis' 
        AND operation = 'DELETE'
    ) THEN
        CREATE POLICY "Factory Users Can Delete Their Analysis"
            ON storage.objects FOR DELETE
            USING (
                bucket_id = 'factory-analysis'
                AND auth.uid()::text = (storage.foldername(name))[1]
            );
    END IF;
END $$;

-- ================================================================
-- 5. Trigger for updated_at timestamp
-- ================================================================

-- Create or replace function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS update_bills_updated_at ON bills;

CREATE TRIGGER update_bills_updated_at
    BEFORE UPDATE ON bills
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ================================================================
-- 6. Comments for documentation
-- ================================================================

COMMENT ON TABLE bills IS 'Stores bill transactions between factories and sellers';
COMMENT ON COLUMN bills.id IS 'Unique identifier for the bill';
COMMENT ON COLUMN bills.seller_id IS 'Reference to the seller (customer) user ID';
COMMENT ON COLUMN bills.factory_id IS 'Reference to the factory user ID';
COMMENT ON COLUMN bills.customer_id IS 'Customer/seller user ID for the transaction';
COMMENT ON COLUMN bills.customer_name IS 'Name of the customer/seller';
COMMENT ON COLUMN bills.items IS 'JSON array of bill items with product details';
COMMENT ON COLUMN bills.subtotal IS 'Total before tax and discount';
COMMENT ON COLUMN bills.tax IS 'Tax amount (typically 15%)';
COMMENT ON COLUMN bills.discount IS 'Discount amount applied';
COMMENT ON COLUMN bills.total IS 'Final total after tax and discount';
COMMENT ON COLUMN bills.payment_status IS 'Payment status: paid, pending, or partial';
COMMENT ON COLUMN bills.payment_method IS 'Payment method: cash, card, or transfer';
COMMENT ON COLUMN bills.status IS 'Bill status: pending, completed, or cancelled';
COMMENT ON COLUMN bills.items_count IS 'Number of items in the bill';

-- ================================================================
-- Migration Complete
-- ================================================================
