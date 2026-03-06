# 🧪 Aurora Edge Functions - Testing Guide

## 📋 Quick Start

### 1. Deploy All Functions
```powershell
# Run the deployment script
cd c:\Users\yn098\aurora\A-U-R-O-R-A
.\supabase\deploy-all-functions.ps1
```

### 2. Set Service Role Key
Get your key from: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/settings/api

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-key-here
```

---

## 🧪 Testing Each Function

### 1️⃣ Create Product

**Edge Function:** `create-product`  
**Flutter Method:** `SupabaseProvider.createProduct()`

**Test via cURL:**
```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/create-product' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Test Product",
    "description": "A test product description",
    "brand": "Test Brand",
    "price": 29.99,
    "quantity": 100,
    "status": "active",
    "category": "Electronics",
    "subcategory": "Accessories",
    "sellerId": "your-seller-uuid",
    "currency": "USD"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Product created successfully",
  "product": { ... },
  "asin": "ASN-..."
}
```

---

### 2️⃣ Update Product

**Edge Function:** `update-product`  
**Flutter Method:** `SupabaseProvider.updateProduct()`

**Test via cURL:**
```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/update-product' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "asin": "ASN-1234567890",
    "sellerId": "your-seller-uuid",
    "updates": {
      "price": 24.99,
      "quantity": 150,
      "status": "active"
    }
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Product updated successfully",
  "product": { ... }
}
```

---

### 3️⃣ Delete Product

**Edge Function:** `delete-product`  
**Flutter Method:** `SupabaseProvider.deleteProduct()`

**Test via cURL:**
```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/delete-product' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "asin": "ASN-1234567890",
    "sellerId": "your-seller-uuid"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Product deleted successfully",
  "deletedImages": 3
}
```

---

### 4️⃣ Search Products

**Edge Function:** `search-products`  
**Flutter Method:** `SupabaseProvider.searchProducts()`

**Test via cURL:**
```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/search-products' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "query": "wireless headphones",
    "category": "Electronics",
    "minPrice": 10,
    "maxPrice": 100,
    "sellerId": "your-seller-uuid",
    "limit": 20,
    "offset": 0
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "products": [...],
  "count": 15,
  "limit": 20,
  "offset": 0
}
```

---

### 5️⃣ Find Nearby Factories ⭐ NEW

**Edge Function:** `find-nearby-factories`  
**Flutter Method:** `SupabaseProvider.findNearbyFactories()`  
**UI Page:** `FactoryDiscoveryPage`

**Test via cURL:**
```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/find-nearby-factories' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "latitude": 51.5074,
    "longitude": -0.1278,
    "radius": 50,
    "limit": 20
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "factories": [
    {
      "user_id": "factory-uuid",
      "full_name": "ABC Manufacturing",
      "location": "London, UK",
      "latitude": 51.5074,
      "longitude": -0.1278,
      "distance_km": 2.5,
      "is_verified": true,
      "wholesale_discount": 15,
      "min_order_quantity": 10,
      "product_count": 45,
      "average_rating": 4.5
    }
  ],
  "count": 1
}
```

---

### 6️⃣ Request Factory Connection ⭐ NEW

**Edge Function:** `request-factory-connection`  
**Flutter Method:** `SupabaseProvider.requestFactoryConnection()`  
**UI Page:** `FactoryProfilePage`

**Test via cURL:**
```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/request-factory-connection' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "factoryId": "factory-uuid",
    "notes": "Interested in wholesale partnership for electronics"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Connection request sent",
  "connection": {
    "id": "connection-uuid",
    "factory_id": "factory-uuid",
    "seller_id": "seller-uuid",
    "status": "pending",
    "requested_at": "2026-03-05T12:00:00Z"
  }
}
```

---

### 7️⃣ Rate Factory ⭐ NEW

**Edge Function:** `rate-factory`  
**Flutter Method:** `SupabaseProvider.rateFactory()`  
**UI Page:** `FactoryProfilePage` (rating dialog)

**Test via cURL:**
```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/rate-factory' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "factoryId": "factory-uuid",
    "rating": 5,
    "deliveryRating": 5,
    "qualityRating": 5,
    "communicationRating": 4,
    "review": "Excellent factory! Fast delivery and great quality products."
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Rating submitted successfully",
  "rating": {
    "id": "rating-uuid",
    "factory_id": "factory-uuid",
    "seller_id": "seller-uuid",
    "rating": 5,
    "review": "Excellent factory! Fast delivery and great quality products.",
    "delivery_rating": 5,
    "quality_rating": 5,
    "communication_rating": 4
  }
}
```

---

### 8️⃣ Manage Product

**Edge Function:** `manage-product`  
**Flutter Method:** Various product management operations

**Test via cURL:**
```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/manage-product' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "bulk_update",
    "asins": ["ASN-1", "ASN-2"],
    "updates": {
      "status": "inactive"
    }
  }'
```

---

### 9️⃣ Create Order

**Edge Function:** `create-order`  
**Flutter Method:** `SupabaseProvider.createOrder()`

**Test via cURL:**
```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/create-order' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "items": [
      {
        "asin": "ASN-123",
        "quantity": 2,
        "price": 29.99
      }
    ],
    "shippingAddress": {
      "street": "123 Main St",
      "city": "London",
      "postalCode": "SW1A 1AA",
      "country": "UK"
    }
  }'
```

---

### 🔟 Upload Image

**Edge Function:** `upload-image`  
**Flutter Method:** `SupabaseProvider.uploadProductImage()`

**Test via cURL:**
```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/upload-image' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "base64": "data:image/jpeg;base64,/9j/4AAQSkZJRg...",
    "folder": "product-images/seller-uuid/ASN-123"
  }'
```

---

## 🐛 Debugging Tips

### 1. Check Function Logs
```bash
# Real-time logs for specific function
supabase functions logs --function create-product

# Last 50 lines
supabase functions logs --function create-product --limit 50

# Follow logs (tail -f)
supabase functions logs --function create-product --follow
```

### 2. Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `401 Unauthorized` | Missing/invalid JWT | Ensure user is logged in |
| `400 Bad Request` | Invalid input data | Check required fields |
| `500 Internal Error` | Function code error | Check logs |
| `CORS error` | Missing CORS headers | Check function imports |

### 3. Test in Flutter App

```dart
// Example: Test create product
final supabase = context.read<SupabaseProvider>();

final result = await supabase.createProduct(
  title: 'Test Product',
  description: 'Test Description',
  brand: 'Test Brand',
  price: 29.99,
  quantity: 100,
  category: 'Electronics',
  sellerId: supabase.currentUser!.id,
);

if (result.success) {
  print('✅ Product created: ${result.data?['asin']}');
} else {
  print('❌ Error: ${result.message}');
}
```

---

## ✅ Testing Checklist

| Function | Deployed | Auth Works | Input Validation | Returns Data | Tested |
|----------|----------|------------|------------------|--------------|--------|
| `create-product` | ☐ | ☐ | ☐ | ☐ | ☐ |
| `update-product` | ☐ | ☐ | ☐ | ☐ | ☐ |
| `delete-product` | ☐ | ☐ | ☐ | ☐ | ☐ |
| `search-products` | ☐ | ☐ | ☐ | ☐ | ☐ |
| `find-nearby-factories` | ☐ | ☐ | ☐ | ☐ | ☐ |
| `request-factory-connection` | ☐ | ☐ | ☐ | ☐ | ☐ |
| `rate-factory` | ☐ | ☐ | ☐ | ☐ | ☐ |
| `manage-product` | ☐ | ☐ | ☐ | ☐ | ☐ |
| `create-order` | ☐ | ☐ | ☐ | ☐ | ☐ |
| `upload-image` | ☐ | ☐ | ☐ | ☐ | ☐ |

---

## 📊 Performance Benchmarks

| Metric | Target | Acceptable |
|--------|--------|------------|
| Response Time | < 500ms | < 1000ms |
| Error Rate | < 1% | < 5% |
| Success Rate | > 99% | > 95% |

---

## 🎯 Factory System Test Flow

### Complete User Journey

1. **As Factory:**
   ```
   - Update factory settings (location, discount)
   - Wait for connection requests
   - Accept/decline requests
   - View ratings
   ```

2. **As Seller:**
   ```
   - Open Factory Discovery
   - Grant location permission
   - Search nearby factories
   - View factory profile
   - Send connection request
   - Wait for acceptance
   - Rate factory after order
   ```

---

**Happy Testing!** 🚀
