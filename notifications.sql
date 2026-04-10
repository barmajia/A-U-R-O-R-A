-- ============================================================================
-- NOTIFICATIONS SYSTEM - COMPLETE SCHEMA
-- ============================================================================
-- File: notifications.sql
-- Description: Complete notification system for Aurora E-Commerce
-- Created: 2026-03-31
-- Status: Production Ready
--
-- Tables:
--   notifications - Main notification storage
--   notification_templates - Message templates
--   notification_settings - User preferences
--
-- Features:
--   - Multiple notification types (order, message, deal, product, system, etc)
--   - Priority levels (low, medium, high, urgent)
--   - Read status tracking
--   - Reference to related entities
--   - User preferences
--   - RLS policies for security
--   - Triggers for automation
--   - Indexes for performance
-- ============================================================================

-- ==============================================================================
-- PART 1: ENABLE REQUIRED EXTENSIONS
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For full-text search optimization

-- ==============================================================================
-- PART 2: CREATE NOTIFICATION TYPES ENUM
-- ==============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'notification_type'
  ) THEN
    CREATE TYPE notification_type AS ENUM (
      'order',         -- Order created, shipped, delivered, cancelled
      'message',       -- New chat message
      'deal',          -- Deal proposal, acceptance, rejection, counter
      'product',       -- Product price drop, restock, rating, review
      'system',        -- System announcements, maintenance
      'payment',       -- Payment confirmation, failed, refund
      'shipping',      -- Shipment tracking updates
      'review'         -- Customer review, rating notification
    );
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'notification_priority'
  ) THEN
    CREATE TYPE notification_priority AS ENUM (
      'low',           -- Non-urgent (product review confirmed)
      'medium',        -- Standard (new message, order update)
      'high',          -- Important (payment failed, deal expiring)
      'urgent'         -- Critical (order issues, account security)
    );
  END IF;
END
$$;

-- ==============================================================================
-- PART 3: CREATE MAIN NOTIFICATIONS TABLE (WITH MIGRATION SUPPORT)
-- ==============================================================================

-- Drop existing table if it exists (to ensure clean schema)
DROP TABLE IF EXISTS public.notifications CASCADE;

CREATE TABLE public.notifications (
  -- Primary Key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Recipient
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Notification Content
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type notification_type NOT NULL,
  priority notification_priority DEFAULT 'medium',
  
  -- Read Status
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMP WITH TIME ZONE,
  
  -- Reference Information (Link to related entity)
  reference_type TEXT,  -- 'order', 'product', 'conversation', 'deal', 'review'
  reference_id UUID,
  
  -- Action URL (for deep linking)
  action_url TEXT,
  
  -- Additional Data (JSON for flexibility)
  metadata JSONB DEFAULT '{}',
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE,  -- Optional expiry for time-sensitive notifications
  
  -- Constraints
  CONSTRAINT valid_reference CHECK (
    (reference_type IS NULL AND reference_id IS NULL)
    OR (reference_type IS NOT NULL AND reference_id IS NOT NULL)
  )
);

-- ==============================================================================
-- PART 4: CREATE NOTIFICATION TEMPLATES TABLE
-- ==============================================================================

DROP TABLE IF EXISTS public.notification_templates CASCADE;

CREATE TABLE public.notification_templates (
  -- Primary Key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Template Info
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  type notification_type NOT NULL,
  priority notification_priority DEFAULT 'medium',
  
  -- Template Content
  title_template TEXT NOT NULL,      -- Variables: {{var_name}}
  message_template TEXT NOT NULL,    -- Variables: {{var_name}}
  action_url_template TEXT,
  
  -- Metadata
  enabled BOOLEAN DEFAULT true,
  variables JSONB DEFAULT '[]',      -- List of required/optional variables
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- ==============================================================================
-- PART 5: CREATE NOTIFICATION SETTINGS TABLE (User Preferences)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.notification_settings (
  -- Primary Key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- User
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Global Settings
  notifications_enabled BOOLEAN DEFAULT true,
  email_notifications BOOLEAN DEFAULT true,
  push_notifications BOOLEAN DEFAULT true,
  
  -- Type-Specific Settings (Can override global)
  order_notifications BOOLEAN DEFAULT true,
  message_notifications BOOLEAN DEFAULT true,
  deal_notifications BOOLEAN DEFAULT true,
  product_notifications BOOLEAN DEFAULT true,
  system_notifications BOOLEAN DEFAULT true,
  payment_notifications BOOLEAN DEFAULT true,
  shipping_notifications BOOLEAN DEFAULT true,
  review_notifications BOOLEAN DEFAULT true,
  
  -- Priority-Based Settings
  notify_low_priority BOOLEAN DEFAULT true,
  notify_medium_priority BOOLEAN DEFAULT true,
  notify_high_priority BOOLEAN DEFAULT true,
  notify_urgent_priority BOOLEAN DEFAULT true,
  
  -- Quiet Hours (e.g., 22:00 - 08:00)
  quiet_hours_enabled BOOLEAN DEFAULT false,
  quiet_hours_start TIME,
  quiet_hours_end TIME,
  quiet_hours_timezone TEXT DEFAULT 'UTC',
  
  -- Batch Settings
  batch_notifications BOOLEAN DEFAULT false,
  batch_frequency TEXT CHECK (batch_frequency IN ('instant', 'hourly', 'daily')),
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==============================================================================
-- PART 6: CREATE INDEXES FOR PERFORMANCE
-- ==============================================================================

-- Notifications Table Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id 
  ON public.notifications(user_id);

CREATE INDEX IF NOT EXISTS idx_notifications_is_read 
  ON public.notifications(is_read)
  WHERE is_read = false;  -- Partial index for unread

CREATE INDEX IF NOT EXISTS idx_notifications_created_at 
  ON public.notifications(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created 
  ON public.notifications(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_type 
  ON public.notifications(type);

CREATE INDEX IF NOT EXISTS idx_notifications_priority 
  ON public.notifications(priority);

CREATE INDEX IF NOT EXISTS idx_notifications_reference 
  ON public.notifications(reference_type, reference_id)
  WHERE reference_type IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_expires_at 
  ON public.notifications(expires_at)
  WHERE expires_at IS NOT NULL;

-- Notification Settings Indexes
CREATE INDEX IF NOT EXISTS idx_notification_settings_user_id 
  ON public.notification_settings(user_id);

-- ==============================================================================
-- PART 7: CREATE FUNCTIONS
-- ==============================================================================

-- Function: Create notification with template
CREATE OR REPLACE FUNCTION create_notification_from_template(
  p_user_id UUID,
  p_template_name TEXT,
  p_variables JSONB DEFAULT '{}',
  p_reference_type TEXT DEFAULT NULL,
  p_reference_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_template RECORD;
  v_title TEXT;
  v_message TEXT;
  v_action_url TEXT;
  v_notification_id UUID;
BEGIN
  -- Get template
  SELECT * INTO v_template
  FROM notification_templates
  WHERE name = p_template_name AND enabled = true
  LIMIT 1;
  
  IF v_template IS NULL THEN
    RAISE EXCEPTION 'Template % not found', p_template_name;
  END IF;
  
  -- Render title (replace {{var}} with values from p_variables)
  v_title := v_template.title_template;
  v_title := REGEXP_REPLACE(
    v_title,
    '\{\{(\w+)\}\}',
    COALESCE(p_variables->>(REGEXP_MATCHES(v_title, '\{\{(\w+)\}\}', 'g'))[1], '\{\{\1\}\}'),
    'g'
  );
  
  -- Render message
  v_message := v_template.message_template;
  v_message := REGEXP_REPLACE(
    v_message,
    '\{\{(\w+)\}\}',
    COALESCE(p_variables->>(REGEXP_MATCHES(v_message, '\{\{(\w+)\}\}', 'g'))[1], '\{\{\1\}\}'),
    'g'
  );
  
  -- Render action URL
  IF v_template.action_url_template IS NOT NULL THEN
    v_action_url := v_template.action_url_template;
    v_action_url := REGEXP_REPLACE(
      v_action_url,
      '\{\{(\w+)\}\}',
      COALESCE(p_variables->>(REGEXP_MATCHES(v_action_url, '\{\{(\w+)\}\}', 'g'))[1], '\{\{\1\}\}'),
      'g'
    );
  END IF;
  
  -- Create notification
  INSERT INTO notifications (
    user_id, title, message, type, priority,
    reference_type, reference_id, action_url, metadata
  )
  VALUES (
    p_user_id, v_title, v_message, v_template.type, v_template.priority,
    p_reference_type, p_reference_id, v_action_url, p_variables
  )
  RETURNING id INTO v_notification_id;
  
  RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Mark notification as read
CREATE OR REPLACE FUNCTION mark_notification_read(p_notification_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE notifications
  SET is_read = true, read_at = NOW(), updated_at = NOW()
  WHERE id = p_notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Mark all notifications as read for user
CREATE OR REPLACE FUNCTION mark_notifications_read(p_user_id UUID)
RETURNS integer AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE notifications
  SET is_read = true, read_at = NOW(), updated_at = NOW()
  WHERE user_id = p_user_id AND is_read = false;
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get unread count for user
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id UUID)
RETURNS integer AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM notifications
    WHERE user_id = p_user_id AND is_read = false
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function: Delete expired notifications (called by cron job)
CREATE OR REPLACE FUNCTION cleanup_expired_notifications()
RETURNS integer AS $$
DECLARE
  v_deleted_count integer;
BEGIN
  DELETE FROM notifications
  WHERE expires_at IS NOT NULL
  AND expires_at < NOW();
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- PART 8: CREATE TRIGGERS
-- ==============================================================================

-- Trigger: Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_notifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notifications_updated_at ON notifications;
CREATE TRIGGER trigger_notifications_updated_at
  BEFORE UPDATE ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION update_notifications_updated_at();

-- ==============================================================================
-- PART 9: ENABLE ROW LEVEL SECURITY (RLS)
-- ==============================================================================

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- PART 10: CREATE RLS POLICIES
-- ==============================================================================

-- ------
-- Notifications Policies
-- ------

-- Users can view their own notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT
  USING (user_id = auth.uid());

-- Service role can insert notifications (for triggers)
DROP POLICY IF EXISTS "Service role can insert notifications" ON public.notifications;
CREATE POLICY "Service role can insert notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- Users can mark their own notifications as read
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Users can delete their own notifications
DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
CREATE POLICY "Users can delete own notifications"
  ON public.notifications FOR DELETE
  USING (user_id = auth.uid());

-- ------
-- Notification Settings Policies
-- ------

-- Users can view their own settings
DROP POLICY IF EXISTS "Users can view own notification settings" ON public.notification_settings;
CREATE POLICY "Users can view own notification settings"
  ON public.notification_settings FOR SELECT
  USING (user_id = auth.uid());

-- Users can update their own settings
DROP POLICY IF EXISTS "Users can update own notification settings" ON public.notification_settings;
CREATE POLICY "Users can update own notification settings"
  ON public.notification_settings FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Users can insert their own settings
DROP POLICY IF EXISTS "Users can insert notification settings" ON public.notification_settings;
CREATE POLICY "Users can insert notification settings"
  ON public.notification_settings FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- ------
-- Notification Templates Policies (Admin only)
-- ------

-- Service role can manage templates
DROP POLICY IF EXISTS "Service role can manage templates" ON public.notification_templates;
CREATE POLICY "Service role can manage templates"
  ON public.notification_templates FOR ALL
  USING (auth.role() = 'service_role');

-- Anyone can read enabled templates
DROP POLICY IF EXISTS "Anyone can read enabled templates" ON public.notification_templates;
CREATE POLICY "Anyone can read enabled templates"
  ON public.notification_templates FOR SELECT
  USING (enabled = true);

-- ==============================================================================
-- PART 11: INSERT DEFAULT NOTIFICATION TEMPLATES
-- ==============================================================================

INSERT INTO public.notification_templates (
  name, description, type, priority,
  title_template, message_template, action_url_template
) VALUES
  -- Order Notifications
  ('order_created', 'New order created', 'order', 'high',
   'New Order #{{order_id}}',
   'Order {{order_id}} created on {{date}}. Total: {{amount}}',
   '/orders/{{order_id}}'),
  
  ('order_shipped', 'Order shipped notification', 'order', 'high',
   'Order #{{order_id}} Shipped',
   'Your order {{order_id}} has been shipped. Tracking: {{tracking_id}}',
   '/orders/{{order_id}}/track'),
  
  ('order_delivered', 'Order delivered', 'order', 'medium',
   'Order #{{order_id}} Delivered',
   'Your order {{order_id}} has been delivered on {{date}}',
   '/orders/{{order_id}}'),
  
  -- Message Notifications
  ('new_message', 'New chat message', 'message', 'high',
   'New Message from {{sender_name}}',
   '{{sender_name}}: {{message_preview}}',
   '/chat/{{conversation_id}}'),
  
  -- Product Notifications
  ('product_price_drop', 'Product price decreased', 'product', 'medium',
   '{{product_name}} Price Drop!',
   'Price reduced to {{new_price}} (was {{old_price}})',
   '/product/{{product_id}}'),
  
  ('product_back_in_stock', 'Product restocked', 'product', 'medium',
   '{{product_name}} Back in Stock',
   '{{product_name}} is now available. Check it out now!',
   '/product/{{product_id}}'),
  
  ('product_new_review', 'New product review', 'product', 'low',
   'New Review on {{product_name}}',
   '{{reviewer_name}} gave {{rating}} stars: {{review_preview}}',
   '/product/{{product_id}}/reviews'),
  
  -- Deal Notifications
  ('deal_proposal', 'New deal proposal', 'deal', 'high',
   'New Deal Proposal from {{seller_name}}',
   'Deal for {{quantity}} units at {{price}} each',
   '/deals/{{deal_id}}'),
  
  ('deal_accepted', 'Deal accepted', 'deal', 'high',
   'Deal Accepted',
   'Your deal proposal #{{deal_id}} has been accepted!',
   '/deals/{{deal_id}}'),
  
  -- Payment Notifications
  ('payment_confirmed', 'Payment successful', 'payment', 'high',
   'Payment Confirmed',
   'Payment of {{amount}} for order {{order_id}} confirmed',
   '/payments/{{payment_id}}'),
  
  ('payment_failed', 'Payment failed', 'payment', 'urgent',
   'Payment Failed - Action Required',
   'Payment for order {{order_id}} failed. Please retry payment.',
   '/orders/{{order_id}}/pay'),
  
  -- System Notifications
  ('system_announcement', 'System announcement', 'system', 'medium',
   '{{announcement_title}}',
   '{{announcement_message}}',
   NULL)
ON CONFLICT (name) DO NOTHING;

-- ==============================================================================
-- PART 12: CREATE FUNCTION TO INITIALIZE USER SETTINGS
-- ==============================================================================

CREATE OR REPLACE FUNCTION initialize_user_notification_settings()
RETURNS TRIGGER AS $$
BEGIN
  -- Create default notification settings when new user is created
  INSERT INTO public.notification_settings (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- This trigger would be attached to auth.users if notified with custom claims
-- For now, this is handled in the application layer

-- ==============================================================================
-- PART 13: VERIFICATION QUERIES
-- ==============================================================================

-- Verify tables created
-- SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'notification%';

-- Verify indexes created
-- SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'notifications';

-- Verify RLS enabled
-- SELECT schemaname, tablename, rowsecurity FROM pg_tables WHERE tablename LIKE 'notification%';

-- Verify templates inserted
-- SELECT name, type, priority FROM notification_templates ORDER BY name;

-- ==============================================================================
-- MIGRATION COMPLETE
-- ==============================================================================
--
-- Notification System Successfully Created!
--
-- Tables:
-- ✓ notifications - Main notification storage
-- ✓ notification_settings - User preferences
-- ✓ notification_templates - Message templates
--
-- Features:
-- ✓ 8 notification types
-- ✓ 4 priority levels
-- ✓ RLS policies for security
-- ✓ Indexes for performance
-- ✓ Functions for common operations
-- ✓ Triggers for automation
-- ✓ Default templates
--
-- Next Steps:
-- 1. Deploy this SQL to Supabase
-- 2. Update Flutter notification service to use new schema
-- 3. Create edge function for sending notifications (optional)
-- 4. Test notification creation and retrieval
-- ============================================================================
