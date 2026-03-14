# 🧪 Aurora Testing Strategy & Gap Analysis

**Purpose:** Identify gaps, bugs, and areas for improvement in the Aurora E-commerce Marketplace

**Date:** March 14, 2026

---

## 📊 Testing Overview

### Current Status (March 2026)

| Test Type | Status | Coverage | Issues Found |
|-----------|--------|----------|--------------|
| **Unit Tests** | ⚠️ Partial | ~15% | 15 failing tests |
| **Widget Tests** | ❌ Missing | 0% | Unknown |
| **Integration Tests** | ❌ Missing | 0% | Unknown |
| **Database Tests (RLS)** | ❌ Missing | 0% | Critical gap |
| **E2E Tests** | ❌ Missing | 0% | Unknown |

---

## 🎯 Testing Priorities

### Priority 1: Critical Gaps (Test Immediately)

1. **Authentication Flow** - Login/Signup/Logout
2. **Product Creation** - Edge function integration
3. **QR Code Generation** - SKU creation and storage
4. **Database RLS Policies** - Security isolation
5. **Share Feature** - Android 11+ compatibility

### Priority 2: High Impact

1. **Chat System** - Real-time messaging
2. **Sales Recording** - Customer linkage
3. **Analytics Dashboard** - Data accuracy
4. **Payment Methods** - CRUD operations
5. **Image Upload** - Storage integration

### Priority 3: Medium Impact

1. **Customer Management** - CRUD operations
2. **Factory System** - Discovery and linking
3. **Wishlist** - Add/remove functionality
4. **Address Management** - Save/update/delete
5. **Theme Switching** - Dark/Light mode

---

## 📁 Test Directory Structure

```
test/
├── helpers/
│   ├── supabase_test_helper.dart
│   ├── test_data_factory.dart
│   ├── mock_supabase_simple.dart ✅ (exists)
│   └── test_helpers.dart ✅ (exists)
├── unit/
│   ├── models/
│   │   ├── aurora_product_test.dart ✅
│   │   ├── chat_models_test.dart ✅
│   │   ├── customer_test.dart ❌
│   │   ├── sale_test.dart ❌
│   │   └── payment_method_test.dart ❌
│   ├── services/
│   │   ├── supabase_test.dart ❌
│   │   ├── chat_provider_test.dart ❌
│   │   ├── queue_service_test.dart ❌
│   │   └── theme_provider_test.dart ✅
│   ├── utils/
│   │   ├── sku_generator_test.dart ❌
│   │   ├── qr_data_builder_test.dart ❌
│   │   └── price_formatter_test.dart ❌
│   └── backend/
│       ├── productsdb_test.dart ✅
│       └── sellerdb_test.dart ✅
├── widget/
│   ├── pages/
│   │   ├── product_details_screen_test.dart ❌
│   │   ├── product_form_screen_test.dart ❌
│   │   ├── record_sale_screen_test.dart ❌
│   │   ├── chat_list_screen_test.dart ❌
│   │   └── analytics_page_test.dart ❌
│   └── widgets/
│       ├── product_card_test.dart ❌
│       ├── qr_code_dialog_test.dart ❌
│       ├── deal_proposal_card_test.dart ❌
│       └── drawer_test.dart ❌
├── integration/
│   ├── auth_flow_test.dart ❌
│   ├── product_crud_test.dart ❌
│   ├── chat_realtime_test.dart ❌
│   ├── cart_sync_test.dart ❌
│   ├── share_feature_test.dart ❌
│   └── qr_code_generation_test.dart ❌
└── sql/
    ├── rls_policies_test.sql ❌
    ├── triggers_test.sql ❌
    └── edge_functions_test.sql ❌
```

**Legend:** ✅ Exists | ❌ Missing (Gap)

---

## 🔍 Identified Gaps

### Gap #1: Database Security (CRITICAL)

**Issue:** No tests for Row Level Security (RLS) policies

**Risk:** Data leakage between sellers, unauthorized access

**Test Required:**
```sql
-- test/sql/rls_policies_test.sql

-- Test 1: Seller cannot view another seller's products
BEGIN;
  -- Create test sellers
  -- Insert products for seller A
  -- Try to query as seller B
  -- Should return 0 rows
ROLLBACK;

-- Test 2: Only active products visible to buyers
BEGIN;
  -- Insert draft product
  -- Query as buyer
  -- Should not see draft product
ROLLBACK;

-- Test 3: Cart isolation
BEGIN;
  -- Insert cart items for user A
  -- Query as user B
  -- Should return empty
ROLLBACK;
```

**Impact:** 🔴 High - Security vulnerability

---

### Gap #2: Product Creation Flow (CRITICAL)

**Issue:** Edge function 503 errors, no integration tests

**Risk:** Products not created, revenue loss

**Test Required:**
```dart
// test/integration/product_creation_test.dart

testWidgets('Create product with edge function', (tester) async {
  // 1. Login as seller
  // 2. Navigate to product creation
  // 3. Fill form
  // 4. Submit
  // 5. Verify in Supabase database
  // 6. Verify QR code generated
  // 7. Verify SKU assigned
});
```

**Impact:** 🔴 High - Core functionality broken

---

### Gap #3: QR Code & SKU Generation (HIGH)

**Issue:** QR data not saving to Supabase (missing column)

**Risk:** Products unshareable, no QR codes

**Test Required:**
```dart
// test/unit/utils/qr_data_builder_test.dart

test('QR data contains all required fields', () {
  final product = AuroraProduct(
    asin: 'ASN-123',
    sku: 'SKU-456',
    sellerId: 'seller-uuid',
    title: 'Test Product',
    price: 19.99,
  );
  
  final qrData = product.generateQRData();
  final decoded = jsonDecode(qrData);
  
  expect(decoded['asin'], 'ASN-123');
  expect(decoded['sku'], 'SKU-456');
  expect(decoded['seller_id'], 'seller-uuid');
  expect(decoded['url'], contains('aurora-app.com'));
});

test('QR data saved to database', () async {
  // Insert product
  // Query database
  // Verify qr_data column is not null
});
```

**Impact:** 🟠 Medium-High - Feature partially broken

---

### Gap #4: Share Feature on Android (MEDIUM)

**Issue:** Share button not working on Android 11+

**Risk:** Users can't share products, reduced marketing

**Test Required:**
```dart
// test/integration/share_feature_test.dart

testWidgets('Share QR code via native dialog', (tester) async {
  // 1. Open product details
  // 2. Tap QR code button
  // 3. Tap Share button
  // 4. Verify share dialog appears
  // 5. Verify share text contains:
  //    - Product name
  //    - ASIN & SKU
  //    - Product link
});

testWidgets('Share product link', (tester) async {
  // 1. Open QR dialog
  // 2. Tap share icon in link section
  // 3. Verify share text contains URL
});
```

**Impact:** 🟡 Medium - Fixed in AndroidManifest (needs testing)

---

### Gap #5: Chat Real-time Updates (HIGH)

**Issue:** No tests for real-time message delivery

**Risk:** Messages not delivered, poor UX

**Test Required:**
```dart
// test/integration/chat_realtime_test.dart

testWidgets('Real-time message delivery', (tester) async {
  // 1. Setup conversation between User A and User B
  // 2. User A sends message
  // 3. Verify User B receives immediately (without refresh)
  // 4. Verify conversation updated_at triggers
  // 5. Verify message count increments
});
```

**Impact:** 🟠 High - Core feature untested

---

### Gap #6: Analytics Accuracy (MEDIUM)

**Issue:** No validation of analytics calculations

**Risk:** Wrong business insights, poor decisions

**Test Required:**
```dart
// test/unit/services/analytics_service_test.dart

test('Calculate total revenue correctly', () async {
  // Insert 3 sales: $10, $20, $30
  // Call analytics service
  // Expect total = $60
});

test('Top customers ranking', () async {
  // Create customers with different spend amounts
  // Call top customers function
  // Verify order matches spend amount
});

test('Daily sales trend accuracy', () async {
  // Insert sales on different dates
  // Query daily trend
  // Verify each day's total is correct
});
```

**Impact:** 🟡 Medium - Business intelligence reliability

---

### Gap #7: Image Upload & Storage (MEDIUM)

**Issue:** No tests for image upload flow

**Risk:** Images not saved, broken product listings

**Test Required:**
```dart
// test/integration/image_upload_test.dart

testWidgets('Upload product image to Supabase Storage', (tester) async {
  // 1. Create product
  // 2. Upload image
  // 3. Verify image URL saved to product.images
  // 4. Verify image accessible via public URL
  // 5. Verify bucket permissions
});

testWidgets('Delete product image', (tester) async {
  // 1. Upload image
  // 2. Delete image
  // 3. Verify removed from product
  // 4. Verify deleted from storage bucket
});
```

**Impact:** 🟡 Medium - Product presentation

---

### Gap #8: Payment Methods CRUD (MEDIUM)

**Issue:** No tests for payment methods (TODO in code)

**Risk:** Payment data not saved correctly

**Test Required:**
```dart
// test/integration/payment_methods_test.dart

testWidgets('Add payment method', (tester) async {
  // 1. Navigate to payment methods
  // 2. Add new card
  // 3. Verify saved to database
  // 4. Verify card preview displays correctly
});

testWidgets('Set default payment method', (tester) async {
  // 1. Add 2 payment methods
  // 2. Set one as default
  // 3. Verify default flag in database
  // 4. Verify UI shows "Default" badge
});

testWidgets('Delete payment method', (tester) async {
  // 1. Add payment method
  // 2. Delete with confirmation
  // 3. Verify removed from database
});
```

**Impact:** 🟡 Medium - Checkout flow

---

### Gap #9: Customer Management (LOW)

**Issue:** Customer features not connected to backend (TODO in code)

**Risk:** Customer data not syncing

**Test Required:**
```dart
// test/integration/customer_management_test.dart

testWidgets('Add customer', (tester) async {
  // 1. Navigate to add customer
  // 2. Fill form
  // 3. Save
  // 4. Verify in database
  // 5. Verify appears in customer list
});

testWidgets('Customer statistics auto-update', (tester) async {
  // 1. Create customer
  // 2. Record sale linked to customer
  // 3. Verify customer.total_orders incremented
  // 4. Verify customer.total_spent updated
  // 5. Verify customer.last_purchase_date updated
});
```

**Impact:** 🟢 Low-Medium - Documented as TODO

---

### Gap #10: Offline & Sync (LOW)

**Issue:** No tests for offline mode and sync

**Risk:** Data loss when offline

**Test Required:**
```dart
// test/integration/offline_sync_test.dart

testWidgets('Create product offline, sync when online', (tester) async {
  // 1. Disable network
  // 2. Create product (saves to local SQLite)
  // 3. Enable network
  // 4. Verify syncs to Supabase
  // 5. Verify isSynced = true
});

testWidgets('View cached products when offline', (tester) async {
  // 1. Load products online
  // 2. Disable network
  // 3. Navigate to products page
  // 4. Verify products load from cache
});
```

**Impact:** 🟢 Low - Nice to have

---

## 🚀 Testing Implementation Plan

### Phase 1: Critical Tests (Week 1)

**Goal:** Fix immediate gaps

1. ✅ **Database RLS Tests** (SQL)
   - Seller isolation
   - Product visibility
   - Cart isolation

2. ✅ **Product Creation Integration** (Dart)
   - Edge function call
   - Database insert
   - QR code generation

3. ✅ **QR Data Column Verification** (SQL)
   - Verify column exists
   - Verify data saved

**Deliverable:** Critical gaps closed

---

### Phase 2: Core Features (Week 2)

**Goal:** Test main user flows

1. ✅ **Authentication Flow**
   - Login
   - Signup
   - Logout
   - Session persistence

2. ✅ **Chat Real-time**
   - Send message
   - Receive message
   - Conversation updates

3. ✅ **Sales Recording**
   - Record sale
   - Link customer
   - Update analytics

**Deliverable:** Core flows tested

---

### Phase 3: UI/UX (Week 3)

**Goal:** Test user interface

1. ✅ **Widget Tests**
   - Product details screen
   - Record sale screen
   - Chat list screen
   - QR code dialog

2. ✅ **Share Feature**
   - Share QR code
   - Share product link
   - Copy to clipboard

3. ✅ **Theme & Settings**
   - Dark/Light mode
   - Biometric auth
   - Location permissions

**Deliverable:** UI tested

---

### Phase 4: Edge Cases (Week 4)

**Goal:** Test error scenarios

1. ✅ **Error Handling**
   - Network failures
   - Invalid input
   - Database errors

2. ✅ **Edge Functions**
   - Timeout handling
   - Retry logic
   - Fallback behavior

3. ✅ **Security**
   - Unauthorized access
   - SQL injection prevention
   - XSS prevention

**Deliverable:** Robust error handling

---

## 📊 Test Coverage Goals

| Component | Current | Goal (Month 1) | Goal (Month 3) |
|-----------|---------|----------------|----------------|
| **Models** | 15% | 60% | 90% |
| **Services** | 5% | 50% | 80% |
| **Widgets** | 0% | 40% | 70% |
| **Integration** | 0% | 30% | 60% |
| **Database (RLS)** | 0% | 100% | 100% |
| **Overall** | ~5% | 50% | 75% |

---

## 🛠️ Testing Tools & Setup

### Required Packages

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mockito: ^5.4.4
  mocktail: ^1.0.3
  build_runner: ^2.4.8
  fake_async: ^1.3.1
  supabase_test: ^1.0.0  # For RLS testing
```

### Test Helper Setup

```dart
// test/helpers/supabase_test_helper.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTestHelper {
  static String get testUrl => 'https://test-project.supabase.co';
  static String get testAnonKey => 'test-anon-key';
  
  static Future<void> setupTestDatabase() async {
    // Initialize test Supabase client
    await Supabase.initialize(
      url: testUrl,
      anonKey: testAnonKey,
    );
  }
  
  static Future<void> cleanupTestData() async {
    // Delete all test data
    final supabase = Supabase.instance.client;
    await supabase.from('products').delete().neq('id', '0000-0000');
    await supabase.from('customers').delete().neq('id', '0000-0000');
    // ... cleanup all tables
  }
}
```

### Test Data Factory

```dart
// test/helpers/test_data_factory.dart

class TestDataFactory {
  static AuroraProduct createProduct({
    String? asin,
    String? sku,
    String? sellerId,
    double price = 19.99,
  }) {
    return AuroraProduct(
      asin: asin ?? 'ASN-${DateTime.now().millisecondsSinceEpoch}',
      sku: sku ?? 'SKU-${DateTime.now().millisecondsSinceEpoch}',
      sellerId: sellerId ?? 'test-seller-id',
      title: 'Test Product',
      price: price,
      quantity: 10,
      status: 'active',
    );
  }
  
  static Customer createCustomer({
    String? name,
    String? phone,
  }) {
    return Customer(
      id: 'customer-${DateTime.now().millisecondsSinceEpoch}',
      name: name ?? 'Test Customer',
      phone: phone ?? '+1234567890',
      sellerId: 'test-seller-id',
    );
  }
}
```

---

## 📈 Running Tests

### Unit & Widget Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/unit/models/aurora_product_test.dart

# Run tests matching pattern
flutter test --plain-name "QR Data"

# Run tests in directory
flutter test test/unit/
```

### Integration Tests

```bash
# Requires connected device/emulator
flutter test integration_test/

# Run specific integration test
flutter test integration_test/product_crud_test.dart
```

### Database Tests (SQL)

```bash
# Using Supabase CLI
supabase db test

# Or run SQL files manually
psql -h db.project.supabase.co -U postgres -d postgres -f test/sql/rls_policies_test.sql
```

### CI/CD Integration

```yaml
# .github/workflows/test.yml

name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Run unit tests
        run: flutter test --coverage
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

---

## ✅ Test Checklist

### Database Layer

- [ ] RLS: Sellers can only view their own products
- [ ] RLS: Buyers can only view active products
- [ ] RLS: Users can only view their own cart
- [ ] RLS: Users can only view their own orders
- [ ] Trigger: Inventory decrements on order
- [ ] Trigger: Analytics update on sale
- [ ] Trigger: Conversation updates on message
- [ ] Function: calculate_seller_analytics returns correct data
- [ ] Function: get_top_customers returns correct ranking
- [ ] Column: qr_data exists in products table

### Unit Tests

- [ ] Product model serialization
- [ ] Customer model serialization
- [ ] Sale model serialization
- [ ] QR data generation
- [ ] SKU generation
- [ ] Price formatting
- [ ] Date formatting
- [ ] Chat message serialization
- [ ] Deal proposal validation

### Widget Tests

- [ ] Product details displays correctly
- [ ] Product form validation
- [ ] Record sale screen calculation
- [ ] Chat list displays messages
- [ ] QR code dialog shows data
- [ ] Analytics dashboard KPIs
- [ ] Payment method card preview
- [ ] Customer details screen
- [ ] Drawer navigation

### Integration Tests

- [ ] Login flow
- [ ] Signup flow
- [ ] Create product
- [ ] Update product
- [ ] Delete product
- [ ] Record sale
- [ ] Add customer
- [ ] Send chat message
- [ ] Share QR code
- [ ] Share product link
- [ ] Upload image
- [ ] Add to cart
- [ ] Create order

### Security Tests

- [ ] Unauthorized access blocked
- [ ] SQL injection prevented
- [ ] XSS prevented
- [ ] CSRF tokens validated
- [ ] Rate limiting works
- [ ] Auth tokens expire correctly

---

## 🎯 Next Steps

### Immediate (This Week)

1. **Fix Failing Tests** - 15 tests currently failing
2. **Add QR Data Column** - Run migration in Supabase
3. **Deploy Edge Functions** - Fix 503 errors
4. **Create RLS Test Suite** - Verify security

### Short Term (2-4 Weeks)

1. **Reach 50% Coverage** - Focus on critical paths
2. **Test All User Flows** - Login to purchase
3. **Automate in CI/CD** - GitHub Actions
4. **Document Test Cases** - Testing guide

### Long Term (1-3 Months)

1. **Reach 75% Coverage** - Industry standard
2. **Performance Tests** - Load testing
3. **Accessibility Tests** - WCAG compliance
4. **Security Audit** - Penetration testing

---

## 📚 Additional Resources

- [Flutter Testing Docs](https://docs.flutter.dev/testing)
- [Supabase Testing Guide](https://supabase.com/docs/guides/testing)
- [Integration Testing Best Practices](https://docs.flutter.dev/testing/integration-tests)
- [Mockito for Flutter](https://pub.dev/packages/mockito)

---

**Status:** 📋 Plan Created  
**Next Action:** Start Phase 1 - Critical Tests  
**Owner:** Development Team
