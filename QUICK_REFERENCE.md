# ⚡ QUICK REFERENCE CARD

**Aurora + Supabase Integration**

---

## 🚀 DEPLOY (Copy-Paste Commands)

### 1. Database Setup
```
→ Go to: https://app.supabase.com/project/ofovfxsfazlwvcakpuer/sql/new
→ Copy: supabase/complete_setup.sql
→ Paste & Run
```

### 2. Deploy Functions
```powershell
cd c:\Users\yn098\aurora\A-U-R-O-R-A
.\deploy-functions.ps1
```

### 3. Test App
```powershell
flutter run
```

---

## 🔗 IMPORTANT LINKS

| Resource | URL |
|----------|-----|
| **Dashboard** | https://app.supabase.com/project/ofovfxsfazlwvcakpuer |
| **Table Editor** | https://app.supabase.com/project/ofovfxsfazlwvcakpuer/editor |
| **Storage** | https://app.supabase.com/project/ofovfxsfazlwvcakpuer/storage |
| **SQL Editor** | https://app.supabase.com/project/ofovfxsfazlwvcakpuer/sql/new |
| **Logs** | https://app.supabase.com/project/ofovfxsfazlwvcakpuer/logs/explorer |
| **API Keys** | https://app.supabase.com/project/ofovfxsfazlwvcakpuer/settings/api |

---

## 📦 EDGE FUNCTIONS

| Function | Purpose | Deploy Command |
|----------|---------|----------------|
| `create-product` | Create product + generate ASIN | `supabase functions deploy create-product --no-verify-jwt` |
| `update-product` | Update existing product | `supabase functions deploy update-product --no-verify-jwt` |
| `delete-product` | Delete product + images | `supabase functions deploy delete-product --no-verify-jwt` |
| `search-products` | Search + filter products | `supabase functions deploy search-products --no-verify-jwt` |

---

## 🔑 KEYS (Get from Dashboard)

```
Anon Key: Settings → API → anon public
Service Role Key: Settings → API → service_role
Project Ref: ofovfxsfazlwvcakpuer
```

---

## 🐛 COMMON ERRORS

| Error | Fix |
|-------|-----|
| `404 Function not found` | Deploy functions |
| `Bucket not found` | Run complete_setup.sql |
| `Unauthorized` | Check user is logged in |
| `Invalid ASIN` | Verify Edge Function returns ASIN |

---

## ✅ VERIFICATION

```bash
# List functions
supabase functions list

# Check logs
supabase functions logs create-product

# Test create
curl -X POST 'https://ofovfxsfazlwvcakpuer.supabase.co/functions/v1/create-product' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"title":"Test","brand":"Test","category":"Electronics","subcategory":"Smartphones","price":999,"quantity":10,"sellerId":"YOUR_USER_ID"}'
```

---

## 📁 KEY FILES

| File | Purpose |
|------|---------|
| `supabase/complete_setup.sql` | Database + storage setup |
| `lib/services/supabase.dart` | Supabase provider + Edge Function calls |
| `lib/services/supabase_storage.dart` | Image upload service |
| `lib/pages/product/product_form_screen.dart` | Create/edit product UI |
| `lib/pages/product/product.dart` | Product list UI |
| `COMPLETE_DEPLOYMENT_GUIDE.md` | Full deployment guide |
| `TROUBLESHOOTING_GUIDE.md` | Error solutions |

---

## 🎯 ASIN FORMAT

```
ASN-{timestamp}-{random}
Example: ASN-1740912345678-ABC123DEF
```

---

## 📊 STORAGE PATH FORMAT

```
product-images/
  └── {seller_id}/
       └── {product_id}/
            └── {filename}
```

---

**Print this page for quick reference!**
