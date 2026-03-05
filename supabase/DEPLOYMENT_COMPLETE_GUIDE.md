# 🚀 Aurora E-Commerce - Complete Deployment Guide

## Project: ofovfxsfazlwvcakpuer

This guide covers the complete deployment of Edge Functions and database setup for the Aurora Flutter e-commerce app.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Part 1: Database Setup](#part-1-database-setup)
3. [Part 2: Edge Functions Deployment](#part-2-edge-functions-deployment)
4. [Part 3: Flutter App Configuration](#part-3-flutter-app-configuration)
5. [Part 4: Testing Checklist](#part-4-testing-checklist)
6. [Part 5: Troubleshooting](#part-5-troubleshooting)

---

## Prerequisites

### Required Software

```bash
# Flutter (version 3.38.7 or higher)
flutter --version

# Supabase CLI
winget install Supabase.CLI
# OR
npm install -g supabase

# Verify installation
supabase --version
```

### Required Credentials

1. **Supabase Project URL**: `https://ofovfxsfazlwvcakpuer.supabase.co`
2. **Supabase Anon Key**: Get from [Supabase Dashboard](https://app.supabase.com/project/ofovfxsfazlwvcakpuer/settings/api)
3. **Supabase Service Role Key**: Get from [Supabase Dashboard](https://app.supabase.com/project/ofovfxsfazlwvcakpuer/settings/api)

---

## Part 1: Database Setup

### Step 1.1: Run SQL Migration

1. Open [Supabase SQL Editor](https://app.supabase.com/project/ofovfxsfazlwvcakpuer/sql/new)
2. Copy the contents of `supabase/complete_setup.sql`
3. Paste and run the SQL script
4. Verify all tables are created successfully

### Step 1.2: Verify Database Tables

Run these verification queries:

```sql
-- Check tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Check storage bucket
SELECT id, name, public, file_size_limit 
FROM storage.buckets 
WHERE id = 'product-images';

-- Check RLS policies
SELECT policyname, tablename 
FROM pg_policies 
WHERE schemaname = 'public';
```

### Step 1.3: Verify Storage Bucket

1. Go to [Storage Dashboard](https://app.supabase.com/project/ofovfxsfazlwvcakpuer/storage)
2. Verify `product-images` bucket exists
3. Bucket should be **Public** with 10MB file size limit

---

## Part 2: Edge Functions Deployment

### Step 2.1: Navigate to Supabase Folder

```powershell
cd c:\Users\yn098\aurora\A-U-R-O-R-A\supabase
```

### Step 2.2: Login to Supabase

```powershell
supabase login
```

This will open a browser for authentication.

### Step 2.3: Link Project

```powershell
supabase link --project-ref ofovfxsfazlwvcakpuer
```

### Step 2.4: Deploy Edge Functions

Use the provided PowerShell script:

```powershell
.\deploy-functions.ps1
```

**OR** deploy manually:

```powershell
# Deploy all 4 functions
supabase functions deploy create-product --no-verify-jwt
supabase functions deploy update-product --no-verify-jwt
supabase functions deploy delete-product --no-verify-jwt
supabase functions deploy search-products --no-verify-jwt
```

### Step 2.5: Set Environment Secrets

```powershell
# Get your service role key from:
# https://app.supabase.com/project/ofovfxsfazlwvcakpuer/settings/api

supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
```

### Step 2.6: Verify Deployment

```powershell
# List all deployed functions
supabase functions list

# Check function logs
supabase functions logs create-product
```

---

## Part 3: Flutter App Configuration

### Step 3.1: Update Supabase Configuration

Ensure your Flutter app has the correct Supabase URL and Anon Key:

**File**: `lib/main.dart` or `lib/config/supabase_config.dart`

```dart
await Supabase.initialize(
  url: 'https://ofovfxsfazlwvcakpuer.supabase.co',
  anonKey: 'YOUR_ANON_KEY', // Get from Supabase Dashboard
);
```

### Step 3.2: Run Flutter App

```powershell
# Get dependencies
flutter pub get

# Run on connected device
flutter run

# OR run on specific device
flutter devices
flutter run -d <device_id>
```

---

## Part 4: Testing Checklist

### 4.1 Edge Functions Testing

#### Test create-product Function

```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/create-product' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Test Product",
    "brand": "Test Brand",
    "category": "Electronics",
    "subcategory": "Smartphones",
    "price": 999,
    "quantity": 10,
    "sellerId": "YOUR_USER_ID"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Product created successfully",
  "asin": "ASN-1234567890-ABCDEFGHI",
  "product": { ... }
}
```

#### Test search-products Function

```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/search-products' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "sellerId": "YOUR_USER_ID",
    "query": "test",
    "limit": 10,
    "offset": 0
  }'
```

#### Test update-product Function

```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/update-product' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "asin": "ASN-1234567890-ABCDEFGHI",
    "sellerId": "YOUR_USER_ID",
    "updates": {
      "price": 899,
      "quantity": 15
    }
  }'
```

#### Test delete-product Function

```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/delete-product' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "asin": "ASN-1234567890-ABCDEFGHI",
    "sellerId": "YOUR_USER_ID"
  }'
```

### 4.2 Flutter App Testing

#### Product Creation Test

1. ✅ Open Flutter app
2. ✅ Navigate to Products page
3. ✅ Tap "Add Product" FAB
4. ✅ Fill in required fields:
   - Title: "Test Product"
   - Category: Electronics
   - Subcategory: Smartphones
   - Brand: Apple
   - Price: 999
   - Quantity: 10
5. ✅ Upload product images
6. ✅ Save product
7. ✅ **Verify**: ASIN is displayed in success message (format: `ASN-{timestamp}-{random}`)

#### Product List Test

1. ✅ Open Products page
2. ✅ **Verify**: Products load without errors
3. ✅ **Verify**: Product count matches database
4. ✅ Test filters: All, In Stock, Low Stock, Draft
5. ✅ Test search functionality

#### Product Update Test

1. ✅ Tap Edit on a product
2. ✅ Change price or quantity
3. ✅ Save changes
4. ✅ **Verify**: Changes reflect immediately

#### Product Delete Test

1. ✅ Tap Delete on a product
2. ✅ Confirm deletion
3. ✅ **Verify**: Product removed from list
4. ✅ **Verify**: Images deleted from storage

### 4.3 Storage Testing

1. ✅ Go to [Storage Dashboard](https://app.supabase.com/project/ofovfxsfazlwvcakpuer/storage)
2. ✅ Open `product-images` bucket
3. ✅ **Verify**: Images uploaded with path format `{seller_id}/{product_id}/{filename}`
4. ✅ **Verify**: Images are publicly accessible

### 4.4 Database Testing

Run these queries to verify data:

```sql
-- Check products created
SELECT asin, title, brand, price, quantity, created_at 
FROM products 
ORDER BY created_at DESC 
LIMIT 10;

-- Check products by seller
SELECT count(*) FROM products WHERE seller_id = 'YOUR_USER_ID';

-- Check JSONB attributes
SELECT asin, attributes 
FROM products 
WHERE attributes IS NOT NULL 
LIMIT 5;
```

---

## Part 5: Troubleshooting

### Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `FunctionException(status: 404)` | Edge Function not deployed | Run `supabase functions deploy <function-name>` |
| `StorageException: Bucket not found` | Bucket doesn't exist | Run SQL from `complete_setup.sql` |
| `Unauthorized` | Invalid auth token | Check user is logged in, verify Anon Key |
| `Missing required fields` | Incomplete request body | Verify all required fields sent to Edge Function |
| `RLS policy violation` | RLS blocking access | Check RLS policies in database |
| `Invalid ASIN` | ASIN not captured | Check `_saveProduct()` captures ASIN from response |

### Debug Commands

```powershell
# Check Edge Function logs
supabase functions logs create-product

# Check database logs
# Go to: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/logs

# Check storage logs
# Go to: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/storage

# Flutter debug
flutter run --verbose

# Clear Flutter cache
flutter clean
flutter pub get
flutter run
```

### RLS Policy Debug

If RLS is blocking access:

```sql
-- Check current policies
SELECT * FROM pg_policies WHERE tablename = 'products';

-- Temporarily disable RLS for testing (NOT FOR PRODUCTION)
ALTER TABLE products DISABLE ROW LEVEL SECURITY;

-- Re-enable RLS
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
```

---

## 📁 File Reference

### SQL Files
- `supabase/complete_setup.sql` - Complete database setup

### Edge Functions
- `supabase/functions/create-product/index.ts`
- `supabase/functions/update-product/index.ts`
- `supabase/functions/delete-product/index.ts`
- `supabase/functions/search-products/index.ts`

### Flutter Files
- `lib/services/supabase.dart` - Supabase provider with Edge Function methods
- `lib/services/supabase_storage.dart` - Image upload service
- `lib/pages/product/product_form_screen.dart` - Product form
- `lib/pages/product/product.dart` - Product list page

### Deployment Scripts
- `supabase/deploy-functions.ps1` - PowerShell deployment script
- `deploy-functions.bat` - Batch file for quick deployment

---

## ✅ Deployment Complete Checklist

- [ ] SQL migration executed successfully
- [ ] Storage bucket created
- [ ] RLS policies configured
- [ ] Edge Functions deployed
- [ ] Environment secrets set
- [ ] Flutter app configured
- [ ] Product creation tested
- [ ] Product update tested
- [ ] Product deletion tested
- [ ] Image upload tested
- [ ] Search functionality tested

---

## 📞 Support

For issues or questions:
1. Check [Supabase Documentation](https://supabase.com/docs)
2. Check [Flutter Documentation](https://docs.flutter.dev)
3. Review Edge Function logs
4. Review database logs in Supabase Dashboard

---

**Last Updated**: March 2, 2026  
**Project**: ofovfxsfazlwvcakpuer  
**Version**: 1.0.0
