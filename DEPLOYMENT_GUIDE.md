# 🚀 Quick Deployment Guide - Aurora E-Commerce

**Last Updated:** February 28, 2026  
**Status:** ✅ Code Ready - Awaiting Deployment

---

## ⚡ 3-Step Deployment (10 Minutes)

### Step 1: Create Storage Bucket (2 min)

**Option A: Via Dashboard (Easiest)**
1. Go to: https://supabase.com/dashboard
2. Select your project
3. Click **Storage** in left sidebar
4. Click **Create bucket**
5. Settings:
   - **Name:** `product-images`
   - **Public:** ✅ Yes
   - **File size limit:** `52428800` (50MB)
   - **Allowed MIME types:** `image/jpeg,image/png,image/webp,image/gif`
6. Click **Create bucket**

**Option B: Via SQL Editor**
1. Go to: https://supabase.com/dashboard → **SQL Editor**
2. Click **New Query**
3. Copy/paste this SQL:
```sql
-- Create bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('product-images', 'product-images', true, 52428800, 
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Policy: Users manage own images
CREATE POLICY "Users can manage own product images"
ON storage.objects FOR ALL TO authenticated
USING (bucket_id = 'product-images' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'product-images' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Policy: Public can view images
CREATE POLICY "Users can view all product images"
ON storage.objects FOR SELECT TO authenticated, anon
USING (bucket_id = 'product-images');
```
4. Click **Run** (or press Ctrl+Enter)

---

### Step 2: Deploy Edge Functions (5 min)

**Prerequisites:**
- Supabase CLI installed (`winget install Supabase.CLI`)
- Logged in (`supabase login`)
- Project linked (`supabase link --project-ref YOUR_REF`)

**Deployment Commands:**
```powershell
# Navigate to project
cd C:\Users\yn098\aurora\A-U-R-O-R-A

# Deploy all functions
supabase functions deploy create-product --no-verify-jwt
supabase functions deploy update-product --no-verify-jwt
supabase functions deploy delete-product --no-verify-jwt
supabase functions deploy search-products --no-verify-jwt

# Set service role key
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
```

**Get Service Role Key:**
1. Go to: https://supabase.com/dashboard → **Settings** → **API**
2. Copy the **service_role** key (NOT anon/public key)
3. Paste it in the command above

**Alternative: Use Deployment Script**
```powershell
# PowerShell
.\deploy-functions.ps1

# OR Batch file
.\deploy-functions.bat
```

---

### Step 3: Test Product Creation (3 min)

```bash
# Hot restart Flutter app
flutter run

# Test Flow:
# 1. Login as seller
# 2. Tap "+" or "Add Product"
# 3. Fill in:
#    - Title: "Test Product"
#    - Category: "Electronics"
#    - Subcategory: "Headphones"
#    - Brand: Select any
#    - Price: 99.99
#    - Quantity: 10
#    - Add 1-2 images
# 4. Tap "Create"
```

**Expected Result:**
```
✅ Success message: "Product created! ASIN: ASN-1709123456-ABC123DEF"
✅ Navigator pops back to product list
✅ New product appears in list
✅ Images display correctly
```

**Check Logs:**
```
I/flutter: ✅ Success message shown
I/flutter: ✅ ASIN captured from response
I/flutter: ✅ Product created successfully
```

**Verify in Supabase:**
1. Dashboard → **Table Editor** → `products`
2. Find your new product
3. Verify:
   - ✅ ASIN format: `ASN-{timestamp}-{random}`
   - ✅ `seller_id` matches your user ID
   - ✅ All fields populated correctly

**Check Storage:**
1. Dashboard → **Storage** → `product-images`
2. Open folder with your `seller_id`
3. Verify images uploaded successfully

---

## 🔍 Troubleshooting

### Issue: "Supabase CLI not found"

```powershell
# Install via winget
winget install Supabase.CLI

# OR via npm
npm install -g supabase
```

### Issue: "Not logged in"

```bash
supabase login
```
This opens a browser for authentication.

### Issue: "Project not linked"

1. Find project ref in URL: `https://app.supabase.com/project/abcdefghijk`
2. Link: `supabase link --project-ref abcdefghijk`

### Issue: "404 Function not found" after deployment

```bash
# List deployed functions
supabase functions list

# Check logs for errors
supabase functions logs create-product

# Redeploy
supabase functions deploy create-product --no-verify-jwt
```

### Issue: "Bucket not found" after creation

- Wait 30 seconds for bucket to propagate
- Verify bucket name is exactly `product-images` (lowercase, hyphen)
- Check bucket exists: Dashboard → Storage

### Issue: Images upload but product creation fails

- Check Edge Function logs: `supabase functions logs create-product`
- Verify `sellerId` matches authenticated user
- Check RLS policies allow insert

---

## ✅ Verification Checklist

After deployment, verify all items:

### Infrastructure
- [ ] Storage bucket `product-images` exists
- [ ] Bucket is public
- [ ] RLS policies configured
- [ ] Edge Functions deployed (all 4)
- [ ] Service role key set

### Product Creation
- [ ] No 404 errors in logs
- [ ] ASIN generated server-side
- [ ] ASIN format: `ASN-{timestamp}-{random}`
- [ ] Product appears in Supabase table
- [ ] Images upload successfully
- [ ] Description auto-generated

### Product Management
- [ ] Update works (uses existing ASIN)
- [ ] Delete works (removes images)
- [ ] Search works (returns results)
- [ ] Keyboard doesn't flicker
- [ ] No frame drops/lag

### Security
- [ ] Can only update own products
- [ ] Can only delete own products
- [ ] Can only view own products (unless active)
- [ ] Images stored in seller's folder
- [ ] Auth verified server-side

---

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter App (Client)                                       │
│  - product_form_screen.dart                                 │
│  - Calls Edge Functions                                     │
│  - Captures ASIN from response                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  Supabase Edge Functions (Server)                           │
│  - create-product: Generates ASIN, inserts product          │
│  - update-product: Updates by ASIN                          │
│  - delete-product: Deletes + removes images                 │
│  - search-products: Filters/sorts products                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  Supabase Backend                                           │
│  - Database: products table with RLS                        │
│  - Storage: product-images bucket                           │
│  - Auth: JWT verification                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Success Metrics

| Metric | Before | After |
|--------|--------|-------|
| **Product Creation** | ❌ 404 Error | ✅ Success |
| **ASIN Generation** | ❌ Client (null) | ✅ Server |
| **Image Upload** | ❌ Bucket not found | ✅ Uploaded |
| **Security** | ⚠️ Weak | ✅ RLS + Auth |
| **Performance** | ⚠️ Main thread blocking | ✅ Async |
| **UX** | ⚠️ Keyboard flicker | ✅ Smooth |

---

## 📞 Support Resources

- **Supabase Docs:** https://supabase.com/docs
- **Edge Functions:** https://supabase.com/docs/guides/functions
- **Storage:** https://supabase.com/docs/guides/storage
- **Flutter Discord:** https://discord.gg/flutter
- **Supabase Discord:** https://discord.gg/supabase

---

## 🎉 Post-Deployment

After successful deployment:

1. **Monitor logs** for 24 hours
2. **Test edge cases** (large images, slow network)
3. **Backup database** (Settings → Database → Backups)
4. **Enable analytics** (track product creation success rate)
5. **Set up alerts** (function errors, storage quota)

---

**Status:** ✅ Ready to Deploy  
**Estimated Time:** 10 minutes  
**Difficulty:** ⭐⭐☆☆☆ (Easy)

**Good luck!** 🚀
