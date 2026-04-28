-- ============================================================================
-- FACTORY STORAGE BUCKETS MIGRATION
-- ============================================================================
-- This migration creates Supabase Storage buckets for factory-related files
-- Version: 1.0.0
-- Date: 2026-03-17
-- ============================================================================

-- Note: Storage buckets need to be created via Dashboard or Admin API
-- This SQL script documents the required bucket structure and RLS policies

-- ============================================================================
-- Step 1: Create Storage Buckets (via Dashboard or Admin)
-- ============================================================================

-- The following buckets should be created in Supabase Dashboard:
-- 1. factory-licenses: For factory license documents (PDF, images)
-- 2. factory-catalogs: For factory product catalogs (PDF)
-- 3. factory-profiles: For factory profile images (JPEG, PNG, WebP)

-- Example SQL for creating buckets (requires admin privileges):
-- INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
-- VALUES 
--   ('factory-licenses', 'factory-licenses', true, 10485760, ARRAY['application/pdf', 'image/jpeg', 'image/png']),
--   ('factory-catalogs', 'factory-catalogs', true, 10485760, ARRAY['application/pdf']),
--   ('factory-profiles', 'factory-profiles', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']);

-- ============================================================================
-- Step 2: Enable RLS on storage.objects
-- ============================================================================

-- RLS is typically already enabled on storage.objects by Supabase

-- ============================================================================
-- Step 3: Create RLS Policies for Factory Licenses Bucket
-- ============================================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Factory owners can upload licenses" ON storage.objects;
DROP POLICY IF EXISTS "Factory owners can view own licenses" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view factory licenses" ON storage.objects;
DROP POLICY IF EXISTS "Factory owners can delete own licenses" ON storage.objects;

-- Allow authenticated users to upload their own factory license
CREATE POLICY "Factory owners can upload licenses"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'factory-licenses' AND
  (storage.foldername(name))[1] = auth.uid()::text AND
  (storage.foldername(name))[2] = 'licenses'
);

-- Allow factory owners to view their own licenses
CREATE POLICY "Factory owners can view own licenses"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'factory-licenses' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow anyone to view factory licenses (for verification purposes)
CREATE POLICY "Anyone can view factory licenses"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'factory-licenses');

-- Allow factory owners to delete their own licenses
CREATE POLICY "Factory owners can delete own licenses"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'factory-licenses' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================================
-- Step 4: Create RLS Policies for Factory Catalogs Bucket
-- ============================================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Factory owners can upload catalogs" ON storage.objects;
DROP POLICY IF EXISTS "Factory owners can view own catalogs" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view factory catalogs" ON storage.objects;
DROP POLICY IF EXISTS "Factory owners can delete own catalogs" ON storage.objects;

-- Allow authenticated users to upload their own factory catalogs
CREATE POLICY "Factory owners can upload catalogs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'factory-catalogs' AND
  (storage.foldername(name))[1] = auth.uid()::text AND
  (storage.foldername(name))[2] = 'catalogs'
);

-- Allow factory owners to view their own catalogs
CREATE POLICY "Factory owners can view own catalogs"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'factory-catalogs' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow anyone to view factory catalogs (for discovery purposes)
CREATE POLICY "Anyone can view factory catalogs"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'factory-catalogs');

-- Allow factory owners to delete their own catalogs
CREATE POLICY "Factory owners can delete own catalogs"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'factory-catalogs' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================================
-- Step 5: Create RLS Policies for Factory Profiles Bucket
-- ============================================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Factory owners can upload profiles" ON storage.objects;
DROP POLICY IF EXISTS "Factory owners can view own profiles" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view factory profiles" ON storage.objects;
DROP POLICY IF EXISTS "Factory owners can delete own profiles" ON storage.objects;

-- Allow authenticated users to upload their own factory profile images
CREATE POLICY "Factory owners can upload profiles"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'factory-profiles' AND
  (storage.foldername(name))[1] = auth.uid()::text AND
  (storage.foldername(name))[2] = 'profiles'
);

-- Allow factory owners to view their own profiles
CREATE POLICY "Factory owners can view own profiles"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'factory-profiles' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow anyone to view factory profile images (for discovery purposes)
CREATE POLICY "Anyone can view factory profiles"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'factory-profiles');

-- Allow factory owners to delete their own profiles
CREATE POLICY "Factory owners can delete own profiles"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'factory-profiles' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================================
-- Step 6: Create Helper Function to Get Factory Storage Path
-- ============================================================================

CREATE OR REPLACE FUNCTION get_factory_storage_path(
  p_file_type TEXT,
  p_file_name TEXT
)
RETURNS TEXT AS $$
BEGIN
  -- Returns the full storage path for a factory file
  -- Usage: get_factory_storage_path('licenses', 'license.pdf')
  -- Returns: {factory_id}/licenses/license.pdf
  
  RETURN auth.uid()::text || '/' || p_file_type || '/' || p_file_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Step 7: Verification Queries
-- ============================================================================

-- Verify buckets exist (run in Supabase Dashboard SQL editor)
-- SELECT id, name, public, file_size_limit, allowed_mime_types
-- FROM storage.buckets
-- WHERE id IN ('factory-licenses', 'factory-catalogs', 'factory-profiles');

-- Verify policies are created
-- SELECT policyname, tablename, cmd
-- FROM pg_policies
-- WHERE schemaname = 'storage' 
--   AND tablename = 'objects'
--   AND policyname LIKE '%factory%';

-- ============================================================================
-- Step 8: Grant Permissions
-- ============================================================================

GRANT ALL ON storage.objects TO authenticated;
GRANT SELECT ON storage.objects TO anon;
GRANT EXECUTE ON FUNCTION get_factory_storage_path TO authenticated;

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
