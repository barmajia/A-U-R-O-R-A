-- Create bills table for factory-seller transactions
CREATE TABLE IF NOT EXISTS public.bills (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    seller_id uuid NOT NULL REFERENCES sellers(user_id) ON DELETE CASCADE,
    factory_id uuid NOT NULL REFERENCES sellers(user_id) ON DELETE CASCADE,
    customer_id uuid NOT NULL,
    customer_name text NOT NULL,
    items jsonb NOT NULL DEFAULT '[]'::jsonb,
    subtotal numeric(12,2) DEFAULT 0.00,
    tax numeric(12,2) DEFAULT 0.00,
    discount numeric(12,2) DEFAULT 0.00,
    total numeric(12,2) NOT NULL,
    payment_status text DEFAULT 'pending' CHECK (payment_status IN ('paid', 'pending', 'partial')),
    payment_method text DEFAULT 'cash' CHECK (payment_method IN ('cash', 'card', 'transfer')),
    notes text,
    status text DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
    items_count integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_bills_seller_id ON bills(seller_id);
CREATE INDEX IF NOT EXISTS idx_bills_factory_id ON bills(factory_id);
CREATE INDEX IF NOT EXISTS idx_bills_payment_status ON bills(payment_status);
CREATE INDEX IF NOT EXISTS idx_bills_created_at ON bills(created_at);

-- Add trigger to update updated_at
CREATE OR REPLACE FUNCTION update_bills_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_bills_timestamp
BEFORE UPDATE ON bills
FOR EACH ROW
EXECUTE FUNCTION update_bills_timestamp();

-- Add RLS policies
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;

-- Factories can view their own bills
CREATE POLICY factories_view_own_bills ON bills
    FOR SELECT
    USING (auth.uid() = factory_id);

-- Factories can insert their own bills
CREATE POLICY factories_insert_own_bills ON bills
    FOR INSERT
    WITH CHECK (auth.uid() = factory_id);

-- Sellers can view bills where they are the seller
CREATE POLICY sellers_view_own_bills ON bills
    FOR SELECT
    USING (auth.uid() = seller_id);

-- Allow authenticated users to view bills they're involved in
CREATE POLICY users_view_involved_bills ON bills
    FOR SELECT
    USING (auth.uid() = factory_id OR auth.uid() = seller_id);
