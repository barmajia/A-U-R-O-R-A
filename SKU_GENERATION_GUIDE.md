# 🏷️ SKU Generation Guide

## ✅ Automatic SKU Generation - COMPLETE!

### **New Products: SKU Generated Automatically** ✨

When creating a **new product**, the SKU and QR code are **automatically generated on the server**. No manual action needed!

### **Legacy Products: Manual Generation Available**

For **old products** created before this feature, use the "Generate SKU for Legacy Product" button in the QR code dialog.

---

## 🎯 How It Works

### **Creating a New Product:**

1. User fills product form (title, description, category, price, etc.)
2. User taps "Save" or "Create"
3. Edge function automatically generates:
   - **ASIN** (UUID) - Unique product identifier
   - **SKU** (UUID) - Unique inventory identifier
   - **QR Data** (JSON with all product details)
4. Product saved with all identifiers
5. User can immediately view and scan QR code

### **Legacy Product (No SKU):**

1. User opens old product (created before auto-SKU)
2. Taps QR Code icon
3. Sees **"Legacy Product (No SKU)"** message
4. Taps "Generate SKU for Legacy Product"
5. Edge function generates SKU and QR data
6. Product updated with new identifiers

---

## 📱 User Interface

### **No SKU Yet (Amber Alert Box)**

```
┌─────────────────────────────────────┐
│     ⚠️ Product QR Code              │
├─────────────────────────────────────┤
│                                     │
│         [ℹ️ Info Icon]              │
│                                     │
│  This product does not have a      │
│  SKU yet                            │
│                                     │
│  Generate a unique SKU and QR code │
│  with all product data             │
│                                     │
│  [🔳 Generate SKU & QR Code]       │
│                                     │
└─────────────────────────────────────┘
```

### **SKU Exists (Green Data Box)**

```
┌─────────────────────────────────────┐
│     📱 Product QR Code              │
├─────────────────────────────────────┤
│                                     │
│       [QR Code Image]               │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ SKU                           │ │
│  │ 6ba7b810-9dad-11d1-80b4-...  │ │
│  └───────────────────────────────┘ │
│                                     │
│  QR Contains Full Product Data:    │
│  • Title: Wireless Headphones      │
│  • Category: Electronics           │
│  • Subcategory: Headphones         │
│  • Brand: AudioTech                │
│  • Price: 79.99                    │
│  • Quantity: 150                   │
│  • Images: 3 URLs                  │
│  • Attributes: 5 fields            │
│                                     │
│  [Copy] [Close]                    │
└─────────────────────────────────────┘
```

---

## 🔧 Technical Implementation

### **1. Flutter UI** (`lib/pages/product/product.dart`)

**Check for SKU:**

```dart
final hasSku = product.sku != null && product.sku!.isNotEmpty;

if (!hasSku) {
  // Show generate button
  ElevatedButton.icon(
    onPressed: () => _generateSKU(context),
    icon: const Icon(Icons.qr_code_generator),
    label: const Text('Generate SKU & QR Code'),
  );
} else {
  // Show QR code and data
  QrImageView(data: qrData, ...);
}
```

**Generate SKU Method:**

```dart
Future<void> _generateSKU(BuildContext context) async {
  // Show loading indicator
  showDialog(...);

  try {
    // Call edge function
    final response = await supabase.functions.invoke(
      'manage-product',
      body: {
        'action': 'update',
        'asin': product.asin,
        'data': {
          'title': product.title,
          'description': product.description,
          'category': product.category,
          'subcategory': product.subcategory,
          'selling_price': product.sellingPrice,
          'quantity': product.quantity,
          'attributes': product.attributes,
          // ... all product data
        },
      },
    );

    // Show success dialog with new SKU
    final updatedSku = response.data?['sku'];
    // Display new SKU
  } catch (e) {
    // Show error
  }
}
```

---

### **2. Edge Function** (`supabase/functions/manage-product/index.ts`)

**Update Action - Generate SKU if Missing:**

```typescript
case "update": {
  // Get existing product
  const { data: existingProduct } = await supabase
    .from("products")
    .select("sku, qr_data")
    .eq("asin", asin)
    .eq("seller_id", user.id)
    .single();

  let sku = existingProduct?.sku;
  let qrDataString = existingProduct?.qr_data;

  // Generate SKU if product doesn't have one
  if (!sku) {
    const generatedSku = crypto.randomUUID();
    sku = generatedSku;

    // Generate full QR data with ALL product details
    const qrData = {
      // Core identifiers
      asin: asin,
      sku: generatedSku,

      // Basic product info
      title: data.title,
      description: data.description,
      brand: data.brand,

      // Category hierarchy
      category: data.category,
      subcategory: data.subcategory,

      // Pricing
      selling_price: data.selling_price,
      currency: data.currency,

      // Inventory
      quantity: data.quantity,

      // Attributes
      attributes: data.attributes,

      // ... all other fields
    };
    qrDataString = JSON.stringify(qrData);

    // Add to update data
    data.sku = sku;
    data.qr_data = qrDataString;
  }

  // Update product
  const { data: updatedProduct } = await supabase
    .from("products")
    .update({ ...data, updated_at: new Date().toISOString() })
    .eq("asin", asin)
    .eq("seller_id", user.id)
    .select()
    .single();

  return {
    success: true,
    message: sku === existingProduct?.sku
      ? "Product updated successfully"
      : "SKU generated successfully",
    data: updatedProduct,
    sku: sku,
    qr_data: qrDataString,
  };
}
```

---

## 📦 QR Code Data Structure

When generated, the QR code contains:

```json
{
  "asin": "550e8400-e29b-41d4-a716-446655440000",
  "sku": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",

  "title": "Wireless Bluetooth Headphones",
  "description": "Premium noise-cancelling...",
  "brand": "AudioTech",

  "category": "Electronics",
  "subcategory": "Headphones",
  "product_type": "Wireless Headphones",

  "selling_price": 79.99,
  "list_price": 99.99,
  "currency": "USD",

  "quantity": 150,
  "fulfillment_channel": "FBM",
  "availability_status": "In Stock",

  "attributes": {
    "color": "Black",
    "connectivity": "Bluetooth 5.0",
    "battery_life": "30 hours"
  },

  "images": [...],
  "variations": [...],
  "compliance": {...},

  "status": "Active",
  "language": "en_US",
  "bullet_points": [...]
}
```

---

## 🚀 Deployment

### **1. Deploy Edge Function**

```powershell
cd c:\Users\yn098\aurora\A-U-R-O-R-A\supabase\functions
supabase functions deploy manage-product --project-ref ofovfxsfazlwvcakpuer
```

### **2. Test in App**

**Test Case 1: Product Without SKU**

1. Open product without SKU
2. Tap QR Code icon
3. See amber alert with "Generate SKU & QR Code" button
4. Tap button
5. See loading indicator
6. See success dialog with new SKU
7. Open QR code again - see full QR code with data

**Test Case 2: Product With SKU**

1. Open product with existing SKU
2. Tap QR Code icon
3. See QR code immediately
4. See SKU displayed
5. See preview of all data in QR code

---

## 🔄 Flow Diagram

```
┌─────────────────────┐
│  Product Details    │
│  (No SKU)           │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Tap QR Code Icon   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Dialog: No SKU     │
│  - Info message     │
│  - Generate button  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Tap Generate       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Loading Indicator  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Edge Function:     │
│  1. Check existing  │
│  2. Generate UUID   │
│  3. Build QR data   │
│  4. Save to DB      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Success Dialog     │
│  - Show new SKU     │
│  - Confirmation     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Product Updated    │
│  - SKU saved        │
│  - QR data saved    │
│  - Ready to scan    │
└─────────────────────┘
```

---

## ✅ Features

| Feature                  | Description                       |
| ------------------------ | --------------------------------- |
| **On-Demand Generation** | Generate SKU only when needed     |
| **UUID Format**          | Standard UUID v4 format           |
| **Full Data QR**         | All product details in QR code    |
| **Loading State**        | Clear loading indicator           |
| **Success Feedback**     | Confirmation dialog with new SKU  |
| **Error Handling**       | Graceful error messages           |
| **Idempotent**           | Won't regenerate if SKU exists    |
| **Secure**               | User can only update own products |

---

## 🎨 UI States

### **State 1: No SKU**

- Amber alert box
- Info icon
- Clear call-to-action button
- No QR code shown

### **State 2: Generating**

- Full-screen loading overlay
- Cannot interact with dialog
- Clear visual feedback

### **State 3: Success**

- Green success dialog
- New SKU displayed
- Option to view QR code

### **State 4: Has SKU**

- QR code image
- SKU displayed
- Data preview
- Copy button

---

## 📝 Summary

| Scenario                 | Behavior                                |
| ------------------------ | --------------------------------------- |
| **New Product**          | SKU generated automatically on creation |
| **Old Product (No SKU)** | "Generate SKU" button shown             |
| **Product With SKU**     | QR code shown immediately               |
| **Generate Clicked**     | Edge function creates SKU + QR data     |
| **Error**                | Error message shown, no changes         |

**SKU generation is now fully automated and on-demand!** 🎉

Products without SKUs can generate them instantly with all product data encoded in the QR code.
