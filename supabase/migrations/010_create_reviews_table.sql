-- Migration: 010_create_reviews_table.sql
-- Created: 2026-03-14
-- Purpose: Create reviews and ratings system for products and sellers
-- Status: PENDING DEPLOYMENT

-- ============================================================================
-- REVIEWS TABLE
-- ============================================================================

-- Drop existing table if it exists (for clean deployment)
DROP TABLE IF EXISTS public.reviews CASCADE;

CREATE TABLE public.reviews (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Reviewer
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Review target (what is being reviewed)
    target_type TEXT NOT NULL CHECK (target_type IN ('product', 'seller', 'order')),
    target_id UUID NOT NULL, -- product_id, seller_id, or order_id
    
    -- Order reference (for verified purchase badge)
    order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
    
    -- Rating (1-5 stars)
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    
    -- Review content
    title TEXT,
    comment TEXT,
    
    -- Media attachments
    images TEXT[], -- Array of image URLs
    videos TEXT[], -- Array of video URLs
    
    -- Review attributes (for products)
    pros TEXT[], -- List of positive points
    cons TEXT[], -- List of negative points
    
    -- Helpfulness tracking
    helpful_count INTEGER DEFAULT 0,
    not_helpful_count INTEGER 0,
    
    -- Seller response (for seller/product reviews)
    seller_response TEXT,
    seller_response_at TIMESTAMPTZ,
    
    -- Moderation
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'flagged')),
    flagged_reason TEXT,
    moderated_by UUID REFERENCES auth.users(id),
    moderated_at TIMESTAMPTZ,
    
    -- Verification
    is_verified_purchase BOOLEAN DEFAULT FALSE,
    is_anonymous BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT unique_user_product_review UNIQUE (user_id, target_id, target_type)
        WHERE target_type = 'product',
    CONSTRAINT unique_user_seller_review UNIQUE (user_id, target_id, target_type)
        WHERE target_type = 'seller'
);

-- ============================================================================
-- REVIEW HELPFULNESS TABLE (Track who found reviews helpful)
-- ============================================================================

DROP TABLE IF EXISTS public.review_helpfulness CASCADE;

CREATE TABLE public.review_helpfulness (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_helpful BOOLEAN NOT NULL, -- true = helpful, false = not helpful
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_user_review_helpfulness UNIQUE (review_id, user_id)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Index for target reviews (most common query)
CREATE INDEX idx_reviews_target ON public.reviews(target_type, target_id);

-- Index for user reviews
CREATE INDEX idx_reviews_user_id ON public.reviews(user_id);

-- Index for approved reviews
CREATE INDEX idx_reviews_status ON public.reviews(status);

-- Index for verified purchases
CREATE INDEX idx_reviews_verified ON public.reviews(is_verified_purchase);

-- Index for rating filtering
CREATE INDEX idx_reviews_rating ON public.reviews(rating);

-- Index for created_at sorting
CREATE INDEX idx_reviews_created_at ON public.reviews(created_at DESC);

-- Composite index for approved reviews by target
CREATE INDEX idx_reviews_approved_target ON public.reviews(target_type, target_id, status, created_at DESC)
    WHERE status = 'approved';

-- Index for reviews with images
CREATE INDEX idx_reviews_with_images ON public.reviews USING GIN (images) WHERE array_length(images, 1) > 0;

-- Index for helpfulness sorting
CREATE INDEX idx_reviews_helpful ON public.reviews(helpful_count DESC);

-- Index for review_helpfulness
CREATE INDEX idx_review_helpfulness_review ON public.review_helpfulness(review_id);
CREATE INDEX idx_review_helpfulness_user ON public.review_helpfulness(user_id);

-- ============================================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_reviews_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER update_reviews_timestamp
    BEFORE UPDATE ON public.reviews
    FOR EACH ROW
    EXECUTE FUNCTION public.update_reviews_updated_at();

-- Function to update review helpfulness counts
CREATE OR REPLACE FUNCTION public.update_review_helpfulness_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.is_helpful IS DISTINCT FROM NEW.is_helpful) THEN
        UPDATE public.reviews
        SET 
            helpful_count = (
                SELECT COUNT(*)::INTEGER 
                FROM public.review_helpfulness 
                WHERE review_id = NEW.review_id AND is_helpful = TRUE
            ),
            not_helpful_count = (
                SELECT COUNT(*)::INTEGER 
                FROM public.review_helpfulness 
                WHERE review_id = NEW.review_id AND is_helpful = FALSE
            )
        WHERE id = NEW.review_id;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        UPDATE public.reviews
        SET 
            helpful_count = (
                SELECT COUNT(*)::INTEGER 
                FROM public.review_helpfulness 
                WHERE review_id = OLD.review_id AND is_helpful = TRUE
            ),
            not_helpful_count = (
                SELECT COUNT(*)::INTEGER 
                FROM public.review_helpfulness 
                WHERE review_id = OLD.review_id AND is_helpful = FALSE
            )
        WHERE id = OLD.review_id;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update helpfulness counts
CREATE TRIGGER update_review_helpfulness_count_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.review_helpfulness
    FOR EACH ROW
    EXECUTE FUNCTION public.update_review_helpfulness_count();

-- Function to update average rating on target (product/seller)
CREATE OR REPLACE FUNCTION public.update_target_average_rating()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.target_type = 'product' THEN
        UPDATE public.products
        SET 
            rating = (
                SELECT COALESCE(AVG(rating), 0)::DECIMAL(3,2)
                FROM public.reviews
                WHERE target_id = NEW.target_id 
                  AND target_type = 'product'
                  AND status = 'approved'
            ),
            total_reviews = (
                SELECT COUNT(*)::INTEGER
                FROM public.reviews
                WHERE target_id = NEW.target_id 
                  AND target_type = 'product'
                  AND status = 'approved'
            )
        WHERE id = NEW.target_id;
    ELSIF NEW.target_type = 'seller' THEN
        UPDATE public.business_profiles
        SET 
            rating = (
                SELECT COALESCE(AVG(rating), 0)::DECIMAL(3,2)
                FROM public.reviews
                WHERE target_id = NEW.target_id 
                  AND target_type = 'seller'
                  AND status = 'approved'
            ),
            total_reviews = (
                SELECT COUNT(*)::INTEGER
                FROM public.reviews
                WHERE target_id = NEW.target_id 
                  AND target_type = 'seller'
                  AND status = 'approved'
            )
        WHERE target_id = NEW.target_id;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update product/seller rating after review is approved
CREATE TRIGGER update_product_rating_after_review
    AFTER INSERT OR UPDATE OR DELETE ON public.reviews
    FOR EACH ROW
    WHEN (NEW.status = 'approved' OR OLD.status = 'approved')
    EXECUTE FUNCTION public.update_target_average_rating();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_helpfulness ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

-- Policy: Anyone can read approved reviews
CREATE POLICY "Anyone can read approved reviews"
    ON public.reviews
    FOR SELECT
    USING (status = 'approved' OR user_id = auth.uid());

-- Policy: Users can create their own reviews
CREATE POLICY "Users can create own reviews"
    ON public.reviews
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own reviews
CREATE POLICY "Users can update own reviews"
    ON public.reviews
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own reviews
CREATE POLICY "Users can delete own reviews"
    ON public.reviews
    FOR DELETE
    USING (auth.uid() = user_id);

-- Policy: Users can read review_helpfulness
CREATE POLICY "Users can read review_helpfulness"
    ON public.review_helpfulness
    FOR SELECT
    USING (true);

-- Policy: Users can create their own helpfulness votes
CREATE POLICY "Users can create own helpfulness votes"
    ON public.review_helpfulness
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own helpfulness votes
CREATE POLICY "Users can update own helpfulness votes"
    ON public.review_helpfulness
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own helpfulness votes
CREATE POLICY "Users can delete own helpfulness votes"
    ON public.review_helpfulness
    FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to create a review
CREATE OR REPLACE FUNCTION public.create_review(
    p_target_type TEXT,
    p_target_id UUID,
    p_rating INTEGER,
    p_title TEXT DEFAULT NULL,
    p_comment TEXT DEFAULT NULL,
    p_images TEXT[] DEFAULT NULL,
    p_pros TEXT[] DEFAULT NULL,
    p_cons TEXT[] DEFAULT NULL,
    p_order_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_review_id UUID;
BEGIN
    -- Verify purchase if order_id is provided
    IF p_order_id IS NOT NULL THEN
        -- Check if user actually purchased this product
        IF NOT EXISTS (
            SELECT 1 FROM public.order_items oi
            JOIN public.orders o ON oi.order_id = o.id
            WHERE o.id = p_order_id 
              AND o.user_id = auth.uid()
              AND (p_target_type != 'product' OR oi.product_id = p_target_id)
        ) THEN
            RAISE EXCEPTION 'You can only review products you have purchased';
        END IF;
    END IF;
    
    INSERT INTO public.reviews (
        user_id, target_type, target_id, rating,
        title, comment, images, pros, cons,
        order_id, is_verified_purchase
    )
    VALUES (
        auth.uid(), p_target_type, p_target_id, p_rating,
        p_title, p_comment, p_images, p_pros, p_cons,
        p_order_id, p_order_id IS NOT NULL
    )
    RETURNING id INTO v_review_id;
    
    RETURN v_review_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to vote on review helpfulness
CREATE OR REPLACE FUNCTION public.vote_review_helpfulness(
    p_review_id UUID,
    p_is_helpful BOOLEAN
)
RETURNS VOID AS $$
BEGIN
    -- Upsert: insert or update existing vote
    INSERT INTO public.review_helpfulness (review_id, user_id, is_helpful)
    VALUES (p_review_id, auth.uid(), p_is_helpful)
    ON CONFLICT (review_id, user_id) 
    DO UPDATE SET is_helpful = p_is_helpful, created_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get review statistics for a target
CREATE OR REPLACE FUNCTION public.get_review_statistics(
    p_target_type TEXT,
    p_target_id UUID
)
RETURNS TABLE (
    average_rating DECIMAL,
    total_reviews BIGINT,
    rating_distribution JSONB,
    recommended_percentage DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(AVG(r.rating), 0)::DECIMAL(3,2) as average_rating,
        COUNT(*)::BIGINT as total_reviews,
        jsonb_build_object(
            '5', COUNT(*) FILTER (WHERE r.rating = 5),
            '4', COUNT(*) FILTER (WHERE r.rating = 4),
            '3', COUNT(*) FILTER (WHERE r.rating = 3),
            '2', COUNT(*) FILTER (WHERE r.rating = 2),
            '1', COUNT(*) FILTER (WHERE r.rating = 1)
        ) as rating_distribution,
        (COUNT(*) FILTER (WHERE r.rating >= 4)::DECIMAL / NULLIF(COUNT(*), 0) * 100)::DECIMAL(5,2) as recommended_percentage
    FROM public.reviews r
    WHERE r.target_id = p_target_id
      AND r.target_type = p_target_type
      AND r.status = 'approved';
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE public.reviews IS 'User reviews and ratings for products, sellers, and orders';
COMMENT ON COLUMN public.reviews.target_type IS 'What is being reviewed: product, seller, or order';
COMMENT ON COLUMN public.reviews.is_verified_purchase IS 'True if reviewer purchased the product through the platform';
COMMENT ON COLUMN public.reviews.status IS 'Moderation status: pending, approved, rejected, or flagged';
COMMENT ON COLUMN public.reviews.helpful_count IS 'Number of users who found this review helpful';

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
