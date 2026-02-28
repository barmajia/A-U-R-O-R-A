# 🚀 DEPLOYMENT GUIDE - AURORA SUPABASE EDGE FUNCTIONS

## 📋 Prerequisites

1. **Node.js** installed (v16 or higher)
2. **Supabase CLI** installed
3. **Supabase Project** (you already have: ofovfxsfazlwvcakpuer)

---

## 🔧 STEP 1: Install Supabase CLI

### Windows (PowerShell):
```powershell
npm install -g supabase
```

### Or using Chocolatey:
```powershell
choco install supabase
```

---

## 🔧 STEP 2: Login to Supabase

```bash
supabase login
```

This will open a browser window. Login with your Supabase account.

---

## 🔧 STEP 3: Link to Your Project

```bash
supabase link --project-ref ofovfxsfazlwvcakpuer
```

**Project Info:**
- **Project Ref:** `ofovfxsfazlwvcakpuer`
- **URL:** `https://ofovfxsfazlwvcakpuer.supabase.co`

---

## 🔧 STEP 4: Set Up Database Schema

1. Go to **Supabase Dashboard**: https://app.supabase.com
2. Select your project
3. Go to **SQL Editor** (left sidebar)
4. Click **New Query**
5. Copy and paste the contents of `supabase/database_schema.sql`
6. Click **Run** or press `Ctrl+Enter`

**This will create:**
- ✅ Sellers table with all columns
- ✅ Users table (optional)
- ✅ Indexes for performance
- ✅ RLS policies
- ✅ Triggers for auto-creating profiles

---

## 🔧 STEP 5: Deploy Edge Functions

### Option A: Deploy All Functions

```bash
cd "c:\Users\yn098\youssef's project\Aurora\flutter\aurora_ecommerse\aurora\aurora\supabase\functions"
supabase functions deploy process-signup
supabase functions deploy process-login
```

### Option B: Deploy One by One

**Deploy process-signup:**
```bash
supabase functions deploy process-signup --project-ref ofovfxsfazlwvcakpuer
```

**Deploy process-login:**
```bash
supabase functions deploy process-login --project-ref ofovfxsfazlwvcakpuer
```

### Expected Output:
```
Deploying process-signup (project ref: ofovfxsfazlwvcakpuer)
Bundle size is 2.5 KB
Deployment complete!
Function URL: https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/process-signup
```

---

## 🔧 STEP 6: Verify Deployment

### Check in Supabase Dashboard:
1. Go to your project
2. Click **Edge Functions** in sidebar
3. You should see:
   - ✅ `process-signup`
   - ✅ `process-login`

### Test the Functions:

**Test process-signup:**
```bash
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/process-signup' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "test-123",
    "email": "test@example.com",
    "fullName": "Test User",
    "accountType": "seller",
    "phone": "+1234567890",
    "location": "Test City",
    "currency": "USD"
  }'
```

---

## 🔧 STEP 7: Update Flutter App

The functions are already configured in your Flutter app. Just make sure:

**In `lib/services/supabase.dart`:**
```dart
// Edge function is called automatically on signup
await _client.functions.invoke(
  'process-signup',  // ✅ Function name matches
  body: {...},
);
```

**In `lib/pages/singup/login.dart`:**
```dart
// After login, you can call process-login if needed
await supabaseProvider.callEdgeFunction(
  functionName: 'process-login',
  body: {
    'userId': user.id,
    'email': user.email,
  },
);
```

---

## 🐛 TROUBLESHOOTING

### ❌ Error: "Function not found"
**Solution:** Make sure the function is deployed
```bash
supabase functions deploy process-signup
```

### ❌ Error: "Permission denied"
**Solution:** Check RLS policies are enabled
```sql
-- Run in SQL Editor
ALTER TABLE sellers ENABLE ROW LEVEL SECURITY;
```

### ❌ Error: "Column does not exist"
**Solution:** Run the database schema SQL again
```sql
-- Copy from supabase/database_schema.sql
```

### ❌ Error: "Failed to fetch"
**Solution:** Check function URL is correct
```
https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/process-signup
```

---

## 📊 MONITORING

### View Function Logs:

1. **Supabase Dashboard** → **Edge Functions**
2. Click on function name
3. Click **Logs** tab
4. See real-time execution logs

### View Database Changes:

1. **Supabase Dashboard** → **Table Editor**
2. Select `sellers` table
3. See new records after signup

---

## 🔐 SECURITY CHECKLIST

- ✅ RLS enabled on all tables
- ✅ Policies restrict access properly
- ✅ Service role key kept secret (only in Edge Functions)
- ✅ Input validation in Edge Functions
- ✅ CORS headers configured
- ✅ Error handling implemented

---

## 📱 TESTING IN APP

### Test Seller Signup:
1. Run Flutter app
2. Go to Signup page
3. Select "Seller" account type
4. Fill in all fields
5. Click "Sign Up"
6. Check:
   - ✅ User created in `auth.users`
   - ✅ Seller created in `sellers` table
   - ✅ Edge Function logs show success

### Test Seller Login:
1. Run Flutter app
2. Go to Login page
3. Toggle to "Seller" login
4. Enter credentials
5. Click "Login"
6. Check:
   - ✅ Navigates to Homepage
   - ✅ Seller data loaded in SellerDB
   - ✅ Drawer shows seller options

---

## 🎯 NEXT STEPS

1. **Add more Edge Functions:**
   - `send-email` - Welcome emails
   - `process-payment` - Payment processing
   - `generate-report` - Sales reports

2. **Add more tables:**
   - Products
   - Orders
   - Categories
   - Reviews

3. **Add real-time features:**
   - Order notifications
   - Chat with customers
   - Live inventory updates

---

## 📚 RESOURCES

- **Supabase Docs:** https://supabase.com/docs
- **Edge Functions Guide:** https://supabase.com/docs/guides/functions
- **Discord Support:** https://discord.supabase.com
- **Your Project:** https://app.supabase.com/project/ofovfxsfazlwvcakpuer

---

## ✅ DEPLOYMENT CHECKLIST

- [ ] Supabase CLI installed
- [ ] Logged in to Supabase
- [ ] Project linked
- [ ] Database schema deployed (SQL run)
- [ ] Edge Functions deployed
- [ ] Functions visible in dashboard
- [ ] Test signup works
- [ ] Test login works
- [ ] Seller data saved correctly
- [ ] No errors in logs

---

**🎉 Congratulations! Your Supabase backend is fully deployed!**
