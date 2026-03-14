# 🚀 Deploy SKU & QR Code Fixes

## Issues Fixed:

1. ✅ **SKU not in Supabase table** - Edge function now accepts and saves SKU
2. ✅ **SKU field empty in UI** - SKU now generated and sent to server
3. ✅ **QR code not visible** - QR data saved to database after product creation

---

## Files Changed:

### **1. Edge Function** (`supabase/functions/create-product/index.ts`)
- Added `sku` parameter acceptance
- Generate SKU if not provided by client
- Save SKU to database
- Return SKU in response

### **2. Flutter Service** (`lib/services/supabase.dart`)
- Added `sku` parameter to `createProductWithEdgeFunction()`
- Send SKU to edge function if provided

### **3. Product Form** (`lib/pages/product/product_form_screen.dart`)
- Generate SKU before calling edge function
- Send SKU to edge function
- Build QR code with ASIN + SKU after creation
- Save QR data to server
- Show success message with ASIN and SKU

---

## 🔧 Deployment Steps:

### **Step 1: Deploy Edge Function**

```powershell
cd c:\Users\yn098\aurora\A-U-R-O-R-A\supabase\functions
supabase functions deploy create-product --project-ref ofovfxsfazlwvcakpuer
```

### **Step 2: Test Product Creation**

1. **Open "Add Product" form**
2. **Fill in all fields** (title, brand, price, category, etc.)
3. **Tap "Save"**
4. **Watch console logs:**
   ```
   ✓ Generated SKU: 550e8400-e29b-41d4-a716-446655440000
   Product created with ASIN: ASN-1234567890-ABC123, SKU: 550e8400-e29b-41d4-a716-446655440000
   ✓ QR code saved to server
   Product URL: https://aurora-app.com/product?seller=...&asin=...
   ```
5. **Success message shows:** `Product created! ASIN: xxx | SKU: yyy`
6. **Check Supabase table:**
   ```sql
   SELECT asin, sku, qr_data FROM products ORDER BY created_at DESC LIMIT 1;
   ```
   Should show:
   - `asin`: ASN-timestamp-random
   - `sku`: UUID from Flutter
   - `qr_data`: JSON with product link

7. **Open product details** → Tap QR code icon → Should display QR code

---

## 📊 Expected Database State:

```sql
-- After creating a product
asin                          | sku                                 | qr_data
------------------------------|-------------------------------------|----------------------------------
ASN-1710234567-XYZ123        | 550e8400-e29b-41d4-a716-446655440000 | {"asin":"...", "sku":"...", ...}
```

---

## ✅ Verification Checklist:

- [ ] Edge function deployed
- [ ] Create product with all fields filled
- [ ] Console shows "Generated SKU: ..."
- [ ] Console shows "QR code saved to server"
- [ ] Success message shows ASIN and SKU
- [ ] Supabase `products` table has `sku` column populated
- [ ] Supabase `products` table has `qr_data` column populated
- [ ] Product details page shows QR code icon
- [ ] Tapping QR code icon displays QR code with product link

---

## 🐛 Troubleshooting:

### **SKU still empty in table:**
1. Check edge function logs:
   ```bash
   supabase functions logs create-product --project-ref ofovfxsfazlwvcakpuer
   ```
2. Verify SKU is in request body (check Flutter console logs)
3. Check edge function accepted SKU (should log it)

### **QR code not showing:**
1. Check if `qr_data` is in database
2. Verify product model loads `qrData` from JSON
3. Check console for "QR code saved to server" message
4. Try pulling down to refresh product list

### **Success message doesn't show SKU:**
1. Check edge function response includes `sku` field
2. Verify Flutter code extracts `sku` from response
3. Check console logs for response data

---

## 📝 Summary:

| Component | Status | Notes |
|-----------|--------|-------|
| **SKU Generation** | ✅ Flutter | UUID v4 |
| **SKU Storage** | ✅ Supabase | Saved via edge function |
| **QR Code** | ✅ Flutter | Built after creation |
| **QR Storage** | ✅ Supabase | Saved via UPDATE |
| **UI Display** | ✅ Both | SKU in success, QR in details |

**Deploy and test!** 🎉
