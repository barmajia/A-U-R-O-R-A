# 📦 AURORA - Supabase Setup Files

This folder contains everything you need to deploy and test your Supabase backend.

---

## 📁 Files Overview

### Deployment
| File | Purpose | How to Use |
|------|---------|------------|
| `DEPLOYMENT_STEPS.md` | **Complete deployment guide** | Read this first! |
| `deploy.ps1` | Automated deployment script | Run: `.\deploy.ps1` |
| `quick_setup.sql` | Database schema setup | Copy to Supabase SQL Editor |

### Testing
| File | Purpose | How to Use |
|------|---------|------------|
| `test_functions.ps1` | Test edge functions | Run after deployment |

### Documentation
| File | Purpose |
|------|---------|
| `DEPLOYMENT_GUIDE.md` | Original detailed guide |
| `README.md` | Functions overview |

### Functions
| Folder | Purpose |
|--------|---------|
| `functions/process-signup/` | Handles new seller signup |
| `functions/process-login/` | Handles seller login verification |

---

## 🚀 Quick Deploy (3 Commands)

```powershell
# 1. Setup Database
# Go to: https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/sql/new
# Paste content from: quick_setup.sql

# 2. Deploy Functions
cd "c:\Users\yn098\youssef's project\Aurora\flutter\aurora_ecommerse\aurora\aurora\supabase"
.\deploy.ps1

# 3. Verify
# Go to: https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/functions
```

---

## 🎯 What You Need to Do NOW

### Step 1: Database Setup (2 minutes)
1. Open: https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/sql/new
2. Open file: `quick_setup.sql`
3. Copy ALL content (Ctrl+A, Ctrl+C)
4. Paste in SQL Editor (Ctrl+V)
5. Click **Run**
6. ✅ Should say "Success. No rows returned"

### Step 2: Deploy Functions (3 minutes)
```powershell
# Open PowerShell in this directory
cd "c:\Users\yn098\youssef's project\Aurora\flutter\aurora_ecommerse\aurora\aurora\supabase"

# Run deployment script
.\deploy.ps1
```

If you get errors:
```powershell
# Install Supabase CLI first
npm install -g supabase

# Login
supabase login

# Then try again
.\deploy.ps1
```

### Step 3: Test in App (1 minute)
1. Open your Flutter app
2. Create a new seller account
3. Check if it appears in Supabase `sellers` table

---

## ✅ Verification Checklist

After deployment, verify:

- [ ] Database table `sellers` exists
- [ ] Function `process-signup` is deployed (Status: Active)
- [ ] Function `process-login` is deployed (Status: Active)
- [ ] Can create seller in app
- [ ] Seller appears in Supabase Table Editor
- [ ] Function logs show successful execution

---

## 🔗 Important Links

- **Project Dashboard:** https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer
- **Table Editor:** https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/editor
- **SQL Editor:** https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/sql
- **Edge Functions:** https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/functions
- **Authentication:** https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/auth/users

---

## 🆘 Quick Troubleshooting

| Problem | Quick Fix |
|---------|-----------|
| `supabase: command not found` | `npm install -g supabase` |
| Functions won't deploy | Run `supabase login` first |
| SQL error in setup | Make sure you're in SQL Editor, not New Query |
| App can't find seller | Check RLS policies are enabled |

---

## 📞 Support

- **Supabase Docs:** https://supabase.com/docs
- **Discord:** https://discord.supabase.com
- **Your Functions Logs:** Dashboard → Edge Functions → Select function → Logs

---

**Ready to deploy? Start with Step 1 above! 🚀**
