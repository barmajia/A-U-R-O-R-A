# 🔧 TROUBLESHOOTING GUIDE - Aurora E-Commerce

**Common Issues & Solutions for Supabase Integration**

---

## 🔴 CRITICAL ERRORS

### 1. FunctionException (status: 404)

```
FunctionException(status: 404, details: {code: NOT_FOUND, 
message: Requested function was not found})
```

**Cause:** Edge Function not deployed to Supabase cloud

**Solution:**

```powershell
# Step 1: Verify functions are deployed
supabase functions list

# Step 2: Deploy missing functions
cd c:\Users\yn098\aurora\A-U-R-O-R-A
supabase functions deploy create-product --no-verify-jwt
supabase functions deploy update-product --no-verify-jwt
supabase functions deploy delete-product --no-verify-jwt
supabase functions deploy search-products --no-verify-jwt

# Step 3: Verify service role key is set
supabase secrets get SUPABASE_SERVICE_ROLE_KEY

# If not set, add it:
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-key-here
```

**Verify Fix:**
- Restart Flutter app
- Try creating a product
- Check logs: should see "Product created! ASIN: ASN-xxxxx"

---

### 2. StorageException (Bucket not found)

```
StorageException(message: Bucket not found, statusCode: 404)
```

**Cause:** `product-images` storage bucket doesn't exist

**Solution:**

**Option A: Run SQL Script (Recommended)**

1. Go to: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/sql/new
2. Run this SQL:

```sql
-- Create product-images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;
```

**Option B: Create via Dashboard**

1. Go to: Storage → Create bucket
2. Name: `product-images`
3. Check: "Public bucket"
4. File size limit: `10485760` (10MB)
5. Allowed MIME types: `image/jpeg, image/png, image/webp`
6. Click **Create bucket**

**Verify Fix:**
- Go to Storage → `product-images` should appear
- Try uploading an image in Flutter app

---

### 3. Unauthorized Errors

```
Unauthorized: sellerId does not match authenticated user
```

**Cause:** User authentication issue or mismatched sellerId

**Solution:**

**Check 1: Verify User is Logged In**

```dart
// In Flutter app
final supabaseProvider = context.read<SupabaseProvider>();
print('Logged in: ${supabaseProvider.isLoggedIn}');
print('User ID: ${supabaseProvider.currentUser?.id}');
```

**Check 2: Verify Seller Record Exists**

```sql
-- Run in Supabase SQL Editor
SELECT * FROM sellers WHERE user_id = 'YOUR_USER_ID_HERE';
```

If no result, create seller record:

```sql
INSERT INTO sellers (
  user_id, email, full_name, phone, location, currency, is_verified
) VALUES (
  'YOUR_USER_ID',
  'your@email.com',
  'Your Name',
  '+1234567890',
  'Your Location',
  'USD',
  false
);
```

**Check 3: Re-login**

```dart
// Logout
await supabaseProvider.logout();

// Login again
await supabaseProvider.login(
  email: 'your@email.com',
  password: 'your-password',
);
```

---

### 4. Invalid ASIN / ASIN Not Generated

```
Product created but ASIN is null
```

**Cause:** Flutter app not capturing ASIN from Edge Function response

**Solution:**

**Verify ProductFormScreen captures ASIN:**

Check `lib/pages/product/product_form_screen.dart` lines 580-600:

```dart
// ✅ Should have this code
if (result.success && widget.product == null) {
  final generatedAsin = result.data?['asin'] as String?;
  final productData = result.data?['product'] as Map<String, dynamic>?;
  final productAsin = productData?['asin'] as String?;
  
  final finalAsin = generatedAsin ?? productAsin;
  
  if (finalAsin != null && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Product created! ASIN: $finalAsin'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
```

**Verify Edge Function returns ASIN:**

Check `supabase/functions/create-product/index.ts`:

```typescript
// Should return:
return new Response(
  JSON.stringify({
    success: true,
    message: 'Product created successfully',
    product: data,
    asin: data.asin  // ✅ ASIN must be here
  }),
  ...
);
```

---

## 🟡 COMMON ISSUES

### 5. Images Not Uploading

**Symptoms:**
- Product creates but images don't appear
- Error: "Storage error uploading images"

**Solution:**

**Check 1: Bucket RLS Policies**

```sql
-- Verify RLS policies exist
SELECT * FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage';

-- Should have these policies:
-- - Anyone can view product images
-- - Sellers can upload product images
-- - Sellers can delete their own images
-- - Sellers can update their own images
```

**Check 2: Image Path Format**

Images must follow path format: `{seller_id}/{product_id}/{filename}`

In `lib/services/supabase_storage.dart`:

```dart
final filePath = '$sellerId/${productId ?? 'temp'}/$fileName';
// ✅ Correct: "abc123/prod-456/image.jpg"
// ❌ Wrong: "products/prod-456/image.jpg"
```

**Check 3: File Size & Type**

```dart
// Allowed in complete_setup.sql:
allowed_mime_types: ['image/jpeg', 'image/png', 'image/webp']
file_size_limit: 10485760 // 10MB
```

If uploading WEBP images, ensure browser/device supports it.

---

### 6. Products Not Appearing in List

**Symptoms:**
- Product created successfully
- Doesn't show in Products page

**Solution:**

**Check 1: Status Filter**

Products page may filter by status. Check `_loadProducts()`:

```dart
// In lib/pages/product/product.dart
// Verify it fetches all statuses
final result = await supabaseProvider.searchProductsWithEdgeFunction(
  query: '',
  status: null, // null = all statuses
  limit: 100,
  offset: 0,
);
```

**Check 2: RLS Policy**

```sql
-- Verify RLS allows seller to view their products
SELECT * FROM pg_policies 
WHERE tablename = 'products' 
AND policyname LIKE '%view%';

-- Should have:
-- "Sellers can view their own products"
```

**Check 3: Seller ID Mismatch**

```sql
-- Check product's seller_id matches your user_id
SELECT asin, seller_id, title FROM products 
WHERE asin = 'YOUR_ASN_HERE';

-- seller_id should match your auth.uid()
```

---

### 7. Search Not Working

**Symptoms:**
- Search returns empty results
- Filters don't work

**Solution:**

**Check 1: Full-Text Search Index**

```sql
-- Verify index exists
SELECT * FROM pg_indexes 
WHERE tablename = 'products' 
AND indexname LIKE '%tsvector%';

-- If missing, create it:
CREATE INDEX IF NOT EXISTS idx_products_title_description_tsvector
  ON products USING gin (
    to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(description, ''))
  );
```

**Check 2: Edge Function Filters**

Check `supabase/functions/search-products/index.ts`:

```typescript
// Verify filters are applied correctly
if (category) {
  dbQuery = dbQuery.eq('category', category);
}
if (status) {
  dbQuery = dbQuery.eq('status', status);
}
```

---

### 8. Keyboard Flickering on Save

**Symptoms:**
- Keyboard closes and reopens when saving
- UI flickers

**Solution:**

Already fixed in `product_form_screen.dart`:

```dart
// ✅ Should have FocusNode
final _focusNode = FocusNode();

// ✅ Should unfocus before save
Future<void> _saveProduct() async {
  _focusNode.unfocus(); // Close keyboard first
  // ... rest of save logic
}
```

If still flickering, add `AutofillGroup` wrapper:

```dart
@override
Widget build(BuildContext context) {
  return AutofillGroup(
    child: Form(
      key: _formKey,
      child: ListView(...),
    ),
  );
}
```

---

## 🟢 PERFORMANCE ISSUES

### 9. Slow Product Creation (>5 seconds)

**Causes & Solutions:**

**Cause 1: Large Images**

```dart
// Compress images before upload
// In product_form_screen.dart, resize images when picking:
final XFile? photo = await _picker.pickImage(
  source: ImageSource.camera,
  maxWidth: 1920,  // ✅ Limit resolution
  maxHeight: 1080,
  imageQuality: 85, // ✅ Compress
);
```

**Cause 2: Network Latency**

Check Edge Function logs:

```bash
supabase functions logs create-product --tail
```

Look for slow database operations.

**Cause 3: Missing Indexes**

```sql
-- Add performance indexes
CREATE INDEX IF NOT EXISTS idx_products_seller_id ON products(seller_id);
CREATE INDEX IF NOT EXISTS idx_products_created_at ON products(created_at DESC);
```

---

### 10. Delete Takes Too Long

**Cause:** Deleting many images

**Solution:**

Check `delete-product` function logs:

```bash
supabase functions logs delete-product
```

If image deletion is slow, optimize by:

1. Limiting images per product (e.g., max 10)
2. Using CDN for images
3. Async deletion (delete product first, images later)

---

## 🔵 DEBUGGING TOOLS

### Enable Verbose Logging

**Flutter:**

```dart
// In lib/services/supabase.dart
// Add debug prints:
if (kDebugMode) {
  print('🔵 [DEBUG] Creating product: $title');
  print('🔵 [DEBUG] Seller ID: $sellerId');
  print('🔵 [DEBUG] Response: $response');
}
```

**Edge Functions:**

```typescript
// In supabase/functions/*/index.ts
console.log('🔵 [DEBUG] Request body:', await req.json());
console.log('🔵 [DEBUG] User:', user);
```

### Test Edge Functions Locally

```bash
# Start local Supabase
supabase start

# Serve function locally
supabase functions serve create-product

# Test with curl
curl -X POST 'http://localhost:54321/functions/v1/create-product' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"title": "Test", ...}'
```

---

## 📊 ERROR CODE REFERENCE

| Error Code | Meaning | Solution |
|------------|---------|----------|
| `404` | Not Found | Deploy Edge Function |
| `401` | Unauthorized | Check auth token |
| `403` | Forbidden | Check RLS policies |
| `400` | Bad Request | Validate input data |
| `500` | Server Error | Check Edge Function logs |
| `PGRST116` | RLS violation | Fix RLS policy |
| `42P01` | Table not found | Run SQL setup |

---

## 🧪 QUICK TEST COMMANDS

### Test All Edge Functions

```powershell
# Save as test_functions.ps1

$projectRef = "ofovfxsfazlwvcakpuer"
$baseUrl = "https://$projectRef.supabase.co/functions/v1"
$anonKey = "YOUR_ANON_KEY"
$userId = "YOUR_USER_ID"

$headers = @{
  "Authorization" = "Bearer $anonKey"
  "Content-Type" = "application/json"
}

# Test create-product
Write-Host "Testing create-product..." -ForegroundColor Cyan
$createBody = @{
  title = "Test Product"
  brand = "Test Brand"
  category = "Electronics"
  subcategory = "Smartphones"
  price = 999
  quantity = 10
  sellerId = $userId
} | ConvertTo-Json

Invoke-RestMethod -Uri "$baseUrl/create-product" -Method Post -Headers $headers -Body $createBody

# Test search-products
Write-Host "`nTesting search-products..." -ForegroundColor Cyan
$searchBody = @{
  query = ""
  sellerId = $userId
  limit = 100
} | ConvertTo-Json

Invoke-RestMethod -Uri "$baseUrl/search-products" -Method Post -Headers $headers -Body $searchBody
```

---

## 📞 GETTING HELP

### Supabase Dashboard Tools

1. **Logs Explorer**: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/logs/explorer
2. **SQL Editor**: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/sql/new
3. **Table Editor**: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/editor
4. **Storage**: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/storage

### Useful Queries

```sql
-- Check recent products
SELECT asin, title, seller_id, created_at 
FROM products 
ORDER BY created_at DESC 
LIMIT 10;

-- Check storage usage
SELECT bucket_id, COUNT(*) as file_count, SUM(metadata->>'size') as total_size
FROM storage.objects
GROUP BY bucket_id;

-- Check RLS policies
SELECT tablename, policyname, cmd, roles, qual
FROM pg_policies
WHERE schemaname = 'public' OR schemaname = 'storage';
```

---

**Last Updated:** March 2, 2026  
**Version:** 1.0  
**Maintained By:** Aurora Development Team
