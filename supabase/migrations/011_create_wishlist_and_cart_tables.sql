-- Migration: 011_create_wishlist_and_cart_tables.sql
-- Created: 2026-03-14
-- Purpose: Create wishlist and shopping cart functionality
-- Status: PENDING DEPLOYMENT

-- ============================================================================
-- WISHLIST TABLE
-- ============================================================================

-- Drop existing table if it exists (for clean deployment)
DROP TABLE IF EXISTS public.wishlist CASCADE;

CREATE TABLE public.wishlist (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- User reference
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Product reference
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    
    -- Priority/interest level
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high')),
    
    -- Notes (optional personal note)
    notes TEXT,
    
    -- Price tracking
    target_price DECIMAL(12, 2), -- User's desired price
    added_at_price DECIMAL(12, 2), -- Price when added to wishlist
    
    -- Notifications
    notify_price_drop BOOLEAN DEFAULT TRUE,
    notify_restock BOOLEAN DEFAULT TRUE,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT unique_user_product_wishlist UNIQUE (user_id, product_id)
);

-- ============================================================================
-- CART TABLE
-- ============================================================================

-- Drop existing table if it exists (for clean deployment)
DROP TABLE IF EXISTS public.cart CASCADE;

CREATE TABLE public.cart (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- User reference
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Product reference
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    
    -- Quantity
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity >= 1),
    
    -- Selected variant (if applicable)
    variant_id UUID, -- Reference to product_variants if exists
    variant_options JSONB, -- e.g., {"size": "L", "color": "red"}
    
    -- Pricing snapshot (to preserve price at time of adding to cart)
    unit_price DECIMAL(12, 2) NOT NULL,
    discount_amount DECIMAL(12, 2) DEFAULT 0,
    
    -- Seller information (for multi-seller cart splitting)
    seller_id UUID REFERENCES auth.users(id),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Timestamps
    added_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT unique_user_product_cart UNIQUE (user_id, product_id, variant_options)
);

-- ============================================================================
-- CART HISTORY TABLE (For abandoned cart tracking)
-- ============================================================================

-- Drop existing table if it exists
DROP TABLE IF EXISTS public.cart_history CASCADE;

CREATE TABLE public.cart_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('added', 'removed', 'purchased', 'abandoned')),
    reason TEXT, -- Why removed (purchased, expired, manually removed, etc.)
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Wishlist indexes
CREATE INDEX idx_wishlist_user_id ON public.wishlist(user_id);
CREATE INDEX idx_wishlist_product_id ON public.wishlist(product_id);
CREATE INDEX idx_wishlist_user_created ON public.wishlist(user_id, created_at DESC);
CREATE INDEX idx_wishlist_priority ON public.wishlist(priority);
CREATE INDEX idx_wishlist_price_tracking ON public.wishlist(target_price) WHERE target_price IS NOT NULL;

-- Cart indexes
CREATE INDEX idx_cart_user_id ON public.cart(user_id);
CREATE INDEX idx_cart_product_id ON public.cart(product_id);
CREATE INDEX idx_cart_active ON public.cart(user_id, is_active) WHERE is_active = TRUE;
CREATE INDEX idx_cart_seller ON public.cart(seller_id);
CREATE INDEX idx_cart_updated ON public.cart(updated_at DESC);

-- Cart history indexes
CREATE INDEX idx_cart_history_user ON public.cart_history(user_id);
CREATE INDEX idx_cart_history_product ON public.cart_history(product_id);
CREATE INDEX idx_cart_history_action ON public.cart_history(action);
CREATE INDEX idx_cart_history_created ON public.cart_history(created_at DESC);

-- ============================================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_wishlist_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_wishlist_timestamp
    BEFORE UPDATE ON public.wishlist
    FOR EACH ROW
    EXECUTE FUNCTION public.update_wishlist_updated_at();

-- Function to update cart updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_cart_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_cart_timestamp
    BEFORE UPDATE ON public.cart
    FOR EACH ROW
    EXECUTE FUNCTION public.update_cart_updated_at();

-- Function to record cart history
CREATE OR REPLACE FUNCTION public.record_cart_history()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.cart_history (user_id, product_id, quantity, unit_price, action)
        VALUES (NEW.user_id, NEW.product_id, NEW.quantity, NEW.unit_price, 'added');
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.is_active = FALSE AND OLD.is_active = TRUE THEN
            INSERT INTO public.cart_history (user_id, product_id, quantity, unit_price, action, reason)
            VALUES (NEW.user_id, NEW.product_id, NEW.quantity, NEW.unit_price, 'removed', 'manually removed');
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.cart_history (user_id, product_id, quantity, unit_price, action, reason)
        VALUES (OLD.user_id, OLD.product_id, OLD.quantity, OLD.unit_price, 'removed', 'deleted');
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger to record cart history
CREATE TRIGGER record_cart_history_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.cart
    FOR EACH ROW
    EXECUTE FUNCTION public.record_cart_history();

-- Function to update cart price when product price changes
CREATE OR REPLACE FUNCTION public.update_cart_prices()
RETURNS TRIGGER AS $$
BEGIN
    -- Update cart prices when product price changes
    UPDATE public.cart
    SET 
        unit_price = NEW.price,
        updated_at = NOW()
    WHERE product_id = NEW.id;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update cart prices
CREATE TRIGGER update_cart_prices_trigger
    AFTER UPDATE OF price ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION public.update_cart_prices();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS
ALTER TABLE public.wishlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_history ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

-- Wishlist policies
CREATE POLICY "Users can read own wishlist"
    ON public.wishlist
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own wishlist items"
    ON public.wishlist
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own wishlist items"
    ON public.wishlist
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own wishlist items"
    ON public.wishlist
    FOR DELETE
    USING (auth.uid() = user_id);

-- Cart policies
CREATE POLICY "Users can read own cart"
    ON public.cart
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own cart items"
    ON public.cart
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own cart items"
    ON public.cart
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own cart items"
    ON public.cart
    FOR DELETE
    USING (auth.uid() = user_id);

-- Cart history policies (users can only read their own history)
CREATE POLICY "Users can read own cart history"
    ON public.cart_history
    FOR SELECT
    USING (auth.uid() = user_id);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to add item to wishlist
CREATE OR REPLACE FUNCTION public.add_to_wishlist(
    p_product_id UUID,
    p_priority TEXT DEFAULT 'normal',
    p_notes TEXT DEFAULT NULL,
    p_target_price DECIMAL DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_wishlist_id UUID;
    v_current_price DECIMAL;
BEGIN
    -- Get current product price
    SELECT price INTO v_current_price
    FROM public.products
    WHERE id = p_product_id;
    
    INSERT INTO public.wishlist (
        user_id, product_id, priority, notes,
        target_price, added_at_price
    )
    VALUES (
        auth.uid(), p_product_id, p_priority, p_notes,
        p_target_price, v_current_price
    )
    ON CONFLICT (user_id, product_id) DO UPDATE
    SET 
        priority = EXCLUDED.priority,
        notes = EXCLUDED.notes,
        target_price = EXCLUDED.target_price,
        updated_at = NOW()
    RETURNING id INTO v_wishlist_id;
    
    RETURN v_wishlist_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to add item to cart
CREATE OR REPLACE FUNCTION public.add_to_cart(
    p_product_id UUID,
    p_quantity INTEGER DEFAULT 1,
    p_variant_options JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_cart_id UUID;
    v_product RECORD;
BEGIN
    -- Get product details
    SELECT * INTO v_product
    FROM public.products
    WHERE id = p_product_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found';
    END IF;
    
    IF v_product.stock_quantity < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock available';
    END IF;
    
    -- Insert or update cart item
    INSERT INTO public.cart (
        user_id, product_id, quantity, unit_price,
        variant_options, seller_id
    )
    VALUES (
        auth.uid(), p_product_id, p_quantity, v_product.price,
        p_variant_options, v_product.seller_id
    )
    ON CONFLICT (user_id, product_id, p_variant_options) DO UPDATE
    SET 
        quantity = cart.quantity + p_quantity,
        updated_at = NOW()
    RETURNING id INTO v_cart_id;
    
    RETURN v_cart_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update cart item quantity
CREATE OR REPLACE FUNCTION public.update_cart_quantity(
    p_cart_id UUID,
    p_quantity INTEGER
)
RETURNS VOID AS $$
BEGIN
    IF p_quantity <= 0 THEN
        -- Remove item if quantity is 0 or less
        DELETE FROM public.cart WHERE id = p_cart_id AND user_id = auth.uid();
    ELSE
        UPDATE public.cart
        SET 
            quantity = p_quantity,
            updated_at = NOW()
        WHERE id = p_cart_id AND user_id = auth.uid();
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get cart summary
CREATE OR REPLACE FUNCTION public.get_cart_summary()
RETURNS TABLE (
    total_items BIGINT,
    total_quantity BIGINT,
    subtotal DECIMAL,
    total_discount DECIMAL,
    grand_total DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(DISTINCT c.id)::BIGINT as total_items,
        SUM(c.quantity)::BIGINT as total_quantity,
        SUM(c.unit_price * c.quantity) as subtotal,
        SUM(c.discount_amount * c.quantity) as total_discount,
        SUM((c.unit_price - c.discount_amount) * c.quantity) as grand_total
    FROM public.cart c
    WHERE c.user_id = auth.uid()
      AND c.is_active = TRUE;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Function to clear cart
CREATE OR REPLACE FUNCTION public.clear_cart()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    DELETE FROM public.cart
    WHERE user_id = auth.uid()
      AND is_active = TRUE;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to move cart items to wishlist
CREATE OR REPLACE FUNCTION public.move_cart_to_wishlist(p_cart_id UUID)
RETURNS VOID AS $$
DECLARE
    v_cart_item RECORD;
BEGIN
    SELECT * INTO v_cart_item
    FROM public.cart
    WHERE id = p_cart_id AND user_id = auth.uid();
    
    IF FOUND THEN
        -- Add to wishlist
        INSERT INTO public.wishlist (user_id, product_id, added_at_price)
        VALUES (auth.uid(), v_cart_item.product_id, v_cart_item.unit_price)
        ON CONFLICT (user_id, product_id) DO NOTHING;
        
        -- Remove from cart
        DELETE FROM public.cart WHERE id = p_cart_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE public.wishlist IS 'User wishlists for saving products for later';
COMMENT ON TABLE public.cart IS 'Shopping cart for products ready to purchase';
COMMENT ON TABLE public.cart_history IS 'History of cart actions for analytics and abandoned cart recovery';
COMMENT ON COLUMN public.wishlist.target_price IS 'User desired price for price drop alerts';
COMMENT ON COLUMN public.cart.variant_options IS 'JSON object storing selected product variants (size, color, etc.)';
COMMENT ON COLUMN public.cart.unit_price IS 'Snapshot of product price at time of adding to cart';

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
