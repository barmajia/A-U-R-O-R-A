# QR Data Column Fix - Deployment Guide

## Issues Fixed

### 1. Missing `qr_data` Column
**Error:** `PostgrestException(message: Could not find the 'qr_data' column of 'products' in the schema cache, code: PGRST204`

**Solution:** Added migration to add the `qr_data` column to the `products` table.

### 2. JWT Authentication for Edge Functions
**Error:** `FunctionException(status: 401, details: {code: 401, message: Invalid JWT}, reasonPhrase: Unauthorized)`

**Solution:** Added authentication headers to all edge function calls.

---

## Deployment Steps

### Step 1: Run Database Migration

Execute the migration SQL file on your Supabase database:

```bash
# Using Supabase CLI
supabase db execute --file supabase/migrations/add_qr_data_column.sql

# OR manually in Supabase SQL Editor
# Copy and paste the contents of: supabase/migrations/add_qr_data_column.sql
```

**Migration SQL:**
```sql
-- Add qr_data column if it doesn't exist
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS qr_data TEXT;

-- Add comment for documentation
COMMENT ON COLUMN products.qr_data IS 'JSON-encoded QR code data containing ASIN, SKU, seller_id, URL, and product details';

-- Create index for faster lookups (optional)
CREATE INDEX IF NOT EXISTS idx_products_qr_data ON products(qr_data) WHERE qr_data IS NOT NULL;
```

### Step 2: Deploy Updated Flutter Code

The following files have been updated:

1. **lib/services/supabase.dart**
   - Added `_getAuthHeaders()` helper method
   - Updated `callManageProduct()` to include auth headers
   - Updated `callEdgeFunction()` to include auth headers
   - Fixed all edge function calls (9 total):
     - `functionCreateOrder`
     - `functionManageProduct`
     - `functionCreateProduct`
     - `functionUpdateProduct`
     - `functionDeleteProduct`
     - `functionSearchProducts`
     - `functionGetOrCreateConversation`
     - `functionProcessSignup`

2. **lib/widgets/product_qr_dialog.dart**
   - Updated `_generateSKU()` to handle missing cloud column gracefully
   - Added debug logging for troubleshooting

### Step 3: Verify the Fix

1. **Restart your Flutter app** (hot reload may not be enough)
   ```bash
   flutter run
   ```

2. **Test SKU generation:**
   - Create a new product
   - Open the QR code dialog
   - Click "Generate SKU"
   - Verify no 401 or PostgrestException errors

3. **Check logs for success messages:**
   ```
   ✅ SKU generated: [uuid]
   ✅ Product SKU updated: [uuid]
   ✅ PRODUCT CREATED SUCCESSFULLY
   ```

---

## Files Changed

- ✅ `lib/services/supabase.dart` - Added auth headers to all edge function calls
- ✅ `lib/widgets/product_qr_dialog.dart` - Improved error handling
- ✅ `supabase/migrations/add_qr_data_column.sql` - New migration file

---

## Troubleshooting

### If you still see 401 errors:

1. **Verify user is logged in:**
   ```dart
   print('Logged in: ${supabaseProvider.isLoggedIn}');
   print('User ID: ${supabaseProvider.currentUser?.id}');
   ```

2. **Check edge function permissions:**
   - Go to Supabase Dashboard → Edge Functions
   - Ensure `manage-product` function has proper RLS policies
   - Verify function accepts Bearer token authentication

### If you still see PostgrestException:

1. **Verify migration ran successfully:**
   ```sql
   -- Check if column exists
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name = 'products' AND column_name = 'qr_data';
   ```

2. **Restart PostgREST (if needed):**
   - In Supabase Dashboard: Settings → API → Restart PostgREST

3. **Clear schema cache:**
   ```bash
   # Using Supabase CLI
   supabase db reset --linked
   ```

---

## Additional Notes

- The migration is **safe to run multiple times** (uses `IF NOT EXISTS`)
- All edge function calls now include proper JWT authentication
- The fix is **backward compatible** with existing products
- Products without QR codes will continue to work as before

---

## Next Steps (Optional)

1. **Update Edge Function** to return QR data in response
2. **Implement cloud sync** for QR data once column is added
3. **Add QR code scanning** feature to product search
4. **Create admin dashboard** to view all product QR codes

---

**Created:** 2026-03-14  
**Status:** ✅ Ready for Deployment
