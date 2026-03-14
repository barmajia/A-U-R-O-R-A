# Fix QR Data Column Error

## Problem
```
PostgrestException(message: Could not find the 'qr_data' column of 'products' in the schema cache
```

The `qr_data` column is missing from your Supabase `products` table.

---

## Solution: Apply the Migration

### Step 1: Open Supabase Dashboard
1. Go to https://supabase.com
2. Select your Aurora project
3. Go to **SQL Editor** (left sidebar)

### Step 2: Run the Migration SQL

Copy and paste this SQL query:

```sql
-- Add qr_data column to products table
ALTER TABLE products
ADD COLUMN IF NOT EXISTS qr_data TEXT;

-- Add description
COMMENT ON COLUMN products.qr_data IS 'JSON-encoded QR code data containing ASIN, SKU, seller_id, URL, and product details';

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_products_qr_data ON products(qr_data) WHERE qr_data IS NOT NULL;
```

### Step 3: Click "Run" or press Ctrl+Enter

### Step 4: Verify the Column Was Added

Run this query to confirm:
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'products' AND column_name = 'qr_data';
```

You should see:
```
column_name | data_type | is_nullable
qr_data     | text      | YES
```

---

## What Was Fixed

### Files Updated:
1. ✅ `jo.sql` - Added `qr_data` column to schema
2. ✅ `atall.sql` - Added `qr_data` column to schema  
3. ✅ `supabase/migrations/007_add_qr_data_column.sql` - Created migration file

### What the Column Stores:
The `qr_data` column stores JSON-encoded data for QR codes:
```json
{
  "asin": "ASN-1773481423829-DM7C7RC18",
  "sku": "85b30146-3202-4165-bc4f-ab42cb81a902",
  "seller_id": "f1951125-909d-4e75-b4a4-5a6cc8e0fa33",
  "url": "https://aurora-app.com/product?seller=...&asin=...",
  "title": "jo",
  "brand": "GE Lighting",
  "selling_price": 68.0,
  "currency": "EGP",
  "quantity": 63
}
```

---

## After Applying the Fix

1. **Restart your Flutter app** (hot reload may not pick up schema changes)
2. **Try creating a product again**
3. The QR code should now save successfully! ✅

---

## Troubleshooting

### Still Getting the Error?

1. **Clear Supabase cache**: Run the SQL again
2. **Check you're on the right project**: Verify in Supabase dashboard
3. **Restart the app completely**: Stop and rebuild

### Check if Column Exists

Run this in Supabase SQL Editor:
```sql
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'products' 
ORDER BY ordinal_position;
```

Look for `qr_data` in the list.

---

## Related Files

- Migration: `supabase/migrations/007_add_qr_data_column.sql`
- Schema: `jo.sql`, `atall.sql`
- Code that uses it: `lib/services/supabase.dart` (line ~1820)
