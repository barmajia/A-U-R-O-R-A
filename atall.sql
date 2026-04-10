


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "hypopg" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "index_advisor" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgmq";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."user_role" AS ENUM (
    'factory',
    'seller',
    'middleman',
    'customer',
    'delivery'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assign_delivery_to_driver"("p_order_id" "uuid", "p_seller_latitude" numeric, "p_seller_longitude" numeric) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_driver_id UUID;
BEGIN
  -- Find nearest available verified driver
  SELECT dp.user_id INTO v_driver_id
  FROM delivery_profiles dp
  WHERE dp.is_active = true
    AND dp.is_verified = true
    AND dp.latitude IS NOT NULL
    AND dp.longitude IS NOT NULL
  ORDER BY haversine_distance(p_seller_latitude, p_seller_longitude, dp.latitude, dp.longitude)
  LIMIT 1;
  
  IF v_driver_id IS NOT NULL THEN
    -- Update order with assigned driver
    UPDATE public.orders
    SET 
      delivery_id = v_driver_id,
      delivery_status = 'assigned',
      updated_at = NOW()
    WHERE id = p_order_id;
    
    -- Create assignment record
    INSERT INTO public.delivery_assignments (order_id, driver_id, status)
    VALUES (p_order_id, v_driver_id, 'assigned');
  END IF;
  
  RETURN v_driver_id;
END;
$$;


ALTER FUNCTION "public"."assign_delivery_to_driver"("p_order_id" "uuid", "p_seller_latitude" numeric, "p_seller_longitude" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_distance"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
  R DECIMAL := 6371;
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
$$;


ALTER FUNCTION "public"."calculate_distance"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_order_commission"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.deal_id IS NOT NULL THEN
    -- Get commission rate from deal (or use a default)
    SELECT commission_rate INTO NEW.commission_rate
    FROM deals WHERE id = NEW.deal_id;
    
    NEW.commission_amount := NEW.subtotal * (NEW.commission_rate / 100);
  ELSE
    NEW.commission_rate := NULL;
    NEW.commission_amount := NULL;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."calculate_order_commission"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_seller_analytics"("p_seller_id" "uuid", "p_period_type" "text" DEFAULT '30d'::"text", "p_start_date" "date" DEFAULT NULL::"date", "p_end_date" "date" DEFAULT NULL::"date") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
DECLARE
  v_start_date DATE;
  v_end_date DATE;
  v_days INTEGER;
  v_result JSONB;
BEGIN
  -- Security check: ensure caller can only access their own data
  IF auth.uid() IS NOT NULL AND auth.uid() != p_seller_id THEN
    RAISE EXCEPTION 'Access denied: can only view own analytics';
  END IF;

  IF p_start_date IS NOT NULL AND p_end_date IS NOT NULL THEN
    v_start_date := p_start_date;
    v_end_date := p_end_date;
    v_days := (p_end_date - p_start_date) + 1;
  ELSE
    IF p_period_type LIKE '%y' THEN
      v_days := (SUBSTRING(p_period_type FROM '(\d+)')::INTEGER) * 365;
    ELSIF p_period_type LIKE '%d' THEN
      v_days := SUBSTRING(p_period_type FROM '(\d+)')::INTEGER;
    ELSE
      v_days := 30;
    END IF;
    v_end_date := CURRENT_DATE;
    v_start_date := v_end_date - (v_days - 1);
  END IF;

  WITH sales_data AS (
    SELECT
      COUNT(*) as total_sales,
      COALESCE(SUM(total_price), 0) as total_revenue,
      COALESCE(SUM(quantity), 0) as total_items_sold,
      COALESCE(AVG(total_price), 0) as average_order_value,
      COUNT(DISTINCT customer_id) as unique_customers
    FROM sales
    WHERE seller_id = p_seller_id
    AND sale_date >= v_start_date
    AND sale_date <= v_end_date
  ),
  customer_data AS (
    SELECT COUNT(*) as total_customers
    FROM customers
    WHERE seller_id = p_seller_id
  ),
  top_products AS (
    SELECT
      COALESCE(p.title, s.product_id::TEXT) as product_name,
      s.product_id,
      COUNT(*) as times_sold,
      SUM(s.quantity) as units_sold,
      SUM(s.total_price) as revenue
    FROM sales s
    LEFT JOIN products p ON p.id = s.product_id
    WHERE s.seller_id = p_seller_id
    AND s.sale_date >= v_start_date
    AND s.sale_date <= v_end_date
    GROUP BY s.product_id, p.title
    ORDER BY revenue DESC
    LIMIT 5
  ),
  top_customers AS (
    SELECT
      c.id, c.name, c.phone,
      COUNT(s.id) as orders_in_period,
      SUM(s.total_price) as spent_in_period
    FROM customers c
    LEFT JOIN sales s ON s.customer_id = c.id
    AND s.sale_date >= v_start_date AND s.sale_date <= v_end_date
    WHERE c.seller_id = p_seller_id
    GROUP BY c.id, c.name, c.phone
    ORDER BY spent_in_period DESC NULLS LAST
    LIMIT 5
  ),
  daily_breakdown AS (
    SELECT
      DATE(sale_date) as date,
      COUNT(*) as sales,
      SUM(total_price) as revenue
    FROM sales
    WHERE seller_id = p_seller_id
    AND sale_date >= v_start_date AND sale_date <= v_end_date
    GROUP BY DATE(sale_date)
    ORDER BY date
  )
  SELECT jsonb_build_object(
    'seller_id', p_seller_id,
    'period', p_period_type,
    'period_days', v_days,
    'start_date', v_start_date,
    'end_date', v_end_date,
    'generated_at', NOW(),
    'kpis', jsonb_build_object(
      'total_revenue', COALESCE(sd.total_revenue, 0),
      'total_sales', COALESCE(sd.total_sales, 0),
      'total_items_sold', COALESCE(sd.total_items_sold, 0),
      'total_customers', COALESCE(cd.total_customers, 0),
      'unique_customers_in_period', COALESCE(sd.unique_customers, 0),
      'average_order_value', COALESCE(sd.average_order_value, 0),
      'conversion_rate', CASE
        WHEN cd.total_customers > 0
        THEN ROUND((sd.unique_customers::NUMERIC / cd.total_customers::NUMERIC) * 100, 2)
        ELSE 0
      END
    ),
    'top_products', COALESCE(
      (SELECT jsonb_agg(jsonb_build_object(
        'id', tp.product_id, 'name', tp.product_name,
        'times_sold', tp.times_sold, 'units_sold', tp.units_sold,
        'revenue', tp.revenue
      )) FROM top_products tp),
      '[]'::jsonb
    ),
    'top_customers', COALESCE(
      (SELECT jsonb_agg(jsonb_build_object(
        'id', tc.id, 'name', tc.name, 'phone', tc.phone,
        'orders_in_period', tc.orders_in_period,
        'spent_in_period', tc.spent_in_period
      )) FROM top_customers tc),
      '[]'::jsonb
    ),
    'daily_breakdown', COALESCE(
      (SELECT jsonb_agg(jsonb_build_object(
        'date', db.date, 'sales', db.sales, 'revenue', db.revenue
      )) FROM daily_breakdown db),
      '[]'::jsonb
    )
  ) INTO v_result
  FROM sales_data sd, customer_data cd;

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."calculate_seller_analytics"("p_seller_id" "uuid", "p_period_type" "text", "p_start_date" "date", "p_end_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_start_conversation"("from_user_id" "uuid", "to_user_id" "uuid", "product_id" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
DECLARE
  from_role users.account_type%TYPE;
  to_role users.account_type%TYPE;
  product_owner_id UUID;
  product_allows BOOLEAN;
BEGIN
  -- Security check
  IF auth.uid() IS NOT NULL AND auth.uid() != from_user_id THEN
    RAISE EXCEPTION 'Access denied: can only initiate conversations as yourself';
  END IF;

  SELECT account_type INTO from_role FROM users WHERE user_id = from_user_id;
  SELECT account_type INTO to_role FROM users WHERE user_id = to_user_id;

  IF from_user_id = to_user_id THEN RETURN FALSE; END IF;
  IF from_role = 'factory' AND to_role IN ('seller', 'middleman') THEN RETURN TRUE; END IF;
  IF from_role = 'seller' THEN
    IF to_role IN ('factory', 'middleman') THEN RETURN TRUE;
    ELSIF to_role = 'customer' THEN
      IF product_id IS NULL THEN RETURN FALSE; END IF;
      SELECT seller_id, allow_chat INTO product_owner_id, product_allows
      FROM products WHERE id = product_id;
      RETURN (product_owner_id = from_user_id) AND product_allows;
    END IF;
  END IF;
  IF from_role = 'middleman' THEN RETURN TRUE; END IF;
  IF from_role = 'customer' THEN
    IF to_role = 'seller' AND product_id IS NOT NULL THEN
      SELECT seller_id, allow_chat INTO product_owner_id, product_allows
      FROM products WHERE id = product_id;
      RETURN (product_owner_id = to_user_id) AND product_allows;
    END IF;
  END IF;
  RETURN FALSE;
END;
$$;


ALTER FUNCTION "public"."can_start_conversation"("from_user_id" "uuid", "to_user_id" "uuid", "product_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_expired_idempotency_keys"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
  DELETE FROM public.idempotency_keys
  WHERE expires_at < NOW();
END;
$$;


ALTER FUNCTION "public"."cleanup_expired_idempotency_keys"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_analytics_snapshot"("p_seller_id" "uuid", "p_period_type" "text" DEFAULT '30d'::"text", "p_start_date" "date" DEFAULT NULL::"date", "p_end_date" "date" DEFAULT NULL::"date") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
DECLARE
  v_snapshot_id UUID;
  v_analytics_data JSONB;
  v_period_start DATE;
  v_period_end DATE;
BEGIN
  -- Security check
  IF auth.uid() IS NOT NULL AND auth.uid() != p_seller_id THEN
    RAISE EXCEPTION 'Access denied: can only create snapshots for own account';
  END IF;

  IF p_start_date IS NOT NULL AND p_end_date IS NOT NULL THEN
    v_period_start := p_start_date;
    v_period_end := p_end_date;
  ELSE
    IF p_period_type LIKE '%y' THEN
      v_period_end := CURRENT_DATE;
      v_period_start := v_period_end - ((SUBSTRING(p_period_type FROM '(\d+)')::INTEGER) * 365 - 1);
    ELSIF p_period_type LIKE '%d' THEN
      v_period_end := CURRENT_DATE;
      v_period_start := v_period_end - (SUBSTRING(p_period_type FROM '(\d+)')::INTEGER - 1);
    ELSE
      v_period_end := CURRENT_DATE;
      v_period_start := v_period_end - 29;
    END IF;
  END IF;

  v_analytics_data := calculate_seller_analytics(p_seller_id, p_period_type, p_start_date, p_end_date);

  UPDATE analytics_snapshots
  SET is_current = false
  WHERE seller_id = p_seller_id
  AND period_type = p_period_type
  AND period_start = v_period_start
  AND period_end = v_period_end;

  INSERT INTO analytics_snapshots (
    seller_id, period_type, period_start, period_end,
    analytics_data, is_current
  ) VALUES (
    p_seller_id, p_period_type, v_period_start, v_period_end,
    v_analytics_data, true
  )
  ON CONFLICT (seller_id, period_type, period_start, period_end)
  DO UPDATE SET
    analytics_data = EXCLUDED.analytics_data,
    is_current = true,
    updated_at = NOW()
  RETURNING id INTO v_snapshot_id;

  RETURN v_snapshot_id;
END;
$$;


ALTER FUNCTION "public"."create_analytics_snapshot"("p_seller_id" "uuid", "p_period_type" "text", "p_start_date" "date", "p_end_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."decrement_product_inventory"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Lock the product row to prevent race conditions
    PERFORM 1 FROM public.products 
    WHERE asin = NEW.asin 
    FOR UPDATE;
    
    -- Check inventory before decrementing
    IF (SELECT quantity FROM public.products WHERE asin = NEW.asin) < NEW.quantity THEN
      RAISE EXCEPTION 'Insufficient inventory for ASIN: %. Available: %, Requested: %', 
        NEW.asin, 
        (SELECT quantity FROM public.products WHERE asin = NEW.asin),
        NEW.quantity;
    END IF;
    
    -- Safe decrement
    UPDATE public.products
    SET quantity = quantity - NEW.quantity,
        updated_at = NOW()
    WHERE asin = NEW.asin;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."decrement_product_inventory"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."dequeue_job"("p_queue_name" "text", "p_visibility_timeout_seconds" integer DEFAULT 30) RETURNS TABLE("id" "uuid", "payload" "jsonb", "attempts" integer)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  UPDATE public.async_jobs
  SET 
    status = 'processing',
    attempts = attempts + 1,
    processed_at = NOW()
  WHERE id = (
    SELECT id 
    FROM public.async_jobs 
    WHERE queue_name = p_queue_name 
      AND status = 'pending' 
      AND scheduled_for <= NOW()
    ORDER BY scheduled_for ASC, created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED
  )
  RETURNING id, payload, attempts;
END;
$$;


ALTER FUNCTION "public"."dequeue_job"("p_queue_name" "text", "p_visibility_timeout_seconds" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enqueue_job"("p_queue_name" "text", "p_payload" "jsonb", "p_scheduled_for" timestamp with time zone DEFAULT "now"()) RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_job_id UUID;
BEGIN
  INSERT INTO public.async_jobs (queue_name, payload, scheduled_for)
  VALUES (p_queue_name, p_payload, p_scheduled_for)
  RETURNING id INTO v_job_id;
  
  -- Notify listeners
  PERFORM pg_notify('job_queue_' || p_queue_name, v_job_id::text);
  
  RETURN v_job_id;
END;
$$;


ALTER FUNCTION "public"."enqueue_job"("p_queue_name" "text", "p_payload" "jsonb", "p_scheduled_for" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_nearby_drivers"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric DEFAULT 10, "p_limit" integer DEFAULT 10) RETURNS TABLE("driver_id" "uuid", "full_name" "text", "vehicle_type" "text", "distance_km" numeric, "rating" numeric, "is_verified" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dp.user_id,
    u.full_name,
    dp.vehicle_type,
    haversine_distance(p_latitude, p_longitude, dp.latitude, dp.longitude) AS distance_km,
    dp.rating,
    dp.is_verified
  FROM delivery_profiles dp
  JOIN users u ON u.user_id = dp.user_id
  WHERE dp.is_active = true
    AND dp.is_verified = true
    AND dp.latitude IS NOT NULL
    AND dp.longitude IS NOT NULL
    AND haversine_distance(p_latitude, p_longitude, dp.latitude, dp.longitude) <= p_max_distance_km
  ORDER BY distance_km
  LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."find_nearby_drivers"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_nearby_factories"("seller_id" "uuid", "max_distance_km" numeric DEFAULT 100, "limit_count" integer DEFAULT 20) RETURNS TABLE("factory_id" "uuid", "company_name" "text", "distance_km" numeric, "latitude" numeric, "longitude" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
DECLARE
  seller_lat NUMERIC;
  seller_lon NUMERIC;
BEGIN
  -- Security check
  IF auth.uid() IS NOT NULL AND auth.uid() != seller_id THEN
    RAISE EXCEPTION 'Access denied: can only search factories for your own seller account';
  END IF;

  SELECT latitude, longitude INTO seller_lat, seller_lon
  FROM sellers WHERE user_id = seller_id;

  IF seller_lat IS NULL OR seller_lon IS NULL THEN
    RAISE EXCEPTION 'Seller location not set';
  END IF;

  RETURN QUERY
  SELECT
    f.user_id, f.company_name,
    haversine_distance(seller_lat, seller_lon, f.latitude, f.longitude) AS distance_km,
    f.latitude, f.longitude
  FROM sellers f
  WHERE f.is_factory = true
  AND f.latitude IS NOT NULL AND f.longitude IS NOT NULL
  AND haversine_distance(seller_lat, seller_lon, f.latitude, f.longitude) <= max_distance_km
  ORDER BY distance_km
  LIMIT limit_count;
END;
$$;


ALTER FUNCTION "public"."find_nearby_factories"("seller_id" "uuid", "max_distance_km" numeric, "limit_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_product_description"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.description IS NULL OR NEW.description = '' THEN
    NEW.description := 
      COALESCE(NEW.title, '') || ' by ' || COALESCE(NEW.brand, '') || '. ' ||
      'Condition: ' || COALESCE(NEW.status, '') || '. ' ||
      'Category: ' || COALESCE(NEW.category, '') || 
      CASE WHEN NEW.subcategory IS NOT NULL THEN ' > ' || NEW.subcategory ELSE '' END || '. ' ||
      CASE 
        WHEN NEW.category = 'Fashion & Apparel' AND NEW.attributes ? 'color' THEN
          'Color: ' || (NEW.attributes->>'color') || '. '
        ELSE ''
      END ||
      COALESCE((
        SELECT string_agg(key || ': ' || value, ', ') 
        FROM jsonb_each_text(NEW.attributes)
        WHERE key NOT IN ('color', 'color_hex')
      ), '');
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."generate_product_description"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_factory_rating"("p_factory_id" "uuid") RETURNS TABLE("average_rating" numeric, "total_reviews" bigint, "delivery_rating" numeric, "quality_rating" numeric, "communication_rating" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_factory_rating"("p_factory_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_low_stock_products"("threshold" integer DEFAULT 10) RETURNS TABLE("id" "uuid", "asin" "text", "title" "text", "quantity" integer, "seller_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.asin, p.title, p.quantity, p.seller_id
  FROM products p
  WHERE p.quantity <= threshold
  AND p.is_deleted = false
  AND p.seller_id = auth.uid();
END;
$$;


ALTER FUNCTION "public"."get_low_stock_products"("threshold" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_seller_kpis"("p_seller_id" "uuid", "p_period" "text" DEFAULT '30d'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
DECLARE
  v_result JSONB;
  v_snapshot RECORD;
BEGIN
  -- Security check
  IF auth.uid() IS NOT NULL AND auth.uid() != p_seller_id THEN
    RAISE EXCEPTION 'Access denied: can only view own KPIs';
  END IF;

  SELECT * INTO v_snapshot
  FROM analytics_snapshots
  WHERE seller_id = p_seller_id
  AND period_type = p_period
  AND is_current = true
  AND created_at > NOW() - INTERVAL '1 hour'
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_snapshot.id IS NOT NULL THEN
    v_result := v_snapshot.analytics_data;
  ELSE
    v_result := calculate_seller_analytics(p_seller_id, p_period);
    PERFORM create_analytics_snapshot(p_seller_id, p_period);
  END IF;
  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_seller_kpis"("p_seller_id" "uuid", "p_period" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_seller_product_count"("seller_uuid" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
  -- Security check
  IF auth.uid() IS NOT NULL AND auth.uid() != seller_uuid THEN
    RAISE EXCEPTION 'Access denied: can only view own product count';
  END IF;

  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM products
    WHERE seller_id = seller_uuid AND is_deleted = false
  );
END;
$$;


ALTER FUNCTION "public"."get_seller_product_count"("seller_uuid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_seller_sales_count"("p_seller_id" "uuid", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
  -- Security check
  IF auth.uid() IS NOT NULL AND auth.uid() != p_seller_id THEN
    RAISE EXCEPTION 'Access denied: can only view own sales count';
  END IF;

  RETURN COALESCE((
    SELECT COUNT(*)
    FROM sales
    WHERE seller_id = p_seller_id
    AND sale_date BETWEEN p_start_date AND p_end_date
  ), 0);
END;
$$;


ALTER FUNCTION "public"."get_seller_sales_count"("p_seller_id" "uuid", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_seller_total_customers"("p_seller_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
  -- Security check
  IF auth.uid() IS NOT NULL AND auth.uid() != p_seller_id THEN
    RAISE EXCEPTION 'Access denied: can only view own customer count';
  END IF;

  RETURN COALESCE((
    SELECT COUNT(*)
    FROM customers
    WHERE seller_id = p_seller_id
  ), 0);
END;
$$;


ALTER FUNCTION "public"."get_seller_total_customers"("p_seller_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_seller_total_revenue"("p_seller_id" "uuid") RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
  -- Security check
  IF auth.uid() IS NOT NULL AND auth.uid() != p_seller_id THEN
    RAISE EXCEPTION 'Access denied: can only view own revenue';
  END IF;

  RETURN COALESCE((
    SELECT SUM(total_price)
    FROM sales
    WHERE seller_id = p_seller_id
  ), 0);
END;
$$;


ALTER FUNCTION "public"."get_seller_total_revenue"("p_seller_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Insert into users table
  INSERT INTO public.users (
    user_id,
    email,
    full_name,
    phone,
    account_type
  ) VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name'),
    NEW.raw_user_meta_data->>'phone',
    -- Strict check: Google logins default to 'user' unless explicitly invited
    CASE 
      WHEN NEW.raw_app_meta_data->>'provider' = 'google' THEN 'user'
      ELSE COALESCE(NEW.raw_user_meta_data->>'account_type', 'user')
    END
  );
  
  -- If seller, also create seller record
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
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."haversine_distance"("lat1" double precision, "lon1" double precision, "lat2" double precision, "lon2" double precision) RETURNS double precision
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
  R DOUBLE PRECISION = 6371; -- Earth radius in km
  dlat DOUBLE PRECISION;
  dlon DOUBLE PRECISION;
  a DOUBLE PRECISION;
  c DOUBLE PRECISION;
BEGIN
  IF lat1 IS NULL OR lon1 IS NULL OR lat2 IS NULL OR lon2 IS NULL THEN
    RETURN NULL;
  END IF;
  
  dlat := radians(lat2 - lat1);
  dlon := radians(lon2 - lon1);
  a := (sin(dlat/2))^2 + cos(radians(lat1)) * cos(radians(lat2)) * (sin(dlon/2))^2;
  c := 2 * asin(sqrt(a));
  RETURN R * c;
END;
$$;


ALTER FUNCTION "public"."haversine_distance"("lat1" double precision, "lon1" double precision, "lat2" double precision, "lon2" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."messages_tsvector_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.content_tsvector := to_tsvector('english', COALESCE(NEW.content, ''));
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."messages_tsvector_trigger"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."products_tsvector_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.title_description := to_tsvector('english', 
    COALESCE(NEW.title, '') || ' ' || 
    COALESCE(NEW.description, '') || ' ' ||
    COALESCE(NEW.brand, '') || ' ' ||
    COALESCE(NEW.category, '') || ' ' ||
    COALESCE(NEW.subcategory, ''));
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."products_tsvector_trigger"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_conversation_on_message"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NOT NEW.is_deleted THEN
    UPDATE conversations
    SET 
      last_message = CASE 
        WHEN NEW.message_type = 'image' THEN '📷 Image'
        WHEN NEW.message_type = 'file' THEN '📎 Attachment'
        ELSE NEW.content
      END,
      last_message_at = NEW.created_at,
      updated_at = NOW()
    WHERE id = NEW.conversation_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_conversation_on_message"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_customer_stats_on_sale"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.customer_id IS NOT NULL THEN
    UPDATE public.customers
    SET
      total_orders = total_orders + 1,
      total_spent = total_spent + NEW.total_price,
      last_purchase_date = NEW.sale_date,
      updated_at = NOW()
    WHERE id = NEW.customer_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_customer_stats_on_sale"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_customers_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_customers_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_factory_connections_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_factory_connections_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_order_status_timestamps"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.status = 'confirmed' AND OLD.status != 'confirmed' THEN
    NEW.confirmed_at = NOW();
  ELSIF NEW.status = 'shipped' AND OLD.status != 'shipped' THEN
    NEW.shipped_at = NOW();
  ELSIF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
    NEW.delivered_at = NOW();
  ELSIF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
    NEW.cancelled_at = NOW();
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_order_status_timestamps"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_products_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_products_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_sales_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_sales_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."admin_users" (
    "user_id" "uuid" NOT NULL
);


ALTER TABLE "public"."admin_users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."analytics" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "seller_id" "uuid",
    "metric_type" "text" NOT NULL,
    "metric_value" numeric(10,2) NOT NULL,
    "metric_date" "date" NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."analytics" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."analytics_snapshots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "seller_id" "uuid" NOT NULL,
    "period_type" "text" NOT NULL,
    "period_start" "date" NOT NULL,
    "period_end" "date" NOT NULL,
    "analytics_data" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "is_current" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "analytics_snapshots_period_type_check" CHECK (("period_type" = ANY (ARRAY['daily'::"text", 'weekly'::"text", 'monthly'::"text", 'yearly'::"text", 'custom'::"text"])))
);


ALTER TABLE "public"."analytics_snapshots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."async_jobs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "queue_name" "text" NOT NULL,
    "payload" "jsonb" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text",
    "attempts" integer DEFAULT 0,
    "max_attempts" integer DEFAULT 3,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "processed_at" timestamp with time zone,
    "error_message" "text",
    "scheduled_for" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "async_jobs_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'completed'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."async_jobs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."brands" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "category" "text",
    "logo_url" "text",
    "is_verified" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."brands" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."business_profiles" (
    "user_id" "uuid" NOT NULL,
    "role" "public"."user_role" NOT NULL,
    "company_name" "text",
    "location" "text",
    "latitude" numeric(10,8),
    "longitude" numeric(10,8),
    "currency" "text" DEFAULT 'USD'::"text",
    "is_verified" boolean DEFAULT false,
    "store_name" "text",
    "commission_rate" numeric(5,2),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."business_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cart" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "asin" "text" NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."cart" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."categories" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "parent_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "slug" "text",
    "description" "text",
    "image_url" "text",
    "display_order" integer DEFAULT 0,
    "is_active" boolean DEFAULT true
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."categories_backup_20260308_124506" (
    "id" "uuid",
    "name" "text",
    "parent_id" "uuid",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone
);


ALTER TABLE "public"."categories_backup_20260308_124506" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conversation_participants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "public"."user_role" NOT NULL,
    "last_read_message_id" "uuid",
    "is_muted" boolean DEFAULT false,
    "joined_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."conversation_participants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "last_message" "text",
    "last_message_at" timestamp with time zone,
    "is_archived" boolean DEFAULT false
);


ALTER TABLE "public"."conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customers" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid",
    "name" "text" NOT NULL,
    "phone" "text" NOT NULL,
    "age_range" "text",
    "email" "text",
    "notes" "text",
    "total_orders" integer DEFAULT 0,
    "total_spent" numeric(10,2) DEFAULT 0,
    "last_purchase_date" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "customers_age_range_check" CHECK (("age_range" = ANY (ARRAY['teens'::"text", '20s'::"text", '30s'::"text", '40s'::"text", '50s'::"text", '60s'::"text", '70s+'::"text"])))
);


ALTER TABLE "public"."customers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "seller_id" "uuid" NOT NULL,
    "customer_id" "uuid",
    "product_id" "uuid",
    "quantity" integer DEFAULT 1 NOT NULL,
    "unit_price" numeric(10,2) NOT NULL,
    "total_price" numeric(10,2) NOT NULL,
    "discount" numeric(10,2) DEFAULT 0.00,
    "sale_date" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "valid_discount" CHECK ((("discount" >= (0)::numeric) AND ("discount" <= "total_price"))),
    CONSTRAINT "valid_quantity" CHECK (("quantity" > 0)),
    CONSTRAINT "valid_total_price" CHECK (("total_price" >= (0)::numeric)),
    CONSTRAINT "valid_unit_price" CHECK (("unit_price" >= (0)::numeric))
);


ALTER TABLE "public"."sales" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."daily_sales_summary" AS
 SELECT "seller_id",
    "date"("sale_date") AS "sale_day",
    "count"(*) AS "total_sales",
    "sum"("total_price") AS "total_revenue",
    "sum"("quantity") AS "total_items",
    "avg"("total_price") AS "average_order_value",
    "count"(DISTINCT "customer_id") AS "unique_customers"
   FROM "public"."sales"
  GROUP BY "seller_id", ("date"("sale_date"));


ALTER VIEW "public"."daily_sales_summary" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."deals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "middleman_id" "uuid" NOT NULL,
    "party_a_id" "uuid" NOT NULL,
    "party_b_id" "uuid" NOT NULL,
    "product_id" "uuid",
    "commission_rate" numeric(5,2),
    "status" "text" DEFAULT 'active'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "valid_commission_rate" CHECK ((("commission_rate" >= (0)::numeric) AND ("commission_rate" <= (100)::numeric)))
);


ALTER TABLE "public"."deals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."delivery_assignments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid",
    "driver_id" "uuid",
    "assigned_at" timestamp with time zone DEFAULT "now"(),
    "picked_up_at" timestamp with time zone,
    "delivered_at" timestamp with time zone,
    "status" "text" DEFAULT 'pending'::"text",
    "delivery_fee" numeric(10,2),
    "distance_km" numeric(10,2),
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "delivery_assignments_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'accepted'::"text", 'picked_up'::"text", 'delivered'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."delivery_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."delivery_profiles" (
    "user_id" "uuid" NOT NULL,
    "vehicle_type" "text",
    "vehicle_number" "text",
    "driver_license_url" "text",
    "is_verified" boolean DEFAULT false,
    "is_active" boolean DEFAULT false,
    "latitude" numeric(10,8),
    "longitude" numeric(10,8),
    "rating" numeric(3,2) DEFAULT 0,
    "total_deliveries" integer DEFAULT 0,
    "completed_deliveries" integer DEFAULT 0,
    "cancelled_deliveries" integer DEFAULT 0,
    "commission_rate" numeric(5,2) DEFAULT 10,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "delivery_profiles_vehicle_type_check" CHECK (("vehicle_type" = ANY (ARRAY['motorcycle'::"text", 'car'::"text", 'bicycle'::"text", 'van'::"text", 'truck'::"text"])))
);


ALTER TABLE "public"."delivery_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."factory_connections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "factory_id" "uuid",
    "seller_id" "uuid",
    "status" "text" DEFAULT 'pending'::"text",
    "requested_at" timestamp with time zone DEFAULT "now"(),
    "accepted_at" timestamp with time zone,
    "rejected_at" timestamp with time zone,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "factory_connections_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'accepted'::"text", 'rejected'::"text", 'blocked'::"text"])))
);


ALTER TABLE "public"."factory_connections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "asin" "text",
    "sku" "text",
    "seller_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text" NOT NULL,
    "brand" "text" NOT NULL,
    "currency" "text" DEFAULT 'USD'::"text",
    "price" numeric(10,2),
    "quantity" integer DEFAULT 0,
    "status" "text" DEFAULT 'draft'::"text",
    "brand_id" "text",
    "is_local_brand" boolean DEFAULT false,
    "attributes" "jsonb" DEFAULT '{}'::"jsonb",
    "color_hex" "text",
    "category" "text",
    "subcategory" "text",
    "images" "jsonb" DEFAULT '[]'::"jsonb",
    "average_rating" numeric(3,2) DEFAULT 0,
    "review_count" integer DEFAULT 0,
    "title_description" "tsvector",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "allow_chat" boolean DEFAULT true,
    CONSTRAINT "products_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'active'::"text", 'inactive'::"text"]))),
    CONSTRAINT "valid_price" CHECK ((("price" IS NULL) OR ("price" >= (0)::numeric))),
    CONSTRAINT "valid_quantity" CHECK (("quantity" >= 0))
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sellers" (
    "user_id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "full_name" "text" NOT NULL,
    "firstname" "text",
    "second_name" "text",
    "thirdname" "text",
    "fourth_name" "text",
    "phone" "text",
    "location" "text",
    "currency" "text" DEFAULT 'USD'::"text",
    "account_type" "text" DEFAULT 'seller'::"text",
    "is_verified" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "latitude" numeric(10,8),
    "longitude" numeric(11,8),
    "is_factory" boolean DEFAULT false,
    "factory_license_url" "text",
    "min_order_quantity" integer DEFAULT 1,
    "wholesale_discount" numeric(5,2) DEFAULT 0,
    "accepts_returns" boolean DEFAULT true,
    "production_capacity" "text",
    "verified_at" timestamp with time zone
);


ALTER TABLE "public"."sellers" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."factory_products" AS
 SELECT "p"."id",
    "p"."asin",
    "p"."sku",
    "p"."seller_id",
    "p"."title",
    "p"."description",
    "p"."brand",
    "p"."currency",
    "p"."price",
    "p"."quantity",
    "p"."status",
    "p"."brand_id",
    "p"."is_local_brand",
    "p"."attributes",
    "p"."color_hex",
    "p"."category",
    "p"."subcategory",
    "p"."images",
    "p"."average_rating",
    "p"."review_count",
    "p"."title_description",
    "p"."created_at",
    "p"."updated_at",
    "s"."full_name" AS "factory_name",
    "s"."location" AS "factory_location",
    "s"."latitude",
    "s"."longitude",
    "s"."wholesale_discount",
    "s"."min_order_quantity",
    ("p"."price" * ((1)::numeric - (COALESCE("s"."wholesale_discount", (0)::numeric) / (100)::numeric))) AS "wholesale_price"
   FROM ("public"."products" "p"
     JOIN "public"."sellers" "s" ON (("p"."seller_id" = "s"."user_id")))
  WHERE (("s"."is_factory" = true) AND ("p"."status" = 'active'::"text") AND ("p"."is_local_brand" = true));


ALTER VIEW "public"."factory_products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."factory_ratings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "factory_id" "uuid",
    "seller_id" "uuid",
    "rating" integer,
    "review" "text",
    "delivery_rating" integer,
    "quality_rating" integer,
    "communication_rating" integer,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "factory_ratings_check" CHECK ((("quality_rating" >= 1) AND ("delivery_rating" <= 5))),
    CONSTRAINT "factory_ratings_communication_rating_check" CHECK ((("communication_rating" >= 1) AND ("communication_rating" <= 5))),
    CONSTRAINT "factory_ratings_delivery_rating_check" CHECK ((("delivery_rating" >= 1) AND ("delivery_rating" <= 5))),
    CONSTRAINT "factory_ratings_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."factory_ratings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."idempotency_keys" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "key" "text" NOT NULL,
    "response" "jsonb" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."idempotency_keys" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "content" "text",
    "message_type" "text" DEFAULT 'text'::"text",
    "attachment_url" "text",
    "attachment_name" "text",
    "attachment_size" bigint,
    "is_deleted" boolean DEFAULT false,
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "content_tsvector" "tsvector",
    CONSTRAINT "messages_message_type_check" CHECK (("message_type" = ANY (ARRAY['text'::"text", 'image'::"text", 'file'::"text"])))
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."middleman_profiles" (
    "user_id" "uuid" NOT NULL,
    "company_name" "text",
    "location" "text",
    "latitude" numeric(10,8),
    "longitude" numeric(10,8),
    "currency" "text" DEFAULT 'USD'::"text",
    "commission_rate" numeric(5,2),
    "is_verified" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."middleman_profiles" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."monthly_sales_summary" AS
 SELECT "seller_id",
    "date_trunc"('month'::"text", "sale_date") AS "sale_month",
    "count"(*) AS "total_sales",
    "sum"("total_price") AS "total_revenue",
    "sum"("quantity") AS "total_items",
    "avg"("total_price") AS "average_order_value",
    "count"(DISTINCT "customer_id") AS "unique_customers"
   FROM "public"."sales"
  GROUP BY "seller_id", ("date_trunc"('month'::"text", "sale_date"));


ALTER VIEW "public"."monthly_sales_summary" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "text",
    "title" "text" NOT NULL,
    "message" "text" NOT NULL,
    "is_read" boolean DEFAULT false,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "notifications_type_check" CHECK (("type" = ANY (ARRAY['order'::"text", 'product'::"text", 'system'::"text", 'promotion'::"text", 'message'::"text"])))
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."order_items" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "product_id" "uuid",
    "asin" "text" NOT NULL,
    "product_name" "text" NOT NULL,
    "product_image" "text",
    "brand" "text",
    "quantity" integer DEFAULT 1 NOT NULL,
    "unit_price" numeric(10,2) NOT NULL,
    "total_price" numeric(10,2) NOT NULL,
    "attributes" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "valid_price" CHECK (("unit_price" >= (0)::numeric)),
    CONSTRAINT "valid_quantity" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."order_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."orders" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "seller_id" "uuid",
    "status" "text" DEFAULT 'pending'::"text",
    "subtotal" numeric(10,2) DEFAULT 0 NOT NULL,
    "discount" numeric(10,2) DEFAULT 0,
    "tax" numeric(10,2) DEFAULT 0,
    "shipping" numeric(10,2) DEFAULT 0,
    "total" numeric(10,2) DEFAULT 0 NOT NULL,
    "payment_method" "text" DEFAULT 'cash'::"text",
    "payment_status" "text" DEFAULT 'pending'::"text",
    "payment_intent_id" "text",
    "shipping_address_id" "uuid",
    "shipping_address_snapshot" "jsonb",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "confirmed_at" timestamp with time zone,
    "shipped_at" timestamp with time zone,
    "delivered_at" timestamp with time zone,
    "cancelled_at" timestamp with time zone,
    "deal_id" "uuid",
    "commission_rate" numeric(5,2),
    "commission_amount" numeric(10,2),
    "delivery_id" "uuid",
    "delivery_status" "text" DEFAULT 'pending'::"text",
    "picked_up_at" timestamp with time zone,
    "delivery_notes" "text",
    "delivery_fee" numeric(10,2),
    CONSTRAINT "orders_delivery_status_check" CHECK (("delivery_status" = ANY (ARRAY['pending'::"text", 'assigned'::"text", 'picked_up'::"text", 'in_transit'::"text", 'delivered'::"text", 'failed'::"text"]))),
    CONSTRAINT "orders_payment_method_check" CHECK (("payment_method" = ANY (ARRAY['cash'::"text", 'card'::"text", 'bank_transfer'::"text", 'digital_wallet'::"text", 'cod'::"text"]))),
    CONSTRAINT "orders_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['pending'::"text", 'completed'::"text", 'failed'::"text", 'refunded'::"text"]))),
    CONSTRAINT "orders_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'confirmed'::"text", 'processing'::"text", 'shipped'::"text", 'out_for_delivery'::"text", 'delivered'::"text", 'cancelled'::"text", 'refunded'::"text"]))),
    CONSTRAINT "valid_subtotal" CHECK (("subtotal" >= (0)::numeric)),
    CONSTRAINT "valid_total" CHECK (("total" >= (0)::numeric))
);


ALTER TABLE "public"."orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payment_intentions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "order_id" "uuid",
    "user_id" "uuid",
    "amount" numeric(10,2) NOT NULL,
    "currency" "text" DEFAULT 'USD'::"text",
    "status" "text",
    "payment_method" "text",
    "payment_intent_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "payment_intentions_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'succeeded'::"text", 'failed'::"text", 'refunded'::"text"])))
);


ALTER TABLE "public"."payment_intentions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."push_subscriptions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "token" "text" NOT NULL,
    "platform" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "push_subscriptions_platform_check" CHECK (("platform" = ANY (ARRAY['ios'::"text", 'android'::"text", 'web'::"text"])))
);


ALTER TABLE "public"."push_subscriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reviews" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "asin" "text" NOT NULL,
    "order_id" "uuid",
    "rating" integer NOT NULL,
    "title" "text",
    "comment" "text",
    "is_verified_purchase" boolean DEFAULT false,
    "is_approved" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "reviews_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."seller_profiles" (
    "id" "uuid" NOT NULL,
    "store_name" "text",
    "currency" "text" DEFAULT 'USD'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."seller_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sellers_backup" (
    "user_id" "uuid",
    "email" "text",
    "full_name" "text",
    "firstname" "text",
    "second_name" "text",
    "thirdname" "text",
    "fourth_name" "text",
    "phone" "text",
    "location" "text",
    "currency" "text",
    "account_type" "text",
    "is_verified" boolean,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "latitude" numeric(10,8),
    "longitude" numeric(11,8),
    "is_factory" boolean,
    "factory_license_url" "text",
    "min_order_quantity" integer,
    "wholesale_discount" numeric(5,2),
    "accepts_returns" boolean,
    "production_capacity" "text",
    "verified_at" timestamp with time zone
);


ALTER TABLE "public"."sellers_backup" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shipping_addresses" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "full_name" "text" NOT NULL,
    "address_line1" "text" NOT NULL,
    "address_line2" "text",
    "city" "text" NOT NULL,
    "state" "text" NOT NULL,
    "postal_code" "text" NOT NULL,
    "country" "text" DEFAULT 'EG'::"text" NOT NULL,
    "phone" "text" NOT NULL,
    "is_default" boolean DEFAULT false,
    "is_verified" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."shipping_addresses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."subcategories" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "category_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "attribute_schema" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."subcategories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "full_name" "text",
    "phone" "text",
    "avatar_url" "text",
    "account_type" "text" DEFAULT 'user'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wishlist" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "asin" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."wishlist" OWNER TO "postgres";


ALTER TABLE ONLY "public"."admin_users"
    ADD CONSTRAINT "admin_users_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."analytics"
    ADD CONSTRAINT "analytics_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."analytics_snapshots"
    ADD CONSTRAINT "analytics_snapshots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."async_jobs"
    ADD CONSTRAINT "async_jobs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."brands"
    ADD CONSTRAINT "brands_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."brands"
    ADD CONSTRAINT "brands_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."business_profiles"
    ADD CONSTRAINT "business_profiles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."cart"
    ADD CONSTRAINT "cart_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cart"
    ADD CONSTRAINT "cart_user_id_asin_key" UNIQUE ("user_id", "asin");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_conversation_id_user_id_key" UNIQUE ("conversation_id", "user_id");



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."delivery_assignments"
    ADD CONSTRAINT "delivery_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."delivery_profiles"
    ADD CONSTRAINT "delivery_profiles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."factory_connections"
    ADD CONSTRAINT "factory_connections_factory_id_seller_id_key" UNIQUE ("factory_id", "seller_id");



ALTER TABLE ONLY "public"."factory_connections"
    ADD CONSTRAINT "factory_connections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."factory_ratings"
    ADD CONSTRAINT "factory_ratings_factory_id_seller_id_key" UNIQUE ("factory_id", "seller_id");



ALTER TABLE ONLY "public"."factory_ratings"
    ADD CONSTRAINT "factory_ratings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."idempotency_keys"
    ADD CONSTRAINT "idempotency_keys_key_key" UNIQUE ("key");



ALTER TABLE ONLY "public"."idempotency_keys"
    ADD CONSTRAINT "idempotency_keys_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."middleman_profiles"
    ADD CONSTRAINT "middleman_profiles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payment_intentions"
    ADD CONSTRAINT "payment_intentions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_asin_key" UNIQUE ("asin");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."push_subscriptions"
    ADD CONSTRAINT "push_subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."push_subscriptions"
    ADD CONSTRAINT "push_subscriptions_user_id_token_key" UNIQUE ("user_id", "token");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_user_id_asin_key" UNIQUE ("user_id", "asin");



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."seller_profiles"
    ADD CONSTRAINT "seller_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sellers"
    ADD CONSTRAINT "sellers_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."sellers"
    ADD CONSTRAINT "sellers_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."shipping_addresses"
    ADD CONSTRAINT "shipping_addresses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shipping_addresses"
    ADD CONSTRAINT "shipping_addresses_user_id_is_default_key" UNIQUE ("user_id", "is_default");



ALTER TABLE ONLY "public"."subcategories"
    ADD CONSTRAINT "subcategories_category_id_name_key" UNIQUE ("category_id", "name");



ALTER TABLE ONLY "public"."subcategories"
    ADD CONSTRAINT "subcategories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."analytics_snapshots"
    ADD CONSTRAINT "unique_seller_period" UNIQUE ("seller_id", "period_type", "period_start", "period_end");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."wishlist"
    ADD CONSTRAINT "wishlist_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."wishlist"
    ADD CONSTRAINT "wishlist_user_id_asin_key" UNIQUE ("user_id", "asin");



CREATE INDEX "idx_analytics_is_current" ON "public"."analytics_snapshots" USING "btree" ("is_current") WHERE ("is_current" = true);



CREATE INDEX "idx_analytics_period_start" ON "public"."analytics_snapshots" USING "btree" ("period_start" DESC);



CREATE INDEX "idx_analytics_period_type" ON "public"."analytics_snapshots" USING "btree" ("period_type");



CREATE INDEX "idx_analytics_seller_id" ON "public"."analytics_snapshots" USING "btree" ("seller_id");



CREATE INDEX "idx_assignments_driver" ON "public"."delivery_assignments" USING "btree" ("driver_id");



CREATE INDEX "idx_assignments_order" ON "public"."delivery_assignments" USING "btree" ("order_id");



CREATE INDEX "idx_async_jobs_queue_status" ON "public"."async_jobs" USING "btree" ("queue_name", "status", "scheduled_for");



CREATE INDEX "idx_async_jobs_scheduled" ON "public"."async_jobs" USING "btree" ("scheduled_for") WHERE ("status" = 'pending'::"text");



CREATE INDEX "idx_cart_user_id" ON "public"."cart" USING "btree" ("user_id");



CREATE INDEX "idx_categories_parent" ON "public"."categories" USING "btree" ("parent_id");



CREATE INDEX "idx_categories_slug" ON "public"."categories" USING "btree" ("slug");



CREATE INDEX "idx_conversations_product_id" ON "public"."conversations" USING "btree" ("product_id");



CREATE INDEX "idx_conversations_updated_at" ON "public"."conversations" USING "btree" ("updated_at" DESC);



CREATE INDEX "idx_customers_age_range" ON "public"."customers" USING "btree" ("age_range");



CREATE INDEX "idx_customers_user_id" ON "public"."customers" USING "btree" ("user_id");



CREATE INDEX "idx_delivery_location" ON "public"."delivery_profiles" USING "btree" ("latitude", "longitude") WHERE (("is_active" = true) AND ("is_verified" = true));



CREATE INDEX "idx_factory_connections_factory" ON "public"."factory_connections" USING "btree" ("factory_id");



CREATE INDEX "idx_factory_connections_seller" ON "public"."factory_connections" USING "btree" ("seller_id");



CREATE INDEX "idx_factory_connections_status" ON "public"."factory_connections" USING "btree" ("status");



CREATE INDEX "idx_factory_ratings_factory" ON "public"."factory_ratings" USING "btree" ("factory_id");



CREATE INDEX "idx_idempotency_keys_expires" ON "public"."idempotency_keys" USING "btree" ("expires_at");



CREATE INDEX "idx_idempotency_keys_key" ON "public"."idempotency_keys" USING "btree" ("key");



CREATE INDEX "idx_messages_conversation_id" ON "public"."messages" USING "btree" ("conversation_id", "created_at" DESC);



CREATE INDEX "idx_messages_read_at" ON "public"."messages" USING "btree" ("read_at") WHERE ("read_at" IS NULL);



CREATE INDEX "idx_messages_search" ON "public"."messages" USING "gin" ("content_tsvector");



CREATE INDEX "idx_messages_sender_id" ON "public"."messages" USING "btree" ("sender_id");



CREATE INDEX "idx_order_items_asin" ON "public"."order_items" USING "btree" ("asin");



CREATE INDEX "idx_order_items_order_id" ON "public"."order_items" USING "btree" ("order_id");



CREATE INDEX "idx_orders_created_at" ON "public"."orders" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_orders_seller_id" ON "public"."orders" USING "btree" ("seller_id");



CREATE INDEX "idx_orders_status" ON "public"."orders" USING "btree" ("status");



CREATE INDEX "idx_orders_user_id" ON "public"."orders" USING "btree" ("user_id");



CREATE INDEX "idx_participants_conversation_id" ON "public"."conversation_participants" USING "btree" ("conversation_id");



CREATE INDEX "idx_participants_user_id" ON "public"."conversation_participants" USING "btree" ("user_id");



CREATE INDEX "idx_products_attributes" ON "public"."products" USING "gin" ("attributes");



CREATE INDEX "idx_products_brand" ON "public"."products" USING "btree" ("brand");



CREATE INDEX "idx_products_category" ON "public"."products" USING "btree" ("category");



CREATE INDEX "idx_products_created_at" ON "public"."products" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_products_price" ON "public"."products" USING "btree" ("price");



CREATE INDEX "idx_products_search" ON "public"."products" USING "gin" ("title_description");



CREATE INDEX "idx_products_seller_id" ON "public"."products" USING "btree" ("seller_id");



CREATE INDEX "idx_products_status" ON "public"."products" USING "btree" ("status");



CREATE INDEX "idx_products_subcategory" ON "public"."products" USING "btree" ("subcategory");



CREATE INDEX "idx_reviews_asin" ON "public"."reviews" USING "btree" ("asin");



CREATE INDEX "idx_reviews_user_id" ON "public"."reviews" USING "btree" ("user_id");



CREATE INDEX "idx_sales_customer_id" ON "public"."sales" USING "btree" ("customer_id");



CREATE INDEX "idx_sales_date" ON "public"."sales" USING "btree" ("sale_date" DESC);



CREATE INDEX "idx_sales_product_id" ON "public"."sales" USING "btree" ("product_id");



CREATE INDEX "idx_sales_seller_date" ON "public"."sales" USING "btree" ("seller_id", "sale_date" DESC);



CREATE INDEX "idx_sales_seller_id" ON "public"."sales" USING "btree" ("seller_id");



CREATE INDEX "idx_sellers_location" ON "public"."sellers" USING "btree" ("latitude", "longitude");



CREATE INDEX "idx_subcategories_category" ON "public"."subcategories" USING "btree" ("category_id");



CREATE INDEX "idx_users_email" ON "public"."users" USING "btree" ("email");



CREATE INDEX "idx_users_user_id" ON "public"."users" USING "btree" ("user_id");



CREATE INDEX "idx_wishlist_user_id" ON "public"."wishlist" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "decrement_inventory_on_order_item" AFTER INSERT ON "public"."order_items" FOR EACH ROW EXECUTE FUNCTION "public"."decrement_product_inventory"();



CREATE OR REPLACE TRIGGER "generate_product_description_trigger" BEFORE INSERT OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."generate_product_description"();



CREATE OR REPLACE TRIGGER "products_tsvector_update" BEFORE INSERT OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."products_tsvector_trigger"();



CREATE OR REPLACE TRIGGER "trigger_calculate_commission" BEFORE INSERT OR UPDATE OF "deal_id", "subtotal" ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_order_commission"();



CREATE OR REPLACE TRIGGER "trigger_messages_tsvector" BEFORE INSERT OR UPDATE ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."messages_tsvector_trigger"();



CREATE OR REPLACE TRIGGER "trigger_update_conversation_on_message" AFTER INSERT ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."update_conversation_on_message"();



CREATE OR REPLACE TRIGGER "trigger_update_customer_stats_on_sale" AFTER INSERT ON "public"."sales" FOR EACH ROW EXECUTE FUNCTION "public"."update_customer_stats_on_sale"();



CREATE OR REPLACE TRIGGER "trigger_update_factory_connections_timestamp" BEFORE UPDATE ON "public"."factory_connections" FOR EACH ROW EXECUTE FUNCTION "public"."update_factory_connections_timestamp"();



CREATE OR REPLACE TRIGGER "trigger_update_sales_timestamp" BEFORE UPDATE ON "public"."sales" FOR EACH ROW EXECUTE FUNCTION "public"."update_sales_timestamp"();



CREATE OR REPLACE TRIGGER "update_brands_updated_at" BEFORE UPDATE ON "public"."brands" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_cart_updated_at" BEFORE UPDATE ON "public"."cart" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_categories_updated_at" BEFORE UPDATE ON "public"."categories" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_customers_updated_at" BEFORE UPDATE ON "public"."customers" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_order_status_timestamps" BEFORE UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."update_order_status_timestamps"();



CREATE OR REPLACE TRIGGER "update_orders_updated_at" BEFORE UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_products_updated_at" BEFORE UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_seller_profiles_updated_at" BEFORE UPDATE ON "public"."seller_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_sellers_updated_at" BEFORE UPDATE ON "public"."sellers" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shipping_addresses_updated_at" BEFORE UPDATE ON "public"."shipping_addresses" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_subcategories_updated_at" BEFORE UPDATE ON "public"."subcategories" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."admin_users"
    ADD CONSTRAINT "admin_users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."analytics"
    ADD CONSTRAINT "analytics_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."analytics_snapshots"
    ADD CONSTRAINT "analytics_snapshots_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."business_profiles"
    ADD CONSTRAINT "business_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."cart"
    ADD CONSTRAINT "cart_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."categories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_last_read_message_id_fkey" FOREIGN KEY ("last_read_message_id") REFERENCES "public"."messages"("id");



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_middleman_id_fkey" FOREIGN KEY ("middleman_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_party_a_id_fkey" FOREIGN KEY ("party_a_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_party_b_id_fkey" FOREIGN KEY ("party_b_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."delivery_assignments"
    ADD CONSTRAINT "delivery_assignments_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "public"."delivery_profiles"("user_id");



ALTER TABLE ONLY "public"."delivery_assignments"
    ADD CONSTRAINT "delivery_assignments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."delivery_profiles"
    ADD CONSTRAINT "delivery_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factory_connections"
    ADD CONSTRAINT "factory_connections_factory_id_fkey" FOREIGN KEY ("factory_id") REFERENCES "public"."sellers"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factory_connections"
    ADD CONSTRAINT "factory_connections_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "public"."sellers"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factory_ratings"
    ADD CONSTRAINT "factory_ratings_factory_id_fkey" FOREIGN KEY ("factory_id") REFERENCES "public"."sellers"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factory_ratings"
    ADD CONSTRAINT "factory_ratings_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "public"."sellers"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."middleman_profiles"
    ADD CONSTRAINT "middleman_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_delivery_id_fkey" FOREIGN KEY ("delivery_id") REFERENCES "public"."delivery_profiles"("user_id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_shipping_address_id_fkey" FOREIGN KEY ("shipping_address_id") REFERENCES "public"."shipping_addresses"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payment_intentions"
    ADD CONSTRAINT "payment_intentions_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payment_intentions"
    ADD CONSTRAINT "payment_intentions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."push_subscriptions"
    ADD CONSTRAINT "push_subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."seller_profiles"
    ADD CONSTRAINT "seller_profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sellers"
    ADD CONSTRAINT "sellers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shipping_addresses"
    ADD CONSTRAINT "shipping_addresses_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."subcategories"
    ADD CONSTRAINT "subcategories_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."wishlist"
    ADD CONSTRAINT "wishlist_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Categories are publicly viewable" ON "public"."categories" FOR SELECT USING (("is_active" = true));



CREATE POLICY "Middlemen can manage their deals" ON "public"."deals" USING (("auth"."uid"() = "middleman_id"));



CREATE POLICY "Participants can view deals" ON "public"."deals" FOR SELECT USING ((("auth"."uid"() = "party_a_id") OR ("auth"."uid"() = "party_b_id")));



CREATE POLICY "Users can update own profile" ON "public"."users" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own profile" ON "public"."users" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "analytics_seller_own" ON "public"."analytics_snapshots" TO "authenticated" USING (("seller_id" = "auth"."uid"())) WITH CHECK (("seller_id" = "auth"."uid"()));



ALTER TABLE "public"."analytics_snapshots" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "anyone_view_factory_ratings" ON "public"."factory_ratings" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."cart" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."conversation_participants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."conversations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "conversations_insert_own" ON "public"."conversations" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "conversations_view_own" ON "public"."conversations" FOR SELECT TO "authenticated" USING (("id" IN ( SELECT "conversation_participants"."conversation_id"
   FROM "public"."conversation_participants"
  WHERE ("conversation_participants"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."customers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "customers_view_active_products" ON "public"."products" FOR SELECT TO "authenticated" USING (("status" = 'active'::"text"));



ALTER TABLE "public"."deals" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "delivery_manage_own_assignments" ON "public"."delivery_assignments" TO "authenticated" USING (("driver_id" = "auth"."uid"())) WITH CHECK (("driver_id" = "auth"."uid"()));



CREATE POLICY "delivery_update_location" ON "public"."delivery_profiles" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "delivery_update_own" ON "public"."delivery_profiles" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "delivery_view_assigned_orders" ON "public"."orders" FOR SELECT TO "authenticated" USING ((("delivery_id" = "auth"."uid"()) OR ("seller_id" = "auth"."uid"()) OR ("user_id" = "auth"."uid"())));



CREATE POLICY "delivery_view_own" ON "public"."delivery_profiles" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "everyone_view_approved_reviews" ON "public"."reviews" FOR SELECT TO "authenticated" USING (("is_approved" = true));



CREATE POLICY "factories_update_own_connections" ON "public"."factory_connections" FOR UPDATE TO "authenticated" USING (("factory_id" = "auth"."uid"())) WITH CHECK (("factory_id" = "auth"."uid"()));



ALTER TABLE "public"."factory_connections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."factory_ratings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."idempotency_keys" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "idempotency_keys_user_own" ON "public"."idempotency_keys" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "messages_insert_own" ON "public"."messages" FOR INSERT TO "authenticated" WITH CHECK (("sender_id" = "auth"."uid"()));



CREATE POLICY "messages_update_own" ON "public"."messages" FOR UPDATE TO "authenticated" USING (("sender_id" = "auth"."uid"())) WITH CHECK (("sender_id" = "auth"."uid"()));



CREATE POLICY "messages_view_own" ON "public"."messages" FOR SELECT TO "authenticated" USING (("conversation_id" IN ( SELECT "conversation_participants"."conversation_id"
   FROM "public"."conversation_participants"
  WHERE ("conversation_participants"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "participants_insert_own" ON "public"."conversation_participants" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "participants_view_own" ON "public"."conversation_participants" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sales" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sales_seller_own" ON "public"."sales" TO "authenticated" USING (("seller_id" = "auth"."uid"())) WITH CHECK (("seller_id" = "auth"."uid"()));



ALTER TABLE "public"."seller_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sellers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sellers_create_factory_connections" ON "public"."factory_connections" FOR INSERT TO "authenticated" WITH CHECK (("seller_id" = "auth"."uid"()));



CREATE POLICY "sellers_create_factory_ratings" ON "public"."factory_ratings" FOR INSERT TO "authenticated" WITH CHECK (("seller_id" = "auth"."uid"()));



CREATE POLICY "sellers_manage_own_products" ON "public"."products" TO "authenticated" USING (("seller_id" = "auth"."uid"())) WITH CHECK (("seller_id" = "auth"."uid"()));



CREATE POLICY "sellers_view_own_customers" ON "public"."customers" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "sellers_view_own_factory_connections" ON "public"."factory_connections" FOR SELECT TO "authenticated" USING ((("seller_id" = "auth"."uid"()) OR ("factory_id" = "auth"."uid"())));



CREATE POLICY "sellers_view_own_orders" ON "public"."orders" FOR SELECT TO "authenticated" USING (("seller_id" = "auth"."uid"()));



ALTER TABLE "public"."shipping_addresses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_create_own_reviews" ON "public"."reviews" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_delete_own_reviews" ON "public"."reviews" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "users_insert_own_profile" ON "public"."seller_profiles" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "users_manage_own_addresses" ON "public"."shipping_addresses" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_manage_own_cart" ON "public"."cart" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_manage_own_customer" ON "public"."customers" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_manage_own_notifications" ON "public"."notifications" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_manage_own_orders" ON "public"."orders" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_manage_own_seller" ON "public"."sellers" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_manage_own_wishlist" ON "public"."wishlist" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_update_own_profile" ON "public"."seller_profiles" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "id"));



CREATE POLICY "users_update_own_reviews" ON "public"."reviews" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "users_view_own_profile" ON "public"."seller_profiles" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "id"));



CREATE POLICY "users_view_own_seller" ON "public"."sellers" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "view_order_items" ON "public"."order_items" FOR SELECT TO "authenticated" USING (("order_id" IN ( SELECT "orders"."id"
   FROM "public"."orders"
  WHERE (("orders"."user_id" = "auth"."uid"()) OR ("orders"."seller_id" = "auth"."uid"())))));



ALTER TABLE "public"."wishlist" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";


















































































































































































































GRANT ALL ON FUNCTION "public"."assign_delivery_to_driver"("p_order_id" "uuid", "p_seller_latitude" numeric, "p_seller_longitude" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."assign_delivery_to_driver"("p_order_id" "uuid", "p_seller_latitude" numeric, "p_seller_longitude" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."assign_delivery_to_driver"("p_order_id" "uuid", "p_seller_latitude" numeric, "p_seller_longitude" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_distance"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_distance"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_distance"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_order_commission"() TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_order_commission"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_order_commission"() TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_seller_analytics"("p_seller_id" "uuid", "p_period_type" "text", "p_start_date" "date", "p_end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_seller_analytics"("p_seller_id" "uuid", "p_period_type" "text", "p_start_date" "date", "p_end_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_start_conversation"("from_user_id" "uuid", "to_user_id" "uuid", "product_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_start_conversation"("from_user_id" "uuid", "to_user_id" "uuid", "product_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_expired_idempotency_keys"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_expired_idempotency_keys"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_expired_idempotency_keys"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_analytics_snapshot"("p_seller_id" "uuid", "p_period_type" "text", "p_start_date" "date", "p_end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_analytics_snapshot"("p_seller_id" "uuid", "p_period_type" "text", "p_start_date" "date", "p_end_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."decrement_product_inventory"() TO "anon";
GRANT ALL ON FUNCTION "public"."decrement_product_inventory"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrement_product_inventory"() TO "service_role";



GRANT ALL ON FUNCTION "public"."dequeue_job"("p_queue_name" "text", "p_visibility_timeout_seconds" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."dequeue_job"("p_queue_name" "text", "p_visibility_timeout_seconds" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dequeue_job"("p_queue_name" "text", "p_visibility_timeout_seconds" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."enqueue_job"("p_queue_name" "text", "p_payload" "jsonb", "p_scheduled_for" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."enqueue_job"("p_queue_name" "text", "p_payload" "jsonb", "p_scheduled_for" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."enqueue_job"("p_queue_name" "text", "p_payload" "jsonb", "p_scheduled_for" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."find_nearby_drivers"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."find_nearby_drivers"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_nearby_drivers"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."find_nearby_factories"("seller_id" "uuid", "max_distance_km" numeric, "limit_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_nearby_factories"("seller_id" "uuid", "max_distance_km" numeric, "limit_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_product_description"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_product_description"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_product_description"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_factory_rating"("p_factory_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_factory_rating"("p_factory_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_low_stock_products"("threshold" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_low_stock_products"("threshold" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_seller_kpis"("p_seller_id" "uuid", "p_period" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_seller_kpis"("p_seller_id" "uuid", "p_period" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_seller_product_count"("seller_uuid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_seller_product_count"("seller_uuid" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_seller_sales_count"("p_seller_id" "uuid", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_seller_sales_count"("p_seller_id" "uuid", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_seller_total_customers"("p_seller_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_seller_total_customers"("p_seller_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_seller_total_revenue"("p_seller_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_seller_total_revenue"("p_seller_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."haversine_distance"("lat1" double precision, "lon1" double precision, "lat2" double precision, "lon2" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."haversine_distance"("lat1" double precision, "lon1" double precision, "lat2" double precision, "lon2" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."haversine_distance"("lat1" double precision, "lon1" double precision, "lat2" double precision, "lon2" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."messages_tsvector_trigger"() TO "anon";
GRANT ALL ON FUNCTION "public"."messages_tsvector_trigger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."messages_tsvector_trigger"() TO "service_role";



GRANT ALL ON FUNCTION "public"."products_tsvector_trigger"() TO "anon";
GRANT ALL ON FUNCTION "public"."products_tsvector_trigger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."products_tsvector_trigger"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_conversation_on_message"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_conversation_on_message"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_conversation_on_message"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_customer_stats_on_sale"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_customer_stats_on_sale"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_customer_stats_on_sale"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_customers_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_customers_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_customers_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_factory_connections_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_factory_connections_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_factory_connections_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_order_status_timestamps"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_order_status_timestamps"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_order_status_timestamps"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_products_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_products_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_products_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_sales_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_sales_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_sales_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";






























GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."admin_users" TO "anon";
GRANT ALL ON TABLE "public"."admin_users" TO "authenticated";
GRANT ALL ON TABLE "public"."admin_users" TO "service_role";



GRANT ALL ON TABLE "public"."analytics" TO "anon";
GRANT ALL ON TABLE "public"."analytics" TO "authenticated";
GRANT ALL ON TABLE "public"."analytics" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."analytics_snapshots" TO "anon";
GRANT ALL ON TABLE "public"."analytics_snapshots" TO "authenticated";
GRANT ALL ON TABLE "public"."analytics_snapshots" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."async_jobs" TO "anon";
GRANT ALL ON TABLE "public"."async_jobs" TO "authenticated";
GRANT ALL ON TABLE "public"."async_jobs" TO "service_role";



GRANT ALL ON TABLE "public"."brands" TO "anon";
GRANT ALL ON TABLE "public"."brands" TO "authenticated";
GRANT ALL ON TABLE "public"."brands" TO "service_role";



GRANT ALL ON TABLE "public"."business_profiles" TO "anon";
GRANT ALL ON TABLE "public"."business_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."business_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."cart" TO "anon";
GRANT ALL ON TABLE "public"."cart" TO "authenticated";
GRANT ALL ON TABLE "public"."cart" TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."categories_backup_20260308_124506" TO "anon";
GRANT ALL ON TABLE "public"."categories_backup_20260308_124506" TO "authenticated";
GRANT ALL ON TABLE "public"."categories_backup_20260308_124506" TO "service_role";



GRANT ALL ON TABLE "public"."conversation_participants" TO "anon";
GRANT ALL ON TABLE "public"."conversation_participants" TO "authenticated";
GRANT ALL ON TABLE "public"."conversation_participants" TO "service_role";



GRANT ALL ON TABLE "public"."conversations" TO "anon";
GRANT ALL ON TABLE "public"."conversations" TO "authenticated";
GRANT ALL ON TABLE "public"."conversations" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."customers" TO "anon";
GRANT ALL ON TABLE "public"."customers" TO "authenticated";
GRANT ALL ON TABLE "public"."customers" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sales" TO "anon";
GRANT ALL ON TABLE "public"."sales" TO "authenticated";
GRANT ALL ON TABLE "public"."sales" TO "service_role";



GRANT ALL ON TABLE "public"."daily_sales_summary" TO "anon";
GRANT ALL ON TABLE "public"."daily_sales_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_sales_summary" TO "service_role";



GRANT ALL ON TABLE "public"."deals" TO "anon";
GRANT ALL ON TABLE "public"."deals" TO "authenticated";
GRANT ALL ON TABLE "public"."deals" TO "service_role";



GRANT ALL ON TABLE "public"."delivery_assignments" TO "anon";
GRANT ALL ON TABLE "public"."delivery_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."delivery_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."delivery_profiles" TO "anon";
GRANT ALL ON TABLE "public"."delivery_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."delivery_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."factory_connections" TO "anon";
GRANT ALL ON TABLE "public"."factory_connections" TO "authenticated";
GRANT ALL ON TABLE "public"."factory_connections" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sellers" TO "anon";
GRANT ALL ON TABLE "public"."sellers" TO "authenticated";
GRANT ALL ON TABLE "public"."sellers" TO "service_role";



GRANT ALL ON TABLE "public"."factory_products" TO "anon";
GRANT ALL ON TABLE "public"."factory_products" TO "authenticated";
GRANT ALL ON TABLE "public"."factory_products" TO "service_role";



GRANT ALL ON TABLE "public"."factory_ratings" TO "anon";
GRANT ALL ON TABLE "public"."factory_ratings" TO "authenticated";
GRANT ALL ON TABLE "public"."factory_ratings" TO "service_role";



GRANT ALL ON TABLE "public"."idempotency_keys" TO "anon";
GRANT ALL ON TABLE "public"."idempotency_keys" TO "authenticated";
GRANT ALL ON TABLE "public"."idempotency_keys" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."middleman_profiles" TO "anon";
GRANT ALL ON TABLE "public"."middleman_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."middleman_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."monthly_sales_summary" TO "anon";
GRANT ALL ON TABLE "public"."monthly_sales_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."monthly_sales_summary" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."order_items" TO "anon";
GRANT ALL ON TABLE "public"."order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."order_items" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."orders" TO "anon";
GRANT ALL ON TABLE "public"."orders" TO "authenticated";
GRANT ALL ON TABLE "public"."orders" TO "service_role";



GRANT ALL ON TABLE "public"."payment_intentions" TO "anon";
GRANT ALL ON TABLE "public"."payment_intentions" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_intentions" TO "service_role";



GRANT ALL ON TABLE "public"."push_subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."push_subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."push_subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."reviews" TO "anon";
GRANT ALL ON TABLE "public"."reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."reviews" TO "service_role";



GRANT ALL ON TABLE "public"."seller_profiles" TO "anon";
GRANT ALL ON TABLE "public"."seller_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."seller_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."sellers_backup" TO "anon";
GRANT ALL ON TABLE "public"."sellers_backup" TO "authenticated";
GRANT ALL ON TABLE "public"."sellers_backup" TO "service_role";



GRANT ALL ON TABLE "public"."shipping_addresses" TO "anon";
GRANT ALL ON TABLE "public"."shipping_addresses" TO "authenticated";
GRANT ALL ON TABLE "public"."shipping_addresses" TO "service_role";



GRANT ALL ON TABLE "public"."subcategories" TO "anon";
GRANT ALL ON TABLE "public"."subcategories" TO "authenticated";
GRANT ALL ON TABLE "public"."subcategories" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



GRANT ALL ON TABLE "public"."wishlist" TO "anon";
GRANT ALL ON TABLE "public"."wishlist" TO "authenticated";
GRANT ALL ON TABLE "public"."wishlist" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";
