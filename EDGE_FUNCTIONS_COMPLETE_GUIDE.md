# 🚀 Aurora Edge Functions - Complete Deployment Guide

**Version:** 1.0.0  
**Date:** March 5, 2026  
**Project:** ofovfxsfazlwvcakpuer

---

## 📦 What You Have

### ✅ Existing Edge Functions (Already Deployed)
- `create-product` - Create new products
- `update-product` - Update product details
- `delete-product` - Delete products (with image cleanup)
- `search-products` - Search and filter products
- `manage-product` - Product management operations
- `create-order` - Create customer orders
- `upload-image` - Upload product images
- `delete-image` - Delete images from storage
- `get-image-url` - Get signed image URLs
- `process-signup` - Handle user signup
- `process-login` - Handle user login

### ⭐ New Factory Discovery Functions
- `find-nearby-factories` - Location-based factory search
- `request-factory-connection` - Send factory connection requests
- `rate-factory` - Submit factory ratings

---

## 🚀 Quick Deploy (3 Steps)

### Step 1: Deploy All Functions

```powershell
# Navigate to project
cd c:\Users\yn098\aurora\A-U-R-O-R-A

# Run deployment script
.\supabase\deploy-all-functions.ps1
```

**Or deploy manually:**
```bash
cd supabase/functions

# Deploy factory functions (NEW)
supabase functions deploy find-nearby-factories --no-verify-jwt
supabase functions deploy request-factory-connection --no-verify-jwt
supabase functions deploy rate-factory --no-verify-jwt

# Deploy product functions (existing)
supabase functions deploy create-product --no-verify-jwt
supabase functions deploy update-product --no-verify-jwt
supabase functions deploy delete-product --no-verify-jwt
supabase functions deploy search-products --no-verify-jwt
```

---

### Step 2: Set Service Role Key

1. Go to: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/settings/api
2. Copy the **Service Role Key** (starts with `eyJ...`)
3. Run:
```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-key-here
```

---

### Step 3: Verify Deployment

```bash
# List all deployed functions
supabase functions list

# Check logs for errors
supabase functions logs --function find-nearby-factories
```

---

## 📁 Complete File Structure

```
c:\Users\yn098\aurora\A-U-R-O-R-A\
├── supabase/
│   ├── functions/
│   │   ├── create-product/
│   │   │   └── index.ts ✅
│   │   ├── update-product/
│   │   │   └── index.ts ✅
│   │   ├── delete-product/
│   │   │   └── index.ts ✅
│   │   ├── search-products/
│   │   │   └── index.ts ✅
│   │   ├── find-nearby-factories/
│   │   │   └── index.ts ⭐ NEW
│   │   ├── request-factory-connection/
│   │   │   └── index.ts ⭐ NEW
│   │   ├── rate-factory/
│   │   │   └── index.ts ⭐ NEW
│   │   ├── manage-product/
│   │   │   └── index.ts ✅
│   │   ├── create-order/
│   │   │   └── index.ts ✅
│   │   ├── upload-image/
│   │   │   └── index.ts ✅
│   │   ├── delete-image/
│   │   │   └── index.ts ✅
│   │   ├── get-image-url/
│   │   │   └── index.ts ✅
│   │   ├── process-signup/
│   │   │   └── index.ts ✅
│   │   ├── process-login/
│   │   │   └── index.ts ✅
│   │   └── import_map.json
│   │
│   ├── migrations/
│   │   └── 20260305000000_create_factory_discovery_system.sql ⭐ NEW
│   │
│   ├── deploy-all-functions.ps1 ⭐ NEW
│   ├── deploy-functions.ps1 ✅
│   └── config.toml
│
├── lib/
│   ├── models/factory/ ⭐ NEW
│   │   ├── factory_info.dart
│   │   ├── factory_connection.dart
│   │   ├── factory_rating.dart
│   │   └── factory_models.dart
│   │
│   ├── pages/factory/ ⭐ NEW
│   │   ├── factory_discovery_page.dart
│   │   ├── factory_profile_page.dart
│   │   ├── factory_connections_page.dart
│   │   └── factory_pages.dart
│   │
│   └── services/
│       └── supabase.dart (updated with factory methods)
│
└── Documentation/ ⭐ NEW
    ├── FACTORY_DISCOVERY_IMPLEMENTATION.md
    ├── FACTORY_DISCOVERY_QUICKSTART.md
    ├── FACTORY_SYSTEM_SUMMARY.md
    └── supabase/
        └── EDGE_FUNCTIONS_TESTING_GUIDE.md
```

---

## 🧪 Testing Guide

### Test Factory Discovery Flow

#### 1. Setup Test Data

```sql
-- Register a test factory
UPDATE sellers 
SET 
  is_factory = true,
  latitude = 51.5074,
  longitude = -0.1278,
  wholesale_discount = 15,
  min_order_quantity = 10
WHERE email = 'factory@test.com';

-- Register a test seller
UPDATE sellers 
SET 
  latitude = 51.5100,
  longitude = -0.1200
WHERE email = 'seller@test.com';
```

#### 2. Test Find Nearby Factories

```bash
# Get JWT token from Flutter app (logged in as seller)
# Then test the function
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/find-nearby-factories' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "latitude": 51.5100,
    "longitude": -0.1200,
    "radius": 50,
    "limit": 10
  }'
```

#### 3. Test in Flutter App

```dart
// In your Flutter app, navigate to Factory Discovery
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const FactoryDiscoveryPage(),
  ),
);

// Tap "Search Nearby"
// Grant location permissions
// Should see your test factory
```

---

## 🔐 Security Checklist

| Security Feature | Status | Notes |
|-----------------|--------|-------|
| JWT Authentication | ✅ | All functions verify tokens |
| Ownership Verification | ✅ | Seller ID matched against auth.uid() |
| Service Role Key | ⚠️ | Must be set manually |
| Input Validation | ✅ | All required fields validated |
| CORS Headers | ✅ | Configured for Flutter |
| RLS Policies | ✅ | Database-level security |
| Error Handling | ✅ | Consistent error responses |

---

## 📊 Function Endpoints

All functions are accessible at:
```
https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/{function-name}
```

| Function | Endpoint | Method |
|----------|----------|--------|
| find-nearby-factories | `/functions/v1/find-nearby-factories` | POST |
| request-factory-connection | `/functions/v1/request-factory-connection` | POST |
| rate-factory | `/functions/v1/rate-factory` | POST |
| create-product | `/functions/v1/create-product` | POST |
| update-product | `/functions/v1/update-product` | POST |
| delete-product | `/functions/v1/delete-product` | POST |
| search-products | `/functions/v1/search-products` | POST |

---

## 🐛 Troubleshooting

### Common Issues

#### 1. "Function not found" (404)
**Cause:** Function not deployed  
**Solution:**
```bash
supabase functions deploy {function-name} --no-verify-jwt
```

#### 2. "Unauthorized" (401)
**Cause:** Missing or invalid JWT token  
**Solution:** Ensure user is logged in and token is passed in headers

#### 3. "Service Role Key not set"
**Cause:** Missing SUPABASE_SERVICE_ROLE_KEY  
**Solution:**
```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-key
```

#### 4. "CORS error" in browser/console
**Cause:** CORS headers missing  
**Solution:** Check function has corsHeaders in response

#### 5. Database permission errors
**Cause:** RLS policies blocking access  
**Solution:** Verify RLS policies allow authenticated users

---

## 📈 Monitoring & Logs

### View Function Logs

```bash
# Real-time logs
supabase functions logs --function find-nearby-factories --follow

# Last 100 lines
supabase functions logs --function find-nearby-factories --limit 100

# All functions
supabase functions logs --all
```

### Monitor in Supabase Dashboard

1. Go to: https://app.supabase.com/project/ofovfxsfazlwvcakpuer
2. Navigate to: **Edge Functions** → Select function
3. View: Logs, Invocations, Errors

---

## 🎯 Performance Optimization

### Best Practices

1. **Keep functions small** - Single responsibility
2. **Use database functions** - Offload complex queries
3. **Cache when possible** - Reduce database calls
4. **Validate early** - Fail fast on invalid input
5. **Use service role key** - Bypass RLS for validation

### Response Time Targets

| Function | Target | Current |
|----------|--------|---------|
| find-nearby-factories | < 500ms | - |
| request-factory-connection | < 300ms | - |
| rate-factory | < 300ms | - |
| create-product | < 1000ms | - |
| search-products | < 500ms | - |

---

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] Backup database
- [ ] Test functions locally (deno test)
- [ ] Review code for security issues
- [ ] Check import_map.json is up to date

### Deployment
- [ ] Deploy all functions
- [ ] Set service role key
- [ ] Verify functions in Supabase dashboard
- [ ] Test CORS headers

### Post-Deployment
- [ ] Test each function via cURL
- [ ] Test in Flutter app
- [ ] Monitor logs for errors
- [ ] Update documentation

### Factory System Specific
- [ ] Run SQL migration
- [ ] Verify factory_connections table
- [ ] Verify factory_ratings table
- [ ] Test location-based search
- [ ] Test connection request flow
- [ ] Test rating system

---

## 📚 Documentation Links

- **Factory Discovery Implementation:** `FACTORY_DISCOVERY_IMPLEMENTATION.md`
- **Quick Start Guide:** `FACTORY_DISCOVERY_QUICKSTART.md`
- **System Summary:** `FACTORY_SYSTEM_SUMMARY.md`
- **Testing Guide:** `supabase/EDGE_FUNCTIONS_TESTING_GUIDE.md`

---

## 🎉 You're Ready!

All Edge Functions are ready to deploy. Follow the 3-step quick deploy above, then test using the guides.

**Need Help?**
- Check logs: `supabase functions logs --function {name}`
- Review docs: See documentation files listed above
- Test flow: Follow `EDGE_FUNCTIONS_TESTING_GUIDE.md`

---

**Good luck!** 🚀
