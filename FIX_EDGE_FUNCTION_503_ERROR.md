# Fix Edge Function 503 Error

## ❌ Error Message
```
FunctionException(status: 503)
SUPABASE_EDGE_RUNTIME_ERROR
Failed to serve request due to an internal service error
```

## 🔍 Root Cause

The `create-product` Edge Function is either:
1. **Not deployed** to Supabase
2. **Deployed but crashed**
3. **Missing database schema**

---

## ✅ Solution: Deploy Edge Functions

### Step 1: Install Supabase CLI (if not installed)

```bash
npm install -g supabase
```

Or check if already installed:
```bash
supabase --version
```

---

### Step 2: Login to Supabase

```bash
supabase login
```

This will open a browser window. Login with your Supabase account.

---

### Step 3: Link to Your Project

```bash
cd c:\Users\yn098\aurora\A-U-R-O-R-A\supabase\functions
supabase link --project-ref ofovfxsfazlwvcakpuer
```

**Note:** Replace `ofovfxsfazlwvcakpuer` with your actual project ID if different.

---

### Step 4: Deploy All Edge Functions

Run these commands from the `supabase/functions` directory:

```bash
# Deploy create-product function
supabase functions deploy create-product

# Deploy update-product function
supabase functions deploy update-product

# Deploy delete-product function
supabase functions deploy delete-product

# Deploy list-products function
supabase functions deploy list-products

# Deploy search-products function
supabase functions deploy search-products

# Deploy process-signup function
supabase functions deploy process-signup

# Deploy process-login function
supabase functions deploy process-login
```

---

### Step 5: Verify Deployment

1. Go to https://supabase.com
2. Select your Aurora project
3. Click **Edge Functions** in left sidebar
4. You should see all deployed functions:
   - ✅ create-product
   - ✅ update-product
   - ✅ delete-product
   - ✅ list-products
   - ✅ search-products
   - ✅ process-signup
   - ✅ process-login

---

## 🐛 If Still Getting 503 Error

### Check Function Logs

1. Go to Supabase Dashboard
2. **Edge Functions** → Select `create-product`
3. Click **Logs** tab
4. Look for error messages

### Common Issues:

#### Issue 1: Database Table Missing

**Error:** `relation "products" does not exist`

**Fix:** Run this in SQL Editor:

```sql
-- Make sure products table exists
CREATE TABLE IF NOT EXISTS products (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    asin text,
    sku text,
    seller_id uuid NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    brand text NOT NULL,
    currency text DEFAULT 'USD'::text,
    price numeric(10,2),
    quantity integer DEFAULT 0,
    status text DEFAULT 'draft'::text,
    brand_id text,
    is_local_brand boolean DEFAULT false,
    attributes jsonb DEFAULT '{}'::jsonb,
    color_hex text,
    category text,
    subcategory text,
    images jsonb DEFAULT '[]'::jsonb,
    average_rating numeric(3,2) DEFAULT 0,
    review_count integer DEFAULT 0,
    title_description tsvector,
    qr_data TEXT,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    allow_chat boolean DEFAULT true,
    search_vector tsvector,
    CONSTRAINT products_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'inactive'::text]))),
    CONSTRAINT valid_price CHECK ((price IS NULL OR price >= (0)::numeric)),
    CONSTRAINT valid_quantity CHECK ((quantity >= 0))
);

-- Add qr_data column if missing
ALTER TABLE products ADD COLUMN IF NOT EXISTS qr_data TEXT;

-- Create index
CREATE INDEX IF NOT EXISTS idx_products_qr_data ON products(qr_data) WHERE qr_data IS NOT NULL;
```

---

#### Issue 2: RLS Policy Blocking

**Error:** `new row violates row-level security policy`

**Fix:** Run this in SQL Editor:

```sql
-- Enable RLS
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Create policies
DROP POLICY IF EXISTS "Users can insert their own products" ON products;
CREATE POLICY "Users can insert their own products" ON products
    FOR INSERT
    WITH CHECK (auth.uid() = seller_id);

DROP POLICY IF EXISTS "Users can update their own products" ON products;
CREATE POLICY "Users can update their own products" ON products
    FOR UPDATE
    USING (auth.uid() = seller_id);

DROP POLICY IF EXISTS "Users can delete their own products" ON products;
CREATE POLICY "Users can delete their own products" ON products
    FOR DELETE
    USING (auth.uid() = seller_id);

DROP POLICY IF EXISTS "Users can view their own products" ON products;
CREATE POLICY "Users can view their own products" ON products
    FOR SELECT
    USING (auth.uid() = seller_id);

-- Allow public read access for product pages
DROP POLICY IF EXISTS "Public can view active products" ON products;
CREATE POLICY "Public can view active products" ON products
    FOR SELECT
    USING (status = 'active');
```

---

#### Issue 3: Missing Environment Variables

**Error:** `Missing environment variable: SUPABASE_URL`

**Fix:** Environment variables are auto-injected by Supabase. Make sure:
1. Function is deployed correctly
2. Using correct Supabase project URL

---

### Step 6: Test the Function

#### Option A: Test from Flutter App

1. **Restart your Flutter app** (hot reload won't work)
   ```bash
   flutter run
   ```

2. **Try creating a product**
   - Fill in all required fields
   - Tap "Create Product"
   - Check logs for success message

#### Option B: Test with curl

```bash
# Get your auth token from Flutter app logs
# Replace YOUR_ANON_KEY and YOUR_SUPABASE_URL

curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/create-product' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Test Product",
    "description": "Test description",
    "brand": "Test Brand",
    "price": 19.99,
    "quantity": 10,
    "status": "draft",
    "category": "Electronics",
    "subcategory": "Accessories",
    "sellerId": "YOUR_USER_ID",
    "currency": "USD"
  }'
```

Expected response:
```json
{
  "success": true,
  "message": "Product created successfully",
  "asin": "ASN-...",
  "sku": "..."
}
```

---

## 📊 Monitor Function Health

### View Real-time Logs

1. Go to Supabase Dashboard
2. **Edge Functions** → `create-product`
3. Click **Logs** tab
4. Watch logs in real-time while testing

### Check Function Status

```bash
# List all functions
supabase functions list

# Check specific function
supabase functions get create-product
```

---

## 🎯 Quick Deploy Script

Create a file `deploy-functions.bat`:

```batch
@echo off
echo Deploying Supabase Edge Functions...
echo.

cd supabase\functions

echo Deploying create-product...
supabase functions deploy create-product

echo Deploying update-product...
supabase functions deploy update-product

echo Deploying delete-product...
supabase functions deploy delete-product

echo Deploying list-products...
supabase functions deploy list-products

echo Deploying search-products...
supabase functions deploy search-products

echo Deploying process-signup...
supabase functions deploy process-signup

echo Deploying process-login...
supabase functions deploy process-login

echo.
echo ✅ All functions deployed!
pause
```

Run it:
```bash
deploy-functions.bat
```

---

## ✅ Success Checklist

- [ ] Supabase CLI installed
- [ ] Logged in to Supabase
- [ ] Project linked
- [ ] All functions deployed
- [ ] Functions visible in Supabase Dashboard
- [ ] No errors in function logs
- [ ] Database tables exist
- [ ] RLS policies configured
- [ ] `qr_data` column added to products table
- [ ] Test product creation works

---

## 🆘 Still Having Issues?

### Contact Supabase Support

1. Go to https://supabase.help
2. Create a ticket with:
   - Function name: `create-product`
   - Error: `503 Service Unavailable`
   - Timestamp of failed request
   - Function logs

### Check Supabase Status

Visit https://status.supabase.com to check for outages.

---

## 📝 Summary

| Step | Command | Status |
|------|---------|--------|
| 1. Install CLI | `npm install -g supabase` | ⬜ |
| 2. Login | `supabase login` | ⬜ |
| 3. Link Project | `supabase link --project-ref ...` | ⬜ |
| 4. Deploy Functions | `supabase functions deploy create-product` | ⬜ |
| 5. Verify | Check Supabase Dashboard | ⬜ |
| 6. Test | Create product in app | ⬜ |

---

**After completing these steps, the 503 error should be resolved!** ✅
