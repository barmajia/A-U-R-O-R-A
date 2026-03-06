# Local Database Updates for Multi-Role System

## Overview

This document describes the updates made to the local SQLite databases (`ProductsDB` and `SellerDB`) to support the Aurora multi-role system (factories, middlemen, customers).

---

## 1. ProductsDB Updates (`lib/backend/productsdb.dart`)

### New Columns Added

The following columns were added to the local `products` table:

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `allow_chat` | INTEGER | 1 | Enable/disable chat for this product |
| `qr_data` | TEXT | NULL | QR code data for product |
| `brand_id` | TEXT | NULL | Reference to predefined brand |
| `is_local_brand` | INTEGER | 0 | Flag for custom/local brands |
| `color_hex` | TEXT | NULL | Product color (hex code) |
| `category` | TEXT | NULL | Product category |
| `subcategory` | TEXT | NULL | Product subcategory |
| `attributes_json` | TEXT | NULL | Additional product attributes (JSON) |

### Updated Methods

#### `_createTables()`
Updated CREATE TABLE statement to include all new columns.

#### `addProduct(AmazonProduct product)`
- Now inserts all new fields
- Maps `allowChat`, `qrData`, `brandId`, `isLocalBrand`, `colorHex`, `category`, `subcategory`, `attributes`

#### `updateProduct(AmazonProduct product)`
- Now updates all new fields
- Maintains sync status tracking

#### `syncProductToSupabase(AmazonProduct product)`
- Sends all new fields to Supabase
- Ensures cloud and local DB parity

#### `syncProductsToSupabase(List<AmazonProduct> products)`
- Batch sync includes all new fields

#### `_rowToProduct(Map<String, dynamic> row)`
- Maps all new database columns to `AmazonProduct` properties
- Converts INTEGER booleans to Dart bools

---

## 2. SellerDB Updates (`lib/backend/sellerdb.dart`)

### New Columns Added

The following columns were added to the local `sellers` table:

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `latitude` | REAL | NULL | Geographic latitude |
| `longitude` | REAL | NULL | Geographic longitude |
| `is_factory` | INTEGER | 0 | Flag for factory sellers |
| `company_name` | TEXT | NULL | Company/business name |
| `business_license` | TEXT | NULL | Business license number |
| `min_order_quantity` | INTEGER | NULL | Minimum order quantity |
| `wholesale_discount` | REAL | NULL | Wholesale discount percentage |
| `accepts_returns` | INTEGER | 0 | Whether returns are accepted |
| `production_capacity` | TEXT | NULL | Production capacity description |
| `verified_at` | TEXT | NULL | Factory verification timestamp |

### Removed Columns

| Column | Reason |
|--------|--------|
| `password` | **Security**: Passwords should never be stored in local DB. Use Supabase Auth sessions instead. |

### Removed Methods

| Method | Reason |
|--------|--------|
| `getCurrentSellerCredentials()` | **Security Risk**: Returned email and password. This is dangerous and unnecessary. |
| `getSellerByEmail()` | Redundant - use `getSellerByUserId()` instead |

### Updated Methods

#### `init()`
- Updated CREATE TABLE statement
- Removed `password` column
- Added all factory/role-specific fields

#### `addSeller(Map<String, dynamic> seller)`
- Removed password parameter
- Added latitude, longitude, and factory-specific fields
- No longer stores sensitive credentials

#### `updateSeller(String userId, Map<String, dynamic> data)`
- Now updates location and factory fields
- Supports full profile updates

#### New: `updateSellerLocation(String userId, double latitude, double longitude)`
- Dedicated method for location updates
- Useful for profile editing and geolocation features

---

## 3. AmazonProduct Model Updates (`lib/models/product.dart`)

### New Properties

```dart
// Multi-Role System Fields
final bool? allowChat;        // Enable chat for product
final String? qrData;         // QR code data
final String? colorHex;       // Color hex code
final String? category;       // Product category
final String? subcategory;    // Product subcategory
```

### Updated Methods

#### `fromJson(Map<String, dynamic> json)`
- Maps `allow_chat`, `qr_data`, `color_hex`, `category`, `subcategory`

#### `toJson()`
- Serializes all new fields for API/Supabase

---

## 4. Migration Guide

### For Existing Installations

Users with existing local databases will need to migrate. The database version system in `ProductsDB` supports migrations.

#### Example Migration Code

```dart
void _migrateDatabase(int oldVersion) {
  db.execute('BEGIN TRANSACTION');
  try {
    if (oldVersion < 2) {
      // Add new columns to products table
      db.execute('ALTER TABLE products ADD COLUMN allow_chat INTEGER DEFAULT 1;');
      db.execute('ALTER TABLE products ADD COLUMN qr_data TEXT;');
      db.execute('ALTER TABLE products ADD COLUMN brand_id TEXT;');
      db.execute('ALTER TABLE products ADD COLUMN is_local_brand INTEGER DEFAULT 0;');
      db.execute('ALTER TABLE products ADD COLUMN color_hex TEXT;');
      db.execute('ALTER TABLE products ADD COLUMN category TEXT;');
      db.execute('ALTER TABLE products ADD COLUMN subcategory TEXT;');
      db.execute('ALTER TABLE products ADD COLUMN attributes_json TEXT;');
    }
    
    db.execute('UPDATE db_version SET version = ?', [_databaseVersion]);
    db.execute('COMMIT');
  } catch (e) {
    db.execute('ROLLBACK');
    rethrow;
  }
}
```

### For SellerDB

Since `SellerDB` doesn't have version tracking, you may need to:

1. **Option A**: Delete and recreate the database (loses local data)
   ```dart
   final dir = await getApplicationDocumentsDirectory();
   final dbPath = path.join(dir.path, 'sellers.db');
   await File(dbPath).delete();
   ```

2. **Option B**: Add version tracking and run ALTER TABLE statements (preserves data)

---

## 5. Security Considerations

### Password Storage

**CRITICAL**: Passwords are no longer stored in the local database. This is a security improvement.

**Before (❌ Unsafe):**
```dart
'password': seller['password'],  // Stored in plain text!
```

**After (✅ Safe):**
- Passwords only handled by Supabase Auth
- Local DB stores profile data only
- Use `flutter_secure_storage` for session tokens if needed

### What Changed

| Before | After |
|--------|-------|
| Password stored in SQLite | No password storage |
| `getCurrentSellerCredentials()` returns password | Method removed |
| Plain text in database | N/A |

---

## 6. Usage Examples

### Adding a Product with New Fields

```dart
final product = AmazonProduct(
  asin: 'B08XYZ123',
  title: 'Wireless Headphones',
  category: 'Electronics',
  subcategory: 'Audio',
  colorHex: '#000000',
  allowChat: true,
  qrData: 'https://example.com/product/B08XYZ123',
  brandId: 'sony-001',
  isLocalBrand: false,
  // ... other fields
);

await productsDb.addProduct(product);
```

### Updating Seller Location

```dart
await sellerDb.updateSellerLocation(
  userId: 'user-123',
  latitude: 40.7128,
  longitude: -74.0060,
);
```

### Adding a Factory Seller

```dart
await sellerDb.addSeller({
  'user_id': 'user-123',
  'firstname': 'John',
  'full_name': 'John Factory',
  'email': 'john@factory.com',
  'location': 'New York, USA',
  'phone': '+1234567890',
  'is_factory': 1,
  'company_name': 'John Manufacturing',
  'latitude': 40.7128,
  'longitude': -74.0060,
  'min_order_quantity': 100,
  'wholesale_discount': 15.0,
  // ... other fields
});
```

---

## 7. Testing Checklist

- [ ] Create product with all new fields
- [ ] Update product with new fields
- [ ] Sync product to Supabase with new fields
- [ ] Retrieve product and verify all fields
- [ ] Create seller with factory fields
- [ ] Update seller location
- [ ] Verify password is not stored
- [ ] Test migration from old database version
- [ ] Verify `getCurrentSellerCredentials()` is removed
- [ ] Test batch sync with new fields

---

## 8. Next Steps

1. **Update UI** - Add inputs for new fields in product/seller forms
2. **Add Factory DB** - Create separate `FactoryDB` for factory discovery caching
3. **Add Middleman DB** - Create `MiddlemanDB` for middleman profiles
4. **Add User DB** - Create `UserDB` for caching user roles
5. **Implement Migration** - Add proper migration logic for existing users

---

## 9. Related Files

- `lib/backend/productsdb.dart` - Updated
- `lib/backend/sellerdb.dart` - Updated
- `lib/models/product.dart` - Updated
- `lib/services/supabase.dart` - Updated (multi-role system)

---

## 10. Database Schema Reference

### Products Table (Final)

```sql
CREATE TABLE products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  asin TEXT UNIQUE,
  sku TEXT,
  seller_id TEXT,
  marketplace_id TEXT,
  product_type TEXT,
  status TEXT,
  
  -- JSON Fields
  identifiers_json TEXT,
  bullet_points_json TEXT,
  images_json TEXT,
  variations_json TEXT,
  compliance_json TEXT,
  
  -- Core Fields
  title TEXT,
  description TEXT,
  brand TEXT,
  manufacturer TEXT,
  language TEXT,
  currency TEXT,
  list_price REAL,
  selling_price REAL,
  business_price REAL,
  tax_code TEXT,
  quantity INTEGER,
  fulfillment_channel TEXT,
  availability_status TEXT,
  lead_time_to_ship TEXT,
  
  -- Multi-Role Fields (NEW)
  allow_chat INTEGER DEFAULT 1,
  qr_data TEXT,
  brand_id TEXT,
  is_local_brand INTEGER DEFAULT 0,
  color_hex TEXT,
  category TEXT,
  subcategory TEXT,
  attributes_json TEXT,
  
  -- Metadata
  created_at TEXT,
  updated_at TEXT,
  version TEXT,
  synced_at TEXT,
  is_synced INTEGER DEFAULT 0
);
```

### Sellers Table (Final)

```sql
CREATE TABLE sellers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL UNIQUE,
  firstname TEXT NOT NULL,
  secoundname TEXT NOT NULL,
  thirdname TEXT NOT NULL,
  forthname TEXT NOT NULL,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  location TEXT NOT NULL,
  phone TEXT NOT NULL,
  currency TEXT,
  account_type TEXT DEFAULT 'seller',
  is_verified INTEGER DEFAULT 0,
  
  -- Multi-Role Fields (NEW)
  latitude REAL,
  longitude REAL,
  is_factory INTEGER DEFAULT 0,
  company_name TEXT,
  business_license TEXT,
  min_order_quantity INTEGER,
  wholesale_discount REAL,
  accepts_returns INTEGER DEFAULT 0,
  production_capacity TEXT,
  verified_at TEXT,
  
  created_at TEXT,
  updated_at TEXT
);
```

---

**Status**: ✅ Complete  
**Version**: 1.0  
**Last Updated**: 2026-03-06
