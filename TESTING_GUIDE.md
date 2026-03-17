# Aurora E-commerce - Comprehensive Testing Guide

## Table of Contents

- [Overview](#overview)
- [Test Organization](#test-organization)
- [Quick Start](#quick-start)
- [Running Tests](#running-tests)
- [Writing Tests](#writing-tests)
- [Best Practices](#best-practices)
- [Mocking Guide](#mocking-guide)
- [Coverage](#coverage)
- [Troubleshooting](#troubleshooting)
- [Test Files Reference](#test-files-reference)

---

## Overview

The Aurora testing suite ensures code quality, prevents regressions, and validates functionality across all layers of the application.

### Testing Pyramid

```
        /\
       /  \
      / E2E \      Integration Tests (Few)
     /--------\
    /  Widget   \    Widget Tests (Some)
   /--------------\
  /    Unit Tests   \  Unit Tests (Many)
 /--------------------\
```

### Test Coverage Goals

| Layer                 | Target | Current |
| --------------------- | ------ | ------- |
| **Unit Tests**        | 90%    | ~40%    |
| **Widget Tests**      | 70%    | ~10%    |
| **Integration Tests** | 50%    | ~5%     |
| **Overall**           | 80%    | ~20%    |

---

## Test Organization

### Directory Structure

```
test/
├── helpers/              # Test utilities and helpers
│   ├── test_helpers.dart
│   └── test_data.dart
├── mocks/                # Mock implementations
│   ├── mocks.dart
│   ├── mock_supabase.dart
│   └── mock_services.dart
├── unit/                 # Unit tests
│   ├── models/           # Model tests
│   ├── services/         # Service tests
│   ├── backend/          # Database tests
│   └── utils/            # Utility tests
├── widget/               # Widget tests
│   ├── pages/            # Page/screen tests
│   └── widgets/          # Component tests
├── integration/          # Integration tests
│   ├── auth_flow_test.dart
│   └── product_flow_test.dart
└── sql/                  # SQL test scripts
```

---

## Quick Start

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
genhtml coverage/lcov.info -o coverage/html
start coverage/html/index.html
```

---

## Running Tests

### Test Commands

| Command                                                  | Description                 |
| -------------------------------------------------------- | --------------------------- |
| `flutter test`                                           | Run all tests               |
| `flutter test --coverage`                                | Run tests with coverage     |
| `flutter test test/unit/`                                | Run unit tests only         |
| `flutter test test/widget/`                              | Run widget tests only       |
| `flutter test test/integration/`                         | Run integration tests only  |
| `flutter test test/unit/models/aurora_product_test.dart` | Run specific test file      |
| `flutter test --plain-name "AuroraProduct"`              | Run tests by name pattern   |
| `flutter test --tags smoke`                              | Run tests with specific tag |
| `flutter test --exclude-tags slow`                       | Exclude tests with tag      |

### Test Tags

Use tags to categorize tests:

```dart
@Tags(['smoke', 'unit'])
group('AuroraProduct', () {
  // ...
});
```

---

## Writing Tests

### Unit Test Template

```dart
// Unit Tests for ClassName
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora/models/your_model.dart';

void main() {
  group('ClassName', () {
    // Setup before all tests
    setUpAll(() async {
      // One-time initialization
    });

    // Setup before each test
    setUp(() {
      // Common setup
    });

    // Cleanup after each test
    tearDown(() {
      // Common cleanup
    });

    // Cleanup after all tests
    tearDownAll(() async {
      // Final cleanup
    });

    test('should do something', () {
      // Arrange
      final expected = 'value';

      // Act
      final actual = methodUnderTest();

      // Assert
      expect(actual, expected);
    });

    test('should handle edge case', () {
      // Test edge cases
    });
  });
}
```

### Widget Test Template

```dart
// Widget Tests for MyWidget
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aurora/widgets/my_widget.dart';

void main() {
  group('MyWidget', () {
    testWidgets('should display correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MyWidget(),
          ),
        ),
      );

      // Verify widget exists
      expect(find.byType(MyWidget), findsOneWidget);

      // Verify content
      expect(find.text('Expected Text'), findsOneWidget);
    });

    testWidgets('should respond to tap', (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MyWidget(
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(MyWidget));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
```

### Integration Test Template

```dart
// Integration Tests for Feature Flow
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aurora/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Feature Flow', () {
    testWidgets('Complete user flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Step 1: Login
      await tester.enterText(
        find.byKey(Key('email-field')),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(Key('password-field')),
        'Password123!',
      );
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Step 2: Verify navigation
      expect(find.text('Welcome'), findsOneWidget);

      // Step 3: Perform action
      await tester.tap(find.text('Create Product'));
      await tester.pumpAndSettle();

      // Step 4: Verify result
      expect(find.text('Product Created'), findsOneWidget);
    });
  });
}
```

---

## Best Practices

### 1. Test Naming Convention

Use descriptive names following the pattern:

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
    CartItem(price: 20, quantity: 1),
  ]);

  // Act
  final total = cart.calculateTotal();

  // Assert
  expect(total, 40);
});
```

### 3. Test Independence

Each test should be independent:

```dart
// GOOD: Each test sets up its own data
test('test 1', () {
  final product = createTestProduct();
  // ...
});

test('test 2', () {
  final product = createTestProduct(); // Fresh instance
  // ...
});
```

### 4. Test Edge Cases

```dart
group('divide', () {
  test('should divide normally', () { ... });
  test('should handle zero numerator', () { ... });
  test('should throw on zero denominator', () { ... });
  test('should handle negative numbers', () { ... });
  test('should handle very large numbers', () { ... });
});
```

### 5. Use Mocks Appropriately

```dart
// Mock external dependencies
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockAuthService extends Mock implements AuthService {}

// Use in tests
final mockClient = MockSupabaseClient();
when(() => mockClient.from('users')).thenReturn(...);
```

### 6. Async Testing

```dart
// Use async/await
test('should fetch data', () async {
  final data = await fetchData();
  expect(data, isNotEmpty);
});

// Use pumpAndSettle for animations
testWidgets('should animate', (tester) async {
  await tester.pumpWidget(MyWidget());
  await tester.pumpAndSettle();
  // ...
});
```

### 7. Golden Tests

```dart
testWidgets('should match golden', (tester) async {
  await tester.pumpWidget(MyWidget());
  await expectLater(
    find.byType(MyWidget),
    matchesGoldenFile('goldens/my_widget.png'),
  );
});
```

---

## Mocking Guide

### Mock Services

```dart
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}
class MockProductService extends Mock implements ProductService {}
class MockNotificationService extends Mock implements NotificationService {}
```

### Mock Databases

```dart
class MockSellerDB extends Mock implements SellerDB {
  final Map<String, dynamic> _data = {};

  @override
  Future<Map<String, dynamic>?> getSellerByUserId(String userId) async {
    return _data[userId];
  }

  @override
  Future<void> addSeller(Map<String, dynamic> seller) async {
    _data[seller['user_id']] = seller;
  }
}
```

### Mock Supabase

```dart
class MockSupabaseClient extends Mock implements SupabaseClient {
  final MockAuth _auth = MockAuth();
  final MockPostgrestClient _database = MockPostgrestClient();

  @override
  MockAuth get auth => _auth;

  @override
  MockPostgrestClient get from(String table) => _database;
}
```

### Setup Mock Method Channels

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void setupMockMethodChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (message) async {
    if (message.method == 'getTemporaryDirectory') {
      return '/tmp';
    }
    if (message.method == 'getApplicationDocumentsDirectory') {
      return '/documents';
    }
    return null;
  });
}
```

---

## Coverage

### Generate Coverage

```bash
# Run tests with coverage
flutter test --coverage

# View coverage report
flutter pub global activate lcov
genhtml coverage/lcov.info -o coverage/html

# Open in browser
start coverage/html/index.html  # Windows
open coverage/html/index.html   # macOS
xdg-open coverage/html/index.html  # Linux
```

### Coverage Goals by File Type

| File Type     | Target Coverage |
| ------------- | --------------- |
| **Models**    | 95%+            |
| **Services**  | 90%+            |
| **Providers** | 85%+            |
| **Pages**     | 70%+            |
| **Widgets**   | 80%+            |

### Check Coverage for Specific File

```bash
# Filter coverage by file
lcov --extract coverage/lcov.info "*/lib/services/auth_provider.dart" -o filtered.info
genhtml filtered.info -o coverage/auth_provider
```

---

## Troubleshooting

### MissingPluginException

**Problem:** Tests fail with `MissingPluginException`

**Solution:** Mock method channels

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

**Problem:** Tests timeout

**Solution:** Increase timeout

```dart
test('long running test', () async {
  // ...
}, timeout: Timeout(Duration(minutes: 2)));
```

### Widget Not Found

**Problem:** `Expected: exactly one matching node, got 0`

**Solutions:**

1. Check widget key
2. Pump and settle animations
3. Verify widget is in tree

```dart
await tester.pumpWidget(MyWidget());
await tester.pumpAndSettle(); // Wait for animations
expect(find.byKey(Key('my-key')), findsOneWidget);
```

### Mock Not Working

**Problem:** Mock returns null or wrong value

**Solution:** Properly setup mock

```dart
when(() => mock.method()).thenReturn(expectedValue);
// OR for async
when(() => mock.asyncMethod()).thenAnswer((_) async => expectedValue);
```

---

## Test Files Reference

### Unit Tests

| File                         | Tests           | Coverage |
| ---------------------------- | --------------- | -------- |
| `aurora_product_test.dart`   | Product model   | 95%      |
| `chat_models_test.dart`      | Chat models     | 90%      |
| `seller_test.dart`           | Seller model    | 90%      |
| `auth_provider_test.dart`    | Auth service    | 85%      |
| `product_provider_test.dart` | Product service | 85%      |
| `sellerdb_test.dart`         | Local DB        | 80%      |
| `productsdb_test.dart`       | Local DB        | 80%      |

### Widget Tests

| File                             | Tests         | Coverage |
| -------------------------------- | ------------- | -------- |
| `login_page_test.dart`           | Login screen  | 70%      |
| `notifications_screen_test.dart` | Notifications | 60%      |
| `qr_code_dialog_test.dart`       | QR dialog     | 75%      |
| `app_drawer_test.dart`           | Navigation    | 65%      |

### Integration Tests

| File                  | Tests     | Coverage |
| --------------------- | --------- | -------- |
| `auth_flow_test.dart` | Auth flow | 50%      |

---

## Continuous Integration

### GitHub Actions

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running tests..."
flutter test

if [ $? -ne 0 ]; then
  echo "Tests failed!"
  exit 1
fi

echo "Running analyzer..."
flutter analyze

if [ $? -ne 0 ]; then
  echo "Analysis failed!"
  exit 1
fi
```

---

## Additional Resources

- [Flutter Testing Guide](https://docs.flutter.dev/testing)
- [mocktail Package](https://pub.dev/packages/mocktail)
- [provider Testing](https://pub.dev/packages/provider#testing)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)

---

**Last Updated:** March 2026  
**Version:** 2.0.0  
**Maintained by:** Aurora Development Team
