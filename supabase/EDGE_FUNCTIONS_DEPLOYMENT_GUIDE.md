# ⚡ Complete Supabase Edge Functions Deployment Guide

## 📋 Overview

This guide will help you deploy **4 complete Edge Functions** for product management in your Aurora E-commerce application:

1. **create-product** - Create products with validation
2. **update-product** - Update existing products
3. **delete-product** - Delete products with automatic image cleanup
4. **search-products** - Advanced product search with filters

---

## 📁 File Structure

Your project should now have this structure:

```
A-U-R-O-R-A/
├── lib/
│   └── services/
│       └── supabase.dart          ← Updated with edge function methods
│
└── supabase/
    ├── functions/
    │   ├── create-product/
    │   │   └── index.ts            ← ✅ Created
    │   ├── update-product/
    │   │   └── index.ts            ← ✅ Created
    │   ├── delete-product/
    │   │   └── index.ts            ← ✅ Created
    │   └── search-products/
    │       └── index.ts            ← ✅ Created
    │
    ├── migrations/
    │   └── 20240301000001_recreate_products.sql  ← ✅ Created
    │
    ├── config.toml                 ← ✅ Updated
    └── deploy-functions.ps1        ← ✅ Deployment script
```

---

## 🚀 Deployment Steps

### Step 1: Install Supabase CLI

#### Windows (PowerShell as Administrator)
```powershell
choco install supabase
```

#### macOS
```bash
brew install supabase/tap/supabase
```

#### Linux
```bash
curl -fsSL https://supabase.com/install.sh | bash
```

#### Verify Installation
```bash
supabase --version
```

---

### Step 2: Login to Supabase

```bash
supabase login
```

This will open a browser window. Login with your Supabase account.

---

### Step 3: Link Your Project

```bash
cd "c:\Users\yn098\aurora\A-U-R-O-R-A"
supabase link --project-ref ofovfxsfazlwvcakpuer
```

**Find your project reference:**
- Go to Supabase Dashboard
- Settings → API
- Copy the **Project Reference** (e.g., `ofovfxsfazlwvcakpuer`)

---

### Step 4: Get Your Service Role Key

1. Go to **Supabase Dashboard**
2. Navigate to **Settings** → **API**
3. Under **Project Service Keys**, copy the **service_role** key (NOT the anon key!)

⚠️ **Important:** The service role key bypasses RLS. Keep it secret!

---

### Step 5: Deploy Using PowerShell Script (Recommended)

```powershell
cd "c:\Users\yn098\aurora\A-U-R-O-R-A"
.\supabase\deploy-functions.ps1
```

The script will:
1. ✅ Check Supabase CLI installation
2. ✅ Verify authentication
3. ✅ Link your project
4. ✅ Prompt for service role key
5. ✅ Deploy all 4 functions
6. ✅ Optionally push database schema

---

### Step 6: Manual Deployment (Alternative)

If you prefer manual deployment:

#### Set Service Role Key
```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
```

#### Deploy Each Function
```bash
cd "c:\Users\yn098\aurora\A-U-R-O-R-A\supabase\functions"

supabase functions deploy create-product --no-verify-jwt
supabase functions deploy update-product --no-verify-jwt
supabase functions deploy delete-product --no-verify-jwt
supabase functions deploy search-products --no-verify-jwt
```

#### Or Deploy All at Once
```bash
supabase functions deploy --no-verify-jwt
```

---

### Step 7: Push Database Schema

```bash
cd "c:\Users\yn098\aurora\A-U-R-O-R-A"
supabase db push
```

This will create:
- `products` table (enhanced with categories)
- `categories` table
- `subcategories` table
- `brands` table
- All necessary indexes and triggers

---

## ✅ Verification

### 1. Check Deployed Functions

Go to: https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/functions

You should see:
- ✅ create-product
- ✅ update-product
- ✅ delete-product
- ✅ search-products

### 2. Test Function URLs

Each function has a URL:

```
https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/create-product
https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/update-product
https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/delete-product
https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/search-products
```

### 3. Check Database Tables

Go to: https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/editor

Verify these tables exist:
- ✅ products
- ✅ categories
- ✅ subcategories
- ✅ brands

---

## 🧪 Testing in Flutter App

### Update your product creation code:

```dart
// OLD WAY (still works)
final product = AmazonProduct(...);
final result = await supabaseProvider.createProduct(product);

// NEW WAY (with edge functions - RECOMMENDED)
final result = await supabaseProvider.createProductWithEdgeFunction(
  title: 'My Product',
  brand: 'My Brand',
  category: 'Electronics',
  subcategory: 'Smartphones',
  price: 29.99,
  quantity: 100,
  description: 'Product description',
  status: 'active',
  attributes: {
    'color': 'Black',
    'storage': '128GB',
  },
  images: [
    {'url': 'https://...'},
  ],
);

if (result.success) {
  print('Product created! ASIN: ${result.data?['asin']}');
} else {
  print('Error: ${result.message}');
}
```

### Update your delete code:

```dart
// NEW WAY (with automatic image cleanup)
final result = await supabaseProvider.deleteProductWithEdgeFunction(asin);

if (result.success) {
  print(result.message); // "Product deleted successfully (3 images removed)"
}
```

### Update your search code:

```dart
// NEW WAY (advanced filtering)
final result = await supabaseProvider.searchProductsWithEdgeFunction(
  query: 'wireless',
  category: 'Electronics',
  brand: 'Samsung',
  minPrice: 50.0,
  maxPrice: 200.0,
  limit: 50,
);

if (result.success) {
  final products = result.data!;
  print('Found ${products.length} products');
}
```

---

## 📊 Function Features

### 1. create-product

**Features:**
- ✅ Automatic ASIN generation
- ✅ Authentication verification
- ✅ Seller ownership validation
- ✅ Attribute schema validation
- ✅ Required fields checking

**Request Body:**
```json
{
  "title": "Product Title",
  "brand": "Brand Name",
  "category": "Category",
  "subcategory": "Subcategory",
  "price": 29.99,
  "quantity": 100,
  "sellerId": "user-uuid",
  "attributes": {...}
}
```

**Response:**
```json
{
  "success": true,
  "message": "Product created successfully",
  "product": {...},
  "asin": "ASN-1234567890-ABCDEF"
}
```

---

### 2. update-product

**Features:**
- ✅ Ownership verification
- ✅ Timestamp auto-update
- ✅ Attribute validation
- ✅ Partial updates support

**Request Body:**
```json
{
  "asin": "ASN-...",
  "updates": {
    "price": 24.99,
    "quantity": 150,
    "attributes": {...}
  },
  "sellerId": "user-uuid"
}
```

---

### 3. delete-product

**Features:**
- ✅ Ownership verification
- ✅ Automatic image deletion from storage
- ✅ Reports deleted/failed images
- ✅ Soft delete support (can be added)

**Response:**
```json
{
  "success": true,
  "message": "Product deleted successfully",
  "deletedImages": 3,
  "failedImages": 0,
  "asin": "ASN-..."
}
```

---

### 4. search-products

**Features:**
- ✅ Full-text search
- ✅ Category/subcategory filters
- ✅ Price range filtering
- ✅ Attribute filtering (JSONB)
- ✅ Pagination support
- ✅ Count total results

**Request Body:**
```json
{
  "query": "wireless headphones",
  "category": "Electronics",
  "minPrice": 50,
  "maxPrice": 200,
  "sellerId": "user-uuid",
  "limit": 50,
  "offset": 0
}
```

**Response:**
```json
{
  "success": true,
  "products": [...],
  "count": 127,
  "limit": 50,
  "offset": 0,
  "hasMore": true
}
```

---

## 🔒 Security Features

All edge functions include:

1. **Authentication Verification**
   - JWT token validation
   - User session verification

2. **Ownership Validation**
   - Seller ID must match authenticated user
   - Can only update/delete own products

3. **Input Validation**
   - Required fields checking
   - Type validation
   - Attribute schema validation

4. **RLS Bypass (Controlled)**
   - Uses service role for validation
   - Still enforces business logic

---

## 🐛 Troubleshooting

### Error: "Function not found"

**Solution:**
```bash
# Redeploy the function
supabase functions deploy create-product --no-verify-jwt
```

### Error: "Unauthorized"

**Causes:**
- Invalid JWT token
- Seller ID doesn't match user

**Solution:**
- Ensure user is logged in
- Check `currentUser!.id` matches `sellerId`

### Error: "Missing required fields"

**Solution:**
- Check request body includes all required fields
- Required: `title`, `brand`, `category`, `subcategory`, `sellerId`

### Error: "Database insert failed"

**Solution:**
1. Check database schema is deployed
2. Verify RLS policies are correct
3. Check function logs in Supabase Dashboard

---

## 📈 Monitoring & Logs

### View Function Logs

**Via Dashboard:**
1. Go to Supabase Dashboard
2. Edge Functions → Select function
3. Click "Logs" tab

**Via CLI:**
```bash
supabase functions logs create-product
```

### Set Up Alerts

1. Go to **Settings** → **Integrations**
2. Add monitoring tools (e.g., Sentry, Datadog)
3. Configure alerts for errors

---

## 🎯 Performance Tips

1. **Use Pagination**
   ```dart
   // Load 50 at a time
   searchProductsWithEdgeFunction(limit: 50, offset: page * 50)
   ```

2. **Cache Results**
   ```dart
   // Cache search results
   await cache.set('search_$query', products, Duration(minutes: 5));
   ```

3. **Optimize Images**
   ```dart
   // Compress before upload
   final optimized = await supabaseProvider.optimizeImage(
     imageFile: file,
     maxWidth: 1920,
     quality: 85,
   );
   ```

4. **Use Indexes**
   - Already created for: `asin`, `seller_id`, `category`, `price`
   - Add more based on your query patterns

---

## 🤖 AI Prompts for Future Enhancements

| Task | Prompt |
|------|--------|
| Bulk import | "Add edge function `bulk-import-products` that accepts CSV and creates multiple products with validation." |
| Analytics | "Create edge function to track product views with daily aggregation." |
| Low stock alerts | "Add webhook that triggers when quantity < 10 to send notifications." |
| Image optimization | "Modify create-product to resize images to max 1920px and compress to 85%." |
| Soft delete | "Add `deleted_at` column and modify delete-product for soft delete." |

---

## ✅ Deployment Checklist

- [ ] Supabase CLI installed
- [ ] Logged in to Supabase
- [ ] Project linked
- [ ] Service role key set
- [ ] All 4 functions deployed
- [ ] Database schema pushed
- [ ] Functions visible in dashboard
- [ ] Flutter app updated with new methods
- [ ] Test create product
- [ ] Test update product
- [ ] Test delete product (verify image cleanup)
- [ ] Test search products
- [ ] Monitor logs for errors

---

## 🎉 Success!

Your complete Edge Functions system is now deployed and ready!

**Function URLs:**
- https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/create-product
- https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/update-product
- https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/delete-product
- https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/search-products

**Next Steps:**
1. Test all functions in your Flutter app
2. Monitor logs in Supabase Dashboard
3. Set up monitoring/alerts
4. Document any custom business logic

---

**Last Updated:** February 28, 2026  
**Version:** 1.0.0  
**Status:** ✅ Ready for Production
