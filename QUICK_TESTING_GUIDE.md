# 🧪 Quick Testing Guide

**Purpose:** Get started with testing in the Aurora app

---

## 🚀 Quick Start

### Run All Tests
```bash
flutter test
```

### Run Specific Test
```bash
flutter test test/unit/utils/qr_data_generator_test.dart
```

---

## 📁 Test Files

### Unit Tests (`test/unit/`)
```bash
# Product models
flutter test test/unit/models/aurora_product_test.dart
flutter test test/unit/models/chat_models_test.dart

# Backend/Database
flutter test test/unit/backend/productsdb_test.dart
flutter test test/unit/backend/sellerdb_test.dart

# Services
flutter test test/unit/services/theme_provider_test.dart

# Utilities (QR Code)
flutter test test/unit/utils/qr_data_generator_test.dart
```

### Widget Tests (`test/widget/`)
```bash
# QR Code Dialog
flutter test test/widget/widgets/qr_code_dialog_test.dart
```

### Database Tests (`test/sql/`)
```sql
-- Open in Supabase SQL Editor
-- Execute all tests at once
test/sql/database_tests.sql
```

---

## 🐛 Bugs Found & Fixed

### Bug #1: Product URL Generation
**Test:** `getProductUrl generates URL if qrData is null`  
**Issue:** Method returned null when qrData is null  
**Fix:** Now generates URL from sellerId + asin as fallback  
**File:** `lib/models/aurora_product.dart`

### Bug #2: Share Text Null URL
**Test:** `Share text contains all required information`  
**Issue:** Shared messages had "null" instead of URL  
**Fix:** Fixed by Bug #1 (cascading fix)

---

## 📊 Coverage Status

| Type | Coverage | Tests | Status |
|------|----------|-------|--------|
| Unit | ~20% | 25+ | ✅ Passing |
| Widget | ~5% | 10 | ✅ Passing |
| Database (SQL) | 100% | 9 | ✅ Passing |
| **Total** | **~25%** | **44+** | **✅ Good Start** |

**Goal:** 75% coverage by end of month

---

## 🎯 Testing Priorities

### Phase 1: Critical ✅ (DONE)
- ✅ QR data generation tests
- ✅ QR dialog widget tests
- ✅ Database RLS tests (SQL)

### Phase 2: Core Features ⏳ (NEXT)
- ⏳ Authentication flow
- ⏳ Product creation
- ⏳ Chat real-time
- ⏳ Sales recording

### Phase 3: UI/UX ⏳ (PLANNED)
- ⏳ Product details screen
- ⏳ Record sale screen
- ⏳ Analytics dashboard

### Phase 4: Edge Cases ⏳ (PLANNED)
- ⏳ Error handling
- ⏳ Security tests
- ⏳ Performance tests

---

## 🔧 Writing New Tests

### Unit Test Template
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora/models/aurora_product.dart';

void main() {
  group('Feature Name', () {
    test('should do something', () {
      // Arrange
      final product = AuroraProduct(
        asin: 'TEST-001',
        // ...
      );
      
      // Act
      final result = product.someMethod();
      
      // Assert
      expect(result, expectedValue);
    });
  });
}
```

### Widget Test Template
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:aurora/widgets/some_widget.dart';

void main() {
  testWidgets('Widget displays correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SomeWidget()),
    );
    
    expect(find.text('Expected Text'), findsOneWidget);
  });
}
```

---

## 📚 Documentation

- [`TESTING_STRATEGY_AND_GAPS.md`](TESTING_STRATEGY_AND_GAPS.md) - Full strategy
- [`TESTING_IMPLEMENTATION_SUMMARY.md`](TESTING_IMPLEMENTATION_SUMMARY.md) - What we did
- [`README.md`](README.md) - Testing section

---

## ✅ Checklist

Before submitting code:

- [ ] New code has unit tests
- [ ] UI changes have widget tests
- [ ] All tests pass: `flutter test`
- [ ] Database changes have SQL tests
- [ ] No test failures

---

## 🆘 Common Issues

### Tests Fail with "MissingPluginException"
**Solution:** Database tests need mocking. See existing tests for examples.

### Tests Fail with "Null Check"
**Solution:** Add null checks or default values. See Bug #1 fix.

### Database Tests Don't Run
**Solution:** Run in Supabase SQL Editor, not with `flutter test`.

---

**Last Updated:** March 14, 2026  
**Status:** ✅ Active Testing
