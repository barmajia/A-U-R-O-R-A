# 🚀 COMPLETE DEPLOYMENT & TESTING GUIDE

**Project:** Aurora E-Commerce Seller App  
**Date:** March 2, 2026  
**Supabase Project:** `ofovfxsfazlwvcakpuer`

---

## 📋 PRE-DEPLOYMENT CHECKLIST

### Prerequisites

- [ ] **Supabase CLI installed**
  ```powershell
  # Check installation
  supabase --version
  
  # Install if needed
  winget install Supabase.CLI
  # OR
  npm install -g supabase
  ```

- [ ] **Flutter SDK 3.38.7+**
  ```powershell
  flutter --version
  ```

- [ ] **Supabase project access**
  - URL: https://app.supabase.com/project/ofovfxsfazlwvcakpuer
  - You have write access to the project

---

## 🔧 STEP 1: DATABASE SETUP (Supabase Dashboard)

### 1.1 Run SQL Script

1. Go to: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/sql/new
2. Copy entire content from: `supabase/complete_setup.sql`
3. Paste into SQL Editor
4. Click **Run** ▶️
5. Verify no errors

### 1.2 Verify Database Setup

Run these verification queries:

```sql
-- Check tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Expected: brands, categories, customers, order_items, orders, 
-- products, sellers, subcategories, users, wishlist

-- Check storage bucket
SELECT * FROM storage.buckets WHERE id = 'product-images';

-- Expected: 1 row with name='product-images', public=true

-- Check RLS policies for products
SELECT policyname FROM pg_policies 
WHERE tablename = 'products' AND schemaname = 'public';

-- Expected: 
-- - Sellers can view their own products
-- - Sellers can insert their own products
-- - Sellers can update their own products
-- - Sellers can delete their own products
-- - Anyone can view active products

-- Check RLS policies for storage
SELECT policyname FROM pg_policies 
WHERE tablename = 'objects' AND schemaname = 'storage';

-- Expected:
-- - Anyone can view product images
-- - Sellers can upload product images
-- - Sellers can delete their own images
-- - Sellers can update their own images
```

---

## 🔧 STEP 2: DEPLOY EDGE FUNCTIONS

### Option A: Use PowerShell Script (Recommended)

```powershell
# Navigate to project directory
cd c:\Users\yn098\aurora\A-U-R-O-R-A

# Run deployment script
.\deploy-functions.ps1
```

The script will:
1. Check Supabase CLI installation
2. Verify authentication
3. Check project linkage
4. Deploy all 4 functions
5. Prompt for service role key

### Option B: Manual Deployment

```bash
# Navigate to project root
cd c:\Users\yn098\aurora\A-U-R-O-R-A

# Login to Supabase
supabase login

# Link project (if not already linked)
supabase link --project-ref ofovfxsfazlwvcakpuer

# Deploy each function
supabase functions deploy create-product --no-verify-jwt
supabase functions deploy update-product --no-verify-jwt
supabase functions deploy delete-product --no-verify-jwt
supabase functions deploy search-products --no-verify-jwt

# Set service role key (REQUIRED)
# Get your key from: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/settings/api
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
```

### 2.1 Verify Function Deployment

```bash
# List all deployed functions
supabase functions list

# Expected output:
# create-product
# update-product
# delete-product
# search-products
# (plus any other functions you have)

# Check function logs
supabase functions logs create-product
supabase functions logs update-product
supabase functions logs delete-product
supabase functions logs search-products
```

---

## 🔧 STEP 3: UPDATE FLUTTER APP

### 3.1 Verify Code Changes

The following files have been updated:

| File | Changes |
|------|---------|
| `lib/services/supabase_storage.dart` | Added explicit bucket parameter |
| `lib/pages/product/product_form_screen.dart` | Enhanced error handling for image upload |
| `supabase/complete_setup.sql` | NEW: Complete database + storage setup |

### 3.2 Get Flutter Dependencies

```powershell
cd c:\Users\yn098\aurora\A-U-R-O-R-A
flutter pub get
```

### 3.3 Hot Restart Flutter App

```powershell
# If app is already running
flutter run

# Or hot restart (press 'r' in terminal)
# Or full restart (press 'R' in terminal)
```

---

## ✅ STEP 4: TESTING CHECKLIST

### 4.1 Test Edge Functions (Direct API Calls)

#### Test Create Product Function

```bash
# Get your anon key from: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/settings/api
$ANON_KEY="your-anon-key-here"
$USER_ID="your-user-id-here"

# Test create-product function
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/create-product' `
  -H "Authorization: Bearer $ANON_KEY" `
  -H 'Content-Type: application/json' `
  -d '{
    "title": "Test Product - DELETE AFTER TESTING",
    "brand": "Test Brand",
    "category": "Electronics",
    "subcategory": "Smartphones",
    "price": 999,
    "quantity": 10,
    "sellerId": "'$USER_ID'",
    "status": "draft",
    "currency": "USD"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Product created successfully",
  "product": {
    "asin": "ASN-1234567890-ABC123DEF",
    "title": "Test Product - DELETE AFTER TESTING",
    ...
  },
  "asin": "ASN-1234567890-ABC123DEF"
}
```

#### Test Search Products Function

```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/search-products' `
  -H "Authorization: Bearer $ANON_KEY" `
  -H 'Content-Type: application/json' `
  -d '{
    "query": "",
    "sellerId": "'$USER_ID'",
    "limit": 100,
    "offset": 0
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "products": [...],
  "count": 1,
  "limit": 100,
  "offset": 0
}
```

### 4.2 Test Flutter App (End-to-End)

#### Test 1: Create New Product

1. Open Flutter app
2. Navigate to **Products** → **Add Product** (+)
3. Fill in form:
   - Title: "Test Product [Current Date]"
   - Category: Electronics
   - Subcategory: Smartphones
   - Brand: Any predefined brand
   - Price: 999
   - Quantity: 10
   - Upload 1-2 test images
4. Click **Save**

**✅ Expected:**
- Keyboard closes smoothly (no flicker)
- Loading indicator appears
- Success message: "Product created! ASIN: ASN-xxxxx"
- Product appears in Products list
- Images display correctly

**Verify in Supabase Dashboard:**
- Go to: Table Editor → `products`
- Find your product by title
- Check ASIN format: `ASN-{timestamp}-{random}`
- Check images array contains URLs

**Verify in Supabase Storage:**
- Go to: Storage → `product-images` bucket
- Navigate to: `{seller_id}/{product_id}/`
- Verify images uploaded successfully

#### Test 2: Update Existing Product

1. In Products list, tap **Edit** (pencil icon) on your test product
2. Change title or price
3. Add more images (optional)
4. Click **Save**

**✅ Expected:**
- Success message: "Product updated successfully"
- Changes reflect in product list
- Updated_at timestamp changes in database

#### Test 3: Delete Product

1. In Products list, tap **Delete** (trash icon) on your test product
2. Confirm deletion

**✅ Expected:**
- Success message: "Product deleted successfully (X images removed)"
- Product disappears from list
- Images deleted from Storage bucket
- Product soft-deleted in database (deleted_at timestamp)

#### Test 4: Search & Filter

1. In Products list, use search bar
2. Try filters: All, In Stock, Low Stock, Draft

**✅ Expected:**
- Search returns matching products
- Filters work correctly
- No 404 errors in logs

---

## 🔍 STEP 5: MONITORING & DEBUGGING

### Check Supabase Logs

1. Go to: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/logs/explorer
2. Filter by:
   - Function name: `create-product`, `update-product`, etc.
   - Time range: Last 15 minutes
3. Look for errors or warnings

### Check Flutter Logs

```powershell
# Run app with verbose logging
flutter run -v

# Or filter logs for specific errors
flutter logs | Select-String "404|StorageException|FunctionException"
```

### Common Log Messages

| Message | Meaning | Action |
|---------|---------|--------|
| `✅ Product saved to local DB` | Success | No action needed |
| `⚠️ Local DB save failed` | Local DB error | Non-critical, cloud operation succeeded |
| `Storage error uploading image` | Bucket not found | Run SQL setup script |
| `FunctionException(status: 404)` | Function not deployed | Deploy functions |
| `Unauthorized: sellerId does not match` | Auth error | Check user is logged in |

---

## 🎯 VERIFICATION CHECKLIST

After completing all steps, verify:

### Database
- [ ] `product-images` bucket exists and is public
- [ ] `products` table has correct schema
- [ ] RLS policies are active for products table
- [ ] RLS policies are active for storage.objects

### Edge Functions
- [ ] `create-product` deployed and responding
- [ ] `update-product` deployed and responding
- [ ] `delete-product` deployed and responding
- [ ] `search-products` deployed and responding
- [ ] `SUPABASE_SERVICE_ROLE_KEY` secret set

### Flutter App
- [ ] No 404 errors in logs
- [ ] Create product works with ASIN generation
- [ ] Update product works
- [ ] Delete product works with image cleanup
- [ ] Images upload to `product-images` bucket
- [ ] Search/filter works correctly
- [ ] Keyboard doesn't flicker on save

### Security
- [ ] Users can only view their own products
- [ ] Users can only update their own products
- [ ] Users can only delete their own products
- [ ] Storage RLS prevents cross-user image access
- [ ] ASIN is server-generated (not client)

---

## 📊 PERFORMANCE METRICS

After deployment, monitor:

| Metric | Target | How to Check |
|--------|--------|--------------|
| Product create time | < 2 seconds | Flutter app timing |
| Image upload time (per image) | < 3 seconds | Flutter app timing |
| Search response time | < 1 second | Edge Function logs |
| Delete + image cleanup | < 3 seconds | Edge Function logs |
| Error rate | < 1% | Supabase logs |

---

## 🚨 ROLLBACK PLAN

If deployment fails:

### 1. Revert Database Changes

```sql
-- Drop tables (CAREFUL: This deletes all data!)
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS brands CASCADE;
DROP TABLE IF EXISTS subcategories CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

-- Drop storage bucket policies
DROP POLICY IF EXISTS "Anyone can view product images" ON storage.objects;
DROP POLICY IF EXISTS "Sellers can upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Sellers can delete their own images" ON storage.objects;
DROP POLICY IF EXISTS "Sellers can update their own images" ON storage.objects;
```

### 2. Undeploy Functions

```bash
supabase functions delete create-product
supabase functions delete update-product
supabase functions delete delete-product
supabase functions delete search-products
```

### 3. Revert Flutter Code

```bash
# If using git
git checkout HEAD -- lib/services/supabase_storage.dart
git checkout HEAD -- lib/pages/product/product_form_screen.dart
```

---

## 📞 SUPPORT & RESOURCES

### Documentation Links
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Supabase Storage](https://supabase.com/docs/guides/storage)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)

### Project Files
- Database schema: `supabase/complete_setup.sql`
- Edge Functions: `supabase/functions/{function-name}/index.ts`
- Flutter services: `lib/services/supabase.dart`, `lib/services/supabase_storage.dart`

### Contact
For issues, check:
1. Supabase Dashboard → Logs
2. Flutter logs (`flutter logs`)
3. Edge Function logs (`supabase functions logs <function-name>`)

---

**Status:** ✅ Ready for deployment  
**Estimated Time:** 15-20 minutes  
**Risk Level:** Medium (backup data before deployment)
