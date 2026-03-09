# Aurora E-commerce App - Complete Testing Guide

## 📋 Overview

This document provides comprehensive testing coverage for the Aurora E-commerce Flutter application, including unit tests, widget tests, and integration tests.

## 🎯 Test Structure

```
test/
├── helpers/                    # Test utilities and helpers
│   └── test_helpers.dart
├── mocks/                      # Mock implementations
│   └── mock_supabase.dart
├── unit/                       # Unit tests
│   ├── models/                 # Model tests
│   │   ├── aurora_product_test.dart
│   │   ├── chat_models_test.dart
│   │   └── seller_test.dart
│   ├── services/               # Service tests
│   │   ├── cache_and_rate_limiter_test.dart
│   │   └── theme_provider_test.dart
│   └── backend/                # Database tests
│       ├── sellerdb_test.dart
│       └── productsdb_test.dart
├── widget/                     # Widget tests
│   └── app_drawer_test.dart
└── integration/                # Integration tests
    └── (to be added)
```

## 🚀 Running Tests

### Run All Tests
```bash
flutter test
```

### Run Tests with Coverage
```bash
flutter test --coverage
```

### Run Specific Test File
```bash
flutter test test/unit/models/aurora_product_test.dart
```

### Run Tests by Tag/Pattern
```bash
flutter test --plain-name "AuroraProduct"
flutter test --plain-name "CacheManager"
```

### Run Tests in Watch Mode
```bash
flutter test --watch
```

### Run Tests with Debug Output
```bash
flutter test --reporter=expanded
```

## 📊 Test Coverage Report

After running tests with coverage:

### Generate HTML Report
```bash
# Install lcov if not already installed
pub global activate lcov

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open in browser (Windows)
start coverage/html/index.html
```

### View Coverage Summary
```bash
# Show coverage in terminal
flutter test --coverage && genhtml coverage/lcov.info -o coverage/html && echo "Coverage report generated at coverage/html/index.html"
```

## 🧪 Test Categories

### 1. Unit Tests

#### Models
- **AuroraProduct**: Product model with all fields, JSON serialization, QR data generation
- **Chat Models**: Conversations, messages, typing indicators
- **Seller**: Seller/factory model with multi-role support

#### Services
- **CacheManager**: In-memory and disk caching with expiry
- **RateLimiter**: API rate limiting functionality
- **ThemeProvider**: Theme state management

#### Backend/Databases
- **SellerDB**: Local SQLite operations for seller data
- **ProductsDB**: Local SQLite operations for product data

### 2. Widget Tests

#### Components
- **AppDrawer**: Navigation drawer with seller/factory menus
- **MetadataFormBuilder**: Dynamic form generation (to be added)

#### Screens
- **Login**: Authentication screen (to be added)
- **Signup**: Registration screen (to be added)
- **Home**: Main dashboard (to be added)

### 3. Integration Tests

Critical user flows (to be added):
- User registration and login
- Product creation and management
- Chat messaging flow
- Order processing

## 📝 Writing Tests

### Unit Test Example

```dart
import 'package:flutter_test/flutter_test.dart';

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

### Widget Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Widget should display text', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Text('Hello World'),
      ),
    );

    expect(find.text('Hello World'), findsOneWidget);
  });
}
```

### Mocking Dependencies

```dart
import 'package:mocktail/mocktail.dart';

class MockService extends Mock implements Service {}

void main() {
  late MockService mockService;

  setUp(() {
    mockService = MockService();
    when(() => mockService.method()).thenReturn('value');
  });
}
```

## ✅ Test Best Practices

### 1. Naming Conventions
- Use descriptive test names: `should_return_null_when_user_not_found`
- Group related tests: `group('Authentication', () {})`
- Follow AAA pattern: Arrange, Act, Assert

### 2. Test Independence
- Each test should be independent
- Use `setUp` and `tearDown` for isolation
- Don't rely on test execution order

### 3. Test Coverage
- Test happy path (expected behavior)
- Test edge cases (null values, empty lists)
- Test error cases (exceptions, failures)

### 4. Mocking
- Mock external dependencies (Supabase, APIs)
- Mock heavy operations (database, file I/O)
- Use fakes for simple implementations

## 🔧 Test Utilities

### Test Helpers (`test/helpers/test_helpers.dart`)
- `createMockUser()`: Create mock Supabase user
- `createMockSession()`: Create mock session
- `pumpApp()`: Pump widget with standard setup
- `waitForAsyncOperations()`: Wait for async operations

### Mocks (`test/mocks/`)
- `MockSupabaseClient`: Mock Supabase client
- `MockAuth`: Mock authentication
- `MockStorage`: Mock storage operations

## 📈 Coverage Goals

| Component | Current | Goal |
|-----------|---------|------|
| Models | ✅ 90%+ | 95%+ |
| Services | ✅ 80%+ | 90%+ |
| Databases | ✅ 85%+ | 90%+ |
| Widgets | 🔄 60%+ | 85%+ |
| Integration | ⏳ 0% | 70%+ |
| **Overall** | **~70%** | **90%** |

## 🐛 Troubleshooting

### Test Fails with "Database not initialized"
```dart
// Ensure database is initialized in setUp
setUp(() async {
  db = MyDatabase();
  await db.init();
});
```

### Test Fails with Async Operations
```dart
// Use pumpAndSettle for async widget operations
await tester.pumpAndSettle();

// Or use explicit delays
await tester.pump(const Duration(milliseconds: 100));
```

### Mock Not Working
```dart
// Ensure you're using the mock correctly
when(() => mock.method()).thenReturn(value);
// NOT
mock.method(); // This calls the real method
```

## 📚 Additional Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [mocktail Package](https://pub.dev/packages/mocktail)
- [Flutter Test Coverage](https://docs.flutter.dev/testing/code-coverage)

## 🔄 Continuous Integration

### GitHub Actions Workflow (`.github/workflows/test.yml`)

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

## 📞 Support

For questions or issues with testing:
1. Check this guide first
2. Review existing test files for examples
3. Consult Flutter testing documentation
4. Ask the development team

---

**Last Updated**: March 2026  
**Version**: 1.0.0  
**Maintained by**: Aurora Development Team
