-- Migration: 009_create_notifications_table.sql
-- Created: 2026-03-14
-- Purpose: Create notifications table for user notifications system
-- Status: PENDING DEPLOYMENT

-- ============================================================================
-- NOTIFICATIONS TABLE
-- ============================================================================

-- Drop existing table if it exists (for clean deployment)
DROP TABLE IF EXISTS public.notifications CASCADE;

CREATE TABLE public.notifications (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Recipient
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Notification details
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN (
        'order',           -- Order-related notifications
        'message',         -- New chat message
        'deal',            -- Deal proposal updates
        'product',         -- Product updates (price drop, restock)
        'system',          -- System announcements
        'payment',         -- Payment confirmations
        'shipping',        -- Shipping updates
        'review',          -- Review/rating notifications
        'promotion',       -- Promotional offers
        'security'         -- Security alerts
    )),
    
    -- Priority level
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    
    -- Related entity (optional)
    reference_type TEXT, -- e.g., 'order', 'product', 'conversation'
    reference_id UUID,   -- ID of the related entity
    
    -- Action URL (optional)
    action_url TEXT,     -- Deep link or URL for notification action
    
    -- Status
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    
    -- Delivery status
    is_sent BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMPTZ,
    is_delivered BOOLEAN DEFAULT FALSE,
    delivered_at TIMESTAMPTZ,
    
    -- Metadata (flexible additional data)
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ, -- Auto-expire old notifications
    
    -- Constraints
    CONSTRAINT valid_reference CHECK (
        (reference_type IS NOT NULL AND reference_id IS NOT NULL) OR
        (reference_type IS NULL AND reference_id IS NULL)
    )
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Index for user notifications (most common query)
CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);

-- Index for unread notifications
CREATE INDEX idx_notifications_unread ON public.notifications(user_id, is_read) WHERE is_read = FALSE;

-- Index for notification type filtering
CREATE INDEX idx_notifications_type ON public.notifications(type);

-- Index for priority sorting
CREATE INDEX idx_notifications_priority ON public.notifications(priority, created_at DESC);

-- Index for created_at sorting (recent notifications)
CREATE INDEX idx_notifications_created_at ON public.notifications(created_at DESC);

-- Index for expiry cleanup
CREATE INDEX idx_notifications_expires_at ON public.notifications(expires_at) WHERE expires_at IS NOT NULL;

-- Composite index for user's unread notifications sorted by date
CREATE INDEX idx_notifications_user_unread_recent ON public.notifications(user_id, is_read, created_at DESC) 
    WHERE is_read = FALSE;

-- ============================================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Function to set read_at timestamp
CREATE OR REPLACE FUNCTION public.set_notification_read_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_read = TRUE AND OLD.is_read = FALSE THEN
        NEW.read_at = NOW();
    ELSIF NEW.is_read = FALSE THEN
        NEW.read_at = NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-set read_at
CREATE TRIGGER set_notification_read_at_trigger
    BEFORE UPDATE ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.set_notification_read_at();

-- Function to auto-expire old notifications
CREATE OR REPLACE FUNCTION public.cleanup_expired_notifications()
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.notifications
    WHERE expires_at IS NOT NULL 
      AND expires_at < NOW()
      AND is_read = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

-- Policy: Users can read their own notifications
CREATE POLICY "Users can read own notifications"
    ON public.notifications
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications"
    ON public.notifications
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own notifications
CREATE POLICY "Users can delete own notifications"
    ON public.notifications
    FOR DELETE
    USING (auth.uid() = user_id);

-- Policy: System can insert notifications (using service role)
CREATE POLICY "System can insert notifications"
    ON public.notifications
    FOR INSERT
    WITH CHECK (true); -- Controlled by service role in production

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to create a notification
CREATE OR REPLACE FUNCTION public.create_notification(
    p_user_id UUID,
    p_title TEXT,
    p_message TEXT,
    p_type TEXT,
    p_priority TEXT DEFAULT 'normal',
    p_reference_type TEXT DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL,
    p_action_url TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb,
    p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_notification_id UUID;
BEGIN
    INSERT INTO public.notifications (
        user_id, title, message, type, priority,
        reference_type, reference_id, action_url,
        metadata, expires_at
    )
    VALUES (
        p_user_id, p_title, p_message, p_type, p_priority,
        p_reference_type, p_reference_id, p_action_url,
        p_metadata, p_expires_at
    )
    RETURNING id INTO v_notification_id;
    
    RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark notification as read
CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.notifications
    SET is_read = TRUE
    WHERE id = p_notification_id
      AND user_id = auth.uid(); -- Ensure user owns the notification
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark all notifications as read for a user
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE public.notifications
    SET is_read = TRUE
    WHERE user_id = auth.uid()
      AND is_read = FALSE;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get unread notification count
CREATE OR REPLACE FUNCTION public.get_unread_notification_count()
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM public.notifications
        WHERE user_id = auth.uid()
          AND is_read = FALSE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE public.notifications IS 'User notifications for orders, messages, deals, and system events';
COMMENT ON COLUMN public.notifications.type IS 'Notification category: order, message, deal, product, system, payment, shipping, review, promotion, security';
COMMENT ON COLUMN public.notifications.priority IS 'Notification priority: low, normal, high, urgent';
COMMENT ON COLUMN public.notifications.reference_type IS 'Type of related entity (e.g., order, product, conversation)';
COMMENT ON COLUMN public.notifications.reference_id IS 'UUID of the related entity';
COMMENT ON COLUMN public.notifications.metadata IS 'Additional notification data in JSON format';

-- ============================================================================
-- SEED DATA (OPTIONAL - FOR TESTING)
-- ============================================================================

-- Uncomment to insert test data
-- INSERT INTO public.notifications (user_id, title, message, type, priority)
-- VALUES 
--     ('00000000-0000-0000-0000-000000000001', 'Welcome to Aurora!', 'Thank you for joining our platform.', 'system', 'normal'),
--     ('00000000-0000-0000-0000-000000000001', 'New Order Received', 'You have received a new order #12345', 'order', 'high');

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
