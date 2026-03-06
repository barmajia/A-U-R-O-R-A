-- ============================================================================
-- FACTORY DISCOVERY SYSTEM - Database Migration
-- ============================================================================
-- Description: Adds factory discovery, connection, and rating capabilities
-- Version: 1.0.0
-- Date: 2026-03-05
-- ============================================================================

-- 1. Add location coordinates and factory-specific fields to sellers table
ALTER TABLE sellers 
ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8),
ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8),
ADD COLUMN IF NOT EXISTS is_factory BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS factory_license_url TEXT,
ADD COLUMN IF NOT EXISTS min_order_quantity INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS wholesale_discount NUMERIC(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS accepts_returns BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS production_capacity TEXT,
ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

-- 2. Create factory_connections table (seller ↔ factory relationships)
CREATE TABLE IF NOT EXISTS factory_connections (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  factory_id UUID REFERENCES sellers(user_id) ON DELETE CASCADE,
  seller_id UUID REFERENCES sellers(user_id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'blocked')),
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  rejected_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(factory_id, seller_id)
);

-- 3. Create factory_ratings table (sellers rate factories)
CREATE TABLE IF NOT EXISTS factory_ratings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  factory_id UUID REFERENCES sellers(user_id) ON DELETE CASCADE,
  seller_id UUID REFERENCES sellers(user_id) ON DELETE CASCADE,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  review TEXT,
  delivery_rating INTEGER CHECK (delivery_rating >= 1 AND delivery_rating <= 5),
  quality_rating INTEGER CHECK (quality_rating >= 1 AND quality_rating <= 5),
  communication_rating INTEGER CHECK (communication_rating >= 1 AND communication_rating <= 5),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(factory_id, seller_id)
);

-- 4. Create factory_products view (wholesale products from factories)
CREATE OR REPLACE VIEW factory_products AS
SELECT 
  p.*,
  s.full_name as factory_name,
  s.location as factory_location,
  s.latitude,
  s.longitude,
  s.wholesale_discount,
  s.min_order_quantity,
  (p.price * (1 - COALESCE(s.wholesale_discount, 0) / 100)) as wholesale_price
FROM products p
JOIN sellers s ON p.seller_id = s.user_id
WHERE s.is_factory = true 
  AND p.status = 'active'
  AND p.is_deleted = false;

-- 5. Add indexes for location queries
CREATE INDEX IF NOT EXISTS idx_sellers_location ON sellers(latitude, longitude) 
  WHERE is_factory = true;
CREATE INDEX IF NOT EXISTS idx_factory_connections_factory ON factory_connections(factory_id);
CREATE INDEX IF NOT EXISTS idx_factory_connections_seller ON factory_connections(seller_id);
CREATE INDEX IF NOT EXISTS idx_factory_connections_status ON factory_connections(status);
CREATE INDEX IF NOT EXISTS idx_factory_ratings_factory ON factory_ratings(factory_id);

-- 6. Create function to calculate distance (Haversine formula)
CREATE OR REPLACE FUNCTION calculate_distance(
  lat1 DECIMAL,
  lon1 DECIMAL,
  lat2 DECIMAL,
  lon2 DECIMAL
) RETURNS DECIMAL AS $$
DECLARE
  R DECIMAL := 6371; -- Earth radius in km
  dLat DECIMAL;
  dLon DECIMAL;
  a DECIMAL;
  c DECIMAL;
  distance DECIMAL;
BEGIN
  dLat := RADIANS(lat2 - lat1);
  dLon := RADIANS(lon2 - lon1);
  
  a := SIN(dLat/2) * SIN(dLat/2) +
       COS(RADIANS(lat1)) * COS(RADIANS(lat2)) *
       SIN(dLon/2) * SIN(dLon/2);
  
  c := 2 * ATAN2(SQRT(a), SQRT(1-a));
  distance := R * c;
  
  RETURN ROUND(distance::numeric, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 7. Create function to find nearby factories
CREATE OR REPLACE FUNCTION find_nearby_factories(
  p_latitude DECIMAL,
  p_longitude DECIMAL,
  p_radius_km DECIMAL DEFAULT 50,
  p_limit INTEGER DEFAULT 20
) RETURNS TABLE (
  user_id UUID,
  full_name TEXT,
  location TEXT,
  latitude DECIMAL,
  longitude DECIMAL,
  distance_km DECIMAL,
  is_verified BOOLEAN,
  wholesale_discount NUMERIC,
  min_order_quantity INTEGER,
  product_count BIGINT,
  average_rating NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.user_id,
    s.full_name,
    s.location,
    s.latitude,
    s.longitude,
    calculate_distance(p_latitude, p_longitude, s.latitude, s.longitude) as distance_km,
    s.is_verified,
    s.wholesale_discount,
    s.min_order_quantity,
    COUNT(DISTINCT p.id) as product_count,
    COALESCE(AVG(fr.rating), 0) as average_rating
  FROM sellers s
  LEFT JOIN products p ON p.seller_id = s.user_id AND p.status = 'active' AND p.is_deleted = false
  LEFT JOIN factory_ratings fr ON fr.factory_id = s.user_id
  WHERE s.is_factory = true
    AND s.latitude IS NOT NULL
    AND s.longitude IS NOT NULL
    AND calculate_distance(p_latitude, p_longitude, s.latitude, s.longitude) <= p_radius_km
  GROUP BY s.user_id, s.full_name, s.location, s.latitude, s.longitude, 
           s.is_verified, s.wholesale_discount, s.min_order_quantity
  ORDER BY distance_km ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Create function to get factory average ratings
CREATE OR REPLACE FUNCTION get_factory_rating(p_factory_id UUID)
RETURNS TABLE (
  average_rating NUMERIC,
  total_reviews BIGINT,
  delivery_rating NUMERIC,
  quality_rating NUMERIC,
  communication_rating NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(AVG(rating), 0) as average_rating,
    COUNT(*) as total_reviews,
    COALESCE(AVG(delivery_rating), 0) as delivery_rating,
    COALESCE(AVG(quality_rating), 0) as quality_rating,
    COALESCE(AVG(communication_rating), 0) as communication_rating
  FROM factory_ratings
  WHERE factory_id = p_factory_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. RLS Policies for factory_connections
ALTER TABLE factory_connections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sellers_view_own_factory_connections" ON factory_connections
  FOR SELECT TO authenticated
  USING (seller_id = auth.uid() OR factory_id = auth.uid());

CREATE POLICY "sellers_create_factory_connections" ON factory_connections
  FOR INSERT TO authenticated
  WITH CHECK (seller_id = auth.uid());

CREATE POLICY "factories_update_own_connections" ON factory_connections
  FOR UPDATE TO authenticated
  USING (factory_id = auth.uid())
  WITH CHECK (factory_id = auth.uid());

-- 10. RLS Policies for factory_ratings
ALTER TABLE factory_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anyone_view_factory_ratings" ON factory_ratings
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "sellers_create_factory_ratings" ON factory_ratings
  FOR INSERT TO authenticated
  WITH CHECK (seller_id = auth.uid());

-- 11. Trigger to update factory_connections timestamp
CREATE OR REPLACE FUNCTION update_factory_connections_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_factory_connections_timestamp
  BEFORE UPDATE ON factory_connections
  FOR EACH ROW
  EXECUTE FUNCTION update_factory_connections_timestamp();

-- 12. Grant permissions
GRANT ALL ON FUNCTION find_nearby_factories TO authenticated;
GRANT ALL ON FUNCTION get_factory_rating TO authenticated;
GRANT ALL ON TABLE factory_connections TO authenticated;
GRANT ALL ON TABLE factory_ratings TO authenticated;

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
