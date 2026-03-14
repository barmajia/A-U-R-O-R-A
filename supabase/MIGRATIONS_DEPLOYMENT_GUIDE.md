# Database Migrations & Edge Functions Deployment Guide

**Created:** 2026-03-14  
**Status:** Ready for Production  
**Version:** 1.0.0

---

## 📋 Overview

This guide covers the deployment of new database tables and edge functions created to fill gaps in the Aurora application.

### New Database Tables

| Table | Purpose | Migration File |
|-------|---------|----------------|
| `business_profiles` | Business profiles for sellers/factories with location-based discovery | `008_create_business_profiles.sql` |
| `notifications` | User notifications system | `009_create_notifications_table.sql` |
| `reviews` | Reviews and ratings for products/sellers | `010_create_reviews_table.sql` |
| `review_helpfulness` | Track review helpfulness votes | `010_create_reviews_table.sql` |
| `wishlist` | User wishlists | `011_create_wishlist_and_cart_tables.sql` |
| `cart` | Shopping cart | `011_create_wishlist_and_cart_tables.sql` |
| `cart_history` | Cart action history | `011_create_wishlist_and_cart_tables.sql` |

### New Edge Functions

| Function | Purpose | Location |
|----------|---------|----------|
| `get-or-create-conversation` | Get existing or create new conversation between users | `supabase/functions/get-or-create-conversation/` |
| `process-notification` | Create and send notifications to users | `supabase/functions/process-notification/` |

---

## 🚀 Prerequisites

1. **Supabase CLI installed:**
   ```bash
   npm install -g supabase
   # or
   brew install supabase/tap/supabase
   ```

2. **Logged into Supabase:**
   ```bash
   supabase login
   ```

3. **Linked to your project:**
   ```bash
   supabase link --project-ref ofovfxsfazlwvcakpuer
   ```

---

## 📦 Step 1: Deploy Database Migrations

### Option A: Deploy All Migrations at Once

```bash
cd supabase
supabase db push
```

### Option B: Deploy Migrations Individually (Recommended)

Deploy in order to avoid dependency issues:

```bash
cd supabase

# 1. Business Profiles (required for nearby chat)
supabase db push --db-schema public

# 2. Notifications (required for notification system)
supabase db push --db-schema public

# 3. Reviews (required for review system)
supabase db push --db-schema public

# 4. Wishlist & Cart (required for e-commerce features)
supabase db push --db-schema public
```

### Verify Migration Success

Connect to your database and check tables exist:

```sql
-- Check all new tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN (
    'business_profiles', 
    'notifications', 
    'reviews', 
    'review_helpfulness',
    'wishlist', 
    'cart', 
    'cart_history'
  )
ORDER BY table_name;
```

---

## ⚡ Step 2: Deploy Edge Functions

### Deploy All Functions

```bash
cd supabase

# Deploy get-or-create-conversation
supabase functions deploy get-or-create-conversation

# Deploy process-notification
supabase functions deploy process-notification
```

### Or Deploy Using PowerShell Script

```powershell
# From supabase directory
.\deploy-functions.ps1
```

### Verify Function Deployment

Test the functions are accessible:

```bash
# Get function list
supabase functions list

# Test get-or-create-conversation (requires auth token)
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/get-or-create-conversation' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"participantId": "00000000-0000-0000-0000-000000000000"}'
```

---

## 🔧 Step 3: Update Flutter Application

### 1. Install New Dependencies

```bash
cd c:\Users\yn098\aurora\A-U-R-O-R-A
flutter pub get
```

### 2. Configure Environment Variables

Create `.env` file in project root:

```bash
# Copy from example
cp .env.example .env
```

Edit `.env` with your credentials:

```env
SUPABASE_URL=https://ofovfxsfazlwvcakpuer.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

### 3. Run Application with Environment Variables

```bash
# Development
flutter run --dart-define-from-file=.env

# Production Build
flutter build apk --dart-define-from-file=.env
flutter build ios --dart-define-from-file=.env
```

---

## 🧪 Step 4: Testing

### Test Business Profiles

```sql
-- Insert test business profile
INSERT INTO public.business_profiles (
  user_id, 
  business_name, 
  business_type,
  latitude,
  longitude,
  city,
  country
) VALUES (
  auth.uid(), -- Replace with actual user ID
  'Test Business',
  'seller',
  30.0444,
  31.2357,
  'Cairo',
  'Egypt'
);

-- Query business profiles
SELECT * FROM public.business_profiles 
WHERE is_active = true;
```

### Test Notifications

```sql
-- Use helper function to create notification
SELECT public.create_notification(
  auth.uid(), -- Replace with actual user ID
  'Test Notification',
  'This is a test notification message',
  'system',
  'normal'
);

-- Query notifications
SELECT * FROM public.notifications 
WHERE user_id = auth.uid(); -- Replace with actual user ID
```

### Test Reviews

```sql
-- Create test review
SELECT public.create_review(
  'product', -- target_type
  '00000000-0000-0000-0000-000000000000', -- product_id (replace)
  5, -- rating
  'Great Product!',
  'This product exceeded my expectations',
  ARRAY['image1.jpg', 'image2.jpg'],
  ARRAY['High quality', 'Fast shipping'],
  ARRAY['Expensive']
);

-- Get review statistics
SELECT * FROM public.get_review_statistics(
  'product',
  '00000000-0000-0000-0000-000000000000' -- product_id
);
```

### Test Wishlist & Cart

```sql
-- Add to wishlist
SELECT public.add_to_wishlist(
  '00000000-0000-0000-0000-000000000000', -- product_id
  'high',
  'Want to buy soon',
  100.00 -- target price
);

-- Add to cart
SELECT public.add_to_cart(
  '00000000-0000-0000-0000-000000000000', -- product_id
  2, -- quantity
  '{"size": "L", "color": "blue"}'::jsonb -- variant options
);

-- Get cart summary
SELECT * FROM public.get_cart_summary();
```

### Test Edge Functions

```bash
# Test get-or-create-conversation
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/get-or-create-conversation' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "participantId": "00000000-0000-0000-0000-000000000000",
    "subject": "Product Inquiry",
    "metadata": {"product_id": "123"}
  }'

# Test process-notification
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/process-notification' \
  -H 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "00000000-0000-0000-0000-000000000000",
    "title": "Order Confirmed",
    "message": "Your order #12345 has been confirmed",
    "type": "order",
    "priority": "high",
    "referenceType": "order",
    "referenceId": "00000000-0000-0000-0000-000000000000",
    "sendPush": true
  }'
```

---

## 🔒 Security Considerations

### RLS Policies

All new tables have Row Level Security (RLS) enabled with appropriate policies:

- **Users can only read/write their own data**
- **Public read access for approved content (reviews, business profiles)**
- **Service role required for system operations**

### Edge Function Security

- **Authentication required** via Bearer token
- **Input validation** on all parameters
- **CORS headers** configured for web access
- **Error handling** prevents information leakage

---

## 📊 Monitoring & Maintenance

### Check Table Sizes

```sql
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'business_profiles', 
    'notifications', 
    'reviews', 
    'review_helpfulness',
    'wishlist', 
    'cart', 
    'cart_history'
  )
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Cleanup Old Notifications

```sql
-- Run monthly to clean up old read notifications
SELECT public.cleanup_expired_notifications();
```

### Monitor Function Invocations

Check function logs in Supabase Dashboard:
1. Go to **Edge Functions** in dashboard
2. Click on function name
3. View **Logs** tab

---

## 🐛 Troubleshooting

### Migration Fails

**Error:** `relation already exists`

**Solution:** The table already exists. Either:
```sql
-- Drop the existing table (WARNING: Deletes all data)
DROP TABLE IF EXISTS public.table_name CASCADE;

-- Or skip the migration if data exists
```

### Function Returns 401 Unauthorized

**Cause:** Invalid or missing authentication token

**Solution:**
- Ensure you're sending `Authorization: Bearer YOUR_TOKEN` header
- For system functions, use service role key
- For user functions, use user's auth token

### RLS Policy Blocking Access

**Error:** `new row violates row-level security policy`

**Solution:**
- Check that the authenticated user matches the policy
- Verify `auth.uid()` is returning expected value
- Review RLS policies in Supabase Dashboard

---

## 📝 Rollback Instructions

If you need to rollback:

### Rollback Migrations

```sql
-- WARNING: This will delete all data!
DROP TABLE IF EXISTS public.cart_history CASCADE;
DROP TABLE IF EXISTS public.cart CASCADE;
DROP TABLE IF EXISTS public.wishlist CASCADE;
DROP TABLE IF EXISTS public.review_helpfulness CASCADE;
DROP TABLE IF EXISTS public.reviews CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.business_profiles CASCADE;
```

### Rollback Edge Functions

```bash
supabase functions delete get-or-create-conversation
supabase functions delete process-notification
```

---

## ✅ Deployment Checklist

- [ ] Supabase CLI installed and logged in
- [ ] Project linked (`supabase link`)
- [ ] All migrations deployed successfully
- [ ] All edge functions deployed successfully
- [ ] `.env` file created with correct credentials
- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] Test queries executed successfully
- [ ] Edge functions tested with curl
- [ ] RLS policies verified
- [ ] Application tested with new features
- [ ] Monitoring setup

---

## 📚 Additional Resources

- [Supabase Migrations Documentation](https://supabase.com/docs/guides/sql/migrations)
- [Supabase Edge Functions Documentation](https://supabase.com/docs/guides/functions)
- [Supabase RLS Documentation](https://supabase.com/docs/guides/auth/row-level-security)
- [PostgreSQL Triggers Documentation](https://www.postgresql.org/docs/current/plpgsql-trigger.html)

---

## 🆘 Support

For issues or questions:
1. Check the [Supabase Dashboard](https://app.supabase.com)
2. Review function logs in Edge Functions section
3. Check database logs in Database section
4. Consult the main [README.md](../../README.md)

---

**Last Updated:** 2026-03-14  
**Maintained By:** Aurora Development Team
