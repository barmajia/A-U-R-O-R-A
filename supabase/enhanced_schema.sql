-- ================================================================
-- AURORA E-COMMERCE - ENHANCED DATABASE SCHEMA
-- ================================================================
-- Complete schema with Orders, Wishlist, Reviews, Notifications, 
-- Analytics, Shipping Addresses, and Cart
-- ================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================================
-- CATEGORIES TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  parent_id UUID REFERENCES categories(id),
  icon TEXT,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_categories_parent ON categories(parent_id);
CREATE INDEX idx_categories_slug ON categories(slug);

-- ================================================================
-- ORDERS TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending',
  subtotal DECIMAL(10,2) DEFAULT 0,
  discount DECIMAL(10,2) DEFAULT 0,
  tax DECIMAL(10,2) DEFAULT 0,
  shipping DECIMAL(10,2) DEFAULT 0,
  total DECIMAL(10,2) DEFAULT 0,
  shipping_address_id UUID,
  payment_method TEXT,
  payment_status TEXT DEFAULT 'pending',
  tracking_number TEXT,
  metadata JSONB,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  shipped_at TIMESTAMP WITH TIME ZONE,
  delivered_at TIMESTAMP WITH TIME ZONE,
  cancelled_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_seller_id ON orders(seller_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);

-- ================================================================
-- ORDER ITEMS TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  product_id UUID,
  asin TEXT,
  sku TEXT,
  title TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_asin ON order_items(asin);

-- ================================================================
-- REVIEWS TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  asin TEXT NOT NULL,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5) NOT NULL,
  title TEXT,
  comment TEXT,
  is_verified_purchase BOOLEAN DEFAULT false,
  helpful_count INTEGER DEFAULT 0,
  images JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_reviews_asin ON reviews(asin);
CREATE INDEX idx_reviews_user_id ON reviews(user_id);
CREATE INDEX idx_reviews_rating ON reviews(rating);

-- Function to calculate product average rating
CREATE OR REPLACE FUNCTION get_product_rating(product_asin TEXT)
RETURNS DECIMAL AS $$
BEGIN
  RETURN (
    SELECT COALESCE(AVG(rating), 0)
    FROM reviews
    WHERE asin = product_asin
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- WISHLIST TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS wishlist (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  asin TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, asin)
);

CREATE INDEX idx_wishlist_user_id ON wishlist(user_id);
CREATE INDEX idx_wishlist_asin ON wishlist(asin);

-- ================================================================
-- CART TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS cart (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  asin TEXT NOT NULL,
  quantity INTEGER DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, asin)
);

CREATE INDEX idx_cart_user_id ON cart(user_id);
CREATE INDEX idx_cart_asin ON cart(asin);

-- ================================================================
-- SHIPPING ADDRESSES TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS shipping_addresses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  full_name TEXT NOT NULL,
  address_line1 TEXT NOT NULL,
  address_line2 TEXT,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  postal_code TEXT NOT NULL,
  country TEXT NOT NULL,
  phone TEXT,
  is_default BOOLEAN DEFAULT false,
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_shipping_addresses_user_id ON shipping_addresses(user_id);
CREATE INDEX idx_shipping_addresses_default ON shipping_addresses(user_id, is_default);

-- ================================================================
-- NOTIFICATIONS TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL, -- order, product, system, promotion, message
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  data JSONB,
  is_read BOOLEAN DEFAULT false,
  action_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_read ON notifications(user_id, is_read);

-- ================================================================
-- ANALYTICS TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS analytics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  metric_type TEXT NOT NULL, -- views, clicks, sales, revenue
  metric_value DECIMAL(12,2) DEFAULT 0,
  metric_date DATE NOT NULL,
  product_asin TEXT,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_analytics_seller_id ON analytics(seller_id);
CREATE INDEX idx_analytics_date ON analytics(metric_date);
CREATE INDEX idx_analytics_type ON analytics(metric_type);

-- ================================================================
-- PUSH SUBSCRIPTIONS TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL, -- ios, android, web
  endpoint TEXT,
  p256dh TEXT,
  auth TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_push_subscriptions_user_id ON push_subscriptions(user_id);
CREATE INDEX idx_push_subscriptions_token ON push_subscriptions(token);

-- ================================================================
-- PRODUCTS TABLE (Enhanced with rating fields)
-- ================================================================

-- Add rating columns if not exists
ALTER TABLE products ADD COLUMN IF NOT EXISTS average_rating DECIMAL(3,2) DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS review_count INTEGER DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS qr_data TEXT;

CREATE INDEX idx_products_rating ON products(average_rating);

-- ================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ================================================================

-- Orders
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own orders"
  ON orders FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own orders"
  ON orders FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own orders"
  ON orders FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Sellers can view their orders"
  ON orders FOR SELECT
  USING (auth.uid() = seller_id);

CREATE POLICY "Sellers can update their orders"
  ON orders FOR UPDATE
  USING (auth.uid() = seller_id);

-- Order Items
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own order items"
  ON order_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE orders.id = order_items.order_id 
      AND orders.user_id = auth.uid()
    )
  );

-- Reviews
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view reviews"
  ON reviews FOR SELECT
  USING (true);

CREATE POLICY "Users can create own reviews"
  ON reviews FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own reviews"
  ON reviews FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own reviews"
  ON reviews FOR DELETE
  USING (auth.uid() = user_id);

-- Wishlist
ALTER TABLE wishlist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own wishlist"
  ON wishlist FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own wishlist"
  ON wishlist FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Cart
ALTER TABLE cart ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own cart"
  ON cart FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own cart"
  ON cart FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Shipping Addresses
ALTER TABLE shipping_addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own addresses"
  ON shipping_addresses FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own addresses"
  ON shipping_addresses FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- Analytics
ALTER TABLE analytics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Sellers can view own analytics"
  ON analytics FOR SELECT
  USING (auth.uid() = seller_id);

CREATE POLICY "Sellers can insert own analytics"
  ON analytics FOR INSERT
  WITH CHECK (auth.uid() = seller_id);

-- Push Subscriptions
ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own subscriptions"
  ON push_subscriptions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own subscriptions"
  ON push_subscriptions FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Categories
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active categories"
  ON categories FOR SELECT
  USING (is_active = true);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- Update updated_at for orders
CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Update updated_at for shipping addresses
CREATE TRIGGER update_shipping_addresses_updated_at
  BEFORE UPDATE ON shipping_addresses
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Update updated_at for cart
CREATE TRIGGER update_cart_updated_at
  BEFORE UPDATE ON cart
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Update updated_at for push subscriptions
CREATE TRIGGER update_push_subscriptions_updated_at
  BEFORE UPDATE ON push_subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ================================================================
-- HELPER FUNCTIONS
-- ================================================================

-- Get user's order count
CREATE OR REPLACE FUNCTION get_user_order_count(user_uuid UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM orders
    WHERE user_id = user_uuid
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get seller's total revenue
CREATE OR REPLACE FUNCTION get_seller_total_revenue(seller_uuid UUID, days INTEGER DEFAULT 30)
RETURNS DECIMAL AS $$
BEGIN
  RETURN (
    SELECT COALESCE(SUM(total), 0)
    FROM orders
    WHERE seller_id = seller_uuid
      AND status NOT IN ('cancelled', 'refunded')
      AND created_at >= NOW() - (days || ' days')::INTERVAL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get product's review summary
CREATE OR REPLACE FUNCTION get_product_review_summary(product_asin TEXT)
RETURNS TABLE (
  average_rating DECIMAL,
  total_reviews INTEGER,
  rating_5 INTEGER,
  rating_4 INTEGER,
  rating_3 INTEGER,
  rating_2 INTEGER,
  rating_1 INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(AVG(rating), 0)::DECIMAL,
    COUNT(*)::INTEGER,
    COUNT(*) FILTER (WHERE rating = 5)::INTEGER,
    COUNT(*) FILTER (WHERE rating = 4)::INTEGER,
    COUNT(*) FILTER (WHERE rating = 3)::INTEGER,
    COUNT(*) FILTER (WHERE rating = 2)::INTEGER,
    COUNT(*) FILTER (WHERE rating = 1)::INTEGER
  FROM reviews
  WHERE asin = product_asin;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- SAMPLE DATA (Optional - for testing)
-- ================================================================

-- Insert sample categories
INSERT INTO categories (name, slug, icon, description) VALUES
  ('Fashion & Apparel', 'fashion-apparel', '👕', 'Clothing, shoes, and accessories'),
  ('Electronics', 'electronics', '💻', 'Phones, laptops, and gadgets'),
  ('Home & Living', 'home-living', '🏠', 'Furniture and home decor'),
  ('Beauty & Personal Care', 'beauty-care', '💄', 'Skincare, makeup, and fragrance'),
  ('Sports & Outdoors', 'sports-outdoors', '⚽', 'Sports equipment and outdoor gear')
ON CONFLICT (slug) DO NOTHING;

-- ================================================================
-- GRANT PERMISSIONS
-- ================================================================

GRANT ALL ON categories TO authenticated;
GRANT SELECT ON categories TO anon;

GRANT ALL ON orders TO authenticated;
GRANT SELECT ON orders TO anon;

GRANT ALL ON order_items TO authenticated;
GRANT SELECT ON order_items TO anon;

GRANT ALL ON reviews TO authenticated;
GRANT SELECT ON reviews TO anon;

GRANT ALL ON wishlist TO authenticated;
GRANT SELECT ON wishlist TO anon;

GRANT ALL ON cart TO authenticated;
GRANT SELECT ON cart TO anon;

GRANT ALL ON shipping_addresses TO authenticated;
GRANT SELECT ON shipping_addresses TO anon;

GRANT ALL ON notifications TO authenticated;
GRANT SELECT ON notifications TO anon;

GRANT ALL ON analytics TO authenticated;
GRANT SELECT ON analytics TO anon;

GRANT ALL ON push_subscriptions TO authenticated;
GRANT SELECT ON push_subscriptions TO anon;

-- ================================================================
-- SETUP COMPLETE! ✓
-- ================================================================
