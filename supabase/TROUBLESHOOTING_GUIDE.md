# 🔧 Troubleshooting Guide - Aurora E-Commerce

## Common Errors and Solutions

This guide helps you diagnose and fix common issues with the Aurora Flutter + Supabase integration.

---

## 🔴 Critical Errors

### 1. FunctionException (Status 404 - NOT FOUND)

**Error Message:**
```
FunctionException(status: 404, details: {code: NOT_FOUND, message: Requested function was not found})
```

**Cause:** Edge Function is not deployed or URL is incorrect.

**Solutions:**

1. **Verify function is deployed:**
   ```powershell
   supabase functions list
   ```

2. **Deploy the function:**
   ```powershell
   supabase functions deploy create-product --no-verify-jwt
   supabase functions deploy update-product --no-verify-jwt
   supabase functions deploy delete-product --no-verify-jwt
   supabase functions deploy search-products --no-verify-jwt
   ```

3. **Check function URL:**
   - Correct format: `https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/create-product`
   - Verify project ref in URL matches your project

4. **Check authentication:**
   ```powershell
   supabase auth status
   ```

---

### 2. StorageException (Bucket Not Found)

**Error Message:**
```
StorageException(message: Bucket not found, statusCode: 404)
```

**Cause:** The `product-images` storage bucket doesn't exist.

**Solutions:**

1. **Create bucket via SQL:**
   ```sql
   INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
   VALUES (
     'product-images', 
     'product-images', 
     true, 
     10485760,
     ARRAY['image/jpeg', 'image/png', 'image/webp']
   );
   ```

2. **Create bucket via Dashboard:**
   - Go to [Storage Dashboard](https://app.supabase.com/project/ofovfxsfazlwvcakpuer/storage)
   - Click "New Bucket"
   - Name: `product-images`
   - Public: ✓ Yes
   - File size limit: `10485760` (10MB)

3. **Verify bucket exists:**
   ```sql
   SELECT * FROM storage.buckets WHERE id = 'product-images';
   ```

---

### 3. Unauthorized Errors

**Error Message:**
```
Unauthorized: Invalid or missing authentication token
```

**Cause:** User is not logged in or token is expired.

**Solutions:**

1. **Check user authentication in Flutter:**
   ```dart
   final supabaseProvider = context.read<SupabaseProvider>();
   if (!supabaseProvider.isLoggedIn) {
     // Navigate to login
   }
   ```

2. **Verify Anon Key is correct:**
   ```dart
   await Supabase.initialize(
     url: 'https://ofovfxsfazlwvcakpuer.supabase.co',
     anonKey: 'eyJhbGc...YOUR_ANON_KEY',
   );
   ```

3. **Refresh session:**
   ```dart
   await supabaseProvider.client.auth.refreshSession();
   ```

---

### 4. RLS Policy Violation

**Error Message:**
```
new row violates row-level security policy for table "products"
```

**Cause:** Row Level Security is blocking the operation.

**Solutions:**

1. **Check current RLS policies:**
   ```sql
   SELECT policyname, cmd, qual 
   FROM pg_policies 
   WHERE tablename = 'products';
   ```

2. **Verify user is authenticated:**
   ```sql
   SELECT auth.uid(); -- Should return user ID
   ```

3. **Check seller_id matches authenticated user:**
   ```sql
   -- In Edge Function, verify:
   if (user.id !== sellerId) {
     throw new Error('Unauthorized');
   }
   ```

4. **Temporarily disable RLS for testing (NOT FOR PRODUCTION):**
   ```sql
   ALTER TABLE products DISABLE ROW LEVEL SECURITY;
   ```

5. **Re-create RLS policies:**
   Run the SQL from `complete_setup.sql`

---

### 5. Invalid ASIN / ASIN Not Generated

**Error Message:**
```
Invalid ASIN or ASIN is null
```

**Cause:** ASIN is not being captured from Edge Function response.

**Solutions:**

1. **Verify Edge Function returns ASIN:**
   Check `create-product/index.ts`:
   ```typescript
   return new Response(
     JSON.stringify({
       success: true,
       asin: product.asin,  // ✅ Ensure this exists
       product: product,
     })
   );
   ```

2. **Capture ASIN in Flutter:**
   Check `product_form_screen.dart`:
   ```dart
   if (result.success && widget.product == null) {
     final generatedAsin = result.data?['asin'] as String?;
     final productAsin = result.data?['product']?['asin'] as String?;
     final finalAsin = generatedAsin ?? productAsin;
     
     if (finalAsin != null) {
       // Use the ASIN
     }
   }
   ```

3. **Verify ASIN format in database:**
   ```sql
   SELECT asin FROM products WHERE asin LIKE 'ASN-%';
   ```

---

## 🟡 Common Issues

### 6. Images Not Uploading

**Symptoms:** Product saves but images don't appear.

**Solutions:**

1. **Check bucket permissions:**
   ```sql
   SELECT * FROM storage.policies WHERE bucket_id = 'product-images';
   ```

2. **Verify image upload path:**
   ```dart
   // Path format: seller_id/product_id/filename
   final filePath = '$sellerId/$productId/$fileName';
   ```

3. **Check file size:**
   - Max file size: 10MB
   - Supported formats: JPEG, PNG, WEBP

4. **Debug upload:**
   ```dart
   try {
     final urls = await storage.uploadMultipleImages(...);
     debugPrint('Uploaded: $urls');
   } catch (e) {
     debugPrint('Upload error: $e');
   }
   ```

---

### 7. Products Not Loading

**Symptoms:** Product list is empty or shows error.

**Solutions:**

1. **Check Edge Function logs:**
   ```powershell
   supabase functions logs search-products
   ```

2. **Verify products exist in database:**
   ```sql
   SELECT count(*) FROM products WHERE seller_id = 'YOUR_USER_ID';
   ```

3. **Check RLS allows read access:**
   ```sql
   -- Policy should allow:
   -- auth.uid() = seller_id OR (is_deleted = false AND status = 'active')
   ```

4. **Test Edge Function directly:**
   ```bash
   curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/search-products' \
     -H 'Authorization: Bearer YOUR_ANON_KEY' \
     -H 'Content-Type: application/json' \
     -d '{"sellerId": "YOUR_USER_ID", "limit": 10, "offset": 0}'
   ```

---

### 8. Product Update Fails

**Symptoms:** Product update returns error or doesn't save.

**Solutions:**

1. **Verify ownership:**
   ```typescript
   // In update-product Edge Function
   if (existingProduct.seller_id !== sellerId) {
     throw new Error('Unauthorized: You can only update your own products');
   }
   ```

2. **Check ASIN exists:**
   ```sql
   SELECT * FROM products WHERE asin = 'YOUR_ASIN';
   ```

3. **Verify update payload:**
   ```dart
   // Allowed fields in Edge Function:
   const allowedFields = [
     'title', 'description', 'brand', 'price', 'quantity',
     'status', 'category', 'subcategory', 'attributes',
     'brand_id', 'is_local_brand', 'images', 'color_hex',
   ];
   ```

---

### 9. Product Delete Doesn't Remove Images

**Symptoms:** Product deleted but images remain in storage.

**Solutions:**

1. **Check delete-product Edge Function:**
   ```typescript
   // Should delete images before product
   if (product.images && Array.isArray(product.images)) {
     for (const img of product.images) {
       if (img.url) {
         const imagePath = img.url.split('/product-images/')[1];
         await supabaseClient.storage
           .from('product-images')
           .remove([imagePath]);
       }
     }
   }
   ```

2. **Manually clean orphaned images:**
   ```sql
   -- List all objects in bucket
   SELECT * FROM storage.objects WHERE bucket_id = 'product-images';
   
   -- Delete specific object
   DELETE FROM storage.objects 
   WHERE bucket_id = 'product-images' 
     AND name = 'seller_id/product_id/image.jpg';
   ```

---

### 10. Cache Issues (Stale Data)

**Symptoms:** App shows old data after updates.

**Solutions:**

1. **Clear Flutter cache:**
   ```dart
   await _cache.remove(_getUserCacheKey(SupabaseConfig.cacheProducts));
   ```

2. **Force refresh:**
   ```dart
   await _loadProducts(); // Ignores cache
   ```

3. **Clear app data (development):**
   ```powershell
   flutter clean
   flutter pub get
   flutter run
   ```

---

## 🟢 Debugging Tools

### Enable Debug Logging

**Flutter:**
```dart
// In main.dart
import 'package:flutter/foundation.dart';

void main() {
  if (kDebugMode) {
    debugPrint('Debug mode enabled');
  }
  runApp(MyApp());
}
```

**Edge Functions:**
```typescript
// Add console.log statements
console.log('Request body:', await req.json());
console.log('User:', user);
console.log('Response:', data);
```

**View Edge Function logs:**
```powershell
supabase functions logs <function-name>
```

---

### Database Debug Queries

```sql
-- Check if user is authenticated
SELECT auth.uid() AS current_user_id;

-- Check products for current user
SELECT * FROM products WHERE seller_id = auth.uid();

-- Check storage objects
SELECT * FROM storage.objects WHERE bucket_id = 'product-images';

-- Check RLS policies
SELECT * FROM pg_policies WHERE tablename = 'products';

-- Get function invocation logs
SELECT * FROM logs 
WHERE function_name = 'create-product' 
ORDER BY timestamp DESC 
LIMIT 10;
```

---

### Network Debugging

**Inspect HTTP requests:**
```dart
// Add logging to supabase.dart
final response = await _client.functions.invoke(
  SupabaseConfig.functionCreateProduct,
  body: {...},
);
debugPrint('Response status: ${response.status}');
debugPrint('Response data: ${response.data}');
```

**Test with curl:**
```bash
# Test create-product
curl -v -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/create-product' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"title":"Test","brand":"Test","category":"Test","subcategory":"Test","sellerId":"YOUR_USER_ID"}'
```

---

## 📊 Health Check Commands

```powershell
# Check Supabase CLI
supabase --version

# Check authentication
supabase auth status

# Check project link
supabase status

# List functions
supabase functions list

# Check function logs
supabase functions logs create-product --tail

# Check database
supabase db pull

# Check storage
# Use Dashboard: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/storage
```

---

## 🆘 Emergency Reset

If everything is broken:

1. **Reset database:**
   ```sql
   -- Drop all tables (CAREFUL - irreversible!)
   DROP TABLE IF EXISTS products CASCADE;
   DROP TABLE IF EXISTS sellers CASCADE;
   DROP TABLE IF EXISTS categories CASCADE;
   DROP TABLE IF EXISTS subcategories CASCADE;
   DROP TABLE IF EXISTS brands CASCADE;
   
   -- Re-run complete_setup.sql
   ```

2. **Redeploy functions:**
   ```powershell
   supabase functions delete create-product
   supabase functions delete update-product
   supabase functions delete delete-product
   supabase functions delete search-products
   
   supabase functions deploy create-product --no-verify-jwt
   supabase functions deploy update-product --no-verify-jwt
   supabase functions deploy delete-product --no-verify-jwt
   supabase functions deploy search-products --no-verify-jwt
   ```

3. **Clear Flutter cache:**
   ```powershell
   flutter clean
   flutter pub get
   flutter run
   ```

---

## 📞 Getting Help

1. **Check logs first** - 90% of issues are visible in logs
2. **Review documentation** - [Supabase Docs](https://supabase.com/docs)
3. **Test with curl** - Isolate Flutter from backend issues
4. **Check RLS policies** - Most common cause of data access issues
5. **Verify environment variables** - Wrong keys cause auth failures

---

**Last Updated:** March 2, 2026  
**Project:** ofovfxsfazlwvcakpuer
