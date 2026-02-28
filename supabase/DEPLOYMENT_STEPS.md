# 🚀 DEPLOYMENT INSTRUCTIONS - AURORA EDGE FUNCTIONS

## Quick Start (3 Steps)

### 1️⃣ Run Database Setup
1. Go to: https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/sql/new
2. Copy **ALL** content from `quick_setup.sql`
3. Paste and click **Run**
4. ✅ You should see "Success. No rows returned"

---

### 2️⃣ Deploy Edge Functions
**Option A: Using PowerShell Script (Recommended)**
```powershell
cd "c:\Users\yn098\youssef's project\Aurora\flutter\aurora_ecommerse\aurora\aurora\supabase"
.\deploy.ps1
```

**Option B: Manual Commands**
```powershell
# Install Supabase CLI (if not installed)
npm install -g supabase

# Login
supabase login

# Deploy functions
cd "c:\Users\yn098\youssef's project\Aurora\flutter\aurora_ecommerse\aurora\aurora\supabase\functions"
supabase functions deploy process-signup --project-ref ofovfxsfazlwvcakpuer
supabase functions deploy process-login --project-ref ofovfxsfazlwvcakpuer
```

---

### 3️⃣ Verify Deployment
1. Go to: https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/functions
2. Check you see both functions:
   - ✅ `process-signup` (Status: Active)
   - ✅ `process-login` (Status: Active)

---

## 🧪 Test in Flutter App

### Test Seller Signup:
1. Open your Flutter app
2. Go to Signup page
3. Select **"Seller"** account type
4. Fill in:
   - Full Name: `Test Seller`
   - Email: `testseller@example.com`
   - Password: `Test123456`
   - Phone: `+1234567890`
   - Location: `Cairo, Egypt`
   - Currency: `EGP`
5. Click **Sign Up**
6. ✅ Should show: "Account created! Please check your email to verify."

### Check in Supabase:
1. Go to: https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/editor
2. Select `sellers` table
3. ✅ You should see your new seller!

### Check Edge Function Logs:
1. Go to: https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/functions
2. Click on `process-signup`
3. Click **Logs** tab
4. ✅ You should see the function execution log

---

## 🔧 Troubleshooting

### ❌ "Supabase CLI not found"
**Solution:**
```powershell
npm install -g supabase
# Then close and reopen PowerShell
```

### ❌ "Not logged in"
**Solution:**
```powershell
supabase login
# This opens browser to authenticate
```

### ❌ "Function already exists"
**Solution:** Just deploy again, it will update:
```powershell
supabase functions deploy process-signup --project-ref ofovfxsfazlwvcakpuer
```

### ❌ "Permission denied" in SQL Editor
**Solution:** Make sure you're using the project admin account

### ❌ "Column does not exist" error
**Solution:** Re-run the `quick_setup.sql` script in SQL Editor

### ❌ Edge function returns 500 error
**Solution:** 
1. Check function logs in Supabase Dashboard
2. Verify `SUPABASE_SERVICE_ROLE_KEY` is set (it's automatic in Supabase)
3. Check the error message in logs

---

## 📊 Function URLs (After Deployment)

- **process-signup:** `https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/process-signup`
- **process-login:** `https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/process-login`

---

## 🔐 Security Notes

### Current Setup:
- ✅ RLS (Row Level Security) enabled on `sellers` table
- ✅ Users can only view/update their own seller profile
- ✅ Verified sellers are visible to everyone
- ✅ Edge functions use service role key (bypasses RLS)

### Service Role Key:
The edge functions automatically use `SUPABASE_SERVICE_ROLE_KEY` which:
- Has full database access
- Should **NEVER** be exposed in client code
- Is only used server-side in edge functions
- Is automatically available in Supabase Functions environment

---

## 📈 Monitoring

### View Function Analytics:
1. Dashboard → Edge Functions → Select function
2. Click **Analytics** tab
3. See: Invocations, Errors, Duration

### View Database Changes:
1. Dashboard → Table Editor → `sellers`
2. See all seller records in real-time

### View Auth Users:
1. Dashboard → Authentication → Users
2. See all registered users

---

## 🎯 What Happens on Signup?

```
User Signs Up in App
    ↓
1. Supabase Auth creates user
    ↓
2. Flutter app calls _createSellerRecord()
    ↓
   - Creates seller in Supabase 'sellers' table
   - Creates seller in local SQLite
    ↓
3. Flutter app calls edge function (non-blocking)
    ↓
   - process-signup runs additional logic
   - Can send emails, analytics, etc.
    ↓
✅ User is created and logged in!
```

---

## 🎯 What Happens on Login?

```
User Logs In in App
    ↓
1. Supabase Auth verifies credentials
    ↓
2. Flutter app calls loginSeller()
    ↓
   - Checks seller exists in 'sellers' table
   - Returns seller data if found
    ↓
3. (Optional) Can call process-login edge function
    ↓
   - Updates last_login timestamp
   - Returns verification status
    ↓
✅ User is logged in!
```

---

## ✅ Deployment Checklist

- [ ] Supabase CLI installed (`supabase --version`)
- [ ] Logged in to Supabase (`supabase whoami`)
- [ ] Database schema deployed (ran `quick_setup.sql`)
- [ ] `process-signup` function deployed
- [ ] `process-login` function deployed
- [ ] Functions visible in dashboard
- [ ] Test signup works in app
- [ ] Seller appears in `sellers` table
- [ ] Edge function logs show success
- [ ] No errors in console

---

## 📚 Additional Resources

- **Supabase Functions Docs:** https://supabase.com/docs/guides/functions
- **Your Project Dashboard:** https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer
- **Supabase Discord:** https://discord.supabase.com

---

## 🆘 Need Help?

If you encounter any issues:

1. **Check the logs** in Supabase Dashboard
2. **Run the test script:** `.\test_functions.ps1`
3. **Verify database schema** was applied correctly
4. **Check RLS policies** are enabled

---

**Good luck with your deployment! 🎉**
