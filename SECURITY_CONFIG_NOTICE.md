# 🔐 Security Configuration Notice

**File:** `lib/config/supabase_config.dart`  
**Date:** 2026-03-08  
**Status:** ⚠️ **CONTAINS REAL CREDENTIALS**

---

## ⚠️ IMPORTANT SECURITY NOTICE

This file (`lib/config/supabase_config.dart`) contains **REAL Supabase credentials** as default values for local development convenience.

### **Current Status:**

```dart
static const String url = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://ofovfxsfazlwvcakpuer.supabase.co', // ✅ REAL URL
);

static const String anonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGci...', // ✅ REAL ANON KEY
);
```

---

## 🛡️ Security Measures

### **What's Protected:**

1. ✅ **Anonymous Key (Public)** - This is the PUBLIC/ANON key, safe for client-side use
2. ✅ **Environment Override** - `--dart-define` always takes precedence
3. ✅ **Development Only** - Defaults are for local dev convenience

### **What's NOT Protected:**

❌ **File is in Git** - Anyone with repo access can see the key  
❌ **No Encryption** - Key is in plain text  
❌ **Default Value** - Used if no `--dart-define` provided  

---

## 🚨 RECOMMENDED ACTIONS

### **Option 1: Keep Current Setup (Development)**

**Pros:**
- ✅ Convenient for local development
- ✅ No need to type credentials every time
- ✅ Works out of the box

**Cons:**
- ⚠️ Key visible in repository
- ⚠️ Not suitable for public repos
- ⚠️ Security risk if repo is compromised

**Best for:** Private repositories, solo development, internal teams

---

### **Option 2: Remove Defaults (Production)**

**Edit `lib/config/supabase_config.dart`:**

```dart
// ❌ REMOVE THIS (current setup)
static const String anonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGci...', // REAL KEY
);

// ✅ REPLACE WITH (production setup)
static const String anonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '', // ⚠️ EMPTY - forces use of --dart-define
);
```

**Pros:**
- ✅ Key not in repository
- ✅ Forces secure configuration
- ✅ Required for CI/CD

**Cons:**
- ⚠️ Must use `--dart-define` every time
- ⚠️ Less convenient for local dev

**Best for:** Production builds, public repositories, CI/CD

---

### **Option 3: Use .env File (Recommended)**

**Step 1: Add to `.gitignore`**

```gitignore
# Environment variables
.env
.env.local
.env.*.local
lib/config/secrets.dart
```

**Step 2: Create `.env` (not committed)**

```env
SUPABASE_URL=https://ofovfxsfazlwvcakpuer.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
```

**Step 3: Load in `main.dart`**

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  
  final url = dotenv.env['SUPABASE_URL']!;
  final key = dotenv.env['SUPABASE_ANON_KEY']!;
  
  await Supabase.initialize(url: url, anonKey: key);
}
```

**Pros:**
- ✅ Key never in repository
- ✅ Convenient for local dev
- ✅ Easy to manage multiple environments

**Cons:**
- ⚠️ Requires additional package (`flutter_dotenv`)
- ⚠️ Must create `.env` file manually

**Best for:** Teams, multiple environments, balanced security

---

## 📋 Current Configuration

| Setting | Value | Security Level |
|---------|-------|----------------|
| **URL Default** | `https://ofovfxsfazlwvcakpuer.supabase.co` | ⚠️ Visible in Git |
| **Anon Key Default** | REAL KEY (full length) | ⚠️ Visible in Git |
| **Environment Override** | ✅ Enabled | ✅ Secure |
| **CI/CD Compatible** | ✅ Yes | ✅ Secure |

---

## 🔒 Best Practices

### **DO:**
- ✅ Use `--dart-define` in production
- ✅ Rotate keys regularly
- ✅ Keep repository private
- ✅ Use different keys for dev/prod
- ✅ Monitor key usage in Supabase dashboard

### **DON'T:**
- ❌ Commit to public repositories
- ❌ Share key via email/chat
- ❌ Use service_role key (only anon)
- ❌ Use same key across projects
- ❌ Forget to rotate keys

---

## 🔄 How to Remove Defaults

If you want to remove the real key from the codebase:

### **Step 1: Edit `lib/config/supabase_config.dart`**

```dart
// Change this:
static const String anonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGci...', // REAL KEY
);

// To this:
static const String anonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '', // EMPTY
);
```

### **Step 2: Always use `--dart-define`**

```bash
# Development
flutter run \
  --dart-define=SUPABASE_URL=https://ofovfxsfazlwvcakpuer.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_key

# Production build
flutter build apk \
  --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
  --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
```

### **Step 3: Update CI/CD**

GitHub Actions already configured correctly:

```yaml
- name: Build APK
  run: flutter build apk \
    --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
    --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
```

---

## 🎯 Decision Matrix

| Scenario | Recommended Setup |
|----------|-------------------|
| **Private repo, solo dev** | ✅ Keep current (with defaults) |
| **Private repo, team** | ⚠️ Consider .env approach |
| **Public repo** | ❌ MUST remove defaults |
| **CI/CD pipeline** | ✅ Already secure (--dart-define) |
| **Client project** | ⚠️ Use .env or remove defaults |
| **Open source** | ❌ MUST remove defaults |

---

## 📊 Risk Assessment

### **Current Risk Level: 🟡 MEDIUM**

**Why Medium (not High):**
- ✅ It's the ANON key (public key), not service_role key
- ✅ Repository is currently private
- ✅ Environment variables override defaults
- ✅ CI/CD uses secure secrets

**Why not Low:**
- ⚠️ Key is visible in Git history
- ⚠️ Anyone with repo access can see it
- ⚠️ If repo goes public, key is exposed

---

## 🛠️ Immediate Actions Required

### **If Repository is Private:**
- [x] No immediate action required
- [ ] Consider rotating key every 90 days
- [ ] Monitor Supabase dashboard for unusual activity

### **If Repository is/will be Public:**
- [ ] **IMMEDIATELY** remove defaults from code
- [ ] **IMMEDIATELY** rotate the Supabase key
- [ ] **IMMEDIATELY** update all environments
- [ ] Add file to `.gitignore`

---

## 📞 Need Help?

**For Security Questions:**
1. Review Supabase security docs: https://supabase.com/docs/guides/auth/row-level-security
2. Check Flutter secure configuration: https://docs.flutter.dev/deployment/obfuscate
3. Review GitHub Actions security: https://docs.github.com/en/actions/security-guides/encrypted-secrets

---

## ✅ Summary

**Current Setup:**
- ✅ Contains real credentials (ANON key)
- ✅ Works for local development
- ✅ Secure in CI/CD (uses secrets)
- ⚠️ Not suitable for public repositories

**Recommendation:**
- For **private repos**: Current setup is acceptable
- For **public repos**: MUST remove defaults
- For **production**: Always use `--dart-define`

**Your Choice:** Keep current setup for development convenience, but be aware of the security implications!

---

**Last Updated:** 2026-03-08  
**Review Date:** 2026-06-08 (90 days)  
**Status:** ⚠️ **CONTAINS REAL CREDENTIALS - PRIVATE REPO ONLY**
