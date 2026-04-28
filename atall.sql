


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






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgmq";






CREATE EXTENSION IF NOT EXISTS "postgis" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."engagement_model" AS ENUM (
    'online_only',
    'offline_only',
    'hybrid',
    'project_based',
    'hourly'
);


ALTER TYPE "public"."engagement_model" OWNER TO "postgres";


CREATE TYPE "public"."factory_order_status" AS ENUM (
    'pending',
    'in_production',
    'quality_check',
    'ready_to_ship',
    'shipped',
    'delivered',
    'cancelled'
);


ALTER TYPE "public"."factory_order_status" OWNER TO "postgres";


CREATE TYPE "public"."hospital_type" AS ENUM (
    'general',
    'specialized',
    'clinic',
    'dental',
    'teaching',
    'public',
    'private',
    'emergency',
    'maternity',
    'psychiatric',
    'rehabilitation',
    'veterinary'
);


ALTER TYPE "public"."hospital_type" OWNER TO "postgres";


CREATE TYPE "public"."notification_priority" AS ENUM (
    'low',
    'medium',
    'high',
    'urgent'
);


ALTER TYPE "public"."notification_priority" OWNER TO "postgres";


CREATE TYPE "public"."notification_type" AS ENUM (
    'order',
    'message',
    'deal',
    'product',
    'system',
    'payment',
    'shipping',
    'review'
);


ALTER TYPE "public"."notification_type" OWNER TO "postgres";


CREATE TYPE "public"."provider_category" AS ENUM (
    'health',
    'freelance',
    'home_service',
    'professional',
    'education'
);


ALTER TYPE "public"."provider_category" OWNER TO "postgres";


CREATE TYPE "public"."store_layout_style" AS ENUM (
    'grid',
    'list',
    'masonry',
    'carousel'
);


ALTER TYPE "public"."store_layout_style" OWNER TO "postgres";


CREATE TYPE "public"."store_theme_mode" AS ENUM (
    'light',
    'dark',
    'auto'
);


ALTER TYPE "public"."store_theme_mode" OWNER TO "postgres";


CREATE TYPE "public"."trading_conv_type" AS ENUM (
    'product_inquiry',
    'custom_request',
    'b2b_sourcing',
    'middleman_restock'
);


ALTER TYPE "public"."trading_conv_type" OWNER TO "postgres";


CREATE TYPE "public"."trading_msg_type" AS ENUM (
    'text',
    'image',
    'file',
    'system_notification'
);


ALTER TYPE "public"."trading_msg_type" OWNER TO "postgres";


CREATE TYPE "public"."user_role" AS ENUM (
    'factory',
    'seller',
    'middleman',
    'customer',
    'delivery'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_earnings_to_wallet"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  net_earnings NUMERIC;
  new_wallet_balance NUMERIC;
BEGIN
  -- Trigger already restricts rows via WHEN clause:
  -- (NEW.status = 'completed' AND OLD.status != 'completed')
  -- So we only need to compute/credit here.
  net_earnings := NEW.total_price * 0.98; -- 2% platform fee example

  -- Upsert and capture the resulting balance
  INSERT INTO public.user_wallets (user_id, available_balance, total_earned, updated_at)
  VALUES (NEW.seller_id, net_earnings, net_earnings, NOW())
  ON CONFLICT (user_id) DO UPDATE
  SET
    available_balance = public.user_wallets.available_balance + EXCLUDED.available_balance,
    total_earned = public.user_wallets.total_earned + EXCLUDED.total_earned,
    updated_at = NOW()
  RETURNING public.user_wallets.available_balance INTO new_wallet_balance;

  -- Record transaction with correct balance_after
  INSERT INTO public.wallet_transactions (
    user_id,
    transaction_type,
    amount,
    description,
    reference_type,
    reference_id,
    balance_after
  ) VALUES (
    NEW.seller_id,
    'credit',
    net_earnings,
    'Sale earnings: Order #' || SUBSTRING(NEW.id::text, 1, 8),
    'sale',
    NEW.id,
    new_wallet_balance
  );

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."add_earnings_to_wallet"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_medicine_to_prescription"("p_prescription_id" "uuid", "p_medicine_id" "uuid", "p_dosage_amount" "text", "p_frequency" "text", "p_duration_days" integer, "p_instructions" "text" DEFAULT NULL::"text", "p_quantity" integer DEFAULT NULL::integer, "p_allow_substitution" boolean DEFAULT true) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_prescription_medicine_id UUID;
    v_medicine RECORD;
    v_doctor_id UUID;
BEGIN
    -- Get medicine details
    SELECT * INTO v_medicine
    FROM public.health_medicines_master
    WHERE id = p_medicine_id;
    
    IF v_medicine IS NULL THEN
        RAISE EXCEPTION 'Medicine not found';
    END IF;
    
    -- Get doctor from prescription
    SELECT doctor_id INTO v_doctor_id
    FROM public.health_prescriptions_digital
    WHERE id = p_prescription_id;
    
    IF v_doctor_id IS NULL THEN
        RAISE EXCEPTION 'Prescription not found';
    END IF;
    
    -- Calculate total quantity if not provided
    IF p_quantity IS NULL THEN
        p_quantity := CASE 
            WHEN p_frequency ILIKE '%once daily%' OR p_frequency ILIKE '%1 time%' THEN p_duration_days
            WHEN p_frequency ILIKE '%twice%' OR p_frequency ILIKE '%2 time%' THEN p_duration_days * 2
            WHEN p_frequency ILIKE '%three%' OR p_frequency ILIKE '%3 time%' THEN p_duration_days * 3
            WHEN p_frequency ILIKE '%four%' OR p_frequency ILIKE '%4 time%' THEN p_duration_days * 4
            ELSE p_duration_days
        END;
    END IF;
    
    -- Add medicine to prescription
    INSERT INTO public.health_prescription_medicines_digital (
        prescription_id,
        medicine_id,
        medicine_name,
        generic_name,
        brand_name,
        dosage_form,
        strength,
        dosage_amount,
        frequency,
        route_of_administration,
        duration_days,
        total_quantity,
        instructions,
        allow_generic_substitution,
        unit_price,
        total_price
    ) VALUES (
        p_prescription_id,
        p_medicine_id,
        v_medicine.name,
        v_medicine.generic_name,
        v_medicine.brand,
        v_medicine.dosage_form,
        v_medicine.strength,
        p_dosage_amount,
        p_frequency,
        v_medicine.administration_route,
        p_duration_days,
        p_quantity,
        p_instructions,
        p_allow_substitution,
        v_medicine.price,
        v_medicine.price * p_quantity
    )
    RETURNING id INTO v_prescription_medicine_id;
    
    -- Log action
    INSERT INTO public.health_prescription_audit_log (
        prescription_id,
        action_type,
        action_by,
        action_by_role,
        action_details
    ) VALUES (
        p_prescription_id,
        'updated',
        v_doctor_id,
        'doctor',
        jsonb_build_object(
            'action', 'medicine_added',
            'medicine_id', p_medicine_id,
            'medicine_name', v_medicine.name
        )
    );
    
    RETURN v_prescription_medicine_id;
END;
$$;


ALTER FUNCTION "public"."add_medicine_to_prescription"("p_prescription_id" "uuid", "p_medicine_id" "uuid", "p_dosage_amount" "text", "p_frequency" "text", "p_duration_days" integer, "p_instructions" "text", "p_quantity" integer, "p_allow_substitution" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_seller_to_conversation"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_seller_id UUID;
BEGIN
  -- Get the seller ID from the products table
  SELECT seller_id INTO v_seller_id
  FROM public.products
  WHERE id = NEW.product_id;

  IF v_seller_id IS NOT NULL THEN
    INSERT INTO public.conversation_participants (conversation_id, user_id, role)
    VALUES (NEW.id, v_seller_id, 'seller')
    ON CONFLICT (conversation_id, user_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."add_seller_to_conversation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."archive_health_messages"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_archived_count INTEGER;
BEGIN
    -- Archive messages older than 7 years
    INSERT INTO public.health_message_archives (conversation_id, message_data, archived_at)
    SELECT
        conversation_id,
        jsonb_agg(to_jsonb(health_messages)),
        NOW()
    FROM public.health_messages
    WHERE created_at < NOW() - INTERVAL '7 years'
    AND id NOT IN (SELECT message_id FROM public.health_message_archives)
    GROUP BY conversation_id;
    
    GET DIAGNOSTICS v_archived_count = ROW_COUNT;
    RETURN v_archived_count;
END;
$$;


ALTER FUNCTION "public"."archive_health_messages"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."archive_old_messages"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Archive messages older than 2 years
  INSERT INTO message_archives (conversation_id, message_data, archived_at)
  SELECT 
    conversation_id,
    jsonb_agg(to_jsonb(messages)),
    NOW()
  FROM messages
  WHERE created_at < NOW() - INTERVAL '2 years'
  AND id NOT IN (SELECT message_id FROM message_archives)
  GROUP BY conversation_id;
  
  -- Delete archived messages
  DELETE FROM messages
  WHERE created_at < NOW() - INTERVAL '2 years'
  AND id IN (SELECT message_id FROM message_archives);
END;
$$;


ALTER FUNCTION "public"."archive_old_messages"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."archive_old_notifications"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Delete read notifications older than 90 days
  DELETE FROM notifications
  WHERE is_read = true
  AND created_at < NOW() - INTERVAL '90 days';
END;
$$;


ALTER FUNCTION "public"."archive_old_notifications"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."archive_patient_data"("p_doctor_id" "uuid", "p_patient_id" "uuid", "p_archive_type" "text" DEFAULT 'full'::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_archive_id UUID;
    v_archive_data JSONB;
    v_data_hash TEXT;
BEGIN
    -- Generate archive JSON
    v_archive_data := public.generate_patient_archive_json(p_doctor_id, p_patient_id);
    
    -- Generate hash for change detection
    v_data_hash := md5(v_archive_data::text);
    
    -- Insert archive
    INSERT INTO public.health_patient_archives (
        doctor_id,
        patient_id,
        archive_data,
        data_version,
        archive_type,
        data_hash,
        backup_date,
        is_synced,
        created_at
    ) VALUES (
        p_doctor_id,
        p_patient_id,
        v_archive_data,
        1,
        p_archive_type,
        v_data_hash,
        CURRENT_DATE,
        FALSE,
        NOW()
    )
    ON CONFLICT (doctor_id, patient_id, backup_date) 
    DO UPDATE SET
        archive_data = EXCLUDED.archive_data,
        data_version = health_patient_archives.data_version + 1,
        data_hash = EXCLUDED.data_hash,
        updated_at = NOW()
    RETURNING id INTO v_archive_id;
    
    RETURN v_archive_id;
END;
$$;


ALTER FUNCTION "public"."archive_patient_data"("p_doctor_id" "uuid", "p_patient_id" "uuid", "p_archive_type" "text") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."audit_sensitive_data_changes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  changes jsonb;
BEGIN
  changes := jsonb_build_object();

  IF OLD.email IS DISTINCT FROM NEW.email THEN
    changes := jsonb_set(changes, '{email}', jsonb_build_object('old', OLD.email, 'new', NEW.email));
  END IF;

  IF OLD.phone IS DISTINCT FROM NEW.phone THEN
    changes := jsonb_set(changes, '{phone}', jsonb_build_object('old', OLD.phone, 'new', NEW.phone));
  END IF;

  -- `changes` is a JSON object, not an array
  IF jsonb_typeof(changes) = 'object' AND jsonb_object_length(changes) > 0 THEN
    INSERT INTO audit_logs (event, severity, description, metadata, user_id)
    VALUES (
      'SENSITIVE_DATA_CHANGE',
      'medium',
      'User sensitive data was modified',
      jsonb_build_object('changes', changes),
      NEW.id
    );
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."audit_sensitive_data_changes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."auto_create_user_wallet"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO public.user_wallets (user_id, balance, currency)
  VALUES (NEW.user_id, 0, 'USD')
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."auto_create_user_wallet"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."auto_credit_service_provider"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.status = 'completed'
     AND OLD.status IS DISTINCT FROM 'completed' THEN

    PERFORM public.credit_wallet(
      (SELECT user_id FROM public.svc_providers WHERE id = NEW.provider_id),
      NEW.agreed_price,
      'service_booking',
      NEW.id,
      'Payment for service: ' || NEW.id,
      'svc_' || NEW.id,
      jsonb_build_object('order_id', NEW.id)
    );
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."auto_credit_service_provider"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."auto_generate_product_description"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.description IS NULL OR NEW.description = '' THEN
    NEW.description := 
      COALESCE(NEW.title, '') || ' by ' || COALESCE(NEW.brand, '') || '. ' ||
      'Condition: ' || COALESCE(NEW.status, '') || '. ' ||
      'Category: ' || COALESCE(NEW.category, '') ||
      CASE WHEN NEW.subcategory IS NOT NULL THEN ' > ' || NEW.subcategory ELSE '' END || '. ';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."auto_generate_product_description"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bulk_upload_medicines"("p_pharmacy_id" "uuid", "p_medicines" "jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_medicine JSONB;
    v_count INTEGER := 0;
BEGIN
    FOR v_medicine IN SELECT * FROM jsonb_array_elements(p_medicines)
    LOOP
        INSERT INTO public.health_medicines (
            pharmacy_id,
            name,
            generic_name,
            brand,
            manufacturer,
            category,
            subcategory,
            description,
            dosage_form,
            strength,
            unit,
            price,
            currency,
            quantity_in_stock,
            requires_prescription,
            prescription_category,
            active_ingredients,
            side_effects,
            warnings,
            storage_instructions,
            barcode,
            sku,
            images,
            is_available
        ) VALUES (
            p_pharmacy_id,
            v_medicine->>'name',
            v_medicine->>'generic_name',
            v_medicine->>'brand',
            v_medicine->>'manufacturer',
            v_medicine->>'category',
            v_medicine->>'subcategory',
            v_medicine->>'description',
            v_medicine->>'dosage_form',
            v_medicine->>'strength',
            COALESCE(v_medicine->>'unit', 'piece'),
            (v_medicine->>'price')::NUMERIC,
            COALESCE(v_medicine->>'currency', 'EGP'),
            COALESCE((v_medicine->>'quantity_in_stock')::INTEGER, 0),
            COALESCE((v_medicine->>'requires_prescription')::BOOLEAN, FALSE),
            COALESCE(v_medicine->>'prescription_category', 'over_counter'),
            COALESCE(v_medicine->'active_ingredients', '[]'::jsonb),
            v_medicine->>'side_effects',
            v_medicine->>'warnings',
            v_medicine->>'storage_instructions',
            v_medicine->>'barcode',
            v_medicine->>'sku',
            COALESCE(v_medicine->'images', '[]'::jsonb),
            COALESCE((v_medicine->>'is_available')::BOOLEAN, TRUE)
        )
        ON CONFLICT DO NOTHING;
        v_count := v_count + 1;
    END LOOP;
    RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."bulk_upload_medicines"("p_pharmacy_id" "uuid", "p_medicines" "jsonb") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."calculate_middle_man_commission"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
DECLARE
  v_commission NUMERIC;
  v_rate NUMERIC;
  v_margin NUMERIC;
  v_deal RECORD;
BEGIN
  IF NEW.middle_man_id IS NOT NULL 
    AND NEW.status = 'confirmed' 
    AND OLD.status IS DISTINCT FROM 'confirmed' THEN
    
    SELECT commission_rate, margin_amount, id, seller_id 
    INTO v_deal
    FROM public.middle_man_deals
    WHERE middle_man_id = NEW.middle_man_id
      AND product_asin = (SELECT asin FROM public.order_items WHERE order_id = NEW.id LIMIT 1)
      AND is_active = true
      AND approval_status IN ('auto_approved', 'pending_approval')
      AND (expires_at IS NULL OR expires_at > NOW())
    LIMIT 1;
    
    IF v_deal.id IS NOT NULL THEN
      IF COALESCE(v_deal.margin_amount, 0) > 0 THEN
        v_commission := v_deal.margin_amount;
      ELSE
        v_commission := NEW.total * (v_deal.commission_rate / 100);
      END IF;
      
      INSERT INTO public.commissions (
        middle_man_id, order_id, deal_id, amount, commission_rate, status
      ) VALUES (
        NEW.middle_man_id, NEW.id, v_deal.id, v_commission, v_deal.commission_rate, 'pending'
      );
      
      UPDATE public.middle_men SET pending_earnings = pending_earnings + v_commission
      WHERE user_id = NEW.middle_man_id;
      
      UPDATE public.middle_man_deals 
      SET conversions = conversions + 1, total_revenue = total_revenue + NEW.total
      WHERE id = v_deal.id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."calculate_middle_man_commission"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_middle_man_margin"("p_product_asin" "text", "p_commission_rate" numeric DEFAULT 5.00, "p_margin_amount" numeric DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_product_price numeric;
  v_commission numeric;
BEGIN
  -- Get product price
  SELECT price INTO v_product_price FROM public.products WHERE asin = p_product_asin LIMIT 1;
  
  IF v_product_price IS NULL THEN
    RAISE EXCEPTION 'Product not found';
  END IF;

  -- Calculate logic
  IF p_margin_amount > 0 THEN
    v_commission := p_margin_amount;
  ELSE
    v_commission := v_product_price * (p_commission_rate / 100);
  END IF;

  RETURN jsonb_build_object(
    'product_price', v_product_price,
    'commission_rate', p_commission_rate,
    'margin_amount', p_margin_amount,
    'estimated_earnings', v_commission,
    'customer_final_price', v_product_price -- Assuming price doesn't change, just split
  );
END;
$$;


ALTER FUNCTION "public"."calculate_middle_man_margin"("p_product_asin" "text", "p_commission_rate" numeric, "p_margin_amount" numeric) OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."can_start_conversation"("from_user_id" "uuid", "to_user_id" "uuid", "product_id" "uuid" DEFAULT NULL::"uuid", "conversation_type" "text" DEFAULT 'general'::"text") RETURNS boolean
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

  -- Get user roles
  SELECT account_type INTO from_role FROM users WHERE user_id = from_user_id;
  SELECT account_type INTO to_role FROM users WHERE user_id = to_user_id;

  -- Cannot chat with self
  IF from_user_id = to_user_id THEN 
    RETURN FALSE; 
  END IF;

  -- Deal negotiation conversations (factory ↔ seller/middleman)
  IF conversation_type = 'deal_negotiation' THEN
    IF from_role = 'factory' AND to_role IN ('seller', 'middleman') THEN 
      RETURN TRUE; 
    END IF;
    IF from_role = 'seller' AND to_role = 'factory' THEN 
      RETURN TRUE; 
    END IF;
    IF from_role = 'middleman' THEN 
      RETURN TRUE; 
    END IF;
  END IF;

  -- Factory can message sellers/middlemen for general chat
  IF from_role = 'factory' AND to_role IN ('seller', 'middleman') THEN 
    RETURN TRUE; 
  END IF;

  -- Seller can message factory/middleman
  IF from_role = 'seller' THEN
    IF to_role IN ('factory', 'middleman') THEN 
      RETURN TRUE;
    ELSIF to_role = 'customer' THEN
      IF product_id IS NULL THEN RETURN FALSE; END IF;
      SELECT seller_id, allow_chat INTO product_owner_id, product_allows
      FROM products WHERE id = product_id;
      RETURN (product_owner_id = from_user_id) AND product_allows;
    END IF;
  END IF;

  -- Middleman can message anyone
  IF from_role = 'middleman' THEN 
    RETURN TRUE; 
  END IF;

  -- Customer can message seller about products
  IF from_role = 'customer' OR from_role = 'user' THEN
    IF to_role = 'seller' AND product_id IS NOT NULL THEN
      SELECT seller_id, allow_chat INTO product_owner_id, product_allows
      FROM products WHERE id = product_id;
      RETURN (product_owner_id = to_user_id) AND product_allows;
    END IF;
  END IF;

  RETURN FALSE;
END;
$$;


ALTER FUNCTION "public"."can_start_conversation"("from_user_id" "uuid", "to_user_id" "uuid", "product_id" "uuid", "conversation_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_low_stock_and_notify"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.quantity <= 5 AND NEW.status = 'active' THEN
    INSERT INTO public.notifications (user_id, type, title, message, metadata)
    VALUES (
      NEW.seller_id,
      'product',
      'Low Stock Alert',
      'Product "' || NEW.title || '" has only ' || NEW.quantity || ' items left',
      jsonb_build_object('product_id', NEW.id, 'asin', NEW.asin, 'quantity', NEW.quantity)
    );
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_low_stock_and_notify"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_product_chat_permission"("p_user_id" "uuid", "p_product_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_allow_chat boolean;
  v_seller_id uuid;
  v_user_type text;
BEGIN
  -- Get product chat permission
  SELECT allow_chat, seller_id INTO v_allow_chat, v_seller_id
  FROM products
  WHERE id = p_product_id;
  
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  
  -- Get user account type
  SELECT account_type INTO v_user_type
  FROM users
  WHERE user_id = p_user_id;
  
  -- Customer/user must check product permission
  IF v_user_type IN ('user', 'customer') THEN
    RETURN v_allow_chat;
  END IF;
  
  -- Seller, factory, middleman always allowed
  RETURN true;
END;
$$;


ALTER FUNCTION "public"."check_product_chat_permission"("p_user_id" "uuid", "p_product_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."claim_and_create_promo_deal"("p_product_asin" "text", "p_margin_type" "text", "p_margin_value" numeric, "p_expires_days" integer DEFAULT 30, "p_promo_tags" "text"[] DEFAULT '{}'::"text"[]) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
DECLARE
  v_mm_id UUID := auth.uid();
  v_deal_id UUID;
  v_slug TEXT;
  v_product RECORD;
  v_seller RECORD;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.middle_men WHERE user_id = v_mm_id) THEN
    RAISE EXCEPTION 'User is not registered as a Middle Man';
  END IF;

  SELECT p.*, s.allow_middleman_promo, s.require_middleman_approval
  INTO v_product
  FROM public.products p
  JOIN public.sellers s ON s.user_id = p.seller_id
  WHERE p.asin = p_product_asin AND p.status = 'active' AND p.is_deleted = false;

  IF v_product IS NULL THEN RAISE EXCEPTION 'Product not found or inactive'; END IF;
  IF NOT v_product.allow_middleman_promo THEN RAISE EXCEPTION 'Seller does not allow middleman promotions for this product'; END IF;

  v_slug := 'mm-' || SUBSTRING(v_mm_id::text, 1, 8) || '-' || v_product.asin;

  INSERT INTO public.middle_man_deals (
    middle_man_id, product_asin, product_id, seller_id,
    commission_rate, margin_amount, unique_slug, is_active,
    approval_status, expires_at, promo_tags, created_at
  ) VALUES (
    v_mm_id, v_product.asin, v_product.id, v_product.seller_id,
    CASE WHEN p_margin_type = 'percentage' THEN p_margin_value ELSE 0 END,
    CASE WHEN p_margin_type = 'fixed' THEN p_margin_value ELSE 0 END,
    v_slug, true, 
    CASE WHEN v_product.require_middleman_approval THEN 'pending_approval' ELSE 'auto_approved' END,
    NOW() + (p_expires_days || ' days')::INTERVAL,
    p_promo_tags, NOW()
  )
  ON CONFLICT (middle_man_id, product_asin) DO UPDATE SET
    commission_rate = EXCLUDED.commission_rate,
    margin_amount = EXCLUDED.margin_amount,
    is_active = true,
    expires_at = EXCLUDED.expires_at,
    promo_tags = EXCLUDED.promo_tags,
    updated_at = NOW()
  RETURNING id, unique_slug INTO v_deal_id, v_slug;

  RETURN jsonb_build_object(
    'success', true, 'deal_id', v_deal_id, 'promo_slug', v_slug,
    'share_url', 'https://yourdomain.com/deal/' || v_slug,
    'estimated_earnings', CASE 
      WHEN p_margin_type = 'percentage' THEN v_product.price * (p_margin_value / 100)
      ELSE p_margin_value 
    END
  );
END;
$$;


ALTER FUNCTION "public"."claim_and_create_promo_deal"("p_product_asin" "text", "p_margin_type" "text", "p_margin_value" numeric, "p_expires_days" integer, "p_promo_tags" "text"[]) OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."cleanup_expired_notifications"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_deleted_count integer;
BEGIN
  DELETE FROM notifications
  WHERE expires_at IS NOT NULL
  AND expires_at < NOW();
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  RETURN v_deleted_count;
END;
$$;


ALTER FUNCTION "public"."cleanup_expired_notifications"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_expired_sessions"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Delete expired refresh tokens (handled by Supabase auth)
  -- Delete expired password reset tokens
  DELETE FROM password_reset_tokens
  WHERE expires_at < NOW();
  
  -- Delete expired verification codes
  DELETE FROM verification_codes
  WHERE expires_at < NOW();
  
  -- Clean up abandoned carts (older than 30 days)
  DELETE FROM cart_items
  WHERE created_at < NOW() - INTERVAL '30 days';
END;
$$;


ALTER FUNCTION "public"."cleanup_expired_sessions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_inactive_push_subscriptions"("p_days_inactive" integer DEFAULT 90) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    UPDATE public.push_subscriptions
    SET is_active = false
    WHERE last_active_at < NOW() - (p_days_inactive || ' days')::INTERVAL
    AND is_active = true;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$;


ALTER FUNCTION "public"."cleanup_inactive_push_subscriptions"("p_days_inactive" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_product_images"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  old_urls TEXT[];
  new_urls TEXT[];
  url_to_delete TEXT;
BEGIN
  -- Extract URLs from old and new images JSONB
  -- Compare and delete orphaned images from storage
  -- This requires storage API access (may need Edge Function instead)
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."cleanup_product_images"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_typing_indicators"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    DELETE FROM public.health_typing_indicators
    WHERE last_activity < NOW() - INTERVAL '1 minute';
END;
$$;


ALTER FUNCTION "public"."cleanup_typing_indicators"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."close_health_conversation"("p_conversation_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_conversation RECORD;
BEGIN
    SELECT * INTO v_conversation
    FROM public.health_conversations
    WHERE id = p_conversation_id;
    
    IF v_conversation IS NULL THEN
        RAISE EXCEPTION 'Conversation not found';
    END IF;
    
    -- Only doctor can close conversation
    IF auth.uid() != (SELECT user_id FROM public.health_doctor_profiles WHERE id = v_conversation.doctor_id) THEN
        RAISE EXCEPTION 'Only doctors can close conversations';
    END IF;
    
    UPDATE public.health_conversations
    SET
        status = 'closed',
        closed_at = NOW(),
        closed_by = auth.uid(),
        updated_at = NOW(),
        metadata = jsonb_set(
            COALESCE(metadata, '{}'::jsonb),
            '{close_reason}',
            to_jsonb(p_reason)
        )
    WHERE id = p_conversation_id
    RETURNING id;
END;
$$;


ALTER FUNCTION "public"."close_health_conversation"("p_conversation_id" "uuid", "p_reason" "text") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."create_cod_verification_on_order"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.payment_method = 'cod' THEN
    -- Generate verification key automatically
    PERFORM public.generate_cod_verification_key(NEW.id, 6, 24);
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_cod_verification_on_order"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_digital_prescription"("p_appointment_id" "uuid", "p_doctor_id" "uuid", "p_patient_id" "uuid", "p_diagnosis" "text" DEFAULT NULL::"text", "p_symptoms" "text" DEFAULT NULL::"text", "p_notes" "text" DEFAULT NULL::"text", "p_valid_days" integer DEFAULT 30, "p_max_refills" integer DEFAULT 0) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_prescription_id UUID;
    v_prescription_number TEXT;
    v_valid_until DATE;
BEGIN
    -- Generate prescription number
    v_prescription_number := 'RX-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || SUBSTRING(gen_random_uuid()::text, 1, 8);
    v_valid_until := CURRENT_DATE + (p_valid_days || ' days')::INTERVAL;
    
    -- Create prescription
    INSERT INTO public.health_prescriptions_digital (
        appointment_id,
        doctor_id,
        patient_id,
        prescription_number,
        prescription_date,
        valid_until,
        diagnosis,
        symptoms,
        notes,
        max_refills,
        refills_remaining,
        requires_signature
    ) VALUES (
        p_appointment_id,
        p_doctor_id,
        p_patient_id,
        v_prescription_number,
        CURRENT_DATE,
        v_valid_until,
        p_diagnosis,
        p_symptoms,
        p_notes,
        p_max_refills,
        p_max_refills,
        TRUE
    )
    RETURNING id INTO v_prescription_id;
    
    -- Log action
    INSERT INTO public.health_prescription_audit_log (
        prescription_id,
        action_type,
        action_by,
        action_by_role,
        action_details
    ) VALUES (
        v_prescription_id,
        'created',
        p_doctor_id,
        'doctor',
        jsonb_build_object('prescription_number', v_prescription_number)
    );
    
    RETURN v_prescription_id;
END;
$$;


ALTER FUNCTION "public"."create_digital_prescription"("p_appointment_id" "uuid", "p_doctor_id" "uuid", "p_patient_id" "uuid", "p_diagnosis" "text", "p_symptoms" "text", "p_notes" "text", "p_valid_days" integer, "p_max_refills" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_direct_conversation"("p_target_user_id" "uuid", "p_context" "text" DEFAULT 'general'::"text", "p_product_id" "uuid" DEFAULT NULL::"uuid", "p_appointment_id" "uuid" DEFAULT NULL::"uuid", "p_listing_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_conversation_id uuid;
  v_initiator_role text;
  v_receiver_role text;
BEGIN
  -- Get roles from users table
  SELECT account_type INTO v_initiator_role FROM public.users WHERE user_id = auth.uid();
  SELECT account_type INTO v_receiver_role FROM public.users WHERE user_id = p_target_user_id;
  
  v_initiator_role := COALESCE(v_initiator_role, 'user'::text);
  v_receiver_role := COALESCE(v_receiver_role, 'user'::text);

  -- Check based on context
  IF p_context = 'trading' THEN
    -- Check if trading_conversations table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'trading_conversations') THEN
      SELECT id INTO v_conversation_id
      FROM public.trading_conversations
      WHERE (initiator_id = auth.uid() AND receiver_id = p_target_user_id)
         OR (initiator_id = p_target_user_id AND receiver_id = auth.uid())
      AND is_archived = false
      LIMIT 1;

      IF v_conversation_id IS NULL THEN
        INSERT INTO public.trading_conversations (
          initiator_id, receiver_id, initiator_role, receiver_role,
          product_id, conversation_type
        ) VALUES (
          auth.uid(), p_target_user_id, v_initiator_role, v_receiver_role,
          p_product_id, 'product_inquiry'
        )
        RETURNING id INTO v_conversation_id;
      END IF;
    END IF;

  ELSIF p_context = 'health' THEN
    -- Check if health_conversations table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'health_conversations') THEN
      SELECT id INTO v_conversation_id
      FROM public.health_conversations
      WHERE appointment_id = p_appointment_id
      LIMIT 1;

      IF v_conversation_id IS NULL THEN
        INSERT INTO public.health_conversations (appointment_id)
        VALUES (p_appointment_id)
        RETURNING id INTO v_conversation_id;
      END IF;
    END IF;

  ELSIF p_context = 'services' THEN
    -- Check if services_conversations table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'services_conversations') THEN
      SELECT id INTO v_conversation_id
      FROM public.services_conversations
      WHERE (provider_id = auth.uid() AND client_id = p_target_user_id)
         OR (provider_id = p_target_user_id AND client_id = auth.uid())
      AND listing_id = p_listing_id
      AND is_archived = false
      LIMIT 1;

      IF v_conversation_id IS NULL THEN
        INSERT INTO public.services_conversations (
          provider_id, client_id, listing_id
        ) VALUES (
          CASE WHEN v_initiator_role = 'service_provider' THEN auth.uid() ELSE p_target_user_id END,
          CASE WHEN v_initiator_role = 'service_provider' THEN p_target_user_id ELSE auth.uid() END,
          p_listing_id
        )
        RETURNING id INTO v_conversation_id;
      END IF;
    END IF;

  ELSE
    -- General conversations (always exists)
    SELECT c.id INTO v_conversation_id
    FROM public.conversations c
    JOIN public.conversation_participants cp1 ON c.id = cp1.conversation_id
    JOIN public.conversation_participants cp2 ON c.id = cp2.conversation_id
    WHERE cp1.user_id = auth.uid() 
      AND cp2.user_id = p_target_user_id
      AND c.is_archived = false
    LIMIT 1;

    IF v_conversation_id IS NULL THEN
      INSERT INTO public.conversations (product_id)
      VALUES (p_product_id)
      RETURNING id INTO v_conversation_id;

      INSERT INTO public.conversation_participants (conversation_id, user_id, role)
      VALUES (v_conversation_id, auth.uid(), v_initiator_role);

      INSERT INTO public.conversation_participants (conversation_id, user_id, role)
      VALUES (v_conversation_id, p_target_user_id, v_receiver_role);
    END IF;
  END IF;

  RETURN v_conversation_id;
END;
$$;


ALTER FUNCTION "public"."create_direct_conversation"("p_target_user_id" "uuid", "p_context" "text", "p_product_id" "uuid", "p_appointment_id" "uuid", "p_listing_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_health_conversation_on_appointment"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_conversation_id UUID;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.status IN ('confirmed', 'active', 'completed') THEN
        -- Check if conversation already exists
        SELECT id INTO v_conversation_id
        FROM public.health_conversations
        WHERE appointment_id = NEW.id;
        
        IF v_conversation_id IS NULL THEN
            INSERT INTO public.health_conversations (
                appointment_id,
                doctor_id,
                patient_id,
                conversation_type,
                status
            ) VALUES (
                NEW.id,
                NEW.doctor_id,
                NEW.patient_id,
                'appointment',
                'active'
            )
            RETURNING id INTO v_conversation_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_health_conversation_on_appointment"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_medicine_order"("p_user_id" "uuid", "p_items" "jsonb", "p_delivery_address" "jsonb") RETURNS TABLE("success" boolean, "message" "text", "order_id" "uuid", "total_amount" numeric, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_order_id UUID;
  v_total_amount NUMERIC := 0;
  v_item JSONB;
  v_medicine_id UUID;
  v_quantity INT;
  v_price NUMERIC;
  v_stock INT;
BEGIN
  v_order_id := gen_random_uuid();

  -- Validate and calculate total
  FOR v_item IN SELECT jsonb_array_elements(p_items)
  LOOP
    v_medicine_id := (v_item->>'medicine_id')::UUID;
    v_quantity := (v_item->>'quantity')::INT;

    -- Get medicine price and stock
    SELECT price, stock_quantity
    INTO v_price, v_stock
    FROM public.health_medicines
    WHERE id = v_medicine_id;

    IF v_price IS NULL THEN
      RETURN QUERY SELECT
        FALSE::BOOLEAN,
        'Medicine not found: ' || v_medicine_id::TEXT,
        NULL::UUID,
        NULL::NUMERIC,
        NULL::TIMESTAMPTZ;
      RETURN;
    END IF;

    IF v_stock < v_quantity THEN
      RETURN QUERY SELECT
        FALSE::BOOLEAN,
        'Insufficient stock for medicine: ' || v_medicine_id::TEXT,
        NULL::UUID,
        NULL::NUMERIC,
        NULL::TIMESTAMPTZ;
      RETURN;
    END IF;

    v_total_amount := v_total_amount + (v_price * v_quantity);
  END LOOP;

  -- Create order
  INSERT INTO public.health_medicine_orders (
    id,
    user_id,
    total_amount,
    order_status,
    delivery_address,
    created_at,
    updated_at
  )
  VALUES (
    v_order_id,
    p_user_id,
    v_total_amount,
    'pending',
    p_delivery_address,
    NOW(),
    NOW()
  );

  -- Add order items
  FOR v_item IN SELECT jsonb_array_elements(p_items)
  LOOP
    v_medicine_id := (v_item->>'medicine_id')::UUID;
    v_quantity := (v_item->>'quantity')::INT;

    SELECT price INTO v_price
    FROM public.health_medicines
    WHERE id = v_medicine_id;

    INSERT INTO public.health_medicine_order_items (
      id,
      order_id,
      Medicine_id,
      quantity,
      price_per_unit,
      created_at
    )
    VALUES (
      gen_random_uuid(),
      v_order_id,
      v_medicine_id,
      v_quantity,
      v_price,
      NOW()
    );

    -- Reduce stock
    UPDATE public.health_medicines
    SET stock_quantity = stock_quantity - v_quantity
    WHERE id = v_medicine_id;
  END LOOP;

  RETURN QUERY SELECT
    TRUE::BOOLEAN,
    'Medicine order created successfully'::TEXT,
    v_order_id,
    v_total_amount,
    NOW();
END;
$$;


ALTER FUNCTION "public"."create_medicine_order"("p_user_id" "uuid", "p_items" "jsonb", "p_delivery_address" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_middle_man_deal"("p_middle_man_id" "uuid", "p_product_asin" "text", "p_commission_rate" numeric DEFAULT 5.00, "p_margin_amount" numeric DEFAULT 0) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_deal_id uuid;
  v_unique_slug text;
  v_product_id uuid;
BEGIN
  -- Get product_id from asin
  SELECT id INTO v_product_id FROM public.products WHERE asin = p_product_asin;
  
  -- Generate unique slug: mm-{middle_man_uuid}-{asin}
  v_unique_slug := 'mm-' || p_middle_man_id || '-' || p_product_asin;
  
  -- Insert or update deal
  INSERT INTO public.middle_man_deals (
    middle_man_id,
    product_asin,
    product_id,
    commission_rate,
    margin_amount,
    unique_slug,
    is_active
  ) VALUES (
    p_middle_man_id,
    p_product_asin,
    v_product_id,
    p_commission_rate,
    p_margin_amount,
    v_unique_slug,
    true
  )
  ON CONFLICT (middle_man_id, product_asin)
  DO UPDATE SET
    commission_rate = EXCLUDED.commission_rate,
    margin_amount = EXCLUDED.margin_amount,
    is_active = true,
    updated_at = now()
  RETURNING id INTO v_deal_id;
  
  RETURN v_deal_id;
END;
$$;


ALTER FUNCTION "public"."create_middle_man_deal"("p_middle_man_id" "uuid", "p_product_asin" "text", "p_commission_rate" numeric, "p_margin_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_notification_from_template"("p_user_id" "uuid", "p_template_name" "text", "p_variables" "jsonb" DEFAULT '{}'::"jsonb", "p_reference_type" "text" DEFAULT NULL::"text", "p_reference_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."create_notification_from_template"("p_user_id" "uuid", "p_template_name" "text", "p_variables" "jsonb", "p_reference_type" "text", "p_reference_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_or_update_middle_man_deal"("p_product_asin" "text", "p_commission_rate" numeric DEFAULT 5.00, "p_margin_amount" numeric DEFAULT 0) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_deal_id uuid;
  v_middle_man_id uuid;
  v_product_id uuid;
  v_slug text;
BEGIN
  -- Get Current User ID
  v_middle_man_id := auth.uid();
  
  -- Verify User is a Middle Man
  IF NOT EXISTS (SELECT 1 FROM public.middle_men WHERE user_id = v_middle_man_id) THEN
    RAISE EXCEPTION 'User is not registered as a Middle Man';
  END IF;

  -- Get Product ID
  SELECT id INTO v_product_id FROM public.products WHERE asin = p_product_asin LIMIT 1;
  IF v_product_id IS NULL THEN
    RAISE EXCEPTION 'Product not found';
  END IF;

  -- Generate Slug
  v_slug := 'mm-' || substr(v_middle_man_id::text, 1, 8) || '-' || p_product_asin;

  -- Insert or Update
  INSERT INTO public.middle_man_deals (
    middle_man_id,
    product_asin,
    product_id,
    commission_rate,
    margin_amount,
    unique_slug,
    is_active
  ) VALUES (
    v_middle_man_id,
    p_product_asin,
    v_product_id,
    p_commission_rate,
    p_margin_amount,
    v_slug,
    true
  )
  ON CONFLICT (middle_man_id, product_asin) DO UPDATE SET
    commission_rate = EXCLUDED.commission_rate,
    margin_amount = EXCLUDED.margin_amount,
    is_active = true,
    updated_at = now()
  RETURNING id INTO v_deal_id;

  RETURN v_deal_id;
END;
$$;


ALTER FUNCTION "public"."create_or_update_middle_man_deal"("p_product_asin" "text", "p_commission_rate" numeric, "p_margin_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_order_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    NEW.user_id,
    'order',
    'Order Status Updated',
    'Your order is now ' || NEW.status,
    jsonb_build_object('link', '/orders/' || NEW.id, 'order_id', NEW.id)
  );
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_order_notification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_secure_order"("p_user_id" "uuid", "p_seller_id" "uuid", "p_items" "jsonb", "p_shipping_address_id" "uuid", "p_payment_method" "text" DEFAULT 'cash'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
DECLARE
  v_order_id uuid;
  v_item jsonb;
  v_product record;
  v_subtotal numeric := 0;
  v_shipping numeric := 10; -- Example: Fixed shipping or calculate dynamically
  v_tax numeric := 0;       -- Example: 0% tax
  v_total numeric := 0;
BEGIN
  -- 1. Validate Seller Ownership & Check Inventory
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    SELECT * INTO v_product FROM public.products WHERE asin = v_item->>'asin';
    
    IF v_product IS NULL THEN
      RAISE EXCEPTION 'Product with ASIN % not found', v_item->>'asin';
    END IF;
    
    IF v_product.seller_id != p_seller_id THEN
      RAISE EXCEPTION 'Seller does not own product %', v_item->>'asin';
    END IF;
    
    IF v_product.quantity < (v_item->>'quantity')::int THEN
      RAISE EXCEPTION 'Insufficient stock for %', v_item->>'asin';
    END IF;
  END LOOP;

  -- 2. Create Order Header (Pending Status)
  INSERT INTO public.orders (
    user_id, seller_id, shipping_address_id, payment_method, 
    subtotal, shipping, tax, total, status, payment_status, created_at
  )
  VALUES (
    p_user_id, p_seller_id, p_shipping_address_id, p_payment_method, 
    v_subtotal, v_shipping, v_tax, v_subtotal + v_shipping + v_tax, 'pending', 'pending', now()
  )
  RETURNING id INTO v_order_id;

  -- 3. Create Order Items & Deduct Inventory Atomically
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO public.order_items (
      order_id, asin, product_name, quantity, unit_price, total_price
    )
    SELECT 
      v_order_id,
      v_item->>'asin',
      p.title,
      (v_item->>'quantity')::int,
      p.price,
      (v_item->>'quantity')::int * p.price
    FROM public.products p
    WHERE p.asin = v_item->>'asin';
    
    -- Update Product Inventory
    UPDATE public.products
    SET quantity = quantity - (v_item->>'quantity')::int,
        updated_at = now()
    WHERE asin = v_item->>'asin';
    
    -- Accumulate Subtotal
    v_subtotal := v_subtotal + ((v_item->>'quantity')::int * (SELECT price FROM public.products WHERE asin = v_item->>'asin'));
  END LOOP;
  
  -- 4. Finalize Totals
  v_total := v_subtotal + v_shipping + v_tax;
  UPDATE public.orders
  SET subtotal = v_subtotal,
      total = v_total
  WHERE id = v_order_id;

  RETURN jsonb_build_object('success', true, 'order_id', v_order_id, 'total', v_total);
END;
$$;


ALTER FUNCTION "public"."create_secure_order"("p_user_id" "uuid", "p_seller_id" "uuid", "p_items" "jsonb", "p_shipping_address_id" "uuid", "p_payment_method" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_user_wallet_on_signup"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.user_wallets (user_id, currency)
  VALUES (NEW.id, 'EGP')
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_user_wallet_on_signup"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."credit_wallet"("p_user_id" "uuid", "p_amount" numeric, "p_reference_type" "text", "p_reference_id" "uuid", "p_description" "text", "p_idempotency_key" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_wallet_id UUID;
  v_transaction_id UUID;
  v_balance_before NUMERIC;
  v_balance_after NUMERIC;
BEGIN
  -- Check idempotency key (PREVENT DUPLICATE TRANSACTIONS)
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_transaction_id
    FROM public.wallet_transactions
    WHERE idempotency_key = p_idempotency_key;
    
    IF v_transaction_id IS NOT NULL THEN
      -- Return existing transaction (already processed)
      RETURN v_transaction_id;
    END IF;
  END IF;
  
  -- Get or create wallet
  SELECT id INTO v_wallet_id
  FROM public.user_wallets
  WHERE user_id = p_user_id;
  
  IF v_wallet_id IS NULL THEN
    INSERT INTO public.user_wallets (user_id, currency)
    VALUES (p_user_id, 'EGP')
    RETURNING id INTO v_wallet_id;
  END IF;
  
  -- Lock wallet row (PREVENT RACE CONDITIONS)
  SELECT balance INTO v_balance_before
  FROM public.user_wallets
  WHERE id = v_wallet_id
  FOR UPDATE;
  
  -- Calculate new balance
  v_balance_after := v_balance_before + p_amount;
  
  -- Create transaction record
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, transaction_type, amount,
    balance_before, balance_after, reference_type,
    reference_id, description, idempotency_key, metadata
  ) VALUES (
    v_wallet_id, p_user_id, 'credit', p_amount,
    v_balance_before, v_balance_after, p_reference_type,
    p_reference_id, p_description, p_idempotency_key, p_metadata
  )
  RETURNING id INTO v_transaction_id;
  
  -- Update wallet balance
  UPDATE public.user_wallets
  SET 
    balance = v_balance_after,
    total_earned = total_earned + p_amount,
    last_transaction_at = NOW(),
    updated_at = NOW()
  WHERE id = v_wallet_id;
  
  RETURN v_transaction_id;
END;
$$;


ALTER FUNCTION "public"."credit_wallet"("p_user_id" "uuid", "p_amount" numeric, "p_reference_type" "text", "p_reference_id" "uuid", "p_description" "text", "p_idempotency_key" "text", "p_metadata" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."customer_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text" DEFAULT NULL::"text") RETURNS TABLE("auth_user_id" "uuid", "customer_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_auth_user auth.users%ROWTYPE;
BEGIN
  -- 1) Create auth user (delegates password handling to Supabase auth schema)
  INSERT INTO auth.users (email, raw_user_meta_data, encrypted_password)
  VALUES (
    lower(trim(p_email)),
    jsonb_build_object(
      'full_name', NULLIF(trim(p_full_name), ''),
      'phone', NULLIF(trim(p_phone), ''),
      'account_type', 'customer'
    ),
    -- NOTE: Supabase normally manages password hashing; this placeholder assumes
    -- you call via Supabase RPC where password is handled by GoTrue.
    NULL
  )
  RETURNING * INTO v_auth_user;

  -- 2) Create customer row
  INSERT INTO public.customers (user_id, name, email, phone, created_at, updated_at)
  VALUES (
    v_auth_user.id,
    COALESCE(NULLIF(trim(p_full_name), ''), v_auth_user.email),
    v_auth_user.email,
    COALESCE(NULLIF(trim(p_phone), ''), 'unknown'),
    now(),
    now()
  );

  auth_user_id := v_auth_user.id;
  customer_id := v_auth_user.id; -- customers.user_id is the link; primary key may differ
  RETURN NEXT;
END;
$$;


ALTER FUNCTION "public"."customer_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."debit_wallet"("p_user_id" "uuid", "p_amount" numeric, "p_reference_type" "text", "p_reference_id" "uuid", "p_description" "text", "p_idempotency_key" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_wallet_id UUID;
  v_transaction_id UUID;
  v_balance_before NUMERIC;
  v_balance_after NUMERIC;
BEGIN
  -- Check idempotency key
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_transaction_id
    FROM public.wallet_transactions
    WHERE idempotency_key = p_idempotency_key;
    
    IF v_transaction_id IS NOT NULL THEN
      RETURN v_transaction_id;
    END IF;
  END IF;
  
  -- Get wallet with lock
  SELECT id, balance INTO v_wallet_id, v_balance_before
  FROM public.user_wallets
  WHERE user_id = p_user_id
  FOR UPDATE;
  
  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;
  
  -- Check sufficient balance
  IF v_balance_before < p_amount THEN
    RAISE EXCEPTION 'Insufficient balance. Available: %, Required: %', v_balance_before, p_amount;
  END IF;
  
  -- Check if wallet is locked
  IF EXISTS (
    SELECT 1 FROM public.user_wallets 
    WHERE id = v_wallet_id AND is_locked = true
  ) THEN
    RAISE EXCEPTION 'Wallet is locked. Contact support.';
  END IF;
  
  v_balance_after := v_balance_before - p_amount;
  
  -- Create transaction
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, transaction_type, amount,
    balance_before, balance_after, reference_type,
    reference_id, description, idempotency_key, metadata
  ) VALUES (
    v_wallet_id, p_user_id, 'debit', p_amount,
    v_balance_before, v_balance_after, p_reference_type,
    p_reference_id, p_description, p_idempotency_key, p_metadata
  )
  RETURNING id INTO v_transaction_id;
  
  -- Update wallet
  UPDATE public.user_wallets
  SET 
    balance = v_balance_after,
    total_spent = total_spent + p_amount,
    last_transaction_at = NOW(),
    updated_at = NOW()
  WHERE id = v_wallet_id;
  
  RETURN v_transaction_id;
END;
$$;


ALTER FUNCTION "public"."debit_wallet"("p_user_id" "uuid", "p_amount" numeric, "p_reference_type" "text", "p_reference_id" "uuid", "p_description" "text", "p_idempotency_key" "text", "p_metadata" "jsonb") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."decrement_product_inventory_on_order"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Only trigger when order moves to confirmed status
  IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'confirmed' THEN
    -- Decrement product quantity
    UPDATE products
    SET quantity = quantity - COALESCE(NEW.subtotal / NULLIF(NEW.total - NEW.shipping - NEW.tax, 0), 1),
        updated_at = NOW()
    WHERE id IN (
      SELECT product_id FROM order_items WHERE order_id = NEW.id
    );
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."decrement_product_inventory_on_order"() OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."enforce_middleman_catalog_limit"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
DECLARE
  v_tier TEXT;
  v_current_total NUMERIC(10,2);
  v_limit NUMERIC(10,2);
BEGIN
  -- Fetch user's tier
  SELECT tier INTO v_tier 
  FROM public.middleman_profiles 
  WHERE user_id = NEW.user_id;

  -- Map tier to limit (EGP)
  v_limit := CASE v_tier
    WHEN 'tier_75k'  THEN 75000
    WHEN 'tier_150k' THEN 150000
    WHEN 'tier_250k' THEN 250000
    WHEN 'tier_500k' THEN 500000
    WHEN 'tier_1m'   THEN 1000000
    WHEN 'tier_2m'   THEN 2000000
    ELSE 75000 -- Default fallback for new/unassigned users
  END;

  -- Calculate current active catalog total
  SELECT COALESCE(SUM(display_price), 0) INTO v_current_total
  FROM public.site_catalog
  WHERE user_id = NEW.user_id
    AND is_active = true
    AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);

  -- Add new/updated price
  v_current_total := v_current_total + NEW.display_price;

  -- Enforce limit
  IF v_current_total > v_limit THEN
    RAISE EXCEPTION 'Catalog limit exceeded for tier %. Current: %, New: %, Limit: % EGP',
      v_tier, v_current_total - NEW.display_price, v_current_total, v_limit;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."enforce_middleman_catalog_limit"() OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."ensure_shop_exists"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_account_type TEXT;
BEGIN
  -- Get account type
  SELECT account_type INTO v_account_type
  FROM public.users WHERE user_id = v_user_id;

  -- Create shop if not exists
  INSERT INTO public.shops (owner_id, slug, shop_type, status, settings)
  SELECT 
    v_user_id,
    'shop-' || v_user_id,
    v_account_type,
    'draft',
    '{}'::jsonb
  WHERE NOT EXISTS (
    SELECT 1 FROM public.shops WHERE owner_id = v_user_id
  );
END;
$$;


ALTER FUNCTION "public"."ensure_shop_exists"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."execute_push_campaign"("p_campaign_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_campaign RECORD;
    v_user_id UUID;
    v_sent_count INTEGER := 0;
    v_failed_count INTEGER := 0;
BEGIN
    -- Get campaign details
    SELECT * INTO v_campaign
    FROM public.push_campaigns
    WHERE id = p_campaign_id;
    
    IF v_campaign IS NULL THEN
        RAISE EXCEPTION 'Campaign not found';
    END IF;
    
    -- Update status
    UPDATE public.push_campaigns
    SET status = 'sending', sent_at = NOW()
    WHERE id = p_campaign_id;
    
    -- Get target user IDs
    FOR v_user_id IN (
        SELECT DISTINCT user_id
        FROM public.users
        WHERE (
            v_campaign.target_audience->'user_ids' IS NULL
            OR user_id = ANY((v_campaign.target_audience->'user_ids')::uuid[])
        )
        AND (
            v_campaign.target_audience->'account_types' IS NULL
            OR account_type = ANY((v_campaign.target_audience->'account_types')::text[])
        )
        AND user_id IN (
            SELECT DISTINCT user_id
            FROM public.push_subscriptions
            WHERE is_active = true
            AND token IS NOT NULL
        )
    ) LOOP
        -- Send notification
        BEGIN
            PERFORM public.send_push_notification(
                p_user_id := v_user_id,
                p_title := v_campaign.title,
                p_body := v_campaign.body,
                p_data := v_campaign.data,
                p_skip_quiet_hours := true
            );
            v_sent_count := v_sent_count + 1;
        EXCEPTION WHEN OTHERS THEN
            v_failed_count := v_failed_count + 1;
        END;
    END LOOP;
    
    -- Update campaign stats
    UPDATE public.push_campaigns
    SET
        status = 'completed',
        sent_count = v_sent_count,
        failed_count = v_failed_count,
        delivered_count = v_sent_count,  -- Assume sent = delivered for now
        completed_at = NOW()
    WHERE id = p_campaign_id;
    
    RETURN v_sent_count;
END;
$$;


ALTER FUNCTION "public"."execute_push_campaign"("p_campaign_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."export_patient_health_data"("p_patient_id" "uuid", "p_export_format" character varying DEFAULT 'json'::character varying) RETURNS TABLE("success" boolean, "message" "text", "export_id" "uuid", "export_url" "text", "exported_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
DECLARE
  v_export_id UUID;
  v_export_data JSONB;
  v_export_url TEXT;
BEGIN
  v_export_id := gen_random_uuid();

  -- Verify patient owns this data
  IF auth.uid() != p_patient_id THEN
    RETURN QUERY SELECT
      FALSE::BOOLEAN,
      'Unauthorized: Can only export own health data'::TEXT,
      NULL::UUID,
      NULL::TEXT,
      NULL::TIMESTAMPTZ;
    RETURN;
  END IF;

  -- Aggregate patient health data
  SELECT jsonb_build_object(
    'patient_id', p_patient_id,
    'export_date', NOW()::TEXT,
    'appointments', (
      SELECT jsonb_agg(jsonb_build_object(
        'id', id,
        'doctor_id', doctor_id,
        'date', appointment_date,
        'type', appointment_type,
        'reason', reason,
        'status', status
      ))
      FROM public.health_appointments
      WHERE patient_id = p_patient_id
      ORDER BY appointment_date DESC
    ),
    'medicines', (
      SELECT jsonb_agg(jsonb_build_object(
        'id', id,
        'name', medicine_name,
        'dosage', dosage,
        'frequency', frequency,
        'prescribed_date', prescribed_date
      ))
      FROM public.health_medicines
      WHERE user_id = p_patient_id
      ORDER BY prescribed_date DESC
    ),
    'medicines_purchased', (
      SELECT jsonb_agg(jsonb_build_object(
        'order_id', order_id,
        'total_amount', total_amount,
        'order_date', created_at,
        'items', (
          SELECT jsonb_agg(jsonb_build_object(
            'medicine_id', Medicine_id,
            'quantity', quantity,
            'price', price_per_unit
          ))
          FROM public.health_medicine_order_items
          WHERE order_id = health_medicine_orders.id
        )
      ))
      FROM public.health_medicine_orders
      WHERE user_id = p_patient_id
      ORDER BY created_at DESC
    )
  ) INTO v_export_data;

  -- Store export record
  INSERT INTO public.async_jobs (
    id,
    job_type,
    user_id,
    status,
    payload,
    result,
    created_at,
    updated_at
  )
  VALUES (
    v_export_id,
    'HEALTH_DATA_EXPORT',
    p_patient_id,
    'completed',
    jsonb_build_object('format', p_export_format),
    v_export_data,
    NOW(),
    NOW()
  );

  -- Generate export URL (would be S3/storage bucket in production)
  v_export_url := 'https://exports.aurora.local/health/' || v_export_id::TEXT || '.' || LOWER(p_export_format);

  -- Log the export
  INSERT INTO public.health_patient_access_log (
    user_id,
    action,
    resource_type,
    accessed_at,
    notes
  )
  VALUES (
    p_patient_id,
    'HEALTH_DATA_EXPORTED',
    'health_records',
    NOW(),
    'Format: ' || p_export_format
  );

  RETURN QUERY SELECT
    TRUE::BOOLEAN,
    'Health data exported successfully'::TEXT,
    v_export_id,
    v_export_url,
    NOW();
END;
$$;


ALTER FUNCTION "public"."export_patient_health_data"("p_patient_id" "uuid", "p_export_format" character varying) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fill_prescription_medicine"("p_prescription_medicine_id" "uuid", "p_pharmacy_id" "uuid", "p_dispensed_quantity" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_prescription_medicine RECORD;
    v_inventory RECORD;
    v_result JSONB;
BEGIN
    -- Get prescription medicine
    SELECT * INTO v_prescription_medicine
    FROM public.health_prescription_medicines_digital
    WHERE id = p_prescription_medicine_id;
    
    IF v_prescription_medicine IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Prescription medicine not found');
    END IF;
    
    IF v_prescription_medicine.is_dispensed THEN
        RETURN jsonb_build_object('success', false, 'error', 'Medicine already dispensed');
    END IF;
    
    -- Check pharmacy inventory
    SELECT * INTO v_inventory
    FROM public.health_medicines
    WHERE pharmacy_id = p_pharmacy_id
    AND medicine_id = v_prescription_medicine.medicine_id
    AND quantity_in_stock >= p_dispensed_quantity
    AND is_available = TRUE
    LIMIT 1;
    
    IF v_inventory IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Medicine not available in pharmacy inventory');
    END IF;
    
    -- Update prescription medicine
    UPDATE public.health_prescription_medicines_digital
    SET 
        is_dispensed = TRUE,
        dispensed_at = NOW(),
        dispensed_by_pharmacy_id = p_pharmacy_id,
        dispensed_quantity = p_dispensed_quantity,
        updated_at = NOW()
    WHERE id = p_prescription_medicine_id;
    
    -- Update pharmacy inventory
    UPDATE public.health_medicines
    SET 
        quantity_in_stock = quantity_in_stock - p_dispensed_quantity,
        updated_at = NOW()
    WHERE id = v_inventory.id;
    
    -- Update prescription times filled
    UPDATE public.health_prescriptions_digital
    SET 
        times_filled = times_filled + 1,
        filled_at = NOW()
    WHERE id = v_prescription_medicine.prescription_id;
    
    -- Log action
    INSERT INTO public.health_prescription_audit_log (
        prescription_id,
        action_type,
        action_by,
        action_by_role,
        action_details
    ) VALUES (
        v_prescription_medicine.prescription_id,
        'filled',
        p_pharmacy_id,
        'pharmacy',
        jsonb_build_object(
            'medicine_id', v_prescription_medicine.medicine_id,
            'quantity', p_dispensed_quantity,
            'pharmacy_id', p_pharmacy_id
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Prescription medicine dispensed successfully',
        'prescription_medicine_id', p_prescription_medicine_id,
        'dispensed_at', NOW()
    );
END;
$$;


ALTER FUNCTION "public"."fill_prescription_medicine"("p_prescription_medicine_id" "uuid", "p_pharmacy_id" "uuid", "p_dispensed_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_factories"("p_search_term" "text" DEFAULT NULL::"text", "p_location" "text" DEFAULT NULL::"text", "p_is_verified" boolean DEFAULT NULL::boolean, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS TABLE("user_id" "uuid", "email" "text", "full_name" "text", "phone" "text", "location" "text", "is_verified" boolean, "created_at" timestamp with time zone, "product_count" bigint, "total_revenue" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.user_id,
    s.email,
    s.full_name,
    s.phone,
    s.location,
    s.is_verified,
    s.created_at,
    COALESCE(pc.count, 0)::BIGINT as product_count,
    COALESCE(sr.total_revenue, 0)::NUMERIC as total_revenue
  FROM public.sellers s
  LEFT JOIN (
    SELECT seller_id, COUNT(*) as count 
    FROM public.products 
    WHERE is_deleted = false 
    GROUP BY seller_id
  ) pc ON pc.seller_id = s.user_id
  LEFT JOIN (
    SELECT seller_id, SUM(total_price) as total_revenue 
    FROM public.sales 
    GROUP BY seller_id
  ) sr ON sr.seller_id = s.user_id
  WHERE 
    (p_search_term IS NULL OR 
      s.full_name ILIKE '%' || p_search_term || '%' OR 
      s.email ILIKE '%' || p_search_term || '%' OR
      s.location ILIKE '%' || p_search_term || '%')
    AND (p_location IS NULL OR s.location ILIKE '%' || p_location || '%')
    AND (p_is_verified IS NULL OR s.is_verified = p_is_verified)
  ORDER BY s.is_verified DESC, product_count DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."find_factories"("p_search_term" "text", "p_location" "text", "p_is_verified" boolean, "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_nearby_drivers"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric DEFAULT 50, "p_limit_count" integer DEFAULT 20) RETURNS TABLE("driver_id" "uuid", "full_name" "text", "vehicle_type" "text", "latitude" numeric, "longitude" numeric, "distance_km" numeric, "rating" numeric, "is_verified" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    dp.user_id AS driver_id,
    u.full_name,
    dp.vehicle_type,
    dp.latitude,
    dp.longitude,
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
  LIMIT p_limit_count;
END;
$$;


ALTER FUNCTION "public"."find_nearby_drivers"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_nearby_drivers_for_middleman"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric DEFAULT 20.0, "p_limit" integer DEFAULT 10) RETURNS TABLE("driver_id" "uuid", "full_name" "text", "vehicle_type" "text", "distance_km" numeric, "rating" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dp.user_id,
    u.full_name,
    dp.vehicle_type,
    haversine_distance(p_latitude, p_longitude, dp.latitude, dp.longitude)::numeric as distance_km,
    dp.rating
  FROM public.delivery_profiles dp
  JOIN public.users u ON u.user_id = dp.user_id
  WHERE dp.is_active = true 
    AND dp.is_verified = true
    AND dp.latitude IS NOT NULL
    AND dp.longitude IS NOT NULL
    AND haversine_distance(p_latitude, p_longitude, dp.latitude, dp.longitude) <= p_max_distance_km
  ORDER BY distance_km ASC
  LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."find_nearby_drivers_for_middleman"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_nearby_factories"("p_seller_id" "uuid", "p_max_distance_km" numeric DEFAULT 100, "p_limit_count" integer DEFAULT 20) RETURNS TABLE("factory_id" "uuid", "factory_name" "text", "distance_km" numeric, "latitude" numeric, "longitude" numeric, "location" "text", "is_verified" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
DECLARE
  v_seller_lat NUMERIC;
  v_seller_lon NUMERIC;
BEGIN
  -- Security check
  IF auth.uid() IS NOT NULL AND auth.uid() != p_seller_id THEN
    RAISE EXCEPTION 'Access denied: can only search factories for your own seller account';
  END IF;

  -- Get current seller's location
  SELECT latitude, longitude 
  INTO v_seller_lat, v_seller_lon
  FROM sellers 
  WHERE user_id = p_seller_id;

  IF v_seller_lat IS NULL OR v_seller_lon IS NULL THEN
    RAISE EXCEPTION 'Seller location not set. Please update your profile location.';
  END IF;

  RETURN QUERY
  SELECT
    f.user_id AS factory_id,
    f.full_name AS factory_name,    -- ✅ Use full_name instead
    haversine_distance(v_seller_lat, v_seller_lon, f.latitude, f.longitude) AS distance_km,
    f.latitude,
    f.longitude,
    f.location,
    f.is_verified
  FROM sellers f
  WHERE f.is_factory = true
    AND f.latitude IS NOT NULL 
    AND f.longitude IS NOT NULL
    AND f.user_id != p_seller_id  -- Exclude self
    AND haversine_distance(v_seller_lat, v_seller_lon, f.latitude, f.longitude) <= p_max_distance_km
  ORDER BY distance_km
  LIMIT p_limit_count;
END;
$$;


ALTER FUNCTION "public"."find_nearby_factories"("p_seller_id" "uuid", "p_max_distance_km" numeric, "p_limit_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_nearby_factories"("p_seller_id" "uuid", "p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric DEFAULT 100, "p_limit_count" integer DEFAULT 20) RETURNS TABLE("factory_id" "uuid", "company_name" "text", "latitude" numeric, "longitude" numeric, "distance_km" numeric, "location" "text", "is_verified" boolean, "rating" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.user_id AS factory_id,
    s.company_name,
    s.latitude,
    s.longitude,
    haversine_distance(p_latitude, p_longitude, s.latitude, s.longitude) AS distance_km,
    s.location,
    s.is_verified,
    s.rating
  FROM sellers s
  WHERE s.is_factory = true
    AND s.latitude IS NOT NULL
    AND s.longitude IS NOT NULL
    AND s.user_id != p_seller_id
    AND haversine_distance(p_latitude, p_longitude, s.latitude, s.longitude) <= p_max_distance_km
  ORDER BY distance_km
  LIMIT p_limit_count;
END;
$$;


ALTER FUNCTION "public"."find_nearby_factories"("p_seller_id" "uuid", "p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_nearby_products_for_middleman"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric DEFAULT 50.0, "p_limit" integer DEFAULT 20) RETURNS TABLE("product_id" "uuid", "title" "text", "price" numeric, "images" "jsonb", "seller_name" "text", "distance_km" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.title,
    p.price,
    p.images,
    s.full_name as seller_name,
    haversine_distance(p_latitude, p_longitude, s.latitude, s.longitude)::numeric as distance_km
  FROM public.products p
  JOIN public.sellers s ON s.user_id = p.seller_id
  WHERE p.status = 'active'
    AND s.latitude IS NOT NULL
    AND s.longitude IS NOT NULL
    AND haversine_distance(p_latitude, p_longitude, s.latitude, s.longitude) <= p_max_distance_km
  ORDER BY distance_km ASC
  LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."find_nearby_products_for_middleman"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_nearby_sellers"("p_latitude" numeric, "p_longitude" numeric, "p_radius_km" numeric DEFAULT 50, "p_limit" integer DEFAULT 20) RETURNS TABLE("user_id" "uuid", "email" "text", "full_name" "text", "phone" "text", "location" "text", "latitude" numeric, "longitude" numeric, "distance_km" numeric, "is_verified" boolean, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  EARTH_RADIUS_KM CONSTANT NUMERIC := 6371;
  lat1_rad NUMERIC;
  lon1_rad NUMERIC;
BEGIN
  lat1_rad := p_latitude * PI() / 180;
  lon1_rad := p_longitude * PI() / 180;

  RETURN QUERY
  SELECT 
    s.user_id,
    s.email,
    s.full_name,
    s.phone,
    s.location,
    s.latitude,
    s.longitude,
    (
      EARTH_RADIUS_KM * 2 * ASIN(
        SQRT(
          POWER(SIN((lat1_rad - (s.latitude * PI() / 180)) / 2), 2) +
          COS(lat1_rad) * COS(s.latitude * PI() / 180) * 
          POWER(SIN((lon1_rad - (s.longitude * PI() / 180)) / 2), 2)
        )
      )
    )::NUMERIC(10, 2) AS distance_km,
    s.is_verified,
    s.created_at
  FROM public.sellers s
  WHERE 
    s.latitude IS NOT NULL 
    AND s.longitude IS NOT NULL
    AND s.latitude BETWEEN (p_latitude - (p_radius_km / 111)) 
                       AND (p_latitude + (p_radius_km / 111))
    AND s.longitude BETWEEN (p_longitude - (p_radius_km / (111 * COS(RADIANS(p_latitude))))) 
                        AND (p_longitude + (p_radius_km / (111 * COS(RADIANS(p_latitude)))))
    AND (
      EARTH_RADIUS_KM * 2 * ASIN(
        SQRT(
          POWER(SIN((lat1_rad - (s.latitude * PI() / 180)) / 2), 2) +
          COS(lat1_rad) * COS(s.latitude * PI() / 180) * 
          POWER(SIN((lon1_rad - (s.longitude * PI() / 180)) / 2), 2)
        )
      )
    ) <= p_radius_km
  ORDER BY distance_km ASC
  LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."find_nearby_sellers"("p_latitude" numeric, "p_longitude" numeric, "p_radius_km" numeric, "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_cod_verification_key"("p_order_id" "uuid", "p_key_length" integer DEFAULT 6, "p_expiry_hours" integer DEFAULT 24) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_verification_key TEXT;
  v_key_id UUID;
  v_order RECORD;
BEGIN
  -- Get order details
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  
  IF v_order IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;
  
  IF v_order.payment_method != 'cod' THEN
    RAISE EXCEPTION 'Verification key only for COD orders. Payment method: %', v_order.payment_method;
  END IF;
  
  -- Generate unique numeric key
  LOOP
    v_verification_key := 'COD-' || LPAD(FLOOR(RANDOM() * (10 ^ p_key_length))::TEXT, p_key_length, '0');
    
    -- Check if key already exists
    IF NOT EXISTS (SELECT 1 FROM public.cod_verification_keys WHERE verification_key = v_verification_key) THEN
      EXIT;
    END IF;
  END LOOP;
  
  -- Insert or update verification key
  INSERT INTO public.cod_verification_keys (
    order_id,
    verification_key,
    key_type,
    key_length,
    status,
    expires_at,
    metadata
  ) VALUES (
    p_order_id,
    v_verification_key,
    'numeric',
    p_key_length,
    'pending',
    NOW() + (p_expiry_hours || ' hours')::INTERVAL,
    jsonb_build_object(
      'order_total', v_order.total,
      'customer_id', v_order.user_id,
      'delivery_address', v_order.shipping_address_snapshot
    )
  )
  ON CONFLICT (order_id) DO UPDATE SET
    verification_key = EXCLUDED.verification_key,
    status = 'pending',
    expires_at = EXCLUDED.expires_at,
    verification_attempts = 0,
    updated_at = NOW()
  RETURNING id INTO v_key_id;
  
  -- Update order
  UPDATE public.orders
  SET 
    cod_verification_required = true,
    cod_verified = false,
    cod_collection_amount = v_order.total,
    updated_at = NOW()
  WHERE id = p_order_id;
  
  -- Create COD collection record
  INSERT INTO public.cod_collections (
    order_id,
    customer_id,
    collection_amount,
    verification_key_id,
    status
  ) VALUES (
    p_order_id,
    v_order.user_id,
    v_order.total,
    v_key_id,
    'pending'
  );
  
  -- Send notification to customer with key
  INSERT INTO public.notifications (user_id, type, title, message, metadata)
  VALUES (
    v_order.user_id,
    'order',
    '🔐 COD Verification Key',
    'Your verification key for order ' || SUBSTRING(p_order_id::TEXT, 1, 8) || ' is: ' || v_verification_key || '. Share this with the delivery driver upon payment.',
    jsonb_build_object(
      'order_id', p_order_id,
      'verification_key', v_verification_key,
      'expires_at', NOW() + (p_expiry_hours || ' hours')::INTERVAL
    )
  );
  
  RETURN v_verification_key;
END;
$$;


ALTER FUNCTION "public"."generate_cod_verification_key"("p_order_id" "uuid", "p_key_length" integer, "p_expiry_hours" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_medicine_qr_code"("p_pharmacy_id" "uuid", "p_medicine_id" "uuid", "p_batch_number" "text") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_qr_code TEXT;
    v_prefix TEXT;
BEGIN
    SELECT qr_code_prefix INTO v_prefix
    FROM public.pharmacy_profiles
    WHERE id = p_pharmacy_id;
    
    IF v_prefix IS NULL THEN
        v_prefix := 'PH' || SUBSTRING(p_pharmacy_id::text FROM 1 FOR 6);
        UPDATE public.pharmacy_profiles
        SET qr_code_prefix = v_prefix
        WHERE id = p_pharmacy_id;
    END IF;
    
    v_qr_code := v_prefix || '-' || 
                 SUBSTRING(p_medicine_id::text FROM 1 FOR 8) || '-' || 
                 p_batch_number || '-' || 
                 TO_CHAR(NOW(), 'YYYYMMDDHH24MISS');
    
    RETURN v_qr_code;
END;
$$;


ALTER FUNCTION "public"."generate_medicine_qr_code"("p_pharmacy_id" "uuid", "p_medicine_id" "uuid", "p_batch_number" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_patient_archive_json"("p_doctor_id" "uuid", "p_patient_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_patient_data JSONB;
    v_appointments JSONB;
    v_prescriptions JSONB;
    v_messages JSONB;
    v_conversations JSONB;
    v_medical_history JSONB;
    v_vitals JSONB;
    v_notes JSONB;
    v_archive_data JSONB;
BEGIN
    -- Patient Profile
    SELECT jsonb_build_object(
        'id', pp.id,
        'user_id', pp.user_id,
        'date_of_birth', pp.date_of_birth,
        'blood_type', pp.blood_type,
        'medical_history', pp.medical_history,
        'total_visits', pp.total_visits,
        'last_visit_date', pp.last_visit_date,
        'created_at', pp.created_at,
        'updated_at', pp.updated_at
    ) INTO v_patient_data
    FROM public.health_patient_profiles pp
    WHERE pp.id = p_patient_id;

    -- Appointments with this doctor
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', a.id,
            'scheduled_at', a.scheduled_at,
            'status', a.status,
            'slot_type', a.slot_type,
            'payment_amount', a.payment_amount,
            'notes', a.notes,
            'prescription_summary', a.prescription_summary,
            'created_at', a.created_at
        )
    ), '[]'::jsonb) INTO v_appointments
    FROM public.health_appointments a
    WHERE a.patient_id = p_patient_id
    AND a.doctor_id = p_doctor_id;

    -- Prescriptions from this doctor
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', pr.id,
            'appointment_id', pr.appointment_id,
            'medicine_name', pr.medicine_name,
            'dosage_instructions', pr.dosage_instructions,
            'duration_days', pr.duration_days,
            'is_dispensed', pr.is_dispensed,
            'created_at', pr.created_at
        )
    ), '[]'::jsonb) INTO v_prescriptions
    FROM public.health_prescriptions pr
    JOIN public.health_appointments a ON a.id = pr.appointment_id
    WHERE a.patient_id = p_patient_id
    AND a.doctor_id = p_doctor_id;

    -- Messages/Chat History
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', m.id,
            'conversation_id', m.conversation_id,
            'sender_id', m.sender_id,
            'content', m.content,
            'message_type', m.message_type,
            'created_at', m.created_at
        )
    ), '[]'::jsonb) INTO v_messages
    FROM public.health_messages m
    JOIN public.health_conversations c ON c.id = m.conversation_id
    JOIN public.health_appointments a ON a.id = c.appointment_id
    WHERE a.patient_id = p_patient_id
    AND a.doctor_id = p_doctor_id
    ORDER BY m.created_at ASC;

    -- Conversations
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', c.id,
            'appointment_id', c.appointment_id,
            'created_at', c.created_at,
            'updated_at', c.updated_at,
            'message_count', (
                SELECT COUNT(*) FROM public.health_messages 
                WHERE conversation_id = c.id
            )
        )
    ), '[]'::jsonb) INTO v_conversations
    FROM public.health_conversations c
    JOIN public.health_appointments a ON a.id = c.appointment_id
    WHERE a.patient_id = p_patient_id
    AND a.doctor_id = p_doctor_id;

    -- Build complete archive
    v_archive_data := jsonb_build_object(
        'archive_version', '1.0',
        'generated_at', NOW(),
        'doctor_id', p_doctor_id,
        'patient', v_patient_data,
        'appointments', v_appointments,
        'prescriptions', v_prescriptions,
        'messages', v_messages,
        'conversations', v_conversations,
        'summary', jsonb_build_object(
            'total_appointments', jsonb_array_length(v_appointments),
            'total_prescriptions', jsonb_array_length(v_prescriptions),
            'total_messages', jsonb_array_length(v_messages),
            'last_appointment', (
                SELECT MAX(scheduled_at) FROM public.health_appointments 
                WHERE patient_id = p_patient_id AND doctor_id = p_doctor_id
            ),
            'last_message', (
                SELECT MAX(created_at) FROM public.health_messages m
                JOIN public.health_conversations c ON c.id = m.conversation_id
                JOIN public.health_appointments a ON a.id = c.appointment_id
                WHERE a.patient_id = p_patient_id AND a.doctor_id = p_doctor_id
            )
        )
    );

    RETURN v_archive_data;
END;
$$;


ALTER FUNCTION "public"."generate_patient_archive_json"("p_doctor_id" "uuid", "p_patient_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_pharmacy_daily_report"("p_pharmacy_id" "uuid", "p_report_date" "date" DEFAULT CURRENT_DATE) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_report_id UUID;
    v_total_scans INTEGER;
    v_total_sales INTEGER;
    v_total_revenue NUMERIC;
    v_medicines_added INTEGER;
    v_medicines_expired INTEGER;
    v_low_stock_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total_scans
    FROM public.pharmacy_qr_scan_logs
    WHERE pharmacy_id = p_pharmacy_id
    AND DATE(created_at) = p_report_date;
    
    SELECT COUNT(*), COALESCE(SUM(quantity_change * price), 0)
    INTO v_total_sales, v_total_revenue
    FROM public.pharmacy_stock_movements sm
    JOIN public.pharmacy_medicine_inventory inv ON inv.id = sm.inventory_id
    WHERE sm.pharmacy_id = p_pharmacy_id
    AND sm.movement_type = 'sell'
    AND DATE(sm.created_at) = p_report_date;
    
    SELECT COUNT(*) INTO v_medicines_added
    FROM public.pharmacy_stock_movements
    WHERE pharmacy_id = p_pharmacy_id
    AND movement_type = 'receive'
    AND DATE(created_at) = p_report_date;
    
    SELECT COUNT(*) INTO v_medicines_expired
    FROM public.pharmacy_medicine_inventory
    WHERE pharmacy_id = p_pharmacy_id
    AND is_expired = TRUE
    AND DATE(updated_at) = p_report_date;
    
    SELECT COUNT(*) INTO v_low_stock_count
    FROM public.pharmacy_medicine_inventory
    WHERE pharmacy_id = p_pharmacy_id
    AND quantity_in_stock <= 10
    AND is_available = TRUE;
    
    INSERT INTO public.pharmacy_daily_reports (
        pharmacy_id,
        report_date,
        total_scans,
        total_sales,
        total_revenue,
        medicines_added,
        medicines_expired,
        low_stock_count,
        report_data
    ) VALUES (
        p_pharmacy_id,
        p_report_date,
        v_total_scans,
        v_total_sales,
        v_total_revenue,
        v_medicines_added,
        v_medicines_expired,
        v_low_stock_count,
        jsonb_build_object(
            'generated_at', NOW(),
            'scans', v_total_scans,
            'sales', v_total_sales,
            'revenue', v_total_revenue,
            'added', v_medicines_added,
            'expired', v_medicines_expired,
            'low_stock', v_low_stock_count
        )
    )
    ON CONFLICT (pharmacy_id, report_date)
    DO UPDATE SET
        total_scans = EXCLUDED.total_scans,
        total_sales = EXCLUDED.total_sales,
        total_revenue = EXCLUDED.total_revenue,
        medicines_added = EXCLUDED.medicines_added,
        medicines_expired = EXCLUDED.medicines_expired,
        low_stock_count = EXCLUDED.low_stock_count,
        report_data = EXCLUDED.report_data,
        generated_at = NOW()
    RETURNING id INTO v_report_id;
    
    RETURN v_report_id;
END;
$$;


ALTER FUNCTION "public"."generate_pharmacy_daily_report"("p_pharmacy_id" "uuid", "p_report_date" "date") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."generate_website_embed_code"("p_website_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_api_key TEXT;
  v_seller_id UUID;
BEGIN
  SELECT api_key, seller_id INTO v_api_key, v_seller_id
  FROM public.websites WHERE id = p_website_id AND seller_id = auth.uid();
  
  IF v_api_key IS NULL THEN RAISE EXCEPTION 'Website not found'; END IF;
  
  RETURN '<script src="https://aurora.com/embed.js" data-api-key="' || v_api_key || '"></script>';
END;
$$;


ALTER FUNCTION "public"."generate_website_embed_code"("p_website_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_cod_reconciliation_report"("p_start_date" "date" DEFAULT (CURRENT_DATE - '7 days'::interval), "p_end_date" "date" DEFAULT CURRENT_DATE) RETURNS TABLE("date" "date", "total_cod_orders" bigint, "total_cod_amount" numeric, "verified_orders" bigint, "pending_orders" bigint, "failed_orders" bigint, "collected_amount" numeric, "deposited_amount" numeric, "pending_deposit" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    DATE(o.created_at) AS date,
    COUNT(o.id) AS total_cod_orders,
    SUM(o.total) AS total_cod_amount,
    COUNT(CASE WHEN o.cod_verified = true THEN 1 END) AS verified_orders,
    COUNT(CASE WHEN o.cod_verified = false AND o.status != 'cancelled' THEN 1 END) AS pending_orders,
    COUNT(CASE WHEN o.cod_collection_status = 'failed' THEN 1 END) AS failed_orders,
    SUM(CASE WHEN o.cod_verified = true THEN o.total ELSE 0 END) AS collected_amount,
    SUM(CASE WHEN cc.status = 'deposited' THEN o.total ELSE 0 END) AS deposited_amount,
    SUM(CASE WHEN o.cod_verified = true AND cc.status != 'deposited' THEN o.total ELSE 0 END) AS pending_deposit
  FROM public.orders o
  LEFT JOIN public.cod_collections cc ON cc.order_id = o.id
  WHERE o.payment_method = 'cod'
    AND DATE(o.created_at) BETWEEN p_start_date AND p_end_date
  GROUP BY DATE(o.created_at)
  ORDER BY date DESC;
END;
$$;


ALTER FUNCTION "public"."get_cod_reconciliation_report"("p_start_date" "date", "p_end_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_driver_cod_orders"("p_driver_id" "uuid") RETURNS TABLE("order_id" "uuid", "customer_name" "text", "customer_phone" "text", "delivery_address" "jsonb", "total_amount" numeric, "verification_key" "text", "expires_at" timestamp with time zone, "status" "text", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    o.id AS order_id,
    u.full_name AS customer_name,
    u.phone AS customer_phone,
    o.shipping_address_snapshot AS delivery_address,
    o.total AS total_amount,
    cvk.verification_key,
    cvk.expires_at,
    cvk.status AS verification_status,
    o.created_at
  FROM public.orders o
  JOIN public.cod_verification_keys cvk ON cvk.order_id = o.id
  JOIN public.users u ON u.user_id = o.user_id
  WHERE o.delivery_id = p_driver_id
    AND o.payment_method = 'cod'
    AND cvk.status = 'pending'
    AND cvk.expires_at > NOW()
  ORDER BY o.created_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_driver_cod_orders"("p_driver_id" "uuid") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."get_feed_posts"("p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0, "p_user_id" "uuid" DEFAULT NULL::"uuid", "p_post_type" "text" DEFAULT NULL::"text") RETURNS TABLE("id" "uuid", "user_id" "uuid", "seller_id" "uuid", "product_id" "uuid", "content" "text", "media_urls" "jsonb", "post_type" "text", "likes_count" integer, "comments_count" integer, "shares_count" integer, "created_at" timestamp with time zone, "author_full_name" "text", "author_avatar_url" "text", "author_account_type" "text", "is_verified" boolean, "product_title" "text", "product_price" numeric, "product_image" "text", "is_liked_by_user" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.user_id,
    p.seller_id,
    p.product_id,
    p.content,
    p.media_urls,
    p.post_type,
    p.likes_count,
    p.comments_count,
    p.shares_count,
    p.created_at,
    u.full_name AS author_full_name,
    u.avatar_url AS author_avatar_url,
    u.account_type AS author_account_type,
    COALESCE(s.is_verified, false) AS is_verified,
    prod.title AS product_title,
    prod.price AS product_price,
    prod.images->>0 AS product_image,
    EXISTS (
      SELECT 1 FROM post_likes pl 
      WHERE pl.post_id = p.id AND pl.user_id = p_user_id
    ) AS is_liked_by_user
  FROM posts p
  LEFT JOIN users u ON u.user_id = p.user_id
  LEFT JOIN sellers s ON s.user_id = p.user_id
  LEFT JOIN products prod ON prod.id = p.product_id
  WHERE p.is_deleted = false
    AND (p_user_id IS NULL OR p.user_id = p_user_id)
    AND (p_post_type IS NULL OR p.post_type = p_post_type)
  ORDER BY p.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."get_feed_posts"("p_limit" integer, "p_offset" integer, "p_user_id" "uuid", "p_post_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_health_audit_logs"("p_user_id" "uuid", "p_limit" integer DEFAULT 100, "p_offset" integer DEFAULT 0) RETURNS TABLE("id" "uuid", "action" character varying, "resource_type" character varying, "accessed_at" timestamp with time zone, "notes" "text", "accessed_by" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
BEGIN
  -- Only allow users to see their own logs or admins to see all
  IF auth.uid() != p_user_id AND NOT is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  RETURN QUERY
  SELECT
    hal.id,
    hal.action::VARCHAR,
    hal.resource_type::VARCHAR,
    hal.accessed_at,
    hal.notes,
    hal.user_id
  FROM public.health_patient_access_log hal
  WHERE hal.user_id = p_user_id
  ORDER BY hal.accessed_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."get_health_audit_logs"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_health_conversation_messages"("p_conversation_id" "uuid", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0, "p_before_timestamp" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS TABLE("id" "uuid", "sender_id" "uuid", "sender_role" "text", "content" "text", "message_type" "text", "attachment_url" "text", "attachment_name" "text", "attachment_size" bigint, "attachment_type" "text", "is_read" boolean, "read_at" timestamp with time zone, "created_at" timestamp with time zone, "sender_name" "text", "sender_avatar" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Security check
    IF NOT EXISTS (
        SELECT 1 FROM public.health_conversations
        WHERE id = p_conversation_id
        AND (
            doctor_id IN (SELECT id FROM public.health_doctor_profiles WHERE user_id = auth.uid())
            OR patient_id IN (SELECT id FROM public.health_patient_profiles WHERE user_id = auth.uid())
        )
    ) THEN
        RAISE EXCEPTION 'Access denied: You are not a participant in this conversation';
    END IF;
    
    RETURN QUERY
    SELECT
        hm.id,
        hm.sender_id,
        hm.sender_role,
        hm.content,
        hm.message_type,
        hm.attachment_url,
        hm.attachment_name,
        hm.attachment_size,
        hm.attachment_type,
        hm.is_read,
        hm.read_at,
        hm.created_at,
        CASE WHEN hm.sender_role = 'doctor' THEN dp.full_name ELSE pp.name END,
        u.avatar_url
    FROM public.health_messages hm
    JOIN public.health_conversations hc ON hc.id = hm.conversation_id
    LEFT JOIN public.health_doctor_profiles dp ON dp.id = hc.doctor_id
    LEFT JOIN public.health_patient_profiles pp ON pp.id = hc.patient_id
    LEFT JOIN public.users u ON u.user_id = hm.sender_id
    WHERE hm.conversation_id = p_conversation_id
    AND hm.is_deleted = false
    AND (p_before_timestamp IS NULL OR hm.created_at < p_before_timestamp)
    ORDER BY hm.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."get_health_conversation_messages"("p_conversation_id" "uuid", "p_limit" integer, "p_offset" integer, "p_before_timestamp" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_health_conversations_list"("p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0, "p_status" "text" DEFAULT 'active'::"text") RETURNS TABLE("conversation_id" "uuid", "appointment_id" "uuid", "other_party_id" "uuid", "other_party_name" "text", "other_party_avatar" "text", "other_party_role" "text", "last_message" "text", "last_message_at" timestamp with time zone, "unread_count" bigint, "conversation_type" "text", "status" "text", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_doctor BOOLEAN;
    v_profile_id UUID;
BEGIN
    -- Check if user is doctor or patient
    SELECT id INTO v_profile_id FROM public.health_doctor_profiles WHERE user_id = v_user_id;
    v_is_doctor := v_profile_id IS NOT NULL;
    
    IF NOT v_is_doctor THEN
        SELECT id INTO v_profile_id FROM public.health_patient_profiles WHERE user_id = v_user_id;
    END IF;
    
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'User is not a doctor or patient';
    END IF;
    
    RETURN QUERY
    SELECT
        hc.id AS conversation_id,
        hc.appointment_id,
        CASE WHEN v_is_doctor THEN hc.patient_id ELSE hc.doctor_id END AS other_party_id,
        CASE 
            WHEN v_is_doctor THEN (SELECT name FROM public.health_patient_profiles WHERE id = hc.patient_id)
            ELSE (SELECT full_name FROM public.health_doctor_profiles WHERE id = hc.doctor_id)
        END AS other_party_name,
        u.avatar_url AS other_party_avatar,
        CASE WHEN v_is_doctor THEN 'patient' ELSE 'doctor' END AS other_party_role,
        hc.last_message,
        hc.last_message_at,
        (
            SELECT COUNT(*)
            FROM public.health_messages hm
            WHERE hm.conversation_id = hc.id
            AND hm.sender_id != v_user_id
            AND hm.is_read = false
            AND hm.is_deleted = false
        ) AS unread_count,
        hc.conversation_type,
        hc.status,
        hc.created_at
    FROM public.health_conversations hc
    LEFT JOIN public.users u ON u.user_id = (
        CASE WHEN v_is_doctor THEN 
            (SELECT user_id FROM public.health_patient_profiles WHERE id = hc.patient_id)
        ELSE 
            (SELECT user_id FROM public.health_doctor_profiles WHERE id = hc.doctor_id)
        END
    )
    WHERE 
        (v_is_doctor AND hc.doctor_id = v_profile_id)
        OR (NOT v_is_doctor AND hc.patient_id = v_profile_id)
    AND (p_status IS NULL OR hc.status = p_status)
    ORDER BY hc.last_message_at DESC NULLS LAST
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."get_health_conversations_list"("p_limit" integer, "p_offset" integer, "p_status" "text") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."get_marketplace_products_for_middlemen"("p_category" "text" DEFAULT NULL::"text", "p_min_price" numeric DEFAULT 0, "p_max_price" numeric DEFAULT 99999, "p_min_stock" integer DEFAULT 5, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS TABLE("asin" "text", "title" "text", "description" "text", "price" numeric, "images" "jsonb", "seller_id" "uuid", "seller_name" "text", "seller_rating" numeric, "stock_quantity" integer, "category" "text", "is_local_brand" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.asin, p.title, p.description, p.price, p.images,
    p.seller_id, s.full_name as seller_name, 
    COALESCE((SELECT AVG(rating) FROM public.reviews WHERE asin = p.asin AND is_approved = true), 0) as seller_rating,
    p.quantity as stock_quantity, p.category, p.is_local_brand
  FROM public.products p
  JOIN public.sellers s ON s.user_id = p.seller_id
  WHERE p.status = 'active'
    AND p.is_deleted = false
    AND p.quantity >= p_min_stock
    AND p.price BETWEEN p_min_price AND p_max_price
    AND (p_category IS NULL OR p.category ILIKE '%' || p_category || '%')
  ORDER BY p.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."get_marketplace_products_for_middlemen"("p_category" "text", "p_min_price" numeric, "p_max_price" numeric, "p_min_stock" integer, "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_middle_man_ids"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid;
  v_profile_exists boolean;
BEGIN
  v_user_id := auth.uid();
  
  -- Check if profile exists
  SELECT EXISTS(SELECT 1 FROM public.middleman_profiles WHERE user_id = v_user_id) INTO v_profile_exists;

  RETURN jsonb_build_object(
    'user_id', v_user_id,             -- This is your Main ID (Primary Key)
    'middle_man_record_id', v_user_id, -- Same as user_id
    'profile_record_id', v_user_id,    -- Same as user_id (linked by FK)
    'profile_exists', v_profile_exists
  );
END;
$$;


ALTER FUNCTION "public"."get_middle_man_ids"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_middleman_profile"("target_user_id" "uuid") RETURNS TABLE("user_id" "uuid", "full_name" "text", "avatar_url" "text", "company_name" "text", "is_verified" boolean, "phone" "text", "email" "text", "location_city" "text", "location_country" "text", "total_connections" bigint, "active_deals" bigint, "total_revenue" numeric, "rating_avg" numeric, "joined_date" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
   	BEGIN
   	    RETURN QUERY
   	    SELECT 
   	        u.id AS user_id,
	        (u.raw_user_meta_data->>'full_name')::TEXT AS full_name,
	        (u.raw_user_meta_data->>'avatar_url')::TEXT AS avatar_url,
	        (u.raw_user_meta_data->>'company_name')::TEXT AS company_name,
|	        COALESCE((u.raw_user_meta_data->>'is_verified')::BOOLEAN, FALSE) AS is_verified,
 	        (u.raw_user_meta_data->>'phone')::TEXT AS phone,
 	        u.email,
 	        (u.raw_user_meta_data->>'city')::TEXT AS location_city,
 	        (u.raw_user_meta_data->>'country')::TEXT AS location_country,
   	        (SELECT COUNT(*) FROM middleman_connections WHERE middleman_id = u.id AND status = 'active') AS total_connections,
   	        (SELECT COUNT(*) FROM deals WHERE middleman_id = u.id AND status = 'active') AS active_deals,
   	        COALESCE((SELECT SUM(total_amount) FROM deals WHERE middleman_id = u.id AND status = 'completed'), 0) AS total_revenue,
   	        COALESCE((SELECT AVG(rating) FROM reviews WHERE reviewed_id = u.id), 0) AS rating_avg,
   	        u.created_at AS joined_date
   	    FROM auth.users u
   	    WHERE u.id = target_user_id;
   	END;
   	$$;


ALTER FUNCTION "public"."get_middleman_profile"("target_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_or_create_conversation"("p_other_user_id" "uuid", "p_product_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_conversation_id uuid;
  v_current_user_id uuid := auth.uid();
BEGIN
  -- Try to find existing conversation
  SELECT c.id INTO v_conversation_id
  FROM public.conversations c
  JOIN public.conversation_participants cp1 ON cp1.conversation_id = c.id
  JOIN public.conversation_participants cp2 ON cp2.conversation_id = c.id
  WHERE cp1.user_id = v_current_user_id
    AND cp2.user_id = p_other_user_id
    AND (c.product_id IS NULL OR c.product_id = p_product_id)
  LIMIT 1;

  -- If found, return it
  IF v_conversation_id IS NOT NULL THEN
    RETURN v_conversation_id;
  END IF;

  -- Create new conversation
  INSERT INTO public.conversations (product_id)
  VALUES (p_product_id)
  RETURNING id INTO v_conversation_id;

  -- Add current user as participant
  INSERT INTO public.conversation_participants (conversation_id, user_id, role)
  VALUES (v_conversation_id, v_current_user_id, 'seller')
  ON CONFLICT (conversation_id, user_id) DO NOTHING;

  -- Add other user as participant
  INSERT INTO public.conversation_participants (conversation_id, user_id, role)
  VALUES (v_conversation_id, p_other_user_id, 'user')
  ON CONFLICT (conversation_id, user_id) DO NOTHING;

  RETURN v_conversation_id;
END;
$$;


ALTER FUNCTION "public"."get_or_create_conversation"("p_other_user_id" "uuid", "p_product_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_or_create_direct_conversation"("p_user1_id" "uuid", "p_user2_id" "uuid", "p_display_name" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
DECLARE
  v_conversation_id UUID;
  v_user1_role TEXT;
  v_user2_role TEXT;
  v_user1_account_type TEXT;
  v_user2_account_type TEXT;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() != p_user1_id THEN
    RAISE EXCEPTION 'Access denied: can only create conversations for yourself';
  END IF;

  IF p_user1_id = p_user2_id THEN
    RAISE EXCEPTION 'Cannot start conversation with yourself';
  END IF;

  SELECT account_type INTO v_user1_account_type FROM public.users WHERE user_id = p_user1_id;
  SELECT account_type INTO v_user2_account_type FROM public.users WHERE user_id = p_user2_id;

  v_user1_role := COALESCE(
    (CASE LOWER(v_user1_account_type)
      WHEN 'user' THEN 'customer'
      WHEN 'customer' THEN 'customer'
      WHEN 'patient' THEN 'customer'
      WHEN 'seller' THEN 'seller'
      WHEN 'factory' THEN 'factory'
      WHEN 'middleman' THEN 'middleman'
      WHEN 'broker' THEN 'middleman'
      WHEN 'delivery' THEN 'delivery'
      WHEN 'delivery_driver' THEN 'delivery'
      WHEN 'freelancer' THEN 'seller'
      WHEN 'service_provider' THEN 'seller'
      WHEN 'doctor' THEN 'seller'
      WHEN 'pharmacy' THEN 'seller'
      WHEN 'admin' THEN 'seller'
      ELSE 'customer'
    END),
    'customer'
  );

  v_user2_role := COALESCE(
    (CASE LOWER(v_user2_account_type)
      WHEN 'user' THEN 'customer'
      WHEN 'customer' THEN 'customer'
      WHEN 'patient' THEN 'customer'
      WHEN 'seller' THEN 'seller'
      WHEN 'factory' THEN 'factory'
      WHEN 'middleman' THEN 'middleman'
      WHEN 'broker' THEN 'middleman'
      WHEN 'delivery' THEN 'delivery'
      WHEN 'delivery_driver' THEN 'delivery'
      WHEN 'freelancer' THEN 'seller'
      WHEN 'service_provider' THEN 'seller'
      WHEN 'doctor' THEN 'seller'
      WHEN 'pharmacy' THEN 'seller'
      WHEN 'admin' THEN 'seller'
      ELSE 'customer'
    END),
    'customer'
  );

  IF NOT public.can_start_conversation(p_user1_id, p_user2_id, NULL) THEN
    RAISE EXCEPTION 'Conversation not allowed between these user types';
  END IF;

  SELECT c.id
    INTO v_conversation_id
  FROM public.conversations c
  JOIN public.conversation_participants cp1 ON c.id = cp1.conversation_id
  JOIN public.conversation_participants cp2 ON c.id = cp2.conversation_id
  WHERE c.type = 'direct'
    AND c.is_archived = false
    AND cp1.user_id = p_user1_id
    AND cp2.user_id = p_user2_id
  ORDER BY c.created_at ASC
  LIMIT 1;

  IF v_conversation_id IS NOT NULL THEN
    RETURN v_conversation_id;
  END IF;

  v_conversation_id := gen_random_uuid();

  INSERT INTO public.conversations (
    id, name, type, context, created_at, updated_at, is_archived
  )
  VALUES (
    v_conversation_id,
    COALESCE(p_display_name, 'Direct Chat'),
    'direct',
    'general',
    NOW(),
    NOW(),
    false
  );

  INSERT INTO public.conversation_participants (
    conversation_id, user_id, role, joined_at
  ) VALUES
    (v_conversation_id, p_user1_id, v_user1_role, NOW()),
    (v_conversation_id, p_user2_id, v_user2_role, NOW());

  RETURN v_conversation_id;
END;
$$;


ALTER FUNCTION "public"."get_or_create_direct_conversation"("p_user1_id" "uuid", "p_user2_id" "uuid", "p_display_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_or_create_direct_conversation_v2"("p_user1_id" "uuid", "p_user2_id" "uuid", "p_display_name" "text" DEFAULT NULL::"text", "p_context_type" "text" DEFAULT 'general'::"text", "p_context_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_id uuid;
  v_user1_role text := 'customer';
  v_user2_role text := 'customer';
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user1_id THEN
    RAISE EXCEPTION 'Access denied: can only create conversations for yourself';
  END IF;

  IF p_user1_id = p_user2_id THEN
    RAISE EXCEPTION 'Cannot start conversation with yourself';
  END IF;

  -- Reuse existing conversation if present
  SELECT c.id INTO v_id
  FROM public.conversations c
  JOIN public.conversation_participants a
    ON a.conversation_id = c.id AND a.user_id = p_user1_id
  JOIN public.conversation_participants b
    ON b.conversation_id = c.id AND b.user_id = p_user2_id
  WHERE c.type = 'direct'
    AND c.is_archived = false
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    RETURN v_id;
  END IF;

  v_id := gen_random_uuid();

  INSERT INTO public.conversations (
    id, name, type, context, product_id, is_archived, created_at, updated_at
  )
  VALUES (
    v_id,
    COALESCE(p_display_name, 'Direct Chat'),
    'direct',
    p_context_type,
    p_context_id,
    false,
    now(),
    now()
  );

  INSERT INTO public.conversation_participants (
    conversation_id, user_id, role, account_type, joined_at
  )
  VALUES
    (v_id, p_user1_id, v_user1_role, v_user1_role, now()),
    (v_id, p_user2_id, v_user2_role, v_user2_role, now());

  RETURN v_id;
END;
$$;


ALTER FUNCTION "public"."get_or_create_direct_conversation_v2"("p_user1_id" "uuid", "p_user2_id" "uuid", "p_display_name" "text", "p_context_type" "text", "p_context_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_or_create_health_conversation"("p_doctor_id" "uuid", "p_patient_id" "uuid", "p_appointment_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_conversation_id UUID;
    v_doctor_user_id UUID;
    v_patient_user_id UUID;
BEGIN
    -- Get user IDs from profiles
    SELECT user_id INTO v_doctor_user_id FROM public.health_doctor_profiles WHERE id = p_doctor_id;
    SELECT user_id INTO v_patient_user_id FROM public.health_patient_profiles WHERE id = p_patient_id;
    
    -- Security check
    IF auth.uid() IS NOT NULL AND auth.uid() != v_doctor_user_id AND auth.uid() != v_patient_user_id THEN
        RAISE EXCEPTION 'Access denied: Can only create conversations for yourself';
    END IF;
    
    -- Try to find existing conversation
    IF p_appointment_id IS NOT NULL THEN
        SELECT id INTO v_conversation_id
        FROM public.health_conversations
        WHERE appointment_id = p_appointment_id
        AND status = 'active'
        LIMIT 1;
    ELSE
        SELECT id INTO v_conversation_id
        FROM public.health_conversations
        WHERE doctor_id = p_doctor_id
        AND patient_id = p_patient_id
        AND status = 'active'
        ORDER BY created_at DESC
        LIMIT 1;
    END IF;
    
    -- Create new if not exists
    IF v_conversation_id IS NULL THEN
        INSERT INTO public.health_conversations (
            appointment_id,
            doctor_id,
            patient_id,
            conversation_type,
            status
        ) VALUES (
            p_appointment_id,
            p_doctor_id,
            p_patient_id,
            CASE WHEN p_appointment_id IS NOT NULL THEN 'appointment' ELSE 'consultation' END,
            'active'
        )
        RETURNING id INTO v_conversation_id;
    END IF;
    
    RETURN v_conversation_id;
END;
$$;


ALTER FUNCTION "public"."get_or_create_health_conversation"("p_doctor_id" "uuid", "p_patient_id" "uuid", "p_appointment_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_or_create_service_conversation"("p_provider_id" "uuid", "p_listing_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_conversation_id UUID;
  v_client_id UUID := auth.uid();
BEGIN
  -- Check existing
  SELECT id INTO v_conversation_id
  FROM public.services_conversations
  WHERE provider_id = p_provider_id
    AND client_id = v_client_id
    AND listing_id = p_listing_id;

  IF v_conversation_id IS NULL THEN
    -- Create new
    INSERT INTO public.services_conversations (provider_id, client_id, listing_id)
    VALUES (p_provider_id, v_client_id, p_listing_id)
    RETURNING id INTO v_conversation_id;
  END IF;

  RETURN v_conversation_id;
END;
$$;


ALTER FUNCTION "public"."get_or_create_service_conversation"("p_provider_id" "uuid", "p_listing_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_pharmacy_medicines"("p_search" "text" DEFAULT NULL::"text", "p_category_id" "uuid" DEFAULT NULL::"uuid", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("medicine_id" "uuid", "medicine_name" "text", "generic_name" "text", "category" "text", "manufacturer" "text", "price" numeric, "stock_quantity" integer, "requires_prescription" boolean, "availability_status" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    hm.id,
    hm.medicine_name,
    hm.generic_name,
    hmc.category_name,
    hm.manufacturer,
    hm.price,
    COALESCE(hm.stock_quantity, 0),
    hm.requires_prescription,
    CASE
      WHEN hm.stock_quantity > 10 THEN 'in_stock'::TEXT
      WHEN hm.stock_quantity > 0 THEN 'low_stock'::TEXT
      ELSE 'out_of_stock'::TEXT
    END
  FROM public.health_medicines hm
  LEFT JOIN public.health_medicine_categories hmc ON hm.category_id = hmc.id
  WHERE
    (p_search IS NULL OR hm.medicine_name ILIKE '%' || p_search || '%' OR hm.generic_name ILIKE '%' || p_search || '%')
    AND (p_category_id IS NULL OR hm.category_id = p_category_id)
    AND hm.is_active = TRUE
  ORDER BY hm.medicine_name ASC
  LIMIT p_limit OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."get_pharmacy_medicines"("p_search" "text", "p_category_id" "uuid", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_prescription_details"("p_prescription_id" "uuid", "p_requesting_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_prescription RECORD;
    v_medicines JSONB;
    v_doctor JSONB;
    v_patient JSONB;
    v_result JSONB;
    v_can_access BOOLEAN;
BEGIN
    -- Check access permission
    SELECT EXISTS (
        SELECT 1 FROM public.health_prescriptions_digital
        WHERE id = p_prescription_id
        AND (
            doctor_id IN (SELECT id FROM public.health_doctor_profiles WHERE user_id = p_requesting_user_id)
            OR patient_id IN (SELECT id FROM public.health_patient_profiles WHERE user_id = p_requesting_user_id)
        )
    ) INTO v_can_access;
    
    IF NOT v_can_access AND NOT EXISTS (SELECT 1 FROM public.admin_users WHERE user_id = p_requesting_user_id) THEN
        RAISE EXCEPTION 'Access denied: You do not have permission to view this prescription';
    END IF;
    
    -- Get prescription
    SELECT * INTO v_prescription
    FROM public.health_prescriptions_digital
    WHERE id = p_prescription_id;
    
    -- Get medicines
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', pm.id,
            'medicine_id', pm.medicine_id,
            'medicine_name', pm.medicine_name,
            'generic_name', pm.generic_name,
            'brand_name', pm.brand_name,
            'dosage_form', pm.dosage_form,
            'strength', pm.strength,
            'dosage_amount', pm.dosage_amount,
            'frequency', pm.frequency,
            'route_of_administration', pm.route_of_administration,
            'duration_days', pm.duration_days,
            'total_quantity', pm.total_quantity,
            'instructions', pm.instructions,
            'warnings', pm.warnings,
            'allow_generic_substitution', pm.allow_generic_substitution,
            'is_dispensed', pm.is_dispensed,
            'unit_price', pm.unit_price,
            'total_price', pm.total_price
        )
    ), '[]'::jsonb) INTO v_medicines
    FROM public.health_prescription_medicines_digital pm
    WHERE pm.prescription_id = p_prescription_id;
    
    -- Get doctor info
    SELECT jsonb_build_object(
        'id', dp.id,
        'name', u.full_name,
        'specialization', dp.specialization,
        'license_number', dp.license_number,
        'clinic_name', dp.clinic_name
    ) INTO v_doctor
    FROM public.health_doctor_profiles dp
    JOIN public.users u ON u.user_id = dp.user_id
    WHERE dp.id = v_prescription.doctor_id;
    
    -- Get patient info (limited for privacy)
    SELECT jsonb_build_object(
        'id', pp.id,
        'name', u.full_name,
        'date_of_birth', pp.date_of_birth,
        'blood_type', pp.blood_type
    ) INTO v_patient
    FROM public.health_patient_profiles pp
    JOIN public.users u ON u.user_id = pp.user_id
    WHERE pp.id = v_prescription.patient_id;
    
    -- Build result
    v_result := jsonb_build_object(
        'prescription', jsonb_build_object(
            'id', v_prescription.id,
            'prescription_number', v_prescription.prescription_number,
            'prescription_date', v_prescription.prescription_date,
            'valid_until', v_prescription.valid_until,
            'status', v_prescription.status,
            'diagnosis', v_prescription.diagnosis,
            'symptoms', v_prescription.symptoms,
            'notes', v_prescription.notes,
            'follow_up_date', v_prescription.follow_up_date,
            'times_filled', v_prescription.times_filled,
            'max_refills', v_prescription.max_refills,
            'refills_remaining', v_prescription.refills_remaining,
            'created_at', v_prescription.created_at
        ),
        'doctor', v_doctor,
        'patient', v_patient,
        'medicines', v_medicines,
        'total_medicines', jsonb_array_length(v_medicines),
        'total_price', (SELECT COALESCE(SUM(total_price), 0) FROM jsonb_array_elements(v_medicines) AS m)
    );
    
    -- Log access
    INSERT INTO public.health_prescription_audit_log (
        prescription_id,
        action_type,
        action_by,
        action_by_role,
        action_details
    ) VALUES (
        p_prescription_id,
        'viewed',
        p_requesting_user_id,
        CASE 
            WHEN EXISTS (SELECT 1 FROM public.health_doctor_profiles WHERE user_id = p_requesting_user_id) THEN 'doctor'
            WHEN EXISTS (SELECT 1 FROM public.health_patient_profiles WHERE user_id = p_requesting_user_id) THEN 'patient'
            ELSE 'system'
        END,
        jsonb_build_object('accessed_at', NOW())
    );
    
    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_prescription_details"("p_prescription_id" "uuid", "p_requesting_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_product_image_url"("image_path" "text") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN storage.storage_url('product-images', image_path);
END;
$$;


ALTER FUNCTION "public"."get_product_image_url"("image_path" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_products_for_middleman"("target_middleman_id" "uuid") RETURNS TABLE("product_id" "uuid", "name" "text", "description" "text", "price" numeric, "currency" "text", "image_url" "text", "stock_quantity" integer, "seller_id" "uuid", "seller_name" "text", "distance_km" double precision, "match_reason" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
   	DECLARE
   	    mid_lat FLOAT;
   	    mid_lng FLOAT;
   	    mid_radius FLOAT := 50.0; -- Default 50km radius
   	    is_verified BOOLEAN;
   	BEGIN
   	    -- Get Middleman Location and Status
   	    SELECT 
	        (raw_user_meta_data->>'latitude')::FLOAT,
   	        (raw_user_meta_data->>'longitude')::FLOAT,
   	        COALESCE((raw_user_meta_data->>'is_verified')::BOOLEAN, FALSE)
 	    INTO mid_lat, mid_lng, is_verified
 	    FROM auth.users WHERE id = target_middleman_id;
	
   	    RETURN QUERY
   	    SELECT 
   	        p.id AS product_id,
  	        p.name,
  	        p.description,
  	        p.price,
	        p.currency,
   	        p.image_url,
   	        p.stock_quantity,
   	        p.seller_id,
   	        (SELECT raw_user_meta_data->>'company_name' FROM auth.users WHERE id = p.seller_id) AS seller_name,
   	        CASE 
   	            WHEN mid_lat IS NOT NULL AND p.latitude IS NOT NULL THEN
   	                ROUND(
   	                    6371 * acos(
   	                        cos(radians(mid_lat)) * cos(radians(p.latitude)) *
   	                        cos(radians(p.longitude) - radians(mid_lng)) +
   	                        sin(radians(mid_lat)) * sin(radians(p.latitude))
   	                    )::numeric, 2
   	                )
   	            ELSE NULL
   	        END AS distance_km,
   	        CASE 
   	            WHEN EXISTS (SELECT 1 FROM middleman_connections WHERE middleman_id = target_middleman_id AND provider_id = p.seller_id AND status = 'active')
   	                THEN 'Connected Seller'
   	            WHEN is_verified THEN 'Verified Access'
   	            WHEN mid_lat IS NOT NULL AND p.latitude IS NOT NULL THEN 'Local Proximity'
   	            ELSE 'Public Listing'
   	        END AS match_reason
   	    FROM products p
   	    WHERE p.status = 'active'
   	      AND (
   	          -- 1. Connected Sellers
   	          EXISTS (SELECT 1 FROM middleman_connections WHERE middleman_id = target_middleman_id AND provider_id = p.seller_id AND status = 'active')
   	          OR
   	          -- 2. Verified Middlemen see all active products
   	          is_verified = TRUE
   	          OR
   	          -- 3. Within Radius (if location exists)
   	          (mid_lat IS NOT NULL AND p.latitude IS NOT NULL AND 
   	           (6371 * acos(
   	                cos(radians(mid_lat)) * cos(radians(p.latitude)) *
   	                cos(radians(p.longitude) - radians(mid_lng)) +
   	                sin(radians(mid_lat)) * sin(radians(p.latitude))
   	           )) <= mid_radius)
   	      );
   	END;
   	$$;


ALTER FUNCTION "public"."get_products_for_middleman"("target_middleman_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_provider_revenue"() RETURNS TABLE("provider_id" "uuid", "total_revenue" numeric)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Replace this with your actual logic to calculate provider revenue
    RETURN QUERY
    SELECT
        p.id AS provider_id,
        SUM(o.amount) AS total_revenue
    FROM
        providers p
    JOIN
        orders o ON p.id = o.provider_id
    GROUP BY
        p.id;
END;
$$;


ALTER FUNCTION "public"."get_provider_revenue"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_provider_revenue"("p_provider_id" "uuid") RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_revenue NUMERIC;
BEGIN
  SELECT COALESCE(SUM(total_price), 0)
  INTO v_revenue
  FROM public.service_bookings
  WHERE provider_id = p_provider_id
    AND status = 'completed'; -- Only count completed bookings as revenue
  
  RETURN v_revenue;
END;
$$;


ALTER FUNCTION "public"."get_provider_revenue"("p_provider_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_provider_user_id"("p_provider_id" "uuid") RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT user_id FROM public.svc_providers WHERE id = p_provider_id;
$$;


ALTER FUNCTION "public"."get_provider_user_id"("p_provider_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_public_profile"("p_user_id" "uuid") RETURNS TABLE("user_id" "uuid", "email" "text", "full_name" "text", "phone" "text", "avatar_url" "text", "account_type" "text", "location" "text", "currency" "text", "is_verified" boolean, "created_at" timestamp with time zone, "product_count" bigint, "total_sales" bigint, "total_revenue" numeric, "average_rating" numeric, "review_count" bigint, "store_name" "text", "is_factory" boolean, "is_middle_man" boolean, "is_seller" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.user_id,
    u.email,
    u.full_name,
    CASE 
      WHEN auth.uid() = p_user_id THEN u.phone
      ELSE NULL 
    END AS phone,
    u.avatar_url,
    u.account_type,
    COALESCE(s.location, NULL) AS location,
    COALESCE(s.currency, 'USD') AS currency,
    COALESCE(s.is_verified, false) AS is_verified,
    u.created_at,
    COALESCE(pc.product_count, 0)::BIGINT AS product_count,
    COALESCE(sc.sales_count, 0)::BIGINT AS total_sales,
    COALESCE(sr.total_revenue, 0)::NUMERIC AS total_revenue,
    COALESCE(r.avg_rating, 0)::NUMERIC AS average_rating,
    COALESCE(r.review_count, 0)::BIGINT AS review_count,
    COALESCE(sp.store_name, NULL) AS store_name,
    (u.account_type = 'factory') AS is_factory,
    (u.account_type = 'middle_man') AS is_middle_man,
    (u.account_type = 'seller') AS is_seller
  FROM public.users u
  LEFT JOIN public.sellers s ON s.user_id = u.user_id
  LEFT JOIN public.seller_profiles sp ON sp.id = u.user_id
  LEFT JOIN (
    SELECT seller_id, COUNT(*) AS product_count
    FROM public.products
    WHERE is_deleted = false
    GROUP BY seller_id
  ) pc ON pc.seller_id = u.user_id
  LEFT JOIN (
    SELECT seller_id, COUNT(*) AS sales_count
    FROM public.sales
    GROUP BY seller_id
  ) sc ON sc.seller_id = u.user_id
  LEFT JOIN (
    SELECT seller_id, SUM(total_price) AS total_revenue
    FROM public.sales
    GROUP BY seller_id
  ) sr ON sr.seller_id = u.user_id
  LEFT JOIN (
    SELECT 
      p.seller_id,
      AVG(r2.rating) AS avg_rating,
      COUNT(r2.id) AS review_count
    FROM public.products p
    LEFT JOIN public.reviews r2 ON r2.asin = p.asin
    WHERE r2.is_approved = true
    GROUP BY p.seller_id
  ) r ON r.seller_id = u.user_id
  WHERE u.user_id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."get_public_profile"("p_user_id" "uuid") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."get_setting"("key_name" "text", "default_value" "jsonb" DEFAULT NULL::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
  val jsonb;
BEGIN
  SELECT value INTO val FROM public.platform_settings WHERE key = key_name;
  RETURN COALESCE(val, default_value);
END;
$$;


ALTER FUNCTION "public"."get_setting"("key_name" "text", "default_value" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_setting_float"("key_name" "text", "default_val" double precision DEFAULT 0) RETURNS double precision
    LANGUAGE "sql" STABLE
    AS $$
  SELECT COALESCE((public.get_setting(key_name) #>> '{}')::float, default_val);
$$;


ALTER FUNCTION "public"."get_setting_float"("key_name" "text", "default_val" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_typing_indicators"("p_conversation_id" "uuid") RETURNS TABLE("user_id" "uuid", "user_name" "text", "is_typing" boolean, "last_activity" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        ti.user_id,
        u.full_name,
        ti.is_typing,
        ti.last_activity
    FROM public.health_typing_indicators ti
    JOIN public.users u ON u.user_id = ti.user_id
    WHERE ti.conversation_id = p_conversation_id
    AND ti.user_id != auth.uid()
    AND ti.last_activity > NOW() - INTERVAL '1 minute';
END;
$$;


ALTER FUNCTION "public"."get_typing_indicators"("p_conversation_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_unified_orders"("p_user_id" "uuid", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS TABLE("order_id" "uuid", "order_type" "text", "provider_id" "uuid", "customer_id" "uuid", "status" "text", "total_amount" numeric, "currency" "text", "created_at" timestamp with time zone, "metadata" "jsonb")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT id, 'ecommerce', seller_id, user_id, status, total, currency, created_at, metadata FROM public.orders WHERE user_id = p_user_id
  UNION ALL
  SELECT id, 'service', provider_id, user_id, status, agreed_price, currency, created_at, metadata FROM public.svc_orders WHERE user_id = p_user_id
  UNION ALL
  SELECT id, 'health_medicine', pharmacy_id, patient_id, status, total, 'EGP', created_at, NULL::JSONB FROM public.health_medicine_orders WHERE patient_id = p_user_id
  ORDER BY created_at DESC LIMIT p_limit OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."get_unified_orders"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_unread_notification_count"("p_user_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM notifications
    WHERE user_id = p_user_id AND is_read = false
  );
END;
$$;


ALTER FUNCTION "public"."get_unread_notification_count"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_unread_push_count"("p_user_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM public.notifications
        WHERE user_id = p_user_id
        AND is_read = false
        AND created_at > NOW() - INTERVAL '30 days'
    );
END;
$$;


ALTER FUNCTION "public"."get_unread_push_count"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_conversations"("p_user_id" "uuid") RETURNS TABLE("conversation_id" "uuid", "product_id" "uuid", "last_message" "text", "last_message_at" timestamp with time zone, "created_at" timestamp with time zone, "is_archived" boolean, "other_user_id" "uuid", "other_user_name" "text", "other_user_avatar" "text", "other_user_account_type" "text", "unread_count" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id AS conversation_id,
    c.product_id,
    c.last_message,
    c.last_message_at,
    c.created_at,
    c.is_archived,
    cp.user_id AS other_user_id,
    u.full_name AS other_user_name,
    u.avatar_url AS other_user_avatar,
    u.account_type AS other_user_account_type,
    (
      SELECT COUNT(*)
      FROM messages m
      WHERE m.conversation_id = c.id
        AND m.sender_id != p_user_id
        AND m.read_at IS NULL
    ) AS unread_count
  FROM conversations c
  JOIN conversation_participants cp ON cp.conversation_id = c.id
  JOIN users u ON u.user_id = cp.user_id
  WHERE c.id IN (
    SELECT conversation_id 
    FROM conversation_participants 
    WHERE user_id = p_user_id
  )
  AND cp.user_id != p_user_id
  ORDER BY c.last_message_at DESC NULLS LAST;
END;
$$;


ALTER FUNCTION "public"."get_user_conversations"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_conversations_with_products"("p_user_id" "uuid") RETURNS TABLE("conversation_id" "uuid", "product_id" "uuid", "product_title" "text", "product_price" numeric, "product_image" "text", "last_message" "text", "last_message_at" timestamp with time zone, "created_at" timestamp with time zone, "other_user_id" "uuid", "other_user_name" "text", "other_user_avatar" "text", "unread_count" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id AS conversation_id,
    c.product_id,
    p.title AS product_title,
    p.price AS product_price,
    p.images->>0 AS product_image,
    c.last_message,
    c.last_message_at,
    c.created_at,
    cp.user_id AS other_user_id,
    u.full_name AS other_user_name,
    u.avatar_url AS other_user_avatar,
    (
      SELECT COUNT(*)
      FROM messages m
      WHERE m.conversation_id = c.id
        AND m.sender_id != p_user_id
        AND m.read_at IS NULL
    ) AS unread_count
  FROM conversations c
  JOIN conversation_participants cp ON cp.conversation_id = c.id
  JOIN users u ON u.user_id = cp.user_id
  LEFT JOIN products p ON p.id = c.product_id
  WHERE c.id IN (
    SELECT conversation_id 
    FROM conversation_participants 
    WHERE user_id = p_user_id
  )
  AND cp.user_id != p_user_id
  ORDER BY c.last_message_at DESC NULLS LAST;
END;
$$;


ALTER FUNCTION "public"."get_user_conversations_with_products"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_verified_doctors"("p_specialty" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("doctor_id" "uuid", "user_id" "uuid", "full_name" "text", "specialty" "text", "rating" numeric, "experience_years" integer, "is_verified" boolean, "verified_at" timestamp with time zone, "consultation_fee" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    hdp.id,
    hdp.user_id,
    hdp.full_name,
    hdp.specialty,
    COALESCE(hdp.rating, 0)::NUMERIC,
    hdp.experience_years,
    hdp.is_verified,
    hdp.verified_at,
    hdp.consultation_fee
  FROM public.health_doctor_profiles hdp
  WHERE
    hdp.is_verified = TRUE
    AND (p_specialty IS NULL OR hdp.specialty ILIKE '%' || p_specialty || '%')
  ORDER BY hdp.rating DESC, hdp.full_name ASC
  LIMIT p_limit OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."get_verified_doctors"("p_specialty" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."websites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "seller_id" "uuid" NOT NULL,
    "subdomain" "text",
    "custom_domain" "text",
    "domain_verified" boolean DEFAULT false,
    "verification_token" "text",
    "connection_type" "text",
    "external_url" "text",
    "api_key" "text" DEFAULT ("gen_random_uuid"())::"text",
    "webhook_secret" "text",
    "theme_config" "jsonb" DEFAULT '{}'::"jsonb",
    "custom_css" "text",
    "logo_url" "text",
    "favicon_url" "text",
    "is_active" boolean DEFAULT false,
    "is_published" boolean DEFAULT false,
    "seo_metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "websites_connection_type_check" CHECK (("connection_type" = ANY (ARRAY['subdomain'::"text", 'path'::"text", 'external'::"text"])))
);


ALTER TABLE "public"."websites" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_website_by_domain"("p_domain" "text") RETURNS "public"."websites"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_website public.websites;
BEGIN
  SELECT * INTO v_website
  FROM public.websites
  WHERE 
    (subdomain = p_domain OR custom_domain = p_domain)
    AND is_active = true 
    AND is_published = true
  LIMIT 1;
  RETURN v_website;
END;
$$;


ALTER FUNCTION "public"."get_website_by_domain"("p_domain" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Insert into users table ONLY
  INSERT INTO public.users (
    user_id,
    email,
    full_name,
    phone,
    account_type,
    preferred_language,
    theme_preference
  ) VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'account_type', 'user'),
    COALESCE(NEW.raw_user_meta_data->>'preferred_language', 'en'),
    COALESCE(NEW.raw_user_meta_data->>'theme_preference', 'system')
  );

  -- NOTE: Business profiles and middleman profiles are created manually
  -- during signup process, NOT automatically by this trigger

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_oauth_signup"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Log new OAuth signup (you can customize this for your analytics)
    IF EXISTS (
        SELECT 1 FROM auth.identities i
        WHERE i.user_id = NEW.id
        AND i.provider IN ('google', 'facebook', 'github', 'microsoft')
    ) THEN
        -- Insert into analytics table if you have one
        -- INSERT INTO public.signup_analytics (user_id, provider, signed_at)
        -- VALUES (NEW.id, provider, NOW());
        
        RAISE NOTICE 'OAuth signup detected for user: %', NEW.email;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_oauth_signup"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."handle_oauth_signup"() IS 'Trigger function to log OAuth signups';



CREATE OR REPLACE FUNCTION "public"."handle_service_booking_notifications"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_provider_id UUID;
  v_customer_id UUID;
  v_listing_title TEXT;
  v_notification_message TEXT;
BEGIN
  -- A. Fetch Related Data
  -- Get Provider ID from the service listing
  SELECT provider_id INTO v_provider_id 
  FROM public.service_listings 
  WHERE id = NEW.listing_id;
  
  -- Get Customer ID (assuming NEW.customer_id is the auth user ID)
  v_customer_id := NEW.customer_id;
  
  -- Get Listing Title for context
  SELECT title INTO v_listing_title 
  FROM public.service_listings 
  WHERE id = NEW.listing_id;

  -- B. Handle INSERT (New Booking Request)
  IF TG_OP = 'INSERT' THEN
    -- Notify the Provider about the new request
    INSERT INTO public.notifications (user_id, type, title, message, metadata)
    VALUES (
      v_provider_id,
      'booking_request',
      '🔔 New Service Booking Request',
      'You have a new booking request for "' || COALESCE(v_listing_title, 'Service') || '".',
      jsonb_build_object(
        'booking_id', NEW.id, 
        'listing_id', NEW.listing_id, 
        'customer_id', NEW.customer_id,
        'action_url', '/services/dashboard/bookings'
      )
    );
    
    RETURN NEW;
  END IF;

  -- C. Handle UPDATE (Status Changes)
  IF TG_OP = 'UPDATE' THEN
    
    -- Scenario 1: Status changed to 'confirmed' -> Notify Customer
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'confirmed' THEN
      INSERT INTO public.notifications (user_id, type, title, message, metadata)
      VALUES (
        v_customer_id,
        'booking_confirmed',
        '✅ Booking Confirmed!',
        'Your booking for "' || COALESCE(v_listing_title, 'Service') || '" has been confirmed by the provider.',
        jsonb_build_object(
          'booking_id', NEW.id, 
          'listing_id', NEW.listing_id,
          'action_url', '/services/dashboard/bookings'
        )
      );
    END IF;

    -- Scenario 2: Status changed to 'cancelled' -> Notify Both
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'cancelled' THEN
      -- Notify Customer
      INSERT INTO public.notifications (user_id, type, title, message, metadata)
      VALUES (
        v_customer_id,
        'booking_cancelled',
        '❌ Booking Cancelled',
        'Your booking for "' || COALESCE(v_listing_title, 'Service') || '" has been cancelled.',
        jsonb_build_object('booking_id', NEW.id)
      );
      
      -- Notify Provider
      INSERT INTO public.notifications (user_id, type, title, message, metadata)
      VALUES (
        v_provider_id,
        'booking_cancelled',
        '⚠️ Booking Cancelled by Customer',
        'A booking for "' || COALESCE(v_listing_title, 'Service') || '" was cancelled.',
        jsonb_build_object('booking_id', NEW.id)
      );
    END IF;

    -- Scenario 3: Status changed to 'completed' -> Prompt for Review (Optional Future Logic)
    -- You can add logic here to notify the customer to leave a review after completion.
    
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_service_booking_notifications"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."has_google_account_linked"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    current_user_id UUID;
    has_google BOOLEAN;
BEGIN
    current_user_id := auth.uid();
    
    SELECT EXISTS (
        SELECT 1 FROM auth.identities i
        WHERE i.user_id = current_user_id
        AND i.provider = 'google'
    ) INTO has_google;
    
    RETURN has_google;
END;
$$;


ALTER FUNCTION "public"."has_google_account_linked"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."has_google_account_linked"() IS 'Check if current user has Google account linked';



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


CREATE OR REPLACE FUNCTION "public"."increment_template_sales"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE public.website_marketplace
  SET total_sales = total_sales + 1,
      updated_at = NOW()
  WHERE id = NEW.template_id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."increment_template_sales"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."initialize_user_notification_settings"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Create default notification settings when new user is created
  INSERT INTO public.notification_settings (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."initialize_user_notification_settings"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"("p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.admins
    WHERE user_id = p_user_id AND is_active = TRUE
  );
END;
$$;


ALTER FUNCTION "public"."is_admin"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin_user"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true);
$$;


ALTER FUNCTION "public"."is_admin_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_activity"("p_action_type" "text", "p_action_category" "text", "p_description" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_log_id uuid;
BEGIN
  INSERT INTO public.activity_logs (
    user_id,
    action_type,
    action_category,
    description,
    metadata,
    device_info
  ) VALUES (
    auth.uid(),
    p_action_type,
    p_action_category,
    p_description,
    p_metadata,
    current_setting('app.device_info', true)
  ) RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$;


ALTER FUNCTION "public"."log_activity"("p_action_type" "text", "p_action_category" "text", "p_description" "text", "p_metadata" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_error"("p_error_type" "text", "p_error_message" "text", "p_stack_trace" "text" DEFAULT NULL::"text", "p_screen_name" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_log_id uuid;
BEGIN
  INSERT INTO public.error_logs (
    user_id,
    error_type,
    error_message,
    stack_trace,
    screen_name,
    metadata
  ) VALUES (
    auth.uid(),
    p_error_type,
    p_error_message,
    p_stack_trace,
    p_screen_name,
    p_metadata
  ) RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$;


ALTER FUNCTION "public"."log_error"("p_error_type" "text", "p_error_message" "text", "p_stack_trace" "text", "p_screen_name" "text", "p_metadata" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_payment_activity"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.activity_logs (
    user_id, action_type, action_category,
    description, metadata
  ) VALUES (
    COALESCE(NEW.user_id, auth.uid()),
    TG_OP,
    'payment',
    TG_TABLE_NAME || ' ' || TG_OP || ' by ' || COALESCE(NEW.user_id::text, auth.uid()::text),
    jsonb_build_object(
      'table', TG_TABLE_NAME,
      'record_id', NEW.id,
      'old_data', TO_JSONB(OLD),
      'new_data', TO_JSONB(NEW)
    )
  );
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."log_payment_activity"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_payment_status_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO audit_logs (event, severity, description, metadata, user_id)
    VALUES (
      'PAYMENT_STATUS_CHANGE',
      CASE 
        WHEN NEW.status = 'failed' THEN 'high'
        WHEN NEW.status = 'succeeded' THEN 'low'
        ELSE 'medium'
      END,
      'Payment status changed from ' || COALESCE(OLD.status, 'NULL') || ' to ' || NEW.status,
      jsonb_build_object(
        'old_status', OLD.status,
        'new_status', NEW.status,
        'amount', NEW.amount,
        'order_id', NEW.order_id
      ),
      NEW.user_id
    );
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."log_payment_status_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_prescription_access"("p_prescription_id" "uuid", "p_access_type" "text" DEFAULT 'view'::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO public.health_prescription_access_log (
        prescription_id,
        user_id,
        access_type,
        ip_address,
        device_info
    ) VALUES (
        p_prescription_id,
        auth.uid(),
        p_access_type,
        current_setting('app.client_ip', true),
        current_setting('app.device_info', true)
    );
END;
$$;


ALTER FUNCTION "public"."log_prescription_access"("p_prescription_id" "uuid", "p_access_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_wallet_transaction"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF OLD.balance IS DISTINCT FROM NEW.balance THEN
    INSERT INTO wallet_transactions (user_id, amount, balance_after, transaction_type, description)
    VALUES (
      NEW.user_id,
      NEW.balance - OLD.balance,
      NEW.balance,
      CASE 
        WHEN NEW.balance > OLD.balance THEN 'credit'
        ELSE 'debit'
      END,
      'Balance change: ' || (NEW.balance - OLD.balance)
    );
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."log_wallet_transaction"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_health_messages_read"("p_conversation_id" "uuid", "p_message_ids" "uuid"[] DEFAULT NULL::"uuid"[]) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_count INTEGER;
    v_conversation RECORD;
    v_user_role TEXT;
BEGIN
    -- Get conversation details
    SELECT * INTO v_conversation
    FROM public.health_conversations
    WHERE id = p_conversation_id;
    
    IF v_conversation IS NULL THEN
        RAISE EXCEPTION 'Conversation not found';
    END IF;
    
    -- Determine user role
    IF auth.uid() = (SELECT user_id FROM public.health_doctor_profiles WHERE id = v_conversation.doctor_id) THEN
        v_user_role := 'doctor';
    ELSIF auth.uid() = (SELECT user_id FROM public.health_patient_profiles WHERE id = v_conversation.patient_id) THEN
        v_user_role := 'patient';
    ELSE
        RAISE EXCEPTION 'Access denied';
    END IF;
    
    -- Mark messages as read
    IF p_message_ids IS NOT NULL THEN
        UPDATE public.health_messages
        SET is_read = true, read_at = NOW()
        WHERE id = ANY(p_message_ids)
        AND conversation_id = p_conversation_id
        AND sender_id != auth.uid();
        
        GET DIAGNOSTICS v_count = ROW_COUNT;
    ELSE
        -- Mark all unread messages as read
        UPDATE public.health_messages
        SET is_read = true, read_at = NOW()
        WHERE conversation_id = p_conversation_id
        AND sender_id != auth.uid()
        AND is_read = false;
        
        GET DIAGNOSTICS v_count = ROW_COUNT;
    END IF;
    
    -- Update conversation read status
    IF v_user_role = 'doctor' THEN
        UPDATE public.health_conversations
        SET is_read_by_doctor = true, updated_at = NOW()
        WHERE id = p_conversation_id;
    ELSE
        UPDATE public.health_conversations
        SET is_read_by_patient = true, updated_at = NOW()
        WHERE id = p_conversation_id;
    END IF;
    
    -- Create read receipts
    INSERT INTO public.health_message_receipts (message_id, user_id, read_at)
    SELECT id, auth.uid(), NOW()
    FROM public.health_messages
    WHERE conversation_id = p_conversation_id
    AND sender_id != auth.uid()
    AND is_read = true
    ON CONFLICT (message_id, user_id) DO NOTHING;
    
    RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."mark_health_messages_read"("p_conversation_id" "uuid", "p_message_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE notifications
  SET is_read = true, read_at = NOW(), updated_at = NOW()
  WHERE id = p_notification_id;
END;
$$;


ALTER FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_notifications_read"("p_user_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE notifications
  SET is_read = true, read_at = NOW(), updated_at = NOW()
  WHERE user_id = p_user_id AND is_read = false;
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."mark_notifications_read"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_push_notification_opened"("p_notification_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Update notification log
    UPDATE public.push_notification_logs
    SET
        status = 'opened',
        opened_at = NOW()
    WHERE notification_id = p_notification_id;
    
    -- Update in-app notification
    UPDATE public.notifications
    SET is_read = true, read_at = NOW()
    WHERE id = p_notification_id;
    
    -- Update campaign if applicable
    UPDATE public.push_campaigns
    SET opened_count = opened_count + 1
    WHERE id IN (
        SELECT target_audience->>'campaign_id'
        FROM public.push_notification_logs
        WHERE notification_id = p_notification_id
    );
END;
$$;


ALTER FUNCTION "public"."mark_push_notification_opened"("p_notification_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."messages_tsvector_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.content_tsvector := to_tsvector('english', COALESCE(NEW.content, ''));
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."messages_tsvector_trigger"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."middleman_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_company_name" "text", "p_location" "text", "p_currency" "text" DEFAULT 'EGP'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authenticate first');
  END IF;

  -- Update users
  UPDATE public.users SET account_type = 'middleman' WHERE user_id = v_user_id;

  -- Ensure middle_men record
  INSERT INTO public.middle_men (user_id, commission_rate, total_earnings, pending_earnings)
  VALUES (v_user_id, 5.00, 0, 0)
  ON CONFLICT (user_id) DO NOTHING;

  -- Ensure middleman_profiles record
  INSERT INTO public.middleman_profiles (user_id, company_name, location, currency)
  VALUES (v_user_id, p_company_name, p_location, p_currency)
  ON CONFLICT (user_id) DO UPDATE SET
    company_name = EXCLUDED.company_name,
    location = EXCLUDED.location,
    currency = EXCLUDED.currency;

  RETURN jsonb_build_object('success', true, 'user_id', v_user_id);
END;
$$;


ALTER FUNCTION "public"."middleman_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_company_name" "text", "p_location" "text", "p_currency" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_account_type_change"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- If account_type is being changed, revert to original value
  IF NEW.account_type IS DISTINCT FROM OLD.account_type THEN
    NEW.account_type := OLD.account_type;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."prevent_account_type_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_fawry_payment"("p_order_id" "uuid", "p_fawry_reference" "text", "p_amount" numeric, "p_gateway_response" "jsonb", "p_idempotency_key" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_transaction_id UUID;
  v_order RECORD;
  v_user_id UUID;
BEGIN
  -- Check idempotency (PREVENT DOUBLE PROCESSING)
  SELECT id INTO v_transaction_id
  FROM public.payment_transactions
  WHERE idempotency_key = p_idempotency_key;
  
  IF v_transaction_id IS NOT NULL THEN
    RETURN v_transaction_id;
  END IF;
  
  -- Get order details
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  
  IF v_order IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;
  
  v_user_id := v_order.user_id;
  
  -- Create payment transaction
  INSERT INTO public.payment_transactions (
    order_id, user_id, payment_gateway, gateway_transaction_id,
    amount, currency, status, payment_method,
    gateway_response, idempotency_key, processed_at
  ) VALUES (
    p_order_id, v_user_id, 'fawry', p_fawry_reference,
    p_amount, 'EGP', 'success', 'card',
    p_gateway_response, p_idempotency_key, NOW()
  )
  RETURNING id INTO v_transaction_id;
  
  -- Update order payment status
  UPDATE public.orders
  SET 
    payment_status = 'completed',
    payment_intent_id = p_fawry_reference,
    updated_at = NOW()
  WHERE id = p_order_id;
  
  -- Split payment to parties
  PERFORM public.split_payment_to_parties(p_order_id, v_transaction_id, p_amount);
  
  RETURN v_transaction_id;
END;
$$;


ALTER FUNCTION "public"."process_fawry_payment"("p_order_id" "uuid", "p_fawry_reference" "text", "p_amount" numeric, "p_gateway_response" "jsonb", "p_idempotency_key" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_medicine_order_payment"("p_order_id" "uuid", "p_payment_amount" numeric, "p_prescription_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_pharmacy_share DECIMAL;
    v_platform_share DECIMAL;
    v_doctor_share DECIMAL := 0;
    v_delivery_share DECIMAL;
    v_order RECORD;
    v_deal RECORD;
BEGIN
    -- Get order details
    SELECT * INTO v_order FROM health_medicine_orders WHERE id = p_order_id;
    
    -- Calculate base splits
    v_platform_share := p_payment_amount * 0.05;  -- 5% platform fee
    v_delivery_share := COALESCE(v_order.delivery_fee, 0);
    v_pharmacy_share := p_payment_amount - v_platform_share - v_delivery_share;
    
    -- Check if prescription has doctor deal
    IF p_prescription_id IS NOT NULL THEN
        SELECT d.commission_rate, d.fixed_commission
        INTO v_deal
        FROM prescription_fulfillment pf
        JOIN health_prescription_medicines pm ON pm.id = pf.prescription_medicine_id
        JOIN health_prescriptions pr ON pr.id = pm.prescription_id
        JOIN doctor_medicine_deals d ON d.medicine_id = pm.medicine_id
        WHERE pr.id = p_prescription_id
        AND d.is_active = true
        LIMIT 1;
        
        IF v_deal IS NOT NULL THEN
            IF v_deal.fixed_commission > 0 THEN
                v_doctor_share := v_deal.fixed_commission;
            ELSE
                v_doctor_share := p_payment_amount * (v_deal.commission_rate / 100);
            END IF;
            
            -- Deduct from pharmacy share
            v_pharmacy_share := v_pharmacy_share - v_doctor_share;
            
            -- Record doctor commission
            INSERT INTO commissions (
                middle_man_id,  -- Using doctor_id here
                order_id,
                amount,
                commission_rate,
                status
            ) VALUES (
                (SELECT doctor_id FROM health_prescriptions WHERE id = p_prescription_id),
                p_order_id,
                v_doctor_share,
                COALESCE(v_deal.commission_rate, 0),
                'pending'
            );
        END IF;
    END IF;
    
    -- Create payment splits
    INSERT INTO payment_splits (order_id, payment_transaction_id, recipient_id, recipient_type, amount, split_type, status)
    VALUES 
        (p_order_id, NULL, v_order.pharmacy_id, 'pharmacy', v_pharmacy_share, 'revenue', 'pending'),
        (p_order_id, NULL, v_order.pharmacy_id, 'platform', v_platform_share, 'fee', 'paid'),
        (p_order_id, NULL, v_order.pharmacy_id, 'delivery', v_delivery_share, 'delivery_fee', 'pending');
    
    -- Add doctor split if applicable
    IF v_doctor_share > 0 THEN
        INSERT INTO payment_splits (order_id, payment_transaction_id, recipient_id, recipient_type, amount, split_type, status)
        VALUES (
            p_order_id, 
            NULL, 
            (SELECT doctor_id FROM health_prescriptions WHERE id = p_prescription_id), 
            'doctor', 
            v_doctor_share, 
            'commission', 
            'pending'
        );
    END IF;
    
    RETURN jsonb_build_object(
        'pharmacy_share', v_pharmacy_share,
        'platform_share', v_platform_share,
        'doctor_share', v_doctor_share,
        'delivery_share', v_delivery_share,
        'total', p_payment_amount
    );
END;
$$;


ALTER FUNCTION "public"."process_medicine_order_payment"("p_order_id" "uuid", "p_payment_amount" numeric, "p_prescription_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_qr_scan"("p_pharmacy_id" "uuid", "p_user_id" "uuid", "p_qr_code" "text", "p_scan_type" "text", "p_device_info" "text" DEFAULT NULL::"text", "p_location_lat" double precision DEFAULT NULL::double precision, "p_location_lng" double precision DEFAULT NULL::double precision) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_inventory RECORD;
    v_medicine RECORD;
    v_scan_result TEXT;
    v_result JSONB;
BEGIN
    SELECT * INTO v_inventory
    FROM public.pharmacy_medicine_inventory
    WHERE qr_code = p_qr_code;
    
    IF v_inventory.id IS NULL THEN
        v_scan_result := 'not_found';
        v_result := jsonb_build_object(
            'success', false,
            'message', 'QR code not found in inventory',
            'qr_code', p_qr_code
        );
    ELSIF v_inventory.is_expired THEN
        v_scan_result := 'expired';
        v_result := jsonb_build_object(
            'success', false,
            'message', 'Medicine has expired',
            'expiry_date', v_inventory.expiry_date,
            'medicine_name', (SELECT title FROM public.products WHERE id = v_inventory.product_id)
        );
    ELSIF NOT v_inventory.is_available THEN
        v_scan_result := 'unavailable';
        v_result := jsonb_build_object(
            'success', false,
            'message', 'Medicine is not available',
            'quantity', v_inventory.quantity_in_stock
        );
    ELSE
        v_scan_result := 'success';
        
        SELECT * INTO v_medicine
        FROM public.products
        WHERE id = v_inventory.product_id;
        
        v_result := jsonb_build_object(
            'success', true,
            'message', 'QR code scanned successfully',
            'inventory_id', v_inventory.id,
            'medicine', jsonb_build_object(
                'id', v_medicine.id,
                'name', v_medicine.title,
                'brand', v_medicine.brand,
                'price', v_medicine.price,
                'requires_prescription', v_medicine.attributes->>'requires_prescription'
            ),
            'inventory', jsonb_build_object(
                'batch_number', v_inventory.batch_number,
                'expiry_date', v_inventory.expiry_date,
                'quantity', v_inventory.quantity_available,
                'price', v_inventory.price,
                'storage_location', v_inventory.storage_location
            )
        );
        
        UPDATE public.pharmacy_medicine_inventory
        SET last_scanned_at = NOW(),
            scanned_by = p_user_id
        WHERE id = v_inventory.id;
    END IF;
    
    INSERT INTO public.pharmacy_qr_scan_logs (
        pharmacy_id,
        user_id,
        qr_code,
        inventory_id,
        medicine_id,
        product_id,
        scan_type,
        scan_result,
        device_info,
        location_lat,
        location_lng,
        created_at
    ) VALUES (
        p_pharmacy_id,
        p_user_id,
        p_qr_code,
        v_inventory.id,
        v_inventory.medicine_id,
        v_inventory.product_id,
        p_scan_type,
        v_scan_result,
        p_device_info,
        p_location_lat,
        p_location_lng,
        NOW()
    );
    
    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."process_qr_scan"("p_pharmacy_id" "uuid", "p_user_id" "uuid", "p_qr_code" "text", "p_scan_type" "text", "p_device_info" "text", "p_location_lat" double precision, "p_location_lng" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."products_search_vector_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(NEW.brand, '')), 'C') ||
    setweight(to_tsvector('english', COALESCE(NEW.category, '')), 'D');
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."products_search_vector_trigger"() OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."register_app_device"("p_token" "text", "p_platform" "text", "p_app_version" "text" DEFAULT NULL::"text", "p_device_model" "text" DEFAULT NULL::"text", "p_os_version" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE v_id UUID;
BEGIN
  INSERT INTO public.app_devices (user_id, device_token, platform, app_version, device_model, os_version)
  VALUES (auth.uid(), p_token, p_platform, p_app_version, p_device_model, p_os_version)
  ON CONFLICT (user_id, device_token, platform) 
  DO UPDATE SET last_seen_at = NOW(), is_active = TRUE, app_version = EXCLUDED.app_version
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;


ALTER FUNCTION "public"."register_app_device"("p_token" "text", "p_platform" "text", "p_app_version" "text", "p_device_model" "text", "p_os_version" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_push_subscription"("p_token" "text", "p_platform" "text", "p_app_version" "text" DEFAULT NULL::"text", "p_device_model" "text" DEFAULT NULL::"text", "p_os_version" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_subscription_id UUID;
    v_user_id UUID := auth.uid();
BEGIN
    -- Upsert subscription
    INSERT INTO public.push_subscriptions (
        user_id,
        token,
        platform,
        app_version,
        device_model,
        os_version,
        last_active_at,
        is_active
    ) VALUES (
        v_user_id,
        p_token,
        p_platform,
        p_app_version,
        p_device_model,
        p_os_version,
        NOW(),
        true
    )
    ON CONFLICT (user_id, token) DO UPDATE SET
        platform = EXCLUDED.platform,
        app_version = EXCLUDED.app_version,
        device_model = EXCLUDED.device_model,
        os_version = EXCLUDED.os_version,
        last_active_at = NOW(),
        is_active = true
    RETURNING id INTO v_subscription_id;
    
    RETURN v_subscription_id;
END;
$$;


ALTER FUNCTION "public"."register_push_subscription"("p_token" "text", "p_platform" "text", "p_app_version" "text", "p_device_model" "text", "p_os_version" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."request_payout"("p_user_id" "uuid", "p_amount" numeric, "p_payout_method" "text", "p_bank_details" "jsonb" DEFAULT NULL::"jsonb", "p_idempotency_key" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_wallet_id UUID;
  v_available_balance NUMERIC;
  v_payout_id UUID;
  v_fee NUMERIC;
  v_net_amount NUMERIC;
  v_min_payout NUMERIC := 50;  -- Minimum payout amount
BEGIN
  -- Check idempotency
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_payout_id
    FROM public.payouts
    WHERE idempotency_key = p_idempotency_key;
    
    IF v_payout_id IS NOT NULL THEN
      RETURN v_payout_id;
    END IF;
  END IF;
  
  -- Get wallet with lock
  SELECT id, balance INTO v_wallet_id, v_available_balance
  FROM public.user_wallets
  WHERE user_id = p_user_id AND is_active = true
  FOR UPDATE;
  
  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'No active wallet found for user';
  END IF;
  
  -- Validate amount
  IF p_amount < v_min_payout THEN
    RAISE EXCEPTION 'Minimum payout amount is % EGP', v_min_payout;
  END IF;
  
  IF p_amount > v_available_balance THEN
    RAISE EXCEPTION 'Insufficient balance. Available: %, Requested: %', v_available_balance, p_amount;
  END IF;
  
  -- Calculate fee (2% fee, min 5 EGP, max 100 EGP)
  v_fee := GREATEST(LEAST(p_amount * 0.02, 100), 5);
  v_net_amount := p_amount - v_fee;
  
  -- Create payout request
  INSERT INTO public.payouts (
    user_id, wallet_id, amount, fee, net_amount, currency,
    status, payout_method, bank_account_name, bank_account_number,
    bank_name, bank_code, metadata, idempotency_key
  ) VALUES (
    p_user_id, v_wallet_id, p_amount, v_fee, v_net_amount, 'EGP',
    'pending', p_payout_method,
    p_bank_details->>'account_name',
    p_bank_details->>'account_number',
    p_bank_details->>'bank_name',
    p_bank_details->>'bank_code',
    p_bank_details,
    p_idempotency_key
  )
  RETURNING id INTO v_payout_id;
  
  -- Hold the amount in wallet
  UPDATE public.user_wallets
  SET
    balance = balance - p_amount,
    pending_balance = pending_balance + p_amount,
    updated_at = NOW()
  WHERE id = v_wallet_id;
  
  -- Create wallet transaction
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, transaction_type, amount,
    balance_before, balance_after, reference_type, reference_id, description
  ) VALUES (
    v_wallet_id, p_user_id, 'hold', p_amount,
    v_available_balance, v_available_balance - p_amount,
    'payout', v_payout_id, 'Payout request held'
  );
  
  RETURN v_payout_id;
END;
$$;


ALTER FUNCTION "public"."request_payout"("p_user_id" "uuid", "p_amount" numeric, "p_payout_method" "text", "p_bank_details" "jsonb", "p_idempotency_key" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."restore_product_inventory_on_cancel"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Only trigger when order is cancelled
  IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'cancelled' THEN
    -- Restore product quantity
    UPDATE products
    SET quantity = quantity + COALESCE(OLD.subtotal / NULLIF(OLD.total - OLD.shipping - OLD.tax, 0), 1),
        updated_at = NOW()
    WHERE id IN (
      SELECT product_id FROM order_items WHERE order_id = OLD.id
    );
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."restore_product_inventory_on_cancel"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."run_daily_patient_backup"("p_doctor_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_backup_id UUID;
    v_patients RECORD;
    v_total_patients INTEGER;
    v_archived_count INTEGER := 0;
    v_failed_count INTEGER := 0;
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
BEGIN
    v_start_time := NOW();
    
    -- Create backup status record
    INSERT INTO public.health_daily_backup_status (
        doctor_id,
        backup_date,
        status,
        started_at
    ) VALUES (
        p_doctor_id,
        CURRENT_DATE,
        'in_progress',
        v_start_time
    )
    ON CONFLICT (doctor_id, backup_date)
    DO UPDATE SET
        status = 'in_progress',
        started_at = v_start_time
    RETURNING id INTO v_backup_id;
    
    -- Get all patients for this doctor
    SELECT COUNT(DISTINCT patient_id) INTO v_total_patients
    FROM public.health_appointments
    WHERE doctor_id = p_doctor_id;
    
    -- Archive each patient
    FOR v_patients IN (
        SELECT DISTINCT patient_id
        FROM public.health_appointments
        WHERE doctor_id = p_doctor_id
    ) LOOP
        BEGIN
            PERFORM public.archive_patient_data(p_doctor_id, v_patients.patient_id, 'daily_backup');
            v_archived_count := v_archived_count + 1;
        EXCEPTION WHEN OTHERS THEN
            v_failed_count := v_failed_count + 1;
            RAISE NOTICE 'Failed to archive patient %: %', v_patients.patient_id, SQLERRM;
        END;
    END LOOP;
    
    v_end_time := NOW();
    
    -- Update backup status
    UPDATE public.health_daily_backup_status
    SET
        total_patients = v_total_patients,
        archived_patients = v_archived_count,
        failed_patients = v_failed_count,
        backup_size_mb = (
            SELECT COALESCE(SUM(pg_column_size(archive_data)), 0) / (1024 * 1024)
            FROM public.health_patient_archives
            WHERE doctor_id = p_doctor_id AND backup_date = CURRENT_DATE
        ),
        status = CASE WHEN v_failed_count = 0 THEN 'completed' ELSE 'failed' END,
        completed_at = v_end_time,
        metadata = jsonb_build_object(
            'duration_seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time)),
            'success_rate', ROUND((v_archived_count::NUMERIC / NULLIF(v_total_patients, 0)) * 100, 2)
        )
    WHERE id = v_backup_id;
    
    RETURN jsonb_build_object(
        'backup_id', v_backup_id,
        'total_patients', v_total_patients,
        'archived', v_archived_count,
        'failed', v_failed_count,
        'duration_seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time)),
        'status', CASE WHEN v_failed_count = 0 THEN 'completed' ELSE 'failed' END
    );
END;
$$;


ALTER FUNCTION "public"."run_daily_patient_backup"("p_doctor_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."schedule_appointment"("p_patient_id" "uuid", "p_doctor_id" "uuid", "p_appointment_date" timestamp with time zone, "p_reason" "text", "p_appointment_type" character varying DEFAULT 'consultation'::character varying) RETURNS TABLE("success" boolean, "message" "text", "appointment_id" "uuid", "scheduled_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
DECLARE
  v_appointment_id UUID;
  v_doctor_verified BOOLEAN;
  v_patient_exists BOOLEAN;
BEGIN
  -- Verify doctor is verified
  SELECT is_verified INTO v_doctor_verified
  FROM public.health_doctor_profiles
  WHERE user_id = p_doctor_id;

  IF NOT COALESCE(v_doctor_verified, FALSE) THEN
    RETURN QUERY SELECT
      FALSE::BOOLEAN,
      'Doctor is not verified'::TEXT,
      NULL::UUID,
      NULL::TIMESTAMPTZ;
    RETURN;
  END IF;

  -- Check patient exists
  SELECT EXISTS(
    SELECT 1 FROM auth.users WHERE id = p_patient_id
  ) INTO v_patient_exists;

  IF NOT v_patient_exists THEN
    RETURN QUERY SELECT
      FALSE::BOOLEAN,
      'Patient not found'::TEXT,
      NULL::UUID,
      NULL::TIMESTAMPTZ;
    RETURN;
  END IF;

  -- Create appointment
  v_appointment_id := gen_random_uuid();

  INSERT INTO public.health_appointments (
    id,
    patient_id,
    doctor_id,
    appointment_date,
    reason,
    appointment_type,
    status,
    created_at,
    updated_at
  )
  VALUES (
    v_appointment_id,
    p_patient_id,
    p_doctor_id,
    p_appointment_date,
    p_reason,
    p_appointment_type,
    'scheduled',
    NOW(),
    NOW()
  );

  -- Log the scheduling
  INSERT INTO public.health_patient_access_log (
    user_id,
    action,
    resource_type,
    accessed_at,
    notes
  )
  VALUES (
    p_patient_id,
    'APPOINTMENT_SCHEDULED',
    'appointment',
    NOW(),
    p_reason
  );

  RETURN QUERY SELECT
    TRUE::BOOLEAN,
    'Appointment scheduled successfully'::TEXT,
    v_appointment_id,
    NOW();
END;
$$;


ALTER FUNCTION "public"."schedule_appointment"("p_patient_id" "uuid", "p_doctor_id" "uuid", "p_appointment_date" timestamp with time zone, "p_reason" "text", "p_appointment_type" character varying) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_auth_users"("p_query" "text", "p_current_user_id" "uuid") RETURNS TABLE("id" "uuid", "email" "text", "raw_user_meta_data" "jsonb", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'auth', 'pg_catalog'
    AS $$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() != p_current_user_id THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  RETURN QUERY
  SELECT au.id, au.email, au.raw_user_meta_data, au.created_at
  FROM auth.users au
  WHERE au.id != p_current_user_id
    AND (au.email ILIKE '%' || p_query || '%' 
         OR au.raw_user_meta_data->>'full_name' ILIKE '%' || p_query || '%')
  ORDER BY CASE WHEN au.email ILIKE p_query || '%' THEN 0 ELSE 1 END, au.email
  LIMIT 50;
END;
$$;


ALTER FUNCTION "public"."search_auth_users"("p_query" "text", "p_current_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_health_messages"("p_conversation_id" "uuid", "p_search_term" "text", "p_limit" integer DEFAULT 20) RETURNS TABLE("id" "uuid", "content" "text", "message_type" "text", "created_at" timestamp with time zone, "sender_role" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        hm.id,
        hm.content,
        hm.message_type,
        hm.created_at,
        hm.sender_role
    FROM public.health_messages hm
    WHERE hm.conversation_id = p_conversation_id
    AND hm.is_deleted = false
    AND (
        hm.content ILIKE '%' || p_search_term || '%'
        OR hm.attachment_name ILIKE '%' || p_search_term || '%'
    )
    ORDER BY hm.created_at DESC
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."search_health_messages"("p_conversation_id" "uuid", "p_search_term" "text", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_public_profiles"("p_search_term" "text" DEFAULT NULL::"text", "p_account_type" "text" DEFAULT NULL::"text", "p_location" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS TABLE("user_id" "uuid", "full_name" "text", "avatar_url" "text", "account_type" "text", "location" "text", "is_verified" boolean, "product_count" bigint, "total_revenue" numeric, "average_rating" numeric, "store_name" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.user_id,
    u.full_name,
    u.avatar_url,
    u.account_type,
    s.location,
    s.is_verified,
    COALESCE(pc.product_count, 0)::BIGINT AS product_count,
    COALESCE(sr.total_revenue, 0)::NUMERIC AS total_revenue,
    COALESCE(r.avg_rating, 0)::NUMERIC AS average_rating,
    sp.store_name
  FROM public.users u
  LEFT JOIN public.sellers s ON s.user_id = u.user_id
  LEFT JOIN public.seller_profiles sp ON sp.id = u.user_id
  LEFT JOIN (
    SELECT seller_id, COUNT(*) AS product_count
    FROM public.products
    WHERE is_deleted = false
    GROUP BY seller_id
  ) pc ON pc.seller_id = u.user_id
  LEFT JOIN (
    SELECT seller_id, SUM(total_price) AS total_revenue
    FROM public.sales
    GROUP BY seller_id
  ) sr ON sr.seller_id = u.user_id
  LEFT JOIN (
    SELECT 
      p.seller_id,
      AVG(r2.rating) AS avg_rating
    FROM public.products p
    LEFT JOIN public.reviews r2 ON r2.asin = p.asin
    WHERE r2.is_approved = true
    GROUP BY p.seller_id
  ) r ON r.seller_id = u.user_id
  WHERE 
    (p_search_term IS NULL OR 
      u.full_name ILIKE '%' || p_search_term || '%' OR 
      u.email ILIKE '%' || p_search_term || '%' OR
      s.location ILIKE '%' || p_search_term || '%' OR
      sp.store_name ILIKE '%' || p_search_term || '%')
    AND (p_account_type IS NULL OR u.account_type = p_account_type)
    AND (p_location IS NULL OR s.location ILIKE '%' || p_location || '%')
  ORDER BY s.is_verified DESC, product_count DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."search_public_profiles"("p_search_term" "text", "p_account_type" "text", "p_location" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_users"("p_query" "text", "p_exclude_user_id" "uuid", "p_limit" integer DEFAULT 50) RETURNS TABLE("id" "uuid", "user_id" "uuid", "email" "text", "full_name" "text", "avatar_url" "text", "account_type" "text")
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  SELECT
    u.user_id AS id,
    u.user_id AS user_id,
    u.email,
    u.full_name,
    u.avatar_url,
    u.account_type
  FROM public.users u
  WHERE u.user_id <> p_exclude_user_id
    AND (
      u.full_name ILIKE '%' || p_query || '%' OR
      u.email     ILIKE '%' || p_query || '%'
    )
  ORDER BY u.full_name NULLS LAST
  LIMIT p_limit;
$$;


ALTER FUNCTION "public"."search_users"("p_query" "text", "p_exclude_user_id" "uuid", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_users_for_chat"("p_query" "text", "p_current_user_id" "uuid") RETURNS TABLE("id" "uuid", "user_id" "text", "email" "text", "full_name" "text", "avatar_url" "text", "account_type" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.user_id, u.email, u.full_name, u.avatar_url, u.account_type
  FROM users u
  WHERE u.id != p_current_user_id
    AND (
      to_tsvector('english', u.full_name || ' ' || u.email) @@ to_tsquery('english', p_query)
      OR u.full_name ILIKE '%' || p_query || '%'
      OR u.email ILIKE '%' || p_query || '%'
    )
  LIMIT 20;
END;
$$;


ALTER FUNCTION "public"."search_users_for_chat"("p_query" "text", "p_current_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."seller_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text" DEFAULT NULL::"text", "p_location" "text" DEFAULT NULL::"text", "p_currency" "text" DEFAULT 'USD'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Get current authenticated user ID (must be called after supabase.auth.signUp)
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User must be authenticated first. Call supabase.auth.signUp() before this RPC.'
    );
  END IF;
  
  -- 1. Create/Update public.users with account_type as ARRAY (text[])
  INSERT INTO public.users (
    user_id,
    email,
    full_name,
    phone,
    account_type,  -- ✅ text[] column
    location,
    currency,
    created_at,
    updated_at
  ) VALUES (
    v_user_id,
    p_email,
    p_full_name,
    p_phone,
    ARRAY['user', 'seller']::text[],  -- ✅ Array format for users.account_type
    p_location,
    p_currency,
    NOW(),
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    account_type = EXCLUDED.account_type,
    location = EXCLUDED.location,
    currency = EXCLUDED.currency,
    updated_at = NOW();
  
  -- 2. Create/Update public.sellers with account_type as STRING (text)
  INSERT INTO public.sellers (
    user_id,
    email,
    full_name,
    phone,
    location,
    currency,
    account_type,  -- ✅ text column (single value)
    is_verified,
    is_factory,
    created_at,
    updated_at
  ) VALUES (
    v_user_id,
    p_email,
    p_full_name,
    p_phone,
    p_location,
    p_currency,
    'seller',  -- ✅ Single string for sellers.account_type
    FALSE,
    FALSE,
    NOW(),
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    location = EXCLUDED.location,
    currency = EXCLUDED.currency,
    updated_at = NOW();
  
  -- 3. Create user wallet (optional but recommended)
  INSERT INTO public.user_wallets (user_id, currency)
  VALUES (v_user_id, COALESCE(p_currency, 'USD'))
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'account_type', ARRAY['user', 'seller'],
    'message', 'Seller account created successfully'
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;


ALTER FUNCTION "public"."seller_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text", "p_location" "text", "p_currency" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_health_message"("p_conversation_id" "uuid", "p_content" "text", "p_message_type" "text" DEFAULT 'text'::"text", "p_attachment_url" "text" DEFAULT NULL::"text", "p_attachment_name" "text" DEFAULT NULL::"text", "p_attachment_size" bigint DEFAULT NULL::bigint, "p_attachment_type" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_message_id UUID;
    v_conversation RECORD;
    v_sender_role TEXT;
    v_recipient_id UUID;
BEGIN
    -- Get conversation details
    SELECT * INTO v_conversation
    FROM public.health_conversations
    WHERE id = p_conversation_id;
    
    IF v_conversation IS NULL THEN
        RAISE EXCEPTION 'Conversation not found';
    END IF;
    
    -- Determine sender role
    IF auth.uid() = (SELECT user_id FROM public.health_doctor_profiles WHERE id = v_conversation.doctor_id) THEN
        v_sender_role := 'doctor';
        v_recipient_id := (SELECT user_id FROM public.health_patient_profiles WHERE id = v_conversation.patient_id);
    ELSIF auth.uid() = (SELECT user_id FROM public.health_patient_profiles WHERE id = v_conversation.patient_id) THEN
        v_sender_role := 'patient';
        v_recipient_id := (SELECT user_id FROM public.health_doctor_profiles WHERE id = v_conversation.doctor_id);
    ELSE
        RAISE EXCEPTION 'Access denied: You are not a participant in this conversation';
    END IF;
    
    -- Check conversation status
    IF v_conversation.status != 'active' THEN
        RAISE EXCEPTION 'Cannot send messages to closed/archived conversations';
    END IF;
    
    -- Create message
    INSERT INTO public.health_messages (
        conversation_id,
        sender_id,
        sender_role,
        content,
        message_type,
        attachment_url,
        attachment_name,
        attachment_size,
        attachment_type,
        metadata,
        is_encrypted
    ) VALUES (
        p_conversation_id,
        auth.uid(),
        v_sender_role,
        p_content,
        p_message_type,
        p_attachment_url,
        p_attachment_name,
        p_attachment_size,
        p_attachment_type,
        p_metadata,
        true
    )
    RETURNING id INTO v_message_id;
    
    -- Send notification to recipient
    INSERT INTO public.notifications (
        user_id,
        title,
        message,
        type,
        priority,
        reference_type,
        reference_id,
        metadata
    ) VALUES (
        v_recipient_id,
        CASE WHEN v_sender_role = 'doctor' THEN '👨‍⚕️ New Message from Doctor' ELSE '📋 New Message from Patient' END,
        LEFT(p_content, 100),
        'message',
        'high',
        'health_conversation',
        p_conversation_id,
        jsonb_build_object(
            'conversation_id', p_conversation_id,
            'sender_role', v_sender_role,
            'message_id', v_message_id
        )
    );
    
    RETURN v_message_id;
END;
$$;


ALTER FUNCTION "public"."send_health_message"("p_conversation_id" "uuid", "p_content" "text", "p_message_type" "text", "p_attachment_url" "text", "p_attachment_name" "text", "p_attachment_size" bigint, "p_attachment_type" "text", "p_metadata" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_push_campaign"("p_title" "text", "p_body" "text", "p_target_user_ids" "uuid"[] DEFAULT NULL::"uuid"[], "p_target_account_types" "text"[] DEFAULT NULL::"text"[], "p_data" "jsonb" DEFAULT '{}'::"jsonb", "p_notification_type" "text" DEFAULT 'system'::"text", "p_scheduled_at" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_campaign_id UUID;
    v_user_ids UUID[];
    v_total_recipients INTEGER := 0;
BEGIN
    -- Determine target users
    IF p_target_user_ids IS NOT NULL THEN
        v_user_ids := p_target_user_ids;
    ELSIF p_target_account_types IS NOT NULL THEN
        SELECT ARRAY_AGG(user_id) INTO v_user_ids
        FROM public.users
        WHERE account_type = ANY(p_target_account_types);
    ELSE
        -- All users
        SELECT ARRAY_AGG(user_id) INTO v_user_ids FROM public.users;
    END IF;
    
    v_total_recipients := ARRAY_LENGTH(v_user_ids, 1);
    
    -- Create campaign
    INSERT INTO public.push_campaigns (
        title,
        body,
        target_audience,
        data,
        scheduled_at,
        status,
        total_recipients,
        created_by
    ) VALUES (
        p_title,
        p_body,
        jsonb_build_object(
            'user_ids', p_target_user_ids,
            'account_types', p_target_account_types
        ),
        p_data,
        COALESCE(p_scheduled_at, NOW()),
        CASE WHEN p_scheduled_at IS NULL THEN 'sending' ELSE 'scheduled' END,
        COALESCE(v_total_recipients, 0),
        auth.uid()
    )
    RETURNING id INTO v_campaign_id;
    
    -- If not scheduled, send immediately
    IF p_scheduled_at IS NULL THEN
        PERFORM public.execute_push_campaign(v_campaign_id);
    END IF;
    
    RETURN v_campaign_id;
END;
$$;


ALTER FUNCTION "public"."send_push_campaign"("p_title" "text", "p_body" "text", "p_target_user_ids" "uuid"[], "p_target_account_types" "text"[], "p_data" "jsonb", "p_notification_type" "text", "p_scheduled_at" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_push_notification"("p_user_id" "uuid", "p_title" "text", "p_body" "text", "p_data" "jsonb" DEFAULT '{}'::"jsonb", "p_notification_type" "text" DEFAULT 'system'::"text", "p_priority" "text" DEFAULT 'normal'::"text", "p_skip_quiet_hours" boolean DEFAULT false) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_notification_id UUID;
    v_subscription RECORD;
    v_quiet_hours_start TIME;
    v_quiet_hours_end TIME;
    v_is_quiet_hours BOOLEAN := false;
    v_log_id UUID;
BEGIN
    -- Check notification preferences
    IF EXISTS (
        SELECT 1 FROM public.notification_channel_preferences
        WHERE user_id = p_user_id
        AND channel_type = 'push'
        AND notification_type = p_notification_type
        AND is_enabled = false
    ) THEN
        RETURN NULL;  -- User disabled this notification type
    END IF;
    
    -- Check quiet hours
    IF NOT p_skip_quiet_hours THEN
        SELECT quiet_hours_start, quiet_hours_end
        INTO v_quiet_hours_start, v_quiet_hours_end
        FROM public.notification_settings
        WHERE user_id = p_user_id
        AND quiet_hours_enabled = true;
        
        IF v_quiet_hours_start IS NOT NULL AND v_quiet_hours_end IS NOT NULL THEN
            v_is_quiet_hours := (
                (v_quiet_hours_start <= v_quiet_hours_end AND CURRENT_TIME BETWEEN v_quiet_hours_start AND v_quiet_hours_end)
                OR (v_quiet_hours_start > v_quiet_hours_end AND (CURRENT_TIME >= v_quiet_hours_start OR CURRENT_TIME <= v_quiet_hours_end))
            );
            
            IF v_is_quiet_hours THEN
                -- Queue for later or skip based on priority
                IF p_priority != 'urgent' THEN
                    RETURN NULL;  -- Skip during quiet hours
                END IF;
            END IF;
        END IF;
    END IF;
    
    -- Create in-app notification
    INSERT INTO public.notifications (
        user_id,
        title,
        message,
        type,
        priority,
        metadata,
        created_at
    ) VALUES (
        p_user_id,
        p_title,
        p_body,
        p_notification_type::notification_type,
        p_priority::notification_priority,
        p_data,
        NOW()
    )
    RETURNING id INTO v_notification_id;
    
    -- Get active push subscriptions for user
    FOR v_subscription IN (
        SELECT id, token, platform
        FROM public.push_subscriptions
        WHERE user_id = p_user_id
        AND is_active = true
        AND token IS NOT NULL
    ) LOOP
        -- Log push notification attempt
        INSERT INTO public.push_notification_logs (
            user_id,
            subscription_id,
            notification_id,
            title,
            body,
            data,
            platform,
            status,
            created_at
        ) VALUES (
            p_user_id,
            v_subscription.id,
            v_notification_id,
            p_title,
            p_body,
            p_data,
            v_subscription.platform,
            'pending',
            NOW()
        )
        RETURNING id INTO v_log_id;
        
        -- NOTE: Actual push sending happens via Edge Function / External Service
        -- This is tracked in the log table
        UPDATE public.push_notification_logs
        SET status = 'sent', sent_at = NOW()
        WHERE id = v_log_id;
        
        -- Update subscription last active
        UPDATE public.push_subscriptions
        SET last_active_at = NOW()
        WHERE id = v_subscription.id;
    END LOOP;
    
    RETURN v_notification_id;
END;
$$;


ALTER FUNCTION "public"."send_push_notification"("p_user_id" "uuid", "p_title" "text", "p_body" "text", "p_data" "jsonb", "p_notification_type" "text", "p_priority" "text", "p_skip_quiet_hours" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_profiles_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_profiles_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at := timezone('utc'::text, now());
  RETURN NEW;
END $$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."share_prescription_with_pharmacy"("p_prescription_id" "uuid", "p_pharmacy_id" "uuid", "p_valid_hours" integer DEFAULT 72) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_share_token TEXT;
    v_expires_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Generate unique token
    v_share_token := 'RXSHARE-' || SUBSTRING(gen_random_uuid()::text, 1, 12);
    v_expires_at := NOW() + (p_valid_hours || ' hours')::INTERVAL;
    
    -- Create share record
    INSERT INTO public.health_prescription_shares (
        prescription_id,
        shared_with_pharmacy_id,
        share_token,
        expires_at,
        is_active
    ) VALUES (
        p_prescription_id,
        p_pharmacy_id,
        v_share_token,
        v_expires_at,
        TRUE
    );
    
    RETURN v_share_token;
END;
$$;


ALTER FUNCTION "public"."share_prescription_with_pharmacy"("p_prescription_id" "uuid", "p_pharmacy_id" "uuid", "p_valid_hours" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."signup_middleman"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text", "p_company_name" "text", "p_location" "text", "p_currency" "text" DEFAULT 'USD'::"text", "p_commission_rate" numeric DEFAULT 5.0, "p_specialization" "text" DEFAULT NULL::"text", "p_years_of_experience" integer DEFAULT NULL::integer, "p_tax_id" "text" DEFAULT NULL::"text", "p_bio" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
  v_middleman_id UUID;
  v_wallet_id UUID;
  v_verification_token TEXT;
  v_result JSON;
BEGIN
  -- Validate inputs
  IF p_email IS NULL OR p_email = '' THEN
    RETURN json_build_object('success', false, 'error', 'Email is required');
  END IF;

  IF p_password IS NULL OR LENGTH(p_password) < 8 THEN
    RETURN json_build_object('success', false, 'error', 'Password must be at least 8 characters');
  END IF;

  IF p_full_name IS NULL OR p_full_name = '' THEN
    RETURN json_build_object('success', false, 'error', 'Full name is required');
  END IF;

  IF p_company_name IS NULL OR p_company_name = '' THEN
    RETURN json_build_object('success', false, 'error', 'Company name is required');
  END IF;

  IF p_commission_rate < 0 OR p_commission_rate > 100 THEN
    RETURN json_build_object('success', false, 'error', 'Commission rate must be between 0 and 100');
  END IF;

  -- Check if email already exists
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
    RETURN json_build_object('success', false, 'error', 'Email already registered');
  END IF;

  -- Start transaction
  BEGIN
    -- Step 1: Create user in auth.users via RPC (using existing signup function pattern)
    -- We'll insert directly into auth.users with proper encryption
    INSERT INTO auth.users (
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      last_sign_in_at,
      role
    )
    VALUES (
      p_email,
      crypt(p_password, gen_salt('bf')),
      NULL, -- Email needs confirmation
      jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
      jsonb_build_object(
        'full_name', p_full_name,
        'phone', p_phone,
        'account_type', 'middleman'
      ),
      NOW(),
      NOW(),
      NOW(),
      'authenticated'
    )
    RETURNING id INTO v_user_id;

    -- Step 2: Create middleman profile
    INSERT INTO public.middlemen (
      user_id,
      company_name,
      location,
      currency,
      commission_rate,
      specialization,
      years_of_experience,
      tax_id,
      bio,
      status,
      verification_status,
      total_deals,
      total_revenue,
      total_commission_earned
    )
    VALUES (
      v_user_id,
      p_company_name,
      p_location,
      p_currency,
      p_commission_rate,
      p_specialization,
      p_years_of_experience,
      p_tax_id,
      p_bio,
      'pending', -- Initial status
      'unverified', -- Needs verification
      0,
      0,
      0
    )
    RETURNING id INTO v_middleman_id;

    -- Step 3: Create wallet for middleman
    INSERT INTO public.user_wallets (
      user_id,
      balance,
      currency,
      pending_balance,
      total_earned,
      total_withdrawn
    )
    VALUES (
      v_user_id,
      0,
      p_currency,
      0,
      0,
      0
    )
    RETURNING id INTO v_wallet_id;

    -- Step 4: Generate verification token
    v_verification_token := encode(gen_random_bytes(32), 'hex');

    -- Step 5: Create verification request
    INSERT INTO public.verification_requests (
      user_id,
      entity_type,
      entity_id,
      verification_token,
      status,
      expires_at
    )
    VALUES (
      v_user_id,
      'middleman',
      v_middleman_id,
      v_verification_token,
      'pending',
      NOW() + INTERVAL '7 days'
    );

    -- Step 6: Send verification email (via notification queue)
    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      message,
      data,
      is_read
    )
    VALUES (
      v_user_id,
      'email_verification',
      'Verify Your Middleman Account',
      'Please verify your email to activate your middleman account.',
      jsonb_build_object(
        'verification_token', v_verification_token,
        'entity_type', 'middleman',
        'company_name', p_company_name
      ),
      false
    );

    -- Build success response
    v_result := json_build_object(
      'success', true,
      'message', 'Middleman account created successfully. Please check your email for verification.',
      'data', json_build_object(
        'user_id', v_user_id,
        'middleman_id', v_middleman_id,
        'wallet_id', v_wallet_id,
        'email', p_email,
        'full_name', p_full_name,
        'company_name', p_company_name,
        'status', 'pending',
        'verification_required', true,
        'verification_token', v_verification_token
      )
    );

    RETURN v_result;

  EXCEPTION
    WHEN unique_violation THEN
      RETURN json_build_object('success', false, 'error', 'Email already exists');
    WHEN foreign_key_violation THEN
      RETURN json_build_object('success', false, 'error', 'Invalid reference data');
    WHEN check_violation THEN
      RETURN json_build_object('success', false, 'error', 'Data validation failed');
    WHEN OTHERS THEN
      RETURN json_build_object('success', false, 'error', SQLERRM);
  END;
END;
$$;


ALTER FUNCTION "public"."signup_middleman"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text", "p_company_name" "text", "p_location" "text", "p_currency" "text", "p_commission_rate" numeric, "p_specialization" "text", "p_years_of_experience" integer, "p_tax_id" "text", "p_bio" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."signup_middleman"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text", "p_company_name" "text", "p_location" "text", "p_currency" "text", "p_commission_rate" numeric, "p_specialization" "text", "p_years_of_experience" integer, "p_tax_id" "text", "p_bio" "text") IS 'Creates a new middleman account with user auth, profile, and wallet';



CREATE OR REPLACE FUNCTION "public"."split_payment_to_parties"("p_order_id" "uuid", "p_transaction_id" "uuid", "p_total_amount" numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_order RECORD;
  v_seller_share NUMERIC;
  v_middleman_share NUMERIC;
  v_platform_share NUMERIC;
  v_delivery_share NUMERIC;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  
  -- Calculate shares (ADJUST PERCENTAGES AS NEEDED)
  v_platform_share := p_total_amount * 0.05;  -- 5% platform fee
  v_seller_share := p_total_amount * 0.90;    -- 90% to seller
  v_middleman_share := 0;
  v_delivery_share := COALESCE(v_order.delivery_fee, 0);
  
  -- Adjust seller share if middleman exists
  IF v_order.middle_man_id IS NOT NULL THEN
    v_middleman_share := p_total_amount * 0.05;  -- 5% to middleman
    v_seller_share := v_seller_share - v_middleman_share;
  END IF;
  
  -- Insert splits
  INSERT INTO public.payment_splits (
    order_id, payment_transaction_id, recipient_id,
    recipient_type, amount, percentage, split_type, status
  ) VALUES 
    (p_order_id, p_transaction_id, v_order.seller_id, 'seller', 
     v_seller_share, 90.00, 'revenue', 'pending'),
    (p_order_id, p_transaction_id, v_order.seller_id, 'platform', 
     v_platform_share, 5.00, 'fee', 'paid');
  
  -- Middleman split
  IF v_order.middle_man_id IS NOT NULL THEN
    INSERT INTO public.payment_splits (
      order_id, payment_transaction_id, recipient_id,
      recipient_type, amount, percentage, split_type, status
    ) VALUES (
      p_order_id, p_transaction_id, v_order.middle_man_id,
      'middleman', v_middleman_share, 5.00, 'commission', 'pending'
    );
    
    -- Credit middleman wallet
    PERFORM public.credit_wallet(
      v_order.middle_man_id,
      v_middleman_share,
      'commission',
      p_order_id,
      'Commission from order ' || p_order_id,
      'mm_comm_' || p_order_id || '_' || v_order.middle_man_id,
      jsonb_build_object('order_id', p_order_id)
    );
  END IF;
  
  -- Delivery split
  IF v_order.delivery_id IS NOT NULL AND v_delivery_share > 0 THEN
    INSERT INTO public.payment_splits (
      order_id, payment_transaction_id, recipient_id,
      recipient_type, amount, split_type, status
    ) VALUES (
      p_order_id, p_transaction_id, v_order.delivery_id,
      'delivery', v_delivery_share, 'delivery_fee', 'pending'
    );
    
    -- Credit delivery wallet
    PERFORM public.credit_wallet(
      v_order.delivery_id,
      v_delivery_share,
      'payment',
      p_order_id,
      'Delivery fee for order ' || p_order_id,
      'del_fee_' || p_order_id,
      jsonb_build_object('order_id', p_order_id)
    );
  END IF;
  
  -- Credit seller wallet (after holding period if needed)
  PERFORM public.credit_wallet(
    v_order.seller_id,
    v_seller_share,
    'payment',
    p_order_id,
    'Revenue from order ' || p_order_id,
    'seller_rev_' || p_order_id,
    jsonb_build_object('order_id', p_order_id)
  );
END;
$$;


ALTER FUNCTION "public"."split_payment_to_parties"("p_order_id" "uuid", "p_transaction_id" "uuid", "p_total_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."split_template_purchase"("p_purchase_id" "uuid", "p_total_amount" numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_purchase RECORD;
  v_platform_share NUMERIC := p_total_amount * 0.15; -- 15% platform fee
  v_creator_share NUMERIC := p_total_amount - v_platform_share;
BEGIN
  SELECT * INTO v_purchase FROM marketplace_purchases WHERE id = p_purchase_id;
  
  -- Credit creator wallet
  PERFORM public.credit_wallet(
    v_purchase.buyer_id, -- actually creator_id from marketplace
    v_creator_share,
    'template_sale',
    p_purchase_id,
    'Template sale: ' || v_purchase.template_id,
    'tpl_creator_' || p_purchase_id
  );
  
  -- Log platform split
  INSERT INTO public.payment_splits (order_id, payment_transaction_id, recipient_id, recipient_type, amount, split_type, status)
  VALUES (NULL, v_purchase.transaction_id, '00000000-0000-0000-0000-000000000000', 'platform', v_platform_share, 'fee', 'paid');
END;
$$;


ALTER FUNCTION "public"."split_template_purchase"("p_purchase_id" "uuid", "p_total_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_consent_form"("p_patient_id" "uuid", "p_consent_type" character varying, "p_consent_data" "jsonb", "p_signature_url" "text") RETURNS TABLE("success" boolean, "message" "text", "consent_id" "uuid", "submitted_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
DECLARE
  v_consent_id UUID;
BEGIN
  v_consent_id := gen_random_uuid();

  -- Store consent form
  INSERT INTO public.health_patient_archives (
    id,
    user_id,
    archived_data,
    archive_date,
    created_at
  )
  VALUES (
    v_consent_id,
    p_patient_id,
    jsonb_build_object(
      'type', p_consent_type,
      'data', p_consent_data,
      'signature_url', p_signature_url,
      'consent_version', '1.0',
      'accepted_terms', TRUE
    ),
    NOW(),
    NOW()
  );

  -- Log the consent submission
  INSERT INTO public.health_patient_access_log (
    user_id,
    action,
    resource_type,
    accessed_at,
    notes
  )
  VALUES (
    p_patient_id,
    'CONSENT_SUBMITTED',
    'consent_form',
    NOW(),
    p_consent_type
  );

  RETURN QUERY SELECT
    TRUE::BOOLEAN,
    'Consent form submitted successfully'::TEXT,
    v_consent_id,
    NOW();
END;
$$;


ALTER FUNCTION "public"."submit_consent_form"("p_patient_id" "uuid", "p_consent_type" character varying, "p_consent_data" "jsonb", "p_signature_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_participant_account_type"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_account_type text;
BEGIN
  SELECT u.account_type INTO v_account_type
  FROM public.users u
  WHERE u.id = NEW.user_id;

  NEW.account_type := COALESCE(v_account_type, 'user');
  RETURN NEW;
END $$;


ALTER FUNCTION "public"."sync_participant_account_type"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_user_roles"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.user_roles (user_id) VALUES (NEW.id) ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_user_roles"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."track_deal_click"("p_unique_slug" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
BEGIN
  UPDATE public.middle_man_deals
  SET clicks = clicks + 1, updated_at = now()
  WHERE unique_slug = p_unique_slug AND is_active = true;
END;
$$;


ALTER FUNCTION "public"."track_deal_click"("p_unique_slug" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_push_appointment_reminder"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_patient_user_id UUID;
    v_doctor_name TEXT;
    v_hours_until INTEGER;
BEGIN
    -- Calculate hours until appointment
    v_hours_until := EXTRACT(EPOCH FROM (NEW.scheduled_at - NOW())) / 3600;
    
    -- Only send reminder if within 24-26 hours window
    IF v_hours_until BETWEEN 24 AND 26 THEN
        -- Get patient user_id
        SELECT user_id INTO v_patient_user_id
        FROM public.health_patient_profiles
        WHERE id = NEW.patient_id;
        
        -- Get doctor name
        SELECT full_name INTO v_doctor_name
        FROM public.users
        WHERE user_id = (
            SELECT user_id FROM public.health_doctor_profiles
            WHERE id = NEW.doctor_id
        );
        
        PERFORM public.send_push_notification(
            p_user_id := v_patient_user_id,
            p_title := '⏰ Appointment Reminder',
            p_body := 'You have an appointment with Dr. ' || v_doctor_name || ' tomorrow at ' || TO_CHAR(NEW.scheduled_at, 'HH:MI AM'),
            p_data := jsonb_build_object(
                'type', 'appointment_reminder',
                'appointment_id', NEW.id,
                'scheduled_at', NEW.scheduled_at,
                'action', 'view_appointment'
            ),
            p_notification_type := 'system',
            p_priority := 'high',
            p_skip_quiet_hours := true
        );
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_push_appointment_reminder"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_push_low_stock_alert"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    IF NEW.quantity_in_stock <= 10 AND NEW.is_available = true THEN
        PERFORM public.send_push_notification(
            p_user_id := (
                SELECT user_id FROM public.health_pharmacy_profiles
                WHERE id = NEW.pharmacy_id
            ),
            p_title := '⚠️ Low Stock Alert',
            p_body := 'Medicine "' || NEW.name || '" is running low (' || NEW.quantity_in_stock || ' remaining).',
            p_data := jsonb_build_object(
                'type', 'low_stock_alert',
                'medicine_id', NEW.id,
                'pharmacy_id', NEW.pharmacy_id,
                'quantity', NEW.quantity_in_stock,
                'action', 'view_inventory'
            ),
            p_notification_type := 'system',
            p_priority := 'medium'
        );
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_push_low_stock_alert"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_push_on_medicine_order_status"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_patient_user_id UUID;
    v_status_message TEXT;
BEGIN
    -- Get patient user_id
    SELECT user_id INTO v_patient_user_id
    FROM public.health_patient_profiles
    WHERE id = NEW.patient_id;
    
    -- Determine status message
    CASE NEW.status
        WHEN 'confirmed' THEN
            v_status_message := 'Your medicine order has been confirmed by the pharmacy.';
        WHEN 'ready' THEN
            v_status_message := 'Your medicine order is ready for pickup/delivery.';
        WHEN 'out_for_delivery' THEN
            v_status_message := 'Your medicine order is out for delivery.';
        WHEN 'delivered' THEN
            v_status_message := 'Your medicine order has been delivered successfully.';
        WHEN 'cancelled' THEN
            v_status_message := 'Your medicine order has been cancelled.';
        ELSE
            v_status_message := 'Your medicine order status has been updated.';
    END CASE;
    
    -- Only notify on status change
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        PERFORM public.send_push_notification(
            p_user_id := v_patient_user_id,
            p_title := '📦 Order Status Update',
            p_body := v_status_message,
            p_data := jsonb_build_object(
                'type', 'order_status_changed',
                'order_id', NEW.id,
                'old_status', OLD.status,
                'new_status', NEW.status,
                'action', 'view_order'
            ),
            p_notification_type := 'order',
            p_priority := CASE
                WHEN NEW.status IN ('ready', 'out_for_delivery', 'delivered') THEN 'high'
                ELSE 'normal'
            END
        );
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_push_on_medicine_order_status"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_push_on_prescription_created"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Notify patient about new prescription
    PERFORM public.send_push_notification(
        p_user_id := (
            SELECT user_id FROM public.health_patient_profiles
            WHERE id = NEW.patient_id
        ),
        p_title := '📋 New Prescription Ready',
        p_body := 'Dr. ' || (
            SELECT full_name FROM public.users
            WHERE user_id = (
                SELECT user_id FROM public.health_doctor_profiles
                WHERE id = NEW.doctor_id
            )
        ) || ' has created a new prescription for you.',
        p_data := jsonb_build_object(
            'type', 'prescription_created',
            'prescription_id', NEW.id,
            'action', 'view_prescription'
        ),
        p_notification_type := 'system',
        p_priority := 'high'
    );
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_push_on_prescription_created"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_push_payment_received"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
BEGIN
    IF NEW.status = 'success' AND OLD.status IS DISTINCT FROM 'success' THEN
        v_user_id := NEW.user_id;
        
        PERFORM public.send_push_notification(
            p_user_id := v_user_id,
            p_title := '💳 Payment Successful',
            p_body := 'Your payment of ' || NEW.currency || ' ' || NEW.amount || ' has been processed successfully.',
            p_data := jsonb_build_object(
                'type', 'payment_received',
                'transaction_id', NEW.id,
                'amount', NEW.amount,
                'currency', NEW.currency,
                'action', 'view_transaction'
            ),
            p_notification_type := 'payment',
            p_priority := 'high'
        );
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_push_payment_received"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_conversation_on_deal_proposal"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE conversations
  SET 
    deal_id = NEW.deal_id,
    conversation_type = 'deal_negotiation',
    last_message = '🤝 Deal proposal sent',
    last_message_at = NOW(),
    updated_at = NOW()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_conversation_on_deal_proposal"() OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."update_conversation_unread_count"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE conversations
    SET unread_count = COALESCE(unread_count, 0) + 1,
        last_message_at = NOW()
    WHERE id = NEW.conversation_id;
  ELSIF TG_OP = 'UPDATE' AND OLD.is_read = false AND NEW.is_read = true THEN
    UPDATE conversations
    SET unread_count = GREATEST(COALESCE(unread_count, 1) - 1, 0)
    WHERE id = NEW.conversation_id;
  END IF;
  RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."update_conversation_unread_count"() OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."update_delivery_assignments_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_delivery_assignments_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_delivery_profiles_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_delivery_profiles_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_factory_connections_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_factory_connections_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_factory_profile_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_factory_profile_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_freelancer_rating"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.freelancer_profiles
    SET 
      review_count = review_count + 1,
      average_rating = (
        SELECT COALESCE(AVG(rating), 0) 
        FROM public.service_reviews 
        WHERE freelancer_id = NEW.freelancer_id AND is_visible = TRUE
      ),
      updated_at = NOW()
    WHERE id = NEW.freelancer_id;
  ELSIF TG_OP = 'UPDATE' AND NEW.is_visible != OLD.is_visible THEN
    -- Recalculate if visibility changes
    UPDATE public.freelancer_profiles
    SET 
      review_count = (SELECT COUNT(*) FROM public.service_reviews WHERE freelancer_id = NEW.freelancer_id AND is_visible = TRUE),
      average_rating = (SELECT COALESCE(AVG(rating), 0) FROM public.service_reviews WHERE freelancer_id = NEW.freelancer_id AND is_visible = TRUE),
      updated_at = NOW()
    WHERE id = NEW.freelancer_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_freelancer_rating"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_freelancer_stats_on_completion"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status = 'completed' AND OLD.status != 'completed' THEN
    UPDATE public.freelancer_profiles
    SET 
      total_jobs_completed = total_jobs_completed + 1,
      total_earnings = total_earnings + NEW.price_paid,
      updated_at = NOW()
    WHERE id = NEW.freelancer_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_freelancer_stats_on_completion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_health_conversation_on_message"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NOT NEW.is_deleted THEN
        UPDATE public.health_conversations
        SET
            last_message = CASE
                WHEN NEW.message_type = 'image' THEN '📷 Image'
                WHEN NEW.message_type = 'file' THEN '📎 Attachment'
                WHEN NEW.message_type = 'prescription' THEN '💊 Prescription'
                ELSE LEFT(NEW.content, 100)
            END,
            last_message_at = NEW.created_at,
            is_read_by_doctor = CASE WHEN NEW.sender_role = 'doctor' THEN true ELSE is_read_by_doctor END,
            is_read_by_patient = CASE WHEN NEW.sender_role = 'patient' THEN true ELSE is_read_by_patient END,
            updated_at = NOW()
        WHERE id = NEW.conversation_id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_health_conversation_on_message"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_health_pharmacy_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_health_pharmacy_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_health_timestamps"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_health_timestamps"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_medicine_expiry_status"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        NEW.is_expired := NEW.expiry_date < CURRENT_DATE;
        NEW.is_near_expiry := NEW.expiry_date <= CURRENT_DATE + (NEW.near_expiry_threshold_days || ' days')::INTERVAL 
                              AND NEW.expiry_date >= CURRENT_DATE;
        NEW.is_available := NOT NEW.is_expired 
                           AND NEW.quantity_in_stock > 0 
                           AND NEW.quality_check_status = 'passed';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_medicine_expiry_status"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_medicine_rating"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        UPDATE public.health_medicines
        SET 
            average_rating = (
                SELECT COALESCE(AVG(rating), 0)
                FROM public.health_medicine_reviews
                WHERE medicine_id = NEW.medicine_id
                AND is_approved = TRUE
            ),
            review_count = (
                SELECT COUNT(*)
                FROM public.health_medicine_reviews
                WHERE medicine_id = NEW.medicine_id
                AND is_approved = TRUE
            )
        WHERE id = NEW.medicine_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.health_medicines
        SET 
            average_rating = (
                SELECT COALESCE(AVG(rating), 0)
                FROM public.health_medicine_reviews
                WHERE medicine_id = OLD.medicine_id
                AND is_approved = TRUE
            ),
            review_count = (
                SELECT COUNT(*)
                FROM public.health_medicine_reviews
                WHERE medicine_id = OLD.medicine_id
                AND is_approved = TRUE
            )
        WHERE id = OLD.medicine_id;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."update_medicine_rating"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_medicine_stock_on_order"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_pharmacy_id UUID;
    v_quantity_before INTEGER;
    v_quantity_after INTEGER;
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Get pharmacy_id and current quantity
        SELECT m.pharmacy_id, m.quantity_in_stock INTO v_pharmacy_id, v_quantity_before
        FROM public.health_medicines m
        WHERE m.id = NEW.medicine_id;
        
        -- Decrease stock
        UPDATE public.health_medicines
        SET quantity_in_stock = quantity_in_stock - NEW.quantity
        WHERE id = NEW.medicine_id;
        
        -- Get new quantity
        SELECT quantity_in_stock INTO v_quantity_after
        FROM public.health_medicines
        WHERE id = NEW.medicine_id;
        
        -- Record stock history
        INSERT INTO public.health_medicine_stock_history (
            medicine_id,
            pharmacy_id,
            change_type,
            quantity_change,
            quantity_before,
            quantity_after,
            reference_id,
            notes
        ) VALUES (
            NEW.medicine_id,
            v_pharmacy_id,
            'sale',
            -NEW.quantity,
            v_quantity_before,
            v_quantity_after,
            NEW.order_id,
            'Sold via order ' || NEW.order_id
        );
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_medicine_stock_on_order"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_notifications_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_notifications_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_order_payment_status"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.status = 'succeeded' THEN
    UPDATE orders
    SET payment_status = 'paid',
        updated_at = NOW()
    WHERE id = NEW.order_id;
  ELSIF NEW.status = 'failed' THEN
    UPDATE orders
    SET payment_status = 'failed',
        updated_at = NOW()
    WHERE id = NEW.order_id;
  ELSIF NEW.status = 'refunded' THEN
    UPDATE orders
    SET payment_status = 'refunded',
        updated_at = NOW()
    WHERE id = NEW.order_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_order_payment_status"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_order_status_secure"("p_order_id" "uuid", "p_seller_id" "uuid", "p_new_status" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_current_status text;
BEGIN
  -- 1. Verify Ownership
  IF NOT EXISTS (
    SELECT 1 FROM public.orders WHERE id = p_order_id AND seller_id = p_seller_id
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Order does not belong to this seller';
  END IF;

  -- 2. Get Current Status
  SELECT status INTO v_current_status FROM public.orders WHERE id = p_order_id;

  -- 3. Validate State Transition
  IF v_current_status = 'cancelled' OR v_current_status = 'refunded' THEN
    RAISE EXCEPTION 'Cannot update status of a cancelled/refunded order';
  END IF;

  IF p_new_status NOT IN ('confirmed', 'processing', 'shipped', 'out_for_delivery', 'delivered', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid status transition';
  END IF;

  -- 4. Update Status with Timestamp
  UPDATE public.orders
  SET 
    status = p_new_status,
    updated_at = now(),
    confirmed_at = CASE WHEN p_new_status = 'confirmed' THEN now() ELSE confirmed_at END,
    shipped_at = CASE WHEN p_new_status = 'shipped' THEN now() ELSE shipped_at END,
    delivered_at = CASE WHEN p_new_status = 'delivered' THEN now() ELSE delivered_at END,
    cancelled_at = CASE WHEN p_new_status = 'cancelled' THEN now() ELSE cancelled_at END
  WHERE id = p_order_id;

  RETURN jsonb_build_object('success', true, 'new_status', p_new_status);
END;
$$;


ALTER FUNCTION "public"."update_order_status_secure"("p_order_id" "uuid", "p_seller_id" "uuid", "p_new_status" "text") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."update_patient_visit_count"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.status = 'completed' AND OLD.status != 'completed' THEN
        UPDATE public.health_patient_profiles
        SET total_visits = total_visits + 1,
            last_visit_date = NEW.scheduled_at
        WHERE id = NEW.patient_id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_patient_visit_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_post_comments_count"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts SET comments_count = comments_count - 1 WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."update_post_comments_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_post_likes_count"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."update_post_likes_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_product_rating"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  avg_rating NUMERIC;
BEGIN
  IF TG_OP = 'DELETE' THEN
    OLD.asin := OLD.asin;
  END IF;
  
  SELECT AVG(rating) INTO avg_rating
  FROM reviews
  WHERE asin = COALESCE(NEW.asin, OLD.asin)
  AND is_approved = true;
  
  UPDATE products
  SET average_rating = COALESCE(avg_rating, 0),
      updated_at = NOW()
  WHERE asin = COALESCE(NEW.asin, OLD.asin);
  
  RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION "public"."update_product_rating"() OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."update_seller_product_count"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- This would need a seller_stats or sellers table with product_count column
  -- For now, you can use the existing get_seller_product_count() function
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_seller_product_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_seller_stats_on_order_delivered"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Only trigger on status change to 'delivered'
  IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'delivered' THEN
    -- Update seller's total revenue
    UPDATE sellers
    SET total_revenue = COALESCE(total_revenue, 0) + NEW.total,
        updated_at = NOW()
    WHERE user_id = NEW.seller_id;
    
    -- Update seller's total orders
    UPDATE sellers
    SET total_orders = COALESCE(total_orders, 0) + 1
    WHERE user_id = NEW.seller_id;
    
    -- Create sales record for analytics
    INSERT INTO sales (seller_id, customer_id, amount, sale_date, order_id)
    VALUES (NEW.seller_id, NEW.user_id, NEW.total, NOW(), NEW.id);
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_seller_stats_on_order_delivered"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_svc_conv_on_message"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NOT NEW.is_read THEN -- Assuming is_read false means new/unread logic or just update text
    UPDATE public.services_conversations
    SET
      last_message = CASE 
        WHEN NEW.message_type = 'image' THEN '📷 Image' 
        WHEN NEW.message_type = 'file' THEN '📎 Attachment'
        ELSE LEFT(NEW.content, 60) 
      END,
      last_message_at = NEW.created_at,
      updated_at = NOW(),
      -- Mark as unread for the receiver
      is_read_by_provider = CASE WHEN NEW.sender_id = provider_id THEN TRUE ELSE FALSE END,
      is_read_by_client = CASE WHEN NEW.sender_id = client_id THEN TRUE ELSE FALSE END
    WHERE id = NEW.conversation_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_svc_conv_on_message"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_svc_provider_rating"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.is_visible THEN
    UPDATE public.svc_providers
    SET 
      review_count = review_count + 1,
      average_rating = (
        SELECT COALESCE(AVG(rating), 0) 
        FROM public.svc_reviews 
        WHERE provider_id = NEW.provider_id AND is_visible = TRUE
      ),
      updated_at = NOW()
    WHERE id = NEW.provider_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_svc_provider_rating"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_svc_provider_stats"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status = 'completed' AND OLD.status != 'completed' THEN
    UPDATE public.svc_providers
    SET 
      total_jobs_completed = total_jobs_completed + 1,
      total_earnings = total_earnings + COALESCE(NEW.agreed_price, 0),
      updated_at = NOW()
    WHERE id = NEW.provider_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_svc_provider_stats"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_svc_timestamps"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_svc_timestamps"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_trading_conv_on_message"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.trading_conversations
    SET
      last_message = CASE WHEN NEW.message_type = 'image' THEN '📷 Image' ELSE LEFT(NEW.content, 50) END,
      last_message_at = NEW.created_at,
      updated_at = NOW()
    WHERE id = NEW.conversation_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_trading_conv_on_message"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_typing_indicator"("p_conversation_id" "uuid", "p_is_typing" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO public.health_typing_indicators (
        conversation_id,
        user_id,
        is_typing,
        last_activity
    ) VALUES (
        p_conversation_id,
        auth.uid(),
        p_is_typing,
        NOW()
    )
    ON CONFLICT (conversation_id, user_id) DO UPDATE SET
        is_typing = EXCLUDED.is_typing,
        last_activity = NOW();
END;
$$;


ALTER FUNCTION "public"."update_typing_indicator"("p_conversation_id" "uuid", "p_is_typing" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_user_last_seen"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.last_seen = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_user_last_seen"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_is_in_conversation"("p_conversation_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.conversation_participants 
        WHERE conversation_id = p_conversation_id 
        AND user_id = auth.uid()
    );
END;
$$;


ALTER FUNCTION "public"."user_is_in_conversation"("p_conversation_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_product_price"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.price IS NOT NULL AND NEW.price < 0 THEN
    RAISE EXCEPTION 'Price cannot be negative';
  END IF;
  IF NEW.price IS NOT NULL AND NEW.price > 999999 THEN
    RAISE EXCEPTION 'Price exceeds maximum allowed value';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."validate_product_price"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_wallet_balance"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.balance < 0 THEN
    RAISE EXCEPTION 'Wallet balance cannot be negative';
  END IF;
  
  IF NEW.pending_balance < 0 THEN
    RAISE EXCEPTION 'Pending balance cannot be negative';
  END IF;
  
  -- Validate balance_after matches calculation
  IF TG_TABLE_NAME = 'wallet_transactions' THEN
    IF NEW.transaction_type IN ('credit', 'release') THEN
      IF NEW.balance_after != NEW.balance_before + NEW.amount THEN
        RAISE EXCEPTION 'Balance calculation mismatch for credit transaction';
      END IF;
    ELSIF NEW.transaction_type IN ('debit', 'hold') THEN
      IF NEW.balance_after != NEW.balance_before - NEW.amount THEN
        RAISE EXCEPTION 'Balance calculation mismatch for debit transaction';
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."validate_wallet_balance"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."verify_cod_verification_key"("p_verification_key" "text", "p_driver_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_key_record RECORD;
  v_order RECORD;
  v_collection RECORD;
  v_result JSONB;
BEGIN
  -- Get verification key details
  SELECT * INTO v_key_record
  FROM public.cod_verification_keys
  WHERE verification_key = p_verification_key
  FOR UPDATE;
  
  IF v_key_record IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid verification key',
      'error_code', 'INVALID_KEY'
    );
  END IF;
  
  -- Check if already verified
  IF v_key_record.status = 'verified' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Verification key already used',
      'error_code', 'ALREADY_VERIFIED',
      'verified_at', v_key_record.verified_at
    );
  END IF;
  
  -- Check if expired
  IF v_key_record.expires_at < NOW() THEN
    UPDATE public.cod_verification_keys
    SET status = 'expired', updated_at = NOW()
    WHERE id = v_key_record.id;
    
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Verification key has expired',
      'error_code', 'KEY_EXPIRED',
      'expires_at', v_key_record.expires_at
    );
  END IF;
  
  -- Check max attempts
  IF v_key_record.verification_attempts >= v_key_record.max_attempts THEN
    UPDATE public.cod_verification_keys
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = v_key_record.id;
    
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Maximum verification attempts exceeded',
      'error_code', 'MAX_ATTEMPTS_EXCEEDED'
    );
  END IF;
  
  -- Get order details
  SELECT * INTO v_order FROM public.orders WHERE id = v_key_record.order_id;
  
  -- Verify driver is assigned to this order
  IF v_order.delivery_id != p_driver_id THEN
    -- Increment attempt counter
    UPDATE public.cod_verification_keys
    SET verification_attempts = verification_attempts + 1, updated_at = NOW()
    WHERE id = v_key_record.id;
    
    RETURN jsonb_build_object(
      'success', false,
      'error', 'You are not assigned to this order',
      'error_code', 'UNAUTHORIZED_DRIVER'
    );
  END IF;
  
  -- Mark key as verified
  UPDATE public.cod_verification_keys
  SET 
    status = 'verified',
    verified_at = NOW(),
    verified_by = p_driver_id,
    updated_at = NOW()
  WHERE id = v_key_record.id;
  
  -- Update order
  UPDATE public.orders
  SET 
    cod_verified = true,
    cod_verified_at = NOW(),
    cod_collected_by = p_driver_id,
    cod_collection_status = 'collected',
    payment_status = 'completed',
    status = 'delivered',
    delivered_at = NOW(),
    updated_at = NOW()
  WHERE id = v_key_record.order_id;
  
  -- Update COD collection
  UPDATE public.cod_collections
  SET 
    status = 'collected',
    collected_at = NOW(),
    delivery_id = p_driver_id,
    metadata = jsonb_set(
      COALESCE(metadata, '{}'::jsonb),
      '{verified_by_driver}',
      'true'::jsonb
    ),
    updated_at = NOW()
  WHERE order_id = v_key_record.order_id
  RETURNING * INTO v_collection;
  
  -- Credit driver wallet (delivery fee)
  IF v_order.delivery_fee > 0 THEN
    PERFORM public.credit_wallet(
      p_driver_id,
      v_order.delivery_fee,
      'payment',
      v_key_record.order_id,
      'Delivery fee for COD order ' || SUBSTRING(v_key_record.order_id::TEXT, 1, 8),
      'cod_delivery_fee_' || v_key_record.order_id::TEXT,
      jsonb_build_object('order_id', v_key_record.order_id, 'cod_verified', true)
    );
  END IF;
  
  -- Hold seller revenue until driver deposits cash (optional security)
  -- Or credit immediately based on your business logic
  PERFORM public.credit_wallet(
    v_order.seller_id,
    v_order.total - COALESCE(v_order.delivery_fee, 0),
    'payment',
    v_key_record.order_id,
    'COD payment for order ' || SUBSTRING(v_key_record.order_id::TEXT, 1, 8),
    'cod_seller_revenue_' || v_key_record.order_id::TEXT,
    jsonb_build_object('order_id', v_key_record.order_id, 'cod_verified', true)
  );
  
  -- Notify customer
  INSERT INTO public.notifications (user_id, type, title, message, metadata)
  VALUES (
    v_order.user_id,
    'order',
    '✅ Order Delivered & Paid',
    'Your COD order has been delivered and payment confirmed. Thank you!',
    jsonb_build_object('order_id', v_key_record.order_id, 'amount', v_order.total)
  );
  
  -- Notify driver
  INSERT INTO public.notifications (user_id, type, title, message, metadata)
  VALUES (
    p_driver_id,
    'delivery',
    '💰 COD Payment Collected',
    'You collected ' || v_order.total || ' EGP. Please deposit to company account within 24 hours.',
    jsonb_build_object('order_id', v_key_record.order_id, 'amount', v_order.total)
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'COD payment verified successfully',
    'order_id', v_key_record.order_id,
    'amount', v_order.total,
    'verified_at', NOW(),
    'driver_id', p_driver_id
  );
END;
$$;


ALTER FUNCTION "public"."verify_cod_verification_key"("p_verification_key" "text", "p_driver_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."verify_doctor"("p_doctor_id" "uuid", "p_verified_by" "uuid" DEFAULT NULL::"uuid", "p_notes" "text" DEFAULT NULL::"text") RETURNS TABLE("success" boolean, "message" "text", "doctor_id" "uuid", "is_verified" boolean, "verified_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
DECLARE
  v_doctor_exists BOOLEAN;
  v_admin_id UUID;
BEGIN
  -- Check if doctor exists
  SELECT EXISTS(
    SELECT 1 FROM public.health_doctor_profiles WHERE user_id = p_doctor_id
  ) INTO v_doctor_exists;

  IF NOT v_doctor_exists THEN
    RETURN QUERY SELECT
      FALSE::BOOLEAN,
      'Doctor not found'::TEXT,
      p_doctor_id,
      FALSE::BOOLEAN,
      NULL::TIMESTAMPTZ;
    RETURN;
  END IF;

  -- Update doctor verification status
  UPDATE public.health_doctor_profiles
  SET
    is_verified = TRUE,
    verified_at = NOW(),
    verified_by = COALESCE(p_verified_by, auth.uid()),
    updated_at = NOW()
  WHERE user_id = p_doctor_id;

  -- Log the verification
  INSERT INTO public.health_patient_access_log (
    user_id,
    action,
    resource_type,
    accessed_at,
    ip_address,
    notes
  )
  VALUES (
    COALESCE(p_verified_by, auth.uid()),
    'DOCTOR_VERIFIED',
    'doctor_profile',
    NOW(),
    '0.0.0.0',
    COALESCE(p_notes, '')
  );

  RETURN QUERY SELECT
    TRUE::BOOLEAN,
    'Doctor verified successfully'::TEXT,
    p_doctor_id,
    TRUE::BOOLEAN,
    NOW();
END;
$$;


ALTER FUNCTION "public"."verify_doctor"("p_doctor_id" "uuid", "p_verified_by" "uuid", "p_notes" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."verify_middleman_email"("p_verification_token" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
  v_middleman_id UUID;
  v_result JSON;
BEGIN
  -- Find verification request
  SELECT vr.user_id, vr.entity_id
  INTO v_user_id, v_middleman_id
  FROM public.verification_requests vr
  WHERE vr.verification_token = p_verification_token
    AND vr.entity_type = 'middleman'
    AND vr.status = 'pending'
    AND vr.expires_at > NOW();

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Invalid or expired verification token');
  END IF;

  -- Update user email confirmation
  UPDATE auth.users
  SET email_confirmed_at = NOW()
  WHERE id = v_user_id;

  -- Update middleman status
  UPDATE public.middlemen
  SET
    status = 'active',
    verification_status = 'verified',
    verified_at = NOW()
  WHERE id = v_middleman_id;

  -- Mark verification request as completed
  UPDATE public.verification_requests
  SET status = 'approved', approved_at = NOW()
  WHERE verification_token = p_verification_token;

  -- Send welcome notification
  INSERT INTO public.notifications (
    user_id,
    type,
    title,
    message,
    is_read
  )
  VALUES (
    v_user_id,
    'account_activated',
    'Welcome to Aurora!',
    'Your middleman account has been activated. You can now start selecting products and creating deals.',
    false
  );

  RETURN json_build_object(
    'success', true,
    'message', 'Email verified successfully. Your middleman account is now active.',
    'data', json_build_object(
      'user_id', v_user_id,
      'middleman_id', v_middleman_id,
      'status', 'active'
    )
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."verify_middleman_email"("p_verification_token" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."verify_middleman_email"("p_verification_token" "text") IS 'Verifies middleman email and activates account';



CREATE OR REPLACE FUNCTION "public"."verify_purchase_before_review"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Check if user actually purchased the product
  IF NOT EXISTS (
    SELECT 1 FROM orders o
    JOIN order_items oi ON o.id = oi.order_id
    WHERE o.user_id = NEW.user_id
    AND oi.asin = NEW.asin
    AND o.status = 'delivered'
  ) THEN
    NEW.is_verified_purchase := false;
    -- Optionally: RAISE EXCEPTION 'Cannot review products you have not purchased';
  ELSE
    NEW.is_verified_purchase := true;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."verify_purchase_before_review"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."activity_logs" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "action_type" "text" NOT NULL,
    "action_category" "text" NOT NULL,
    "description" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "ip_address" "text",
    "device_info" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."activity_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."admin_users" (
    "user_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'admin'::"text"
);


ALTER TABLE "public"."admin_users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."admins" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "granted_by" "uuid",
    "granted_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."admins" OWNER TO "postgres";


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


CREATE TABLE IF NOT EXISTS "public"."analytics_uploads" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" "uuid" NOT NULL,
    "file_name" "text" NOT NULL,
    "bucket_path" "text" NOT NULL,
    "uploaded_at" timestamp with time zone DEFAULT "now"(),
    "status" "text" DEFAULT 'success'::"text",
    "error_message" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    CONSTRAINT "analytics_uploads_entity_type_check" CHECK (("entity_type" = ANY (ARRAY['seller'::"text", 'factory'::"text", 'middleman'::"text"])))
);


ALTER TABLE "public"."analytics_uploads" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."app_devices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "device_token" "text" NOT NULL,
    "platform" "text",
    "app_version" "text",
    "os_version" "text",
    "device_model" "text",
    "is_active" boolean DEFAULT true,
    "last_seen_at" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "app_devices_platform_check" CHECK (("platform" = ANY (ARRAY['ios'::"text", 'android'::"text", 'web'::"text"])))
);


ALTER TABLE "public"."app_devices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."appointments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "uuid" NOT NULL,
    "service_id" "uuid" NOT NULL,
    "provider_id" "uuid" NOT NULL,
    "provider_type" "text" NOT NULL,
    "scheduled_at" timestamp with time zone NOT NULL,
    "status" "text" DEFAULT 'pending'::"text",
    "notes" "text",
    "meeting_link" "text",
    "total_price" numeric(10,2) NOT NULL,
    "payment_status" "text" DEFAULT 'pending'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "appointments_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['pending'::"text", 'paid'::"text", 'refunded'::"text"]))),
    CONSTRAINT "appointments_provider_type_check" CHECK (("provider_type" = ANY (ARRAY['freelancer'::"text", 'doctor'::"text", 'pharmacy'::"text"]))),
    CONSTRAINT "appointments_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'confirmed'::"text", 'completed'::"text", 'cancelled'::"text", 'no_show'::"text"])))
);


ALTER TABLE "public"."appointments" OWNER TO "postgres";


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


CREATE TABLE IF NOT EXISTS "public"."booking_milestones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "amount" numeric(10,2),
    "due_date" "date",
    "status" "text" DEFAULT 'pending'::"text",
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "booking_milestones_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'in_progress'::"text", 'completed'::"text", 'approved'::"text"])))
);


ALTER TABLE "public"."booking_milestones" OWNER TO "postgres";


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
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "verification_status" "text" DEFAULT 'pending'::"text"
);


ALTER TABLE "public"."business_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."calls" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid",
    "caller_id" "uuid",
    "callee_id" "uuid",
    "call_type" "text" NOT NULL,
    "status" "text" DEFAULT 'ringing'::"text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"(),
    "answered_at" timestamp with time zone,
    "ended_at" timestamp with time zone,
    "duration_seconds" integer,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "calls_call_type_check" CHECK (("call_type" = ANY (ARRAY['voice'::"text", 'video'::"text"]))),
    CONSTRAINT "calls_status_check" CHECK (("status" = ANY (ARRAY['ringing'::"text", 'connected'::"text", 'ended'::"text", 'rejected'::"text", 'missed'::"text"])))
);


ALTER TABLE "public"."calls" OWNER TO "postgres";


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


CREATE TABLE IF NOT EXISTS "public"."cod_collections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "verification_key_id" "uuid",
    "customer_id" "uuid" NOT NULL,
    "delivery_id" "uuid",
    "collection_amount" numeric(10,2) NOT NULL,
    "collection_method" "text" DEFAULT 'cash'::"text",
    "status" "text" DEFAULT 'pending'::"text",
    "collected_at" timestamp with time zone,
    "deposited_at" timestamp with time zone,
    "deposit_reference" "text",
    "deposit_method" "text",
    "customer_signature_url" "text",
    "driver_notes" "text",
    "customer_feedback" "text",
    "dispute_reason" "text",
    "disputed_at" timestamp with time zone,
    "disputed_by" "uuid",
    "resolved_at" timestamp with time zone,
    "resolved_by" "uuid",
    "resolution_notes" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "cod_collections_collection_method_check" CHECK (("collection_method" = ANY (ARRAY['cash'::"text", 'digital_wallet'::"text", 'card_on_delivery'::"text"]))),
    CONSTRAINT "cod_collections_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'collected'::"text", 'deposited'::"text", 'failed'::"text", 'disputed'::"text", 'refunded'::"text"])))
);


ALTER TABLE "public"."cod_collections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cod_verification_keys" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "verification_key" "text" NOT NULL,
    "key_type" "text" DEFAULT 'numeric'::"text",
    "key_length" integer DEFAULT 6,
    "status" "text" DEFAULT 'pending'::"text",
    "expires_at" timestamp with time zone NOT NULL,
    "verified_at" timestamp with time zone,
    "verified_by" "uuid",
    "verification_attempts" integer DEFAULT 0,
    "max_attempts" integer DEFAULT 3,
    "customer_notified_at" timestamp with time zone,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "cod_verification_keys_key_type_check" CHECK (("key_type" = ANY (ARRAY['numeric'::"text", 'alphanumeric'::"text"]))),
    CONSTRAINT "cod_verification_keys_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'verified'::"text", 'expired'::"text", 'cancelled'::"text", 'disputed'::"text"])))
);


ALTER TABLE "public"."cod_verification_keys" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."commissions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "middle_man_id" "uuid" NOT NULL,
    "order_id" "uuid",
    "deal_id" "uuid",
    "amount" numeric(10,2) NOT NULL,
    "commission_rate" numeric(5,2) NOT NULL,
    "status" "text" DEFAULT 'pending'::"text",
    "paid_at" timestamp with time zone,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "commissions_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'paid'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."commissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conversation_participants" (
    "conversation_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"(),
    "account_type" "text" DEFAULT 'user'::"text" NOT NULL,
    "role" "text" DEFAULT 'customer'::"text" NOT NULL,
    CONSTRAINT "conversation_participants_account_type_check" CHECK (("account_type" = ANY (ARRAY['user'::"text", 'seller'::"text", 'factory'::"text", 'admin'::"text", 'middleman'::"text", 'freelancer'::"text", 'doctor'::"text", 'pharmacy'::"text"]))),
    CONSTRAINT "conversation_participants_role_check" CHECK (("role" = ANY (ARRAY['customer'::"text", 'seller'::"text", 'factory'::"text", 'middleman'::"text", 'delivery'::"text", 'freelancer'::"text", 'doctor'::"text", 'pharmacy'::"text", 'admin'::"text"])))
);


ALTER TABLE "public"."conversation_participants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "type" "text" DEFAULT 'group'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "context" "text" DEFAULT 'general'::"text",
    "product_id" "uuid",
    "is_archived" boolean DEFAULT false,
    "last_message" "text",
    "last_message_at" timestamp with time zone,
    "unread_count" integer DEFAULT 0,
    CONSTRAINT "conversations_type_check" CHECK (("type" = ANY (ARRAY['direct'::"text", 'group'::"text"])))
);


ALTER TABLE "public"."conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customers" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid",
    "name" "text" NOT NULL,
    "phone" "text" DEFAULT ''::"text",
    "age_range" "text",
    "email" "text",
    "notes" "text",
    "total_orders" integer DEFAULT 0,
    "total_spent" numeric(10,2) DEFAULT 0,
    "last_purchase_date" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "seller_id" "uuid",
    "latitude" numeric(10,8),
    "longitude" numeric(11,8),
    CONSTRAINT "customers_age_range_check" CHECK (("age_range" = ANY (ARRAY['teens'::"text", '20s'::"text", '30s'::"text", '40s'::"text", '50s'::"text", '60s'::"text", '70s+'::"text"])))
);


ALTER TABLE "public"."customers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."deal_proposals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "proposer_id" "uuid" NOT NULL,
    "recipient_id" "uuid" NOT NULL,
    "commission_rate" numeric(5,2) NOT NULL,
    "min_order_quantity" integer DEFAULT 1,
    "terms" "text",
    "expires_at" timestamp with time zone,
    "status" "text" DEFAULT 'pending'::"text",
    "responded_at" timestamp with time zone,
    "responded_by" "uuid",
    "product_ids" "uuid"[] DEFAULT '{}'::"uuid"[],
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "deal_proposals_commission_rate_check" CHECK ((("commission_rate" >= (0)::numeric) AND ("commission_rate" <= (100)::numeric))),
    CONSTRAINT "deal_proposals_min_order_quantity_check" CHECK (("min_order_quantity" > 0)),
    CONSTRAINT "deal_proposals_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'accepted'::"text", 'rejected'::"text", 'cancelled'::"text", 'expired'::"text"])))
);


ALTER TABLE "public"."deal_proposals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."deals" (
    "id" "uuid" NOT NULL,
    "middleman_id" "uuid" NOT NULL,
    "party_a_id" "uuid" NOT NULL,
    "party_b_id" "uuid" NOT NULL,
    "product_id" "uuid",
    "commission_rate" numeric(5,2),
    "status" "text" DEFAULT 'active'::"text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone
);


ALTER TABLE "public"."deals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."deals_v2" (
    "id" "uuid" NOT NULL,
    "middleman_id" "uuid" NOT NULL,
    "party_a_id" "uuid" NOT NULL,
    "party_b_id" "uuid" NOT NULL,
    "product_id" "uuid",
    "commission_rate" numeric(5,2),
    "status" "text" DEFAULT 'active'::"text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone
);


ALTER TABLE "public"."deals_v2" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."delivery_assignments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid",
    "driver_id" "uuid",
    "status" "text" DEFAULT 'pending'::"text",
    "assigned_at" timestamp with time zone,
    "picked_up_at" timestamp with time zone,
    "delivered_at" timestamp with time zone,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "delivery_assignments_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'assigned'::"text", 'in_transit'::"text", 'delivered'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."delivery_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."delivery_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "full_name" "text" NOT NULL,
    "phone" "text",
    "vehicle_type" "text",
    "license_number" "text",
    "is_active" boolean DEFAULT true,
    "is_verified" boolean DEFAULT false,
    "is_available" boolean DEFAULT true,
    "current_location" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "latitude" double precision,
    "longitude" double precision,
    CONSTRAINT "delivery_profiles_vehicle_type_check" CHECK (("vehicle_type" = ANY (ARRAY['motorcycle'::"text", 'car'::"text", 'van'::"text", 'truck'::"text"])))
);


ALTER TABLE "public"."delivery_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."doctor_medicine_deals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "doctor_id" "uuid" NOT NULL,
    "medicine_id" "uuid" NOT NULL,
    "pharmacy_id" "uuid",
    "commission_rate" numeric(5,2) DEFAULT 5.00,
    "fixed_commission" numeric(10,2) DEFAULT 0,
    "min_quantity" integer DEFAULT 1,
    "is_active" boolean DEFAULT true,
    "is_exclusive" boolean DEFAULT false,
    "start_date" "date" DEFAULT CURRENT_DATE,
    "end_date" "date",
    "total_prescriptions" integer DEFAULT 0,
    "total_earnings" numeric(12,2) DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "valid_commission" CHECK ((("commission_rate" >= (0)::numeric) AND ("commission_rate" <= (100)::numeric))),
    CONSTRAINT "valid_fixed_commission" CHECK (("fixed_commission" >= (0)::numeric))
);


ALTER TABLE "public"."doctor_medicine_deals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."doctor_performance_metrics" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "doctor_id" "uuid" NOT NULL,
    "period_start" "date" NOT NULL,
    "period_end" "date" NOT NULL,
    "total_prescriptions" integer DEFAULT 0,
    "total_medicines_prescribed" integer DEFAULT 0,
    "total_patient_visits" integer DEFAULT 0,
    "total_commission_earned" numeric(12,2) DEFAULT 0,
    "average_prescription_value" numeric(10,2) DEFAULT 0,
    "top_prescribed_medicine_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."doctor_performance_metrics" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."doctors" (
    "user_id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "full_name" "text" NOT NULL,
    "phone" "text",
    "account_type" "text" DEFAULT 'doctor'::"text",
    "is_verified" boolean DEFAULT false,
    "license_number" "text" NOT NULL,
    "specialization" "text" NOT NULL,
    "clinic_name" "text",
    "clinic_address" "text",
    "consultation_fee" numeric(10,2),
    "available_days" "jsonb" DEFAULT '[]'::"jsonb",
    "available_hours" "jsonb" DEFAULT '{}'::"jsonb",
    "rating" numeric(3,2) DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "website_url" "text",
    CONSTRAINT "doctors_account_type_check" CHECK (("account_type" = 'doctor'::"text"))
);


ALTER TABLE "public"."doctors" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."error_logs" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid",
    "error_type" "text" NOT NULL,
    "error_message" "text" NOT NULL,
    "stack_trace" "text",
    "screen_name" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."error_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."factories" (
    "user_id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "full_name" "text" NOT NULL,
    "company_name" "text",
    "phone" "text",
    "location" "text",
    "currency" "text" DEFAULT 'USD'::"text",
    "account_type" "text" DEFAULT 'factory'::"text",
    "is_verified" boolean DEFAULT false,
    "capacity_info" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "business_license_url" "text",
    "is_factory" boolean,
    "latitude" bigint,
    "location_text" "text",
    "longitude" bigint,
    "production_capacity" bigint,
    "specialization" "text",
    "website_url" "text",
    "settings" "jsonb" DEFAULT '{"notifications": true, "lead_time_days": 7, "production_capacity": 0}'::"jsonb",
    "customers" "jsonb" DEFAULT '[]'::"jsonb"
);


ALTER TABLE "public"."factories" OWNER TO "postgres";


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


CREATE TABLE IF NOT EXISTS "public"."factory_production_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid",
    "status" "public"."factory_order_status",
    "notes" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "created_by" "uuid"
);


ALTER TABLE "public"."factory_production_logs" OWNER TO "postgres";


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
    "search_vector" "tsvector",
    "is_deleted" boolean DEFAULT false,
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
    "verified_at" timestamp with time zone,
    "allow_product_chats" boolean DEFAULT true,
    "allow_custom_requests" boolean DEFAULT false,
    "avatar_url" "text",
    "bio" "text",
    "response_rate" integer DEFAULT 0,
    "website_url" "text",
    "allow_middleman_promo" boolean DEFAULT true,
    "require_middleman_approval" boolean DEFAULT false,
    "store_slug" "text",
    "store_name" "text",
    "current_template_id" integer DEFAULT 1,
    CONSTRAINT "sellers_latitude_check" CHECK ((("latitude" >= ('-90'::integer)::numeric) AND ("latitude" <= (90)::numeric))),
    CONSTRAINT "sellers_longitude_check" CHECK ((("longitude" >= ('-180'::integer)::numeric) AND ("longitude" <= (180)::numeric)))
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


CREATE TABLE IF NOT EXISTS "public"."factory_profiles" (
    "id" "uuid" NOT NULL,
    "company_name" "text" NOT NULL,
    "business_license" "text",
    "specialization" "text"[],
    "production_capacity" "text",
    "min_order_quantity" integer DEFAULT 1,
    "location" "text",
    "country" "text",
    "website_url" "text",
    "description" "text",
    "rating" numeric(3,2) DEFAULT 0.00,
    "total_orders" integer DEFAULT 0,
    "response_time_hours" integer DEFAULT 24,
    "verified" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "settings" "jsonb" DEFAULT '{"notifications": true, "lead_time_days": 7, "production_capacity": 0}'::"jsonb",
    "customers" "jsonb" DEFAULT '[]'::"jsonb"
);


ALTER TABLE "public"."factory_profiles" OWNER TO "postgres";


COMMENT ON TABLE "public"."factory_profiles" IS 'Factory profile information for marketplace and dashboard';



CREATE TABLE IF NOT EXISTS "public"."factory_quotes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "factory_id" "uuid",
    "requester_id" "uuid",
    "product_id" "uuid",
    "status" "text",
    "quoted_price" numeric,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "factory_quotes_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'quoted'::"text", 'accepted'::"text", 'rejected'::"text", 'expired'::"text"])))
);


ALTER TABLE "public"."factory_quotes" OWNER TO "postgres";


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


CREATE TABLE IF NOT EXISTS "public"."freelancer_orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "service_id" "uuid",
    "client_id" "uuid",
    "status" "text" DEFAULT 'pending'::"text",
    "total_amount" numeric(10,2),
    "commission_amount" numeric(10,2),
    "requirements" "text",
    "delivery_date" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."freelancer_orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."freelancer_portfolio" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "freelancer_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "image_url" "text" NOT NULL,
    "project_link" "text",
    "category_tag" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."freelancer_portfolio" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."freelancer_profiles" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "display_name" "text" NOT NULL,
    "tagline" "text",
    "biography" "text",
    "profile_image_url" "text",
    "cover_image_url" "text",
    "hourly_rate" numeric(10,2),
    "currency" "text" DEFAULT 'USD'::"text",
    "location_country" "text",
    "languages" "text"[],
    "skills" "text"[],
    "total_jobs_completed" integer DEFAULT 0,
    "total_earnings" numeric(10,2) DEFAULT 0,
    "average_rating" numeric(3,2) DEFAULT 0,
    "review_count" integer DEFAULT 0,
    "is_verified" boolean DEFAULT false,
    "is_available" boolean DEFAULT true,
    "response_time_hours" integer,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "website_url" "text",
    "full_name" "text",
    "settings" "jsonb" DEFAULT '{}'::"jsonb",
    "customers" "jsonb" DEFAULT '[]'::"jsonb"
);


ALTER TABLE "public"."freelancer_profiles" OWNER TO "postgres";


COMMENT ON TABLE "public"."freelancer_profiles" IS 'Profiles for independent contractors and gig workers';



CREATE TABLE IF NOT EXISTS "public"."freelancer_services" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "provider_id" "uuid",
    "title" "text" NOT NULL,
    "description" "text",
    "category" "text",
    "price" numeric(10,2),
    "delivery_days" integer,
    "images" "text"[],
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."freelancer_services" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."freelancer_stats" AS
 SELECT "fp"."id",
    "fp"."full_name",
    "count"(DISTINCT "fo"."id") AS "total_orders",
    COALESCE("sum"("fo"."total_amount"), (0)::numeric) AS "total_revenue",
    COALESCE("avg"("fo"."total_amount"), (0)::numeric) AS "avg_order_value",
    "count"(
        CASE
            WHEN ("fo"."status" = 'completed'::"text") THEN 1
            ELSE NULL::integer
        END) AS "completed_orders",
    "count"(
        CASE
            WHEN ("fo"."status" = 'pending'::"text") THEN 1
            ELSE NULL::integer
        END) AS "pending_orders"
   FROM (("public"."freelancer_profiles" "fp"
     LEFT JOIN "public"."freelancer_services" "fs" ON (("fp"."id" = "fs"."provider_id")))
     LEFT JOIN "public"."freelancer_orders" "fo" ON (("fs"."id" = "fo"."service_id")))
  GROUP BY "fp"."id", "fp"."full_name";


ALTER VIEW "public"."freelancer_stats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_appointments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "doctor_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "scheduled_at" timestamp with time zone NOT NULL,
    "duration_minutes" integer DEFAULT 30,
    "status" "text" DEFAULT 'pending'::"text",
    "payment_status" "text" DEFAULT 'pending'::"text",
    "payment_amount" numeric(10,2),
    "payment_intent_id" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "health_appointments_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['pending'::"text", 'paid'::"text", 'refunded'::"text"]))),
    CONSTRAINT "health_appointments_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'confirmed'::"text", 'active'::"text", 'completed'::"text", 'cancelled'::"text", 'no_show'::"text"])))
);


ALTER TABLE "public"."health_appointments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_chat_attachments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "message_id" "uuid",
    "conversation_id" "uuid" NOT NULL,
    "file_url" "text" NOT NULL,
    "file_name" "text" NOT NULL,
    "file_size" bigint NOT NULL,
    "file_type" "text" NOT NULL,
    "uploaded_by" "uuid" NOT NULL,
    "is_scanned" boolean DEFAULT false,
    "scan_result" "text",
    "virus_scan_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "expires_at" timestamp with time zone
);


ALTER TABLE "public"."health_chat_attachments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "appointment_id" "uuid",
    "doctor_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "conversation_type" "text" DEFAULT 'appointment'::"text",
    "status" "text" DEFAULT 'active'::"text",
    "last_message" "text",
    "last_message_at" timestamp with time zone,
    "is_read_by_doctor" boolean DEFAULT false,
    "is_read_by_patient" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "closed_at" timestamp with time zone,
    "closed_by" "uuid",
    CONSTRAINT "health_conversations_conversation_type_check" CHECK (("conversation_type" = ANY (ARRAY['appointment'::"text", 'consultation'::"text", 'follow_up'::"text", 'emergency'::"text"]))),
    CONSTRAINT "health_conversations_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'archived'::"text", 'closed'::"text"])))
);


ALTER TABLE "public"."health_conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_daily_backup_status" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "doctor_id" "uuid" NOT NULL,
    "backup_date" "date" NOT NULL,
    "total_patients" integer DEFAULT 0,
    "archived_patients" integer DEFAULT 0,
    "failed_patients" integer DEFAULT 0,
    "backup_size_mb" numeric(10,2) DEFAULT 0,
    "status" "text" DEFAULT 'pending'::"text",
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "error_message" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    CONSTRAINT "health_daily_backup_status_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'in_progress'::"text", 'completed'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."health_daily_backup_status" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_doctor_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "specialization" "text" NOT NULL,
    "license_number" "text" NOT NULL,
    "consultation_fee" numeric(10,2) NOT NULL,
    "availability_schedule" "jsonb" DEFAULT '[]'::"jsonb",
    "is_verified" boolean DEFAULT false,
    "bio" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."health_doctor_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_medicine_categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "parent_id" "uuid",
    "description" "text",
    "icon" "text",
    "sort_order" integer DEFAULT 0,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "requires_special_license" boolean DEFAULT false
);


ALTER TABLE "public"."health_medicine_categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_medicine_expiry_alerts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pharmacy_id" "uuid" NOT NULL,
    "inventory_id" "uuid" NOT NULL,
    "medicine_id" "uuid" NOT NULL,
    "batch_number" "text" NOT NULL,
    "expiry_date" "date" NOT NULL,
    "days_until_expiry" integer NOT NULL,
    "alert_level" "text",
    "quantity_affected" integer NOT NULL,
    "is_resolved" boolean DEFAULT false,
    "resolved_at" timestamp with time zone,
    "resolved_by" "uuid",
    "resolution_action" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "health_medicine_expiry_alerts_alert_level_check" CHECK (("alert_level" = ANY (ARRAY['info'::"text", 'warning'::"text", 'critical'::"text", 'expired'::"text"])))
);


ALTER TABLE "public"."health_medicine_expiry_alerts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_medicine_order_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "medicine_id" "uuid" NOT NULL,
    "medicine_name" "text" NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "unit_price" numeric(10,2) NOT NULL,
    "total_price" numeric(10,2) NOT NULL,
    "prescription_required" boolean DEFAULT false,
    "prescription_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."health_medicine_order_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_medicine_orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pharmacy_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "prescription_id" "uuid",
    "status" "text" DEFAULT 'pending'::"text",
    "payment_status" "text" DEFAULT 'pending'::"text",
    "subtotal" numeric(10,2) DEFAULT 0 NOT NULL,
    "delivery_fee" numeric(10,2) DEFAULT 0,
    "discount" numeric(10,2) DEFAULT 0,
    "total" numeric(10,2) DEFAULT 0 NOT NULL,
    "payment_method" "text" DEFAULT 'cash'::"text",
    "delivery_address" "jsonb" NOT NULL,
    "delivery_phone" "text" NOT NULL,
    "delivery_notes" "text",
    "payment_intent_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "confirmed_at" timestamp with time zone,
    "ready_at" timestamp with time zone,
    "delivered_at" timestamp with time zone,
    "cancelled_at" timestamp with time zone,
    CONSTRAINT "health_medicine_orders_payment_method_check" CHECK (("payment_method" = ANY (ARRAY['cash'::"text", 'card'::"text", 'digital_wallet'::"text", 'cod'::"text"]))),
    CONSTRAINT "health_medicine_orders_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['pending'::"text", 'paid'::"text", 'refunded'::"text"]))),
    CONSTRAINT "health_medicine_orders_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'confirmed'::"text", 'preparing'::"text", 'ready'::"text", 'out_for_delivery'::"text", 'delivered'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."health_medicine_orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_medicine_recalls" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "medicine_id" "uuid" NOT NULL,
    "recall_number" "text" NOT NULL,
    "recall_type" "text",
    "recall_reason" "text" NOT NULL,
    "risk_level" "text",
    "affected_batches" "jsonb" DEFAULT '[]'::"jsonb",
    "manufacturer_notice" "text",
    "regulatory_authority" "text",
    "recall_date" "date" NOT NULL,
    "expiry_date" "date",
    "instructions" "text",
    "is_active" boolean DEFAULT true,
    "resolved_at" timestamp with time zone,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "health_medicine_recalls_recall_type_check" CHECK (("recall_type" = ANY (ARRAY['Class I'::"text", 'Class II'::"text", 'Class III'::"text", 'Safety Alert'::"text", 'Market Withdrawal'::"text"]))),
    CONSTRAINT "health_medicine_recalls_risk_level_check" CHECK (("risk_level" = ANY (ARRAY['high'::"text", 'medium'::"text", 'low'::"text"])))
);


ALTER TABLE "public"."health_medicine_recalls" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_medicine_reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "medicine_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "order_id" "uuid",
    "rating" integer NOT NULL,
    "title" "text",
    "comment" "text",
    "is_verified_purchase" boolean DEFAULT false,
    "is_approved" boolean DEFAULT true,
    "helpful_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "health_medicine_reviews_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."health_medicine_reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_medicine_stock_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "medicine_id" "uuid" NOT NULL,
    "pharmacy_id" "uuid" NOT NULL,
    "change_type" "text" NOT NULL,
    "quantity_change" integer NOT NULL,
    "quantity_before" integer NOT NULL,
    "quantity_after" integer NOT NULL,
    "reference_id" "uuid",
    "notes" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "health_medicine_stock_history_change_type_check" CHECK (("change_type" = ANY (ARRAY['sale'::"text", 'restock'::"text", 'adjustment'::"text", 'expiry'::"text", 'return'::"text"])))
);


ALTER TABLE "public"."health_medicine_stock_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_medicines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pharmacy_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "generic_name" "text",
    "brand" "text",
    "manufacturer" "text",
    "category" "text" NOT NULL,
    "subcategory" "text",
    "description" "text",
    "dosage_form" "text",
    "strength" "text",
    "unit" "text" DEFAULT 'piece'::"text",
    "price" numeric(10,2) NOT NULL,
    "currency" "text" DEFAULT 'EGP'::"text",
    "quantity_in_stock" integer DEFAULT 0,
    "requires_prescription" boolean DEFAULT false,
    "prescription_category" "text",
    "active_ingredients" "jsonb" DEFAULT '[]'::"jsonb",
    "side_effects" "text",
    "warnings" "text",
    "storage_instructions" "text",
    "expiry_date" "date",
    "batch_number" "text",
    "barcode" "text",
    "sku" "text",
    "images" "jsonb" DEFAULT '[]'::"jsonb",
    "is_available" boolean DEFAULT true,
    "is_featured" boolean DEFAULT false,
    "average_rating" numeric(3,2) DEFAULT 0,
    "review_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "health_medicines_dosage_form_check" CHECK (("dosage_form" = ANY (ARRAY['tablet'::"text", 'capsule'::"text", 'syrup'::"text", 'injection'::"text", 'cream'::"text", 'ointment'::"text", 'drops'::"text", 'inhaler'::"text", 'patch'::"text", 'other'::"text"]))),
    CONSTRAINT "health_medicines_prescription_category_check" CHECK (("prescription_category" = ANY (ARRAY['none'::"text", 'over_counter'::"text", 'prescription_required'::"text", 'controlled'::"text"])))
);


ALTER TABLE "public"."health_medicines" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_medicines_master" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "generic_name" "text",
    "brand" "text",
    "manufacturer" "text",
    "category" "text" NOT NULL,
    "subcategory" "text",
    "description" "text",
    "dosage_form" "text",
    "strength" "text",
    "unit" "text" DEFAULT 'piece'::"text",
    "requires_prescription" boolean DEFAULT false,
    "prescription_category" "text",
    "controlled_substance_schedule" "text",
    "active_ingredients" "jsonb" DEFAULT '[]'::"jsonb",
    "inactive_ingredients" "jsonb" DEFAULT '[]'::"jsonb",
    "indications" "text",
    "contraindications" "text",
    "side_effects" "text",
    "warnings" "text",
    "precautions" "text",
    "drug_interactions" "jsonb" DEFAULT '[]'::"jsonb",
    "pregnancy_category" "text",
    "breastfeeding_safety" "text",
    "pediatric_safety" "text",
    "geriatric_safety" "text",
    "dosage_instructions" "text",
    "administration_route" "text",
    "storage_instructions" "text",
    "shelf_life_months" integer,
    "is_hazardous" boolean DEFAULT false,
    "is_refrigerated" boolean DEFAULT false,
    "is_light_sensitive" boolean DEFAULT false,
    "who_essential_medicine" boolean DEFAULT false,
    "fda_approved" boolean DEFAULT false,
    "source_url" "text",
    "source_verified_date" "date",
    "barcode_template" "text",
    "sku_template" "text",
    "is_active" boolean DEFAULT true,
    "is_featured" boolean DEFAULT false,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "health_medicines_master_controlled_substance_schedule_check" CHECK (("controlled_substance_schedule" = ANY (ARRAY['none'::"text", 'Schedule I'::"text", 'Schedule II'::"text", 'Schedule III'::"text", 'Schedule IV'::"text", 'Schedule V'::"text"]))),
    CONSTRAINT "health_medicines_master_dosage_form_check" CHECK (("dosage_form" = ANY (ARRAY['tablet'::"text", 'capsule'::"text", 'syrup'::"text", 'injection'::"text", 'cream'::"text", 'ointment'::"text", 'drops'::"text", 'inhaler'::"text", 'patch'::"text", 'suppository'::"text", 'liquid'::"text", 'powder'::"text", 'other'::"text"]))),
    CONSTRAINT "health_medicines_master_pregnancy_category_check" CHECK (("pregnancy_category" = ANY (ARRAY['A'::"text", 'B'::"text", 'C'::"text", 'D'::"text", 'X'::"text", 'unknown'::"text"]))),
    CONSTRAINT "health_medicines_master_prescription_category_check" CHECK (("prescription_category" = ANY (ARRAY['none'::"text", 'over_counter'::"text", 'prescription_required'::"text", 'controlled'::"text", 'narcotic'::"text", 'psychotropic'::"text"])))
);


ALTER TABLE "public"."health_medicines_master" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_message_archives" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "message_data" "jsonb" NOT NULL,
    "archived_at" timestamp with time zone DEFAULT "now"(),
    "retention_until" timestamp with time zone DEFAULT ("now"() + '7 years'::interval)
);


ALTER TABLE "public"."health_message_archives" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_message_receipts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "message_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "read_at" timestamp with time zone DEFAULT "now"(),
    "device_info" "text"
);


ALTER TABLE "public"."health_message_receipts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "sender_role" "text" NOT NULL,
    "content" "text",
    "message_type" "text" DEFAULT 'text'::"text",
    "attachment_url" "text",
    "attachment_name" "text",
    "attachment_size" bigint,
    "attachment_type" "text",
    "is_encrypted" boolean DEFAULT true,
    "is_read" boolean DEFAULT false,
    "read_at" timestamp with time zone,
    "is_deleted" boolean DEFAULT false,
    "deleted_at" timestamp with time zone,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "health_messages_message_type_check" CHECK (("message_type" = ANY (ARRAY['text'::"text", 'image'::"text", 'file'::"text", 'prescription'::"text", 'lab_result'::"text", 'system'::"text"]))),
    CONSTRAINT "health_messages_sender_role_check" CHECK (("sender_role" = ANY (ARRAY['doctor'::"text", 'patient'::"text", 'system'::"text"])))
);


ALTER TABLE "public"."health_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_patient_access_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "doctor_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "access_type" "text" NOT NULL,
    "data_accessed" "jsonb",
    "device_info" "text",
    "ip_address" "text",
    "accessed_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "health_patient_access_log_access_type_check" CHECK (("access_type" = ANY (ARRAY['view'::"text", 'edit'::"text", 'export'::"text", 'print'::"text"])))
);


ALTER TABLE "public"."health_patient_access_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_patient_archives" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "doctor_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "archive_data" "jsonb" NOT NULL,
    "data_version" integer DEFAULT 1,
    "archive_type" "text" DEFAULT 'full'::"text",
    "data_hash" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "backup_date" "date" DEFAULT CURRENT_DATE,
    "is_synced" boolean DEFAULT false,
    "sync_attempts" integer DEFAULT 0,
    "last_sync_at" timestamp with time zone,
    CONSTRAINT "health_patient_archives_archive_type_check" CHECK (("archive_type" = ANY (ARRAY['full'::"text", 'incremental'::"text", 'daily_backup'::"text"])))
);


ALTER TABLE "public"."health_patient_archives" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_patient_change_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "doctor_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "change_type" "text" NOT NULL,
    "entity_id" "uuid",
    "old_data" "jsonb",
    "new_data" "jsonb",
    "changed_by" "uuid",
    "changed_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "health_patient_change_log_change_type_check" CHECK (("change_type" = ANY (ARRAY['appointment'::"text", 'prescription'::"text", 'message'::"text", 'vital'::"text", 'note'::"text", 'other'::"text"])))
);


ALTER TABLE "public"."health_patient_change_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_patient_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "date_of_birth" "date",
    "blood_type" "text",
    "medical_history" "jsonb" DEFAULT '[]'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."health_patient_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_pharmacy_inspections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pharmacy_id" "uuid" NOT NULL,
    "inspector_id" "uuid",
    "inspector_name" "text" NOT NULL,
    "inspection_type" "text",
    "inspection_date" "date" NOT NULL,
    "next_inspection_date" "date",
    "overall_status" "text",
    "findings" "jsonb" DEFAULT '[]'::"jsonb",
    "violations" "jsonb" DEFAULT '[]'::"jsonb",
    "corrective_actions" "jsonb" DEFAULT '[]'::"jsonb",
    "corrective_action_deadline" "date",
    "notes" "text",
    "report_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "health_pharmacy_inspections_inspection_type_check" CHECK (("inspection_type" = ANY (ARRAY['routine'::"text", 'complaint'::"text", 'follow_up'::"text", 'license_renewal'::"text"]))),
    CONSTRAINT "health_pharmacy_inspections_overall_status_check" CHECK (("overall_status" = ANY (ARRAY['pass'::"text", 'pass_with_conditions'::"text", 'fail'::"text", 'suspended'::"text"])))
);


ALTER TABLE "public"."health_pharmacy_inspections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_pharmacy_inventory" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pharmacy_id" "uuid" NOT NULL,
    "medicine_id" "uuid" NOT NULL,
    "batch_number" "text" NOT NULL,
    "expiry_date" "date" NOT NULL,
    "manufacturing_date" "date",
    "price" numeric(10,2) NOT NULL,
    "currency" "text" DEFAULT 'EGP'::"text",
    "quantity_in_stock" integer DEFAULT 0,
    "quantity_reserved" integer DEFAULT 0,
    "quantity_available" integer GENERATED ALWAYS AS (("quantity_in_stock" - "quantity_reserved")) STORED,
    "is_available" boolean DEFAULT true,
    "is_expired" boolean DEFAULT false,
    "is_near_expiry" boolean DEFAULT false,
    "near_expiry_threshold_days" integer DEFAULT 90,
    "purchase_price" numeric(10,2),
    "supplier_name" "text",
    "supplier_invoice_number" "text",
    "received_date" "date",
    "storage_location" "text",
    "requires_refrigeration" boolean DEFAULT false,
    "current_temperature" numeric(5,2),
    "last_temperature_check" timestamp with time zone,
    "quality_check_status" "text" DEFAULT 'pending'::"text",
    "quality_check_date" "date",
    "quality_check_by" "uuid",
    "recall_status" "text" DEFAULT 'none'::"text",
    "recall_notice" "text",
    "recall_date" "date",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "health_pharmacy_inventory_quality_check_status_check" CHECK (("quality_check_status" = ANY (ARRAY['pending'::"text", 'passed'::"text", 'failed'::"text", 'quarantine'::"text"]))),
    CONSTRAINT "health_pharmacy_inventory_recall_status_check" CHECK (("recall_status" = ANY (ARRAY['none'::"text", 'voluntary'::"text", 'mandatory'::"text", 'completed'::"text"]))),
    CONSTRAINT "valid_expiry" CHECK ((("expiry_date" > "manufacturing_date") OR ("manufacturing_date" IS NULL))),
    CONSTRAINT "valid_price" CHECK (("price" >= (0)::numeric)),
    CONSTRAINT "valid_quantity" CHECK (("quantity_in_stock" >= 0))
);


ALTER TABLE "public"."health_pharmacy_inventory" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_pharmacy_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "license_number" "text" NOT NULL,
    "location_address" "jsonb",
    "is_verified" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "pharmacy_name" "text",
    "license_document_url" "text",
    "phone" "text",
    "email" "text",
    "address_line1" "text",
    "address_line2" "text",
    "city" "text",
    "state" "text",
    "postal_code" "text",
    "country" "text" DEFAULT 'EG'::"text",
    "location_lat" numeric(10,8),
    "location_lng" numeric(11,8),
    "operating_hours" "jsonb" DEFAULT '{}'::"jsonb",
    "verification_status" "text" DEFAULT 'pending'::"text",
    "delivery_available" boolean DEFAULT false,
    "delivery_fee" numeric(10,2) DEFAULT 0,
    "min_order_for_delivery" numeric(10,2) DEFAULT 0,
    "bio" "text",
    "license_expiry_date" "date",
    "can_sell_prescription_medicines" boolean DEFAULT false,
    "can_sell_controlled_medicines" boolean DEFAULT false,
    "controlled_license_number" "text",
    "controlled_license_expiry" "date",
    "compliance_notes" "text",
    "last_inspection_date" "date",
    "next_inspection_date" "date"
);


ALTER TABLE "public"."health_pharmacy_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_prescription_access_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prescription_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "access_type" "text" DEFAULT 'view'::"text" NOT NULL,
    "accessed_at" timestamp with time zone DEFAULT "now"(),
    "ip_address" "text",
    "device_info" "text"
);


ALTER TABLE "public"."health_prescription_access_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_prescription_audit_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prescription_id" "uuid" NOT NULL,
    "action_type" "text" NOT NULL,
    "action_by" "uuid" NOT NULL,
    "action_by_role" "text" NOT NULL,
    "action_details" "jsonb",
    "ip_address" "text",
    "device_info" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "health_prescription_audit_log_action_by_role_check" CHECK (("action_by_role" = ANY (ARRAY['doctor'::"text", 'patient'::"text", 'pharmacy'::"text", 'system'::"text"]))),
    CONSTRAINT "health_prescription_audit_log_action_type_check" CHECK (("action_type" = ANY (ARRAY['created'::"text", 'updated'::"text", 'filled'::"text", 'cancelled'::"text", 'viewed'::"text", 'shared'::"text"])))
);


ALTER TABLE "public"."health_prescription_audit_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_prescription_medicines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prescription_id" "uuid" NOT NULL,
    "medicine_id" "uuid",
    "medicine_name" "text" NOT NULL,
    "dosage_instructions" "text" NOT NULL,
    "duration_days" integer,
    "quantity_prescribed" integer,
    "is_dispensed" boolean DEFAULT false,
    "dispensed_at" timestamp with time zone,
    "dispensed_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."health_prescription_medicines" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_prescription_medicines_digital" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prescription_id" "uuid" NOT NULL,
    "medicine_id" "uuid" NOT NULL,
    "pharmacy_medicine_id" "uuid",
    "medicine_name" "text" NOT NULL,
    "generic_name" "text",
    "brand_name" "text",
    "dosage_form" "text",
    "strength" "text",
    "dosage_amount" "text" NOT NULL,
    "frequency" "text" NOT NULL,
    "route_of_administration" "text",
    "duration_days" integer,
    "total_quantity" integer,
    "instructions" "text",
    "warnings" "text",
    "special_instructions" "text",
    "allow_generic_substitution" boolean DEFAULT true,
    "substitution_notes" "text",
    "is_dispensed" boolean DEFAULT false,
    "dispensed_at" timestamp with time zone,
    "dispensed_by_pharmacy_id" "uuid",
    "dispensed_quantity" integer,
    "unit_price" numeric(10,2),
    "total_price" numeric(10,2),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "valid_dosage" CHECK ((("dosage_amount" IS NOT NULL) AND ("dosage_amount" <> ''::"text"))),
    CONSTRAINT "valid_frequency" CHECK ((("frequency" IS NOT NULL) AND ("frequency" <> ''::"text")))
);


ALTER TABLE "public"."health_prescription_medicines_digital" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_prescription_shares" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prescription_id" "uuid" NOT NULL,
    "shared_with_pharmacy_id" "uuid",
    "shared_with_patient" boolean DEFAULT true,
    "share_token" "text",
    "expires_at" timestamp with time zone,
    "is_active" boolean DEFAULT true,
    "accessed_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."health_prescription_shares" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_prescriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "appointment_id" "uuid" NOT NULL,
    "medicine_name" "text" NOT NULL,
    "dosage_instructions" "text" NOT NULL,
    "duration_days" integer,
    "is_dispensed" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."health_prescriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_prescriptions_digital" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "appointment_id" "uuid" NOT NULL,
    "doctor_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "pharmacy_id" "uuid",
    "prescription_number" "text" NOT NULL,
    "prescription_date" "date" DEFAULT CURRENT_DATE,
    "valid_until" "date",
    "status" "text" DEFAULT 'active'::"text",
    "diagnosis" "text",
    "symptoms" "text",
    "notes" "text",
    "follow_up_date" "date",
    "follow_up_notes" "text",
    "is_controlled_substance" boolean DEFAULT false,
    "requires_signature" boolean DEFAULT true,
    "doctor_signature_hash" "text",
    "digital_signature_url" "text",
    "times_filled" integer DEFAULT 0,
    "max_refills" integer DEFAULT 0,
    "refills_remaining" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "filled_at" timestamp with time zone,
    "cancelled_at" timestamp with time zone,
    "cancelled_reason" "text",
    CONSTRAINT "health_prescriptions_digital_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'filled'::"text", 'expired'::"text", 'cancelled'::"text"]))),
    CONSTRAINT "valid_prescription_dates" CHECK (("valid_until" >= "prescription_date"))
);


ALTER TABLE "public"."health_prescriptions_digital" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "doctor_id" "uuid",
    "patient_id" "uuid",
    "appointment_id" "uuid",
    "rating" integer NOT NULL,
    "title" "text",
    "comment" "text",
    "is_verified" boolean DEFAULT false,
    "is_approved" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "health_reviews_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."health_reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_typing_indicators" (
    "conversation_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "is_typing" boolean DEFAULT true,
    "last_activity" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."health_typing_indicators" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."healthcare_provider_profiles" (
    "id" "uuid" NOT NULL,
    "provider_type" "text" NOT NULL,
    "name" "text" NOT NULL,
    "license_number" "text",
    "address" "text",
    "city" "text",
    "phone" "text",
    "email" "text",
    "website" "text",
    "description" "text",
    "operating_hours" "jsonb",
    "emergency_services" boolean DEFAULT false,
    "rating_avg" numeric(3,2) DEFAULT 0,
    "verified" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "settings" "jsonb" DEFAULT '{}'::"jsonb",
    "customers" "jsonb" DEFAULT '[]'::"jsonb"
);


ALTER TABLE "public"."healthcare_provider_profiles" OWNER TO "postgres";


COMMENT ON TABLE "public"."healthcare_provider_profiles" IS 'Profiles for hospitals, clinics, and medical centers';



CREATE TABLE IF NOT EXISTS "public"."service_appointments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "appointment_type" "text" NOT NULL,
    "provider_id" "uuid" NOT NULL,
    "provider_type" "text" NOT NULL,
    "client_id" "uuid",
    "staff_id" "uuid",
    "service_id" "uuid",
    "scheduled_time" timestamp with time zone,
    "duration_minutes" integer,
    "status" "text" DEFAULT 'pending'::"text",
    "notes" "text",
    "prescription_url" "text",
    "total_price" numeric(10,2),
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."service_appointments" OWNER TO "postgres";


COMMENT ON TABLE "public"."service_appointments" IS 'Unified booking system for all service types';



CREATE OR REPLACE VIEW "public"."healthcare_provider_stats" AS
 SELECT "hp"."id",
    "hp"."name",
    "hp"."provider_type",
    "count"(DISTINCT "sa"."id") AS "total_appointments",
    COALESCE("sum"("sa"."total_price"), (0)::numeric) AS "total_revenue",
    "count"(
        CASE
            WHEN ("sa"."status" = 'confirmed'::"text") THEN 1
            ELSE NULL::integer
        END) AS "upcoming_appointments",
    "count"(
        CASE
            WHEN ("sa"."status" = 'completed'::"text") THEN 1
            ELSE NULL::integer
        END) AS "completed_appointments"
   FROM ("public"."healthcare_provider_profiles" "hp"
     LEFT JOIN "public"."service_appointments" "sa" ON (("hp"."id" = "sa"."provider_id")))
  GROUP BY "hp"."id", "hp"."name", "hp"."provider_type";


ALTER VIEW "public"."healthcare_provider_stats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."hospitals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_user_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "description" "text",
    "avatar_url" "text",
    "cover_image_url" "text",
    "hospital_type" "public"."hospital_type" NOT NULL,
    "is_verified" boolean DEFAULT false,
    "is_active" boolean DEFAULT true,
    "phone" "text",
    "email" "text",
    "website_url" "text",
    "address" "text",
    "city" "text",
    "state" "text",
    "country" "text" DEFAULT 'EG'::"text",
    "latitude" numeric(10,8),
    "longitude" numeric(11,8),
    "opening_hours" "jsonb" DEFAULT '{}'::"jsonb",
    "specialties" "text"[] DEFAULT '{}'::"text"[],
    "features" "text"[] DEFAULT '{}'::"text"[],
    "bed_capacity" integer,
    "emergency_services" boolean DEFAULT false,
    "average_rating" numeric(3,2) DEFAULT 0.00,
    "total_reviews" integer DEFAULT 0,
    "total_services" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."hospitals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."idempotency_keys" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "key" "text" NOT NULL,
    "response" "jsonb" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."idempotency_keys" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."location_history" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "latitude" double precision NOT NULL,
    "longitude" double precision NOT NULL,
    "accuracy" double precision,
    "altitude" double precision,
    "heading" double precision,
    "speed" double precision,
    "location_type" "text" DEFAULT 'gps'::"text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."location_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."marketplace_purchases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "buyer_id" "uuid" NOT NULL,
    "template_id" "uuid" NOT NULL,
    "amount_paid" numeric(10,2) NOT NULL,
    "currency" "text" DEFAULT 'USD'::"text",
    "payment_status" "text" DEFAULT 'pending'::"text",
    "transaction_id" "uuid",
    "downloaded" boolean DEFAULT false,
    "license_key" "text" DEFAULT ('LIC-'::"text" || "encode"("extensions"."gen_random_bytes"(8), 'hex'::"text")),
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "marketplace_purchases_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['pending'::"text", 'completed'::"text", 'failed'::"text", 'refunded'::"text"])))
);


ALTER TABLE "public"."marketplace_purchases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."medical_staff" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "provider_id" "uuid",
    "user_id" "uuid",
    "full_name" "text" NOT NULL,
    "specialization" "text",
    "title" "text",
    "qualifications" "text"[],
    "experience_years" integer,
    "consultation_fee" numeric(10,2),
    "is_available" boolean DEFAULT true,
    "schedule" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."medical_staff" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."medicine_sales_analytics" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "medicine_id" "uuid" NOT NULL,
    "pharmacy_id" "uuid",
    "sale_date" "date" NOT NULL,
    "quantity_sold" integer DEFAULT 0,
    "total_revenue" numeric(12,2) DEFAULT 0,
    "prescription_orders" integer DEFAULT 0,
    "direct_orders" integer DEFAULT 0,
    "doctor_commissions_paid" numeric(12,2) DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."medicine_sales_analytics" OWNER TO "postgres";


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
    CONSTRAINT "messages_message_type_check" CHECK (("message_type" = ANY (ARRAY['text'::"text", 'image'::"text", 'file'::"text", 'deal_proposal'::"text"])))
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."middle_man_deals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "middle_man_id" "uuid" NOT NULL,
    "product_asin" "text" NOT NULL,
    "product_id" "uuid",
    "commission_rate" numeric(5,2) DEFAULT 5.00,
    "margin_amount" numeric(10,2) DEFAULT 0,
    "unique_slug" "text" NOT NULL,
    "clicks" integer DEFAULT 0,
    "conversions" integer DEFAULT 0,
    "total_revenue" numeric(10,2) DEFAULT 0,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "seller_id" "uuid",
    "expires_at" timestamp with time zone,
    "approval_status" "text" DEFAULT 'auto_approved'::"text",
    "promo_tags" "text"[] DEFAULT '{}'::"text"[],
    "last_price_synced_at" timestamp with time zone,
    "max_margin_allowed" numeric DEFAULT 50,
    CONSTRAINT "middle_man_deals_approval_status_check" CHECK (("approval_status" = ANY (ARRAY['auto_approved'::"text", 'pending_approval'::"text", 'rejected'::"text", 'archived'::"text"])))
);


ALTER TABLE "public"."middle_man_deals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."middle_men" (
    "user_id" "uuid" NOT NULL,
    "commission_rate" numeric(5,2) DEFAULT 5.00,
    "total_earnings" numeric(10,2) DEFAULT 0,
    "pending_earnings" numeric(10,2) DEFAULT 0,
    "is_verified" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."middle_men" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."middleman_connections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "middleman_id" "uuid" NOT NULL,
    "provider_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "middleman_connections_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'active'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."middleman_connections" OWNER TO "postgres";


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
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "settings" "jsonb" DEFAULT '{"specialties": [], "notifications": true, "commission_rate": 0.05}'::"jsonb",
    "customers" "jsonb" DEFAULT '[]'::"jsonb",
    "verification_status" "text" DEFAULT 'pending'::"text",
    "tier" "text" DEFAULT 'tier_75k'::"text",
    CONSTRAINT "middleman_profiles_tier_check" CHECK (("tier" = ANY (ARRAY['tier_75k'::"text", 'tier_150k'::"text", 'tier_250k'::"text", 'tier_500k'::"text", 'tier_1m'::"text", 'tier_2m'::"text"])))
);


ALTER TABLE "public"."middleman_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."middleman_seller_links" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "middleman_id" "uuid",
    "seller_id" "uuid",
    "seller_shop_id" "uuid",
    "commission_rate" numeric(5,2) DEFAULT 5.00,
    "status" "text" DEFAULT 'pending'::"text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."middleman_seller_links" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."middleman_store_configs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "middleman_id" "uuid" NOT NULL,
    "store_name" "text" NOT NULL,
    "store_slug" "text" NOT NULL,
    "tagline" "text",
    "logo_url" "text",
    "favicon_url" "text",
    "primary_color" "text" DEFAULT '#0F172A'::"text",
    "secondary_color" "text" DEFAULT '#3B82F6'::"text",
    "accent_color" "text" DEFAULT '#10B981'::"text",
    "template_id" "text" DEFAULT 'modern'::"text" NOT NULL,
    "layout_style" "public"."store_layout_style" DEFAULT 'grid'::"public"."store_layout_style",
    "theme_mode" "public"."store_theme_mode" DEFAULT 'light'::"public"."store_theme_mode",
    "font_family" "text" DEFAULT 'Inter'::"text",
    "font_heading" "text" DEFAULT 'Poppins'::"text",
    "hero_image_url" "text",
    "hero_title" "text",
    "hero_subtitle" "text",
    "about_section" "text",
    "currency_code" "text" DEFAULT 'USD'::"text",
    "language_code" "text" DEFAULT 'en'::"text",
    "is_published" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."middleman_store_configs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_settings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "notifications_enabled" boolean DEFAULT true,
    "email_notifications" boolean DEFAULT true,
    "push_notifications" boolean DEFAULT true,
    "order_notifications" boolean DEFAULT true,
    "message_notifications" boolean DEFAULT true,
    "deal_notifications" boolean DEFAULT true,
    "product_notifications" boolean DEFAULT true,
    "system_notifications" boolean DEFAULT true,
    "payment_notifications" boolean DEFAULT true,
    "shipping_notifications" boolean DEFAULT true,
    "review_notifications" boolean DEFAULT true,
    "notify_low_priority" boolean DEFAULT true,
    "notify_medium_priority" boolean DEFAULT true,
    "notify_high_priority" boolean DEFAULT true,
    "notify_urgent_priority" boolean DEFAULT true,
    "quiet_hours_enabled" boolean DEFAULT false,
    "quiet_hours_start" time without time zone,
    "quiet_hours_end" time without time zone,
    "quiet_hours_timezone" "text" DEFAULT 'UTC'::"text",
    "batch_notifications" boolean DEFAULT false,
    "batch_frequency" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "notification_settings_batch_frequency_check" CHECK (("batch_frequency" = ANY (ARRAY['instant'::"text", 'hourly'::"text", 'daily'::"text"])))
);


ALTER TABLE "public"."notification_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "type" "public"."notification_type" NOT NULL,
    "priority" "public"."notification_priority" DEFAULT 'medium'::"public"."notification_priority",
    "title_template" "text" NOT NULL,
    "message_template" "text" NOT NULL,
    "action_url_template" "text",
    "enabled" boolean DEFAULT true,
    "variables" "jsonb" DEFAULT '[]'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid"
);


ALTER TABLE "public"."notification_templates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "message" "text" NOT NULL,
    "type" "public"."notification_type" NOT NULL,
    "priority" "public"."notification_priority" DEFAULT 'medium'::"public"."notification_priority",
    "is_read" boolean DEFAULT false,
    "read_at" timestamp with time zone,
    "reference_type" "text",
    "reference_id" "uuid",
    "action_url" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "expires_at" timestamp with time zone,
    CONSTRAINT "valid_reference" CHECK (((("reference_type" IS NULL) AND ("reference_id" IS NULL)) OR (("reference_type" IS NOT NULL) AND ("reference_id" IS NOT NULL))))
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
    "production_status" "public"."factory_order_status" DEFAULT 'pending'::"public"."factory_order_status",
    "production_started_at" timestamp without time zone,
    "production_completed_at" timestamp without time zone,
    "quality_check_passed" boolean,
    "middle_man_id" "uuid",
    "cod_verification_required" boolean DEFAULT false,
    "cod_verified" boolean DEFAULT false,
    "cod_verified_at" timestamp with time zone,
    "cod_collection_amount" numeric(10,2),
    "cod_collected_by" "uuid",
    "cod_collection_status" "text" DEFAULT 'pending'::"text",
    "cod_deposit_deadline" timestamp with time zone,
    CONSTRAINT "orders_cod_collection_status_check" CHECK (("cod_collection_status" = ANY (ARRAY['pending'::"text", 'collected'::"text", 'failed'::"text", 'refunded'::"text"]))),
    CONSTRAINT "orders_delivery_status_check" CHECK (("delivery_status" = ANY (ARRAY['pending'::"text", 'assigned'::"text", 'picked_up'::"text", 'in_transit'::"text", 'delivered'::"text", 'failed'::"text"]))),
    CONSTRAINT "orders_payment_method_check" CHECK (("payment_method" = ANY (ARRAY['cash'::"text", 'card'::"text", 'bank_transfer'::"text", 'digital_wallet'::"text", 'cod'::"text"]))),
    CONSTRAINT "orders_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['pending'::"text", 'completed'::"text", 'failed'::"text", 'refunded'::"text"]))),
    CONSTRAINT "orders_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'confirmed'::"text", 'processing'::"text", 'shipped'::"text", 'out_for_delivery'::"text", 'delivered'::"text", 'cancelled'::"text", 'refunded'::"text"]))),
    CONSTRAINT "valid_subtotal" CHECK (("subtotal" >= (0)::numeric)),
    CONSTRAINT "valid_total" CHECK (("total" >= (0)::numeric))
);


ALTER TABLE "public"."orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patient_medicine_preferences" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "medicine_id" "uuid",
    "preference_type" character varying(20) DEFAULT 'favorite'::character varying,
    "is_auto_refill" boolean DEFAULT false,
    "refill_frequency_days" integer,
    "notes" "text",
    "preferred_pharmacy_id" "uuid",
    "preferred_brand" character varying(255),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."patient_medicine_preferences" OWNER TO "postgres";


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


CREATE TABLE IF NOT EXISTS "public"."payment_splits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "payment_transaction_id" "uuid",
    "recipient_id" "uuid" NOT NULL,
    "recipient_type" "text" NOT NULL,
    "amount" numeric(15,2) NOT NULL,
    "percentage" numeric(5,2),
    "split_type" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "held_until" timestamp with time zone,
    "released_at" timestamp with time zone,
    "paid_at" timestamp with time zone,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "payment_splits_amount_check" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "payment_splits_percentage_check" CHECK ((("percentage" >= (0)::numeric) AND ("percentage" <= (100)::numeric))),
    CONSTRAINT "payment_splits_recipient_type_check" CHECK (("recipient_type" = ANY (ARRAY['seller'::"text", 'factory'::"text", 'middleman'::"text", 'platform'::"text", 'freelancer'::"text", 'doctor'::"text", 'pharmacy'::"text", 'service_provider'::"text", 'delivery'::"text"]))),
    CONSTRAINT "payment_splits_split_type_check" CHECK (("split_type" = ANY (ARRAY['revenue'::"text", 'commission'::"text", 'fee'::"text", 'tax'::"text", 'delivery_fee'::"text"]))),
    CONSTRAINT "payment_splits_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'held'::"text", 'released'::"text", 'paid'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."payment_splits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payment_transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid",
    "user_id" "uuid" NOT NULL,
    "wallet_id" "uuid",
    "payment_gateway" "text" DEFAULT 'fawry'::"text" NOT NULL,
    "gateway_transaction_id" "text",
    "amount" numeric(15,2) NOT NULL,
    "currency" "text" DEFAULT 'EGP'::"text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "payment_method" "text",
    "gateway_response" "jsonb",
    "failure_reason" "text",
    "processed_at" timestamp with time zone,
    "refunded_at" timestamp with time zone,
    "refund_amount" numeric(15,2),
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "idempotency_key" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "payment_transactions_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "payment_transactions_payment_gateway_check" CHECK (("payment_gateway" = ANY (ARRAY['fawry'::"text", 'stripe'::"text", 'cod'::"text", 'wallet'::"text", 'bank_transfer'::"text"]))),
    CONSTRAINT "payment_transactions_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'success'::"text", 'failed'::"text", 'cancelled'::"text", 'refunded'::"text", 'reversed'::"text"])))
);


ALTER TABLE "public"."payment_transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payment_webhook_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "payment_gateway" "text" DEFAULT 'fawry'::"text" NOT NULL,
    "event_type" "text" NOT NULL,
    "gateway_transaction_id" "text",
    "order_id" "uuid",
    "amount" numeric(15,2),
    "raw_payload" "jsonb" NOT NULL,
    "signature_verified" boolean DEFAULT false,
    "processed" boolean DEFAULT false,
    "processed_at" timestamp with time zone,
    "error_message" "text",
    "retry_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."payment_webhook_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payout_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "amount" numeric(10,2) NOT NULL,
    "fee_amount" numeric(10,2) DEFAULT 0,
    "net_amount" numeric(10,2) NOT NULL,
    "status" "text" DEFAULT 'pending'::"text",
    "payout_method" "text",
    "payout_details" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "processed_at" timestamp with time zone,
    "rejection_reason" "text",
    CONSTRAINT "payout_requests_amount_check" CHECK (("amount" >= (50)::numeric)),
    CONSTRAINT "payout_requests_payout_method_check" CHECK (("payout_method" = ANY (ARRAY['bank_transfer'::"text", 'vodafone_cash'::"text", 'orange_cash'::"text", 'etisalat_cash'::"text"]))),
    CONSTRAINT "payout_requests_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'completed'::"text", 'failed'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."payout_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payouts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "wallet_id" "uuid" NOT NULL,
    "amount" numeric(15,2) NOT NULL,
    "fee" numeric(15,2) DEFAULT 0 NOT NULL,
    "net_amount" numeric(15,2) NOT NULL,
    "currency" "text" DEFAULT 'EGP'::"text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "payout_method" "text" NOT NULL,
    "bank_account_name" "text",
    "bank_account_number" "text",
    "bank_name" "text",
    "bank_code" "text",
    "fawry_reference" "text",
    "processed_by" "uuid",
    "processed_at" timestamp with time zone,
    "rejected_reason" "text",
    "failure_reason" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "idempotency_key" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "payouts_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "payouts_fee_check" CHECK (("fee" >= (0)::numeric)),
    CONSTRAINT "payouts_net_amount_check" CHECK (("net_amount" >= (0)::numeric)),
    CONSTRAINT "payouts_payout_method_check" CHECK (("payout_method" = ANY (ARRAY['bank_transfer'::"text", 'fawry_cash'::"text", 'wallet'::"text", 'cod'::"text"]))),
    CONSTRAINT "payouts_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'paid'::"text", 'failed'::"text", 'cancelled'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."payouts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pharmacy_activity_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pharmacy_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "action" "text" NOT NULL,
    "entity_type" "text",
    "entity_id" "uuid",
    "old_data" "jsonb",
    "new_data" "jsonb",
    "device_info" "text",
    "location_lat" double precision,
    "location_lng" double precision,
    "ip_address" "text",
    "is_success" boolean DEFAULT true,
    "error_message" "text",
    "duration_ms" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."pharmacy_activity_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pharmacy_daily_reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pharmacy_id" "uuid" NOT NULL,
    "report_date" "date" NOT NULL,
    "total_scans" integer DEFAULT 0,
    "total_sales" integer DEFAULT 0,
    "total_revenue" numeric(10,2) DEFAULT 0,
    "medicines_added" integer DEFAULT 0,
    "medicines_expired" integer DEFAULT 0,
    "low_stock_count" integer DEFAULT 0,
    "generated_at" timestamp with time zone DEFAULT "now"(),
    "report_data" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "public"."pharmacy_daily_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pharmacy_details" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "provider_id" "uuid",
    "license_number" "text",
    "pharmacist_name" "text",
    "delivery_available" boolean DEFAULT true,
    "prescription_required" boolean DEFAULT true,
    "insurance_accepted" "text"[],
    "operating_24_7" boolean DEFAULT false
);


ALTER TABLE "public"."pharmacy_details" OWNER TO "postgres";


COMMENT ON TABLE "public"."pharmacy_details" IS 'Extended details for pharmacy operations';



CREATE TABLE IF NOT EXISTS "public"."pharmacy_medicine_inventory" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pharmacy_id" "uuid" NOT NULL,
    "medicine_id" "uuid",
    "product_id" "uuid",
    "qr_code" "text",
    "batch_number" "text" NOT NULL,
    "expiry_date" "date" NOT NULL,
    "manufacturing_date" "date",
    "price" numeric(10,2) NOT NULL,
    "currency" "text" DEFAULT 'EGP'::"text",
    "quantity_in_stock" integer DEFAULT 0,
    "quantity_reserved" integer DEFAULT 0,
    "quantity_available" integer GENERATED ALWAYS AS (("quantity_in_stock" - "quantity_reserved")) STORED,
    "is_available" boolean DEFAULT true,
    "is_expired" boolean DEFAULT false,
    "is_near_expiry" boolean DEFAULT false,
    "near_expiry_threshold_days" integer DEFAULT 90,
    "purchase_price" numeric(10,2),
    "supplier_name" "text",
    "supplier_invoice_number" "text",
    "received_date" "date",
    "storage_location" "text",
    "requires_refrigeration" boolean DEFAULT false,
    "current_temperature" double precision,
    "last_temperature_check" timestamp with time zone,
    "quality_check_status" "text" DEFAULT 'pending'::"text",
    "quality_check_date" "date",
    "quality_check_by" "uuid",
    "recall_status" "text" DEFAULT 'none'::"text",
    "recall_notice" "text",
    "recall_date" "date",
    "notes" "text",
    "last_scanned_at" timestamp with time zone,
    "scanned_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "pharmacy_medicine_inventory_quality_check_status_check" CHECK (("quality_check_status" = ANY (ARRAY['pending'::"text", 'passed'::"text", 'failed'::"text", 'quarantine'::"text"]))),
    CONSTRAINT "pharmacy_medicine_inventory_recall_status_check" CHECK (("recall_status" = ANY (ARRAY['none'::"text", 'voluntary'::"text", 'mandatory'::"text", 'completed'::"text"]))),
    CONSTRAINT "valid_expiry" CHECK ((("expiry_date" > "manufacturing_date") OR ("manufacturing_date" IS NULL))),
    CONSTRAINT "valid_price" CHECK (("price" >= (0)::numeric)),
    CONSTRAINT "valid_quantity" CHECK (("quantity_in_stock" >= 0))
);


ALTER TABLE "public"."pharmacy_medicine_inventory" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pharmacy_products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pharmacy_id" "uuid",
    "name" "text" NOT NULL,
    "generic_name" "text",
    "category" "text",
    "price" numeric(10,2),
    "stock_quantity" integer,
    "requires_prescription" boolean DEFAULT true,
    "description" "text",
    "image_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."pharmacy_products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pharmacy_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "pharmacy_name" "text" NOT NULL,
    "license_number" "text" NOT NULL,
    "license_document_url" "text",
    "license_expiry_date" "date",
    "phone" "text" NOT NULL,
    "email" "text" NOT NULL,
    "address_line1" "text" NOT NULL,
    "address_line2" "text",
    "city" "text" NOT NULL,
    "state" "text",
    "postal_code" "text",
    "country" "text" DEFAULT 'EG'::"text",
    "location_lat" double precision,
    "location_lng" double precision,
    "operating_hours" "jsonb" DEFAULT '{}'::"jsonb",
    "is_verified" boolean DEFAULT false,
    "verification_status" "text" DEFAULT 'pending'::"text",
    "delivery_available" boolean DEFAULT false,
    "delivery_fee" numeric(10,2) DEFAULT 0,
    "min_order_for_delivery" numeric(10,2) DEFAULT 0,
    "can_sell_prescription_medicines" boolean DEFAULT false,
    "can_sell_controlled_medicines" boolean DEFAULT false,
    "controlled_license_number" "text",
    "controlled_license_expiry" "date",
    "bio" "text",
    "compliance_notes" "text",
    "last_inspection_date" "date",
    "next_inspection_date" "date",
    "qr_code_prefix" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "website_url" "text",
    CONSTRAINT "pharmacy_profiles_verification_status_check" CHECK (("verification_status" = ANY (ARRAY['pending'::"text", 'verified'::"text", 'rejected'::"text", 'suspended'::"text"])))
);


ALTER TABLE "public"."pharmacy_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pharmacy_qr_scan_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pharmacy_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "qr_code" "text" NOT NULL,
    "inventory_id" "uuid",
    "medicine_id" "uuid",
    "product_id" "uuid",
    "scan_type" "text",
    "scan_result" "text",
    "device_info" "text",
    "location_lat" double precision,
    "location_lng" double precision,
    "ip_address" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "pharmacy_qr_scan_logs_scan_result_check" CHECK (("scan_result" = ANY (ARRAY['success'::"text", 'not_found'::"text", 'expired'::"text", 'error'::"text"]))),
    CONSTRAINT "pharmacy_qr_scan_logs_scan_type_check" CHECK (("scan_type" = ANY (ARRAY['add'::"text", 'view'::"text", 'update'::"text", 'sell'::"text", 'return'::"text", 'audit'::"text"])))
);


ALTER TABLE "public"."pharmacy_qr_scan_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pharmacy_stock_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pharmacy_id" "uuid" NOT NULL,
    "inventory_id" "uuid" NOT NULL,
    "medicine_id" "uuid",
    "product_id" "uuid",
    "movement_type" "text" NOT NULL,
    "quantity_change" integer NOT NULL,
    "quantity_before" integer NOT NULL,
    "quantity_after" integer NOT NULL,
    "reference_id" "uuid",
    "reference_type" "text",
    "performed_by" "uuid",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "pharmacy_stock_movements_movement_type_check" CHECK (("movement_type" = ANY (ARRAY['receive'::"text", 'sell'::"text", 'return'::"text", 'adjustment'::"text", 'expiry'::"text", 'damage'::"text", 'recall'::"text", 'transfer'::"text"])))
);


ALTER TABLE "public"."pharmacy_stock_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."platform_reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "reporter_id" "uuid",
    "reported_type" "text" NOT NULL,
    "reported_id" "uuid" NOT NULL,
    "reason" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text",
    "admin_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "platform_reports_reported_type_check" CHECK (("reported_type" = ANY (ARRAY['user'::"text", 'product'::"text", 'listing'::"text", 'message'::"text", 'review'::"text", 'order'::"text"]))),
    CONSTRAINT "platform_reports_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'reviewing'::"text", 'resolved'::"text", 'dismissed'::"text"])))
);


ALTER TABLE "public"."platform_reports" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."platform_revenue" AS
 SELECT "date_trunc"('day'::"text", "created_at") AS "day",
    "sum"("amount") AS "total_fees"
   FROM "public"."payment_splits"
  WHERE ("recipient_type" = 'platform'::"text")
  GROUP BY ("date_trunc"('day'::"text", "created_at"));


ALTER VIEW "public"."platform_revenue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."platform_settings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "key" "text" NOT NULL,
    "value" "jsonb" NOT NULL,
    "description" "text",
    "updated_by" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."platform_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."post_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "content" "text" NOT NULL,
    "parent_comment_id" "uuid",
    "likes_count" integer DEFAULT 0,
    "is_deleted" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."post_comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."post_likes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."post_likes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."posts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "seller_id" "uuid",
    "product_id" "uuid",
    "content" "text" NOT NULL,
    "media_urls" "jsonb" DEFAULT '[]'::"jsonb",
    "post_type" "text" DEFAULT 'announcement'::"text",
    "likes_count" integer DEFAULT 0,
    "comments_count" integer DEFAULT 0,
    "shares_count" integer DEFAULT 0,
    "is_deleted" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "posts_post_type_check" CHECK (("post_type" = ANY (ARRAY['announcement'::"text", 'product'::"text", 'update'::"text", 'promotion'::"text"])))
);


ALTER TABLE "public"."posts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."prescription_fulfillment" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prescription_id" "uuid" NOT NULL,
    "prescription_medicine_id" "uuid",
    "medicine_order_id" "uuid",
    "medicine_order_item_id" "uuid",
    "status" character varying(20) DEFAULT 'pending'::character varying,
    "pharmacy_id" "uuid",
    "doctor_commission_amount" numeric(10,2) DEFAULT 0,
    "commission_paid" boolean DEFAULT false,
    "commission_paid_at" timestamp with time zone,
    "fulfilled_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "valid_status" CHECK ((("status")::"text" = ANY ((ARRAY['pending'::character varying, 'fulfilled'::character varying, 'partially_fulfilled'::character varying, 'cancelled'::character varying])::"text"[])))
);


ALTER TABLE "public"."prescription_fulfillment" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_admin" boolean DEFAULT false,
    "accountType" "text"
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."provider_availability" (
    "provider_id" "uuid" NOT NULL,
    "day_of_week" smallint NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "is_available" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "provider_availability_day_of_week_check" CHECK ((("day_of_week" >= 0) AND ("day_of_week" <= 6)))
);


ALTER TABLE "public"."provider_availability" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."provider_time_off" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "provider_id" "uuid" NOT NULL,
    "start_date" timestamp with time zone NOT NULL,
    "end_date" timestamp with time zone NOT NULL,
    "reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."provider_time_off" OWNER TO "postgres";


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


CREATE OR REPLACE VIEW "public"."sales" AS
 SELECT "oi"."id",
    "o"."seller_id",
    "o"."user_id" AS "customer_id",
    "oi"."product_id",
    "oi"."quantity",
    "oi"."unit_price",
    "oi"."total_price",
    0 AS "discount",
    "o"."created_at" AS "sale_date",
    "o"."created_at",
    "o"."updated_at"
   FROM ("public"."order_items" "oi"
     JOIN "public"."orders" "o" ON (("oi"."order_id" = "o"."id")))
  WHERE ("o"."payment_status" = 'completed'::"text");


ALTER VIEW "public"."sales" OWNER TO "postgres";


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


CREATE TABLE IF NOT EXISTS "public"."sellers_tmp_test" (
    "id" "uuid" NOT NULL
);


ALTER TABLE "public"."sellers_tmp_test" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."services" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "provider_id" "uuid" NOT NULL,
    "provider_type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "category" "text" NOT NULL,
    "subcategory" "text",
    "price" numeric(10,2) NOT NULL,
    "price_type" "text" DEFAULT 'fixed'::"text",
    "duration_minutes" integer,
    "is_available" boolean DEFAULT true,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "services_price_type_check" CHECK (("price_type" = ANY (ARRAY['fixed'::"text", 'hourly'::"text", 'per_session'::"text"]))),
    CONSTRAINT "services_provider_type_check" CHECK (("provider_type" = ANY (ARRAY['freelancer'::"text", 'doctor'::"text", 'pharmacy'::"text"])))
);


ALTER TABLE "public"."services" OWNER TO "postgres";


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


CREATE TABLE IF NOT EXISTS "public"."shop_products" (
    "shop_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "position" integer DEFAULT 0,
    "is_featured" boolean DEFAULT false,
    "custom_title" "text",
    "custom_description" "text",
    "middleman_commission" numeric(5,2)
);


ALTER TABLE "public"."shop_products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shop_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "shop_type" "text" NOT NULL,
    "preview_url" "text",
    "config_schema" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "status" "text" DEFAULT 'active'::"text",
    "created_by" "uuid",
    CONSTRAINT "shop_templates_shop_type_check" CHECK (("shop_type" = ANY (ARRAY['doctor'::"text", 'seller'::"text", 'factory'::"text", 'middleman'::"text"]))),
    CONSTRAINT "shop_templates_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'active'::"text", 'archived'::"text"])))
);


ALTER TABLE "public"."shop_templates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shops" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "slug" "text" NOT NULL,
    "shop_type" "text" NOT NULL,
    "template_id" "uuid",
    "status" "text" DEFAULT 'draft'::"text",
    "settings" "jsonb" DEFAULT '{}'::"jsonb",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "customers" "jsonb" DEFAULT '[]'::"jsonb",
    "name" "text",
    CONSTRAINT "shops_shop_type_check" CHECK (("shop_type" = ANY (ARRAY['doctor'::"text", 'seller'::"text", 'factory'::"text", 'middleman'::"text"]))),
    CONSTRAINT "shops_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'active'::"text", 'suspended'::"text"])))
);


ALTER TABLE "public"."shops" OWNER TO "postgres";


COMMENT ON COLUMN "public"."shops"."name" IS 'Display name for the shop shown in dashboards and UI';



CREATE TABLE IF NOT EXISTS "public"."site_catalog" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "deal_id" "uuid",
    "display_price" numeric(10,2) NOT NULL,
    "max_display_qty" integer DEFAULT 100,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "site_catalog_display_price_check" CHECK (("display_price" >= (0)::numeric)),
    CONSTRAINT "site_catalog_max_display_qty_check" CHECK (("max_display_qty" > 0))
);


ALTER TABLE "public"."site_catalog" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_configs" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "middleman_id" "uuid" NOT NULL,
    "template_id" "uuid" NOT NULL,
    "slug" "text" NOT NULL,
    "design_json" "jsonb" DEFAULT '{}'::"jsonb",
    "settings_json" "jsonb" DEFAULT '{}'::"jsonb",
    "content_json" "jsonb" DEFAULT '{}'::"jsonb",
    "is_active" boolean DEFAULT true,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."store_configs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_customizations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "store_id" "uuid",
    "template_id" character varying(50) NOT NULL,
    "layout_mode" character varying(20) DEFAULT 'grid'::character varying,
    "products_per_page" integer DEFAULT 12,
    "show_sidebar" boolean DEFAULT true,
    "primary_color" character varying(7) DEFAULT '#3B82F6'::character varying,
    "secondary_color" character varying(7) DEFAULT '#1E40AF'::character varying,
    "font_family" character varying(50) DEFAULT 'inter'::character varying,
    "hero_banner_url" "text",
    "hero_title" "text",
    "hero_subtitle" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."store_customizations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid",
    "asin" "text" NOT NULL,
    "custom_title" "text",
    "custom_price" numeric(10,2),
    "sort_order" integer DEFAULT 0,
    "added_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."store_products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."subcategories" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "category_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "attribute_schema" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."subcategories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."svc_categories" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "icon_url" "text",
    "description" "text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "sort_order" integer DEFAULT 0
);


ALTER TABLE "public"."svc_categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."svc_listing_packages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "listing_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "price" numeric(10,2) NOT NULL,
    "delivery_days" integer,
    "revisions" integer,
    "features" "jsonb" DEFAULT '[]'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."svc_listing_packages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."svc_listings" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "provider_id" "uuid" NOT NULL,
    "category_id" "uuid",
    "subcategory_id" "uuid",
    "title" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "description" "text" NOT NULL,
    "listing_type" "text" NOT NULL,
    "price_type" "text",
    "price_min" numeric(10,2),
    "price_max" numeric(10,2),
    "currency" "text" DEFAULT 'USD'::"text",
    "packages" "jsonb",
    "delivery_days" integer,
    "duration_minutes" integer,
    "requirements_prompt" "text",
    "images" "jsonb" DEFAULT '[]'::"jsonb",
    "video_url" "text",
    "status" "text" DEFAULT 'draft'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "is_active" boolean DEFAULT true,
    "rating" numeric(3,2) DEFAULT 0.00,
    "review_count" integer DEFAULT 0,
    "reviews_count" integer DEFAULT 0,
    "location_type" "text" DEFAULT 'online'::"text",
    "address_line1" "text",
    "address_line2" "text",
    "city" "text",
    "latitude" numeric(10,8),
    "longitude" numeric(11,8),
    "search_vector" "tsvector",
    CONSTRAINT "svc_listings_listing_type_check" CHECK (("listing_type" = ANY (ARRAY['service_package'::"text", 'appointment'::"text", 'job_posting'::"text", 'quote_request'::"text"]))),
    CONSTRAINT "svc_listings_price_type_check" CHECK (("price_type" = ANY (ARRAY['fixed'::"text", 'hourly'::"text", 'range'::"text", 'negotiable'::"text", 'free'::"text"]))),
    CONSTRAINT "svc_listings_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'active'::"text", 'paused'::"text", 'filled'::"text", 'closed'::"text"])))
);


ALTER TABLE "public"."svc_listings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."svc_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid",
    "sender_id" "uuid",
    "content" "text",
    "message_type" "text" DEFAULT 'text'::"text",
    "attachment_url" "text",
    "attachment_name" "text",
    "attachment_size" bigint,
    "is_read" boolean DEFAULT false,
    "read_at" timestamp with time zone,
    "is_deleted" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "svc_messages_message_type_check" CHECK (("message_type" = ANY (ARRAY['text'::"text", 'image'::"text", 'file'::"text", 'voice'::"text"])))
);


ALTER TABLE "public"."svc_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."svc_orders" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "listing_id" "uuid" NOT NULL,
    "provider_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "order_type" "text" NOT NULL,
    "agreed_price" numeric(10,2),
    "currency" "text" DEFAULT 'USD'::"text",
    "payment_status" "text" DEFAULT 'pending'::"text",
    "status" "text" DEFAULT 'pending'::"text",
    "client_message" "text",
    "client_files" "jsonb" DEFAULT '[]'::"jsonb",
    "provider_delivery_url" "text",
    "provider_message" "text",
    "ordered_at" timestamp with time zone DEFAULT "now"(),
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "scheduled_start" timestamp with time zone,
    "scheduled_end" timestamp with time zone,
    "duration_minutes" integer,
    CONSTRAINT "svc_orders_order_type_check" CHECK (("order_type" = ANY (ARRAY['purchase'::"text", 'booking'::"text", 'application'::"text", 'inquiry'::"text"]))),
    CONSTRAINT "svc_orders_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['pending'::"text", 'paid'::"text", 'refunded'::"text", 'failed'::"text"]))),
    CONSTRAINT "svc_orders_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'requirements_pending'::"text", 'in_progress'::"text", 'delivered'::"text", 'completed'::"text", 'cancelled'::"text", 'disputed'::"text", 'interview_scheduled'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."svc_orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."svc_portfolio" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "provider_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "category_tag" "text",
    "image_url" "text" NOT NULL,
    "project_url" "text",
    "completion_date" "date",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."svc_portfolio" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."svc_providers" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "provider_name" "text" NOT NULL,
    "provider_type" "text" NOT NULL,
    "tagline" "text",
    "registration_number" "text",
    "tax_id" "text",
    "is_verified" boolean DEFAULT false,
    "verification_documents" "jsonb" DEFAULT '[]'::"jsonb",
    "description" "text",
    "website_url" "text",
    "phone_public" "text",
    "email_public" "text",
    "location_country" "text",
    "location_city" "text",
    "full_address" "text",
    "geo_coordinates" "jsonb",
    "specialties" "text"[],
    "languages" "text"[],
    "year_established" integer,
    "team_size_range" "text",
    "logo_url" "text",
    "cover_image_url" "text",
    "gallery_images" "jsonb" DEFAULT '[]'::"jsonb",
    "total_jobs_completed" integer DEFAULT 0,
    "total_earnings" numeric(10,2) DEFAULT 0,
    "average_rating" numeric(3,2) DEFAULT 0,
    "review_count" integer DEFAULT 0,
    "response_time_hours" integer,
    "is_available" boolean DEFAULT true,
    "status" "text" DEFAULT 'active'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "phone" character varying(20),
    "website" character varying(200),
    "email" character varying(200),
    "latitude" numeric(10,8),
    "longitude" numeric(11,8),
    "response_rate" integer DEFAULT 0,
    "vertical" "text",
    CONSTRAINT "svc_providers_provider_type_check" CHECK (("provider_type" = ANY (ARRAY['individual'::"text", 'company'::"text", 'hospital'::"text", 'institution'::"text", 'ngo'::"text"]))),
    CONSTRAINT "svc_providers_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'suspended'::"text", 'pending_review'::"text"])))
);


ALTER TABLE "public"."svc_providers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."svc_reviews" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "provider_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "rating" integer NOT NULL,
    "comment" "text",
    "response_from_provider" "text",
    "is_visible" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "helpful_votes" integer DEFAULT 0,
    "is_flagged" boolean DEFAULT false,
    CONSTRAINT "svc_reviews_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."svc_reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."svc_subcategories" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "category_id" "uuid",
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."svc_subcategories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."template_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "shop_type" "text" NOT NULL,
    "description" "text" NOT NULL,
    "reference_urls" "text"[] DEFAULT '{}'::"text"[],
    "attachments" "jsonb" DEFAULT '[]'::"jsonb",
    "status" "text" DEFAULT 'pending'::"text",
    "feedback" "text",
    "assigned_to" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "template_requests_shop_type_check" CHECK (("shop_type" = ANY (ARRAY['doctor'::"text", 'seller'::"text", 'factory'::"text", 'middleman'::"text"]))),
    CONSTRAINT "template_requests_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'in_review'::"text", 'approved'::"text", 'rejected'::"text", 'completed'::"text"])))
);


ALTER TABLE "public"."template_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "description" "text",
    "category" "text" NOT NULL,
    "thumbnail_url" "text",
    "preview_url" "text",
    "is_active" boolean DEFAULT true,
    "is_premium" boolean DEFAULT false,
    "features" "jsonb" DEFAULT '[]'::"jsonb",
    "color_scheme" "jsonb",
    "layout_config" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."templates" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."trading_conversations" AS
 SELECT "id",
    "name",
    "type" AS "conversation_type",
    ( SELECT "cp"."user_id"
           FROM "public"."conversation_participants" "cp"
          WHERE ("cp"."conversation_id" = "c"."id")
          ORDER BY "cp"."joined_at"
         LIMIT 1) AS "initiator_id",
    ( SELECT "cp"."user_id"
           FROM "public"."conversation_participants" "cp"
          WHERE ("cp"."conversation_id" = "c"."id")
          ORDER BY "cp"."joined_at"
         OFFSET 1
         LIMIT 1) AS "receiver_id"
   FROM "public"."conversations" "c";


ALTER VIEW "public"."trading_conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "event_type" "text" NOT NULL,
    "event_category" "text" NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "device_info" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_events" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."user_oauth_providers" AS
 SELECT "u"."id" AS "user_id",
    "u"."email",
    "u"."created_at",
    "array_agg"(DISTINCT "i"."provider") FILTER (WHERE ("i"."provider" IS NOT NULL)) AS "linked_providers"
   FROM ("auth"."users" "u"
     LEFT JOIN "auth"."identities" "i" ON (("i"."user_id" = "u"."id")))
  GROUP BY "u"."id", "u"."email", "u"."created_at";


ALTER VIEW "public"."user_oauth_providers" OWNER TO "postgres";


COMMENT ON VIEW "public"."user_oauth_providers" IS 'View showing OAuth providers linked to each user';



CREATE TABLE IF NOT EXISTS "public"."user_roles" (
    "user_id" "uuid" NOT NULL,
    "is_seller" boolean DEFAULT false,
    "is_customer" boolean DEFAULT true,
    "is_service_provider" boolean DEFAULT false,
    "is_doctor" boolean DEFAULT false,
    "is_pharmacy" boolean DEFAULT false,
    "is_driver" boolean DEFAULT false,
    "is_middleman" boolean DEFAULT false,
    "is_admin" boolean DEFAULT false,
    "last_active_at" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_template_selections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "template_id" "uuid",
    "selected_at" timestamp with time zone DEFAULT "now"(),
    "is_customized" boolean DEFAULT false,
    "custom_config" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_template_selections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_wallets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "balance" numeric(15,2) DEFAULT 0 NOT NULL,
    "pending_balance" numeric(15,2) DEFAULT 0 NOT NULL,
    "total_deposited" numeric(15,2) DEFAULT 0 NOT NULL,
    "total_withdrawn" numeric(15,2) DEFAULT 0 NOT NULL,
    "total_earned" numeric(15,2) DEFAULT 0 NOT NULL,
    "total_spent" numeric(15,2) DEFAULT 0 NOT NULL,
    "currency" "text" DEFAULT 'EGP'::"text" NOT NULL,
    "is_active" boolean DEFAULT true,
    "is_locked" boolean DEFAULT false,
    "lock_reason" "text",
    "locked_at" timestamp with time zone,
    "last_transaction_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "user_wallets_balance_check" CHECK (("balance" >= (0)::numeric)),
    CONSTRAINT "user_wallets_pending_balance_check" CHECK (("pending_balance" >= (0)::numeric))
);


ALTER TABLE "public"."user_wallets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "user_id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "full_name" "text",
    "phone" "text",
    "avatar_url" "text",
    "account_type" "text" DEFAULT ARRAY['user'::"text"],
    "location" "jsonb",
    "currency" "text" DEFAULT 'EGP'::"text",
    "is_verified" boolean DEFAULT false,
    "is_factory" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "preferred_language" "text" DEFAULT 'en'::"text",
    "preferred_currency" "text" DEFAULT 'USD'::"text",
    "theme_preference" "text" DEFAULT 'system'::"text",
    "sidebar_state" "jsonb" DEFAULT '{"width": 280, "collapsed": false}'::"jsonb",
    "onboarding_completed" boolean DEFAULT false,
    "custom_theme" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "public"."users" OWNER TO "postgres";


COMMENT ON COLUMN "public"."users"."onboarding_completed" IS 'Tracks whether user has completed their role-specific onboarding flow';



CREATE TABLE IF NOT EXISTS "public"."wallet_transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "wallet_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "transaction_type" "text" NOT NULL,
    "amount" numeric(15,2) NOT NULL,
    "balance_before" numeric(15,2) NOT NULL,
    "balance_after" numeric(15,2) NOT NULL,
    "reference_type" "text" NOT NULL,
    "reference_id" "uuid",
    "description" "text" NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "idempotency_key" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "wallet_transactions_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "wallet_transactions_reference_type_check" CHECK (("reference_type" = ANY (ARRAY['order'::"text", 'commission'::"text", 'payout'::"text", 'refund'::"text", 'adjustment'::"text", 'payment'::"text", 'deal'::"text", 'booking'::"text", 'service'::"text"]))),
    CONSTRAINT "wallet_transactions_transaction_type_check" CHECK (("transaction_type" = ANY (ARRAY['credit'::"text", 'debit'::"text", 'hold'::"text", 'release'::"text", 'refund'::"text", 'adjustment'::"text", 'fee'::"text", 'commission'::"text", 'payout'::"text", 'payment'::"text"])))
);


ALTER TABLE "public"."wallet_transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."website_integrations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "website_id" "uuid" NOT NULL,
    "integration_type" "text" NOT NULL,
    "config" "jsonb" NOT NULL,
    "is_active" boolean DEFAULT true,
    "last_synced_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."website_integrations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."website_marketplace" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "creator_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "category" "text" NOT NULL,
    "target_role" "text" NOT NULL,
    "preview_url" "text",
    "thumbnail_url" "text",
    "template_files" "jsonb" DEFAULT '[]'::"jsonb",
    "price" numeric(10,2) DEFAULT 0,
    "currency" "text" DEFAULT 'USD'::"text",
    "version" "text" DEFAULT '1.0.0'::"text",
    "is_published" boolean DEFAULT false,
    "download_count" integer DEFAULT 0,
    "rating" numeric(3,2) DEFAULT 0,
    "review_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "pages_preview" "jsonb" DEFAULT '[]'::"jsonb",
    "is_featured" boolean DEFAULT false,
    "total_sales" integer DEFAULT 0,
    CONSTRAINT "website_marketplace_target_role_check" CHECK (("target_role" = ANY (ARRAY['seller'::"text", 'doctor'::"text", 'pharmacy'::"text", 'factory'::"text", 'freelancer'::"text"])))
);


ALTER TABLE "public"."website_marketplace" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."website_pages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "website_id" "uuid" NOT NULL,
    "slug" "text" NOT NULL,
    "title" "text" NOT NULL,
    "content" "jsonb",
    "is_published" boolean DEFAULT false,
    "seo_title" "text",
    "seo_description" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."website_pages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."website_settings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "site_slug" "text" NOT NULL,
    "template_id" "text",
    "bucket_name" "text" DEFAULT 'website_assets'::"text",
    "custom_domain" "text",
    "status" "text" DEFAULT 'draft'::"text",
    "settings" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "website_settings_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'active'::"text", 'suspended'::"text"])))
);


ALTER TABLE "public"."website_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wishlist" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "asin" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."wishlist" OWNER TO "postgres";


ALTER TABLE ONLY "public"."activity_logs"
    ADD CONSTRAINT "activity_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."admin_users"
    ADD CONSTRAINT "admin_users_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."admins"
    ADD CONSTRAINT "admins_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."analytics"
    ADD CONSTRAINT "analytics_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."analytics_snapshots"
    ADD CONSTRAINT "analytics_snapshots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."analytics_uploads"
    ADD CONSTRAINT "analytics_uploads_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."app_devices"
    ADD CONSTRAINT "app_devices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."app_devices"
    ADD CONSTRAINT "app_devices_user_id_device_token_platform_key" UNIQUE ("user_id", "device_token", "platform");



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."async_jobs"
    ADD CONSTRAINT "async_jobs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."booking_milestones"
    ADD CONSTRAINT "booking_milestones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."brands"
    ADD CONSTRAINT "brands_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."brands"
    ADD CONSTRAINT "brands_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."business_profiles"
    ADD CONSTRAINT "business_profiles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."calls"
    ADD CONSTRAINT "calls_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cart"
    ADD CONSTRAINT "cart_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cart"
    ADD CONSTRAINT "cart_user_id_asin_key" UNIQUE ("user_id", "asin");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."cod_collections"
    ADD CONSTRAINT "cod_collections_order_id_key" UNIQUE ("order_id");



ALTER TABLE ONLY "public"."cod_collections"
    ADD CONSTRAINT "cod_collections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cod_verification_keys"
    ADD CONSTRAINT "cod_verification_keys_order_id_key" UNIQUE ("order_id");



ALTER TABLE ONLY "public"."cod_verification_keys"
    ADD CONSTRAINT "cod_verification_keys_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cod_verification_keys"
    ADD CONSTRAINT "cod_verification_keys_verification_key_key" UNIQUE ("verification_key");



ALTER TABLE ONLY "public"."commissions"
    ADD CONSTRAINT "commissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_pkey" PRIMARY KEY ("conversation_id", "user_id");



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."deal_proposals"
    ADD CONSTRAINT "deal_proposals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."deals"
    ADD CONSTRAINT "deals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."deals_v2"
    ADD CONSTRAINT "deals_v2_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."delivery_assignments"
    ADD CONSTRAINT "delivery_assignments_order_id_key" UNIQUE ("order_id");



ALTER TABLE ONLY "public"."delivery_assignments"
    ADD CONSTRAINT "delivery_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."delivery_profiles"
    ADD CONSTRAINT "delivery_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."delivery_profiles"
    ADD CONSTRAINT "delivery_profiles_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."doctor_medicine_deals"
    ADD CONSTRAINT "doctor_medicine_deals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."doctor_performance_metrics"
    ADD CONSTRAINT "doctor_performance_metrics_doctor_id_period_start_period_en_key" UNIQUE ("doctor_id", "period_start", "period_end");



ALTER TABLE ONLY "public"."doctor_performance_metrics"
    ADD CONSTRAINT "doctor_performance_metrics_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."doctors"
    ADD CONSTRAINT "doctors_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."error_logs"
    ADD CONSTRAINT "error_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."factories"
    ADD CONSTRAINT "factories_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."factories"
    ADD CONSTRAINT "factories_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."factory_connections"
    ADD CONSTRAINT "factory_connections_factory_id_seller_id_key" UNIQUE ("factory_id", "seller_id");



ALTER TABLE ONLY "public"."factory_connections"
    ADD CONSTRAINT "factory_connections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."factory_production_logs"
    ADD CONSTRAINT "factory_production_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."factory_profiles"
    ADD CONSTRAINT "factory_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."factory_quotes"
    ADD CONSTRAINT "factory_quotes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."factory_ratings"
    ADD CONSTRAINT "factory_ratings_factory_id_seller_id_key" UNIQUE ("factory_id", "seller_id");



ALTER TABLE ONLY "public"."factory_ratings"
    ADD CONSTRAINT "factory_ratings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."freelancer_orders"
    ADD CONSTRAINT "freelancer_orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."freelancer_portfolio"
    ADD CONSTRAINT "freelancer_portfolio_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."freelancer_profiles"
    ADD CONSTRAINT "freelancer_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."freelancer_profiles"
    ADD CONSTRAINT "freelancer_profiles_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."freelancer_services"
    ADD CONSTRAINT "freelancer_services_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_appointments"
    ADD CONSTRAINT "health_appointments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_chat_attachments"
    ADD CONSTRAINT "health_chat_attachments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_conversations"
    ADD CONSTRAINT "health_conversations_appointment_id_key" UNIQUE ("appointment_id");



ALTER TABLE ONLY "public"."health_conversations"
    ADD CONSTRAINT "health_conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_daily_backup_status"
    ADD CONSTRAINT "health_daily_backup_status_doctor_id_backup_date_key" UNIQUE ("doctor_id", "backup_date");



ALTER TABLE ONLY "public"."health_daily_backup_status"
    ADD CONSTRAINT "health_daily_backup_status_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_doctor_profiles"
    ADD CONSTRAINT "health_doctor_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_medicine_categories"
    ADD CONSTRAINT "health_medicine_categories_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."health_medicine_categories"
    ADD CONSTRAINT "health_medicine_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_medicine_categories"
    ADD CONSTRAINT "health_medicine_categories_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."health_medicine_expiry_alerts"
    ADD CONSTRAINT "health_medicine_expiry_alerts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_medicine_order_items"
    ADD CONSTRAINT "health_medicine_order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_medicine_orders"
    ADD CONSTRAINT "health_medicine_orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_medicine_recalls"
    ADD CONSTRAINT "health_medicine_recalls_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_medicine_recalls"
    ADD CONSTRAINT "health_medicine_recalls_recall_number_key" UNIQUE ("recall_number");



ALTER TABLE ONLY "public"."health_medicine_reviews"
    ADD CONSTRAINT "health_medicine_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_medicine_stock_history"
    ADD CONSTRAINT "health_medicine_stock_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_medicines_master"
    ADD CONSTRAINT "health_medicines_master_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_medicines"
    ADD CONSTRAINT "health_medicines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_message_archives"
    ADD CONSTRAINT "health_message_archives_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_message_receipts"
    ADD CONSTRAINT "health_message_receipts_message_id_user_id_key" UNIQUE ("message_id", "user_id");



ALTER TABLE ONLY "public"."health_message_receipts"
    ADD CONSTRAINT "health_message_receipts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_messages"
    ADD CONSTRAINT "health_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_patient_access_log"
    ADD CONSTRAINT "health_patient_access_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_patient_archives"
    ADD CONSTRAINT "health_patient_archives_doctor_id_patient_id_backup_date_key" UNIQUE ("doctor_id", "patient_id", "backup_date");



ALTER TABLE ONLY "public"."health_patient_archives"
    ADD CONSTRAINT "health_patient_archives_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_patient_change_log"
    ADD CONSTRAINT "health_patient_change_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_patient_profiles"
    ADD CONSTRAINT "health_patient_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_pharmacy_inspections"
    ADD CONSTRAINT "health_pharmacy_inspections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_pharmacy_inventory"
    ADD CONSTRAINT "health_pharmacy_inventory_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_pharmacy_profiles"
    ADD CONSTRAINT "health_pharmacy_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_prescription_access_log"
    ADD CONSTRAINT "health_prescription_access_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_prescription_audit_log"
    ADD CONSTRAINT "health_prescription_audit_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_prescription_medicines_digital"
    ADD CONSTRAINT "health_prescription_medicines_digital_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_prescription_medicines"
    ADD CONSTRAINT "health_prescription_medicines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_prescription_shares"
    ADD CONSTRAINT "health_prescription_shares_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_prescription_shares"
    ADD CONSTRAINT "health_prescription_shares_share_token_key" UNIQUE ("share_token");



ALTER TABLE ONLY "public"."health_prescriptions_digital"
    ADD CONSTRAINT "health_prescriptions_digital_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_prescriptions_digital"
    ADD CONSTRAINT "health_prescriptions_digital_prescription_number_key" UNIQUE ("prescription_number");



ALTER TABLE ONLY "public"."health_prescriptions"
    ADD CONSTRAINT "health_prescriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_reviews"
    ADD CONSTRAINT "health_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_typing_indicators"
    ADD CONSTRAINT "health_typing_indicators_pkey" PRIMARY KEY ("conversation_id", "user_id");



ALTER TABLE ONLY "public"."healthcare_provider_profiles"
    ADD CONSTRAINT "healthcare_provider_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."hospitals"
    ADD CONSTRAINT "hospitals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."hospitals"
    ADD CONSTRAINT "hospitals_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."idempotency_keys"
    ADD CONSTRAINT "idempotency_keys_key_key" UNIQUE ("key");



ALTER TABLE ONLY "public"."idempotency_keys"
    ADD CONSTRAINT "idempotency_keys_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."marketplace_purchases"
    ADD CONSTRAINT "marketplace_purchases_license_key_key" UNIQUE ("license_key");



ALTER TABLE ONLY "public"."marketplace_purchases"
    ADD CONSTRAINT "marketplace_purchases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."medical_staff"
    ADD CONSTRAINT "medical_staff_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."medicine_sales_analytics"
    ADD CONSTRAINT "medicine_sales_analytics_medicine_id_pharmacy_id_sale_date_key" UNIQUE ("medicine_id", "pharmacy_id", "sale_date");



ALTER TABLE ONLY "public"."medicine_sales_analytics"
    ADD CONSTRAINT "medicine_sales_analytics_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."middle_man_deals"
    ADD CONSTRAINT "middle_man_deals_middle_man_id_product_asin_key" UNIQUE ("middle_man_id", "product_asin");



ALTER TABLE ONLY "public"."middle_man_deals"
    ADD CONSTRAINT "middle_man_deals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."middle_man_deals"
    ADD CONSTRAINT "middle_man_deals_unique_slug_key" UNIQUE ("unique_slug");



ALTER TABLE ONLY "public"."middle_men"
    ADD CONSTRAINT "middle_men_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."middleman_connections"
    ADD CONSTRAINT "middleman_connections_middleman_id_provider_id_key" UNIQUE ("middleman_id", "provider_id");



ALTER TABLE ONLY "public"."middleman_connections"
    ADD CONSTRAINT "middleman_connections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."middleman_profiles"
    ADD CONSTRAINT "middleman_profiles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."middleman_seller_links"
    ADD CONSTRAINT "middleman_seller_links_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."middleman_store_configs"
    ADD CONSTRAINT "middleman_store_configs_middleman_id_key" UNIQUE ("middleman_id");



ALTER TABLE ONLY "public"."middleman_store_configs"
    ADD CONSTRAINT "middleman_store_configs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."middleman_store_configs"
    ADD CONSTRAINT "middleman_store_configs_store_slug_key" UNIQUE ("store_slug");



ALTER TABLE ONLY "public"."notification_settings"
    ADD CONSTRAINT "notification_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_settings"
    ADD CONSTRAINT "notification_settings_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."notification_templates"
    ADD CONSTRAINT "notification_templates_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."notification_templates"
    ADD CONSTRAINT "notification_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patient_medicine_preferences"
    ADD CONSTRAINT "patient_medicine_preferences_patient_id_medicine_id_prefere_key" UNIQUE ("patient_id", "medicine_id", "preference_type");



ALTER TABLE ONLY "public"."patient_medicine_preferences"
    ADD CONSTRAINT "patient_medicine_preferences_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payment_intentions"
    ADD CONSTRAINT "payment_intentions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payment_splits"
    ADD CONSTRAINT "payment_splits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payment_transactions"
    ADD CONSTRAINT "payment_transactions_gateway_transaction_id_key" UNIQUE ("gateway_transaction_id");



ALTER TABLE ONLY "public"."payment_transactions"
    ADD CONSTRAINT "payment_transactions_idempotency_key_key" UNIQUE ("idempotency_key");



ALTER TABLE ONLY "public"."payment_transactions"
    ADD CONSTRAINT "payment_transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payment_webhook_logs"
    ADD CONSTRAINT "payment_webhook_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payout_requests"
    ADD CONSTRAINT "payout_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payouts"
    ADD CONSTRAINT "payouts_idempotency_key_key" UNIQUE ("idempotency_key");



ALTER TABLE ONLY "public"."payouts"
    ADD CONSTRAINT "payouts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pharmacy_activity_logs"
    ADD CONSTRAINT "pharmacy_activity_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pharmacy_daily_reports"
    ADD CONSTRAINT "pharmacy_daily_reports_pharmacy_id_report_date_key" UNIQUE ("pharmacy_id", "report_date");



ALTER TABLE ONLY "public"."pharmacy_daily_reports"
    ADD CONSTRAINT "pharmacy_daily_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pharmacy_details"
    ADD CONSTRAINT "pharmacy_details_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pharmacy_details"
    ADD CONSTRAINT "pharmacy_details_provider_id_key" UNIQUE ("provider_id");



ALTER TABLE ONLY "public"."pharmacy_medicine_inventory"
    ADD CONSTRAINT "pharmacy_medicine_inventory_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pharmacy_medicine_inventory"
    ADD CONSTRAINT "pharmacy_medicine_inventory_qr_code_key" UNIQUE ("qr_code");



ALTER TABLE ONLY "public"."pharmacy_products"
    ADD CONSTRAINT "pharmacy_products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pharmacy_profiles"
    ADD CONSTRAINT "pharmacy_profiles_license_number_key" UNIQUE ("license_number");



ALTER TABLE ONLY "public"."pharmacy_profiles"
    ADD CONSTRAINT "pharmacy_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pharmacy_profiles"
    ADD CONSTRAINT "pharmacy_profiles_qr_code_prefix_key" UNIQUE ("qr_code_prefix");



ALTER TABLE ONLY "public"."pharmacy_qr_scan_logs"
    ADD CONSTRAINT "pharmacy_qr_scan_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pharmacy_stock_movements"
    ADD CONSTRAINT "pharmacy_stock_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."platform_reports"
    ADD CONSTRAINT "platform_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."platform_settings"
    ADD CONSTRAINT "platform_settings_key_key" UNIQUE ("key");



ALTER TABLE ONLY "public"."platform_settings"
    ADD CONSTRAINT "platform_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."post_comments"
    ADD CONSTRAINT "post_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."post_likes"
    ADD CONSTRAINT "post_likes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."post_likes"
    ADD CONSTRAINT "post_likes_post_id_user_id_key" UNIQUE ("post_id", "user_id");



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."prescription_fulfillment"
    ADD CONSTRAINT "prescription_fulfillment_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_asin_key" UNIQUE ("asin");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_asin_unique" UNIQUE ("asin");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."provider_availability"
    ADD CONSTRAINT "provider_availability_pkey" PRIMARY KEY ("provider_id", "day_of_week", "start_time");



ALTER TABLE ONLY "public"."provider_time_off"
    ADD CONSTRAINT "provider_time_off_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."push_subscriptions"
    ADD CONSTRAINT "push_subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."push_subscriptions"
    ADD CONSTRAINT "push_subscriptions_user_id_token_key" UNIQUE ("user_id", "token");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_user_id_asin_key" UNIQUE ("user_id", "asin");



ALTER TABLE ONLY "public"."seller_profiles"
    ADD CONSTRAINT "seller_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sellers"
    ADD CONSTRAINT "sellers_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."sellers"
    ADD CONSTRAINT "sellers_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."sellers_tmp_test"
    ADD CONSTRAINT "sellers_tmp_test_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."service_appointments"
    ADD CONSTRAINT "service_appointments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."services"
    ADD CONSTRAINT "services_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shipping_addresses"
    ADD CONSTRAINT "shipping_addresses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shipping_addresses"
    ADD CONSTRAINT "shipping_addresses_user_id_is_default_key" UNIQUE ("user_id", "is_default");



ALTER TABLE ONLY "public"."shop_products"
    ADD CONSTRAINT "shop_products_pkey" PRIMARY KEY ("shop_id", "product_id");



ALTER TABLE ONLY "public"."shop_templates"
    ADD CONSTRAINT "shop_templates_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."shop_templates"
    ADD CONSTRAINT "shop_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shops"
    ADD CONSTRAINT "shops_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shops"
    ADD CONSTRAINT "shops_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."site_catalog"
    ADD CONSTRAINT "site_catalog_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_catalog"
    ADD CONSTRAINT "site_catalog_user_id_product_id_key" UNIQUE ("user_id", "product_id");



ALTER TABLE ONLY "public"."store_configs"
    ADD CONSTRAINT "store_configs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_configs"
    ADD CONSTRAINT "store_configs_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."store_customizations"
    ADD CONSTRAINT "store_customizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_products"
    ADD CONSTRAINT "store_products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_products"
    ADD CONSTRAINT "store_products_profile_id_asin_key" UNIQUE ("profile_id", "asin");



ALTER TABLE ONLY "public"."subcategories"
    ADD CONSTRAINT "subcategories_category_id_name_key" UNIQUE ("category_id", "name");



ALTER TABLE ONLY "public"."subcategories"
    ADD CONSTRAINT "subcategories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."svc_categories"
    ADD CONSTRAINT "svc_categories_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."svc_categories"
    ADD CONSTRAINT "svc_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."svc_categories"
    ADD CONSTRAINT "svc_categories_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."svc_listing_packages"
    ADD CONSTRAINT "svc_listing_packages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."svc_listings"
    ADD CONSTRAINT "svc_listings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."svc_listings"
    ADD CONSTRAINT "svc_listings_provider_id_slug_key" UNIQUE ("provider_id", "slug");



ALTER TABLE ONLY "public"."svc_messages"
    ADD CONSTRAINT "svc_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."svc_orders"
    ADD CONSTRAINT "svc_orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."svc_portfolio"
    ADD CONSTRAINT "svc_portfolio_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."svc_providers"
    ADD CONSTRAINT "svc_providers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."svc_providers"
    ADD CONSTRAINT "svc_providers_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."svc_reviews"
    ADD CONSTRAINT "svc_reviews_order_id_key" UNIQUE ("order_id");



ALTER TABLE ONLY "public"."svc_reviews"
    ADD CONSTRAINT "svc_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."svc_subcategories"
    ADD CONSTRAINT "svc_subcategories_category_id_name_key" UNIQUE ("category_id", "name");



ALTER TABLE ONLY "public"."svc_subcategories"
    ADD CONSTRAINT "svc_subcategories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."template_requests"
    ADD CONSTRAINT "template_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."templates"
    ADD CONSTRAINT "templates_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."templates"
    ADD CONSTRAINT "templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."analytics_snapshots"
    ADD CONSTRAINT "unique_seller_period" UNIQUE ("seller_id", "period_type", "period_start", "period_end");



ALTER TABLE ONLY "public"."user_events"
    ADD CONSTRAINT "user_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."user_template_selections"
    ADD CONSTRAINT "user_template_selections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_template_selections"
    ADD CONSTRAINT "user_template_selections_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."user_wallets"
    ADD CONSTRAINT "user_wallets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_wallets"
    ADD CONSTRAINT "user_wallets_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."wallet_transactions"
    ADD CONSTRAINT "wallet_transactions_idempotency_key_key" UNIQUE ("idempotency_key");



ALTER TABLE ONLY "public"."wallet_transactions"
    ADD CONSTRAINT "wallet_transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."website_integrations"
    ADD CONSTRAINT "website_integrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."website_integrations"
    ADD CONSTRAINT "website_integrations_website_id_integration_type_key" UNIQUE ("website_id", "integration_type");



ALTER TABLE ONLY "public"."website_marketplace"
    ADD CONSTRAINT "website_marketplace_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."website_pages"
    ADD CONSTRAINT "website_pages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."website_pages"
    ADD CONSTRAINT "website_pages_website_id_slug_key" UNIQUE ("website_id", "slug");



ALTER TABLE ONLY "public"."website_settings"
    ADD CONSTRAINT "website_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."website_settings"
    ADD CONSTRAINT "website_settings_site_slug_key" UNIQUE ("site_slug");



ALTER TABLE ONLY "public"."websites"
    ADD CONSTRAINT "websites_api_key_key" UNIQUE ("api_key");



ALTER TABLE ONLY "public"."websites"
    ADD CONSTRAINT "websites_custom_domain_key" UNIQUE ("custom_domain");



ALTER TABLE ONLY "public"."websites"
    ADD CONSTRAINT "websites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."websites"
    ADD CONSTRAINT "websites_seller_id_subdomain_key" UNIQUE ("seller_id", "subdomain");



ALTER TABLE ONLY "public"."websites"
    ADD CONSTRAINT "websites_subdomain_key" UNIQUE ("subdomain");



ALTER TABLE ONLY "public"."wishlist"
    ADD CONSTRAINT "wishlist_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."wishlist"
    ADD CONSTRAINT "wishlist_user_id_asin_key" UNIQUE ("user_id", "asin");



CREATE INDEX "customers_location_idx" ON "public"."customers" USING "btree" ("latitude", "longitude");



CREATE INDEX "idx_access_log_date" ON "public"."health_patient_access_log" USING "btree" ("accessed_at");



CREATE INDEX "idx_access_log_doctor" ON "public"."health_patient_access_log" USING "btree" ("doctor_id");



CREATE INDEX "idx_access_log_patient" ON "public"."health_patient_access_log" USING "btree" ("patient_id");



CREATE INDEX "idx_activity_logs_created_at" ON "public"."activity_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_activity_logs_user_id" ON "public"."activity_logs" USING "btree" ("user_id");



CREATE INDEX "idx_analytics_is_current" ON "public"."analytics_snapshots" USING "btree" ("is_current") WHERE ("is_current" = true);



CREATE INDEX "idx_analytics_period_start" ON "public"."analytics_snapshots" USING "btree" ("period_start" DESC);



CREATE INDEX "idx_analytics_period_type" ON "public"."analytics_snapshots" USING "btree" ("period_type");



CREATE INDEX "idx_analytics_seller_id" ON "public"."analytics_snapshots" USING "btree" ("seller_id");



CREATE INDEX "idx_analytics_uploads_entity" ON "public"."analytics_uploads" USING "btree" ("entity_type", "entity_id");



CREATE INDEX "idx_analytics_uploads_uploaded_at" ON "public"."analytics_uploads" USING "btree" ("uploaded_at" DESC);



CREATE INDEX "idx_appointments_client" ON "public"."appointments" USING "btree" ("client_id");



CREATE INDEX "idx_appointments_provider" ON "public"."appointments" USING "btree" ("provider_id", "scheduled_at");



CREATE INDEX "idx_appointments_status" ON "public"."service_appointments" USING "btree" ("status");



CREATE INDEX "idx_appointments_time" ON "public"."service_appointments" USING "btree" ("scheduled_time");



CREATE INDEX "idx_async_jobs_queue_status" ON "public"."async_jobs" USING "btree" ("queue_name", "status", "scheduled_for");



CREATE INDEX "idx_async_jobs_scheduled" ON "public"."async_jobs" USING "btree" ("scheduled_for") WHERE ("status" = 'pending'::"text");



CREATE INDEX "idx_backup_status_date" ON "public"."health_daily_backup_status" USING "btree" ("backup_date");



CREATE INDEX "idx_backup_status_doctor" ON "public"."health_daily_backup_status" USING "btree" ("doctor_id");



CREATE INDEX "idx_business_profiles_role" ON "public"."business_profiles" USING "btree" ("role");



CREATE INDEX "idx_business_profiles_user_id" ON "public"."business_profiles" USING "btree" ("user_id");



CREATE INDEX "idx_calls_callee" ON "public"."calls" USING "btree" ("callee_id");



CREATE INDEX "idx_calls_caller" ON "public"."calls" USING "btree" ("caller_id");



CREATE INDEX "idx_calls_conversation" ON "public"."calls" USING "btree" ("conversation_id");



CREATE INDEX "idx_calls_status" ON "public"."calls" USING "btree" ("status");



CREATE INDEX "idx_cart_asin" ON "public"."cart" USING "btree" ("asin");



CREATE INDEX "idx_cart_user_asin" ON "public"."cart" USING "btree" ("user_id", "asin");



CREATE INDEX "idx_cart_user_id" ON "public"."cart" USING "btree" ("user_id");



CREATE INDEX "idx_categories_parent" ON "public"."categories" USING "btree" ("parent_id");



CREATE INDEX "idx_categories_slug" ON "public"."categories" USING "btree" ("slug");



CREATE INDEX "idx_change_log_doctor" ON "public"."health_patient_change_log" USING "btree" ("doctor_id");



CREATE INDEX "idx_change_log_patient" ON "public"."health_patient_change_log" USING "btree" ("patient_id");



CREATE INDEX "idx_change_log_type" ON "public"."health_patient_change_log" USING "btree" ("change_type");



CREATE INDEX "idx_chat_attachments_conversation" ON "public"."health_chat_attachments" USING "btree" ("conversation_id");



CREATE INDEX "idx_chat_attachments_uploaded_by" ON "public"."health_chat_attachments" USING "btree" ("uploaded_by");



CREATE INDEX "idx_cod_collections_collected" ON "public"."cod_collections" USING "btree" ("collected_at");



CREATE INDEX "idx_cod_collections_delivery" ON "public"."cod_collections" USING "btree" ("delivery_id");



CREATE INDEX "idx_cod_collections_disputed" ON "public"."cod_collections" USING "btree" ("disputed_at") WHERE ("status" = 'disputed'::"text");



CREATE INDEX "idx_cod_collections_order" ON "public"."cod_collections" USING "btree" ("order_id");



CREATE INDEX "idx_cod_collections_status" ON "public"."cod_collections" USING "btree" ("status");



CREATE INDEX "idx_cod_keys_expires" ON "public"."cod_verification_keys" USING "btree" ("expires_at");



CREATE INDEX "idx_cod_keys_key" ON "public"."cod_verification_keys" USING "btree" ("verification_key");



CREATE INDEX "idx_cod_keys_order" ON "public"."cod_verification_keys" USING "btree" ("order_id");



CREATE INDEX "idx_cod_keys_status" ON "public"."cod_verification_keys" USING "btree" ("status");



CREATE INDEX "idx_commissions_middle_man" ON "public"."commissions" USING "btree" ("middle_man_id");



CREATE INDEX "idx_commissions_status" ON "public"."commissions" USING "btree" ("status");



CREATE INDEX "idx_conversation_participants_user_conv" ON "public"."conversation_participants" USING "btree" ("user_id", "conversation_id");



CREATE INDEX "idx_conversations_last_message_at" ON "public"."conversations" USING "btree" ("last_message_at" DESC);



CREATE INDEX "idx_conversations_last_msg" ON "public"."conversations" USING "btree" ("updated_at" DESC NULLS LAST) WHERE ("is_archived" = false);



CREATE INDEX "idx_conversations_product" ON "public"."conversations" USING "btree" ("product_id");



CREATE INDEX "idx_conversations_type" ON "public"."conversations" USING "btree" ("type");



CREATE INDEX "idx_customers_age_range" ON "public"."customers" USING "btree" ("age_range");



CREATE INDEX "idx_customers_seller_id" ON "public"."customers" USING "btree" ("seller_id");



CREATE INDEX "idx_customers_seller_total_spent" ON "public"."customers" USING "btree" ("user_id", "total_spent" DESC);



CREATE INDEX "idx_customers_user_id" ON "public"."customers" USING "btree" ("user_id");



CREATE INDEX "idx_daily_reports_pharmacy" ON "public"."pharmacy_daily_reports" USING "btree" ("pharmacy_id", "report_date" DESC);



CREATE INDEX "idx_delivery_assignments_driver" ON "public"."delivery_assignments" USING "btree" ("driver_id");



CREATE INDEX "idx_delivery_assignments_order" ON "public"."delivery_assignments" USING "btree" ("order_id");



CREATE INDEX "idx_delivery_assignments_status" ON "public"."delivery_assignments" USING "btree" ("status");



CREATE INDEX "idx_delivery_location" ON "public"."delivery_profiles" USING "btree" ("latitude", "longitude") WHERE (("is_active" = true) AND ("is_verified" = true));



CREATE INDEX "idx_delivery_profiles_active" ON "public"."delivery_profiles" USING "btree" ("is_active", "is_verified", "is_available");



CREATE INDEX "idx_delivery_profiles_user" ON "public"."delivery_profiles" USING "btree" ("user_id");



CREATE INDEX "idx_doctor_deals_active" ON "public"."doctor_medicine_deals" USING "btree" ("is_active") WHERE ("is_active" = true);



CREATE INDEX "idx_doctor_deals_doctor" ON "public"."doctor_medicine_deals" USING "btree" ("doctor_id");



CREATE INDEX "idx_doctor_deals_medicine" ON "public"."doctor_medicine_deals" USING "btree" ("medicine_id");



CREATE INDEX "idx_error_logs_user_id" ON "public"."error_logs" USING "btree" ("user_id");



CREATE INDEX "idx_factories_customers" ON "public"."factories" USING "gin" ("customers");



CREATE INDEX "idx_factories_settings" ON "public"."factories" USING "gin" ("settings");



CREATE INDEX "idx_factories_user_id" ON "public"."factories" USING "btree" ("user_id");



CREATE INDEX "idx_factory_connections_factory" ON "public"."factory_connections" USING "btree" ("factory_id");



CREATE INDEX "idx_factory_connections_seller" ON "public"."factory_connections" USING "btree" ("seller_id");



CREATE INDEX "idx_factory_connections_status" ON "public"."factory_connections" USING "btree" ("status");



CREATE INDEX "idx_factory_profiles_company_name" ON "public"."factory_profiles" USING "btree" ("company_name");



CREATE INDEX "idx_factory_profiles_customers" ON "public"."factory_profiles" USING "gin" ("customers");



CREATE INDEX "idx_factory_profiles_location" ON "public"."factory_profiles" USING "btree" ("location");



CREATE INDEX "idx_factory_profiles_settings" ON "public"."factory_profiles" USING "gin" ("settings");



CREATE INDEX "idx_factory_profiles_verified" ON "public"."factory_profiles" USING "btree" ("verified");



CREATE INDEX "idx_factory_ratings_factory" ON "public"."factory_ratings" USING "btree" ("factory_id");



CREATE INDEX "idx_freelancer_profiles_skills" ON "public"."freelancer_profiles" USING "gin" ("skills");



CREATE INDEX "idx_freelancer_profiles_user_id" ON "public"."freelancer_profiles" USING "btree" ("user_id");



CREATE INDEX "idx_freelancer_skills" ON "public"."freelancer_profiles" USING "gin" ("skills");



CREATE INDEX "idx_health_appt_doctor" ON "public"."health_appointments" USING "btree" ("doctor_id");



CREATE INDEX "idx_health_appt_patient" ON "public"."health_appointments" USING "btree" ("patient_id");



CREATE INDEX "idx_health_appt_status" ON "public"."health_appointments" USING "btree" ("status");



CREATE INDEX "idx_health_conversations_appointment" ON "public"."health_conversations" USING "btree" ("appointment_id");



CREATE INDEX "idx_health_conversations_doctor" ON "public"."health_conversations" USING "btree" ("doctor_id");



CREATE INDEX "idx_health_conversations_patient" ON "public"."health_conversations" USING "btree" ("patient_id");



CREATE INDEX "idx_health_conversations_status" ON "public"."health_conversations" USING "btree" ("status");



CREATE INDEX "idx_health_conversations_updated" ON "public"."health_conversations" USING "btree" ("updated_at" DESC);



CREATE INDEX "idx_health_expiry_alerts_pharmacy" ON "public"."health_medicine_expiry_alerts" USING "btree" ("pharmacy_id");



CREATE INDEX "idx_health_expiry_alerts_unresolved" ON "public"."health_medicine_expiry_alerts" USING "btree" ("pharmacy_id", "is_resolved") WHERE ("is_resolved" = false);



CREATE INDEX "idx_health_inventory_batch" ON "public"."health_pharmacy_inventory" USING "btree" ("pharmacy_id", "batch_number");



CREATE INDEX "idx_health_inventory_expired" ON "public"."health_pharmacy_inventory" USING "btree" ("is_expired") WHERE ("is_expired" = true);



CREATE INDEX "idx_health_inventory_expiry" ON "public"."health_pharmacy_inventory" USING "btree" ("expiry_date");



CREATE INDEX "idx_health_inventory_medicine" ON "public"."health_pharmacy_inventory" USING "btree" ("medicine_id");



CREATE INDEX "idx_health_inventory_near_expiry" ON "public"."health_pharmacy_inventory" USING "btree" ("is_near_expiry") WHERE ("is_near_expiry" = true);



CREATE INDEX "idx_health_inventory_pharmacy" ON "public"."health_pharmacy_inventory" USING "btree" ("pharmacy_id");



CREATE INDEX "idx_health_medicine_available" ON "public"."health_medicines" USING "btree" ("is_available");



CREATE INDEX "idx_health_medicine_category" ON "public"."health_medicines" USING "btree" ("category");



CREATE INDEX "idx_health_medicine_master_category" ON "public"."health_medicines_master" USING "btree" ("category");



CREATE INDEX "idx_health_medicine_master_prescription" ON "public"."health_medicines_master" USING "btree" ("requires_prescription");



CREATE INDEX "idx_health_medicine_master_search" ON "public"."health_medicines_master" USING "gin" ("to_tsvector"('"english"'::"regconfig", ((((COALESCE("name", ''::"text") || ' '::"text") || COALESCE("generic_name", ''::"text")) || ' '::"text") || COALESCE("brand", ''::"text"))));



CREATE INDEX "idx_health_medicine_order_patient" ON "public"."health_medicine_orders" USING "btree" ("patient_id");



CREATE INDEX "idx_health_medicine_order_pharmacy" ON "public"."health_medicine_orders" USING "btree" ("pharmacy_id");



CREATE INDEX "idx_health_medicine_order_prescription" ON "public"."health_medicine_orders" USING "btree" ("prescription_id");



CREATE INDEX "idx_health_medicine_order_status" ON "public"."health_medicine_orders" USING "btree" ("status");



CREATE INDEX "idx_health_medicine_pharmacy" ON "public"."health_medicines" USING "btree" ("pharmacy_id");



CREATE INDEX "idx_health_medicine_prescription" ON "public"."health_medicines" USING "btree" ("requires_prescription");



CREATE INDEX "idx_health_medicine_search" ON "public"."health_medicines" USING "gin" ("to_tsvector"('"english"'::"regconfig", ((((COALESCE("name", ''::"text") || ' '::"text") || COALESCE("generic_name", ''::"text")) || ' '::"text") || COALESCE("brand", ''::"text"))));



CREATE INDEX "idx_health_messages_conversation" ON "public"."health_messages" USING "btree" ("conversation_id", "created_at" DESC);



CREATE INDEX "idx_health_messages_created" ON "public"."health_messages" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_health_messages_read" ON "public"."health_messages" USING "btree" ("is_read") WHERE ("is_read" = false);



CREATE INDEX "idx_health_messages_sender" ON "public"."health_messages" USING "btree" ("sender_id");



CREATE INDEX "idx_health_messages_type" ON "public"."health_messages" USING "btree" ("message_type");



CREATE INDEX "idx_health_pharmacy_city" ON "public"."health_pharmacy_profiles" USING "btree" ("city");



CREATE INDEX "idx_health_pharmacy_license_expiry" ON "public"."health_pharmacy_profiles" USING "btree" ("license_expiry_date");



CREATE INDEX "idx_health_pharmacy_user" ON "public"."health_pharmacy_profiles" USING "btree" ("user_id");



CREATE INDEX "idx_health_pharmacy_verified" ON "public"."health_pharmacy_profiles" USING "btree" ("is_verified");



CREATE INDEX "idx_health_reviews_approved" ON "public"."health_reviews" USING "btree" ("is_approved");



CREATE INDEX "idx_health_reviews_doctor" ON "public"."health_reviews" USING "btree" ("doctor_id");



CREATE INDEX "idx_health_reviews_patient" ON "public"."health_reviews" USING "btree" ("patient_id");



CREATE INDEX "idx_health_stock_history_medicine" ON "public"."health_medicine_stock_history" USING "btree" ("medicine_id");



CREATE INDEX "idx_health_stock_history_pharmacy" ON "public"."health_medicine_stock_history" USING "btree" ("pharmacy_id");



CREATE INDEX "idx_healthcare_type" ON "public"."healthcare_provider_profiles" USING "btree" ("provider_type");



CREATE INDEX "idx_hospitals_location" ON "public"."hospitals" USING "btree" ("latitude", "longitude");



CREATE INDEX "idx_hospitals_owner" ON "public"."hospitals" USING "btree" ("owner_user_id");



CREATE INDEX "idx_hospitals_search" ON "public"."hospitals" USING "gin" ("to_tsvector"('"english"'::"regconfig", (((("name" || ' '::"text") || COALESCE("description", ''::"text")) || ' '::"text") || COALESCE("city", ''::"text"))));



CREATE INDEX "idx_hospitals_type" ON "public"."hospitals" USING "btree" ("hospital_type");



CREATE INDEX "idx_hospitals_verified" ON "public"."hospitals" USING "btree" ("is_verified") WHERE ("is_verified" = true);



CREATE INDEX "idx_idempotency_keys_expires" ON "public"."idempotency_keys" USING "btree" ("expires_at");



CREATE INDEX "idx_idempotency_keys_key" ON "public"."idempotency_keys" USING "btree" ("key");



CREATE INDEX "idx_location_history_user_id" ON "public"."location_history" USING "btree" ("user_id");



CREATE INDEX "idx_marketplace_creator" ON "public"."website_marketplace" USING "btree" ("creator_id");



CREATE INDEX "idx_marketplace_is_published" ON "public"."website_marketplace" USING "btree" ("is_published");



CREATE INDEX "idx_marketplace_price" ON "public"."website_marketplace" USING "btree" ("price");



CREATE INDEX "idx_marketplace_target_role" ON "public"."website_marketplace" USING "btree" ("target_role");



CREATE INDEX "idx_marketplace_total_sales" ON "public"."website_marketplace" USING "btree" ("total_sales" DESC);



CREATE INDEX "idx_message_archives_conversation" ON "public"."health_message_archives" USING "btree" ("conversation_id");



CREATE INDEX "idx_message_archives_date" ON "public"."health_message_archives" USING "btree" ("archived_at");



CREATE INDEX "idx_message_receipts_message" ON "public"."health_message_receipts" USING "btree" ("message_id");



CREATE INDEX "idx_message_receipts_user" ON "public"."health_message_receipts" USING "btree" ("user_id");



CREATE INDEX "idx_messages_conversation_created" ON "public"."messages" USING "btree" ("conversation_id", "created_at" DESC);



CREATE INDEX "idx_messages_conversation_id" ON "public"."messages" USING "btree" ("conversation_id", "created_at" DESC);



CREATE INDEX "idx_messages_convo_created" ON "public"."messages" USING "btree" ("conversation_id", "created_at" DESC);



CREATE INDEX "idx_messages_read_at" ON "public"."messages" USING "btree" ("read_at") WHERE ("read_at" IS NULL);



CREATE INDEX "idx_messages_search" ON "public"."messages" USING "gin" ("content_tsvector");



CREATE INDEX "idx_messages_sender_id" ON "public"."messages" USING "btree" ("sender_id");



CREATE INDEX "idx_middle_man_deals_middle_man" ON "public"."middle_man_deals" USING "btree" ("middle_man_id");



CREATE INDEX "idx_middle_man_deals_slug" ON "public"."middle_man_deals" USING "btree" ("unique_slug");



CREATE INDEX "idx_middleman_connections_mid" ON "public"."middleman_connections" USING "btree" ("middleman_id");



CREATE INDEX "idx_middleman_connections_pid" ON "public"."middleman_connections" USING "btree" ("provider_id");



CREATE INDEX "idx_middleman_profiles_customers" ON "public"."middleman_profiles" USING "gin" ("customers");



CREATE INDEX "idx_middleman_profiles_settings" ON "public"."middleman_profiles" USING "gin" ("settings");



CREATE INDEX "idx_middleman_profiles_user_id" ON "public"."middleman_profiles" USING "btree" ("user_id");



CREATE INDEX "idx_middleman_profiles_verification" ON "public"."middleman_profiles" USING "btree" ("is_verified", "verification_status");



CREATE INDEX "idx_mm_deals_expires" ON "public"."middle_man_deals" USING "btree" ("expires_at") WHERE (("expires_at" IS NOT NULL) AND ("is_active" = true));



CREATE INDEX "idx_mm_deals_seller_status" ON "public"."middle_man_deals" USING "btree" ("seller_id", "is_active", "approval_status") WHERE (("is_active" = true) AND ("approval_status" = 'auto_approved'::"text"));



CREATE INDEX "idx_mm_deals_slug_active" ON "public"."middle_man_deals" USING "btree" ("unique_slug", "is_active") WHERE ("is_active" = true);



CREATE INDEX "idx_notification_settings_user_id" ON "public"."notification_settings" USING "btree" ("user_id");



CREATE INDEX "idx_notifications_created_at" ON "public"."notifications" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_notifications_expires_at" ON "public"."notifications" USING "btree" ("expires_at") WHERE ("expires_at" IS NOT NULL);



CREATE INDEX "idx_notifications_is_read" ON "public"."notifications" USING "btree" ("is_read") WHERE ("is_read" = false);



CREATE INDEX "idx_notifications_priority" ON "public"."notifications" USING "btree" ("priority");



CREATE INDEX "idx_notifications_reference" ON "public"."notifications" USING "btree" ("reference_type", "reference_id") WHERE ("reference_type" IS NOT NULL);



CREATE INDEX "idx_notifications_type" ON "public"."notifications" USING "btree" ("type");



CREATE INDEX "idx_notifications_user_created" ON "public"."notifications" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_notifications_user_id" ON "public"."notifications" USING "btree" ("user_id");



CREATE INDEX "idx_order_items_asin" ON "public"."order_items" USING "btree" ("asin");



CREATE INDEX "idx_order_items_order_id" ON "public"."order_items" USING "btree" ("order_id");



CREATE INDEX "idx_orders_cod_collection_status" ON "public"."orders" USING "btree" ("cod_collection_status");



CREATE INDEX "idx_orders_cod_verified" ON "public"."orders" USING "btree" ("cod_verified") WHERE ("cod_verified" = true);



CREATE INDEX "idx_orders_created_at" ON "public"."orders" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_orders_middle_man" ON "public"."orders" USING "btree" ("middle_man_id");



CREATE INDEX "idx_orders_middleman_status" ON "public"."orders" USING "btree" ("middle_man_id", "status") WHERE ("middle_man_id" IS NOT NULL);



CREATE INDEX "idx_orders_payment_status" ON "public"."orders" USING "btree" ("payment_status", "created_at" DESC);



CREATE INDEX "idx_orders_seller_id" ON "public"."orders" USING "btree" ("seller_id");



CREATE INDEX "idx_orders_seller_status_date" ON "public"."orders" USING "btree" ("seller_id", "status", "created_at" DESC) WHERE ("status" <> 'cancelled'::"text");



CREATE INDEX "idx_orders_status" ON "public"."orders" USING "btree" ("status");



CREATE INDEX "idx_orders_status_created" ON "public"."orders" USING "btree" ("status", "created_at" DESC);



CREATE INDEX "idx_orders_user_id" ON "public"."orders" USING "btree" ("user_id");



CREATE INDEX "idx_orders_user_status_created" ON "public"."orders" USING "btree" ("user_id", "status", "created_at" DESC);



CREATE INDEX "idx_participants_conversation" ON "public"."conversation_participants" USING "btree" ("conversation_id");



CREATE INDEX "idx_participants_conversation_id" ON "public"."conversation_participants" USING "btree" ("conversation_id");



CREATE INDEX "idx_participants_user" ON "public"."conversation_participants" USING "btree" ("user_id");



CREATE INDEX "idx_participants_user_id" ON "public"."conversation_participants" USING "btree" ("user_id");



CREATE INDEX "idx_patient_archives_date" ON "public"."health_patient_archives" USING "btree" ("backup_date");



CREATE INDEX "idx_patient_archives_doctor" ON "public"."health_patient_archives" USING "btree" ("doctor_id");



CREATE INDEX "idx_patient_archives_patient" ON "public"."health_patient_archives" USING "btree" ("patient_id");



CREATE INDEX "idx_patient_archives_sync" ON "public"."health_patient_archives" USING "btree" ("is_synced") WHERE ("is_synced" = false);



CREATE INDEX "idx_patient_preferences_patient" ON "public"."patient_medicine_preferences" USING "btree" ("patient_id");



CREATE INDEX "idx_patient_preferences_type" ON "public"."patient_medicine_preferences" USING "btree" ("preference_type");



CREATE INDEX "idx_payment_splits_order" ON "public"."payment_splits" USING "btree" ("order_id");



CREATE INDEX "idx_payment_splits_recipient" ON "public"."payment_splits" USING "btree" ("recipient_id");



CREATE INDEX "idx_payment_splits_status" ON "public"."payment_splits" USING "btree" ("status");



CREATE INDEX "idx_payment_splits_transaction" ON "public"."payment_splits" USING "btree" ("payment_transaction_id");



CREATE INDEX "idx_payment_transactions_created" ON "public"."payment_transactions" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_payment_transactions_gateway" ON "public"."payment_transactions" USING "btree" ("gateway_transaction_id");



CREATE INDEX "idx_payment_transactions_order" ON "public"."payment_transactions" USING "btree" ("order_id");



CREATE INDEX "idx_payment_transactions_status" ON "public"."payment_transactions" USING "btree" ("status");



CREATE INDEX "idx_payment_transactions_user" ON "public"."payment_transactions" USING "btree" ("user_id");



CREATE INDEX "idx_payouts_created" ON "public"."payouts" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_payouts_status" ON "public"."payouts" USING "btree" ("status");



CREATE INDEX "idx_payouts_user" ON "public"."payouts" USING "btree" ("user_id");



CREATE INDEX "idx_payouts_wallet" ON "public"."payouts" USING "btree" ("wallet_id");



CREATE INDEX "idx_pharmacy_activity_action" ON "public"."pharmacy_activity_logs" USING "btree" ("action");



CREATE INDEX "idx_pharmacy_activity_created" ON "public"."pharmacy_activity_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_pharmacy_activity_pharmacy" ON "public"."pharmacy_activity_logs" USING "btree" ("pharmacy_id");



CREATE INDEX "idx_pharmacy_activity_user" ON "public"."pharmacy_activity_logs" USING "btree" ("user_id");



CREATE INDEX "idx_pharmacy_inventory_available" ON "public"."pharmacy_medicine_inventory" USING "btree" ("is_available") WHERE ("is_available" = true);



CREATE INDEX "idx_pharmacy_inventory_expiry" ON "public"."pharmacy_medicine_inventory" USING "btree" ("expiry_date");



CREATE INDEX "idx_pharmacy_inventory_pharmacy" ON "public"."pharmacy_medicine_inventory" USING "btree" ("pharmacy_id");



CREATE INDEX "idx_pharmacy_inventory_product" ON "public"."pharmacy_medicine_inventory" USING "btree" ("product_id");



CREATE INDEX "idx_pharmacy_inventory_qr" ON "public"."pharmacy_medicine_inventory" USING "btree" ("qr_code");



CREATE INDEX "idx_pharmacy_profiles_location" ON "public"."pharmacy_profiles" USING "btree" ("location_lat", "location_lng");



CREATE INDEX "idx_pharmacy_profiles_location_lat" ON "public"."pharmacy_profiles" USING "btree" ("location_lat");



CREATE INDEX "idx_pharmacy_profiles_location_lng" ON "public"."pharmacy_profiles" USING "btree" ("location_lng");



CREATE INDEX "idx_pharmacy_profiles_user" ON "public"."pharmacy_profiles" USING "btree" ("user_id");



CREATE INDEX "idx_pharmacy_profiles_verified" ON "public"."pharmacy_profiles" USING "btree" ("is_verified");



CREATE INDEX "idx_post_comments_post_id" ON "public"."post_comments" USING "btree" ("post_id");



CREATE INDEX "idx_post_likes_post_id" ON "public"."post_likes" USING "btree" ("post_id");



CREATE INDEX "idx_posts_created_at" ON "public"."posts" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_posts_product_id" ON "public"."posts" USING "btree" ("product_id");



CREATE INDEX "idx_posts_seller_id" ON "public"."posts" USING "btree" ("seller_id");



CREATE INDEX "idx_posts_user_id" ON "public"."posts" USING "btree" ("user_id");



CREATE INDEX "idx_prescription_access_log_date" ON "public"."health_prescription_access_log" USING "btree" ("accessed_at");



CREATE INDEX "idx_prescription_access_log_prescription" ON "public"."health_prescription_access_log" USING "btree" ("prescription_id");



CREATE INDEX "idx_prescription_access_log_user" ON "public"."health_prescription_access_log" USING "btree" ("user_id");



CREATE INDEX "idx_prescription_audit_log_date" ON "public"."health_prescription_audit_log" USING "btree" ("created_at");



CREATE INDEX "idx_prescription_audit_log_prescription" ON "public"."health_prescription_audit_log" USING "btree" ("prescription_id");



CREATE INDEX "idx_prescription_fulfillment_commission" ON "public"."prescription_fulfillment" USING "btree" ("commission_paid") WHERE ("commission_paid" = false);



CREATE INDEX "idx_prescription_fulfillment_order" ON "public"."prescription_fulfillment" USING "btree" ("medicine_order_id");



CREATE INDEX "idx_prescription_fulfillment_prescription" ON "public"."prescription_fulfillment" USING "btree" ("prescription_id");



CREATE INDEX "idx_prescription_medicines_digital_dispensed" ON "public"."health_prescription_medicines_digital" USING "btree" ("is_dispensed");



CREATE INDEX "idx_prescription_medicines_digital_medicine" ON "public"."health_prescription_medicines_digital" USING "btree" ("medicine_id");



CREATE INDEX "idx_prescription_medicines_digital_prescription" ON "public"."health_prescription_medicines_digital" USING "btree" ("prescription_id");



CREATE INDEX "idx_prescription_shares_prescription" ON "public"."health_prescription_shares" USING "btree" ("prescription_id");



CREATE INDEX "idx_prescription_shares_token" ON "public"."health_prescription_shares" USING "btree" ("share_token");



CREATE INDEX "idx_prescriptions_digital_date" ON "public"."health_prescriptions_digital" USING "btree" ("prescription_date");



CREATE INDEX "idx_prescriptions_digital_doctor" ON "public"."health_prescriptions_digital" USING "btree" ("doctor_id");



CREATE INDEX "idx_prescriptions_digital_patient" ON "public"."health_prescriptions_digital" USING "btree" ("patient_id");



CREATE INDEX "idx_prescriptions_digital_status" ON "public"."health_prescriptions_digital" USING "btree" ("status");



CREATE INDEX "idx_products_attributes" ON "public"."products" USING "gin" ("attributes");



CREATE INDEX "idx_products_brand" ON "public"."products" USING "btree" ("brand");



CREATE INDEX "idx_products_category" ON "public"."products" USING "btree" ("category");



CREATE INDEX "idx_products_created_at" ON "public"."products" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_products_created_desc" ON "public"."products" USING "btree" ("created_at" DESC) WHERE ("status" = 'active'::"text");



CREATE INDEX "idx_products_price" ON "public"."products" USING "btree" ("price");



CREATE INDEX "idx_products_quantity" ON "public"."products" USING "btree" ("quantity") WHERE ("status" = 'active'::"text");



CREATE INDEX "idx_products_search" ON "public"."products" USING "gin" ("title_description");



CREATE INDEX "idx_products_seller_id" ON "public"."products" USING "btree" ("seller_id");



CREATE INDEX "idx_products_seller_status_price" ON "public"."products" USING "btree" ("seller_id", "status", "price");



CREATE INDEX "idx_products_status" ON "public"."products" USING "btree" ("status");



CREATE INDEX "idx_products_subcategory" ON "public"."products" USING "btree" ("subcategory");



CREATE INDEX "idx_profiles_is_admin" ON "public"."profiles" USING "btree" ("is_admin");



CREATE INDEX "idx_purchases_buyer" ON "public"."marketplace_purchases" USING "btree" ("buyer_id");



CREATE INDEX "idx_purchases_payment_status" ON "public"."marketplace_purchases" USING "btree" ("payment_status");



CREATE INDEX "idx_purchases_template" ON "public"."marketplace_purchases" USING "btree" ("template_id");



CREATE INDEX "idx_qr_scan_logs_created" ON "public"."pharmacy_qr_scan_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_qr_scan_logs_pharmacy" ON "public"."pharmacy_qr_scan_logs" USING "btree" ("pharmacy_id");



CREATE INDEX "idx_qr_scan_logs_qr" ON "public"."pharmacy_qr_scan_logs" USING "btree" ("qr_code");



CREATE INDEX "idx_qr_scan_logs_user" ON "public"."pharmacy_qr_scan_logs" USING "btree" ("user_id");



CREATE INDEX "idx_reviews_asin" ON "public"."reviews" USING "btree" ("asin");



CREATE INDEX "idx_reviews_user_id" ON "public"."reviews" USING "btree" ("user_id");



CREATE INDEX "idx_sellers_location" ON "public"."sellers" USING "btree" ("latitude", "longitude");



CREATE INDEX "idx_sellers_slug" ON "public"."sellers" USING "btree" ("store_slug");



CREATE UNIQUE INDEX "idx_sellers_store_slug_unique" ON "public"."sellers" USING "btree" ("store_slug") WHERE ("store_slug" IS NOT NULL);



CREATE INDEX "idx_sellers_template" ON "public"."sellers" USING "btree" ("current_template_id");



CREATE INDEX "idx_services_category" ON "public"."services" USING "btree" ("category", "subcategory");



CREATE INDEX "idx_services_provider" ON "public"."services" USING "btree" ("provider_id", "provider_type");



CREATE INDEX "idx_shop_products_shop_id" ON "public"."shop_products" USING "btree" ("shop_id");



CREATE INDEX "idx_shop_products_shop_position" ON "public"."shop_products" USING "btree" ("shop_id", "position");



CREATE INDEX "idx_shop_templates_status_type" ON "public"."shop_templates" USING "btree" ("status", "shop_type");



CREATE INDEX "idx_shops_customers" ON "public"."shops" USING "gin" ("customers");



CREATE INDEX "idx_shops_owner_id" ON "public"."shops" USING "btree" ("owner_id");



CREATE INDEX "idx_shops_owner_status" ON "public"."shops" USING "btree" ("owner_id", "status");



CREATE INDEX "idx_shops_settings" ON "public"."shops" USING "gin" ("settings");



CREATE INDEX "idx_shops_slug" ON "public"."shops" USING "btree" ("slug");



CREATE INDEX "idx_site_catalog_user_active" ON "public"."site_catalog" USING "btree" ("user_id") WHERE ("is_active" = true);



CREATE INDEX "idx_stock_movements_inventory" ON "public"."pharmacy_stock_movements" USING "btree" ("inventory_id");



CREATE INDEX "idx_stock_movements_pharmacy" ON "public"."pharmacy_stock_movements" USING "btree" ("pharmacy_id");



CREATE INDEX "idx_stock_movements_type" ON "public"."pharmacy_stock_movements" USING "btree" ("movement_type");



CREATE INDEX "idx_store_configs_mid" ON "public"."middleman_store_configs" USING "btree" ("middleman_id");



CREATE INDEX "idx_store_configs_slug" ON "public"."middleman_store_configs" USING "btree" ("store_slug");



CREATE INDEX "idx_store_products_asin" ON "public"."store_products" USING "btree" ("asin");



CREATE INDEX "idx_store_products_profile" ON "public"."store_products" USING "btree" ("profile_id");



CREATE INDEX "idx_subcategories_category" ON "public"."subcategories" USING "btree" ("category_id");



CREATE INDEX "idx_svc_categories_active" ON "public"."svc_categories" USING "btree" ("is_active");



CREATE INDEX "idx_svc_listings_active" ON "public"."svc_listings" USING "btree" ("is_active");



CREATE INDEX "idx_svc_listings_category" ON "public"."svc_listings" USING "btree" ("category_id");



CREATE INDEX "idx_svc_listings_category_id" ON "public"."svc_listings" USING "btree" ("category_id");



CREATE INDEX "idx_svc_listings_provider_id" ON "public"."svc_listings" USING "btree" ("provider_id");



CREATE INDEX "idx_svc_listings_rating" ON "public"."svc_listings" USING "btree" ("rating" DESC NULLS LAST);



CREATE INDEX "idx_svc_listings_status" ON "public"."svc_listings" USING "btree" ("status");



CREATE INDEX "idx_svc_listings_subcategory" ON "public"."svc_listings" USING "btree" ("subcategory_id") WHERE "is_active";



CREATE INDEX "idx_svc_listings_type" ON "public"."svc_listings" USING "btree" ("listing_type");



CREATE INDEX "idx_svc_messages_conversation" ON "public"."svc_messages" USING "btree" ("conversation_id", "created_at" DESC);



CREATE INDEX "idx_svc_orders_listing_id" ON "public"."svc_orders" USING "btree" ("listing_id");



CREATE INDEX "idx_svc_orders_provider" ON "public"."svc_orders" USING "btree" ("provider_id");



CREATE INDEX "idx_svc_orders_provider_id" ON "public"."svc_orders" USING "btree" ("provider_id");



CREATE INDEX "idx_svc_orders_status" ON "public"."svc_orders" USING "btree" ("status");



CREATE INDEX "idx_svc_orders_user" ON "public"."svc_orders" USING "btree" ("user_id");



CREATE INDEX "idx_svc_orders_user_id" ON "public"."svc_orders" USING "btree" ("user_id");



CREATE INDEX "idx_svc_packages_listing_id" ON "public"."svc_listing_packages" USING "btree" ("listing_id");



CREATE INDEX "idx_svc_providers_location" ON "public"."svc_providers" USING "btree" ("location_city");



CREATE INDEX "idx_svc_providers_specialties" ON "public"."svc_providers" USING "gin" ("specialties");



CREATE INDEX "idx_svc_providers_status" ON "public"."svc_providers" USING "btree" ("status");



CREATE INDEX "idx_svc_providers_type" ON "public"."svc_providers" USING "btree" ("provider_type");



CREATE INDEX "idx_svc_reviews_order_visible" ON "public"."svc_reviews" USING "btree" ("order_id", "is_visible");



CREATE INDEX "idx_svc_reviews_provider_visible" ON "public"."svc_reviews" USING "btree" ("provider_id", "is_visible");



CREATE INDEX "idx_template_requests_status" ON "public"."template_requests" USING "btree" ("status");



CREATE INDEX "idx_templates_active" ON "public"."templates" USING "btree" ("is_active");



CREATE INDEX "idx_templates_category" ON "public"."templates" USING "btree" ("category");



CREATE INDEX "idx_typing_indicators_conversation" ON "public"."health_typing_indicators" USING "btree" ("conversation_id");



CREATE INDEX "idx_user_events_created_at" ON "public"."user_events" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_user_events_type" ON "public"."user_events" USING "btree" ("event_type");



CREATE INDEX "idx_user_events_user_id" ON "public"."user_events" USING "btree" ("user_id");



CREATE INDEX "idx_user_template_selections_user_id" ON "public"."user_template_selections" USING "btree" ("user_id");



CREATE INDEX "idx_user_wallets_active" ON "public"."user_wallets" USING "btree" ("is_active") WHERE ("is_active" = true);



CREATE INDEX "idx_user_wallets_balance" ON "public"."user_wallets" USING "btree" ("balance");



CREATE INDEX "idx_user_wallets_user" ON "public"."user_wallets" USING "btree" ("user_id");



CREATE INDEX "idx_users_account_type" ON "public"."users" USING "btree" ("account_type");



CREATE INDEX "idx_users_email" ON "public"."users" USING "btree" ("email");



CREATE INDEX "idx_users_location_gin" ON "public"."users" USING "gin" ("location");



CREATE INDEX "idx_users_onboarding_completed" ON "public"."users" USING "btree" ("onboarding_completed");



CREATE INDEX "idx_wallet_transactions_created" ON "public"."wallet_transactions" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_wallet_transactions_idempotency" ON "public"."wallet_transactions" USING "btree" ("idempotency_key") WHERE ("idempotency_key" IS NOT NULL);



CREATE INDEX "idx_wallet_transactions_reference" ON "public"."wallet_transactions" USING "btree" ("reference_type", "reference_id");



CREATE INDEX "idx_wallet_transactions_type" ON "public"."wallet_transactions" USING "btree" ("transaction_type");



CREATE INDEX "idx_wallet_transactions_user" ON "public"."wallet_transactions" USING "btree" ("user_id");



CREATE INDEX "idx_wallet_transactions_wallet" ON "public"."wallet_transactions" USING "btree" ("wallet_id");



CREATE INDEX "idx_webhook_logs_created" ON "public"."payment_webhook_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_webhook_logs_gateway" ON "public"."payment_webhook_logs" USING "btree" ("payment_gateway", "gateway_transaction_id");



CREATE INDEX "idx_webhook_logs_processed" ON "public"."payment_webhook_logs" USING "btree" ("processed") WHERE ("processed" = false);



CREATE INDEX "idx_wishlist_user_id" ON "public"."wishlist" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "decrement_inventory_on_order_item" AFTER INSERT ON "public"."order_items" FOR EACH ROW EXECUTE FUNCTION "public"."decrement_product_inventory"();



CREATE OR REPLACE TRIGGER "generate_product_description_trigger" BEFORE INSERT OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."generate_product_description"();



CREATE OR REPLACE TRIGGER "order_notification_trigger" AFTER UPDATE OF "status" ON "public"."orders" FOR EACH ROW WHEN (("old"."status" IS DISTINCT FROM "new"."status")) EXECUTE FUNCTION "public"."create_order_notification"();



CREATE OR REPLACE TRIGGER "products_tsvector_update" BEFORE INSERT OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."products_tsvector_trigger"();



CREATE OR REPLACE TRIGGER "set_conversations_updated_at" BEFORE UPDATE ON "public"."conversations" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_hospitals_updated_at" BEFORE UPDATE ON "public"."hospitals" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_auto_generate_description" BEFORE INSERT ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."auto_generate_product_description"();



CREATE OR REPLACE TRIGGER "trg_create_health_conversation_on_appointment" AFTER INSERT OR UPDATE OF "status" ON "public"."health_appointments" FOR EACH ROW EXECUTE FUNCTION "public"."create_health_conversation_on_appointment"();



CREATE OR REPLACE TRIGGER "trg_decrement_inventory_on_order_confirmed" AFTER UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."decrement_product_inventory_on_order"();



CREATE OR REPLACE TRIGGER "trg_enforce_middleman_limit" BEFORE INSERT OR UPDATE OF "display_price", "is_active" ON "public"."site_catalog" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_middleman_catalog_limit"();



CREATE OR REPLACE TRIGGER "trg_log_payment_status_change" AFTER UPDATE ON "public"."payment_intentions" FOR EACH ROW WHEN (("old"."status" IS DISTINCT FROM "new"."status")) EXECUTE FUNCTION "public"."log_payment_status_change"();



CREATE OR REPLACE TRIGGER "trg_log_wallet_transaction" AFTER UPDATE ON "public"."user_wallets" FOR EACH ROW WHEN (("old"."balance" IS DISTINCT FROM "new"."balance")) EXECUTE FUNCTION "public"."log_wallet_transaction"();



CREATE OR REPLACE TRIGGER "trg_low_stock_alert" AFTER INSERT OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."check_low_stock_and_notify"();



CREATE OR REPLACE TRIGGER "trg_profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_profiles_updated_at"();



CREATE OR REPLACE TRIGGER "trg_push_low_stock_alert" AFTER INSERT OR UPDATE ON "public"."health_medicines" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_push_low_stock_alert"();



CREATE OR REPLACE TRIGGER "trg_push_medicine_order_status" AFTER UPDATE ON "public"."health_medicine_orders" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_push_on_medicine_order_status"();



CREATE OR REPLACE TRIGGER "trg_push_payment_received" AFTER UPDATE ON "public"."payment_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_push_payment_received"();



CREATE OR REPLACE TRIGGER "trg_push_prescription_created" AFTER INSERT ON "public"."health_prescriptions" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_push_on_prescription_created"();



CREATE OR REPLACE TRIGGER "trg_restore_inventory_on_order_cancelled" AFTER UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."restore_product_inventory_on_cancel"();



CREATE OR REPLACE TRIGGER "trg_svc_booking_completed" AFTER UPDATE ON "public"."svc_orders" FOR EACH ROW EXECUTE FUNCTION "public"."auto_credit_service_provider"();



CREATE OR REPLACE TRIGGER "trg_update_conversation_unread" AFTER INSERT OR UPDATE ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."update_conversation_unread_count"();



CREATE OR REPLACE TRIGGER "trg_update_health_conversation_on_message" AFTER INSERT ON "public"."health_messages" FOR EACH ROW EXECUTE FUNCTION "public"."update_health_conversation_on_message"();



CREATE OR REPLACE TRIGGER "trg_update_order_payment_status" AFTER UPDATE ON "public"."payment_intentions" FOR EACH ROW EXECUTE FUNCTION "public"."update_order_payment_status"();



CREATE OR REPLACE TRIGGER "trg_update_product_rating" AFTER INSERT OR DELETE OR UPDATE ON "public"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."update_product_rating"();



CREATE OR REPLACE TRIGGER "trg_update_seller_product_count" AFTER INSERT OR DELETE OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."update_seller_product_count"();



CREATE OR REPLACE TRIGGER "trg_update_seller_stats_on_order_delivered" AFTER UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."update_seller_stats_on_order_delivered"();



CREATE OR REPLACE TRIGGER "trg_validate_product_price" BEFORE INSERT OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."validate_product_price"();



CREATE OR REPLACE TRIGGER "trg_verify_purchase_review" BEFORE INSERT ON "public"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."verify_purchase_before_review"();



CREATE OR REPLACE TRIGGER "trigger_calculate_commission" BEFORE INSERT OR UPDATE OF "deal_id", "subtotal" ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_order_commission"();



CREATE OR REPLACE TRIGGER "trigger_calculate_middle_man_commission" AFTER UPDATE OF "status" ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_middle_man_commission"();



CREATE OR REPLACE TRIGGER "trigger_cleanup_product_images" BEFORE UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."cleanup_product_images"();



CREATE OR REPLACE TRIGGER "trigger_create_cod_verification_on_order" AFTER INSERT ON "public"."orders" FOR EACH ROW WHEN (("new"."payment_method" = 'cod'::"text")) EXECUTE FUNCTION "public"."create_cod_verification_on_order"();



CREATE OR REPLACE TRIGGER "trigger_lock_account_type" BEFORE UPDATE ON "public"."conversation_participants" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_account_type_change"();



CREATE OR REPLACE TRIGGER "trigger_log_payout_changes" AFTER INSERT OR UPDATE ON "public"."payouts" FOR EACH ROW EXECUTE FUNCTION "public"."log_payment_activity"();



CREATE OR REPLACE TRIGGER "trigger_log_wallet_changes" AFTER INSERT OR UPDATE ON "public"."user_wallets" FOR EACH ROW EXECUTE FUNCTION "public"."log_payment_activity"();



CREATE OR REPLACE TRIGGER "trigger_notifications_updated_at" BEFORE UPDATE ON "public"."notifications" FOR EACH ROW EXECUTE FUNCTION "public"."update_notifications_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_svc_rating" AFTER INSERT ON "public"."svc_reviews" FOR EACH ROW EXECUTE FUNCTION "public"."update_svc_provider_rating"();



CREATE OR REPLACE TRIGGER "trigger_svc_stats" AFTER UPDATE ON "public"."svc_orders" FOR EACH ROW EXECUTE FUNCTION "public"."update_svc_provider_stats"();



CREATE OR REPLACE TRIGGER "trigger_sync_account_type" BEFORE INSERT ON "public"."conversation_participants" FOR EACH ROW EXECUTE FUNCTION "public"."sync_participant_account_type"();



CREATE OR REPLACE TRIGGER "trigger_update_factory_connections_timestamp" BEFORE UPDATE ON "public"."factory_connections" FOR EACH ROW EXECUTE FUNCTION "public"."update_factory_connections_timestamp"();



CREATE OR REPLACE TRIGGER "trigger_update_patient_visits" AFTER UPDATE ON "public"."health_appointments" FOR EACH ROW EXECUTE FUNCTION "public"."update_patient_visit_count"();



CREATE OR REPLACE TRIGGER "trigger_update_post_comments" AFTER INSERT OR DELETE ON "public"."post_comments" FOR EACH ROW EXECUTE FUNCTION "public"."update_post_comments_count"();



CREATE OR REPLACE TRIGGER "trigger_update_post_likes" AFTER INSERT OR DELETE ON "public"."post_likes" FOR EACH ROW EXECUTE FUNCTION "public"."update_post_likes_count"();



CREATE OR REPLACE TRIGGER "trigger_validate_transaction_balance" BEFORE INSERT ON "public"."wallet_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."validate_wallet_balance"();



CREATE OR REPLACE TRIGGER "trigger_validate_wallet_balance" BEFORE INSERT OR UPDATE ON "public"."user_wallets" FOR EACH ROW EXECUTE FUNCTION "public"."validate_wallet_balance"();



CREATE OR REPLACE TRIGGER "update_delivery_assignments_updated_at" BEFORE UPDATE ON "public"."delivery_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_delivery_assignments_updated_at"();



CREATE OR REPLACE TRIGGER "update_delivery_profiles_updated_at" BEFORE UPDATE ON "public"."delivery_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_delivery_profiles_updated_at"();



CREATE OR REPLACE TRIGGER "update_factory_profile_updated_at" BEFORE UPDATE ON "public"."factory_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_factory_profile_updated_at"();



CREATE OR REPLACE TRIGGER "update_health_appt_timestamp" BEFORE UPDATE ON "public"."health_appointments" FOR EACH ROW EXECUTE FUNCTION "public"."update_health_timestamps"();



CREATE OR REPLACE TRIGGER "update_health_doctor_timestamp" BEFORE UPDATE ON "public"."health_doctor_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_health_timestamps"();



CREATE OR REPLACE TRIGGER "update_health_medicine_order_timestamp" BEFORE UPDATE ON "public"."health_medicine_orders" FOR EACH ROW EXECUTE FUNCTION "public"."update_health_pharmacy_timestamp"();



CREATE OR REPLACE TRIGGER "update_health_medicine_timestamp" BEFORE UPDATE ON "public"."health_medicines" FOR EACH ROW EXECUTE FUNCTION "public"."update_health_pharmacy_timestamp"();



CREATE OR REPLACE TRIGGER "update_health_patient_timestamp" BEFORE UPDATE ON "public"."health_patient_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_health_timestamps"();



CREATE OR REPLACE TRIGGER "update_health_pharmacy_timestamp" BEFORE UPDATE ON "public"."health_pharmacy_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_health_pharmacy_timestamp"();



CREATE OR REPLACE TRIGGER "update_marketplace_updated_at" BEFORE UPDATE ON "public"."website_marketplace" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_medicine_expiry_status_trigger" BEFORE INSERT OR UPDATE ON "public"."pharmacy_medicine_inventory" FOR EACH ROW EXECUTE FUNCTION "public"."update_medicine_expiry_status"();



CREATE OR REPLACE TRIGGER "update_medicine_rating_trigger" AFTER INSERT OR DELETE OR UPDATE ON "public"."health_medicine_reviews" FOR EACH ROW EXECUTE FUNCTION "public"."update_medicine_rating"();



CREATE OR REPLACE TRIGGER "update_medicine_stock_on_order_trigger" AFTER INSERT ON "public"."health_medicine_order_items" FOR EACH ROW EXECUTE FUNCTION "public"."update_medicine_stock_on_order"();



CREATE OR REPLACE TRIGGER "update_order_status_timestamps" BEFORE UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."update_order_status_timestamps"();



CREATE OR REPLACE TRIGGER "update_pharmacy_inventory_updated_at" BEFORE UPDATE ON "public"."pharmacy_medicine_inventory" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_pharmacy_profiles_updated_at" BEFORE UPDATE ON "public"."pharmacy_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shop_templates_updated_at" BEFORE UPDATE ON "public"."shop_templates" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shops_updated_at" BEFORE UPDATE ON "public"."shops" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_store_configs_timestamp" BEFORE UPDATE ON "public"."store_configs" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_svc_listings_search_vector" BEFORE INSERT OR UPDATE ON "public"."svc_listings" FOR EACH ROW EXECUTE FUNCTION "tsvector_update_trigger"('search_vector', 'pg_catalog.english', 'title', 'description');



CREATE OR REPLACE TRIGGER "update_svc_messages_updated_at" BEFORE UPDATE ON "public"."svc_messages" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_template_requests_updated_at" BEFORE UPDATE ON "public"."template_requests" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_website_settings_updated_at" BEFORE UPDATE ON "public"."website_settings" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."admin_users"
    ADD CONSTRAINT "admin_users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."analytics"
    ADD CONSTRAINT "analytics_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."analytics_snapshots"
    ADD CONSTRAINT "analytics_snapshots_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."analytics_uploads"
    ADD CONSTRAINT "analytics_uploads_entity_id_fkey" FOREIGN KEY ("entity_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."app_devices"
    ADD CONSTRAINT "app_devices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."services"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."business_profiles"
    ADD CONSTRAINT "business_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."calls"
    ADD CONSTRAINT "calls_callee_id_fkey" FOREIGN KEY ("callee_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."calls"
    ADD CONSTRAINT "calls_caller_id_fkey" FOREIGN KEY ("caller_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."cart"
    ADD CONSTRAINT "cart_asin_fkey" FOREIGN KEY ("asin") REFERENCES "public"."products"("asin") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."cart"
    ADD CONSTRAINT "cart_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."categories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."cod_collections"
    ADD CONSTRAINT "cod_collections_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."cod_collections"
    ADD CONSTRAINT "cod_collections_disputed_by_fkey" FOREIGN KEY ("disputed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."cod_collections"
    ADD CONSTRAINT "cod_collections_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."cod_collections"
    ADD CONSTRAINT "cod_collections_resolved_by_fkey" FOREIGN KEY ("resolved_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."cod_collections"
    ADD CONSTRAINT "cod_collections_verification_key_id_fkey" FOREIGN KEY ("verification_key_id") REFERENCES "public"."cod_verification_keys"("id");



ALTER TABLE ONLY "public"."cod_verification_keys"
    ADD CONSTRAINT "cod_verification_keys_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."cod_verification_keys"
    ADD CONSTRAINT "cod_verification_keys_verified_by_fkey" FOREIGN KEY ("verified_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."commissions"
    ADD CONSTRAINT "commissions_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."middle_man_deals"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."commissions"
    ADD CONSTRAINT "commissions_middle_man_id_fkey" FOREIGN KEY ("middle_man_id") REFERENCES "public"."middle_men"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."commissions"
    ADD CONSTRAINT "commissions_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."deal_proposals"
    ADD CONSTRAINT "deal_proposals_proposer_id_fkey" FOREIGN KEY ("proposer_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."deal_proposals"
    ADD CONSTRAINT "deal_proposals_recipient_id_fkey" FOREIGN KEY ("recipient_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."deal_proposals"
    ADD CONSTRAINT "deal_proposals_responded_by_fkey" FOREIGN KEY ("responded_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."delivery_assignments"
    ADD CONSTRAINT "delivery_assignments_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "public"."delivery_profiles"("id");



ALTER TABLE ONLY "public"."delivery_assignments"
    ADD CONSTRAINT "delivery_assignments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."delivery_profiles"
    ADD CONSTRAINT "delivery_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."doctor_medicine_deals"
    ADD CONSTRAINT "doctor_medicine_deals_doctor_id_fkey" FOREIGN KEY ("doctor_id") REFERENCES "public"."health_doctor_profiles"("id");



ALTER TABLE ONLY "public"."doctor_medicine_deals"
    ADD CONSTRAINT "doctor_medicine_deals_medicine_id_fkey" FOREIGN KEY ("medicine_id") REFERENCES "public"."health_medicines_master"("id");



ALTER TABLE ONLY "public"."doctor_medicine_deals"
    ADD CONSTRAINT "doctor_medicine_deals_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."health_pharmacy_profiles"("id");



ALTER TABLE ONLY "public"."doctor_performance_metrics"
    ADD CONSTRAINT "doctor_performance_metrics_doctor_id_fkey" FOREIGN KEY ("doctor_id") REFERENCES "public"."health_doctor_profiles"("id");



ALTER TABLE ONLY "public"."doctors"
    ADD CONSTRAINT "doctors_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factories"
    ADD CONSTRAINT "factories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factory_connections"
    ADD CONSTRAINT "factory_connections_factory_id_fkey" FOREIGN KEY ("factory_id") REFERENCES "public"."sellers"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factory_connections"
    ADD CONSTRAINT "factory_connections_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "public"."sellers"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factory_production_logs"
    ADD CONSTRAINT "factory_production_logs_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."factory_production_logs"
    ADD CONSTRAINT "factory_production_logs_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."factory_profiles"
    ADD CONSTRAINT "factory_profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factory_quotes"
    ADD CONSTRAINT "factory_quotes_factory_id_fkey" FOREIGN KEY ("factory_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."factory_quotes"
    ADD CONSTRAINT "factory_quotes_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."factory_quotes"
    ADD CONSTRAINT "factory_quotes_requester_id_fkey" FOREIGN KEY ("requester_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."factory_ratings"
    ADD CONSTRAINT "factory_ratings_factory_id_fkey" FOREIGN KEY ("factory_id") REFERENCES "public"."sellers"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factory_ratings"
    ADD CONSTRAINT "factory_ratings_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "public"."sellers"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_prescription_access_log"
    ADD CONSTRAINT "fk_prescription" FOREIGN KEY ("prescription_id") REFERENCES "public"."health_prescriptions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_prescription_access_log"
    ADD CONSTRAINT "fk_user" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."freelancer_orders"
    ADD CONSTRAINT "freelancer_orders_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."freelancer_orders"
    ADD CONSTRAINT "freelancer_orders_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."freelancer_services"("id");



ALTER TABLE ONLY "public"."freelancer_portfolio"
    ADD CONSTRAINT "freelancer_portfolio_freelancer_id_fkey" FOREIGN KEY ("freelancer_id") REFERENCES "public"."freelancer_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."freelancer_profiles"
    ADD CONSTRAINT "freelancer_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."freelancer_services"
    ADD CONSTRAINT "freelancer_services_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "public"."freelancer_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_appointments"
    ADD CONSTRAINT "health_appointments_doctor_id_fkey" FOREIGN KEY ("doctor_id") REFERENCES "public"."health_doctor_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_appointments"
    ADD CONSTRAINT "health_appointments_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "public"."health_patient_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_chat_attachments"
    ADD CONSTRAINT "health_chat_attachments_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."health_conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_chat_attachments"
    ADD CONSTRAINT "health_chat_attachments_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "public"."health_messages"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."health_chat_attachments"
    ADD CONSTRAINT "health_chat_attachments_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_conversations"
    ADD CONSTRAINT "health_conversations_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "public"."health_appointments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_conversations"
    ADD CONSTRAINT "health_conversations_doctor_id_fkey" FOREIGN KEY ("doctor_id") REFERENCES "public"."health_doctor_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_conversations"
    ADD CONSTRAINT "health_conversations_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "public"."health_patient_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_daily_backup_status"
    ADD CONSTRAINT "health_daily_backup_status_doctor_id_fkey" FOREIGN KEY ("doctor_id") REFERENCES "public"."health_doctor_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_doctor_profiles"
    ADD CONSTRAINT "health_doctor_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_medicine_categories"
    ADD CONSTRAINT "health_medicine_categories_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."health_medicine_categories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."health_medicine_expiry_alerts"
    ADD CONSTRAINT "health_medicine_expiry_alerts_inventory_id_fkey" FOREIGN KEY ("inventory_id") REFERENCES "public"."health_pharmacy_inventory"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_medicine_expiry_alerts"
    ADD CONSTRAINT "health_medicine_expiry_alerts_medicine_id_fkey" FOREIGN KEY ("medicine_id") REFERENCES "public"."health_medicines_master"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_medicine_expiry_alerts"
    ADD CONSTRAINT "health_medicine_expiry_alerts_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."health_pharmacy_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_medicine_expiry_alerts"
    ADD CONSTRAINT "health_medicine_expiry_alerts_resolved_by_fkey" FOREIGN KEY ("resolved_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."health_medicine_order_items"
    ADD CONSTRAINT "health_medicine_order_items_medicine_id_fkey" FOREIGN KEY ("medicine_id") REFERENCES "public"."health_medicines"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_medicine_order_items"
    ADD CONSTRAINT "health_medicine_order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."health_medicine_orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_medicine_order_items"
    ADD CONSTRAINT "health_medicine_order_items_prescription_id_fkey" FOREIGN KEY ("prescription_id") REFERENCES "public"."health_prescriptions"("id");



ALTER TABLE ONLY "public"."health_medicine_orders"
    ADD CONSTRAINT "health_medicine_orders_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "public"."health_patient_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_medicine_orders"
    ADD CONSTRAINT "health_medicine_orders_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."health_pharmacy_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_medicine_orders"
    ADD CONSTRAINT "health_medicine_orders_prescription_id_fkey" FOREIGN KEY ("prescription_id") REFERENCES "public"."health_prescriptions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."health_medicine_recalls"
    ADD CONSTRAINT "health_medicine_recalls_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."health_medicine_recalls"
    ADD CONSTRAINT "health_medicine_recalls_medicine_id_fkey" FOREIGN KEY ("medicine_id") REFERENCES "public"."health_medicines_master"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_medicine_reviews"
    ADD CONSTRAINT "health_medicine_reviews_medicine_id_fkey" FOREIGN KEY ("medicine_id") REFERENCES "public"."health_medicines"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_medicine_reviews"
    ADD CONSTRAINT "health_medicine_reviews_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."health_medicine_orders"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."health_medicine_reviews"
    ADD CONSTRAINT "health_medicine_reviews_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "public"."health_patient_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_medicine_stock_history"
    ADD CONSTRAINT "health_medicine_stock_history_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."health_medicine_stock_history"
    ADD CONSTRAINT "health_medicine_stock_history_medicine_id_fkey" FOREIGN KEY ("medicine_id") REFERENCES "public"."health_medicines"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_medicine_stock_history"
    ADD CONSTRAINT "health_medicine_stock_history_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."health_pharmacy_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_medicines_master"
    ADD CONSTRAINT "health_medicines_master_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."health_medicines"
    ADD CONSTRAINT "health_medicines_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."health_pharmacy_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_message_receipts"
    ADD CONSTRAINT "health_message_receipts_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "public"."health_messages"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_message_receipts"
    ADD CONSTRAINT "health_message_receipts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_messages"
    ADD CONSTRAINT "health_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."health_conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_messages"
    ADD CONSTRAINT "health_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_patient_access_log"
    ADD CONSTRAINT "health_patient_access_log_doctor_id_fkey" FOREIGN KEY ("doctor_id") REFERENCES "public"."health_doctor_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_patient_access_log"
    ADD CONSTRAINT "health_patient_access_log_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "public"."health_patient_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_patient_archives"
    ADD CONSTRAINT "health_patient_archives_doctor_id_fkey" FOREIGN KEY ("doctor_id") REFERENCES "public"."health_doctor_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_patient_archives"
    ADD CONSTRAINT "health_patient_archives_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "public"."health_patient_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_patient_change_log"
    ADD CONSTRAINT "health_patient_change_log_changed_by_fkey" FOREIGN KEY ("changed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."health_patient_change_log"
    ADD CONSTRAINT "health_patient_change_log_doctor_id_fkey" FOREIGN KEY ("doctor_id") REFERENCES "public"."health_doctor_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_patient_change_log"
    ADD CONSTRAINT "health_patient_change_log_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "public"."health_patient_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_patient_profiles"
    ADD CONSTRAINT "health_patient_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_pharmacy_inspections"
    ADD CONSTRAINT "health_pharmacy_inspections_inspector_id_fkey" FOREIGN KEY ("inspector_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."health_pharmacy_inspections"
    ADD CONSTRAINT "health_pharmacy_inspections_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."health_pharmacy_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_pharmacy_inventory"
    ADD CONSTRAINT "health_pharmacy_inventory_medicine_id_fkey" FOREIGN KEY ("medicine_id") REFERENCES "public"."health_medicines_master"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_pharmacy_inventory"
    ADD CONSTRAINT "health_pharmacy_inventory_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."health_pharmacy_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_pharmacy_inventory"
    ADD CONSTRAINT "health_pharmacy_inventory_quality_check_by_fkey" FOREIGN KEY ("quality_check_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."health_pharmacy_profiles"
    ADD CONSTRAINT "health_pharmacy_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_prescription_audit_log"
    ADD CONSTRAINT "health_prescription_audit_log_prescription_id_fkey" FOREIGN KEY ("prescription_id") REFERENCES "public"."health_prescriptions_digital"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_prescription_medicines_digital"
    ADD CONSTRAINT "health_prescription_medicines_dig_dispensed_by_pharmacy_id_fkey" FOREIGN KEY ("dispensed_by_pharmacy_id") REFERENCES "public"."health_pharmacy_profiles"("id");



ALTER TABLE ONLY "public"."health_prescription_medicines_digital"
    ADD CONSTRAINT "health_prescription_medicines_digital_medicine_id_fkey" FOREIGN KEY ("medicine_id") REFERENCES "public"."health_medicines_master"("id");



ALTER TABLE ONLY "public"."health_prescription_medicines_digital"
    ADD CONSTRAINT "health_prescription_medicines_digital_pharmacy_medicine_id_fkey" FOREIGN KEY ("pharmacy_medicine_id") REFERENCES "public"."health_medicines"("id");



ALTER TABLE ONLY "public"."health_prescription_medicines_digital"
    ADD CONSTRAINT "health_prescription_medicines_digital_prescription_id_fkey" FOREIGN KEY ("prescription_id") REFERENCES "public"."health_prescriptions_digital"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_prescription_medicines"
    ADD CONSTRAINT "health_prescription_medicines_dispensed_by_fkey" FOREIGN KEY ("dispensed_by") REFERENCES "public"."health_pharmacy_profiles"("id");



ALTER TABLE ONLY "public"."health_prescription_medicines"
    ADD CONSTRAINT "health_prescription_medicines_medicine_id_fkey" FOREIGN KEY ("medicine_id") REFERENCES "public"."health_medicines"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."health_prescription_medicines"
    ADD CONSTRAINT "health_prescription_medicines_prescription_id_fkey" FOREIGN KEY ("prescription_id") REFERENCES "public"."health_prescriptions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_prescription_shares"
    ADD CONSTRAINT "health_prescription_shares_prescription_id_fkey" FOREIGN KEY ("prescription_id") REFERENCES "public"."health_prescriptions_digital"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_prescription_shares"
    ADD CONSTRAINT "health_prescription_shares_shared_with_pharmacy_id_fkey" FOREIGN KEY ("shared_with_pharmacy_id") REFERENCES "public"."health_pharmacy_profiles"("id");



ALTER TABLE ONLY "public"."health_prescriptions"
    ADD CONSTRAINT "health_prescriptions_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "public"."health_appointments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_prescriptions_digital"
    ADD CONSTRAINT "health_prescriptions_digital_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "public"."health_appointments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_prescriptions_digital"
    ADD CONSTRAINT "health_prescriptions_digital_doctor_id_fkey" FOREIGN KEY ("doctor_id") REFERENCES "public"."health_doctor_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_prescriptions_digital"
    ADD CONSTRAINT "health_prescriptions_digital_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "public"."health_patient_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_prescriptions_digital"
    ADD CONSTRAINT "health_prescriptions_digital_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."health_pharmacy_profiles"("id");



ALTER TABLE ONLY "public"."health_reviews"
    ADD CONSTRAINT "health_reviews_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "public"."health_appointments"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."health_reviews"
    ADD CONSTRAINT "health_reviews_doctor_id_fkey" FOREIGN KEY ("doctor_id") REFERENCES "public"."health_doctor_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_reviews"
    ADD CONSTRAINT "health_reviews_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_typing_indicators"
    ADD CONSTRAINT "health_typing_indicators_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."health_conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_typing_indicators"
    ADD CONSTRAINT "health_typing_indicators_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."healthcare_provider_profiles"
    ADD CONSTRAINT "healthcare_provider_profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."hospitals"
    ADD CONSTRAINT "hospitals_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."marketplace_purchases"
    ADD CONSTRAINT "marketplace_purchases_buyer_id_fkey" FOREIGN KEY ("buyer_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."marketplace_purchases"
    ADD CONSTRAINT "marketplace_purchases_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."website_marketplace"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."marketplace_purchases"
    ADD CONSTRAINT "marketplace_purchases_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "public"."payment_transactions"("id");



ALTER TABLE ONLY "public"."medical_staff"
    ADD CONSTRAINT "medical_staff_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "public"."healthcare_provider_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."medical_staff"
    ADD CONSTRAINT "medical_staff_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."medicine_sales_analytics"
    ADD CONSTRAINT "medicine_sales_analytics_medicine_id_fkey" FOREIGN KEY ("medicine_id") REFERENCES "public"."health_medicines_master"("id");



ALTER TABLE ONLY "public"."medicine_sales_analytics"
    ADD CONSTRAINT "medicine_sales_analytics_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."health_pharmacy_profiles"("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."middle_man_deals"
    ADD CONSTRAINT "middle_man_deals_middle_man_id_fkey" FOREIGN KEY ("middle_man_id") REFERENCES "public"."middle_men"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."middle_man_deals"
    ADD CONSTRAINT "middle_man_deals_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."middle_man_deals"
    ADD CONSTRAINT "middle_man_deals_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."middle_men"
    ADD CONSTRAINT "middle_men_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."middleman_connections"
    ADD CONSTRAINT "middleman_connections_middleman_id_fkey" FOREIGN KEY ("middleman_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."middleman_connections"
    ADD CONSTRAINT "middleman_connections_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."middleman_profiles"
    ADD CONSTRAINT "middleman_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."middleman_seller_links"
    ADD CONSTRAINT "middleman_seller_links_middleman_id_fkey" FOREIGN KEY ("middleman_id") REFERENCES "public"."users"("user_id");



ALTER TABLE ONLY "public"."middleman_seller_links"
    ADD CONSTRAINT "middleman_seller_links_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "public"."users"("user_id");



ALTER TABLE ONLY "public"."middleman_seller_links"
    ADD CONSTRAINT "middleman_seller_links_seller_shop_id_fkey" FOREIGN KEY ("seller_shop_id") REFERENCES "public"."shops"("id");



ALTER TABLE ONLY "public"."middleman_store_configs"
    ADD CONSTRAINT "middleman_store_configs_middleman_id_fkey" FOREIGN KEY ("middleman_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_settings"
    ADD CONSTRAINT "notification_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_templates"
    ADD CONSTRAINT "notification_templates_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_cod_collected_by_fkey" FOREIGN KEY ("cod_collected_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_middle_man_id_fkey" FOREIGN KEY ("middle_man_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_shipping_address_id_fkey" FOREIGN KEY ("shipping_address_id") REFERENCES "public"."shipping_addresses"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patient_medicine_preferences"
    ADD CONSTRAINT "patient_medicine_preferences_medicine_id_fkey" FOREIGN KEY ("medicine_id") REFERENCES "public"."health_medicines_master"("id");



ALTER TABLE ONLY "public"."patient_medicine_preferences"
    ADD CONSTRAINT "patient_medicine_preferences_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "public"."health_patient_profiles"("id");



ALTER TABLE ONLY "public"."patient_medicine_preferences"
    ADD CONSTRAINT "patient_medicine_preferences_preferred_pharmacy_id_fkey" FOREIGN KEY ("preferred_pharmacy_id") REFERENCES "public"."health_pharmacy_profiles"("id");



ALTER TABLE ONLY "public"."payment_intentions"
    ADD CONSTRAINT "payment_intentions_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payment_intentions"
    ADD CONSTRAINT "payment_intentions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payment_splits"
    ADD CONSTRAINT "payment_splits_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payment_splits"
    ADD CONSTRAINT "payment_splits_payment_transaction_id_fkey" FOREIGN KEY ("payment_transaction_id") REFERENCES "public"."payment_transactions"("id");



ALTER TABLE ONLY "public"."payment_splits"
    ADD CONSTRAINT "payment_splits_recipient_id_fkey" FOREIGN KEY ("recipient_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payment_transactions"
    ADD CONSTRAINT "payment_transactions_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."payment_transactions"
    ADD CONSTRAINT "payment_transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payment_transactions"
    ADD CONSTRAINT "payment_transactions_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "public"."user_wallets"("id");



ALTER TABLE ONLY "public"."payout_requests"
    ADD CONSTRAINT "payout_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payouts"
    ADD CONSTRAINT "payouts_processed_by_fkey" FOREIGN KEY ("processed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."payouts"
    ADD CONSTRAINT "payouts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payouts"
    ADD CONSTRAINT "payouts_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "public"."user_wallets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pharmacy_activity_logs"
    ADD CONSTRAINT "pharmacy_activity_logs_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."pharmacy_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pharmacy_activity_logs"
    ADD CONSTRAINT "pharmacy_activity_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pharmacy_daily_reports"
    ADD CONSTRAINT "pharmacy_daily_reports_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."pharmacy_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pharmacy_details"
    ADD CONSTRAINT "pharmacy_details_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "public"."healthcare_provider_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pharmacy_medicine_inventory"
    ADD CONSTRAINT "pharmacy_medicine_inventory_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."pharmacy_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pharmacy_medicine_inventory"
    ADD CONSTRAINT "pharmacy_medicine_inventory_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."pharmacy_medicine_inventory"
    ADD CONSTRAINT "pharmacy_medicine_inventory_quality_check_by_fkey" FOREIGN KEY ("quality_check_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."pharmacy_medicine_inventory"
    ADD CONSTRAINT "pharmacy_medicine_inventory_scanned_by_fkey" FOREIGN KEY ("scanned_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."pharmacy_products"
    ADD CONSTRAINT "pharmacy_products_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."healthcare_provider_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pharmacy_profiles"
    ADD CONSTRAINT "pharmacy_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pharmacy_qr_scan_logs"
    ADD CONSTRAINT "pharmacy_qr_scan_logs_inventory_id_fkey" FOREIGN KEY ("inventory_id") REFERENCES "public"."pharmacy_medicine_inventory"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."pharmacy_qr_scan_logs"
    ADD CONSTRAINT "pharmacy_qr_scan_logs_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."pharmacy_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pharmacy_qr_scan_logs"
    ADD CONSTRAINT "pharmacy_qr_scan_logs_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."pharmacy_qr_scan_logs"
    ADD CONSTRAINT "pharmacy_qr_scan_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pharmacy_stock_movements"
    ADD CONSTRAINT "pharmacy_stock_movements_inventory_id_fkey" FOREIGN KEY ("inventory_id") REFERENCES "public"."pharmacy_medicine_inventory"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pharmacy_stock_movements"
    ADD CONSTRAINT "pharmacy_stock_movements_performed_by_fkey" FOREIGN KEY ("performed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."pharmacy_stock_movements"
    ADD CONSTRAINT "pharmacy_stock_movements_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."pharmacy_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pharmacy_stock_movements"
    ADD CONSTRAINT "pharmacy_stock_movements_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."platform_reports"
    ADD CONSTRAINT "platform_reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."platform_settings"
    ADD CONSTRAINT "platform_settings_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."post_comments"
    ADD CONSTRAINT "post_comments_parent_comment_id_fkey" FOREIGN KEY ("parent_comment_id") REFERENCES "public"."post_comments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_comments"
    ADD CONSTRAINT "post_comments_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_comments"
    ADD CONSTRAINT "post_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_likes"
    ADD CONSTRAINT "post_likes_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_likes"
    ADD CONSTRAINT "post_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."prescription_fulfillment"
    ADD CONSTRAINT "prescription_fulfillment_medicine_order_id_fkey" FOREIGN KEY ("medicine_order_id") REFERENCES "public"."health_medicine_orders"("id");



ALTER TABLE ONLY "public"."prescription_fulfillment"
    ADD CONSTRAINT "prescription_fulfillment_medicine_order_item_id_fkey" FOREIGN KEY ("medicine_order_item_id") REFERENCES "public"."health_medicine_order_items"("id");



ALTER TABLE ONLY "public"."prescription_fulfillment"
    ADD CONSTRAINT "prescription_fulfillment_pharmacy_id_fkey" FOREIGN KEY ("pharmacy_id") REFERENCES "public"."health_pharmacy_profiles"("id");



ALTER TABLE ONLY "public"."prescription_fulfillment"
    ADD CONSTRAINT "prescription_fulfillment_prescription_id_fkey" FOREIGN KEY ("prescription_id") REFERENCES "public"."health_prescriptions"("id");



ALTER TABLE ONLY "public"."prescription_fulfillment"
    ADD CONSTRAINT "prescription_fulfillment_prescription_medicine_id_fkey" FOREIGN KEY ("prescription_medicine_id") REFERENCES "public"."health_prescription_medicines"("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."push_subscriptions"
    ADD CONSTRAINT "push_subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."seller_profiles"
    ADD CONSTRAINT "seller_profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sellers_tmp_test"
    ADD CONSTRAINT "sellers_tmp_test_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sellers"
    ADD CONSTRAINT "sellers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."service_appointments"
    ADD CONSTRAINT "service_appointments_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."service_appointments"
    ADD CONSTRAINT "service_appointments_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "public"."medical_staff"("id");



ALTER TABLE ONLY "public"."services"
    ADD CONSTRAINT "services_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shipping_addresses"
    ADD CONSTRAINT "shipping_addresses_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shop_products"
    ADD CONSTRAINT "shop_products_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shop_products"
    ADD CONSTRAINT "shop_products_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "public"."shops"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shop_templates"
    ADD CONSTRAINT "shop_templates_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."shops"
    ADD CONSTRAINT "shops_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shops"
    ADD CONSTRAINT "shops_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."shop_templates"("id");



ALTER TABLE ONLY "public"."site_catalog"
    ADD CONSTRAINT "site_catalog_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."site_catalog"
    ADD CONSTRAINT "site_catalog_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."site_catalog"
    ADD CONSTRAINT "site_catalog_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."store_configs"
    ADD CONSTRAINT "store_configs_middleman_id_fkey" FOREIGN KEY ("middleman_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."store_configs"
    ADD CONSTRAINT "store_configs_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."templates"("id");



ALTER TABLE ONLY "public"."store_customizations"
    ADD CONSTRAINT "store_customizations_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."middleman_profiles"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."store_products"
    ADD CONSTRAINT "store_products_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."middleman_profiles"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."subcategories"
    ADD CONSTRAINT "subcategories_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."svc_listing_packages"
    ADD CONSTRAINT "svc_listing_packages_listing_id_fkey" FOREIGN KEY ("listing_id") REFERENCES "public"."svc_listings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."svc_listings"
    ADD CONSTRAINT "svc_listings_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."svc_categories"("id");



ALTER TABLE ONLY "public"."svc_listings"
    ADD CONSTRAINT "svc_listings_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "public"."svc_providers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."svc_listings"
    ADD CONSTRAINT "svc_listings_subcategory_id_fkey" FOREIGN KEY ("subcategory_id") REFERENCES "public"."svc_subcategories"("id");



ALTER TABLE ONLY "public"."svc_messages"
    ADD CONSTRAINT "svc_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."svc_orders"
    ADD CONSTRAINT "svc_orders_listing_id_fkey" FOREIGN KEY ("listing_id") REFERENCES "public"."svc_listings"("id");



ALTER TABLE ONLY "public"."svc_orders"
    ADD CONSTRAINT "svc_orders_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "public"."svc_providers"("id");



ALTER TABLE ONLY "public"."svc_orders"
    ADD CONSTRAINT "svc_orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."svc_portfolio"
    ADD CONSTRAINT "svc_portfolio_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "public"."svc_providers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."svc_providers"
    ADD CONSTRAINT "svc_providers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."svc_reviews"
    ADD CONSTRAINT "svc_reviews_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."svc_orders"("id");



ALTER TABLE ONLY "public"."svc_reviews"
    ADD CONSTRAINT "svc_reviews_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "public"."svc_providers"("id");



ALTER TABLE ONLY "public"."svc_reviews"
    ADD CONSTRAINT "svc_reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."svc_subcategories"
    ADD CONSTRAINT "svc_subcategories_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."svc_categories"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."template_requests"
    ADD CONSTRAINT "template_requests_assigned_to_fkey" FOREIGN KEY ("assigned_to") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."template_requests"
    ADD CONSTRAINT "template_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_events"
    ADD CONSTRAINT "user_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_template_selections"
    ADD CONSTRAINT "user_template_selections_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."templates"("id");



ALTER TABLE ONLY "public"."user_template_selections"
    ADD CONSTRAINT "user_template_selections_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_wallets"
    ADD CONSTRAINT "user_wallets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."wallet_transactions"
    ADD CONSTRAINT "wallet_transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."wallet_transactions"
    ADD CONSTRAINT "wallet_transactions_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "public"."user_wallets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."website_integrations"
    ADD CONSTRAINT "website_integrations_website_id_fkey" FOREIGN KEY ("website_id") REFERENCES "public"."websites"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."website_marketplace"
    ADD CONSTRAINT "website_marketplace_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."website_pages"
    ADD CONSTRAINT "website_pages_website_id_fkey" FOREIGN KEY ("website_id") REFERENCES "public"."websites"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."website_settings"
    ADD CONSTRAINT "website_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."websites"
    ADD CONSTRAINT "websites_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."wishlist"
    ADD CONSTRAINT "wishlist_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Admins can create conversations" ON "public"."conversations" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "au"
  WHERE ("au"."user_id" = "auth"."uid"()))));



CREATE POLICY "Admins can manage templates" ON "public"."templates" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."user_id" = "auth"."uid"()) AND ("users"."account_type" = 'admin'::"text")))));



CREATE POLICY "Admins can view all business profiles" ON "public"."business_profiles" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."user_id" = "auth"."uid"()) AND ("users"."account_type" = 'admin'::"text")))));



CREATE POLICY "Admins can view all middleman profiles" ON "public"."middleman_profiles" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."user_id" = "auth"."uid"()) AND ("users"."account_type" = 'admin'::"text")))));



CREATE POLICY "Admins can view all profiles" ON "public"."health_doctor_profiles" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"()))));



CREATE POLICY "Admins can view all template selections" ON "public"."user_template_selections" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."user_id" = "auth"."uid"()) AND ("users"."account_type" = 'admin'::"text")))));



CREATE POLICY "Admins view all reports" ON "public"."platform_reports" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"()))));



CREATE POLICY "Allow seller signup insertions" ON "public"."sellers" FOR INSERT WITH CHECK ((("auth"."uid"() = "user_id") OR (CURRENT_USER = 'postgres'::"name")));



CREATE POLICY "Anyone can read enabled templates" ON "public"."notification_templates" FOR SELECT USING (("enabled" = true));



CREATE POLICY "Anyone can view active templates" ON "public"."templates" FOR SELECT USING (("is_active" = true));



CREATE POLICY "Categories are publicly viewable" ON "public"."categories" FOR SELECT USING (("is_active" = true));



CREATE POLICY "Customers can update their own record" ON "public"."customers" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Customers can view their own record" ON "public"."customers" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Doctors can update own profile" ON "public"."health_doctor_profiles" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Doctors can view own profile" ON "public"."health_doctor_profiles" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Doctors insert own access log" ON "public"."health_patient_access_log" FOR INSERT TO "authenticated" WITH CHECK (("doctor_id" IN ( SELECT "health_doctor_profiles"."id"
   FROM "public"."health_doctor_profiles"
  WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Doctors insert own change log" ON "public"."health_patient_change_log" FOR INSERT TO "authenticated" WITH CHECK (("doctor_id" IN ( SELECT "health_doctor_profiles"."id"
   FROM "public"."health_doctor_profiles"
  WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Doctors insert own patient archives" ON "public"."health_patient_archives" FOR INSERT TO "authenticated" WITH CHECK (("doctor_id" IN ( SELECT "health_doctor_profiles"."id"
   FROM "public"."health_doctor_profiles"
  WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Doctors manage own profile" ON "public"."health_doctor_profiles" TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Doctors update own appointments" ON "public"."health_appointments" FOR UPDATE TO "authenticated" USING (("doctor_id" = "auth"."uid"()));



CREATE POLICY "Doctors view own access log" ON "public"."health_patient_access_log" FOR SELECT TO "authenticated" USING (("doctor_id" IN ( SELECT "health_doctor_profiles"."id"
   FROM "public"."health_doctor_profiles"
  WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Doctors view own appointments" ON "public"."health_appointments" FOR SELECT TO "authenticated" USING (("doctor_id" = "auth"."uid"()));



CREATE POLICY "Doctors view own backup status" ON "public"."health_daily_backup_status" FOR SELECT TO "authenticated" USING (("doctor_id" IN ( SELECT "health_doctor_profiles"."id"
   FROM "public"."health_doctor_profiles"
  WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Doctors view own change log" ON "public"."health_patient_change_log" FOR SELECT TO "authenticated" USING (("doctor_id" IN ( SELECT "health_doctor_profiles"."id"
   FROM "public"."health_doctor_profiles"
  WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Doctors view own patient archives" ON "public"."health_patient_archives" FOR SELECT TO "authenticated" USING (("doctor_id" IN ( SELECT "health_doctor_profiles"."id"
   FROM "public"."health_doctor_profiles"
  WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Freelancers manage own portfolio" ON "public"."freelancer_portfolio" TO "authenticated" USING (("freelancer_id" = ( SELECT "freelancer_profiles"."id"
   FROM "public"."freelancer_profiles"
  WHERE ("freelancer_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Owners can manage store" ON "public"."middleman_store_configs" USING (("auth"."uid"() = "middleman_id"));



CREATE POLICY "Owners manage own hospital" ON "public"."hospitals" USING (("owner_user_id" = "auth"."uid"())) WITH CHECK (("owner_user_id" = "auth"."uid"()));



CREATE POLICY "Patients manage own profile" ON "public"."health_patient_profiles" TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Patients view own appointments" ON "public"."health_appointments" FOR SELECT TO "authenticated" USING (("patient_id" = "auth"."uid"()));



CREATE POLICY "Pharmacies insert own activity logs" ON "public"."pharmacy_activity_logs" FOR INSERT TO "authenticated" WITH CHECK (("pharmacy_id" IN ( SELECT "pharmacy_profiles"."id"
   FROM "public"."pharmacy_profiles"
  WHERE ("pharmacy_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Pharmacies insert own scan logs" ON "public"."pharmacy_qr_scan_logs" FOR INSERT TO "authenticated" WITH CHECK (("pharmacy_id" IN ( SELECT "pharmacy_profiles"."id"
   FROM "public"."pharmacy_profiles"
  WHERE ("pharmacy_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Pharmacies insert own stock movements" ON "public"."pharmacy_stock_movements" FOR INSERT TO "authenticated" WITH CHECK (("pharmacy_id" IN ( SELECT "pharmacy_profiles"."id"
   FROM "public"."pharmacy_profiles"
  WHERE ("pharmacy_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Pharmacies manage own inventory" ON "public"."pharmacy_medicine_inventory" TO "authenticated" USING (("pharmacy_id" IN ( SELECT "pharmacy_profiles"."id"
   FROM "public"."pharmacy_profiles"
  WHERE ("pharmacy_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Pharmacies manage own medicines" ON "public"."health_medicines" TO "authenticated" USING (("pharmacy_id" IN ( SELECT "health_pharmacy_profiles"."id"
   FROM "public"."health_pharmacy_profiles"
  WHERE ("health_pharmacy_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Pharmacies manage own profile" ON "public"."health_pharmacy_profiles" TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Pharmacies update own medicine orders" ON "public"."health_medicine_orders" FOR UPDATE TO "authenticated" USING (("pharmacy_id" IN ( SELECT "health_pharmacy_profiles"."id"
   FROM "public"."health_pharmacy_profiles"
  WHERE ("health_pharmacy_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Pharmacies view own activity logs" ON "public"."pharmacy_activity_logs" FOR SELECT TO "authenticated" USING (("pharmacy_id" IN ( SELECT "pharmacy_profiles"."id"
   FROM "public"."pharmacy_profiles"
  WHERE ("pharmacy_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Pharmacies view own daily reports" ON "public"."pharmacy_daily_reports" FOR SELECT TO "authenticated" USING (("pharmacy_id" IN ( SELECT "pharmacy_profiles"."id"
   FROM "public"."pharmacy_profiles"
  WHERE ("pharmacy_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Pharmacies view own medicine orders" ON "public"."health_medicine_orders" FOR SELECT TO "authenticated" USING (("pharmacy_id" IN ( SELECT "health_pharmacy_profiles"."id"
   FROM "public"."health_pharmacy_profiles"
  WHERE ("health_pharmacy_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Pharmacies view own profile" ON "public"."pharmacy_profiles" TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Pharmacies view own scan logs" ON "public"."pharmacy_qr_scan_logs" FOR SELECT TO "authenticated" USING (("pharmacy_id" IN ( SELECT "pharmacy_profiles"."id"
   FROM "public"."pharmacy_profiles"
  WHERE ("pharmacy_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Pharmacies view own stock history" ON "public"."health_medicine_stock_history" FOR SELECT TO "authenticated" USING (("pharmacy_id" IN ( SELECT "health_pharmacy_profiles"."id"
   FROM "public"."health_pharmacy_profiles"
  WHERE ("health_pharmacy_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Pharmacies view own stock movements" ON "public"."pharmacy_stock_movements" FOR SELECT TO "authenticated" USING (("pharmacy_id" IN ( SELECT "pharmacy_profiles"."id"
   FROM "public"."pharmacy_profiles"
  WHERE ("pharmacy_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Prevent direct inserts - must use API" ON "public"."payment_intentions" FOR INSERT TO "authenticated" WITH CHECK (false);



CREATE POLICY "Public can view published stores" ON "public"."middleman_store_configs" FOR SELECT USING ((("is_published" = true) OR ("auth"."uid"() = "middleman_id")));



CREATE POLICY "Public can view store settings" ON "public"."store_customizations" FOR SELECT USING (true);



CREATE POLICY "Public profiles are viewable by everyone" ON "public"."profiles" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Public view active hospitals" ON "public"."hospitals" FOR SELECT USING (("is_active" = true));



CREATE POLICY "Public view available medicines" ON "public"."health_medicines" FOR SELECT TO "authenticated" USING (("is_available" = true));



CREATE POLICY "Public view freelancer profiles" ON "public"."freelancer_profiles" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Public view portfolio" ON "public"."freelancer_portfolio" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Public view store products" ON "public"."store_products" FOR SELECT USING (true);



CREATE POLICY "Public view verified doctors" ON "public"."health_doctor_profiles" FOR SELECT TO "authenticated" USING (("is_verified" = true));



CREATE POLICY "Public view verified pharmacies" ON "public"."health_pharmacy_profiles" FOR SELECT TO "authenticated" USING (("is_verified" = true));



CREATE POLICY "Public view verified pharmacies" ON "public"."pharmacy_profiles" FOR SELECT TO "authenticated" USING (("is_verified" = true));



CREATE POLICY "Sellers can insert products" ON "public"."products" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "seller_id"));



CREATE POLICY "Sellers can update products" ON "public"."products" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "seller_id"));



CREATE POLICY "Sellers can view own products" ON "public"."products" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "seller_id"));



CREATE POLICY "Service role can insert notifications" ON "public"."notifications" FOR INSERT WITH CHECK (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Service role can manage templates" ON "public"."notification_templates" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Service role can update user profiles" ON "public"."users" USING ((("auth"."jwt"() ->> 'role'::"text") = 'service_role'::"text")) WITH CHECK ((("auth"."jwt"() ->> 'role'::"text") = 'service_role'::"text"));



CREATE POLICY "Service role full access" ON "public"."customers" USING (("auth"."role"() = 'service_role'::"text")) WITH CHECK (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Service role full access" ON "public"."hospitals" USING (("auth"."role"() = 'service_role'::"text")) WITH CHECK (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Service role full access" ON "public"."site_catalog" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Service role full access" ON "public"."website_settings" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Store owners can insert own settings" ON "public"."store_customizations" FOR INSERT WITH CHECK (("auth"."uid"() IN ( SELECT "middleman_profiles"."user_id"
   FROM "public"."middleman_profiles"
  WHERE ("middleman_profiles"."user_id" = "store_customizations"."store_id"))));



CREATE POLICY "Store owners can update own settings" ON "public"."store_customizations" FOR UPDATE USING (("auth"."uid"() IN ( SELECT "middleman_profiles"."user_id"
   FROM "public"."middleman_profiles"
  WHERE ("middleman_profiles"."user_id" = "store_customizations"."store_id"))));



CREATE POLICY "Store owners can view own settings" ON "public"."store_customizations" FOR SELECT USING (("auth"."uid"() IN ( SELECT "middleman_profiles"."user_id"
   FROM "public"."middleman_profiles"
  WHERE ("middleman_profiles"."user_id" = "store_customizations"."store_id"))));



CREATE POLICY "System manage devices" ON "public"."app_devices" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "System manage roles" ON "public"."user_roles" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Users can create connection requests" ON "public"."middleman_connections" FOR INSERT WITH CHECK (("auth"."uid"() = "middleman_id"));



CREATE POLICY "Users can delete own notifications" ON "public"."notifications" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can delete own participants" ON "public"."conversation_participants" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can insert notification settings" ON "public"."notification_settings" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can insert own business profile" ON "public"."business_profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own middleman profile" ON "public"."middleman_profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own participants" ON "public"."conversation_participants" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can insert own profile" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can insert own profile" ON "public"."sellers" FOR INSERT TO "authenticated", "service_role" WITH CHECK ((("auth"."uid"() = "user_id") OR (CURRENT_USER = 'postgres'::"name")));



CREATE POLICY "Users can insert own template selection" ON "public"."user_template_selections" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can only view their own payment intentions" ON "public"."payment_intentions" FOR SELECT TO "authenticated" USING ((("auth"."uid"() = "user_id") OR ("auth"."uid"() = ( SELECT "orders"."user_id"
   FROM "public"."orders"
  WHERE ("orders"."id" = "payment_intentions"."order_id")))));



CREATE POLICY "Users can send messages to their conversations" ON "public"."messages" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."conversation_participants"
  WHERE (("conversation_participants"."conversation_id" = "messages"."conversation_id") AND ("conversation_participants"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can update own business profile" ON "public"."business_profiles" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own connections" ON "public"."middleman_connections" FOR UPDATE USING ((("auth"."uid"() = "middleman_id") OR ("auth"."uid"() = "provider_id")));



CREATE POLICY "Users can update own middleman profile" ON "public"."middleman_profiles" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own notification settings" ON "public"."notification_settings" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can update own notifications" ON "public"."notifications" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can update own participants" ON "public"."conversation_participants" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can update own preferences" ON "public"."users" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can update own profile" ON "public"."users" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own template selection" ON "public"."user_template_selections" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view messages in their conversations" ON "public"."messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."conversation_participants"
  WHERE (("conversation_participants"."conversation_id" = "messages"."conversation_id") AND ("conversation_participants"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can view own business profile" ON "public"."business_profiles" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own connections" ON "public"."middleman_connections" FOR SELECT USING ((("auth"."uid"() = "middleman_id") OR ("auth"."uid"() = "provider_id")));



CREATE POLICY "Users can view own middleman profile" ON "public"."middleman_profiles" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own notification settings" ON "public"."notification_settings" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view own notifications" ON "public"."notifications" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view own participants" ON "public"."conversation_participants" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view own preferences" ON "public"."users" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own template selection" ON "public"."user_template_selections" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own upload history" ON "public"."analytics_uploads" FOR SELECT USING (("entity_id" = "auth"."uid"()));



CREATE POLICY "Users cannot directly insert payment intentions" ON "public"."payment_intentions" FOR INSERT TO "authenticated" WITH CHECK (false);



CREATE POLICY "Users create own medicine reviews" ON "public"."health_medicine_reviews" FOR INSERT TO "authenticated" WITH CHECK (("patient_id" IN ( SELECT "health_patient_profiles"."id"
   FROM "public"."health_patient_profiles"
  WHERE ("health_patient_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users create own payouts" ON "public"."payout_requests" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users insert own profile" ON "public"."freelancer_profiles" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users manage own catalog" ON "public"."site_catalog" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users manage own devices" ON "public"."app_devices" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users manage own doctor profile" ON "public"."health_doctor_profiles" TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users manage own patient profile" ON "public"."health_patient_profiles" TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users manage own products" ON "public"."store_products" USING ((EXISTS ( SELECT 1
   FROM "public"."middleman_profiles" "mp"
  WHERE (("mp"."user_id" = "store_products"."profile_id") AND ("mp"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users manage own website settings" ON "public"."website_settings" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users submit reports" ON "public"."platform_reports" FOR INSERT WITH CHECK (("auth"."uid"() = "reporter_id"));



CREATE POLICY "Users update own profile" ON "public"."freelancer_profiles" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users update own wallet" ON "public"."user_wallets" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users view own appointments" ON "public"."health_appointments" FOR SELECT TO "authenticated" USING ((("doctor_id" = "auth"."uid"()) OR ("patient_id" = "auth"."uid"())));



CREATE POLICY "Users view own medicine orders" ON "public"."health_medicine_orders" FOR SELECT TO "authenticated" USING (("patient_id" IN ( SELECT "health_patient_profiles"."id"
   FROM "public"."health_patient_profiles"
  WHERE ("health_patient_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users view own medicine reviews" ON "public"."health_medicine_reviews" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Users view own payouts" ON "public"."payout_requests" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users view own reports" ON "public"."platform_reports" FOR SELECT USING (("auth"."uid"() = "reporter_id"));



CREATE POLICY "Users view own roles" ON "public"."user_roles" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users view own transactions" ON "public"."wallet_transactions" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users view own wallet" ON "public"."user_wallets" FOR SELECT USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."activity_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "admin_manage_settings" ON "public"."platform_settings" USING ((("auth"."role"() = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"())))));



CREATE POLICY "admins_manage_all_payouts" ON "public"."payouts" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"())))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"()))));



CREATE POLICY "admins_manage_all_products" ON "public"."products" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"())))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"()))));



CREATE POLICY "admins_manage_assignments" ON "public"."delivery_assignments" TO "authenticated" USING ((("auth"."jwt"() ->> 'role'::"text") = ANY (ARRAY['admin'::"text", 'delivery_manager'::"text"])));



CREATE POLICY "admins_manage_delivery_profiles" ON "public"."delivery_profiles" TO "authenticated" USING ((("auth"."jwt"() ->> 'role'::"text") = ANY (ARRAY['admin'::"text", 'delivery_manager'::"text"])));



CREATE POLICY "admins_update_requests_v2" ON "public"."template_requests" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "au"
  WHERE ("au"."user_id" = "auth"."uid"())))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "au"
  WHERE ("au"."user_id" = "auth"."uid"()))));



CREATE POLICY "admins_view_all_commissions" ON "public"."commissions" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"()))));



CREATE POLICY "admins_view_all_deals" ON "public"."middle_man_deals" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"()))));



CREATE POLICY "admins_view_all_orders" ON "public"."orders" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"()))));



CREATE POLICY "admins_view_all_payments" ON "public"."payment_transactions" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"()))));



CREATE POLICY "admins_view_all_prescriptions" ON "public"."health_prescriptions" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"()))));



CREATE POLICY "admins_view_all_splits" ON "public"."payment_splits" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"()))));



CREATE POLICY "admins_view_all_transactions" ON "public"."wallet_transactions" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"()))));



CREATE POLICY "admins_view_all_wallets" ON "public"."user_wallets" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"()))));



CREATE POLICY "admins_view_all_webhook_logs" ON "public"."payment_webhook_logs" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users"
  WHERE ("admin_users"."user_id" = "auth"."uid"()))));



CREATE POLICY "admins_view_requests_v2" ON "public"."template_requests" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_users" "au"
  WHERE ("au"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."analytics_snapshots" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."analytics_uploads" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "anyone_read_settings" ON "public"."platform_settings" FOR SELECT USING (true);



CREATE POLICY "anyone_view_factory_ratings" ON "public"."factory_ratings" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."app_devices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."appointments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."async_jobs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "async_jobs_no_user_access" ON "public"."async_jobs" FOR SELECT TO "authenticated" USING (false);



CREATE POLICY "async_jobs_no_user_delete" ON "public"."async_jobs" FOR DELETE TO "authenticated" USING (false);



CREATE POLICY "async_jobs_no_user_insert" ON "public"."async_jobs" FOR INSERT TO "authenticated" WITH CHECK (false);



CREATE POLICY "async_jobs_no_user_update" ON "public"."async_jobs" FOR UPDATE TO "authenticated" WITH CHECK (false);



CREATE POLICY "async_jobs_service_only" ON "public"."async_jobs" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."business_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."calls" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "calls_insert_own" ON "public"."calls" FOR INSERT TO "authenticated" WITH CHECK (("caller_id" = "auth"."uid"()));



CREATE POLICY "calls_update_own" ON "public"."calls" FOR UPDATE TO "authenticated" USING ((("caller_id" = "auth"."uid"()) OR ("callee_id" = "auth"."uid"())));



CREATE POLICY "calls_view_own" ON "public"."calls" FOR SELECT TO "authenticated" USING ((("caller_id" = "auth"."uid"()) OR ("callee_id" = "auth"."uid"())));



ALTER TABLE "public"."cart" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."commissions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."conversation_participants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."conversations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "conversations_select" ON "public"."conversations" FOR SELECT TO "authenticated" USING (("id" IN ( SELECT "conversation_participants"."conversation_id"
   FROM "public"."conversation_participants"
  WHERE ("conversation_participants"."user_id" = "auth"."uid"()))));



CREATE POLICY "creators_manage_own_templates" ON "public"."website_marketplace" USING (("creator_id" = "auth"."uid"())) WITH CHECK (("creator_id" = "auth"."uid"()));



ALTER TABLE "public"."customers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "customers_view_active_products" ON "public"."products" FOR SELECT TO "authenticated" USING (("status" = 'active'::"text"));



ALTER TABLE "public"."deal_proposals" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "deal_proposals_insert_own" ON "public"."deal_proposals" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "proposer_id"));



CREATE POLICY "deal_proposals_update_own" ON "public"."deal_proposals" FOR UPDATE TO "authenticated" USING ((("auth"."uid"() = "proposer_id") OR (("auth"."uid"() = "recipient_id") AND ("status" = 'pending'::"text"))));



CREATE POLICY "deals_manage_middleman" ON "public"."deals" TO "authenticated" USING (("middleman_id" = "auth"."uid"())) WITH CHECK (("middleman_id" = "auth"."uid"()));



CREATE POLICY "deals_view_participants" ON "public"."deals" FOR SELECT TO "authenticated" USING ((("party_a_id" = "auth"."uid"()) OR ("party_b_id" = "auth"."uid"()) OR ("middleman_id" = "auth"."uid"())));



ALTER TABLE "public"."delivery_assignments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."delivery_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "delivery_view_assigned_orders" ON "public"."orders" FOR SELECT TO "authenticated" USING ((("delivery_id" = "auth"."uid"()) OR ("seller_id" = "auth"."uid"()) OR ("user_id" = "auth"."uid"())));



ALTER TABLE "public"."doctors" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "doctors_view_own_prescriptions" ON "public"."health_prescriptions" FOR SELECT TO "authenticated" USING (("appointment_id" IN ( SELECT "health_appointments"."id"
   FROM "public"."health_appointments"
  WHERE ("health_appointments"."doctor_id" IN ( SELECT "health_doctor_profiles"."id"
           FROM "public"."health_doctor_profiles"
          WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))))));



CREATE POLICY "drivers_view_own_assignments" ON "public"."delivery_assignments" TO "authenticated" USING (("driver_id" = ( SELECT "delivery_profiles"."id"
   FROM "public"."delivery_profiles"
  WHERE ("delivery_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "drivers_view_own_profile" ON "public"."delivery_profiles" TO "authenticated" USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."error_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "everyone_view_approved_reviews" ON "public"."reviews" FOR SELECT TO "authenticated" USING (("is_approved" = true));



ALTER TABLE "public"."factories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "factories_manage_own" ON "public"."factories" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "factories_manage_own_production" ON "public"."factory_production_logs" TO "authenticated" USING (("order_id" IN ( SELECT "orders"."id"
   FROM "public"."orders"
  WHERE ("orders"."seller_id" = "auth"."uid"()))));



CREATE POLICY "factories_update_own_connections" ON "public"."factory_connections" FOR UPDATE TO "authenticated" USING (("factory_id" = "auth"."uid"())) WITH CHECK (("factory_id" = "auth"."uid"()));



CREATE POLICY "factories_view_public" ON "public"."factories" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."factory_connections" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "factory_connections_insert_own" ON "public"."factory_connections" FOR INSERT TO "authenticated" WITH CHECK ((("factory_id" = "auth"."uid"()) OR ("seller_id" = "auth"."uid"())));



CREATE POLICY "factory_connections_update_own" ON "public"."factory_connections" FOR UPDATE TO "authenticated" USING ((("factory_id" = "auth"."uid"()) OR ("seller_id" = "auth"."uid"()))) WITH CHECK ((("factory_id" = "auth"."uid"()) OR ("seller_id" = "auth"."uid"())));



CREATE POLICY "factory_connections_view_own" ON "public"."factory_connections" FOR SELECT TO "authenticated" USING ((("factory_id" = "auth"."uid"()) OR ("seller_id" = "auth"."uid"())));



ALTER TABLE "public"."factory_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "factory_profiles_insert_own" ON "public"."factory_profiles" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "factory_profiles_update_own" ON "public"."factory_profiles" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "id"));



CREATE POLICY "factory_profiles_viewable_by_all" ON "public"."factory_profiles" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."factory_ratings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."freelancer_portfolio" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."freelancer_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_appointments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_chat_attachments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "health_chat_attachments_insert" ON "public"."health_chat_attachments" FOR INSERT TO "authenticated" WITH CHECK (("uploaded_by" = "auth"."uid"()));



CREATE POLICY "health_chat_attachments_view" ON "public"."health_chat_attachments" FOR SELECT TO "authenticated" USING (("conversation_id" IN ( SELECT "health_conversations"."id"
   FROM "public"."health_conversations"
  WHERE (("health_conversations"."doctor_id" IN ( SELECT "health_doctor_profiles"."id"
           FROM "public"."health_doctor_profiles"
          WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))) OR ("health_conversations"."patient_id" IN ( SELECT "health_patient_profiles"."id"
           FROM "public"."health_patient_profiles"
          WHERE ("health_patient_profiles"."user_id" = "auth"."uid"())))))));



ALTER TABLE "public"."health_conversations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "health_conversations_doctor_view" ON "public"."health_conversations" FOR SELECT TO "authenticated" USING (("doctor_id" IN ( SELECT "health_doctor_profiles"."id"
   FROM "public"."health_doctor_profiles"
  WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "health_conversations_insert" ON "public"."health_conversations" FOR INSERT TO "authenticated" WITH CHECK ((("doctor_id" IN ( SELECT "health_doctor_profiles"."id"
   FROM "public"."health_doctor_profiles"
  WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))) OR ("patient_id" IN ( SELECT "health_patient_profiles"."id"
   FROM "public"."health_patient_profiles"
  WHERE ("health_patient_profiles"."user_id" = "auth"."uid"())))));



CREATE POLICY "health_conversations_patient_view" ON "public"."health_conversations" FOR SELECT TO "authenticated" USING (("patient_id" IN ( SELECT "health_patient_profiles"."id"
   FROM "public"."health_patient_profiles"
  WHERE ("health_patient_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "health_conversations_update" ON "public"."health_conversations" FOR UPDATE TO "authenticated" USING ((("doctor_id" IN ( SELECT "health_doctor_profiles"."id"
   FROM "public"."health_doctor_profiles"
  WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))) OR ("patient_id" IN ( SELECT "health_patient_profiles"."id"
   FROM "public"."health_patient_profiles"
  WHERE ("health_patient_profiles"."user_id" = "auth"."uid"())))));



ALTER TABLE "public"."health_daily_backup_status" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_doctor_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_medicine_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_medicine_expiry_alerts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_medicine_order_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_medicine_orders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_medicine_recalls" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_medicine_reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_medicine_stock_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_medicines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_medicines_master" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_message_receipts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "health_message_receipts_insert" ON "public"."health_message_receipts" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "health_message_receipts_view" ON "public"."health_message_receipts" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."health_messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "health_messages_delete" ON "public"."health_messages" FOR DELETE TO "authenticated" USING (("sender_id" = "auth"."uid"()));



CREATE POLICY "health_messages_insert" ON "public"."health_messages" FOR INSERT TO "authenticated" WITH CHECK ((("conversation_id" IN ( SELECT "health_conversations"."id"
   FROM "public"."health_conversations"
  WHERE (("health_conversations"."doctor_id" IN ( SELECT "health_doctor_profiles"."id"
           FROM "public"."health_doctor_profiles"
          WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))) OR ("health_conversations"."patient_id" IN ( SELECT "health_patient_profiles"."id"
           FROM "public"."health_patient_profiles"
          WHERE ("health_patient_profiles"."user_id" = "auth"."uid"())))))) AND ("sender_id" = "auth"."uid"())));



CREATE POLICY "health_messages_update" ON "public"."health_messages" FOR UPDATE TO "authenticated" USING (("sender_id" = "auth"."uid"()));



CREATE POLICY "health_messages_view" ON "public"."health_messages" FOR SELECT TO "authenticated" USING (("conversation_id" IN ( SELECT "health_conversations"."id"
   FROM "public"."health_conversations"
  WHERE (("health_conversations"."doctor_id" IN ( SELECT "health_doctor_profiles"."id"
           FROM "public"."health_doctor_profiles"
          WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))) OR ("health_conversations"."patient_id" IN ( SELECT "health_patient_profiles"."id"
           FROM "public"."health_patient_profiles"
          WHERE ("health_patient_profiles"."user_id" = "auth"."uid"())))))));



ALTER TABLE "public"."health_patient_access_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_patient_archives" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_patient_change_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_patient_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_pharmacy_inspections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_pharmacy_inventory" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_pharmacy_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_prescription_medicines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_prescriptions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_typing_indicators" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "health_typing_indicators_insert" ON "public"."health_typing_indicators" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "health_typing_indicators_update" ON "public"."health_typing_indicators" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "health_typing_indicators_view" ON "public"."health_typing_indicators" FOR SELECT TO "authenticated" USING (("conversation_id" IN ( SELECT "health_conversations"."id"
   FROM "public"."health_conversations"
  WHERE (("health_conversations"."doctor_id" IN ( SELECT "health_doctor_profiles"."id"
           FROM "public"."health_doctor_profiles"
          WHERE ("health_doctor_profiles"."user_id" = "auth"."uid"()))) OR ("health_conversations"."patient_id" IN ( SELECT "health_patient_profiles"."id"
           FROM "public"."health_patient_profiles"
          WHERE ("health_patient_profiles"."user_id" = "auth"."uid"())))))));



ALTER TABLE "public"."hospitals" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."idempotency_keys" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "idempotency_keys_user_own" ON "public"."idempotency_keys" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "listings_delete_own" ON "public"."svc_listings" FOR DELETE TO "authenticated" USING (("provider_id" IN ( SELECT "svc_providers"."id"
   FROM "public"."svc_providers"
  WHERE ("svc_providers"."user_id" = "auth"."uid"()))));



CREATE POLICY "listings_insert_own" ON "public"."svc_listings" FOR INSERT TO "authenticated" WITH CHECK (("provider_id" IN ( SELECT "svc_providers"."id"
   FROM "public"."svc_providers"
  WHERE ("svc_providers"."user_id" = "auth"."uid"()))));



CREATE POLICY "listings_manage_own" ON "public"."svc_listings" TO "authenticated" USING (("provider_id" IN ( SELECT "svc_providers"."id"
   FROM "public"."svc_providers"
  WHERE ("svc_providers"."user_id" = "auth"."uid"())))) WITH CHECK (("provider_id" IN ( SELECT "svc_providers"."id"
   FROM "public"."svc_providers"
  WHERE ("svc_providers"."user_id" = "auth"."uid"()))));



CREATE POLICY "listings_public_view" ON "public"."svc_listings" FOR SELECT TO "authenticated", "anon" USING (("is_active" = true));



CREATE POLICY "listings_update_own" ON "public"."svc_listings" FOR UPDATE TO "authenticated" USING (("provider_id" IN ( SELECT "svc_providers"."id"
   FROM "public"."svc_providers"
  WHERE ("svc_providers"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."location_history" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "manage_own_requests_v2" ON "public"."template_requests" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "manage_own_shop" ON "public"."shops" TO "authenticated" USING (("owner_id" = "auth"."uid"())) WITH CHECK (("owner_id" = "auth"."uid"()));



CREATE POLICY "manage_own_shop_products" ON "public"."shop_products" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."shops" "s"
  WHERE (("s"."id" = "shop_products"."shop_id") AND ("s"."owner_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."shops" "s"
  WHERE (("s"."id" = "shop_products"."shop_id") AND ("s"."owner_id" = "auth"."uid"())))));



CREATE POLICY "manage_own_shops" ON "public"."shops" TO "authenticated" USING (("owner_id" = "auth"."uid"())) WITH CHECK (("owner_id" = "auth"."uid"()));



CREATE POLICY "manage_own_templates" ON "public"."shop_templates" TO "authenticated" USING (("created_by" = "auth"."uid"())) WITH CHECK (("created_by" = "auth"."uid"()));



CREATE POLICY "manage_shop_products" ON "public"."shop_products" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."shops" "s"
  WHERE (("s"."id" = "shop_products"."shop_id") AND ("s"."owner_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."shops" "s"
  WHERE (("s"."id" = "shop_products"."shop_id") AND ("s"."owner_id" = "auth"."uid"())))));



CREATE POLICY "marketplace_manage_own" ON "public"."website_marketplace" USING (("creator_id" = "auth"."uid"())) WITH CHECK (("creator_id" = "auth"."uid"()));



ALTER TABLE "public"."marketplace_purchases" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "marketplace_service_full" ON "public"."website_marketplace" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "marketplace_view_published" ON "public"."website_marketplace" FOR SELECT USING (("is_published" = true));



ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "messages_delete_own" ON "public"."messages" FOR DELETE TO "authenticated" USING (("sender_id" = "auth"."uid"()));



CREATE POLICY "messages_insert_own" ON "public"."messages" FOR INSERT TO "authenticated" WITH CHECK (("sender_id" = "auth"."uid"()));



CREATE POLICY "messages_update_own" ON "public"."messages" FOR UPDATE TO "authenticated" USING (("sender_id" = "auth"."uid"())) WITH CHECK (("sender_id" = "auth"."uid"()));



ALTER TABLE "public"."middle_man_deals" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."middle_men" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "middle_men_create_own_deals" ON "public"."middle_man_deals" FOR INSERT TO "authenticated" WITH CHECK (("middle_man_id" = "auth"."uid"()));



CREATE POLICY "middle_men_view_own" ON "public"."middle_men" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "middle_men_view_own_commissions" ON "public"."commissions" FOR SELECT TO "authenticated" USING (("middle_man_id" = "auth"."uid"()));



CREATE POLICY "middle_men_view_own_deals" ON "public"."middle_man_deals" FOR SELECT TO "authenticated" USING (("middle_man_id" = "auth"."uid"()));



CREATE POLICY "middle_men_view_own_orders" ON "public"."orders" FOR SELECT TO "authenticated" USING (("middle_man_id" = "auth"."uid"()));



ALTER TABLE "public"."middleman_connections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."middleman_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."middleman_store_configs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "middlemen_create_own_deals" ON "public"."middle_man_deals" FOR INSERT TO "authenticated" WITH CHECK (("middle_man_id" = "auth"."uid"()));



CREATE POLICY "middlemen_update_own_deals" ON "public"."middle_man_deals" FOR UPDATE TO "authenticated" USING (("middle_man_id" = "auth"."uid"())) WITH CHECK (("middle_man_id" = "auth"."uid"()));



CREATE POLICY "middlemen_view_own_commissions" ON "public"."commissions" FOR SELECT TO "authenticated" USING (("middle_man_id" = "auth"."uid"()));



CREATE POLICY "middlemen_view_own_deals" ON "public"."middle_man_deals" FOR SELECT TO "authenticated" USING (("middle_man_id" = "auth"."uid"()));



CREATE POLICY "middlemen_view_own_orders" ON "public"."orders" FOR SELECT TO "authenticated" USING (("middle_man_id" = "auth"."uid"()));



ALTER TABLE "public"."notification_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_templates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "participant_delete" ON "public"."conversation_participants" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "participant_insert" ON "public"."conversation_participants" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "participant_update" ON "public"."conversation_participants" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "participants_insert_own" ON "public"."conversation_participants" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "participants_view_own" ON "public"."conversation_participants" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "patients_private" ON "public"."health_patient_profiles" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "patients_view_own_prescriptions" ON "public"."health_prescriptions" FOR SELECT TO "authenticated" USING (("appointment_id" IN ( SELECT "health_appointments"."id"
   FROM "public"."health_appointments"
  WHERE ("health_appointments"."patient_id" IN ( SELECT "health_patient_profiles"."id"
           FROM "public"."health_patient_profiles"
          WHERE ("health_patient_profiles"."user_id" = "auth"."uid"()))))));



ALTER TABLE "public"."payment_intentions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."payment_splits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."payment_transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."payment_webhook_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."payout_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."payouts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pharmacies_view_prescriptions_for_fulfillment" ON "public"."health_prescriptions" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."health_pharmacy_profiles"
  WHERE (("health_pharmacy_profiles"."user_id" = "auth"."uid"()) AND ("health_pharmacy_profiles"."is_verified" = true)))));



ALTER TABLE "public"."pharmacy_activity_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pharmacy_daily_reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pharmacy_medicine_inventory" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pharmacy_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pharmacy_qr_scan_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pharmacy_stock_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."platform_reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."platform_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."post_comments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "post_comments_delete_own" ON "public"."post_comments" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "post_comments_insert_own" ON "public"."post_comments" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "post_comments_update_own" ON "public"."post_comments" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "post_comments_view_public" ON "public"."post_comments" FOR SELECT TO "authenticated" USING (("is_deleted" = false));



ALTER TABLE "public"."post_likes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "post_likes_delete_own" ON "public"."post_likes" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "post_likes_insert_own" ON "public"."post_likes" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "post_likes_view_public" ON "public"."post_likes" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."posts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "posts_delete_own" ON "public"."posts" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "posts_insert_own" ON "public"."posts" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "posts_update_own" ON "public"."posts" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "posts_view_public" ON "public"."posts" FOR SELECT TO "authenticated" USING (("is_deleted" = false));



CREATE POLICY "posts_view_public_anon" ON "public"."posts" FOR SELECT TO "anon" USING (("is_deleted" = false));



CREATE POLICY "prevent_balance_changes" ON "public"."user_wallets" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK ((("user_id" = "auth"."uid"()) AND ("balance" = ( SELECT "uw"."balance"
   FROM "public"."user_wallets" "uw"
  WHERE ("uw"."id" = "user_wallets"."id")))));



CREATE POLICY "prevent_direct_analytics_inserts" ON "public"."analytics_snapshots" FOR INSERT TO "authenticated" WITH CHECK (false);



CREATE POLICY "prevent_direct_analytics_updates" ON "public"."analytics_snapshots" FOR UPDATE TO "authenticated" WITH CHECK (false);



CREATE POLICY "prevent_direct_payment_inserts" ON "public"."payment_intentions" FOR INSERT TO "authenticated" WITH CHECK (false);



CREATE POLICY "prevent_direct_payment_updates" ON "public"."payment_intentions" FOR UPDATE TO "authenticated" WITH CHECK (false);



ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "products_view_active_anon" ON "public"."products" FOR SELECT TO "anon" USING ((("is_deleted" = false) AND ("status" = 'active'::"text")));



CREATE POLICY "products_view_active_public" ON "public"."products" FOR SELECT TO "authenticated" USING ((("is_deleted" = false) AND ("status" = 'active'::"text")));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_public_view" ON "public"."factories" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "profiles_public_view" ON "public"."freelancer_profiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "profiles_public_view" ON "public"."health_doctor_profiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "profiles_public_view" ON "public"."health_pharmacy_profiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "profiles_public_view" ON "public"."middle_men" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "profiles_public_view" ON "public"."sellers" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "profiles_select_all_authenticated" ON "public"."profiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "public_view_active_products" ON "public"."products" FOR SELECT TO "anon" USING (("status" = 'active'::"text"));



CREATE POLICY "public_view_middleman_profiles" ON "public"."middleman_profiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "public_view_published_templates" ON "public"."website_marketplace" FOR SELECT USING (("is_published" = true));



CREATE POLICY "public_view_published_websites" ON "public"."websites" FOR SELECT TO "anon" USING ((("is_published" = true) AND ("is_active" = true)));



CREATE POLICY "purchases_system_manage" ON "public"."marketplace_purchases" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "purchases_view_own" ON "public"."marketplace_purchases" FOR SELECT USING (("buyer_id" = "auth"."uid"()));



ALTER TABLE "public"."push_subscriptions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "recipients_view_own_splits" ON "public"."payment_splits" FOR SELECT TO "authenticated" USING (("recipient_id" = "auth"."uid"()));



ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."seller_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "seller_profiles_view_public" ON "public"."seller_profiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "seller_profiles_view_public_anon" ON "public"."seller_profiles" FOR SELECT TO "anon" USING (true);



ALTER TABLE "public"."sellers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sellers_create_factory_connections" ON "public"."factory_connections" FOR INSERT TO "authenticated" WITH CHECK (("seller_id" = "auth"."uid"()));



CREATE POLICY "sellers_create_factory_ratings" ON "public"."factory_ratings" FOR INSERT TO "authenticated" WITH CHECK (("seller_id" = "auth"."uid"()));



CREATE POLICY "sellers_manage_own" ON "public"."sellers" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "sellers_manage_own_products" ON "public"."products" TO "authenticated" USING (("seller_id" = "auth"."uid"())) WITH CHECK (("seller_id" = "auth"."uid"()));



CREATE POLICY "sellers_manage_own_websites" ON "public"."websites" TO "authenticated" USING (("seller_id" = "auth"."uid"())) WITH CHECK (("seller_id" = "auth"."uid"()));



CREATE POLICY "sellers_view_all_anon" ON "public"."sellers" FOR SELECT TO "anon" USING (true);



CREATE POLICY "sellers_view_all_authenticated" ON "public"."sellers" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "sellers_view_order_payments" ON "public"."payment_transactions" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."orders"
  WHERE (("orders"."id" = "payment_transactions"."order_id") AND ("orders"."seller_id" = "auth"."uid"())))));



CREATE POLICY "sellers_view_order_splits" ON "public"."payment_splits" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."orders"
  WHERE (("orders"."id" = "payment_splits"."order_id") AND ("orders"."seller_id" = "auth"."uid"())))));



CREATE POLICY "sellers_view_own_analytics" ON "public"."analytics_snapshots" FOR SELECT TO "authenticated" USING (("seller_id" = "auth"."uid"()));



CREATE POLICY "sellers_view_own_customers" ON "public"."customers" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "sellers_view_own_factory_connections" ON "public"."factory_connections" FOR SELECT TO "authenticated" USING ((("seller_id" = "auth"."uid"()) OR ("factory_id" = "auth"."uid"())));



CREATE POLICY "sellers_view_own_orders" ON "public"."orders" FOR SELECT TO "authenticated" USING (("seller_id" = "auth"."uid"()));



CREATE POLICY "service_role_manage_analytics" ON "public"."analytics_snapshots" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_manage_payment_intentions" ON "public"."payment_intentions" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."services" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."shipping_addresses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."shop_products" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."shop_templates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."shops" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."site_catalog" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_customizations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_products" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "svc_cat_public_read" ON "public"."svc_categories" FOR SELECT TO "authenticated", "anon" USING (("is_active" = true));



ALTER TABLE "public"."svc_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."svc_listings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."svc_messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "svc_ord_create" ON "public"."svc_orders" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "svc_ord_provider_update" ON "public"."svc_orders" FOR UPDATE TO "authenticated" USING (("provider_id" = ( SELECT "svc_providers"."id"
   FROM "public"."svc_providers"
  WHERE ("svc_providers"."user_id" = "auth"."uid"()))));



CREATE POLICY "svc_ord_view_own" ON "public"."svc_orders" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR ("provider_id" = ( SELECT "svc_providers"."id"
   FROM "public"."svc_providers"
  WHERE ("svc_providers"."user_id" = "auth"."uid"())))));



ALTER TABLE "public"."svc_orders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "svc_port_owner_write" ON "public"."svc_portfolio" TO "authenticated" USING (("provider_id" = ( SELECT "svc_providers"."id"
   FROM "public"."svc_providers"
  WHERE ("svc_providers"."user_id" = "auth"."uid"()))));



CREATE POLICY "svc_port_public_read" ON "public"."svc_portfolio" FOR SELECT TO "authenticated", "anon" USING (true);



ALTER TABLE "public"."svc_portfolio" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "svc_prov_owner_write" ON "public"."svc_providers" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "svc_prov_public_read" ON "public"."svc_providers" FOR SELECT TO "authenticated", "anon" USING (("status" = 'active'::"text"));



ALTER TABLE "public"."svc_providers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "svc_rev_create" ON "public"."svc_reviews" FOR INSERT TO "authenticated" WITH CHECK ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."svc_orders"
  WHERE (("svc_orders"."id" = "svc_reviews"."order_id") AND ("svc_orders"."status" = 'completed'::"text") AND ("svc_orders"."user_id" = "auth"."uid"()))))));



CREATE POLICY "svc_rev_public_read" ON "public"."svc_reviews" FOR SELECT TO "authenticated", "anon" USING (("is_visible" = true));



ALTER TABLE "public"."svc_reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."svc_subcategories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "system_insert_payments" ON "public"."payment_transactions" FOR INSERT TO "service_role" WITH CHECK (true);



CREATE POLICY "system_insert_transactions" ON "public"."wallet_transactions" FOR INSERT TO "service_role" WITH CHECK (true);



CREATE POLICY "system_insert_wallets" ON "public"."user_wallets" FOR INSERT TO "service_role" WITH CHECK (true);



CREATE POLICY "system_insert_webhook_logs" ON "public"."payment_webhook_logs" FOR INSERT TO "service_role" WITH CHECK (true);



CREATE POLICY "system_manage_purchases" ON "public"."marketplace_purchases" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "system_manage_splits" ON "public"."payment_splits" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "system_update_payments" ON "public"."payment_transactions" FOR UPDATE TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "system_update_payouts" ON "public"."payouts" FOR UPDATE TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "system_update_webhook_logs" ON "public"."payment_webhook_logs" FOR UPDATE TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."template_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."templates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_template_selections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_wallets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_create_own_payouts" ON "public"."payouts" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_create_own_reviews" ON "public"."reviews" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_delete_own_push_subscriptions" ON "public"."push_subscriptions" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "users_delete_own_reviews" ON "public"."reviews" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "users_insert_own_activity_logs" ON "public"."activity_logs" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_insert_own_error_logs" ON "public"."error_logs" FOR INSERT TO "authenticated" WITH CHECK ((("user_id" = "auth"."uid"()) OR ("user_id" IS NULL)));



CREATE POLICY "users_insert_own_events" ON "public"."user_events" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "users_insert_own_location_history" ON "public"."location_history" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_insert_own_profile" ON "public"."seller_profiles" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "users_insert_own_push_subscriptions" ON "public"."push_subscriptions" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_insert_own_svc_provider" ON "public"."svc_providers" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "users_manage_own_activity_logs" ON "public"."activity_logs" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_manage_own_addresses" ON "public"."shipping_addresses" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_manage_own_cart" ON "public"."cart" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_manage_own_customer" ON "public"."customers" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_manage_own_error_logs" ON "public"."error_logs" TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR ("user_id" IS NULL))) WITH CHECK ((("user_id" = "auth"."uid"()) OR ("user_id" IS NULL)));



CREATE POLICY "users_manage_own_location_history" ON "public"."location_history" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_manage_own_middleman_profile" ON "public"."middleman_profiles" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_manage_own_orders" ON "public"."orders" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_manage_own_wishlist" ON "public"."wishlist" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_update_own_profile" ON "public"."seller_profiles" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "id"));



CREATE POLICY "users_update_own_push_subscriptions" ON "public"."push_subscriptions" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_update_own_reviews" ON "public"."reviews" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "users_update_own_svc_provider" ON "public"."svc_providers" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "users_update_own_wallet" ON "public"."user_wallets" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "users_view_own_activity_logs" ON "public"."activity_logs" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "users_view_own_error_logs" ON "public"."error_logs" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR ("user_id" IS NULL)));



CREATE POLICY "users_view_own_location_history" ON "public"."location_history" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "users_view_own_payment_intentions" ON "public"."payment_intentions" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."orders"
  WHERE (("orders"."id" = "payment_intentions"."order_id") AND ("orders"."user_id" = "auth"."uid"()))))));



CREATE POLICY "users_view_own_payments" ON "public"."payment_transactions" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "users_view_own_payouts" ON "public"."payouts" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "users_view_own_profile" ON "public"."seller_profiles" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "id"));



CREATE POLICY "users_view_own_purchases" ON "public"."marketplace_purchases" FOR SELECT USING (("buyer_id" = "auth"."uid"()));



CREATE POLICY "users_view_own_push_subscriptions" ON "public"."push_subscriptions" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "users_view_own_svc_provider" ON "public"."svc_providers" FOR SELECT USING ((("auth"."uid"() = "user_id") OR ("status" = 'active'::"text")));



CREATE POLICY "users_view_own_transactions" ON "public"."wallet_transactions" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "users_view_own_wallet" ON "public"."user_wallets" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "view_active_shop_products" ON "public"."shop_products" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."shops" "s"
  WHERE (("s"."id" = "shop_products"."shop_id") AND ("s"."status" = 'active'::"text")))));



CREATE POLICY "view_active_shops" ON "public"."shops" FOR SELECT USING (("status" = 'active'::"text"));



CREATE POLICY "view_active_shops_auth" ON "public"."shops" FOR SELECT TO "authenticated" USING ((("status" = 'active'::"text") AND ("owner_id" = "auth"."uid"())));



CREATE POLICY "view_active_templates" ON "public"."shop_templates" FOR SELECT USING (("status" = 'active'::"text"));



CREATE POLICY "view_order_items" ON "public"."order_items" FOR SELECT TO "authenticated" USING (("order_id" IN ( SELECT "orders"."id"
   FROM "public"."orders"
  WHERE (("orders"."user_id" = "auth"."uid"()) OR ("orders"."seller_id" = "auth"."uid"())))));



CREATE POLICY "view_shop_products" ON "public"."shop_products" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."shops" "s"
  WHERE (("s"."id" = "shop_products"."shop_id") AND ("s"."status" = 'active'::"text")))));



CREATE POLICY "view_shop_products_public" ON "public"."shop_products" FOR SELECT TO "anon" USING ((EXISTS ( SELECT 1
   FROM "public"."shops" "s"
  WHERE (("s"."id" = "shop_products"."shop_id") AND ("s"."status" = 'active'::"text")))));



ALTER TABLE "public"."wallet_transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."website_marketplace" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."website_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wishlist" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."calls";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."cart";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."deal_proposals";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."factories";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."messages";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."products";






GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";











































































GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "service_role";
































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































GRANT ALL ON FUNCTION "public"."add_earnings_to_wallet"() TO "anon";
GRANT ALL ON FUNCTION "public"."add_earnings_to_wallet"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_earnings_to_wallet"() TO "service_role";



GRANT ALL ON FUNCTION "public"."add_medicine_to_prescription"("p_prescription_id" "uuid", "p_medicine_id" "uuid", "p_dosage_amount" "text", "p_frequency" "text", "p_duration_days" integer, "p_instructions" "text", "p_quantity" integer, "p_allow_substitution" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."add_medicine_to_prescription"("p_prescription_id" "uuid", "p_medicine_id" "uuid", "p_dosage_amount" "text", "p_frequency" "text", "p_duration_days" integer, "p_instructions" "text", "p_quantity" integer, "p_allow_substitution" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_medicine_to_prescription"("p_prescription_id" "uuid", "p_medicine_id" "uuid", "p_dosage_amount" "text", "p_frequency" "text", "p_duration_days" integer, "p_instructions" "text", "p_quantity" integer, "p_allow_substitution" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."add_seller_to_conversation"() TO "anon";
GRANT ALL ON FUNCTION "public"."add_seller_to_conversation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_seller_to_conversation"() TO "service_role";



GRANT ALL ON FUNCTION "public"."archive_health_messages"() TO "anon";
GRANT ALL ON FUNCTION "public"."archive_health_messages"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."archive_health_messages"() TO "service_role";



GRANT ALL ON FUNCTION "public"."archive_old_messages"() TO "anon";
GRANT ALL ON FUNCTION "public"."archive_old_messages"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."archive_old_messages"() TO "service_role";



GRANT ALL ON FUNCTION "public"."archive_old_notifications"() TO "anon";
GRANT ALL ON FUNCTION "public"."archive_old_notifications"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."archive_old_notifications"() TO "service_role";



GRANT ALL ON FUNCTION "public"."archive_patient_data"("p_doctor_id" "uuid", "p_patient_id" "uuid", "p_archive_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."archive_patient_data"("p_doctor_id" "uuid", "p_patient_id" "uuid", "p_archive_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."archive_patient_data"("p_doctor_id" "uuid", "p_patient_id" "uuid", "p_archive_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."assign_delivery_to_driver"("p_order_id" "uuid", "p_seller_latitude" numeric, "p_seller_longitude" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."assign_delivery_to_driver"("p_order_id" "uuid", "p_seller_latitude" numeric, "p_seller_longitude" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."assign_delivery_to_driver"("p_order_id" "uuid", "p_seller_latitude" numeric, "p_seller_longitude" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."audit_sensitive_data_changes"() TO "anon";
GRANT ALL ON FUNCTION "public"."audit_sensitive_data_changes"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."audit_sensitive_data_changes"() TO "service_role";



GRANT ALL ON FUNCTION "public"."auto_create_user_wallet"() TO "anon";
GRANT ALL ON FUNCTION "public"."auto_create_user_wallet"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."auto_create_user_wallet"() TO "service_role";



GRANT ALL ON FUNCTION "public"."auto_credit_service_provider"() TO "anon";
GRANT ALL ON FUNCTION "public"."auto_credit_service_provider"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."auto_credit_service_provider"() TO "service_role";



GRANT ALL ON FUNCTION "public"."auto_generate_product_description"() TO "anon";
GRANT ALL ON FUNCTION "public"."auto_generate_product_description"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."auto_generate_product_description"() TO "service_role";



GRANT ALL ON FUNCTION "public"."bulk_upload_medicines"("p_pharmacy_id" "uuid", "p_medicines" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."bulk_upload_medicines"("p_pharmacy_id" "uuid", "p_medicines" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."bulk_upload_medicines"("p_pharmacy_id" "uuid", "p_medicines" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_distance"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_distance"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_distance"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_middle_man_commission"() TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_middle_man_commission"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_middle_man_commission"() TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_middle_man_margin"("p_product_asin" "text", "p_commission_rate" numeric, "p_margin_amount" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_middle_man_margin"("p_product_asin" "text", "p_commission_rate" numeric, "p_margin_amount" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_middle_man_margin"("p_product_asin" "text", "p_commission_rate" numeric, "p_margin_amount" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_order_commission"() TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_order_commission"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_order_commission"() TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_seller_analytics"("p_seller_id" "uuid", "p_period_type" "text", "p_start_date" "date", "p_end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_seller_analytics"("p_seller_id" "uuid", "p_period_type" "text", "p_start_date" "date", "p_end_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_start_conversation"("from_user_id" "uuid", "to_user_id" "uuid", "product_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_start_conversation"("from_user_id" "uuid", "to_user_id" "uuid", "product_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_start_conversation"("from_user_id" "uuid", "to_user_id" "uuid", "product_id" "uuid", "conversation_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."can_start_conversation"("from_user_id" "uuid", "to_user_id" "uuid", "product_id" "uuid", "conversation_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_start_conversation"("from_user_id" "uuid", "to_user_id" "uuid", "product_id" "uuid", "conversation_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_low_stock_and_notify"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_low_stock_and_notify"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_low_stock_and_notify"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_product_chat_permission"("p_user_id" "uuid", "p_product_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."check_product_chat_permission"("p_user_id" "uuid", "p_product_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_product_chat_permission"("p_user_id" "uuid", "p_product_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."claim_and_create_promo_deal"("p_product_asin" "text", "p_margin_type" "text", "p_margin_value" numeric, "p_expires_days" integer, "p_promo_tags" "text"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."claim_and_create_promo_deal"("p_product_asin" "text", "p_margin_type" "text", "p_margin_value" numeric, "p_expires_days" integer, "p_promo_tags" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."claim_and_create_promo_deal"("p_product_asin" "text", "p_margin_type" "text", "p_margin_value" numeric, "p_expires_days" integer, "p_promo_tags" "text"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_expired_idempotency_keys"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_expired_idempotency_keys"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_expired_idempotency_keys"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_expired_notifications"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_expired_notifications"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_expired_notifications"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_expired_sessions"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_expired_sessions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_expired_sessions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_inactive_push_subscriptions"("p_days_inactive" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_inactive_push_subscriptions"("p_days_inactive" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_inactive_push_subscriptions"("p_days_inactive" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_product_images"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_product_images"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_product_images"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_typing_indicators"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_typing_indicators"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_typing_indicators"() TO "service_role";



GRANT ALL ON FUNCTION "public"."close_health_conversation"("p_conversation_id" "uuid", "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."close_health_conversation"("p_conversation_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."close_health_conversation"("p_conversation_id" "uuid", "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_analytics_snapshot"("p_seller_id" "uuid", "p_period_type" "text", "p_start_date" "date", "p_end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_analytics_snapshot"("p_seller_id" "uuid", "p_period_type" "text", "p_start_date" "date", "p_end_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_cod_verification_on_order"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_cod_verification_on_order"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_cod_verification_on_order"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_digital_prescription"("p_appointment_id" "uuid", "p_doctor_id" "uuid", "p_patient_id" "uuid", "p_diagnosis" "text", "p_symptoms" "text", "p_notes" "text", "p_valid_days" integer, "p_max_refills" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."create_digital_prescription"("p_appointment_id" "uuid", "p_doctor_id" "uuid", "p_patient_id" "uuid", "p_diagnosis" "text", "p_symptoms" "text", "p_notes" "text", "p_valid_days" integer, "p_max_refills" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_digital_prescription"("p_appointment_id" "uuid", "p_doctor_id" "uuid", "p_patient_id" "uuid", "p_diagnosis" "text", "p_symptoms" "text", "p_notes" "text", "p_valid_days" integer, "p_max_refills" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_direct_conversation"("p_target_user_id" "uuid", "p_context" "text", "p_product_id" "uuid", "p_appointment_id" "uuid", "p_listing_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_direct_conversation"("p_target_user_id" "uuid", "p_context" "text", "p_product_id" "uuid", "p_appointment_id" "uuid", "p_listing_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_direct_conversation"("p_target_user_id" "uuid", "p_context" "text", "p_product_id" "uuid", "p_appointment_id" "uuid", "p_listing_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_health_conversation_on_appointment"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_health_conversation_on_appointment"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_health_conversation_on_appointment"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_medicine_order"("p_user_id" "uuid", "p_items" "jsonb", "p_delivery_address" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."create_medicine_order"("p_user_id" "uuid", "p_items" "jsonb", "p_delivery_address" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_medicine_order"("p_user_id" "uuid", "p_items" "jsonb", "p_delivery_address" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_middle_man_deal"("p_middle_man_id" "uuid", "p_product_asin" "text", "p_commission_rate" numeric, "p_margin_amount" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."create_middle_man_deal"("p_middle_man_id" "uuid", "p_product_asin" "text", "p_commission_rate" numeric, "p_margin_amount" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_middle_man_deal"("p_middle_man_id" "uuid", "p_product_asin" "text", "p_commission_rate" numeric, "p_margin_amount" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_notification_from_template"("p_user_id" "uuid", "p_template_name" "text", "p_variables" "jsonb", "p_reference_type" "text", "p_reference_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_notification_from_template"("p_user_id" "uuid", "p_template_name" "text", "p_variables" "jsonb", "p_reference_type" "text", "p_reference_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_notification_from_template"("p_user_id" "uuid", "p_template_name" "text", "p_variables" "jsonb", "p_reference_type" "text", "p_reference_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_or_update_middle_man_deal"("p_product_asin" "text", "p_commission_rate" numeric, "p_margin_amount" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."create_or_update_middle_man_deal"("p_product_asin" "text", "p_commission_rate" numeric, "p_margin_amount" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_or_update_middle_man_deal"("p_product_asin" "text", "p_commission_rate" numeric, "p_margin_amount" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_order_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_order_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_order_notification"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_secure_order"("p_user_id" "uuid", "p_seller_id" "uuid", "p_items" "jsonb", "p_shipping_address_id" "uuid", "p_payment_method" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_secure_order"("p_user_id" "uuid", "p_seller_id" "uuid", "p_items" "jsonb", "p_shipping_address_id" "uuid", "p_payment_method" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_secure_order"("p_user_id" "uuid", "p_seller_id" "uuid", "p_items" "jsonb", "p_shipping_address_id" "uuid", "p_payment_method" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_user_wallet_on_signup"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_user_wallet_on_signup"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_user_wallet_on_signup"() TO "service_role";



GRANT ALL ON FUNCTION "public"."credit_wallet"("p_user_id" "uuid", "p_amount" numeric, "p_reference_type" "text", "p_reference_id" "uuid", "p_description" "text", "p_idempotency_key" "text", "p_metadata" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."credit_wallet"("p_user_id" "uuid", "p_amount" numeric, "p_reference_type" "text", "p_reference_id" "uuid", "p_description" "text", "p_idempotency_key" "text", "p_metadata" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."credit_wallet"("p_user_id" "uuid", "p_amount" numeric, "p_reference_type" "text", "p_reference_id" "uuid", "p_description" "text", "p_idempotency_key" "text", "p_metadata" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."customer_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."customer_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."customer_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."debit_wallet"("p_user_id" "uuid", "p_amount" numeric, "p_reference_type" "text", "p_reference_id" "uuid", "p_description" "text", "p_idempotency_key" "text", "p_metadata" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."debit_wallet"("p_user_id" "uuid", "p_amount" numeric, "p_reference_type" "text", "p_reference_id" "uuid", "p_description" "text", "p_idempotency_key" "text", "p_metadata" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."debit_wallet"("p_user_id" "uuid", "p_amount" numeric, "p_reference_type" "text", "p_reference_id" "uuid", "p_description" "text", "p_idempotency_key" "text", "p_metadata" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."decrement_product_inventory"() TO "anon";
GRANT ALL ON FUNCTION "public"."decrement_product_inventory"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrement_product_inventory"() TO "service_role";



GRANT ALL ON FUNCTION "public"."decrement_product_inventory_on_order"() TO "anon";
GRANT ALL ON FUNCTION "public"."decrement_product_inventory_on_order"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrement_product_inventory_on_order"() TO "service_role";



GRANT ALL ON FUNCTION "public"."dequeue_job"("p_queue_name" "text", "p_visibility_timeout_seconds" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."dequeue_job"("p_queue_name" "text", "p_visibility_timeout_seconds" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dequeue_job"("p_queue_name" "text", "p_visibility_timeout_seconds" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_middleman_catalog_limit"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_middleman_catalog_limit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_middleman_catalog_limit"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enqueue_job"("p_queue_name" "text", "p_payload" "jsonb", "p_scheduled_for" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."enqueue_job"("p_queue_name" "text", "p_payload" "jsonb", "p_scheduled_for" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."enqueue_job"("p_queue_name" "text", "p_payload" "jsonb", "p_scheduled_for" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_shop_exists"() TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_shop_exists"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_shop_exists"() TO "service_role";



GRANT ALL ON FUNCTION "public"."execute_push_campaign"("p_campaign_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."execute_push_campaign"("p_campaign_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."execute_push_campaign"("p_campaign_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."export_patient_health_data"("p_patient_id" "uuid", "p_export_format" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."export_patient_health_data"("p_patient_id" "uuid", "p_export_format" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."export_patient_health_data"("p_patient_id" "uuid", "p_export_format" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."fill_prescription_medicine"("p_prescription_medicine_id" "uuid", "p_pharmacy_id" "uuid", "p_dispensed_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."fill_prescription_medicine"("p_prescription_medicine_id" "uuid", "p_pharmacy_id" "uuid", "p_dispensed_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."fill_prescription_medicine"("p_prescription_medicine_id" "uuid", "p_pharmacy_id" "uuid", "p_dispensed_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."find_factories"("p_search_term" "text", "p_location" "text", "p_is_verified" boolean, "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."find_factories"("p_search_term" "text", "p_location" "text", "p_is_verified" boolean, "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_factories"("p_search_term" "text", "p_location" "text", "p_is_verified" boolean, "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."find_nearby_drivers"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."find_nearby_drivers"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_nearby_drivers"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."find_nearby_drivers_for_middleman"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."find_nearby_drivers_for_middleman"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_nearby_drivers_for_middleman"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."find_nearby_factories"("p_seller_id" "uuid", "p_max_distance_km" numeric, "p_limit_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."find_nearby_factories"("p_seller_id" "uuid", "p_max_distance_km" numeric, "p_limit_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_nearby_factories"("p_seller_id" "uuid", "p_max_distance_km" numeric, "p_limit_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."find_nearby_factories"("p_seller_id" "uuid", "p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."find_nearby_factories"("p_seller_id" "uuid", "p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_nearby_factories"("p_seller_id" "uuid", "p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."find_nearby_products_for_middleman"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."find_nearby_products_for_middleman"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_nearby_products_for_middleman"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."find_nearby_sellers"("p_latitude" numeric, "p_longitude" numeric, "p_radius_km" numeric, "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."find_nearby_sellers"("p_latitude" numeric, "p_longitude" numeric, "p_radius_km" numeric, "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_nearby_sellers"("p_latitude" numeric, "p_longitude" numeric, "p_radius_km" numeric, "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_cod_verification_key"("p_order_id" "uuid", "p_key_length" integer, "p_expiry_hours" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."generate_cod_verification_key"("p_order_id" "uuid", "p_key_length" integer, "p_expiry_hours" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_cod_verification_key"("p_order_id" "uuid", "p_key_length" integer, "p_expiry_hours" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_medicine_qr_code"("p_pharmacy_id" "uuid", "p_medicine_id" "uuid", "p_batch_number" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_medicine_qr_code"("p_pharmacy_id" "uuid", "p_medicine_id" "uuid", "p_batch_number" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_medicine_qr_code"("p_pharmacy_id" "uuid", "p_medicine_id" "uuid", "p_batch_number" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_patient_archive_json"("p_doctor_id" "uuid", "p_patient_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_patient_archive_json"("p_doctor_id" "uuid", "p_patient_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_patient_archive_json"("p_doctor_id" "uuid", "p_patient_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_pharmacy_daily_report"("p_pharmacy_id" "uuid", "p_report_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_pharmacy_daily_report"("p_pharmacy_id" "uuid", "p_report_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_pharmacy_daily_report"("p_pharmacy_id" "uuid", "p_report_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_product_description"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_product_description"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_product_description"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_website_embed_code"("p_website_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_website_embed_code"("p_website_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_website_embed_code"("p_website_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_cod_reconciliation_report"("p_start_date" "date", "p_end_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_cod_reconciliation_report"("p_start_date" "date", "p_end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_cod_reconciliation_report"("p_start_date" "date", "p_end_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_driver_cod_orders"("p_driver_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_driver_cod_orders"("p_driver_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_driver_cod_orders"("p_driver_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_factory_rating"("p_factory_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_factory_rating"("p_factory_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_feed_posts"("p_limit" integer, "p_offset" integer, "p_user_id" "uuid", "p_post_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_feed_posts"("p_limit" integer, "p_offset" integer, "p_user_id" "uuid", "p_post_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_feed_posts"("p_limit" integer, "p_offset" integer, "p_user_id" "uuid", "p_post_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_health_audit_logs"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_health_audit_logs"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_health_audit_logs"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_health_conversation_messages"("p_conversation_id" "uuid", "p_limit" integer, "p_offset" integer, "p_before_timestamp" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."get_health_conversation_messages"("p_conversation_id" "uuid", "p_limit" integer, "p_offset" integer, "p_before_timestamp" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_health_conversation_messages"("p_conversation_id" "uuid", "p_limit" integer, "p_offset" integer, "p_before_timestamp" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_health_conversations_list"("p_limit" integer, "p_offset" integer, "p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_health_conversations_list"("p_limit" integer, "p_offset" integer, "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_health_conversations_list"("p_limit" integer, "p_offset" integer, "p_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_low_stock_products"("threshold" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_low_stock_products"("threshold" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_marketplace_products_for_middlemen"("p_category" "text", "p_min_price" numeric, "p_max_price" numeric, "p_min_stock" integer, "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_marketplace_products_for_middlemen"("p_category" "text", "p_min_price" numeric, "p_max_price" numeric, "p_min_stock" integer, "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_marketplace_products_for_middlemen"("p_category" "text", "p_min_price" numeric, "p_max_price" numeric, "p_min_stock" integer, "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_middle_man_ids"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_middle_man_ids"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_middle_man_ids"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_middleman_profile"("target_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_middleman_profile"("target_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_middleman_profile"("target_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_or_create_conversation"("p_other_user_id" "uuid", "p_product_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_or_create_conversation"("p_other_user_id" "uuid", "p_product_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_or_create_conversation"("p_other_user_id" "uuid", "p_product_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_or_create_direct_conversation"("p_user1_id" "uuid", "p_user2_id" "uuid", "p_display_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_or_create_direct_conversation"("p_user1_id" "uuid", "p_user2_id" "uuid", "p_display_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_or_create_direct_conversation"("p_user1_id" "uuid", "p_user2_id" "uuid", "p_display_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_or_create_direct_conversation_v2"("p_user1_id" "uuid", "p_user2_id" "uuid", "p_display_name" "text", "p_context_type" "text", "p_context_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_or_create_direct_conversation_v2"("p_user1_id" "uuid", "p_user2_id" "uuid", "p_display_name" "text", "p_context_type" "text", "p_context_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_or_create_health_conversation"("p_doctor_id" "uuid", "p_patient_id" "uuid", "p_appointment_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_or_create_health_conversation"("p_doctor_id" "uuid", "p_patient_id" "uuid", "p_appointment_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_or_create_health_conversation"("p_doctor_id" "uuid", "p_patient_id" "uuid", "p_appointment_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_or_create_service_conversation"("p_provider_id" "uuid", "p_listing_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_or_create_service_conversation"("p_provider_id" "uuid", "p_listing_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_or_create_service_conversation"("p_provider_id" "uuid", "p_listing_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_pharmacy_medicines"("p_search" "text", "p_category_id" "uuid", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_pharmacy_medicines"("p_search" "text", "p_category_id" "uuid", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_pharmacy_medicines"("p_search" "text", "p_category_id" "uuid", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_prescription_details"("p_prescription_id" "uuid", "p_requesting_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_prescription_details"("p_prescription_id" "uuid", "p_requesting_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_prescription_details"("p_prescription_id" "uuid", "p_requesting_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_product_image_url"("image_path" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_product_image_url"("image_path" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_product_image_url"("image_path" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_products_for_middleman"("target_middleman_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_products_for_middleman"("target_middleman_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_products_for_middleman"("target_middleman_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_provider_revenue"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_provider_revenue"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_provider_revenue"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_provider_revenue"("p_provider_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_provider_revenue"("p_provider_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_provider_revenue"("p_provider_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_provider_user_id"("p_provider_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_public_profile"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_public_profile"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_public_profile"("p_user_id" "uuid") TO "service_role";



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



GRANT ALL ON FUNCTION "public"."get_setting"("key_name" "text", "default_value" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."get_setting"("key_name" "text", "default_value" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_setting"("key_name" "text", "default_value" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_setting_float"("key_name" "text", "default_val" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."get_setting_float"("key_name" "text", "default_val" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_setting_float"("key_name" "text", "default_val" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_typing_indicators"("p_conversation_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_typing_indicators"("p_conversation_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_typing_indicators"("p_conversation_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_unified_orders"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_unified_orders"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_unified_orders"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_unread_notification_count"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_unread_notification_count"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_unread_notification_count"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_unread_push_count"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_unread_push_count"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_unread_push_count"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_conversations"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_conversations"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_conversations"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_conversations_with_products"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_conversations_with_products"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_conversations_with_products"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_verified_doctors"("p_specialty" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_verified_doctors"("p_specialty" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_verified_doctors"("p_specialty" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON TABLE "public"."websites" TO "anon";
GRANT ALL ON TABLE "public"."websites" TO "authenticated";
GRANT ALL ON TABLE "public"."websites" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_website_by_domain"("p_domain" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_website_by_domain"("p_domain" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_website_by_domain"("p_domain" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_oauth_signup"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_oauth_signup"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_oauth_signup"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_service_booking_notifications"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_service_booking_notifications"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_service_booking_notifications"() TO "service_role";



GRANT ALL ON FUNCTION "public"."has_google_account_linked"() TO "anon";
GRANT ALL ON FUNCTION "public"."has_google_account_linked"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."has_google_account_linked"() TO "service_role";



GRANT ALL ON FUNCTION "public"."haversine_distance"("lat1" double precision, "lon1" double precision, "lat2" double precision, "lon2" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."haversine_distance"("lat1" double precision, "lon1" double precision, "lat2" double precision, "lon2" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."haversine_distance"("lat1" double precision, "lon1" double precision, "lat2" double precision, "lon2" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_template_sales"() TO "anon";
GRANT ALL ON FUNCTION "public"."increment_template_sales"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_template_sales"() TO "service_role";



GRANT ALL ON FUNCTION "public"."initialize_user_notification_settings"() TO "anon";
GRANT ALL ON FUNCTION "public"."initialize_user_notification_settings"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."initialize_user_notification_settings"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_admin"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_admin_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."log_activity"("p_action_type" "text", "p_action_category" "text", "p_description" "text", "p_metadata" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."log_activity"("p_action_type" "text", "p_action_category" "text", "p_description" "text", "p_metadata" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_activity"("p_action_type" "text", "p_action_category" "text", "p_description" "text", "p_metadata" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."log_error"("p_error_type" "text", "p_error_message" "text", "p_stack_trace" "text", "p_screen_name" "text", "p_metadata" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."log_error"("p_error_type" "text", "p_error_message" "text", "p_stack_trace" "text", "p_screen_name" "text", "p_metadata" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_error"("p_error_type" "text", "p_error_message" "text", "p_stack_trace" "text", "p_screen_name" "text", "p_metadata" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."log_payment_activity"() TO "anon";
GRANT ALL ON FUNCTION "public"."log_payment_activity"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_payment_activity"() TO "service_role";



GRANT ALL ON FUNCTION "public"."log_payment_status_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."log_payment_status_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_payment_status_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."log_prescription_access"("p_prescription_id" "uuid", "p_access_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."log_prescription_access"("p_prescription_id" "uuid", "p_access_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_prescription_access"("p_prescription_id" "uuid", "p_access_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."log_wallet_transaction"() TO "anon";
GRANT ALL ON FUNCTION "public"."log_wallet_transaction"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_wallet_transaction"() TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_health_messages_read"("p_conversation_id" "uuid", "p_message_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."mark_health_messages_read"("p_conversation_id" "uuid", "p_message_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_health_messages_read"("p_conversation_id" "uuid", "p_message_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_notifications_read"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."mark_notifications_read"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_notifications_read"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_push_notification_opened"("p_notification_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."mark_push_notification_opened"("p_notification_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_push_notification_opened"("p_notification_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."messages_tsvector_trigger"() TO "anon";
GRANT ALL ON FUNCTION "public"."messages_tsvector_trigger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."messages_tsvector_trigger"() TO "service_role";



GRANT ALL ON FUNCTION "public"."middleman_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_company_name" "text", "p_location" "text", "p_currency" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."middleman_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_company_name" "text", "p_location" "text", "p_currency" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."middleman_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_company_name" "text", "p_location" "text", "p_currency" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_account_type_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_account_type_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_account_type_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."process_fawry_payment"("p_order_id" "uuid", "p_fawry_reference" "text", "p_amount" numeric, "p_gateway_response" "jsonb", "p_idempotency_key" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."process_fawry_payment"("p_order_id" "uuid", "p_fawry_reference" "text", "p_amount" numeric, "p_gateway_response" "jsonb", "p_idempotency_key" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_fawry_payment"("p_order_id" "uuid", "p_fawry_reference" "text", "p_amount" numeric, "p_gateway_response" "jsonb", "p_idempotency_key" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."process_medicine_order_payment"("p_order_id" "uuid", "p_payment_amount" numeric, "p_prescription_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."process_medicine_order_payment"("p_order_id" "uuid", "p_payment_amount" numeric, "p_prescription_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_medicine_order_payment"("p_order_id" "uuid", "p_payment_amount" numeric, "p_prescription_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."process_qr_scan"("p_pharmacy_id" "uuid", "p_user_id" "uuid", "p_qr_code" "text", "p_scan_type" "text", "p_device_info" "text", "p_location_lat" double precision, "p_location_lng" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."process_qr_scan"("p_pharmacy_id" "uuid", "p_user_id" "uuid", "p_qr_code" "text", "p_scan_type" "text", "p_device_info" "text", "p_location_lat" double precision, "p_location_lng" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_qr_scan"("p_pharmacy_id" "uuid", "p_user_id" "uuid", "p_qr_code" "text", "p_scan_type" "text", "p_device_info" "text", "p_location_lat" double precision, "p_location_lng" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."products_search_vector_trigger"() TO "anon";
GRANT ALL ON FUNCTION "public"."products_search_vector_trigger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."products_search_vector_trigger"() TO "service_role";



GRANT ALL ON FUNCTION "public"."products_tsvector_trigger"() TO "anon";
GRANT ALL ON FUNCTION "public"."products_tsvector_trigger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."products_tsvector_trigger"() TO "service_role";



GRANT ALL ON FUNCTION "public"."register_app_device"("p_token" "text", "p_platform" "text", "p_app_version" "text", "p_device_model" "text", "p_os_version" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."register_app_device"("p_token" "text", "p_platform" "text", "p_app_version" "text", "p_device_model" "text", "p_os_version" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_app_device"("p_token" "text", "p_platform" "text", "p_app_version" "text", "p_device_model" "text", "p_os_version" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."register_push_subscription"("p_token" "text", "p_platform" "text", "p_app_version" "text", "p_device_model" "text", "p_os_version" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."register_push_subscription"("p_token" "text", "p_platform" "text", "p_app_version" "text", "p_device_model" "text", "p_os_version" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_push_subscription"("p_token" "text", "p_platform" "text", "p_app_version" "text", "p_device_model" "text", "p_os_version" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."request_payout"("p_user_id" "uuid", "p_amount" numeric, "p_payout_method" "text", "p_bank_details" "jsonb", "p_idempotency_key" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."request_payout"("p_user_id" "uuid", "p_amount" numeric, "p_payout_method" "text", "p_bank_details" "jsonb", "p_idempotency_key" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."request_payout"("p_user_id" "uuid", "p_amount" numeric, "p_payout_method" "text", "p_bank_details" "jsonb", "p_idempotency_key" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."restore_product_inventory_on_cancel"() TO "anon";
GRANT ALL ON FUNCTION "public"."restore_product_inventory_on_cancel"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."restore_product_inventory_on_cancel"() TO "service_role";



GRANT ALL ON FUNCTION "public"."run_daily_patient_backup"("p_doctor_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."run_daily_patient_backup"("p_doctor_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."run_daily_patient_backup"("p_doctor_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."schedule_appointment"("p_patient_id" "uuid", "p_doctor_id" "uuid", "p_appointment_date" timestamp with time zone, "p_reason" "text", "p_appointment_type" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."schedule_appointment"("p_patient_id" "uuid", "p_doctor_id" "uuid", "p_appointment_date" timestamp with time zone, "p_reason" "text", "p_appointment_type" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."schedule_appointment"("p_patient_id" "uuid", "p_doctor_id" "uuid", "p_appointment_date" timestamp with time zone, "p_reason" "text", "p_appointment_type" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."search_auth_users"("p_query" "text", "p_current_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."search_auth_users"("p_query" "text", "p_current_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_auth_users"("p_query" "text", "p_current_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."search_health_messages"("p_conversation_id" "uuid", "p_search_term" "text", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."search_health_messages"("p_conversation_id" "uuid", "p_search_term" "text", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_health_messages"("p_conversation_id" "uuid", "p_search_term" "text", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."search_public_profiles"("p_search_term" "text", "p_account_type" "text", "p_location" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."search_public_profiles"("p_search_term" "text", "p_account_type" "text", "p_location" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_public_profiles"("p_search_term" "text", "p_account_type" "text", "p_location" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."search_users"("p_query" "text", "p_exclude_user_id" "uuid", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_users"("p_query" "text", "p_exclude_user_id" "uuid", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."search_users_for_chat"("p_query" "text", "p_current_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."search_users_for_chat"("p_query" "text", "p_current_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_users_for_chat"("p_query" "text", "p_current_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."seller_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text", "p_location" "text", "p_currency" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."seller_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text", "p_location" "text", "p_currency" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."seller_signup"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text", "p_location" "text", "p_currency" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."send_health_message"("p_conversation_id" "uuid", "p_content" "text", "p_message_type" "text", "p_attachment_url" "text", "p_attachment_name" "text", "p_attachment_size" bigint, "p_attachment_type" "text", "p_metadata" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."send_health_message"("p_conversation_id" "uuid", "p_content" "text", "p_message_type" "text", "p_attachment_url" "text", "p_attachment_name" "text", "p_attachment_size" bigint, "p_attachment_type" "text", "p_metadata" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_health_message"("p_conversation_id" "uuid", "p_content" "text", "p_message_type" "text", "p_attachment_url" "text", "p_attachment_name" "text", "p_attachment_size" bigint, "p_attachment_type" "text", "p_metadata" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."send_push_campaign"("p_title" "text", "p_body" "text", "p_target_user_ids" "uuid"[], "p_target_account_types" "text"[], "p_data" "jsonb", "p_notification_type" "text", "p_scheduled_at" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."send_push_campaign"("p_title" "text", "p_body" "text", "p_target_user_ids" "uuid"[], "p_target_account_types" "text"[], "p_data" "jsonb", "p_notification_type" "text", "p_scheduled_at" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_push_campaign"("p_title" "text", "p_body" "text", "p_target_user_ids" "uuid"[], "p_target_account_types" "text"[], "p_data" "jsonb", "p_notification_type" "text", "p_scheduled_at" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."send_push_notification"("p_user_id" "uuid", "p_title" "text", "p_body" "text", "p_data" "jsonb", "p_notification_type" "text", "p_priority" "text", "p_skip_quiet_hours" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."send_push_notification"("p_user_id" "uuid", "p_title" "text", "p_body" "text", "p_data" "jsonb", "p_notification_type" "text", "p_priority" "text", "p_skip_quiet_hours" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_push_notification"("p_user_id" "uuid", "p_title" "text", "p_body" "text", "p_data" "jsonb", "p_notification_type" "text", "p_priority" "text", "p_skip_quiet_hours" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "postgres";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "anon";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_profiles_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_profiles_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_profiles_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."share_prescription_with_pharmacy"("p_prescription_id" "uuid", "p_pharmacy_id" "uuid", "p_valid_hours" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."share_prescription_with_pharmacy"("p_prescription_id" "uuid", "p_pharmacy_id" "uuid", "p_valid_hours" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."share_prescription_with_pharmacy"("p_prescription_id" "uuid", "p_pharmacy_id" "uuid", "p_valid_hours" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."show_limit"() TO "postgres";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "anon";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "service_role";



GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."signup_middleman"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text", "p_company_name" "text", "p_location" "text", "p_currency" "text", "p_commission_rate" numeric, "p_specialization" "text", "p_years_of_experience" integer, "p_tax_id" "text", "p_bio" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."signup_middleman"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text", "p_company_name" "text", "p_location" "text", "p_currency" "text", "p_commission_rate" numeric, "p_specialization" "text", "p_years_of_experience" integer, "p_tax_id" "text", "p_bio" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."signup_middleman"("p_email" "text", "p_password" "text", "p_full_name" "text", "p_phone" "text", "p_company_name" "text", "p_location" "text", "p_currency" "text", "p_commission_rate" numeric, "p_specialization" "text", "p_years_of_experience" integer, "p_tax_id" "text", "p_bio" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."split_payment_to_parties"("p_order_id" "uuid", "p_transaction_id" "uuid", "p_total_amount" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."split_payment_to_parties"("p_order_id" "uuid", "p_transaction_id" "uuid", "p_total_amount" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."split_payment_to_parties"("p_order_id" "uuid", "p_transaction_id" "uuid", "p_total_amount" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."split_template_purchase"("p_purchase_id" "uuid", "p_total_amount" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."split_template_purchase"("p_purchase_id" "uuid", "p_total_amount" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."split_template_purchase"("p_purchase_id" "uuid", "p_total_amount" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."submit_consent_form"("p_patient_id" "uuid", "p_consent_type" character varying, "p_consent_data" "jsonb", "p_signature_url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."submit_consent_form"("p_patient_id" "uuid", "p_consent_type" character varying, "p_consent_data" "jsonb", "p_signature_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_consent_form"("p_patient_id" "uuid", "p_consent_type" character varying, "p_consent_data" "jsonb", "p_signature_url" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."sync_participant_account_type"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sync_participant_account_type"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_participant_account_type"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_participant_account_type"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_user_roles"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_user_roles"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_user_roles"() TO "service_role";



GRANT ALL ON FUNCTION "public"."track_deal_click"("p_unique_slug" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."track_deal_click"("p_unique_slug" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."track_deal_click"("p_unique_slug" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_push_appointment_reminder"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_push_appointment_reminder"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_push_appointment_reminder"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_push_low_stock_alert"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_push_low_stock_alert"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_push_low_stock_alert"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_push_on_medicine_order_status"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_push_on_medicine_order_status"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_push_on_medicine_order_status"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_push_on_prescription_created"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_push_on_prescription_created"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_push_on_prescription_created"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_push_payment_received"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_push_payment_received"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_push_payment_received"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_conversation_on_deal_proposal"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_conversation_on_deal_proposal"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_conversation_on_deal_proposal"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_conversation_on_message"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_conversation_on_message"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_conversation_on_message"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_conversation_unread_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_conversation_unread_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_conversation_unread_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_customer_stats_on_sale"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_customer_stats_on_sale"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_customer_stats_on_sale"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_customers_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_customers_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_customers_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_delivery_assignments_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_delivery_assignments_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_delivery_assignments_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_delivery_profiles_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_delivery_profiles_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_delivery_profiles_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_factory_connections_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_factory_connections_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_factory_connections_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_factory_profile_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_factory_profile_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_factory_profile_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_freelancer_rating"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_freelancer_rating"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_freelancer_rating"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_freelancer_stats_on_completion"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_freelancer_stats_on_completion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_freelancer_stats_on_completion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_health_conversation_on_message"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_health_conversation_on_message"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_health_conversation_on_message"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_health_pharmacy_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_health_pharmacy_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_health_pharmacy_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_health_timestamps"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_health_timestamps"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_health_timestamps"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_medicine_expiry_status"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_medicine_expiry_status"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_medicine_expiry_status"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_medicine_rating"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_medicine_rating"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_medicine_rating"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_medicine_stock_on_order"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_medicine_stock_on_order"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_medicine_stock_on_order"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_notifications_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_notifications_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_notifications_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_order_payment_status"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_order_payment_status"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_order_payment_status"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_order_status_secure"("p_order_id" "uuid", "p_seller_id" "uuid", "p_new_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_order_status_secure"("p_order_id" "uuid", "p_seller_id" "uuid", "p_new_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_order_status_secure"("p_order_id" "uuid", "p_seller_id" "uuid", "p_new_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_order_status_timestamps"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_order_status_timestamps"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_order_status_timestamps"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_patient_visit_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_patient_visit_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_patient_visit_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_post_comments_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_post_comments_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_post_comments_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_post_likes_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_post_likes_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_post_likes_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_product_rating"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_product_rating"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_product_rating"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_products_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_products_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_products_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_sales_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_sales_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_sales_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_seller_product_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_seller_product_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_seller_product_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_seller_stats_on_order_delivered"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_seller_stats_on_order_delivered"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_seller_stats_on_order_delivered"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_svc_conv_on_message"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_svc_conv_on_message"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_svc_conv_on_message"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_svc_provider_rating"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_svc_provider_rating"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_svc_provider_rating"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_svc_provider_stats"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_svc_provider_stats"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_svc_provider_stats"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_svc_timestamps"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_svc_timestamps"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_svc_timestamps"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_trading_conv_on_message"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_trading_conv_on_message"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_trading_conv_on_message"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_typing_indicator"("p_conversation_id" "uuid", "p_is_typing" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."update_typing_indicator"("p_conversation_id" "uuid", "p_is_typing" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_typing_indicator"("p_conversation_id" "uuid", "p_is_typing" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_last_seen"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_last_seen"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_last_seen"() TO "service_role";



GRANT ALL ON FUNCTION "public"."user_is_in_conversation"("p_conversation_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."user_is_in_conversation"("p_conversation_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_is_in_conversation"("p_conversation_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_product_price"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_product_price"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_product_price"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_wallet_balance"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_wallet_balance"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_wallet_balance"() TO "service_role";



GRANT ALL ON FUNCTION "public"."verify_cod_verification_key"("p_verification_key" "text", "p_driver_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."verify_cod_verification_key"("p_verification_key" "text", "p_driver_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."verify_cod_verification_key"("p_verification_key" "text", "p_driver_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."verify_doctor"("p_doctor_id" "uuid", "p_verified_by" "uuid", "p_notes" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."verify_doctor"("p_doctor_id" "uuid", "p_verified_by" "uuid", "p_notes" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."verify_doctor"("p_doctor_id" "uuid", "p_verified_by" "uuid", "p_notes" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."verify_middleman_email"("p_verification_token" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."verify_middleman_email"("p_verification_token" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."verify_middleman_email"("p_verification_token" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."verify_purchase_before_review"() TO "anon";
GRANT ALL ON FUNCTION "public"."verify_purchase_before_review"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."verify_purchase_before_review"() TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "service_role";





























































































GRANT ALL ON TABLE "public"."activity_logs" TO "anon";
GRANT ALL ON TABLE "public"."activity_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."activity_logs" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."admin_users" TO "anon";
GRANT ALL ON TABLE "public"."admin_users" TO "authenticated";
GRANT ALL ON TABLE "public"."admin_users" TO "service_role";



GRANT ALL ON TABLE "public"."admins" TO "anon";
GRANT ALL ON TABLE "public"."admins" TO "authenticated";
GRANT ALL ON TABLE "public"."admins" TO "service_role";



GRANT ALL ON TABLE "public"."analytics" TO "anon";
GRANT ALL ON TABLE "public"."analytics" TO "authenticated";
GRANT ALL ON TABLE "public"."analytics" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."analytics_snapshots" TO "anon";
GRANT ALL ON TABLE "public"."analytics_snapshots" TO "authenticated";
GRANT ALL ON TABLE "public"."analytics_snapshots" TO "service_role";



GRANT ALL ON TABLE "public"."analytics_uploads" TO "anon";
GRANT ALL ON TABLE "public"."analytics_uploads" TO "authenticated";
GRANT ALL ON TABLE "public"."analytics_uploads" TO "service_role";



GRANT ALL ON TABLE "public"."app_devices" TO "anon";
GRANT ALL ON TABLE "public"."app_devices" TO "authenticated";
GRANT ALL ON TABLE "public"."app_devices" TO "service_role";



GRANT ALL ON TABLE "public"."appointments" TO "anon";
GRANT ALL ON TABLE "public"."appointments" TO "authenticated";
GRANT ALL ON TABLE "public"."appointments" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."async_jobs" TO "anon";
GRANT ALL ON TABLE "public"."async_jobs" TO "authenticated";
GRANT ALL ON TABLE "public"."async_jobs" TO "service_role";



GRANT ALL ON TABLE "public"."booking_milestones" TO "anon";
GRANT ALL ON TABLE "public"."booking_milestones" TO "authenticated";
GRANT ALL ON TABLE "public"."booking_milestones" TO "service_role";



GRANT ALL ON TABLE "public"."brands" TO "anon";
GRANT ALL ON TABLE "public"."brands" TO "authenticated";
GRANT ALL ON TABLE "public"."brands" TO "service_role";



GRANT ALL ON TABLE "public"."business_profiles" TO "anon";
GRANT ALL ON TABLE "public"."business_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."business_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."calls" TO "anon";
GRANT ALL ON TABLE "public"."calls" TO "authenticated";
GRANT ALL ON TABLE "public"."calls" TO "service_role";



GRANT ALL ON TABLE "public"."cart" TO "anon";
GRANT ALL ON TABLE "public"."cart" TO "authenticated";
GRANT ALL ON TABLE "public"."cart" TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."categories_backup_20260308_124506" TO "anon";
GRANT ALL ON TABLE "public"."categories_backup_20260308_124506" TO "authenticated";
GRANT ALL ON TABLE "public"."categories_backup_20260308_124506" TO "service_role";



GRANT ALL ON TABLE "public"."cod_collections" TO "anon";
GRANT ALL ON TABLE "public"."cod_collections" TO "authenticated";
GRANT ALL ON TABLE "public"."cod_collections" TO "service_role";



GRANT ALL ON TABLE "public"."cod_verification_keys" TO "anon";
GRANT ALL ON TABLE "public"."cod_verification_keys" TO "authenticated";
GRANT ALL ON TABLE "public"."cod_verification_keys" TO "service_role";



GRANT ALL ON TABLE "public"."commissions" TO "anon";
GRANT ALL ON TABLE "public"."commissions" TO "authenticated";
GRANT ALL ON TABLE "public"."commissions" TO "service_role";



GRANT ALL ON TABLE "public"."conversation_participants" TO "anon";
GRANT ALL ON TABLE "public"."conversation_participants" TO "authenticated";
GRANT ALL ON TABLE "public"."conversation_participants" TO "service_role";



GRANT ALL ON TABLE "public"."conversations" TO "anon";
GRANT ALL ON TABLE "public"."conversations" TO "authenticated";
GRANT ALL ON TABLE "public"."conversations" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."customers" TO "anon";
GRANT ALL ON TABLE "public"."customers" TO "authenticated";
GRANT ALL ON TABLE "public"."customers" TO "service_role";



GRANT ALL ON TABLE "public"."deal_proposals" TO "anon";
GRANT ALL ON TABLE "public"."deal_proposals" TO "authenticated";
GRANT ALL ON TABLE "public"."deal_proposals" TO "service_role";



GRANT ALL ON TABLE "public"."deals" TO "anon";
GRANT ALL ON TABLE "public"."deals" TO "authenticated";
GRANT ALL ON TABLE "public"."deals" TO "service_role";



GRANT ALL ON TABLE "public"."deals_v2" TO "anon";
GRANT ALL ON TABLE "public"."deals_v2" TO "authenticated";
GRANT ALL ON TABLE "public"."deals_v2" TO "service_role";



GRANT ALL ON TABLE "public"."delivery_assignments" TO "anon";
GRANT ALL ON TABLE "public"."delivery_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."delivery_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."delivery_profiles" TO "anon";
GRANT ALL ON TABLE "public"."delivery_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."delivery_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."doctor_medicine_deals" TO "anon";
GRANT ALL ON TABLE "public"."doctor_medicine_deals" TO "authenticated";
GRANT ALL ON TABLE "public"."doctor_medicine_deals" TO "service_role";



GRANT ALL ON TABLE "public"."doctor_performance_metrics" TO "anon";
GRANT ALL ON TABLE "public"."doctor_performance_metrics" TO "authenticated";
GRANT ALL ON TABLE "public"."doctor_performance_metrics" TO "service_role";



GRANT ALL ON TABLE "public"."doctors" TO "anon";
GRANT ALL ON TABLE "public"."doctors" TO "authenticated";
GRANT ALL ON TABLE "public"."doctors" TO "service_role";



GRANT ALL ON TABLE "public"."error_logs" TO "anon";
GRANT ALL ON TABLE "public"."error_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."error_logs" TO "service_role";



GRANT ALL ON TABLE "public"."factories" TO "anon";
GRANT ALL ON TABLE "public"."factories" TO "authenticated";
GRANT ALL ON TABLE "public"."factories" TO "service_role";



GRANT ALL ON TABLE "public"."factory_connections" TO "anon";
GRANT ALL ON TABLE "public"."factory_connections" TO "authenticated";
GRANT ALL ON TABLE "public"."factory_connections" TO "service_role";



GRANT ALL ON TABLE "public"."factory_production_logs" TO "anon";
GRANT ALL ON TABLE "public"."factory_production_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."factory_production_logs" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sellers" TO "anon";
GRANT ALL ON TABLE "public"."sellers" TO "authenticated";
GRANT ALL ON TABLE "public"."sellers" TO "service_role";



GRANT ALL ON TABLE "public"."factory_products" TO "anon";
GRANT ALL ON TABLE "public"."factory_products" TO "authenticated";
GRANT ALL ON TABLE "public"."factory_products" TO "service_role";



GRANT ALL ON TABLE "public"."factory_profiles" TO "anon";
GRANT ALL ON TABLE "public"."factory_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."factory_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."factory_quotes" TO "anon";
GRANT ALL ON TABLE "public"."factory_quotes" TO "authenticated";
GRANT ALL ON TABLE "public"."factory_quotes" TO "service_role";



GRANT ALL ON TABLE "public"."factory_ratings" TO "anon";
GRANT ALL ON TABLE "public"."factory_ratings" TO "authenticated";
GRANT ALL ON TABLE "public"."factory_ratings" TO "service_role";



GRANT ALL ON TABLE "public"."freelancer_orders" TO "anon";
GRANT ALL ON TABLE "public"."freelancer_orders" TO "authenticated";
GRANT ALL ON TABLE "public"."freelancer_orders" TO "service_role";



GRANT ALL ON TABLE "public"."freelancer_portfolio" TO "anon";
GRANT ALL ON TABLE "public"."freelancer_portfolio" TO "authenticated";
GRANT ALL ON TABLE "public"."freelancer_portfolio" TO "service_role";



GRANT ALL ON TABLE "public"."freelancer_profiles" TO "anon";
GRANT ALL ON TABLE "public"."freelancer_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."freelancer_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."freelancer_services" TO "anon";
GRANT ALL ON TABLE "public"."freelancer_services" TO "authenticated";
GRANT ALL ON TABLE "public"."freelancer_services" TO "service_role";



GRANT ALL ON TABLE "public"."freelancer_stats" TO "anon";
GRANT ALL ON TABLE "public"."freelancer_stats" TO "authenticated";
GRANT ALL ON TABLE "public"."freelancer_stats" TO "service_role";



GRANT ALL ON TABLE "public"."health_appointments" TO "anon";
GRANT ALL ON TABLE "public"."health_appointments" TO "authenticated";
GRANT ALL ON TABLE "public"."health_appointments" TO "service_role";



GRANT ALL ON TABLE "public"."health_chat_attachments" TO "anon";
GRANT ALL ON TABLE "public"."health_chat_attachments" TO "authenticated";
GRANT ALL ON TABLE "public"."health_chat_attachments" TO "service_role";



GRANT ALL ON TABLE "public"."health_conversations" TO "anon";
GRANT ALL ON TABLE "public"."health_conversations" TO "authenticated";
GRANT ALL ON TABLE "public"."health_conversations" TO "service_role";



GRANT ALL ON TABLE "public"."health_daily_backup_status" TO "anon";
GRANT ALL ON TABLE "public"."health_daily_backup_status" TO "authenticated";
GRANT ALL ON TABLE "public"."health_daily_backup_status" TO "service_role";



GRANT ALL ON TABLE "public"."health_doctor_profiles" TO "anon";
GRANT ALL ON TABLE "public"."health_doctor_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."health_doctor_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."health_medicine_categories" TO "anon";
GRANT ALL ON TABLE "public"."health_medicine_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."health_medicine_categories" TO "service_role";



GRANT ALL ON TABLE "public"."health_medicine_expiry_alerts" TO "anon";
GRANT ALL ON TABLE "public"."health_medicine_expiry_alerts" TO "authenticated";
GRANT ALL ON TABLE "public"."health_medicine_expiry_alerts" TO "service_role";



GRANT ALL ON TABLE "public"."health_medicine_order_items" TO "anon";
GRANT ALL ON TABLE "public"."health_medicine_order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."health_medicine_order_items" TO "service_role";



GRANT ALL ON TABLE "public"."health_medicine_orders" TO "anon";
GRANT ALL ON TABLE "public"."health_medicine_orders" TO "authenticated";
GRANT ALL ON TABLE "public"."health_medicine_orders" TO "service_role";



GRANT ALL ON TABLE "public"."health_medicine_recalls" TO "anon";
GRANT ALL ON TABLE "public"."health_medicine_recalls" TO "authenticated";
GRANT ALL ON TABLE "public"."health_medicine_recalls" TO "service_role";



GRANT ALL ON TABLE "public"."health_medicine_reviews" TO "anon";
GRANT ALL ON TABLE "public"."health_medicine_reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."health_medicine_reviews" TO "service_role";



GRANT ALL ON TABLE "public"."health_medicine_stock_history" TO "anon";
GRANT ALL ON TABLE "public"."health_medicine_stock_history" TO "authenticated";
GRANT ALL ON TABLE "public"."health_medicine_stock_history" TO "service_role";



GRANT ALL ON TABLE "public"."health_medicines" TO "anon";
GRANT ALL ON TABLE "public"."health_medicines" TO "authenticated";
GRANT ALL ON TABLE "public"."health_medicines" TO "service_role";



GRANT ALL ON TABLE "public"."health_medicines_master" TO "anon";
GRANT ALL ON TABLE "public"."health_medicines_master" TO "authenticated";
GRANT ALL ON TABLE "public"."health_medicines_master" TO "service_role";



GRANT ALL ON TABLE "public"."health_message_archives" TO "anon";
GRANT ALL ON TABLE "public"."health_message_archives" TO "authenticated";
GRANT ALL ON TABLE "public"."health_message_archives" TO "service_role";



GRANT ALL ON TABLE "public"."health_message_receipts" TO "anon";
GRANT ALL ON TABLE "public"."health_message_receipts" TO "authenticated";
GRANT ALL ON TABLE "public"."health_message_receipts" TO "service_role";



GRANT ALL ON TABLE "public"."health_messages" TO "anon";
GRANT ALL ON TABLE "public"."health_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."health_messages" TO "service_role";



GRANT ALL ON TABLE "public"."health_patient_access_log" TO "anon";
GRANT ALL ON TABLE "public"."health_patient_access_log" TO "authenticated";
GRANT ALL ON TABLE "public"."health_patient_access_log" TO "service_role";



GRANT ALL ON TABLE "public"."health_patient_archives" TO "anon";
GRANT ALL ON TABLE "public"."health_patient_archives" TO "authenticated";
GRANT ALL ON TABLE "public"."health_patient_archives" TO "service_role";



GRANT ALL ON TABLE "public"."health_patient_change_log" TO "anon";
GRANT ALL ON TABLE "public"."health_patient_change_log" TO "authenticated";
GRANT ALL ON TABLE "public"."health_patient_change_log" TO "service_role";



GRANT ALL ON TABLE "public"."health_patient_profiles" TO "anon";
GRANT ALL ON TABLE "public"."health_patient_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."health_patient_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."health_pharmacy_inspections" TO "anon";
GRANT ALL ON TABLE "public"."health_pharmacy_inspections" TO "authenticated";
GRANT ALL ON TABLE "public"."health_pharmacy_inspections" TO "service_role";



GRANT ALL ON TABLE "public"."health_pharmacy_inventory" TO "anon";
GRANT ALL ON TABLE "public"."health_pharmacy_inventory" TO "authenticated";
GRANT ALL ON TABLE "public"."health_pharmacy_inventory" TO "service_role";



GRANT ALL ON TABLE "public"."health_pharmacy_profiles" TO "anon";
GRANT ALL ON TABLE "public"."health_pharmacy_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."health_pharmacy_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."health_prescription_access_log" TO "anon";
GRANT ALL ON TABLE "public"."health_prescription_access_log" TO "authenticated";
GRANT ALL ON TABLE "public"."health_prescription_access_log" TO "service_role";



GRANT ALL ON TABLE "public"."health_prescription_audit_log" TO "anon";
GRANT ALL ON TABLE "public"."health_prescription_audit_log" TO "authenticated";
GRANT ALL ON TABLE "public"."health_prescription_audit_log" TO "service_role";



GRANT ALL ON TABLE "public"."health_prescription_medicines" TO "anon";
GRANT ALL ON TABLE "public"."health_prescription_medicines" TO "authenticated";
GRANT ALL ON TABLE "public"."health_prescription_medicines" TO "service_role";



GRANT ALL ON TABLE "public"."health_prescription_medicines_digital" TO "anon";
GRANT ALL ON TABLE "public"."health_prescription_medicines_digital" TO "authenticated";
GRANT ALL ON TABLE "public"."health_prescription_medicines_digital" TO "service_role";



GRANT ALL ON TABLE "public"."health_prescription_shares" TO "anon";
GRANT ALL ON TABLE "public"."health_prescription_shares" TO "authenticated";
GRANT ALL ON TABLE "public"."health_prescription_shares" TO "service_role";



GRANT ALL ON TABLE "public"."health_prescriptions" TO "anon";
GRANT ALL ON TABLE "public"."health_prescriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."health_prescriptions" TO "service_role";



GRANT ALL ON TABLE "public"."health_prescriptions_digital" TO "anon";
GRANT ALL ON TABLE "public"."health_prescriptions_digital" TO "authenticated";
GRANT ALL ON TABLE "public"."health_prescriptions_digital" TO "service_role";



GRANT ALL ON TABLE "public"."health_reviews" TO "anon";
GRANT ALL ON TABLE "public"."health_reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."health_reviews" TO "service_role";



GRANT ALL ON TABLE "public"."health_typing_indicators" TO "anon";
GRANT ALL ON TABLE "public"."health_typing_indicators" TO "authenticated";
GRANT ALL ON TABLE "public"."health_typing_indicators" TO "service_role";



GRANT ALL ON TABLE "public"."healthcare_provider_profiles" TO "anon";
GRANT ALL ON TABLE "public"."healthcare_provider_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."healthcare_provider_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."service_appointments" TO "anon";
GRANT ALL ON TABLE "public"."service_appointments" TO "authenticated";
GRANT ALL ON TABLE "public"."service_appointments" TO "service_role";



GRANT ALL ON TABLE "public"."healthcare_provider_stats" TO "anon";
GRANT ALL ON TABLE "public"."healthcare_provider_stats" TO "authenticated";
GRANT ALL ON TABLE "public"."healthcare_provider_stats" TO "service_role";



GRANT ALL ON TABLE "public"."hospitals" TO "anon";
GRANT ALL ON TABLE "public"."hospitals" TO "authenticated";
GRANT ALL ON TABLE "public"."hospitals" TO "service_role";



GRANT ALL ON TABLE "public"."idempotency_keys" TO "anon";
GRANT ALL ON TABLE "public"."idempotency_keys" TO "authenticated";
GRANT ALL ON TABLE "public"."idempotency_keys" TO "service_role";



GRANT ALL ON TABLE "public"."location_history" TO "anon";
GRANT ALL ON TABLE "public"."location_history" TO "authenticated";
GRANT ALL ON TABLE "public"."location_history" TO "service_role";



GRANT ALL ON TABLE "public"."marketplace_purchases" TO "anon";
GRANT ALL ON TABLE "public"."marketplace_purchases" TO "authenticated";
GRANT ALL ON TABLE "public"."marketplace_purchases" TO "service_role";



GRANT ALL ON TABLE "public"."medical_staff" TO "anon";
GRANT ALL ON TABLE "public"."medical_staff" TO "authenticated";
GRANT ALL ON TABLE "public"."medical_staff" TO "service_role";



GRANT ALL ON TABLE "public"."medicine_sales_analytics" TO "anon";
GRANT ALL ON TABLE "public"."medicine_sales_analytics" TO "authenticated";
GRANT ALL ON TABLE "public"."medicine_sales_analytics" TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."middle_man_deals" TO "anon";
GRANT ALL ON TABLE "public"."middle_man_deals" TO "authenticated";
GRANT ALL ON TABLE "public"."middle_man_deals" TO "service_role";



GRANT ALL ON TABLE "public"."middle_men" TO "anon";
GRANT ALL ON TABLE "public"."middle_men" TO "authenticated";
GRANT ALL ON TABLE "public"."middle_men" TO "service_role";



GRANT ALL ON TABLE "public"."middleman_connections" TO "anon";
GRANT ALL ON TABLE "public"."middleman_connections" TO "authenticated";
GRANT ALL ON TABLE "public"."middleman_connections" TO "service_role";



GRANT ALL ON TABLE "public"."middleman_profiles" TO "anon";
GRANT ALL ON TABLE "public"."middleman_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."middleman_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."middleman_seller_links" TO "anon";
GRANT ALL ON TABLE "public"."middleman_seller_links" TO "authenticated";
GRANT ALL ON TABLE "public"."middleman_seller_links" TO "service_role";



GRANT ALL ON TABLE "public"."middleman_store_configs" TO "anon";
GRANT ALL ON TABLE "public"."middleman_store_configs" TO "authenticated";
GRANT ALL ON TABLE "public"."middleman_store_configs" TO "service_role";



GRANT ALL ON TABLE "public"."notification_settings" TO "anon";
GRANT ALL ON TABLE "public"."notification_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_settings" TO "service_role";



GRANT ALL ON TABLE "public"."notification_templates" TO "anon";
GRANT ALL ON TABLE "public"."notification_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_templates" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."order_items" TO "anon";
GRANT ALL ON TABLE "public"."order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."order_items" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."orders" TO "anon";
GRANT ALL ON TABLE "public"."orders" TO "authenticated";
GRANT ALL ON TABLE "public"."orders" TO "service_role";



GRANT ALL ON TABLE "public"."patient_medicine_preferences" TO "anon";
GRANT ALL ON TABLE "public"."patient_medicine_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."patient_medicine_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."payment_intentions" TO "anon";
GRANT ALL ON TABLE "public"."payment_intentions" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_intentions" TO "service_role";



GRANT ALL ON TABLE "public"."payment_splits" TO "anon";
GRANT ALL ON TABLE "public"."payment_splits" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_splits" TO "service_role";



GRANT ALL ON TABLE "public"."payment_transactions" TO "anon";
GRANT ALL ON TABLE "public"."payment_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_transactions" TO "service_role";



GRANT ALL ON TABLE "public"."payment_webhook_logs" TO "anon";
GRANT ALL ON TABLE "public"."payment_webhook_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_webhook_logs" TO "service_role";



GRANT ALL ON TABLE "public"."payout_requests" TO "anon";
GRANT ALL ON TABLE "public"."payout_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."payout_requests" TO "service_role";



GRANT ALL ON TABLE "public"."payouts" TO "anon";
GRANT ALL ON TABLE "public"."payouts" TO "authenticated";
GRANT ALL ON TABLE "public"."payouts" TO "service_role";



GRANT ALL ON TABLE "public"."pharmacy_activity_logs" TO "anon";
GRANT ALL ON TABLE "public"."pharmacy_activity_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."pharmacy_activity_logs" TO "service_role";



GRANT ALL ON TABLE "public"."pharmacy_daily_reports" TO "anon";
GRANT ALL ON TABLE "public"."pharmacy_daily_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."pharmacy_daily_reports" TO "service_role";



GRANT ALL ON TABLE "public"."pharmacy_details" TO "anon";
GRANT ALL ON TABLE "public"."pharmacy_details" TO "authenticated";
GRANT ALL ON TABLE "public"."pharmacy_details" TO "service_role";



GRANT ALL ON TABLE "public"."pharmacy_medicine_inventory" TO "anon";
GRANT ALL ON TABLE "public"."pharmacy_medicine_inventory" TO "authenticated";
GRANT ALL ON TABLE "public"."pharmacy_medicine_inventory" TO "service_role";



GRANT ALL ON TABLE "public"."pharmacy_products" TO "anon";
GRANT ALL ON TABLE "public"."pharmacy_products" TO "authenticated";
GRANT ALL ON TABLE "public"."pharmacy_products" TO "service_role";



GRANT ALL ON TABLE "public"."pharmacy_profiles" TO "anon";
GRANT ALL ON TABLE "public"."pharmacy_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."pharmacy_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."pharmacy_qr_scan_logs" TO "anon";
GRANT ALL ON TABLE "public"."pharmacy_qr_scan_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."pharmacy_qr_scan_logs" TO "service_role";



GRANT ALL ON TABLE "public"."pharmacy_stock_movements" TO "anon";
GRANT ALL ON TABLE "public"."pharmacy_stock_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."pharmacy_stock_movements" TO "service_role";



GRANT ALL ON TABLE "public"."platform_reports" TO "anon";
GRANT ALL ON TABLE "public"."platform_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."platform_reports" TO "service_role";



GRANT ALL ON TABLE "public"."platform_revenue" TO "anon";
GRANT ALL ON TABLE "public"."platform_revenue" TO "authenticated";
GRANT ALL ON TABLE "public"."platform_revenue" TO "service_role";



GRANT ALL ON TABLE "public"."platform_settings" TO "anon";
GRANT ALL ON TABLE "public"."platform_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."platform_settings" TO "service_role";



GRANT ALL ON TABLE "public"."post_comments" TO "anon";
GRANT ALL ON TABLE "public"."post_comments" TO "authenticated";
GRANT ALL ON TABLE "public"."post_comments" TO "service_role";



GRANT ALL ON TABLE "public"."post_likes" TO "anon";
GRANT ALL ON TABLE "public"."post_likes" TO "authenticated";
GRANT ALL ON TABLE "public"."post_likes" TO "service_role";



GRANT ALL ON TABLE "public"."posts" TO "anon";
GRANT ALL ON TABLE "public"."posts" TO "authenticated";
GRANT ALL ON TABLE "public"."posts" TO "service_role";



GRANT ALL ON TABLE "public"."prescription_fulfillment" TO "anon";
GRANT ALL ON TABLE "public"."prescription_fulfillment" TO "authenticated";
GRANT ALL ON TABLE "public"."prescription_fulfillment" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."provider_availability" TO "anon";
GRANT ALL ON TABLE "public"."provider_availability" TO "authenticated";
GRANT ALL ON TABLE "public"."provider_availability" TO "service_role";



GRANT ALL ON TABLE "public"."provider_time_off" TO "anon";
GRANT ALL ON TABLE "public"."provider_time_off" TO "authenticated";
GRANT ALL ON TABLE "public"."provider_time_off" TO "service_role";



GRANT ALL ON TABLE "public"."push_subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."push_subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."push_subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."reviews" TO "anon";
GRANT ALL ON TABLE "public"."reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."reviews" TO "service_role";



GRANT ALL ON TABLE "public"."sales" TO "anon";
GRANT ALL ON TABLE "public"."sales" TO "authenticated";
GRANT ALL ON TABLE "public"."sales" TO "service_role";



GRANT ALL ON TABLE "public"."seller_profiles" TO "anon";
GRANT ALL ON TABLE "public"."seller_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."seller_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."sellers_backup" TO "anon";
GRANT ALL ON TABLE "public"."sellers_backup" TO "authenticated";
GRANT ALL ON TABLE "public"."sellers_backup" TO "service_role";



GRANT ALL ON TABLE "public"."sellers_tmp_test" TO "anon";
GRANT ALL ON TABLE "public"."sellers_tmp_test" TO "authenticated";
GRANT ALL ON TABLE "public"."sellers_tmp_test" TO "service_role";



GRANT ALL ON TABLE "public"."services" TO "anon";
GRANT ALL ON TABLE "public"."services" TO "authenticated";
GRANT ALL ON TABLE "public"."services" TO "service_role";



GRANT ALL ON TABLE "public"."shipping_addresses" TO "anon";
GRANT ALL ON TABLE "public"."shipping_addresses" TO "authenticated";
GRANT ALL ON TABLE "public"."shipping_addresses" TO "service_role";



GRANT ALL ON TABLE "public"."shop_products" TO "anon";
GRANT ALL ON TABLE "public"."shop_products" TO "authenticated";
GRANT ALL ON TABLE "public"."shop_products" TO "service_role";



GRANT ALL ON TABLE "public"."shop_templates" TO "anon";
GRANT ALL ON TABLE "public"."shop_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."shop_templates" TO "service_role";



GRANT ALL ON TABLE "public"."shops" TO "anon";
GRANT ALL ON TABLE "public"."shops" TO "authenticated";
GRANT ALL ON TABLE "public"."shops" TO "service_role";



GRANT ALL ON TABLE "public"."site_catalog" TO "anon";
GRANT ALL ON TABLE "public"."site_catalog" TO "authenticated";
GRANT ALL ON TABLE "public"."site_catalog" TO "service_role";



GRANT ALL ON TABLE "public"."store_configs" TO "anon";
GRANT ALL ON TABLE "public"."store_configs" TO "authenticated";
GRANT ALL ON TABLE "public"."store_configs" TO "service_role";



GRANT ALL ON TABLE "public"."store_customizations" TO "anon";
GRANT ALL ON TABLE "public"."store_customizations" TO "authenticated";
GRANT ALL ON TABLE "public"."store_customizations" TO "service_role";



GRANT ALL ON TABLE "public"."store_products" TO "anon";
GRANT ALL ON TABLE "public"."store_products" TO "authenticated";
GRANT ALL ON TABLE "public"."store_products" TO "service_role";



GRANT ALL ON TABLE "public"."subcategories" TO "anon";
GRANT ALL ON TABLE "public"."subcategories" TO "authenticated";
GRANT ALL ON TABLE "public"."subcategories" TO "service_role";



GRANT ALL ON TABLE "public"."svc_categories" TO "anon";
GRANT ALL ON TABLE "public"."svc_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."svc_categories" TO "service_role";



GRANT ALL ON TABLE "public"."svc_listing_packages" TO "anon";
GRANT ALL ON TABLE "public"."svc_listing_packages" TO "authenticated";
GRANT ALL ON TABLE "public"."svc_listing_packages" TO "service_role";



GRANT ALL ON TABLE "public"."svc_listings" TO "anon";
GRANT ALL ON TABLE "public"."svc_listings" TO "authenticated";
GRANT ALL ON TABLE "public"."svc_listings" TO "service_role";



GRANT ALL ON TABLE "public"."svc_messages" TO "anon";
GRANT ALL ON TABLE "public"."svc_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."svc_messages" TO "service_role";



GRANT ALL ON TABLE "public"."svc_orders" TO "anon";
GRANT ALL ON TABLE "public"."svc_orders" TO "authenticated";
GRANT ALL ON TABLE "public"."svc_orders" TO "service_role";



GRANT ALL ON TABLE "public"."svc_portfolio" TO "anon";
GRANT ALL ON TABLE "public"."svc_portfolio" TO "authenticated";
GRANT ALL ON TABLE "public"."svc_portfolio" TO "service_role";



GRANT ALL ON TABLE "public"."svc_providers" TO "anon";
GRANT ALL ON TABLE "public"."svc_providers" TO "authenticated";
GRANT ALL ON TABLE "public"."svc_providers" TO "service_role";



GRANT ALL ON TABLE "public"."svc_reviews" TO "anon";
GRANT ALL ON TABLE "public"."svc_reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."svc_reviews" TO "service_role";



GRANT ALL ON TABLE "public"."svc_subcategories" TO "anon";
GRANT ALL ON TABLE "public"."svc_subcategories" TO "authenticated";
GRANT ALL ON TABLE "public"."svc_subcategories" TO "service_role";



GRANT ALL ON TABLE "public"."template_requests" TO "anon";
GRANT ALL ON TABLE "public"."template_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."template_requests" TO "service_role";



GRANT ALL ON TABLE "public"."templates" TO "anon";
GRANT ALL ON TABLE "public"."templates" TO "authenticated";
GRANT ALL ON TABLE "public"."templates" TO "service_role";



GRANT ALL ON TABLE "public"."trading_conversations" TO "anon";
GRANT ALL ON TABLE "public"."trading_conversations" TO "authenticated";
GRANT ALL ON TABLE "public"."trading_conversations" TO "service_role";



GRANT ALL ON TABLE "public"."user_events" TO "anon";
GRANT ALL ON TABLE "public"."user_events" TO "authenticated";
GRANT ALL ON TABLE "public"."user_events" TO "service_role";



GRANT ALL ON TABLE "public"."user_oauth_providers" TO "anon";
GRANT ALL ON TABLE "public"."user_oauth_providers" TO "authenticated";
GRANT ALL ON TABLE "public"."user_oauth_providers" TO "service_role";



GRANT ALL ON TABLE "public"."user_roles" TO "anon";
GRANT ALL ON TABLE "public"."user_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_roles" TO "service_role";



GRANT ALL ON TABLE "public"."user_template_selections" TO "anon";
GRANT ALL ON TABLE "public"."user_template_selections" TO "authenticated";
GRANT ALL ON TABLE "public"."user_template_selections" TO "service_role";



GRANT ALL ON TABLE "public"."user_wallets" TO "anon";
GRANT ALL ON TABLE "public"."user_wallets" TO "authenticated";
GRANT ALL ON TABLE "public"."user_wallets" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



GRANT ALL ON TABLE "public"."wallet_transactions" TO "anon";
GRANT ALL ON TABLE "public"."wallet_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."wallet_transactions" TO "service_role";



GRANT ALL ON TABLE "public"."website_integrations" TO "anon";
GRANT ALL ON TABLE "public"."website_integrations" TO "authenticated";
GRANT ALL ON TABLE "public"."website_integrations" TO "service_role";



GRANT ALL ON TABLE "public"."website_marketplace" TO "anon";
GRANT ALL ON TABLE "public"."website_marketplace" TO "authenticated";
GRANT ALL ON TABLE "public"."website_marketplace" TO "service_role";



GRANT ALL ON TABLE "public"."website_pages" TO "anon";
GRANT ALL ON TABLE "public"."website_pages" TO "authenticated";
GRANT ALL ON TABLE "public"."website_pages" TO "service_role";



GRANT ALL ON TABLE "public"."website_settings" TO "anon";
GRANT ALL ON TABLE "public"."website_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."website_settings" TO "service_role";



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































