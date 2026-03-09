# Aurora E-commerce - Test Suite

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

# Direct Flutter command
flutter test --coverage
```

## Test Organization

### Unit Tests (`test/unit/`)
- **models/**: Data model tests
  - `aurora_product_test.dart`: Product model
  - `chat_models_test.dart`: Chat conversation and message models
  - `seller_test.dart`: Seller/factory model

- **services/**: Service layer tests
  - `cache_and_rate_limiter_test.dart`: Caching and rate limiting
  - `theme_provider_test.dart`: Theme state management

- **backend/**: Database tests
  - `sellerdb_test.dart`: Seller SQLite database
  - `productsdb_test.dart`: Products SQLite database

### Widget Tests (`test/widget/`)
- `app_drawer_test.dart`: Navigation drawer component

### Integration Tests (`test/integration/`)
- (To be added)

### Helpers & Mocks
- **helpers/**: Test utilities
  - `test_helpers.dart`: Common test functions and mock creators

- **mocks/**: Mock implementations
  - `mock_supabase.dart`: Mock Supabase client and services

## Test Commands Reference

| Command | Description |
|---------|-------------|
| `flutter test` | Run all tests |
| `flutter test --coverage` | Run tests with coverage |
| `flutter test test/unit/` | Run unit tests only |
| `flutter test test/widget/` | Run widget tests only |
| `flutter test test/unit/models/aurora_product_test.dart` | Run specific test |
| `flutter test --plain-name "AuroraProduct"` | Run tests by name pattern |
| `flutter test --watch` | Run in watch mode |

## Coverage

View coverage report:
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
start coverage/html/index.html  # Windows
```

## Writing Tests

### Test File Template
```dart
// Unit Tests for ClassName
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

### Widget Test Template
```dart
// Widget Tests for MyWidget
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Widget should display correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyWidget(),
      ),
    );

    expect(find.byType(MyWidget), findsOneWidget);
  });
}
```

## Best Practices

1. **Naming**: Use descriptive names - `should_return_value_when_condition`
2. **Independence**: Each test should be independent
3. **AAA Pattern**: Arrange, Act, Assert
4. **Coverage**: Test happy path, edge cases, and error cases
5. **Mocks**: Mock external dependencies (Supabase, APIs, databases)

## Dependencies

Test dependencies are in `pubspec.yaml`:
- `flutter_test`: Flutter testing framework
- `mockito`: Mocking framework
- `mocktail`: Modern mocking library for Dart
- `integration_test`: Integration testing

## Troubleshooting

### Test not found
Ensure the test file is in the `test/` directory and follows the `*_test.dart` naming convention.

### Database not initialized
Call `await db.init()` in your `setUp()` method.

### Async operations not completing
Use `await tester.pumpAndSettle()` for widget tests or add explicit delays.

## Additional Resources

- [Flutter Testing Guide](https://docs.flutter.dev/testing)
- [TESTING_GUIDE.md](../TESTING_GUIDE.md) - Comprehensive testing documentation
- [mocktail Package](https://pub.dev/packages/mocktail)

---

**Last Updated**: March 2026  
**Version**: 1.0.0
