# 🚀 Edge Functions Deployment & Fix Guide

**Date:** February 28, 2026  
**Issue:** 404 Error when creating products - Edge Functions not deployed to Supabase

---

## 🔴 Problem Summary

Your Flutter app calls Edge Functions that exist **locally** but are **not deployed** to Supabase cloud:

```
❌ FunctionException(status: 404, details: {code: NOT_FOUND, 
   message: Requested function was not found})
```

---

## ✅ Quick Fix (3 Steps)

### Step 1: Deploy Edge Functions

**Option A: Use PowerShell Script (Recommended)**
```powershell
.\deploy-functions.ps1
```

**Option B: Manual Deployment**
```bash
# Navigate to project root
cd c:\Users\yn098\aurora\A-U-R-O-R-A

# Deploy each function
supabase functions deploy create-product --no-verify-jwt
supabase functions deploy update-product --no-verify-jwt
supabase functions deploy delete-product --no-verify-jwt
supabase functions deploy search-products --no-verify-jwt

# Set service role key
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

### Step 2: Get Your Service Role Key

1. Go to: https://app.supabase.com
2. Select your project
3. Navigate to: **Settings** → **API**
4. Copy the **service_role** key (NOT anon key)
5. Use it in the deployment script

### Step 3: Test the Fix

```bash
# Hot restart your Flutter app
flutter run

# Test flow:
# 1. Navigate to "Add Product" screen
# 2. Fill in product details
# 3. Click "Create"
# 4. Check logs - should see "Product created! ASIN: ASN-xxx"
# 5. Verify in Supabase Dashboard → Table Editor → products
```

---

## 📋 What Was Fixed

### 1. ✅ ProductFormScreen Changes

| Change | Before | After |
|--------|--------|-------|
| **Method Called** | `createProduct(product)` | `createProductWithEdgeFunction(...)` |
| **ASIN Handling** | Client sends `null` | Server generates ASIN |
| **Response** | Not captured | ASIN extracted from `result.data['asin']` |
| **Focus Management** | None | `_focusNode` prevents keyboard flicker |

**File:** `lib/pages/product/product_form_screen.dart`

**Key Changes:**
```dart
// ✅ Added FocusNode to prevent keyboard flickering
final _focusNode = FocusNode();

// ✅ Unfocus before save operation
Future<void> _saveProduct() async {
  _focusNode.unfocus(); // Close keyboard first
  // ... rest of save logic
}

// ✅ Use Edge Function for create (NO ASIN sent)
final result = widget.product != null
    ? await supabaseProvider.updateProductWithEdgeFunction(...)
    : await supabaseProvider.createProductWithEdgeFunction(
        title: ...,
        brand: ...,
        // NO ASIN PARAMETER - server generates it
      );

// ✅ Capture ASIN from response
if (result.success && widget.product == null) {
  final generatedAsin = result.data?['asin'] as String?;
  // Show ASIN to user
}
```

### 2. ✅ Edge Function Code (Already Exists)

**File:** `supabase/functions/create-product/index.ts`

**Already handles:**
- ✅ ASIN generation: `ASN-${Date.now()}-${random()}`
- ✅ Authentication verification
- ✅ Ownership verification (sellerId matches user)
- ✅ Attribute validation
- ✅ Returns ASIN in response

### 3. ✅ SupabaseProvider (Already Correct)

**File:** `lib/services/supabase.dart` (Line 1944-2120)

**Already handles:**
- ✅ `createProductWithEdgeFunction()` - returns response with ASIN
- ✅ `updateProductWithEdgeFunction()` - uses existing ASIN
- ✅ `deleteProductWithEdgeFunction()` - includes image cleanup

---

## 🔧 Troubleshooting

### Issue: "Supabase CLI not found"

**Solution:**
```powershell
# Install via winget (Windows)
winget install Supabase.CLI

# OR via npm
npm install -g supabase

# OR via chocolatey
choco install supabase-cli
```

### Issue: "Not logged in"

**Solution:**
```bash
supabase login
```
This opens a browser for authentication.

### Issue: "Project not linked"

**Solution:**
1. Find your project ref in Supabase dashboard URL:
   - `https://app.supabase.com/project/abcdefghijk` → ref = `abcdefghijk`
2. Link project:
   ```bash
   supabase link --project-ref abcdefghijk
   ```

### Issue: "Function deploy fails"

**Check:**
1. Internet connection
2. Project ref is correct
3. You have write access to the project
4. Function files exist:
   ```
   supabase/functions/create-product/index.ts
   supabase/functions/update-product/index.ts
   supabase/functions/delete-product/index.ts
   supabase/functions/search-products/index.ts
   ```

### Issue: Still getting 404 after deployment

**Debug steps:**
```bash
# List deployed functions
supabase functions list

# Check function exists and is deployed
# You should see: create-product, update-product, delete-product, search-products

# Redeploy specific function
supabase functions deploy create-product --no-verify-jwt

# Check logs
supabase functions logs create-product
```

---

## 🎯 Verification Checklist

After deployment, verify:

- [ ] **No 404 errors** in Flutter logs
- [ ] **ASIN shown** in success message: "Product created! ASIN: ASN-xxx"
- [ ] **Product exists** in Supabase `products` table
- [ ] **ASIN format** is correct: `ASN-{timestamp}-{random}`
- [ ] **Keyboard doesn't flicker** when saving
- [ ] **Images upload** successfully
- [ ] **Update works** for existing products
- [ ] **Delete works** with image cleanup

---

## 📊 ASIN Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Flutter: Create Product                                  │
│    - User fills form                                        │
│    - NO ASIN in request body                                │
│    - Sends: title, brand, category, price, etc.             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Supabase Edge Function: create-product                   │
│    - Verifies authentication                                │
│    - Generates ASIN: ASN-{timestamp}-{random}               │
│    - Inserts into products table                            │
│    - Returns: { success, asin, product }                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Flutter: Capture ASIN                                    │
│    - Extract: result.data['asin']                           │
│    - Display to user                                        │
│    - Store for future update/delete operations              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security Benefits

| Before | After |
|--------|-------|
| ❌ Client could send `null` ASIN | ✅ Server generates unique ASIN |
| ❌ No ownership verification | ✅ Verifies sellerId = authenticated user |
| ❌ ASIN could be guessed | ✅ Timestamp + random = unguessable |
| ❌ No validation | ✅ Validates attributes against schema |
| ❌ Images not cleaned on delete | ✅ Delete function removes orphaned images |

---

## 📈 Performance Improvements

| Issue | Fix |
|-------|-----|
| Keyboard flickering | ✅ Added `_focusNode.unfocus()` before save |
| Frame drops | ✅ Edge Function handles heavy DB operations |
| Main thread blocking | ✅ Async image upload |

---

## 🎯 Next Steps

1. **Deploy functions** using the script
2. **Test product creation** end-to-end
3. **Verify ASIN generation** in Supabase dashboard
4. **Test update/delete** operations
5. **Monitor logs** for any errors

---

## 📞 Support

If you encounter issues:

1. Check deployment script output for errors
2. Review Supabase function logs: `supabase functions logs <function-name>`
3. Verify Flutter logs show successful ASIN capture
4. Ensure Supabase project has correct table schema

---

**Status:** ✅ Code changes complete, awaiting deployment  
**Priority:** 🔴 HIGH - Blocks product creation  
**Estimated Time:** 5-10 minutes for deployment
