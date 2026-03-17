# Aurora E-commerce - Test Suite

> Comprehensive testing suite for the Aurora E-commerce platform

[![Test Status](https://img.shields.io/badge/tests-45%20tests-blue)]()
[![Coverage](https://img.shields.io/badge/coverage-~25%25-orange)]()
[![Flutter](https://img.shields.io/badge/Flutter-3.10.7-blue)]()

---

## 📖 Table of Contents

- [Quick Start](#quick-start)
- [Test Organization](#test-organization)
- [Running Tests](#running-tests)
- [Writing Tests](#writing-tests)
- [Test Coverage](#test-coverage)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Test Files](#test-files)
- [Resources](#resources)

---

## 🚀 Quick Start

### Run All Tests

```bash
# Windows (Command Prompt)
test.bat

# Windows (PowerShell)
.\test.ps1

# Direct Flutter command
flutter test
```

### Run with Coverage

```bash
# Windows (Command Prompt)
test.bat coverage

# Windows (PowerShell)
.\test.ps1 coverage

# Generate HTML report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
start coverage/html/index.html
```

---

## 📁 Test Organization

### Directory Structure

```
test/
├── helpers/                    # Test utilities
│   ├── test_helpers.dart       # Common test functions
│   └── test_data.dart          # Test data generators
├── mocks/                      # Mock implementations
│   ├── mocks.dart              # Comprehensive mocks
│   └── mock_supabase_simple.dart
├── unit/                       # Unit tests
│   ├── models/                 # Data model tests
│   │   ├── aurora_product_test.dart
│   │   ├── chat_models_test.dart
│   │   └── seller_test.dart
│   ├── services/               # Service layer tests
│   │   ├── auth_provider_test.dart
│   │   ├── product_provider_test.dart
│   │   ├── notification_service_test.dart
│   │   ├── presence_service_test.dart
│   │   ├── error_handler_test.dart
│   │   ├── cache_and_rate_limiter_test.dart
│   │   └── theme_provider_test.dart
│   ├── backend/                # Database tests
│   │   ├── sellerdb_test.dart
│   │   └── productsdb_test.dart
│   └── utils/                  # Utility tests
│       └── qr_data_generator_test.dart
├── widget/                     # Widget tests
│   ├── pages/                  # Page/screen tests
│   │   ├── login_page_test.dart
│   │   └── notifications_screen_test.dart
│   └── widgets/                # Component tests
│       ├── app_drawer_test.dart
│       └── qr_code_dialog_test.dart
├── integration/                # Integration tests
│   └── auth_flow_test.dart
├── sql/                        # SQL test scripts
└── README.md                   # This file
```

### Test Categories

| Category        | Location            | Purpose                           | Target Coverage |
| --------------- | ------------------- | --------------------------------- | --------------- |
| **Unit**        | `test/unit/`        | Test individual classes/functions | 90%             |
| **Widget**      | `test/widget/`      | Test UI components                | 70%             |
| **Integration** | `test/integration/` | Test feature flows                | 50%             |

---

## 🧪 Running Tests

### Test Commands

| Command                                                  | Description                     |
| -------------------------------------------------------- | ------------------------------- |
| `flutter test`                                           | Run all tests                   |
| `flutter test --coverage`                                | Run tests with coverage report  |
| `flutter test test/unit/`                                | Run unit tests only             |
| `flutter test test/widget/`                              | Run widget tests only           |
| `flutter test test/integration/`                         | Run integration tests only      |
| `flutter test test/unit/models/aurora_product_test.dart` | Run specific test file          |
| `flutter test --plain-name "AuroraProduct"`              | Run tests matching name pattern |
| `flutter test --tags smoke`                              | Run tests with specific tag     |
| `flutter test --exclude-tags slow`                       | Exclude tests with tag          |

### Using Test Scripts

**test.bat** (Windows Command Prompt):

```batch
test.bat                  # Run all tests
test.bat unit             # Run unit tests
test.bat widget           # Run widget tests
test.bat coverage         # Run with coverage report
test.bat file <file.dart> # Run specific test file
test.bat name <pattern>   # Run tests matching pattern
```

**test.ps1** (Windows PowerShell):

```powershell
.\test.ps1                  # Run all tests
.\test.ps1 unit             # Run unit tests
.\test.ps1 widget           # Run widget tests
.\test.ps1 coverage         # Run with coverage report
.\test.ps1 file <file.dart> # Run specific test file
.\test.ps1 name <pattern>   # Run tests matching pattern
```

---

## ✍️ Writing Tests

### Unit Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora/models/your_model.dart';

void main() {
  group('ClassName', () {
    setUp(() {
      // Setup before each test
    });

    tearDown(() {
      // Cleanup after each test
    });

    test('should do something', () {
      // Arrange
      final expected = 'value';

      // Act
      final actual = methodUnderTest();

      // Assert
      expect(actual, expected);
    });
  });
}
```

### Widget Test Template

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora/widgets/my_widget.dart';

void main() {
  testWidgets('Widget should display correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyWidget(),
      ),
    );

    expect(find.byType(MyWidget), findsOneWidget);
    expect(find.text('Expected Text'), findsOneWidget);
  });
}
```

### Integration Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aurora/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Complete user flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Step 1: Login
    await tester.enterText(find.byKey(Key('email')), 'test@example.com');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // Verify navigation
    expect(find.text('Welcome'), findsOneWidget);
  });
}
```

---

## 📊 Test Coverage

### Generate Coverage Report

```bash
# Run tests with coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open in browser (Windows)
start coverage/html/index.html
```

### Coverage Goals

| Component     | Target | Current |
| ------------- | ------ | ------- |
| **Models**    | 95%    | ~90%    |
| **Services**  | 90%    | ~40%    |
| **Providers** | 85%    | ~30%    |
| **Pages**     | 70%    | ~10%    |
| **Widgets**   | 80%    | ~15%    |
| **Overall**   | 80%    | ~25%    |

### View Coverage by File

```bash
# Extract coverage for specific file
lcov --extract coverage/lcov.info "*/lib/services/auth_provider.dart" -o filtered.info
genhtml filtered.info -o coverage/auth_provider
```

---

## 🏆 Best Practices

### 1. Naming Convention

Use descriptive test names:

```dart
test('should_return_value_when_condition', () { ... });
test('should_throw_exception_when_invalid_input', () { ... });
test('should_update_state_on_success', () { ... });
```

### 2. AAA Pattern (Arrange-Act-Assert)

```dart
test('should calculate total correctly', () {
  // Arrange
  final cart = Cart(items: [
    CartItem(price: 10, quantity: 2),
  ]);

  // Act
  final total = cart.calculateTotal();

  // Assert
  expect(total, 20);
});
```

### 3. Test Independence

Each test should be independent and not rely on other tests:

```dart
// GOOD
test('test 1', () {
  final product = createTestProduct(); // Fresh instance
  // ...
});

test('test 2', () {
  final product = createTestProduct(); // Fresh instance
  // ...
});
```

### 4. Mock External Dependencies

```dart
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

// In test
final mockAuth = MockAuthService();
when(() => mockAuth.login(any(), any())).thenAnswer((_) async => true);
```

### 5. Test Edge Cases

```dart
group('divide', () {
  test('should divide normally', () { ... });
  test('should handle zero numerator', () { ... });
  test('should throw on zero denominator', () { ... });
  test('should handle negative numbers', () { ... });
});
```

---

## 🔧 Troubleshooting

### MissingPluginException

**Problem:**

```
MissingPluginException(No implementation found for method
getApplicationDocumentsDirectory on channel plugins.flutter.io/path_provider)
```

**Solution:** Mock method channels in test setup:

```dart
setUpAll(() async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (message) async {
    if (message.method == 'getApplicationDocumentsDirectory') {
      return '/documents';
    }
    return null;
  });
});
```

### Test Timeout

**Problem:** Test times out after 30 seconds

**Solution:** Increase timeout

```dart
test('long running test', () async {
  // ...
}, timeout: Timeout(Duration(minutes: 2)));
```

### Widget Not Found

**Problem:** `Expected: exactly one matching node, got 0`

**Solutions:**

1. Pump and settle animations: `await tester.pumpAndSettle();`
2. Check widget key is correct
3. Verify widget is in tree

### Mock Not Working

**Problem:** Mock returns null or wrong value

**Solution:** Setup mock properly

```dart
// For sync methods
when(() => mock.method()).thenReturn(expectedValue);

// For async methods
when(() => mock.asyncMethod()).thenAnswer((_) async => expectedValue);
```

---

## 📄 Test Files

### Unit Tests (11 files)

| File                               | Tests | Coverage | Status |
| ---------------------------------- | ----- | -------- | ------ |
| `aurora_product_test.dart`         | 25    | 95%      | ✅     |
| `chat_models_test.dart`            | 12    | 90%      | ✅     |
| `seller_test.dart`                 | 8     | 85%      | ✅     |
| `auth_provider_test.dart`          | 20    | 85%      | ✅ New |
| `product_provider_test.dart`       | 25    | 85%      | ✅ New |
| `notification_service_test.dart`   | 10    | 80%      | ✅     |
| `presence_service_test.dart`       | 8     | 75%      | ✅     |
| `error_handler_test.dart`          | 12    | 90%      | ✅     |
| `cache_and_rate_limiter_test.dart` | 15    | 85%      | ✅     |
| `theme_provider_test.dart`         | 10    | 80%      | ✅     |
| `qr_data_generator_test.dart`      | 8     | 90%      | ✅     |

### Widget Tests (4 files)

| File                             | Tests | Coverage | Status |
| -------------------------------- | ----- | -------- | ------ |
| `login_page_test.dart`           | 12    | 70%      | ✅ New |
| `notifications_screen_test.dart` | 8     | 60%      | ✅     |
| `qr_code_dialog_test.dart`       | 10    | 75%      | ✅     |
| `app_drawer_test.dart`           | 6     | 65%      | ✅     |

### Integration Tests (1 file)

| File                  | Tests | Coverage | Status |
| --------------------- | ----- | -------- | ------ |
| `auth_flow_test.dart` | 8     | 50%      | ✅     |

---

## 📚 Resources

### Documentation

- [TESTING_GUIDE.md](TESTING_GUIDE.md) - Comprehensive testing guide
- [Flutter Testing Guide](https://docs.flutter.dev/testing)
- [mocktail Package](https://pub.dev/packages/mocktail)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)

### Packages

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.4
  mocktail: ^1.0.3
  integration_test:
    sdk: flutter
  build_runner: ^2.4.8
```

### Useful Commands

```bash
# Run tests in watch mode
flutter test --watch

# Run tests with debugger
flutter test --start-paused

# Run tests with custom platform
flutter test --platform chrome

# Generate coverage for specific test
flutter test --coverage test/unit/models/aurora_product_test.dart
```

---

## 📈 Test Metrics

### Current Status

| Metric               | Value |
| -------------------- | ----- |
| **Total Test Files** | 16    |
| **Total Tests**      | ~200  |
| **Passing Tests**    | ~185  |
| **Failing Tests**    | ~15   |
| **Overall Coverage** | ~25%  |

### Test Distribution

```
Unit Tests:       ████████████████ 65%
Widget Tests:     ████████ 25%
Integration:      ███ 10%
```

---

## 🔄 Continuous Integration

### GitHub Actions

Tests run automatically on:

- Every push to main branch
- Every pull request
- Every release

### Pre-commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
flutter test
flutter analyze
```

---

**Last Updated:** March 2026  
**Version:** 2.0.0  
**Maintained by:** Aurora Development Team

---

## 📝 Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│                    TEST COMMANDS                        │
├─────────────────────────────────────────────────────────┤
│ flutter test              Run all tests                 │
│ flutter test --coverage   Run with coverage             │
│ flutter test test/unit/   Run unit tests                │
│ flutter test -n "name"    Run tests by name pattern     │
│ test.bat                  Windows batch runner          │
│ .\test.ps1                PowerShell runner             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                  COVERAGE COMMANDS                      │
├─────────────────────────────────────────────────────────┤
│ flutter test --coverage     Generate coverage           │
│ genhtml coverage/lcov.info  Generate HTML report        │
│ start coverage/html/index.html  Open report (Windows)   │
└─────────────────────────────────────────────────────────┘
```
