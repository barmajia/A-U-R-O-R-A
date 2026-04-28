# Aurora Project Analysis & Refactoring Plan

## 📊 Current Project State

### Architecture Overview
- **Platform**: Flutter multi-vendor marketplace (Aurora)
- **Backend**: Supabase (PostgreSQL + Realtime + Edge Functions)
- **Local Storage**: Drift (SQLite), SharedPreferences, flutter_secure_storage
- **State Management**: Provider pattern
- **Total Dart Files**: 116 files
- **Main Entry**: `/lib/main.dart`

### Current Account Types
```dart
enum AccountType { 
  seller,      // ✅ Fully implemented
  customer,    // ⚠️ Partial (deprecated in some areas)
  factory,     // ❌ Not fully integrated
  distributor  // ❌ Not implemented
}
```

### Key Issues Identified

#### 1. **Duplicate Authentication Systems**
- `/lib/services/supabase.dart` (3,110 lines) - God class
- `/lib/services/auth_provider.dart` (538 lines) - Better separation
- Both define `AccountType` enum differently
- Factory auth pages use different implementations

#### 2. **Factory System Inconsistencies**
**Two sets of factory auth pages:**
- `/lib/pages/factory_auth/` - Connected to Supabase
  - `factory_login.dart` (217 lines)
  - `factory_signup.dart` (737 lines)
  
- `/lib/pages/auth/` - Fake/mock implementation
  - `factory_login_page.dart` (190 lines) - Uses fake delay
  - `factory_signup_page.dart` (~300 lines) - No real backend

**Problems:**
- Factory signup uses `AccountType.seller` instead of `AccountType.factory`
- No factory profile creation in database
- Welcome page routes to both sets of pages (confusion)

#### 3. **Code Duplication**
- Login logic duplicated across 3+ files
- Signup logic duplicated with minor variations
- Location permission code repeated 4+ times
- Country picker implementation repeated

#### 4. **Large Files (>500 lines)**
- `supabase.dart`: 3,110 lines ⚠️ Critical
- `signup.dart`: 822 lines ⚠️
- `factory_signup.dart`: 737 lines ⚠️
- `home.dart`: ~600 lines estimated

#### 5. **Missing Factory Features**
- No `AccountType.factory` handling in auth flow
- No factory profile table integration
- Factory dashboard exists but disconnected from auth
- No factory-specific repository pattern

---

## 🎯 Refactoring Strategy

### Phase 1: Clarify Requirements (YOUR INPUT NEEDED)

### Phase 2: Unified Authentication System
1. Create single source of truth for AccountType
2. Consolidate login/signup into reusable components
3. Add proper factory account type support
4. Remove duplicate auth pages

### Phase 3: Repository Pattern Expansion
1. Create `FactoryRepository` interface + impl
2. Create `SellerRepository` interface + impl
3. Migrate from direct DB access to repositories
4. Add caching layer

### Phase 4: Component Extraction
1. Extract common form fields to `app_text_field.dart` ✅ (done)
2. Extract buttons to `app_button.dart` ✅ (done)
3. Create `auth_form_widgets.dart`
4. Create `location_picker_widget.dart`
5. Create `country_picker_widget.dart`

### Phase 5: Factory App Cloning
1. Decide: Separate app vs. role-based single app
2. Create factory-specific navigation
3. Implement factory dashboard features
4. Connect to existing factory system

---

## ❓ CRITICAL QUESTIONS FOR YOU

### Question 1: Factory App Strategy
**Do you want:**
- **Option A**: Single app with role-based UI (Seller/Factory views)?
- **Option B**: Two separate Flutter apps (aurora_seller/, aurora_factory/)?
- **Option C**: Single app with flavor configurations?

**Recommendation**: Option A (easier maintenance, shared codebase)

---

### Question 2: Account Type Cleanup
**Current state**: `AccountType.factory` exists in enum but not used

**Should we:**
- **A**: Fully implement factory accounts with proper DB tables?
- **B**: Keep factories as a special seller subtype?
- **C**: Remove factory concept and use separate relationship model?

**Recommendation**: Option A (cleaner architecture)

---

### Question 3: Auth Page Consolidation
**We have 4 login/signup pages:**
1. `/lib/pages/singup/login.dart` - Seller login
2. `/lib/pages/singup/signup.dart` - Seller signup
3. `/lib/pages/factory_auth/factory_login.dart` - Factory login (real)
4. `/lib/pages/factory_auth/factory_signup.dart` - Factory signup (real)
5. `/lib/pages/auth/factory_login_page.dart` - Factory login (fake)
6. `/lib/pages/auth/factory_signup_page.dart` - Factory signup (fake)

**Action plan:**
- Delete fake pages (#5, #6)?
- Refactor #3, #4 to use shared components?
- Create unified auth flow with role selection?

---

### Question 4: Database Schema
**For factory accounts, do we need:**
- Separate `factories` table? ✅ (Already exists based on `aurora_factory.dart`)
- Link to `sellers` table (one-to-many)?
- Link to `users` table via `user_id`?
- All of the above?

---

### Question 5: Navigation Flow
**Current welcome page shows:**
- Customer → Coming soon
- Seller → Login/Signup
- Factory → Login/Signup  
- Middleman → Coming soon

**Should we:**
- Keep role selection on welcome screen?
- Auto-detect role after login?
- Separate apps entirely?

---

### Question 6: Data Migration
**Do you have:**
- Existing production data to preserve?
- Test data we can wipe/recreate?
- Specific schema requirements from current Supabase setup?

---

## 📋 Next Steps

1. **You answer the 6 questions above**
2. **I'll create detailed implementation plan**
3. **Start with authentication refactoring**
4. **Clone seller features for factory role**
5. **Test and validate**

---

## 🗂️ File Structure Summary

```
lib/
├── main.dart                    # Entry point
├── config/                      # Configuration
│   └── supabase_config.dart
├── core/                        # Core utilities ✅ Started
│   ├── exceptions/
│   │   └── app_exception.dart
│   └── result.dart
├── models/                      # Data models
│   ├── aurora_factory.dart      # Factory model
│   ├── seller.dart              # Seller model
│   └── ...
├── repositories/                # Repository pattern ✅ Started
│   ├── product_repository.dart
│   └── product_repository_impl.dart
├── services/                    # Business logic ⚠️ Needs refactoring
│   ├── supabase.dart            # 3110 lines - GOD CLASS
│   ├── auth_provider.dart       # 538 lines
│   └── ...
├── pages/                       # UI Screens ⚠️ Duplicated
│   ├── singup/                  # Seller auth
│   ├── factory_auth/            # Factory auth (real)
│   ├── auth/                    # Factory auth (fake) ⚠️ Delete?
│   ├── factory/                 # Factory screens
│   ├── seller/                  # Seller screens
│   └── user/                    # User screens
└── widgets/                     # Reusable components ✅ Started
    └── common/
        ├── app_button.dart
        ├── app_text_field.dart
        └── common_widgets.dart
```

---

## ✅ Already Completed (Previous Session)

1. ✅ Exception hierarchy created
2. ✅ Result type pattern implemented
3. ✅ Product repository pattern started
4. ✅ Common UI components (Button, TextField)
5. ✅ Documentation created

---

**Please answer the 6 questions above so I can proceed with the correct implementation strategy!**
