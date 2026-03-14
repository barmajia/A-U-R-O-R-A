# 🔗 QR Code with Product Link - Implementation Guide

## ✅ COMPLETE! QR Code Generated in Flutter App

The QR code is now **generated asynchronously in the Flutter app** after product creation, containing a **direct link** to access the product using **seller UUID** and **product ASIN**.

---

## 🎯 Key Features

### **1. Automatic SKU & ASIN Generation**
- **Server-side**: Edge function generates UUID for both ASIN and SKU
- **During creation**: No user input required
- **Instant**: Available immediately after product save

### **2. QR Code Generated in Flutter App**
- **Asynchronous**: Runs in background after product creation
- **Non-blocking**: Doesn't delay UI or show loading
- **Contains product link**: URL with seller_id and asin parameters

### **3. Product Link Format**
```
https://aurora-app.com/product?seller={seller_id}&asin={asin}
```

Example:
```
https://aurora-app.com/product?seller=550e8400-e29b-41d4-a716-446655440000&asin=6ba7b810-9dad-11d1-80b4-00c04fd430c8
```

---

## 📦 QR Code Data Structure

```json
{
  "asin": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
  "seller_id": "550e8400-e29b-41d4-a716-446655440000",
  "url": "https://aurora-app.com/product?seller=550e8400-e29b-41d4-a716-446655440000&asin=6ba7b810-9dad-11d1-80b4-00c04fd430c8",
  "title": "Wireless Bluetooth Headphones",
  "brand": "AudioTech",
  "price": 79.99,
  "currency": "USD"
}
```

**Key Fields:**
- `asin` - Product unique identifier
- `seller_id` - Seller's UUID (for multi-vendor marketplace)
- `url` - Direct link to product page
- `title`, `brand`, `price` - Basic product info (for offline scanning)

---

## 🔄 Flow Diagram

```
┌─────────────────────┐
│  User Creates       │
│  Product            │
│  (Fill Form)        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Tap Save           │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Edge Function:     │
│  - Generate ASIN    │
│  - Generate SKU     │
│  - Save Product     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Response:          │
│  - ASIN             │
│  - SKU              │
│  - Seller ID        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Show Success       │
│  (Don't wait)       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Async: Generate    │
│  QR Code in Flutter │
│  - Build URL        │
│  - Create QR data   │
│  - Save to DB       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  QR Code Ready      │
│  - Scan to get URL  │
│  - Access product   │
│    via link         │
└─────────────────────┘
```

---

## 🔧 Technical Implementation

### **1. Edge Function** (`supabase/functions/manage-product/index.ts`)

**Simplified - No QR Generation:**
```typescript
case "create": {
  // Generate ASIN and SKU
  const generatedAsin = crypto.randomUUID();
  const generatedSku = crypto.randomUUID();

  const productData = {
    ...data,
    asin: generatedAsin,
    sku: generatedSku,
    seller_id: user.id,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };

  // Insert to database
  const { data: newProduct } = await supabase
    .from("products")
    .insert(productData)
    .select()
    .single();

  // Return ASIN, SKU, and seller_id
  return {
    success: true,
    data: newProduct,
    asin: generatedAsin,
    sku: generatedSku,
    seller_id: user.id,
  };
}
```

---

### **2. Flutter App** (`lib/pages/product/product_form_screen.dart`)

**Add Import:**
```dart
import 'dart:convert'; // For jsonEncode
```

**Async QR Generation Method:**
```dart
Future<void> _generateQRCodeAsync(
  BuildContext context,
  String asin,
  String sellerId,
) async {
  // Run asynchronously without blocking UI
  Future.delayed(Duration.zero, () async {
    try {
      // Build product URL with seller UUID and ASIN
      final productUrl = 'https://aurora-app.com/product?seller=$sellerId&asin=$asin';
      
      // Create QR data with link and basic product info
      final qrData = jsonEncode({
        'asin': asin,
        'seller_id': sellerId,
        'url': productUrl,
        'title': _titleController.text.trim(),
        'brand': _selectedBrand?.name ?? _customBrandController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'currency': _accountCurrency,
      });
      
      // Save QR data to database asynchronously
      final supabaseProvider = context.read<SupabaseProvider>();
      await supabaseProvider.client
          .from('products')
          .update({'qr_data': qrData})
          .eq('asin', asin);
      
      debugPrint('QR code generated for product: $asin');
      debugPrint('Product URL: $productUrl');
    } catch (e) {
      debugPrint('Error generating QR code: $e');
      // Don't show error - non-critical
    }
  });
}
```

**Call After Product Creation:**
```dart
if (result.success && widget.product == null) {
  final finalAsin = result.data?['asin'] as String?;
  final sellerId = result.data?['seller_id'] as String?;
  
  if (finalAsin != null) {
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Product created! ASIN: $finalAsin')),
    );
    
    // Generate QR code asynchronously
    _generateQRCodeAsync(
      context,
      finalAsin,
      sellerId ?? supabaseProvider.currentUser!.id,
    );
  }
}
```

---

### **3. Product Model** (`lib/models/aurora_product.dart`)

**Generate QR Data with URL:**
```dart
String generateQRData() {
  // Build product URL with seller UUID and ASIN
  final productUrl = 'https://aurora-app.com/product?seller=${sellerId ?? ''}&asin=${asin ?? ''}';
  
  return jsonEncode({
    // Core identifiers
    'asin': asin ?? '',
    'sku': sku ?? '',
    'seller_id': sellerId ?? '',
    
    // Product URL for quick access
    'url': productUrl,
    
    // Basic product info (for offline scanning)
    'title': title,
    'brand': brand,
    'selling_price': sellingPrice ?? listPrice,
    'currency': currency ?? 'USD',
    'quantity': quantity,
  });
}
```

---

## 📱 Usage

### **Creating a Product:**

1. Fill product form (title, brand, price, category, etc.)
2. Tap **Save**
3. Product created with ASIN + SKU (server-generated)
4. Success message shows ASIN
5. **QR code generated asynchronously** in background
6. Navigate away (no waiting needed)

### **Viewing QR Code:**

1. Open product details
2. Tap **QR Code icon** (top right)
3. QR code displays with:
   - Product URL (clickable/link)
   - Seller ID
   - ASIN
   - Basic product info

### **Scanning QR Code:**

**Option 1: QR Scanner App**
- Scan → Get JSON data
- Extract `url` field
- Open URL in browser/app

**Option 2: In-App Scanner**
```dart
// When scanning QR code
final data = jsonDecode(scannedData);
final productUrl = data['url'];
final asin = data['asin'];
final sellerId = data['seller_id'];

// Navigate to product
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ProductPage(
      asin: asin,
      sellerId: sellerId,
    ),
  ),
);
```

---

## 🗄️ Database Schema

**Products Table:**
```sql
CREATE TABLE products (
  id UUID PRIMARY KEY,
  asin UUID UNIQUE NOT NULL,          -- Server-generated
  sku UUID UNIQUE NOT NULL,           -- Server-generated
  seller_id UUID NOT NULL,            -- Seller's UUID
  qr_data TEXT,                       -- JSON with URL and info
  title TEXT,
  brand TEXT,
  price DECIMAL,
  -- ... other fields
  UNIQUE(asin, seller_id)
);
```

---

## ✅ Benefits

| Benefit | Description |
|---------|-------------|
| **Fast Creation** | QR generation doesn't block UI |
| **Direct Link** | URL contains seller_id + asin for instant access |
| **Multi-Vendor** | Seller UUID ensures product isolation |
| **Scalable** | Async generation handles high volume |
| **Non-Critical** | Product works even if QR fails |
| **Trackable** | URL can include analytics params |

---

## 🔐 Security Notes

**URL Parameters:**
- `seller_id` - Identifies product owner (UUID)
- `asin` - Product identifier (UUID)

**RLS Policies:**
```sql
-- Sellers can only see their own products
CREATE POLICY "Sellers can only see their own products"
ON products
FOR SELECT
USING (seller_id = auth.uid());

-- URL access should validate seller ownership
```

**When accessing via URL:**
1. Extract `seller_id` and `asin` from URL
2. Validate current user matches `seller_id` OR has public access
3. Fetch product with both parameters
4. Prevent unauthorized access

---

## 🧪 Testing

### **Test Product Creation:**

1. Create new product
2. Check console logs:
   ```
   Product created! ASIN: xxx-xxx-xxx
   QR code generated for product: xxx-xxx-xxx
   Product URL: https://aurora-app.com/product?seller=...&asin=...
   ```
3. Verify database has `qr_data` field populated
4. Open product details → View QR code

### **Test QR Scanning:**

1. Scan QR code with any scanner
2. Verify JSON contains:
   - `url` field with correct format
   - `seller_id` matches creator
   - `asin` matches product
3. Open URL → Should navigate to product page

---

## 📝 Summary

| Aspect | Implementation |
|--------|---------------|
| **ASIN/SKU** | Server-generated (UUID) |
| **QR Code** | Flutter app (async) |
| **QR Content** | URL + seller_id + asin + basic info |
| **URL Format** | `https://aurora-app.com/product?seller={id}&asin={id}` |
| **Storage** | `products.qr_data` column |
| **Timing** | After product save (non-blocking) |
| **Error Handling** | Silent fail (non-critical) |

**QR codes now contain direct product links with seller UUID and ASIN!** 🎉

Generated asynchronously in Flutter app without blocking the UI.
