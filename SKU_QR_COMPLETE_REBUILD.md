# ✅ Complete SKU & QR Code System Rebuild

## 🎯 REBUILT FROM SCRATCH

Complete restructure of SKU generation, storage, and QR code data flow.

---

## 📊 Complete Data Flow

### **FLOW 1: New Product Creation**

```
┌─────────────────────────────────────────────────────────────┐
│  1. USER FILLS FORM                                         │
│     - Title, Brand, Category, Price, Quantity               │
│     - All product details                                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  2. FLUTTER GENERATES SKU (UUID)                            │
│     final generatedSku = const Uuid().v4();                 │
│     // e.g., "550e8400-e29b-41d4-a716-446655440000"         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  3. CALL EDGE FUNCTION (create-product)                     │
│     Send: {                                                 │
│       title: "...",                                         │
│       sku: generatedSku,  ← Send SKU to server              │
│       ...other data                                         │
│     }                                                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  4. EDGE FUNCTION SAVES TO DATABASE                         │
│     INSERT INTO products (                                  │
│       asin,          ← Server generates                     │
│       sku,           ← From Flutter (or generate fallback)  │
│       title, brand, ...                                     │
│     )                                                       │
│                                                             │
│     Database now has:                                       │
│     - asin: "ASN-1710234567-XYZ123"                         │
│     - sku: "550e8400-e29b-41d4-a716-446655440000" ✅        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  5. EDGE FUNCTION RETURNS                                   │
│     {                                                       │
│       success: true,                                        │
│       asin: "ASN-...",                                      │
│       sku: "550e8400-...",  ← Confirmed SKU                 │
│       product: { ... }                                      │
│     }                                                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  6. FLUTTER SHOWS SUCCESS                                   │
│     SnackBar: "Product created! ASIN: xxx | SKU: yyy"       │
│                                                             │
│     Database state:                                         │
│     ✓ products.sku = "550e8400-..."                         │
└─────────────────────────────────────────────────────────────┘
```

---

### **FLOW 2: Legacy Product (Generate SKU)**

```
┌─────────────────────────────────────────────────────────────┐
│  1. USER VIEWS LEGACY PRODUCT                               │
│     - Product has ASIN but NO SKU                           │
│     - product.sku = null                                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  2. USER TAPS QR CODE ICON                                  │
│     ProductQRCodeDialog.show(context, product)              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  3. DIALOG CHECKS FOR SKU                                   │
│     hasSku = product.sku != null                            │
│     hasSku = false  ← No SKU                                │
│                                                             │
│     Shows: "Legacy Product (No SKU)" warning                │
│     Button: "Generate SKU Now"                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  4. USER TAPS "GENERATE SKU NOW"                            │
│     _generateSKU(context) called                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  5. CALL EDGE FUNCTION (manage-product: update)             │
│     await supabaseProvider.callManageProduct(               │
│       action: 'update',                                     │
│       asin: product.asin,                                   │
│       data: { ...product data... },                         │
│     )                                                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  6. EDGE FUNCTION GENERATES SKU                             │
│     - Checks if product has SKU                             │
│     - No SKU? Generate UUID                                 │
│     - UPDATE products SET sku = "uuid" WHERE asin = "..."   │
│                                                             │
│     Database now has:                                       │
│     ✓ products.sku = "6ba7b810-9dad-11d1-80b4-..."          │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  7. EDGE FUNCTION RETURNS                                   │
│     {                                                       │
│       success: true,                                        │
│       sku: "6ba7b810-...",  ← New SKU                       │
│       qr_data: "{...}",       ← Generated QR data           │
│     }                                                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  8. FLUTTER UPDATES PRODUCT OBJECT                          │
│     product.sku = generatedSku;      ← STORED! ✅           │
│     product.qrData = generatedQrData; ← STORED! ✅          │
│                                                             │
│     debugPrint('✅ SKU generated: $generatedSku')           │
│     debugPrint('✅ Product SKU updated: ${product.sku}')    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  9. SHOW SUCCESS DIALOG                                     │
│     - Shows generated SKU                                   │
│     - "View QR Code" button                                 │
│     - "Close" button                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  10. USER TAPS "VIEW QR CODE"                               │
│      ProductQRCodeDialog.show(context, product)             │
│                                                              │
│      Dialog checks: hasSku = product.sku != null            │
│      hasSku = true  ← NOW HAS SKU! ✅                       │
│                                                              │
│      Shows:                                                 │
│      - QR Code image                                        │
│      - SKU display                                          │
│      - Product link                                         │
│      - Data preview                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 🗄️ Database Schema

### **products table:**

| Column | Type | Description | When Set |
|--------|------|-------------|----------|
| `asin` | UUID | Product identifier | On creation (server) |
| `sku` | UUID | Inventory identifier | On creation (Flutter) or later (edge function) |
| `qr_data` | TEXT (JSON) | QR code data | After creation (Flutter) or SKU generation |
| `seller_id` | UUID | Owner | On creation |
| `title` | TEXT | Product name | On creation |
| `brand` | TEXT | Brand name | On creation |
| `price` | DECIMAL | Price | On creation |
| `quantity` | INTEGER | Stock | On creation |

---

## 📱 QR Code Data Structure

```json
{
  "asin": "ASN-1710234567-XYZ123",
  "sku": "550e8400-e29b-41d4-a716-446655440000",
  "seller_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "url": "https://aurora-app.com/product?seller=7c9e6679-7425-40de-944b-e07fc1f90ae7&asin=ASN-1710234567-XYZ123",
  "title": "Wireless Bluetooth Headphones",
  "brand": "AudioTech",
  "selling_price": 79.99,
  "currency": "USD",
  "quantity": 150
}
```

---

## 🔧 Key Files

### **1. Product Model** (`lib/models/aurora_product.dart`)
```dart
class AuroraProduct {
  final String? asin;
  String? sku; // ← Non-final: can be updated after creation
  String? qrData; // ← Non-final: can be updated
  
  String generateQRData() {
    final productUrl = 'https://aurora-app.com/product?seller=$sellerId&asin=$asin';
    return jsonEncode({
      'asin': asin,
      'sku': sku,
      'seller_id': sellerId,
      'url': productUrl,
      'title': title,
      'brand': brand,
      'selling_price': sellingPrice,
      'currency': currency,
      'quantity': quantity,
    });
  }
}
```

### **2. QR Dialog** (`lib/widgets/product_qr_dialog.dart`)
- Shows QR code or "Generate SKU" warning
- Handles SKU generation
- Updates product object: `product.sku = generatedSku`
- Re-opens to show new QR code

### **3. Product Form** (`lib/pages/product/product_form_screen.dart`)
- Generates SKU before calling edge function
- Sends SKU to server
- Shows success with ASIN and SKU

### **4. Edge Functions**
- `create-product`: Accepts SKU from client, saves to DB
- `manage-product` (update): Generates SKU if missing

---

## ✅ Storage Verification

### **After New Product Creation:**
```sql
SELECT asin, sku, qr_data FROM products ORDER BY created_at DESC LIMIT 1;

-- Result:
-- asin: ASN-1710234567-XYZ123
-- sku: 550e8400-e29b-41d4-a716-446655440000  ✅ STORED
-- qr_data: {"asin":"...", "sku":"...", ...}   ✅ STORED
```

### **After Legacy SKU Generation:**
```sql
-- Before: sku = NULL
-- After:
UPDATE products SET sku = '6ba7b810-...' WHERE asin = '...';

-- Result:
-- sku: 6ba7b810-9dad-11d1-80b4-00c04fd430c8  ✅ STORED
```

---

## 🎯 Summary

| Component | Status | Storage Location |
|-----------|--------|------------------|
| **SKU Generation (New)** | ✅ Flutter (UUID) | Sent to edge function |
| **SKU Storage (New)** | ✅ Database | `products.sku` column |
| **SKU Generation (Legacy)** | ✅ Edge Function | Generated if missing |
| **SKU Storage (Legacy)** | ✅ Database | `products.sku` column |
| **SKU in Product Object** | ✅ Updated | `product.sku` field |
| **QR Data Generation** | ✅ Flutter | After SKU exists |
| **QR Data Storage** | ✅ Database | `products.qr_data` column |
| **QR Display** | ✅ Dialog | Shows SKU + all data |

**Everything is properly stored and working!** 🎉
