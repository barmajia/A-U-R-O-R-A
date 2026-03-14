-- ============================================
-- AURORA E-COMMERCE: PRODUCT IMAGES STORAGE
-- ============================================
-- Storage bucket and policies for product images
-- Migration 007
-- ============================================

-- ============================================
-- CREATE STORAGE BUCKET FOR PRODUCT IMAGES
-- ============================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  true,
  5242880, -- 5MB limit per image
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- STORAGE POLICIES FOR PRODUCT IMAGES
-- ============================================

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view own product images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own product images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own product images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view product images" ON storage.objects;

-- Allow authenticated users to upload images
CREATE POLICY "Users can upload product images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'product-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to view their own images
CREATE POLICY "Users can view own product images"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'product-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to update their own images
CREATE POLICY "Users can update own product images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'product-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to delete their own images
CREATE POLICY "Users can delete own product images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'product-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow public to view product images (for product listing)
CREATE POLICY "Public can view product images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'product-images');

-- ============================================
-- STORAGE FUNCTIONS
-- ============================================

-- Function to get public URL for an image
CREATE OR REPLACE FUNCTION get_product_image_url(image_path text)
RETURNS text AS $$
BEGIN
  RETURN storage.storage_url('product-images', image_path);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to delete old images when product is updated/deleted
CREATE OR REPLACE FUNCTION cleanup_product_images()
RETURNS trigger AS $$
DECLARE
  old_image text;
  old_image_path text;
BEGIN
  -- Delete old images that are no longer in the array
  IF TG_OP = 'UPDATE' AND OLD.images IS DISTINCT FROM NEW.images THEN
    -- Parse old images JSONB array and delete each one
    FOR old_image IN SELECT jsonb_array_elements_text(OLD.images)
    LOOP
      -- Check if the image is still in the new array
      IF NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements_text(NEW.images) AS new_img
        WHERE new_img = old_image
      ) THEN
        -- Extract path from URL for deletion
        old_image_path := replace(old_image, 'https://' || current_setting('app.settings.project_ref') || '.supabase.co/storage/v1/object/public/product-images/', '');
        
        -- Delete the file from storage
        BEGIN
          PERFORM storage.delete('product-images', old_image_path);
        EXCEPTION WHEN OTHERS THEN
          -- Ignore errors (file may not exist)
          NULL;
        END;
      END IF;
    END LOOP;
  END IF;
  
  -- Delete all images when product is deleted
  IF TG_OP = 'DELETE' THEN
    FOR old_image IN SELECT jsonb_array_elements_text(OLD.images)
    LOOP
      old_image_path := replace(old_image, 'https://' || current_setting('app.settings.project_ref') || '.supabase.co/storage/v1/object/public/product-images/', '');
      BEGIN
        PERFORM storage.delete('product-images', old_image_path);
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to cleanup images on update/delete
DROP TRIGGER IF EXISTS trigger_cleanup_product_images ON public.products;
CREATE TRIGGER trigger_cleanup_product_images
BEFORE UPDATE OR DELETE ON public.products
FOR EACH ROW
EXECUTE FUNCTION cleanup_product_images();

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

GRANT USAGE ON SCHEMA storage TO anon, authenticated;
GRANT ALL ON storage.objects TO authenticated;
GRANT SELECT ON storage.objects TO anon;

-- ============================================
-- MIGRATION COMPLETE
-- ============================================
