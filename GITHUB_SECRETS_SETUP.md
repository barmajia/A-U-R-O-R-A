# 🔐 GitHub Secrets Setup Guide

**For:** Aurora E-commerce Flutter App  
**Date:** 2026-03-08  
**Status:** ✅ **READY TO CONFIGURE**

---

## 📋 Required Secrets

You need to configure the following secrets in your GitHub repository:

### **Mandatory Secrets:**

| Secret Name | Description | Where to Get |
|-------------|-------------|--------------|
| `SUPABASE_URL` | Your Supabase project URL | Supabase Dashboard → Settings → API |
| `SUPABASE_ANON_KEY` | Supabase anonymous/public key | Supabase Dashboard → Settings → API |

### **Optional Secrets (for deployment):**

| Secret Name | Description | Where to Get |
|-------------|-------------|--------------|
| `FIREBASE_APP_ID` | Firebase App Distribution ID | Firebase Console |
| `FIREBASE_SERVICE_ACCOUNT` | Firebase service account JSON | Firebase Console → Project Settings → Service Accounts |

---

## 🚀 Step-by-Step Setup

### **Step 1: Get Supabase Credentials**

1. **Go to Supabase Dashboard**
   - Visit: https://supabase.com/dashboard
   - Select your project: `ofovfxsfazlwvcakpuer`

2. **Navigate to API Settings**
   - Click **Settings** (sidebar)
   - Click **API**
   - You'll see your project credentials

3. **Copy Credentials**
   ```
   Project URL: https://ofovfxsfazlwvcakpuer.supabase.co
   anon/public key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

   ⚠️ **IMPORTANT:** Copy the `anon` key (public key), NOT the `service_role` key!

---

### **Step 2: Add Secrets to GitHub**

1. **Go to GitHub Repository**
   - Visit: https://github.com/YOUR_USERNAME/YOUR_REPO
   - Click **Settings** tab

2. **Navigate to Secrets**
   - Click **Secrets and variables** (sidebar)
   - Click **Actions**
   - Click **New repository secret**

3. **Add SUPABASE_URL**
   ```
   Name: SUPABASE_URL
   Value: https://ofovfxsfazlwvcakpuer.supabase.co
   ```
   Click **Add secret**

4. **Add SUPABASE_ANON_KEY**
   ```
   Name: SUPABASE_ANON_KEY
   Value: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... (your full key)
   ```
   Click **Add secret**

---

### **Step 3: Verify Secrets**

Your secrets should look like this:

```
Repository secrets:
├── SUPABASE_URL          (set)
└── SUPABASE_ANON_KEY     (set)
```

---

## 🧪 Test the Workflow

### **Manual Trigger:**

1. Go to **Actions** tab in GitHub
2. Click on **Build Flutter App** workflow
3. Click **Run workflow** button
4. Select branch (main)
5. Click **Run workflow**

### **Automatic Trigger:**

The workflow will automatically run when you:
- ✅ Push to `main` branch
- ✅ Push to `develop` branch
- ✅ Create a pull request to `main`

---

## 📦 What the Workflow Does

### **Build Job:**

1. ✅ **Checkout code** - Downloads your repository
2. ✅ **Setup Java** - Installs Java 11 (required for Android)
3. ✅ **Setup Flutter** - Installs Flutter 3.x stable
4. ✅ **Install dependencies** - Runs `flutter pub get`
5. ✅ **Analyze code** - Runs `flutter analyze` (checks for errors)
6. ✅ **Run tests** - Runs `flutter test`
7. ✅ **Build APK** - Creates release APK with secure config
8. ✅ **Build App Bundle** - Creates AAB for Google Play
9. ✅ **Upload artifacts** - Saves build files for 30 days
10. ✅ **Create release** - (If on main branch) Creates GitHub release

### **Outputs:**

**Artifacts (available for 30 days):**
- `app-release-apk` - Android APK file
- `app-release-bundle` - Android App Bundle (AAB)

**GitHub Release (if on main):**
- Tag: `v1.0.0+<build_number>`
- Includes APK and AAB downloads
- Auto-generated release notes

---

## 🔒 Security Best Practices

### **DO:**
- ✅ Use repository secrets (not environment variables)
- ✅ Rotate keys regularly (every 90 days recommended)
- ✅ Use different keys for dev/staging/production
- ✅ Monitor secret access in GitHub audit log
- ✅ Limit workflow permissions

### **DON'T:**
- ❌ Commit keys to code
- ❌ Share keys via email/chat
- ❌ Use production keys in development
- ❌ Print keys in logs
- ❌ Use service_role key (only use anon key)

---

## 🔄 Rotating Keys

### **When to Rotate:**
- Every 90 days (best practice)
- If key is compromised
- If team member leaves
- After security audit

### **How to Rotate:**

1. **Generate New Key in Supabase**
   - Go to Supabase Dashboard
   - Settings → API
   - Click **Regenerate** next to anon key
   - Copy new key

2. **Update GitHub Secret**
   - Go to GitHub → Settings → Secrets
   - Click on `SUPABASE_ANON_KEY`
   - Paste new key
   - Click **Update secret**

3. **Test**
   - Trigger workflow manually
   - Verify build succeeds
   - Test app connects to Supabase

---

## 🛠️ Troubleshooting

### **Error: "Secret not found"**

**Symptoms:**
```
⚠️ CONFIGURATION ERROR: Supabase anonymous key is empty
```

**Solution:**
1. Verify secret name is exactly `SUPABASE_ANON_KEY` (case-sensitive)
2. Check secret is set in correct repository
3. Re-add the secret (delete and create again)

### **Error: "Invalid API key"**

**Symptoms:**
```
PostgrestException: Invalid API key
```

**Solution:**
1. Verify you're using `anon` key, not `service_role` key
2. Check key hasn't expired
3. Regenerate key in Supabase
4. Update GitHub secret

### **Error: "Build failed"**

**Symptoms:**
```
Error: ADB command failed
```

**Solution:**
1. Check Flutter version in workflow matches your project
2. Verify `pubspec.yaml` dependencies are correct
3. Run `flutter clean` locally and push changes

---

## 📊 Workflow Status

### **View Build Status:**

1. Go to **Actions** tab
2. Click on workflow run
3. View logs for each step

### **Download Artifacts:**

1. Go to workflow run
2. Scroll to bottom
3. Click on artifact name
4. Download starts automatically

### **View Releases:**

1. Go to **Releases** tab
2. Click on latest release
3. Download APK or AAB

---

## 🎯 Advanced Configuration

### **Build Specific Branches:**

Edit `.github/workflows/build.yml`:

```yaml
on:
  push:
    branches: [main, develop, release/*]
```

### **Skip Tests:**

```yaml
- name: Run Tests
  run: flutter test
  if: false # Disable tests
```

### **Custom Build Number:**

```yaml
- name: Build APK
  run: flutter build apk \
    --build-number=${{ github.run_number }}
```

### **Deploy to Google Play:**

Add step after build:

```yaml
- name: Deploy to Google Play
  uses: r0adkll/upload-google-play@v1
  with:
    serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
    packageName: com.example.aurora
    releaseFiles: build/app/outputs/bundle/release/app-release.aab
    track: internal
```

---

## 📝 Checklist

Before your first build:

- [ ] Added `SUPABASE_URL` secret
- [ ] Added `SUPABASE_ANON_KEY` secret
- [ ] Verified workflow file exists
- [ ] Pushed code to GitHub
- [ ] Triggered workflow manually
- [ ] Verified build succeeded
- [ ] Downloaded and tested APK
- [ ] Created first release

---

## 🎉 Success!

Once configured, your workflow will:

✅ **Automatically build** on every push  
✅ **Securely manage** credentials  
✅ **Generate releases** automatically  
✅ **Provide artifacts** for testing  
✅ **Ensure quality** with analysis and tests  

**Your CI/CD pipeline is production-ready!** 🚀

---

**Setup Date:** 2026-03-08  
**Status:** ✅ **READY**  
**Next:** Add secrets and trigger first build!
