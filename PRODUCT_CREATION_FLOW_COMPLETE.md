# ✅ Complete Product Creation Flow with SKU & QR

## IMPLEMENTATION COMPLETE!

### **New Flow:**
1. **Generate SKU** (Flutter app) 
2. **Call Edge Function** (get ASIN from server)
3. **Build QR Code** (with ASIN + SKU)
4. **Save to Server** (update qr_data field)

---

## 🔄 Step-by-Step Flow

```
┌─────────────────────┐
│  User Fills Form    │
│  (Title, Price...)  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  STEP 1:            │
│  Generate SKU       │
│  (Flutter: UUID)    │
│  sku = uuid.v4()    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  STEP 2:            │
│  Call Edge Function │
│  Send: SKU          │
│  Get: ASIN          │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Edge Function:     │
│  - Generate ASIN    │
│  - Accept SKU       │
│  - Save Product     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  STEP 3:            │
│  Build QR Code      │
│  - ASIN (server)    │
│  - SKU (from step1) │
│  - URL              │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  STEP 4:            │
│  Save QR to Server  │
│  UPDATE products    │
│  SET qr_data = ...  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Show Success       │
│  ASIN + SKU         │
└─────────────────────┘
```

---

## 📦 Code Implementation

### **Step 1: Generate SKU (Flutter)**

```dart
// lib/pages/product/product_form_screen.dart

import 'package:uuid/uuid.dart';

Future<void> _saveProduct() async {
  // ... validation ...
  
  // STEP 1: Generate SKU locally BEFORE calling edge function
  final generatedSku = const Uuid().v4();
  debugPrint('✓ Generated SKU: $generatedSku');
  
  // ... rest of preparation ...
}
```

---

### **Step 2: Send to Edge Function**

```dart
// CREATE: New product - send generated SKU, server generates ASIN
final result = await supabaseProvider.createProductWithEdgeFunction(
  title: _titleController.text.trim(),
  brand: finalBrandName,
  category: _selectedCategory!,
  subcategory: _selectedSubcategory!,
  price: double.tryParse(_priceController.text.trim()) ?? 0,
  quantity: int.tryParse(_quantityController.text.trim()) ?? 0,
  description: generatedDescription,
  attributes: _productAttributes,
  brandId: finalBrandId,
  isLocalBrand: isLocalBrand,
  images: imageUrls.map((url) => {'url': url}).toList(),
  status: _status,
  currency: _accountCurrency,
  sku: generatedSku, // ← Send our generated SKU to server
);
```

---

### **Edge Function (Supabase)**

```typescript
// supabase/functions/manage-product/index.ts

case "create": {
  // Generate ASIN as UUID (server-side)
  const generatedAsin = crypto.randomUUID();
  
  // Get SKU from client, or generate if not provided
  const providedSku = data.sku as string | undefined;
  const finalSku = providedSku || crypto.randomUUID();

  const productData = {
    ...data,
    asin: generatedAsin, // Server-generated ASIN
    sku: finalSku, // Client-provided SKU
    seller_id: user.id,
  };

  // Insert to database
  const { data: newProduct } = await supabase
    .from("products")
    .insert(productData)
    .select()
    .single();

  return {
    success: true,
    asin: generatedAsin,
    sku: finalSku,
    seller_id: user.id,
  };
}
```

---

### **Step 3 & 4: Build QR and Save**

```dart
// After edge function returns
if (result.success && widget.product == null) {
  final finalAsin = result.data?['asin'] as String?;
  final sellerId = result.data?['seller_id'] as String?;
  
  if (finalAsin != null) {
    // Build product URL
    final productUrl = 'https://aurora-app.com/product?seller=$sellerId&asin=$finalAsin';
    
    // Build QR data with ASIN + SKU + URL
    final qrData = jsonEncode({
      'asin': finalAsin,
      'sku': generatedSku, // Use the SKU we generated earlier
      'seller_id': sellerId,
      'url': productUrl,
      'title': _titleController.text.trim(),
      'brand': finalBrandName,
      'selling_price': price,
      'currency': _accountCurrency,
      'quantity': quantity,
    });
    
    // Send QR data to server immediately
    await supabaseProvider.client
        .from('products')
        .update({'qr_data': qrData})
        .eq('asin', finalAsin);
    
    debugPrint('✓ QR code saved to server');
    debugPrint('SKU: $generatedSku');
    
    // Show success with both ASIN and SKU
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Product created! ASIN: $finalAsin | SKU: $generatedSku'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
```

---

## 📊 QR Code Data Structure

```json
{
  "asin": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
  "sku": "550e8400-e29b-41d4-a716-446655440000",
  "seller_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "url": "https://aurora-app.com/product?seller=7c9e6679-7425-40de-944b-e07fc1f90ae7&asin=6ba7b810-9dad-11d1-80b4-00c04fd430c8",
  "title": "Wireless Bluetooth Headphones",
  "brand": "AudioTech",
  "selling_price": 79.99,
  "currency": "USD",
  "quantity": 150
}
```

**Key Fields:**
- `asin` - Generated by server (Step 2)
- `sku` - Generated by Flutter app (Step 1)
- `seller_id` - Current user's UUID
- `url` - Direct link to product page

---

## ✅ What Changed

| Component | Before | After |
|-----------|--------|-------|
| **SKU Generation** | Server only | ✅ Flutter app (Step 1) |
| **ASIN Generation** | Server only | ✅ Server (Step 2) |
| **QR Generation** | Server | ✅ Flutter app (Step 3) |
| **QR Storage** | During insert | ✅ After insert (Step 4) |
| **Flow Order** | Mixed | ✅ Sequential (1→2→3→4) |

---

## 🎯 Timing Sequence

```
Time →

[User fills form]
     │
     ▼
[Click Save]
     │
     ▼
[Generate SKU] ← Step 1 (Flutter)
     │
     ▼
[Call Edge Function] ← Step 2 (Network)
     │  ├─ Server generates ASIN
     │  └─ Returns ASIN + SKU
     │
     ▼
[Build QR Data] ← Step 3 (Flutter)
     │  ├─ Use ASIN from server
     │  └─ Use SKU from Step 1
     │
     ▼
[Save QR to Server] ← Step 4 (Database UPDATE)
     │
     ▼
[Show Success Message]
     │  ├─ Display ASIN
     │  └─ Display SKU
     │
     ▼
[Close Form / Navigate Back]
```

---

## 🚀 Deployment

### **1. Deploy Edge Function**
```powershell
cd c:\Users\yn098\aurora\A-U-R-O-R-A\supabase\functions
supabase functions deploy manage-product --project-ref ofovfxsfazlwvcakpuer
```

### **2. Test Product Creation**

1. Open "Add Product" form
2. Fill in all fields
3. Tap "Save"
4. Watch console logs:
   ```
   ✓ Generated SKU: 550e8400-e29b-41d4-a716-446655440000
   Product created with ASIN: 6ba7b810-9dad-11d1-80b4-00c04fd430c8, SKU: 550e8400-e29b-41d4-a716-446655440000
   ✓ QR code saved to server
   Product URL: https://aurora-app.com/product?seller=...&asin=...
   SKU: 550e8400-e29b-41d4-a716-446655440000
   ```
5. Success message shows: `Product created! ASIN: xxx | SKU: yyy`
6. Verify database has both `sku` and `qr_data` fields populated

---

## 📝 Summary

| Step | Who | What | When |
|------|-----|------|------|
| **1** | Flutter | Generate SKU (UUID) | Before edge function |
| **2** | Edge Function | Generate ASIN, save product | Network call |
| **3** | Flutter | Build QR with ASIN + SKU | After edge function returns |
| **4** | Flutter | Save QR to database | After QR built |

**Perfect sequential flow: SKU → ASIN → QR → Save!** 🎉
